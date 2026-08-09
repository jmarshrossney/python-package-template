import pytest

from python_package_template import greet


def test_greet_default():
    assert greet() == "Hello, world!"


@pytest.mark.parametrize("name", ["template", "Joe", ""])
def test_greet_name(name):
    assert greet(name) == f"Hello, {name}!"
