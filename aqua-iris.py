import psycopg2
import argparse
from os import getenv, path, makedirs, listdir
import os
import sys
import csv
import time
from psycopg2.extras import DictCursor
from flask import Flask, send_file, render_template
from zipfile import ZipFile
import glob
import multiprocessing
import signal
import boto3
from botocore.exceptions import NoCredentialsError
import tarfile
import datetime
import json

def connect_to_database(params):
    connection = psycopg2.connect(**params)
    cursor = connection.cursor(cursor_factory=DictCursor)
    return connection, cursor

def execute_query(connection, cursor, query_file):
    with open(query_file, "r") as file:
        query = file.read()
        cursor.execute(query)
        result = cursor.fetchall()
    return result, [desc[0] for desc in cursor.description]

def save_query_results_to_csv(output_file, header, result_rows):
    with open(output_file, "w", newline="") as file:
        csv_writer = csv.writer(file)
        csv_writer.writerow(header)
        csv_writer.writerows(result_rows)

def create_tarball(file_list, output_name):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    output_filename = f"{output_directory}/{output_name}_{timestamp}.tar.gz"
    
    with tarfile.open(output_filename, "w:gz") as tar:
        for file_path in file_list:
            tar.add(file_path, arcname=os.path.basename(file_path))

    print(f"Tarball created: {output_filename}")
    return output_filename

class QueryTimeoutException(Exception):
    pass

def timeout_handler(signum, frame):
    raise QueryTimeoutException("Query execution timed out")

def execute_query_with_timeout(connection, cursor, query_file, query_timeout):
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(query_timeout)

    try:
        result, header = execute_query(connection, cursor, query_file)
    except QueryTimeoutException:
        print("Query execution timed out")
        result, header = [], []  # Placeholder response for timeout
    finally:
        signal.alarm(0)  # Reset the alarm

    return result, header

def timed_query_execution(params, query_file, output_file, query_timeout):
    try:
        output_directory = os.path.dirname(output_file)
        metadata_tmp_file = f'{os.path.splitext(os.path.basename(query_file))[0]}.tmp.json'
        metadata_tmp_file_path = f'{output_directory}/{metadata_tmp_file}'
        start_time = time.time()
        connection, cursor = connect_to_database(params)
        result, header = execute_query_with_timeout(connection, cursor, query_file, query_timeout)
        end_time = time.time()

        execution_time = end_time - start_time
        print(f"[{query_file}] Query execution time: {execution_time:.2f} seconds")

        save_query_results_to_csv(output_file, header, result)

        # Append metadata file here

        metadata_entry = {"query_name": query_file, "collection_time": round(execution_time, 2), 
                        "status": 'Success' if result is not None else 'Failure'}
        
        with open(metadata_tmp_file_path, 'w') as file:
            json.dump(metadata_entry, file, indent=4)

        cursor.close()
        connection.close()
    except Exception as e:
        # Handle exceptions during query execution
        print(f"[{query_file}] Error during query execution: {str(e).rstrip()}")
        # Update metadata to indicate failure
        metadata_entry = {"query_name": query_file, "status": "Failure", "error": f'{str(e).rstrip()}'}
        with open(metadata_tmp_file_path, 'w') as file:
            json.dump(metadata_entry, file, indent=4)

def upload_to_s3(local_file, bucket, s3_file):
    s3 = boto3.client('s3')
    try:
        s3.upload_file(local_file, bucket, s3_file)
        print(f"Successfully uploaded {local_file} to {bucket}/{s3_file}")
    except NoCredentialsError:
        print("AWS credentials not available.")
    except Exception as e:
        print(f"Error uploading to S3: {e}")

def run_queries(sql_directory, db_params):
    sql_files = [file for file in os.listdir(sql_directory) if file.endswith(".sql")]
    query_timeout = 7200

    with multiprocessing.Pool(processes=8) as pool:
        pool.starmap(
            timed_query_execution,
            [(db_params, os.path.join(sql_directory, sql_file), f"{output_directory}/{os.path.splitext(sql_file)[0]}_results.csv", query_timeout) for sql_file in sql_files]
        )

