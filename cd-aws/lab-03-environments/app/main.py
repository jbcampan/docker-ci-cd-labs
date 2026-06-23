"""
Minimal Flask application for ECS deployment lab.

Exposes:
  GET /        → welcome message with version info
  GET /health  → ALB health-check endpoint (must return 200)
  GET /env     → shows non-sensitive runtime environment metadata
"""

import os
from flask import Flask, jsonify

app = Flask(__name__)

APP_VERSION = os.getenv("APP_VERSION", "0.0.0")
ENVIRONMENT = os.getenv("ENVIRONMENT", "unknown")


@app.route("/")
def index():
    return jsonify(
        {
            "message": "Hello from ECS Fargate!",
            "version": APP_VERSION,
            "environment": ENVIRONMENT,
        }
    )


@app.route("/health")
def health():
    """
    ALB health-check target.
    Must return HTTP 200 within the configured timeout, or the target is marked
    unhealthy and the task is drained and replaced.
    """
    return jsonify({"status": "healthy", "version": APP_VERSION}), 200


@app.route("/env")
def env():
    """Expose non-sensitive runtime metadata useful for debugging deployments."""
    return jsonify(
        {
            "APP_VERSION": APP_VERSION,
            "ENVIRONMENT": ENVIRONMENT,
            "AWS_DEFAULT_REGION": os.getenv("AWS_DEFAULT_REGION", "not-set"),
        }
    )


if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
