FROM python:3.12.0b1-alpine3.18
ADD aqua-iris.py /
ADD csp-queries /csp-queries
RUN apk add libpq-dev gcc musl-dev
RUN pip install psycopg2 flask
ENTRYPOINT ["python", "-u", "/aqua-iris.py"]
