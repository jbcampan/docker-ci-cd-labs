import sqlite3
import os
from flask import Flask, request, jsonify

app = Flask(__name__)
DB_PATH = os.getenv("DB_PATH", "/data/app.db")

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    with get_db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS notes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                content TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

@app.route("/notes", methods=["GET"])
def get_notes():
    with get_db() as conn:
        notes = conn.execute("SELECT * FROM notes").fetchall()
    return jsonify([dict(n) for n in notes])

@app.route("/notes", methods=["POST"])
def add_note():
    content = request.json.get("content", "")
    with get_db() as conn:
        conn.execute("INSERT INTO notes (content) VALUES (?)", (content,))
    return jsonify({"status": "created"}), 201

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000, debug=True)