def process_metadata(directory):
    collection = {
        "collection_timestamp": datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        "collection_data": []
    }
    
    for filename in os.listdir(directory):
        if filename.endswith('.tmp.json'):
            file_path = os.path.join(directory, filename)
            with open(file_path, 'r') as file:
                json_content = json.load(file)
                collection["collection_data"].append(json_content)
            # Delete the tmp.json as it's no longer needed
            os.remove(file_path)
    
    return collection


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Aqua Security metrics gathering tool necessary for assessing risk and security posture as seen by the Aqua Platform. This tool connects directly to the backend database.')
    parser.add_argument('-s', '--server', help='PostgreSQL hostname or IP for the operational databse [Default: aqua-db]', default='aqua-db', required=False)
    parser.add_argument('-p', '--port', help='Specify port, if other than 5432 [Default: 5432]', default='5432', required=False)
    parser.add_argument('-db', '--dbname', help='Name of the operational Aqua database within PostgreSQL [Default: scalock]', default='scalock', required=False)
    parser.add_argument('-u', '--dbuser', help='PostgreSQL user that can perform queries on the operational Aqua database [Default: postgres]', default='postgres', required=False)
    parser.add_argument('-d', '--daemon', help='Run in daemon mode, starting the http server',
                        action='store_true')
    parser.add_argument('-D', '--debug', help='Enable debug messages', action='store_true')
    parser.add_argument('-q', '--query', help='', choices=['all', 'operational', 'audit'])
    parser.add_argument('-as', '--aserver', help='PostgreSQL hostname or IP for the audit database [Default: aqua-db]', default='aqua-db', required=False)
    parser.add_argument('-ap', '--aport', help='Specify port, if other than 5432 [Default: 5432]', default='5432', required=False)
    parser.add_argument('-adb', '--adbname', help='Name of the audit Aqua database within PostgreSQL [Default: slk_audit]', default='slk_audit', required=False)
    parser.add_argument('-au', '--adbuser', help='PostgreSQL user that can perform queries on the audit Aqua database [Default: postgres]', default='postgres', required=False)
    parser.add_argument('-s3', '--s3', help='Specify if the results should be pushed to an s3 bucket', required=False, action='store_true')
    parser.add_argument('--s3-bucket-name', help='Name of target s3 bucket to write results', required=False)
    args = parser.parse_args()

    if args.s3 and not args.s3_bucket_name:
        parser.error("--s3 requires --s3-bucket-name")
    elif args.s3 and args.s3_bucket_name:
        iris_s3_bucket_name = args.s3_bucket_name
    else:
        iris_s3_bucket_name = None

    # Output directory
    output_directory = "out"

    # Operational database connection details
    if getenv('SCALOCK_DBHOST'): db_server = getenv('SCALOCK_DBHOST') 
    else: db_server = args.server
    print('db_server = ' + db_server)

    if getenv('SCALOCK_DBPORT'): db_port = getenv('SCALOCK_DBPORT') 
    else: db_port = args.port

    if getenv('SCALOCK_DBNAME'): db_name = getenv('SCALOCK_DBNAME') 
    else: db_name = args.dbname

    if getenv('SCALOCK_DBUSER'): db_user = getenv('SCALOCK_DBUSER') 
    else: db_user = args.dbuser

    # Audit database connection details
    if getenv('SCALOCK_AUDIT_DBHOST'): db_audit_server = getenv('SCALOCK_AUDIT_DBHOST') 
    elif parser.get_default('aserver') != args.aserver: db_audit_server = args.aserver
    else: db_audit_server = db_server

    if getenv('SCALOCK_AUDIT_DBPORT'): db_audit_port = getenv('SCALOCK_AUDIT_DBPORT') 
    elif parser.get_default('aport') != args.aport: db_audit_port = args.aport
    else: db_audit_port = db_port

    if getenv('SCALOCK_AUDIT_DBNAME'): db_audit_name = getenv('SCALOCK_AUDIT_DBNAME')
    else: db_audit_name = args.adbname

    if getenv('SCALOCK_AUDIT_DBUSER'): db_audit_user = getenv('SCALOCK_AUDIT_DBUSER') 
    elif parser.get_default('adbuser') != args.adbuser: db_audit_user = args.adbuser
    else: db_audit_user = db_user

    # Get database password from environment
    db_password = getenv('SCALOCK_DBPASSWORD')
    if getenv('SCALOCK_AUDIT_DBPASSWORD'): db_audit_password = getenv('SCALOCK_AUDIT_DBPASSWORD')
    else: db_audit_password = db_password

    # Check if s3 push was specified
    if getenv('IRIS_PUSH_S3', 'False') in ('true', '1', 't') or args.s3: 
        iris_push_s3 = True
        if iris_s3_bucket_name == None and getenv('IRIS_S3_BUCKET_NAME') == None:
            parser.error("ERROR: No s3 bucket name specified by --s3-bucket-name or environment variable IRIS_S3_BUCKET_NAME")
        elif getenv('IRIS_S3_BUCKET_NAME'):
            iris_s3_bucket_name = getenv('IRIS_S3_BUCKET_NAME')
    else: iris_push_s3 = False

    if getenv("IRIS_ENV_NAME"):
        iris_env_name = getenv("IRIS_ENV_NAME")
    else:
        iris_env_name = "iris-metrics"

    # Define operational database connection details as dict
    op_db_params = {
      "dbname": db_name,
      "user": db_user,
      "password": db_password,
      "host": db_server,
      "port": db_port
    }

    # Define operational database connection details as dict
    aud_db_params = {
      "dbname": db_audit_name,
      "user": db_audit_user,
      "password": db_audit_password,
      "host": db_audit_server,
      "port": db_audit_port
    }

    if not os.path.exists('out'):
        os.makedirs('out')

    metadata_file  = f"metadata_{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}.json"
    metadata_file_path = os.path.join(output_directory, metadata_file)

    try:
        if args.daemon or getenv('IRIS_WEBUI', 'False') in ('true', '1', 't'):
            # If the -d param was provided, stay running, and launch Flask 
            # Create Flask HTTP server
            app = Flask(__name__, template_folder='ui')

            @app.route('/')
            def index():
                return render_template('/index.html')

            @app.route('/download')
            def download():
                #filename = 'test.json'
                filename = f'{output_directory}/data.zip'
                with ZipFile(filename, 'w') as f:
                  for file in glob.glob(f'{output_directory}/*.csv'):
                      f.write(file)
                return send_file(filename, as_attachment=True)
            
            run_queries("csp-queries/scalock/", op_db_params)
            run_queries("csp-queries/slk_audit/", aud_db_params)

            csv_files = [f'{output_directory}/{file}' for file in os.listdir(output_directory) if file.endswith(".csv")]
            with open(metadata_file_path, "w") as metadata_file_new:
                json.dump(process_metadata(output_directory), metadata_file_new, indent=4)
            csv_files.append(metadata_file_path)
            query_tarball = create_tarball(csv_files, iris_env_name)

            # If enabled, push query results to specified s3 bucket
            if iris_push_s3:
                # Upload the result tarball file to S3
                timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
                s3_bucket = iris_s3_bucket_name
                s3_file_key = f"{iris_env_name}-{timestamp}/{os.path.basename(query_tarball)}"
                upload_to_s3(query_tarball, s3_bucket, s3_file_key)
                upload_to_s3(metadata_file_path, s3_bucket, s3_file_key)
            
            app.run(host='0.0.0.0', port=8088)
        else: 
            run_queries("csp-queries/scalock/", op_db_params)
            run_queries("csp-queries/slk_audit/", aud_db_params)

            csv_files = [f'{output_directory}/{file}' for file in os.listdir(output_directory) if file.endswith(".csv")]
            with open(metadata_file_path, "w") as metadata_file_new:
                json.dump(process_metadata(output_directory), metadata_file_new, indent=4)
            csv_files.append(metadata_file_path)
            query_tarball = create_tarball(csv_files, iris_env_name)

            # If enabled, push query results to specified s3 bucket
            if iris_push_s3:
                # Upload the result tarball file to S3
                timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
                s3_bucket = iris_s3_bucket_name
                s3_file_key = f"{iris_env_name}-{timestamp}/{os.path.basename(query_tarball)}"
                upload_to_s3(query_tarball, s3_bucket, s3_file_key)
                upload_to_s3(metadata_file_path, s3_bucket, f'{iris_env_name}-{timestamp}/{metadata_file}')

    except KeyboardInterrupt:
        print("\nExiting by user request.\n", file=sys.stderr)
        sys.exit(0)


    
