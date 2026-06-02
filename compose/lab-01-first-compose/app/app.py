import os
import redis
from flask import Flask, jsonify

app = Flask(__name__)

# Redis is reachable by its service name thanks to Compose's built-in DNS
redis_client = redis.Redis(
    host=os.getenv("REDIS_HOST", "redis"),
    port=int(os.getenv("REDIS_PORT", 6379)),
    decode_responses=True,
)


@app.route("/")
def index():
    count = redis_client.incr("visits")
    return jsonify({
        "message": "Hello from Flask + Redis!",
        "visits": count,
    })


@app.route("/health")
def health():
    try:
        redis_client.ping()
        return jsonify({"status": "ok", "redis": "reachable"}), 200
    except redis.exceptions.ConnectionError:
        return jsonify({"status": "error", "redis": "unreachable"}), 503


@app.route("/reset")
def reset():
    redis_client.set("visits", 0)
    return jsonify({"message": "Counter reset to 0"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)