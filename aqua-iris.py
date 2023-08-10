import psycopg2
import argparse
from os import getenv, path, makedirs, listdir
import os
import sys
from flask import Flask, send_file, render_template
import csv
from zipfile import ZipFile
import glob
from psycopg2.extras import DictCursor
from tabulate import tabulate
import time

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
args = parser.parse_args()

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

# Create Flask HTTP server
app = Flask(__name__, template_folder='ui')

# Establish long-lived connection to PostgreSQL Server
conn = psycopg2.connect(f"host={db_server} dbname={db_name} user={db_user} password={db_password}")
cur = conn.cursor(cursor_factory=DictCursor)

# Establish long-lived connection to *audit* PostgreSQL Server
conn_a = psycopg2.connect(f"host={db_audit_server} dbname={db_audit_name} user={db_audit_user} password={db_audit_password}")
cur_a = conn_a.cursor(cursor_factory=DictCursor)

# Create output directory
if not path.exists('out'):
  makedirs('out')

@app.route('/')
def index():
    return render_template('/index.html')

@app.route('/download')
def download():
    #filename = 'test.json'
    filename = 'out/data.zip'
    with ZipFile(filename, 'w') as f:
      for file in glob.glob('out/*.csv'):
          f.write(file)
    return send_file(filename, as_attachment=True)

def execute_query(cursor, query_file):
   cursor.execute(open(query_file, "r").read())
   return cursor.fetchall()

# def execute_query_a(query_file):
#    cur_a.execute(open(query_file, "r").read())
#    return cur_a.fetchall()

def get_header(cursor):
   return [desc[0] for desc in cursor.description]

def result_table(cursor, records):
    # Get column names from cursor description
    columns = get_header(cursor)

    # Format query results as a list of lists
    formatted_rows = [[row[col] for col in columns] for row in records]

    # Print the query results in a nicely formatted table
    return tabulate(formatted_rows, headers=columns, tablefmt="psql")

def write_csv(filename, header, records):
  with open(filename, 'w', newline='') as output_file:
    csv_writer = csv.writer(output_file)
    csv_writer.writerow(header)
    csv_writer.writerows(records)
   

def run_all_scalock():
   for file in os.listdir("csp-queries/scalock/"):
      if not file.endswith('.sql'):
         continue
      tic = time.perf_counter()
      f = os.path.join("csp-queries/scalock/", file)
      print(f"Working on: {f}") 
      records = execute_query(cur, f)
      if len(records) < 50:
         print(f"{f}:\n" + result_table(cur, records)+"\n")
      header = get_header(cur)
      write_csv('out/'+file.replace(".sql", ".csv"), header, records)
      toc = time.perf_counter()
      print(f"{file}: SQL query completed in {toc - tic:0.4f} seconds")
      
def run_all_scalock_audit():
   for file in os.listdir("csp-queries/slk_audit/"):
      if not file.endswith('.sql'):
         continue
      tic = time.perf_counter()
      f = os.path.join("csp-queries/slk_audit/", file)
      print(f"Working on: {f}") 
      records = execute_query(cur_a, f)
      if len(records) < 50:
         print(f"{f}:\n" + result_table(cur_a, records)+"\n")
      header = get_header(cur_a)
      write_csv('out/'+file.replace(".sql", ".csv"), header, records)
      toc = time.perf_counter()
      print(f"{file}: SQL query completed in {toc - tic:0.4f} seconds")



if __name__ == '__main__':
    try:
        if args.daemon:
            run_all_scalock()
            run_all_scalock_audit()
            app.run(host='0.0.0.0', port=8088)
        else: 
           print("")
           
          #conn = psycopg2.connect(f"host={args.server} dbname=scalock user=postgres password={db_password}")
          #cur = conn.cursor()
          #cur.execute("SELECT * FROM settings")
          #cur.execute(open("csp-queries/scalock/image_repo_vuln_severity_distribution.sql", "r").read())
          #records = cur.fetchall()
          #print(records)

    except KeyboardInterrupt:
        print("\nExiting by user request.\n", file=sys.stderr)
        sys.exit(0)