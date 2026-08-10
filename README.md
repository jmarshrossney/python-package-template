# python-package-template

A [Copier](https://copier.readthedocs.io/) template for Python packages.

Its CI generates a project from this template and runs that project's full
suite — lint, typecheck, tests, example notebooks and docs build — so the
configuration here is checked as what you actually receive, not as it looks
sitting in the template.

## Usage

```sh
uvx copier copy --trust gh:jmarshrossney/python-package-template my-project
```

`--trust` is required, and Copier will refuse to run without it: the template
uses post-generation tasks to stamp the copyright year and create `uv.lock`.

Then:

```sh
cd my-project
git init && git add -A && git commit -m "Generated from python-package-template"
just
```

Commit `uv.lock` — the generated CI runs `uv sync --locked`.

Finally, enable Pages under **Settings → Pages → Source: GitHub Actions**.

### Licensing

By default you get an MIT `LICENSE` and `license = "MIT"` in
`pyproject.toml`. MIT is a default, not a recommendation — if it isn't what
you want, pass `--data with_license=false` and add your own;
[choosealicense.com](https://choosealicense.com/) is a reasonable starting
point.

With `with_license=false` no `LICENSE` is written and the `license` field is
set to `LicenseRef-TODO-CHOOSE-A-LICENSE`. That is a valid SPDX expression, so
the package still builds and installs, but it appears verbatim in the built
wheel metadata and on the PyPI page until you replace it. The field is
deliberately never left absent, because a missing license is easy to not
notice and a loud placeholder isn't.

`copyright_holder` fills the `LICENSE` copyright line and the docs footer.

### Questions

| Question | Default | Notes |
|---|---|---|
| `project_name` | — | Distribution name, e.g. `my-package` |
| `package_name` | derived from `project_name` | Import name; must be a valid identifier |
| `project_description` | — | One line |
| `github_owner` | — | User or organisation |
| `author_name` | — | |
| `author_email` | — | |
| `copyright_holder` | `author_name` | LICENSE and docs footer; set this to your employer if they own the work |
| `with_license` | `true` | An MIT LICENSE. False leaves a loud placeholder instead |
| `with_pypi` | `true` | The PyPI publishing workflow |
| `with_cli` | `false` | A Typer entry point, with tests |

Answer non-interactively by passing any of them with `--data`:

```sh
uvx copier copy --trust \
  --data project_name=my-package \
  --data author_name="Your Name" \
  --data author_email=you@example.com \
  gh:jmarshrossney/python-package-template my-project
```

Copier cannot read `git config`, so `author_name` and `author_email` have no
inferred defaults. If you generate projects often, keep your answers in a file
and pass `--data-file`.

### Updating an existing project

Generated projects keep a `.copier-answers.yml`, which records the answers and
the template version. To pull in later template changes:

```sh
copier update --trust
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

`marimo-md-export` is a package of the template author's. It is a normal
published dependency, but if you would rather not depend on it, drop the
`examples/` directory, the `docs`-group entry, and the `docs-examples`,
`check-canonical` and `check-examples` recipes from the `justfile`.

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
  "marimo ↔ ruff interaction" section of the generated `AGENTS.md` for the
  measured reasoning — don't reorder `lint` without reading it.

## Working on the template

See [AGENTS.md](AGENTS.md) and [CONTRIBUTING.md](CONTRIBUTING.md).
