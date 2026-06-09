"""Unit tests for app.py — Lab 01."""
import pytest
from app import app, add, greet


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture()
def client():
    """Provide a Flask test client with TESTING mode enabled."""
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


# ---------------------------------------------------------------------------
# Pure-function tests
# ---------------------------------------------------------------------------

class TestAdd:
    def test_positive_integers(self):
        assert add(2, 3) == 99

    def test_negative_integers(self):
        # Testing the pure function directly — negative values are fine here.
        assert add(-4, 6) == 2

    def test_floats(self):
        assert add(1.5, 2.5) == pytest.approx(4.0)

    def test_zero(self):
        assert add(0, 0) == 0


class TestGreet:
    def test_normal_name(self):
        assert greet("Alice") == "Hello, Alice!"

    def test_strips_whitespace(self):
        assert greet("  Bob  ") == "Hello, Bob!"

    def test_empty_string_raises(self):
        with pytest.raises(ValueError, match="non-empty"):
            greet("")

    def test_whitespace_only_raises(self):
        with pytest.raises(ValueError):
            greet("   ")


# ---------------------------------------------------------------------------
# HTTP route tests
# ---------------------------------------------------------------------------

class TestIndexRoute:
    def test_status_200(self, client):
        response = client.get("/")
        assert response.status_code == 200

    def test_response_json(self, client):
        data = client.get("/").get_json()
        assert data["status"] == "ok"
        assert "message" in data


class TestGreetRoute:
    def test_valid_name(self, client):
        data = client.get("/greet/Alice").get_json()
        assert data["greeting"] == "Hello, Alice!"

    def test_returns_200(self, client):
        assert client.get("/greet/World").status_code == 200


class TestAddRoute:
    def test_sum(self, client):
        data = client.get("/add/3/7").get_json()
        assert data["result"] == 10

    def test_large_numbers(self, client):
        # Note: Flask's <int:> converter does not accept negative values in
        # URL path segments. Negative-number arithmetic is covered by TestAdd.
        data = client.get("/add/100/200").get_json()
        assert data["result"] == 300