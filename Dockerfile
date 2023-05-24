FROM python:3.12.0b1-alpine3.18
ADD aqua-iris.py /
RUN apk add libpq-dev gcc musl-dev
RUN pip install psycopg2
ENTRYPOINT ["python", "-u", "/aqua-iris.py"]
