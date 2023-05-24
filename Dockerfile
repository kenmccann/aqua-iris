FROM python:3.12.0b1-alpine3.18
ADD aqua-iris.py /
ENTRYPOINT ["python", "-u", "/aqua-iris.py"]
