# AGENTS.md

## Project overview

`python-package-template` is a GitHub template repository for Python packages.
It is also a real, working (if trivial) package, so that its own CI exercises every config it ships.

## Source layout

```
src/python_package_template/
  __init__.py      — public API (placeholder: `greet`)
tests/             — one test file per module
examples/          — marimo notebooks, exported into docs/ by `just docs`
docs/              — hand-written Markdown + generated example.md
bootstrap.py       — one-off template rename (PEP 723 script; deletes itself)
site/              — built documentation output (gitignored)
```

## Commands

All via `just`; prefix with `uv run` if `just` isn't on the PATH.

| Command | What it does |
|---|---|
| `just` | lint → typecheck → test → check-examples → docs, in order |
| `just lint` | `ruff format` + `marimo check --fix` + `ruff check --fix` + `marimo check --strict` |
| `just lint-check` | Non-mutating variant for CI |
| `just check-canonical` | Applies `marimo check --fix` and asserts the tree is clean |
| `just check-examples` | `python examples/notebook.py` — the only gate that executes cells |
| `just typecheck` | `pyright` |
| `just test` | `pytest` |
| `just test-cov` | `pytest` with coverage, `--cov-fail-under=90` |
| `just doctest` | Doctests in `src/` |
| `just docs` | Export notebooks, then `zensical build` |

Setup: `uv sync`.

## Toolchain

uv (packaging), just (tasks), ruff (format + lint), pyright (types), pytest (tests), zensical + mkdocstrings (docs), marimo + marimo-md-export (example notebooks), pre-commit, GitHub Actions.

## Conventions

- Ruff `select` is explicit, never left to defaults — see the comment in `pyproject.toml`.
- Docstrings are required in `src/` (google convention) and exempt in `tests/` and `examples/`.
- `docs/example.md` and `docs/figures/` are **generated**; edit `examples/notebook.py` instead.
- Tool versions are pinned in three places that must stay in step: `[dependency-groups] dev`, `.pre-commit-config.yaml` revs, and the `uv_build` bound in `[build-system]`.

## marimo ↔ ruff interaction (do not reorder `lint`)

Verified against marimo 0.23.16 / ruff 0.16.1:

- `marimo check --fix` must run **before** `ruff check --fix`. It prunes cell
  return tuples, which can strand an import; ruff then reports the `F401`. The
  reverse order needs two passes to reach a fixed point.
- `marimo check` **without `--strict` exits 0** on runtime, formatting and WASM
  findings — only a broken dependency graph fails it. Always pass `--strict`.
- Plain `marimo check` reports *nothing* about non-canonical cell signatures, in
  either mode. `check-canonical` is the only gate for that.
- `marimo-md-export` prints an error but **exits 0** and still writes the
  markdown when a cell raises, so `just docs` is not an execution gate.
  `check-examples` is.
- Never enable `PLR1711` for `examples/` — ruff deletes the bare `return`
  ending each cell and `marimo check --fix` re-adds it, forever. Likewise
  `E501`: a `# noqa` after the closing `"""` oscillates on whitespace.
