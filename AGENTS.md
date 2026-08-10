# AGENTS.md

## Project overview

`python-package-template` is a [Copier](https://copier.readthedocs.io/) template
for Python packages. This repository is **not** itself a Python package: there
is no `pyproject.toml`, no `src/` and no virtualenv at the root. Everything
under `template/` is a Jinja template of the project that Copier generates.

## Layout

```
copier.yml                  — questions, tasks, post-copy message
template/                   — the generated project (Copier `_subdirectory`)
.github/workflows/
  test-template.yml         — renders the template, then runs the rendered
                              project's own suite and publishes its docs
```

## The two suffix rules

**1. Files containing GitHub Actions `${{ }}` never get a `.jinja` suffix.**
Jinja's `{{ }}` would consume the Actions expressions. None of the three
workflows under `template/.github/workflows/` needs any substitution, so all
three are unsuffixed and copy verbatim. If one ever does need substitution,
wrap every Actions expression in `{% raw %}…{% endraw %}` first.

**2. Only suffix files that actually need substitution.** Everything else
copies verbatim, which keeps `git diff` against the generated output readable.
`CONTRIBUTING.md`, `.pre-commit-config.yaml`, `.python-version`, `.gitignore`
and `docs/_static/js/katex.js` contain no placeholders and are unsuffixed.

Watch for accidental `{{` in suffixed files. The likeliest source is LaTeX in
Markdown — `docs/getting-started.md.jinja` contains maths, and something like
`\frac{{a}}{{b}}` would be parsed as a Jinja expression. Single braces are fine.

## Conditional files

A file whose rendered *name* is empty is not created, so the condition lives in
the filename:

```
template/.github/workflows/{% if with_pypi %}publish.yml{% endif %}
template/src/{{ package_name }}/{% if with_cli %}cli.py{% endif %}.jinja
template/{% if license == 'MIT' %}LICENSE{% endif %}.jinja
```

This works with and without the `.jinja` suffix. The three `LICENSE` variants
are mutually exclusive, so at most one is ever created. Prefer this to
`_exclude`: the condition stays next to the file it governs.

## Working on the template

There is nothing to lint or test at the root. The loop is render, then run the
generated project's suite:

```sh
uvx copier copy --defaults --trust \
  --data project_name=demo-pkg \
  --data project_description="Does a thing." \
  --data github_owner=someone-else \
  --data author_name="Ada Lovelace" \
  --data author_email=ada@example.com \
  . rendered
cd rendered && uv sync --group dev && just
```

`rendered/` and `rendered-*/` are gitignored. Copier renders from git `HEAD`,
warning that uncommitted changes are included — that warning is expected while
iterating.

Test both feature combinations before pushing: `with_pypi`/`with_cli` both true
and both false. CI does this, and additionally asserts that no `@YEAR@`, Jinja
delimiter, or `python_package_template` survives into the rendered output.

The one permitted occurrence of `jmarshrossney` in rendered output is the
`marimo-md-export` URL in `examples/notebook.py` — a real third-party link. CI
allows exactly that one and fails on any other, because rewriting it to a
nonexistent URL is precisely the bug the old `bootstrap.py` had.

## Releasing

Copier resolves `gh:` shorthand to the latest PEP 440 git tag, **not** to the
default branch. Template changes are invisible to users until a new tag exists:

```sh
git tag v1.1.0 && git push --tags
```

## Things that do not work in Copier

- **No date function**, and question defaults cannot shell out, so the
  copyright year cannot be rendered. It is stamped by a post-copy task in
  `copier.yml`, which replaces a literal `@YEAR@`.
- **No `git config` access**, so `author_name` and `author_email` have no
  inferred defaults and must be answered or passed with `--data`.
- **Jinja has no `re`**, so `package_name`'s default sanitises via chained
  `.replace()` and a `validator` enforces `.isidentifier()`.
