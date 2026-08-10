# python-package-template

A [Copier](https://copier.readthedocs.io/) template for Python packages.

Its CI generates a project from this template and runs that project's full suite.

> [!NOTE]
> This template is primarily for my own personal use.
> I've made it public so feel free to use it, fork it, adapt it etc., but I'm not really interested in taking contributions.

## Usage

```sh
uvx copier copy gh:jmarshrossney/python-package-template my-project
```

Then:

```sh
cd my-project
uv sync --group dev
just
git init && git add -A && git commit -m "Generated from python-package-template"
```

Finally, enable Pages under **Settings → Pages → Source: GitHub Actions**.

### Licensing

By default you get an MIT `LICENSE` and `license = "MIT"` in `pyproject.toml`.
If this isn't what you want, pass `--data with_license=false` and add your own; [choosealicense.com](https://choosealicense.com/) is a reasonable starting point.

With `with_license=false` no `LICENSE` is written and the `license` field is set to `LicenseRef-TODO-CHOOSE-A-LICENSE`. 

### Questions

| Question | Default | Notes |
|---|---|---|
| `project_name` | — | Distribution name, e.g. `my-package` |
| `package_name` | derived from `project_name` | Import name; must be a valid identifier |
| `project_description` | — | One line |
| `github_owner` | — | User or organisation |
| `author_name` | — | |
| `author_email` | — | |
| `copyright_holder` | `author_name` | LICENSE and docs footer |
| `with_license` | `true` | An MIT LICENSE. False leaves a loud placeholder instead |
| `with_pypi` | `true` | The PyPI publishing workflow |
| `with_cli` | `false` | A Typer entry point, with tests |

Answer non-interactively by passing any of them with `--data`:

```sh
uvx copier copy \
  --data project_name=my-package \
  --data author_name="Your Name" \
  --data author_email=you@example.com \
  gh:jmarshrossney/python-package-template my-project
```

Copier cannot read `git config`, so we cannot infer defaults for `author_name` and `author_email`.
If you generate projects often, keep your answers in a file and pass `--data-file`.

### Updating an existing project

Generated projects keep a `.copier-answers.yml`, which records the answers and the template version.
To pull in later template changes:

```sh
copier update
```

## What's in the generated project

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


