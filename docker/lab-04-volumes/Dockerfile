FROM python:3.11-slim

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

# The /data directory will contain the SQLite database and will be mounted as a volume
VOLUME ["/data"]

EXPOSE 5000

CMD ["python", "app.py"]