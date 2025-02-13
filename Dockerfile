ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim

RUN groupadd -r web && useradd -m -r -g web web && \
    apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY --chown=web:web app/requirements.txt /tmp/requirements.txt

USER web

WORKDIR /home/web

RUN pip install --no-cache-dir -r /tmp/requirements.txt

COPY --chown=web:web app/app.py /home/web/app.py

# These values will be overidden
ENV DB_USER="user" \
    DB_PASSWORD="password" \
    DB_HOST="localhost" \
    DB_NAME="counter_db"

EXPOSE 5000

CMD ["python", "app.py"]
