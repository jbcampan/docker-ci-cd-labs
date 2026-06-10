"""Unit tests for the calculator module."""

import pytest

from app.calculator import add, divide, multiply, subtract


class TestAdd:
    def test_positive_numbers(self):
        assert add(2, 3) == 5

    def test_negative_numbers(self):
        assert add(-1, -4) == -5

    def test_mixed_sign(self):
        assert add(-1, 3) == 2

    def test_floats(self):
        assert add(0.1, 0.2) == pytest.approx(0.3)


class TestSubtract:
    def test_basic(self):
        assert subtract(10, 4) == 6

    def test_result_negative(self):
        assert subtract(3, 7) == -4


class TestMultiply:
    def test_basic(self):
        assert multiply(3, 4) == 12

    def test_by_zero(self):
        assert multiply(99, 0) == 0

    def test_floats(self):
        assert multiply(2.5, 4) == pytest.approx(10.0)


class TestDivide:
    def test_basic(self):
        assert divide(10, 2) == 5

    def test_float_result(self):
        assert divide(7, 2) == pytest.approx(3.5)

    def test_divide_by_zero_raises(self):
        with pytest.raises(ValueError, match="Cannot divide by zero"):
            divide(5, 0)
