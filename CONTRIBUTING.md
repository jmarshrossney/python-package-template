# Contributing

Contributions are welcome. Please open a Pull Request against the `main` branch.

This repository is a Copier template, not a Python package — there is nothing
to install at the root, and no tests that run here. Changes are checked by
generating a project and running *that* project's suite.

## Making a change

Edit the files under `template/`, then render and check:

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

Render both feature combinations — `with_pypi` and `with_cli` both true and
both false — since each adds and removes files. CI does the same, and also
checks that no Jinja delimiters, `@YEAR@` placeholders or references to the
template itself survive into the generated project.

`rendered/` and `rendered-*/` are gitignored.

## Before you open a PR

- [`AGENTS.md`](AGENTS.md) documents the rules that govern which files carry a
  `.jinja` suffix and how conditional files work. Read it before adding files.
- If you add a question to `copier.yml`, add it to the table in
  [`README.md`](README.md) too.
- If you change what the generated project contains, check the generated
  `README.md` and `AGENTS.md` still describe it accurately.

## Releasing

Copier resolves `gh:` shorthand to the latest git tag, so template changes only
reach users once a new tag is pushed. Maintainers: tag after merging.
