# AGENTS.md

`python-package-template` is a [Copier](https://copier.readthedocs.io/) template.
The generated project lives under `template/`; there is no package to lint or test at the repository root.

## Templating Rules

- Only add `.jinja` to files that contain Jinja substitutions.
- Files containing GitHub Actions `${{ }}` must remain unsuffixed so Copier does not parse them.
  If such a file needs substitution, wrap every Actions expression in `{% raw %}…{% endraw %}`.
- Watch for accidental `{{` in suffixed files, especially LaTeX in Markdown.
- For feature-dependent files, put the condition in the filename so an empty rendered name omits the file.
  Prefer this to `_exclude`.

## Verification

Render the template, then run the generated project's suite:

```sh
uvx copier copy --defaults \
  --data project_name=demo-pkg \
  --data project_description="Does a thing." \
  --data github_owner=someone-else \
  --data author_name="Ada Lovelace" \
  --data author_email=ada@example.com \
  . rendered
cd rendered && uv sync --group dev && just
```

`rendered/` and `rendered-*/` are gitignored, and Copier's warning about uncommitted changes is expected.
Test both `with_pypi`/`with_cli` combinations (both true and both false).
CI also checks that rendered output contains no Jinja delimiters or `python_package_template`.
The sole permitted `jmarshrossney` occurrence is the real `marimo-md-export` URL in `examples/notebook.py`.

## Releasing

Copier resolves `gh:` shorthand to the latest PEP 440 git tag, not the default branch.
Template changes are invisible to users until a new tag exists.

The template version is unrelated to the generated project's starting version.
Bump the minor when questions are added, renamed, or removed because `copier update` replays those questions and a rename is breaking.

## Copier Constraints

- Keep `_tasks` empty: declaring any makes `--trust` mandatory for every `copy` and `update`, and tasks re-run on update so each would have to be idempotent.
  The copyright year comes from `{{ "%Y" | strftime }}`, an Ansible filter Copier always loads; the generated project has no `uv.lock` until `uv sync` runs.
- When `with_license` is false, keep `license = "LicenseRef-TODO-CHOOSE-A-LICENSE"` valid SPDX so `uv sync` and `uv build` continue to work.
- Copier cannot access `git config`, so `author_name` and `author_email` need explicit answers or `--data` values.
- Jinja has no `re`; keep `package_name` sanitisation as chained `.replace()` calls with `.isidentifier()` validation.
