FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Default port — can be overridden via EXPOSE is informational only
EXPOSE 5000

CMD ["python", "main.py"]