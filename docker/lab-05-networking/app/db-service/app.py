from flask import Flask, jsonify

app = Flask(__name__)

RECORDS = [
    {"id": 1, "value": "record-alpha"},
    {"id": 2, "value": "record-beta"},
    {"id": 3, "value": "record-gamma"},
]

@app.route("/")
def home():
    return jsonify({"service": "db-service", "status": "ok"})

@app.route("/records")
def get_records():
    return jsonify(RECORDS)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=6000)