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

```sh
just template-check           # full variant
just template-check minimal   # both feature flags off
just template-check-all       # both
```

This mirrors the `render` job in `.github/workflows/test-template.yml`, rendering to a temp directory outside the repository.
Keep the two in step; a local check that is a subset of CI gives false confidence.

By hand, if you need to poke at the result:

```sh
uvx copier copy --defaults --vcs-ref=HEAD \
  --data project_name=demo-pkg \
  --data project_description="Does a thing." \
  --data github_owner=someone-else \
  --data author_name="Ada Lovelace" \
  --data author_email=ada@example.com \
  . rendered
cd rendered && uv sync --group dev && just
```

`--vcs-ref=HEAD` is essential: without it Copier renders the latest tag, so you silently test the last release instead of your work.
It is also what makes Copier pick up uncommitted changes, hence the dirty-state warning, which is expected.
`rendered/` and `rendered-*/` are gitignored.
Render from `.` rather than an absolute path: Copier records the source in `.copier-answers.yml`, and an absolute path containing the owner's name trips CI's leak check.
Test both `with_pypi`/`with_cli` combinations (both true and both false).
CI also checks that rendered output contains no Jinja delimiters or `python_package_template`.

## Dependency Maintenance

There is no dependency bot here, deliberately.
Most version strings under `template/` need no maintenance: the `[dependency-groups]` bounds are floors, and `uv sync` already resolves past them, so raising one changes nothing for any user.
`[tool.uv] exclude-newer = "1 week"` makes a raised floor actively harmful, because a floor above the version that existed a week ago fails resolution outright.
Leave them alone unless you need a feature.

What does go stale is short, and none of it is weekly:

| Thing | Where | Cadence |
|---|---|---|
| `uv_build` upper bound | `template/pyproject.toml.jinja` `[build-system]` | per uv minor |
| `rev:` pins | `template/.pre-commit-config.yaml` | per release of uv, ruff, pyright |
| Action versions | root and `template/.github/workflows/` | per major |
| `requires-python`, classifiers, `.python-version`, CI matrices | several | per Python release |

### The quarterly bump

```sh
just bump              # updates the revs, re-pins uv, verifies both variants
git commit -am "Bump pinned tool versions"
just release vX.Y      # tags and pushes; nothing reaches users until this runs
```

`just bump` runs `pre-commit autoupdate`, then pins uv itself rather than taking the version autoupdate chose.
`exclude-newer = "1 week"` applies to `build-system.requires` too, so a `uv_build` floor naming a release published in the last week makes every fresh `uv sync` fail until the cutoff catches up.
So `bump` picks the newest `uv-build` on PyPI that is at least a week old, writes it to both the `uv-pre-commit` rev and the `uv_build` range, and says so when that lags the actual latest.
The cap is always one minor above the floor.

It stops before committing, so read the diff.
`just release` refuses a dirty tree, a branch other than `main`, and an existing tag, and re-runs `check-versions` before tagging.

`just check-versions` asserts that uv pairing on its own, and CI runs it.
The ruff and pyright revs are not paired to anything: pre-commit builds those hooks in its own environments, so they are free to sit at latest.

## Releasing

Copier resolves `gh:` shorthand to the latest PEP 440 git tag, not the default branch.
Template changes are invisible to users until a new tag exists.

The template version is unrelated to the generated project's starting version.
Bump the minor when questions are added, renamed, or removed because `copier update` replays those questions and a rename is breaking.

## Copier Constraints

- Aim to keep `_tasks` empty: declaring any makes `--trust` mandatory for every `copy` and `update`, and tasks re-run on update so each would have to be idempotent.
  The copyright year comes from `{{ "%Y" | strftime }}`, an Ansible filter Copier always loads; the generated project has no `uv.lock` until `uv sync` runs.
- When `with_license` is false, keep `license = "LicenseRef-TODO-CHOOSE-A-LICENSE"` valid SPDX so `uv sync` and `uv build` continue to work.
- Copier cannot access `git config`, so `author_name` and `author_email` need explicit answers or `--data` values.
- Jinja itself has no `re`, but the Ansible filters provide `regex_replace` and friends, which is what `package_name` sanitisation uses.
