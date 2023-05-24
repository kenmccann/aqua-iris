import psycopg2
import argparse
from os import getenv
import sys

parser = argparse.ArgumentParser(description='Aqua Security metrics gathering tool necessary for assessing risk and security posture as seen by the Aqua Platform ')
parser.add_argument('-s', '--server', help='PostgreSQL hostname or IP', required=True)
args = parser.parse_args()

# Get database password from environment
db_password = getenv('SCALOCK_DBPASSWORD')

if __name__ == '__main__':
    try:
        conn = psycopg2.connect(f"host={args.server} dbname=scalock user=postgres password={db_password}")
        cur = conn.cursor()
        cur.execute("SELECT * FROM settings")
        records = cur.fetchall()
        print(records)

    except KeyboardInterrupt:
        print("\nExiting by user request.\n", file=sys.stderr)
        sys.exit(0)