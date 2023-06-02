import psycopg2
import argparse
from os import getenv, path, makedirs
import sys
from flask import Flask, send_file
import csv
from zipfile import ZipFile
import glob
from psycopg2.extras import DictCursor
from tabulate import tabulate

parser = argparse.ArgumentParser(description='Aqua Security metrics gathering tool necessary for assessing risk and security posture as seen by the Aqua Platform. This tool connects directly to the backend database.')
parser.add_argument('-s', '--server', help='PostgreSQL hostname or IP', required=True)
parser.add_argument('-p', '--port', help='Specify port, if other than 5432 [Default: 5432]', default='5432', required=False)
parser.add_argument('-n', '--dbname', help='Name of the Aqua database within PostgreSQL [Default: scalock]', default='scalock', required=False)
parser.add_argument('-u', '--dbuser', help='PostgreSQL user that can perform queries on the Aqua database', default='postgres', required=False)
parser.add_argument('-d', '--daemon', help='Run in daemon mode, starting the http server',
                    action='store_true')
parser.add_argument('-D', '--debug', help='Enable debug messages', action='store_true')
args = parser.parse_args()

if getenv('SCALOCK_DBHOST'): db_server = getenv('SCALOCK_DBHOST') 
else: db_server = args.server

if getenv('SCALOCK_DBPORT'): db_port = getenv('SCALOCK_DBPORT') 
else: db_port = args.port

if getenv('SCALOCK_DBNAME'): db_name = getenv('SCALOCK_DBNAME') 
else: db_name = args.dbname

if getenv('SCALOCK_DBUSER'): db_user = getenv('SCALOCK_DBUSER') 
else: db_user = args.dbuser

# Get database password from environment
db_password = getenv('SCALOCK_DBPASSWORD')

# Create Flask HTTP server
app = Flask(__name__)

# Establish long-lived connection to PostgreSQL Server
conn = psycopg2.connect(f"host={args.server} dbname={db_name} user={db_user} password={db_password}")
cur = conn.cursor(cursor_factory=DictCursor)

# Create output directory
if not path.exists('out'):
  makedirs('out')

@app.route('/')
def index():
    return '''
        <html>
            <head>
                <title>Download Test</title>
                <style>
                    body {
                        background-color: #01253f;
                        background-image: url("https://example.com/aqua_logo.png");
                        background-repeat: no-repeat;
                        background-position: center center;
                        background-size: cover;
                    }

                    .content {
                        text-align: center;
                        padding: 50px;
                        color: #ffffff;
                        font-family: Arial, sans-serif;
                    }

                    .download-button {
                        background-color: #00b4e6;
                        color: #ffffff;
                        border: none;
                        padding: 10px 20px;
                        font-size: 16px;
                        cursor: pointer;
                        border-radius: 4px;
                    }

                    .download-button:hover {
                        background-color: #007c9b;
                    }
                </style>
            </head>
            <body>
                <div class="content">
                    <h1>Download Test Page</h1>
                    <p>Click the button below to download the JSON file.</p>
                    <button class="download-button" onclick="window.location.href='/download'">Download JSON</button>
                </div>
            </body>
        </html>
    '''

@app.route('/download')
def download():
    #filename = 'test.json'
    filename = 'out/data.zip'
    with ZipFile(filename, 'w') as f:
      for file in glob.glob('out/*.csv'):
          f.write(file)
    return send_file(filename, as_attachment=True)

def execute_query(query_file):
   cur.execute(open(query_file, "r").read())
   return cur.fetchall()

def get_header():
   return [desc[0] for desc in cur.description]

def result_table(records):
    # Get column names from cursor description
    columns = get_header()

    # Format query results as a list of lists
    formatted_rows = [[row[col] for col in columns] for row in records]

    # Print the query results in a nicely formatted table
    return tabulate(formatted_rows, headers=columns, tablefmt="psql")

def write_csv(filename, header, records):
  with open(filename, 'w', newline='') as output_file:
    csv_writer = csv.writer(output_file)
    csv_writer.writerow(header)
    csv_writer.writerows(records)
   

def image_repo_vuln_severity_distribution():
  records = execute_query("csp-queries/scalock/image_repo_vuln_severity_distribution.sql")
  print("Top 10 repos by Vulnerability severity distirbution\n" + result_table(records)+"\n")
  header = get_header()
  write_csv('out/image_repo_vuln_sev_distro.csv', header, records)

def containers_overall_assurance():
  records = execute_query("csp-queries/scalock/containers_overall_assurance_results.sql")
  print("Containers overall assurance results\n" + result_table(records)+"\n")
  header = get_header()
  write_csv('out/containers_overall_assurance_results.csv', header, records)

def image_assurance_control_summary():
  records = execute_query("csp-queries/scalock/image_assurance_control_summary.sql")
  print("Image Assurance control summary\n" + result_table(records)+"\n")
  header = get_header()
  write_csv('out/image_assurance_control_summary.csv', header, records)

def image_count_over_time():
  records = execute_query("csp-queries/scalock/image_count_over_time.sql")
  print("Image count growth over 12 months\n" + result_table(records)+"\n")
  header = get_header()
  write_csv('out/image_count_over_time.csv', header, records)

def image_growth_metrics():
  records = execute_query("csp-queries/scalock/image_growth_metrics.sql")
  print("Growth metrics\n" + result_table(records)+"\n")
  header = get_header()
  write_csv('out/image_count_over_time.csv', header, records)

if __name__ == '__main__':
    try:
        if args.daemon:
            image_repo_vuln_severity_distribution()
            containers_overall_assurance()
            image_assurance_control_summary()
            image_count_over_time()
            image_growth_metrics()
            app.run(host='0.0.0.0', port=8088)
        else: 
          conn = psycopg2.connect(f"host={args.server} dbname=scalock user=postgres password={db_password}")
          cur = conn.cursor()
          #cur.execute("SELECT * FROM settings")
          cur.execute(open("csp-queries/scalock/image_repo_vuln_severity_distribution.sql", "r").read())
          records = cur.fetchall()
          print(records)

    except KeyboardInterrupt:
        print("\nExiting by user request.\n", file=sys.stderr)
        sys.exit(0)