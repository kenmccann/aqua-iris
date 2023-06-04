FROM python:3.12.0b1-alpine3.18 as build

RUN apk add libpq-dev gcc musl-dev
RUN pip install psycopg2 flask tabulate

FROM python:3.12.0b1-alpine3.18

COPY --from=build /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/
ADD aqua-iris.py /
ADD csp-queries /csp-queries
RUN addgroup -g 11433 aqua && adduser -G aqua -u 11431 aqua -D && mkdir -p /out && chown -R aqua:aqua /aqua-iris.py /csp-queries /out

ENTRYPOINT ["python", "-u", "/aqua-iris.py"]
