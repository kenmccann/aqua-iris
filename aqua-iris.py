import psycopg2
import argparse
from os import getenv
import sys
from flask import Flask, send_file
import csv

parser = argparse.ArgumentParser(description='Aqua Security metrics gathering tool necessary for assessing risk and security posture as seen by the Aqua Platform ')
parser.add_argument('-s', '--server', help='PostgreSQL hostname or IP', required=True)
parser.add_argument('-d', '--daemon', help='Run in daemon mode, starting the http server',
                    action='store_true')
args = parser.parse_args()

# Get database password from environment
db_password = getenv('SCALOCK_DBPASSWORD')

# Create Flask HTTP server
app = Flask(__name__)

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
    filename = 'test.json'
    return send_file(filename, as_attachment=True)

def run_image_repo_vuln_sev_distro():
    conn = psycopg2.connect(f"host={args.server} dbname=scalock user=postgres password={db_password}")
    cur = conn.cursor()
    cur.execute(open("csp-queries/scalock/image_repo_vuln_severity_distribution.sql", "r").read())
    records = cur.fetchall()

    header = ["repo_name", "num_images", "total_vulns", "critical", "high", "medium", "low", "negligible" ]
    with open('image_repo_vuln_sev_distro.csv', 'w', newline='') as output_file:
      csv_writer = csv.writer(output_file)
      csv_writer.writerow(header)
      csv_writer.writerows(records)
      # for row in records:
      #     dict_writer.writerow(row)
    return records


if __name__ == '__main__':
    try:
        if args.daemon:
            img_repo_distro = run_image_repo_vuln_sev_distro()
            app.run()
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