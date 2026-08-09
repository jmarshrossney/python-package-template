"""A template for Python packages.

Replace this module with your own. The point of the placeholder is to give the
template a real public API, so that the linter, the type checker, the test
suite and the API reference all have something to act on.
"""

__all__ = ["greet"]


def greet(name: str = "world") -> str:
    """Build a friendly greeting.

    Args:
        name: Who to greet.

    Returns:
        The greeting.

    Examples:
        >>> greet()
        'Hello, world!'
        >>> greet("template")
        'Hello, template!'
    """
    return f"Hello, {name}!"
