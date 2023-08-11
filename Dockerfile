FROM python:3.12.0b1-alpine3.18

RUN buildDeps='gcc python3-dev musl-dev libpq-dev' \
    && apk update \
    && apk add --no-cache libpq \
    && apk add --virtual temp1 --no-cache $buildDeps \
    && pip install --no-cache-dir psycopg2 flask tabulate \
    && apk del temp1

ADD aqua-iris.py /
ADD csp-queries /csp-queries
ADD ui /ui
ADD static /static
RUN addgroup -g 11433 aqua \
    && adduser -G aqua -u 11431 aqua -D \
    && mkdir -p /out \
    && chown -R aqua:aqua /aqua-iris.py /csp-queries /out /ui /static

ENTRYPOINT ["python", "-u", "/aqua-iris.py"]
