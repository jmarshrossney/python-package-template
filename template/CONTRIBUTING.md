# Contributing

Contributions are welcome.
Please open a Pull Request against the `main` branch.

## Getting started

This project uses [`uv`](https://docs.astral.sh/uv/). 
Install the project and its development dependencies with

```sh
uv sync
```

A [`justfile`](justfile) provides the common tasks. Run the checks and build the docs, without re-exporting the notebooks, with

```sh
uv run just
```

or individually:

| Command | What it does |
|---|---|
| `just lint` | `ruff format`, `marimo check --fix`, `ruff check --fix`, `marimo check --strict` |
| `just lint-check` | Non-mutating variant, used by CI |
| `just check-canonical` | Asserts the example notebooks are in marimo's canonical form |
| `just check-examples` | Runs the example notebooks — the only step that executes cells |
| `just typecheck` | `pyright` |
| `just test` | `pytest` |
| `just test-cov` | `pytest` with coverage, failing under 90% |
| `just doctest` | Run the doctest examples in `src/` |
| `just docs-examples [name...]` | Export the named example notebooks (default all) to `docs/examples/` with their outputs |
| `just docs` | `zensical build`, using the notebooks as last exported |
| `just docs-serve` | The same, with a live-reloading local server |
| `just bump` | Pin the uv hook and `uv_build` to the installed uv, update the ruff and pyright hooks, relock |

The recipes call tools installed in the project's virtual environment, so prefix each command with `uv run`, e.g. `uv run just test`, unless that environment is activated (for example by direnv).

Consider installing [`pre-commit`](https://pre-commit.com/) so that the hooks in [`.pre-commit-config.yaml`](.pre-commit-config.yaml) run before each commit:

```sh
uv tool install pre-commit
pre-commit install
```

## Documentation

The documentation is built with [Zensical](https://zensical.org/) from the Markdown in `docs/`, plus an API reference generated from docstrings by [mkdocstrings](https://mkdocstrings.github.io/).

`docs/examples/` is **generated**: each [marimo](https://marimo.io/) notebook `examples/<name>.py` is exported to `docs/examples/<name>.md`, with cell outputs rendered, by `just docs-examples`.
`just docs` and `just docs-serve` do not re-export, so after editing a notebook run, for example, `just docs-examples notebook`.
Edit the notebook, not the Markdown:

```sh
marimo edit examples/notebook.py
```

Preview the site locally with `just docs-serve`.

## Style

- Ruff enforces formatting and lint; see `[tool.ruff]` in `pyproject.toml`.
- Public functions and classes in `src/` need docstrings, in [Google style](https://google.github.io/styleguide/pyguide.html#38-comments-and-docstrings).
- Type annotations are expected; `pyright` runs over `src/` and `tests/`.
