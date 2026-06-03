import os
from flask import Flask, jsonify

app = Flask(__name__)

APP_ENV = os.environ.get("APP_ENV", "unknown")
APP_VERSION = os.environ.get("APP_VERSION", "0.0.0")
DEBUG_MODE = os.environ.get("DEBUG_MODE", "false").lower() == "true"
FEATURE_DARK_MODE = os.environ.get("FEATURE_DARK_MODE", "false").lower() == "true"
FEATURE_ANALYTICS = os.environ.get("FEATURE_ANALYTICS", "false").lower() == "true"
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = os.environ.get("DB_PORT", "5432")
DB_NAME = os.environ.get("DB_NAME", "appdb")


@app.route("/")
def index():
    return jsonify({
        "status": "ok",
        "env": APP_ENV,
        "version": APP_VERSION,
        "debug": DEBUG_MODE,
        "features": {
            "dark_mode": FEATURE_DARK_MODE,
            "analytics": FEATURE_ANALYTICS,
        },
        "database": {
            "host": DB_HOST,
            "port": DB_PORT,
            "name": DB_NAME,
            # Never expose the password — this is intentional
            "password_set": bool(os.environ.get("DB_PASSWORD")),
        },
        "lab": "02-variables"
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy", "env": APP_ENV})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=DEBUG_MODE)