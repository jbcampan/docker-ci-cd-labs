from flask import Flask, jsonify

app = Flask(__name__)


def add(a: int | float, b: int | float) -> int | float:
    """Return the sum of a and b."""
    return a + b


def greet(name: str) -> str:
    """Return a greeting string for the given name."""
    if not name or not name.strip():
        raise ValueError("Name must be a non-empty string")
    return f"Hello, {name.strip()}!"


@app.route("/")
def index():
    return jsonify({"message": "Hello from Lab 01!", "status": "ok"})


@app.route("/greet/<name>")
def greet_route(name: str):
    try:
        return jsonify({"greeting": greet(name)})
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400


@app.route("/add/<int:a>/<int:b>")
def add_route(a: int, b: int):
    return jsonify({"result": add(a, b)})


if __name__ == "__main__":  # pragma: no cover
    app.run(host="0.0.0.0", port=5000)