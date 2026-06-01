from flask import Flask, jsonify
import requests
import os

app = Flask(__name__)

# The service name "db-service" is automatically resolved by Docker DNS
DB_SERVICE_URL = os.getenv("DB_SERVICE_URL", "http://db-service:6000")

@app.route("/")
def home():
    return jsonify({"service": "api", "status": "ok"})

@app.route("/data")
def get_data():
    try:
        response = requests.get(f"{DB_SERVICE_URL}/records", timeout=3)
        return jsonify({
            "source": "db-service",
            "data": response.json()
        })
    except requests.exceptions.ConnectionError:
        return jsonify({"error": "Cannot reach db-service"}), 503

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)