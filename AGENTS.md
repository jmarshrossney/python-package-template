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
just template-check           # full variant: release=pypi, all flags on
just template-check github    # release=github, all flags on
just template-check minimal   # release=none, all flags off
just template-check-all       # all three
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
cd rendered && uv sync --group dev && uv run just
```

`--vcs-ref=HEAD` is essential: without it Copier renders the latest tag, so you silently test the last release instead of your work.
It is also what makes Copier pick up uncommitted changes, hence the dirty-state warning, which is expected.
`rendered/` and `rendered-*/` are gitignored.
Render from `.` rather than an absolute path: Copier records the source in `.copier-answers.yml`, and an absolute path containing the owner's name trips CI's leak check.
Test all three `release` values; `just template-check-all` pairs them with the feature flags as CI does.
CI also checks that rendered output contains no Jinja delimiters or `python_package_template`.

### Testing `copier update`

Needed when a change touches questions or answers, since `copier update` is how existing projects receive it.
CI does not cover it.

```sh
just template-update-check                        # latest tag, default answers
just template-update-check --data release=github  # old answers whose handling changed
```

It renders the latest tag, updates it to the working tree, and prints the diff, including `.copier-answers.yml`.
The scratch project is kept for inspection; `scripts/template-update-check.sh` explains each step.

## Dependency Maintenance

There is no dependency bot, deliberately; see [ADR 0001](docs/adr/0001-dependency-floors-cutoff-and-canary.md).
Leave the `[dependency-groups]` floors alone unless you need a feature, and never raise one above the version that existed a week ago.

What does go stale is short, and none of it is weekly:

| Thing | Where | Cadence |
|---|---|---|
| `uv_build` range | `template/pyproject.toml.jinja` `[build-system]` | per uv minor |
| `rev:` pins | `template/.pre-commit-config.yaml` | per release of uv, ruff, pyright |
| Action versions | root and `template/.github/workflows/` | per major |
| `requires-python`, classifiers, `.python-version`, CI matrices | several | per Python release |

### Version bump

```sh
just bump              # updates the revs, re-pins uv, verifies the full and minimal variants
git commit -am "Bump pinned tool versions"
just release X.Y       # tags and pushes; nothing reaches users until this runs
```

To be done by the user only!

The `uv_build` range is always the whole minor of the uv-pre-commit rev, `>=X.Y.0,<X.(Y+1).0`; `scripts/uv_pins.py` and the generated `just bump` in `template/justfile.jinja` must agree.
See [ADR 0002](docs/adr/0002-uv-build-range-follows-installed-uv.md).

## Releasing

Copier resolves `gh:` shorthand to the latest PEP 440 git tag, not the default branch.
Template changes are invisible to users until a new tag exists.

The template version is unrelated to the generated project's starting version.
Bump the minor when questions are added, renamed, or removed because `copier update` replays those questions and a rename is breaking.

## Decisions

Design decisions too large for a commit message are in `docs/adr/`.
Read the relevant one before changing what it covers, and add one rather than growing this file.

## Copier Constraints

- Aim to keep `_tasks` empty: declaring any makes `--trust` mandatory for every `copy` and `update`, and tasks re-run on update so each would have to be idempotent.
  The copyright year comes from `{{ "%Y" | strftime }}`, an Ansible filter Copier always loads; the generated project has no `uv.lock` until `uv sync` runs.
- When `with_license` is false, keep `license = "LicenseRef-TODO-CHOOSE-A-LICENSE"` valid SPDX so `uv sync` and `uv build` continue to work.
- Copier cannot access `git config`, so `author_name` and `author_email` need explicit answers or `--data` values.
- Jinja itself has no `re`, but the Ansible filters provide `regex_replace` and friends, which is what `package_name` sanitisation uses.
