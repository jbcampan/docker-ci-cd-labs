"""Minimal Flask app — security-lab-01 container.

Routes
------
GET /        → {"service": "security-lab-01", "status": "ok"}
GET /health  → {"status": "healthy"}
"""

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    return jsonify({"service": "security-lab-01", "status": "ok"})


@app.route("/health")
def health():
    return jsonify({"status": "healthy"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)