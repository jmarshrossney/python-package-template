# python-package-template

A GitHub template repository for Python packages.

Unlike a cookiecutter template, this repo *is* a working package: its own CI
runs `just lint-check`, `just typecheck`, `just test-cov` and `just docs` on
every push, so the configuration here cannot silently rot.

## What's in it

| Tool | Role | Config |
|---|---|---|
| [uv](https://docs.astral.sh/uv/) | Packaging, environments, locking, publishing | `pyproject.toml`, `uv.lock` |
| [just](https://just.systems/) | Task runner | `justfile` |
| [ruff](https://docs.astral.sh/ruff/) | Format + lint | `[tool.ruff]` |
| [pyright](https://github.com/microsoft/pyright) | Static type checking | `[tool.pyright]` |
| [pytest](https://pytest.org/) | Tests, coverage | `[tool.pytest]` |
| [zensical](https://zensical.org/) | Documentation site | `zensical.toml` |
| [mkdocstrings](https://mkdocstrings.github.io/) | API reference from docstrings | `zensical.toml` |
| [marimo](https://marimo.io/) + [marimo-md-export](https://github.com/jmarshrossney/marimo-md-export) | Executable example notebooks in the docs | `examples/` |
| [pre-commit](https://pre-commit.com/) | uv-lock, ruff, pyright on commit | `.pre-commit-config.yaml` |
| GitHub Actions | CI, Pages deploy, PyPI publish | `.github/workflows/` |

## Usage

1. Click **Use this template** → **Create a new repository**.
2. Clone it, then run the one-off rename:

   ```sh
   uv run bootstrap.py
   ```

   It's a [PEP 723](https://peps.python.org/pep-0723/) script, so uv installs
   its own dependencies — no `uv sync` needed first. It infers the project name
   and owner from the git remote, prompts for anything missing, rewrites every
   reference to the template across the tracked files, renames
   `src/python_package_template/`, replaces this README, and then deletes
   itself. Pass `--name`/`--owner`/`--description`/`--package` to skip the
   prompts, `--yes` to skip confirmation, and `--dry-run` to see what it would
   touch.

3. `uv sync` to build the environment and regenerate `uv.lock` under the new
   name, then `just` to check everything passes.
4. Enable Pages: **Settings → Pages → Source: GitHub Actions**.
5. To publish to PyPI, create `pypi` and `testpypi` environments in the repo
   settings and register a pending trusted publisher on each index. See the
   header comment in `.github/workflows/publish.yml`. Delete that workflow if
   the package isn't going to PyPI.

## Commands

```
just                  # lint, typecheck, test, check-examples, docs
just lint             # ruff format, marimo check --fix, ruff check --fix, marimo --strict
just lint-check       # non-mutating variant, used by CI
just check-canonical  # assert the notebooks are in marimo's canonical form
just check-examples   # actually execute the example notebooks
just typecheck        # pyright
just test             # pytest
just test-cov         # pytest with coverage, fails under 90%
just doctest          # run the doctest examples in src/
just docs             # export example notebooks, then zensical build
just docs-serve       # the same, with a live-reloading local server
```

## Deliberate choices

- **Explicit `ruff` `select`.** Ruff 0.16 broadened its default rule set; the
  template selects rules explicitly so a version bump can't change what's
  enforced. Docstrings (`D`, google convention) are required in `src/`, and
  exempted in `tests/` and `examples/`.
- **`exclude-newer = "1 week"`** in `[tool.uv]`, so a release published today
  can't break a fresh `uv sync`. Override per package with
  `exclude-newer-package`.
- **`just` comes from the `dev` group** (`rust-just`), so `ci.yml` doesn't need
  `extractions/setup-just`. `docs.yml` does, because the `docs` group omits it.
- **Docs build on PRs too**, without deploying, so broken docs fail before
  merge rather than after.
- **Generated docs are gitignored.** `docs/example.md` and `docs/figures/` are
  built from `examples/notebook.py` by `just docs`; the notebook is the source.
- **The marimo lint order is load-bearing.** `marimo check --fix` runs before
  `ruff check --fix`, every `marimo check` passes `--strict`, and two extra
  gates exist (`check-canonical`, `check-examples`) because neither linting nor
  the docs export catches a notebook that has drifted or that raises. See the
  "marimo ↔ ruff interaction" section of [AGENTS.md](AGENTS.md) for the
  measured reasoning — don't reorder `lint` without reading it.
