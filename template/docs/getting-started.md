# Getting started

## Installation

Install from PyPI:

```sh
pip install python-package-template
```

Or, if you use [uv](https://docs.astral.sh/uv/), add it to a project:

```sh
uv add python-package-template
```

## First steps

The package exposes a single function:

```python
from python_package_template import greet

print(greet())  # Hello, world!
print(greet("reader"))  # Hello, reader!
```

That's the whole interface. Replace this page with something useful once the
package does something useful.

## Maths

KaTeX is wired up, so inline maths like $e^{i\pi} = -1$ and display maths

$$
\int_{-\infty}^{\infty} e^{-x^{2}} \, \mathrm{d}x = \sqrt{\pi}
$$

both render. This section exists so the template's own docs build exercises
the KaTeX configuration; delete it (and see `zensical.toml`) if the package's
documentation has no maths in it.
