# ADR 0002: The `uv_build` range covers a uv minor, so projects can follow their installed uv

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-11-19 |

Results below were measured with uv 0.13.7.

## Context

The uv version appears in a generated project twice:

- the uv-pre-commit hook's `rev:`, the uv that runs `uv lock` on commit;
- `[build-system] requires = ["uv_build>=…,<…"]`, the backend `uv build` and `uv sync` use.

The hook writes `uv.lock` and the backend reads the project, so the two should name the same uv.
Previously the floor equalled the hook's rev exactly, and both moved only with a template release.

After `uv self update` the local uv runs ahead of both.
Then pre-commit's `uv lock` and your own `uv lock` come from different uv versions and can disagree about `uv.lock`, and the template offered a project no way to catch up.

A project cannot simply set the floor to its installed uv.
`uv self update` usually installs a release younger than a week, and the one-week `exclude-newer` cutoff from [ADR 0001](0001-dependency-floors-cutoff-and-canary.md) applies to `build-system.requires` too, so such a floor fails resolution.

## Decision

1. **The `uv_build` range is the whole minor of the hook's rev:** `>=X.Y.0,<X.(Y+1).0`. `scripts/check_versions.py` and CI enforce this.
2. **Generated projects get `just bump`.** It pins the hook to `uv self version`, writes the matching range, updates the ruff and pyright hooks, relocks, and builds with `uv build --force-pep517` to check that `uv_build` still resolves.
3. **The template's own `just bump` still pins the hook to a release at least a week old**, then writes the same range, so a freshly rendered project resolves on day one.

`scripts/uv_pins.py` and the recipe in `template/justfile.jinja` write the same shape and must agree.

## Reasons

### An `X.Y.0` floor is almost always past the cutoff

The floor no longer moves with each patch release, only with each minor, and a minor's `.0` is more than a week old except during that minor's first week.
So the hook can follow any uv in the minor without the floor breaking resolution.

### The build check needs `--force-pep517`

A uv build normally installs `build-system.requires` into an isolated environment from the index, then calls the backend: the PEP 517 path.
When `build-backend = "uv_build"` and the running uv is inside the range, uv skips that and builds with its own backend, so `uv_build` is never resolved.
The uv running `just bump` is always inside the range it just wrote, so a plain `uv build` cannot fail on the cutoff.

| `exclude-newer` | `uv_build` range | `uv build` | `uv build --force-pep517` |
|---|---|---|---|
| 1 week | `>=0.13.0,<0.14.0` | builds | builds |
| 45 days, before 0.13.0 | `>=0.13.0,<0.14.0` | **builds** | fails: `uv-build` filtered by `exclude-newer` |

The forced build shows what uv versions outside the range see, such as a contributor on an older uv or a CI runner on a newer minor.
pip and `python -m build` also take the PEP 517 path but ignore `[tool.uv]`, so for them the check only proves `uv_build` is installable.

### Projects should not wait for a template release

`copier update` brings template bumps in, but only after a tag, and together with every other template change.
A recipe in the project lets it move when its developer updates uv.

## Alternatives

| Alternative | Why not |
|---|---|
| Floor equal to the hook's rev, lagging a week | A project could never follow a uv younger than a week, which is most of them after `uv self update` |
| Rely on `copier update` | Waits for a template release and brings unrelated changes |
| A floor older than the minor, such as the previous minor's `.0` | Admits a backend older than the hook's uv, which defeats the pairing |
| Check with plain `uv build` | Takes uv's shortcut and never tests the cutoff, as above |

## Consequences

- **First week of a minor:** `just bump` refuses, because `X.Y.0` is younger than the cutoff. Retry a week later.
- **The floor can sit below the hook:** `uv_build` may resolve to any patch in the minor, not exactly the hook's.
- **The shortcut behaviour was measured, not documented:** if uv changes when it builds with its own backend, the table above needs remeasuring.
- **CI lifts the cutoff for the recipe:** the `render` job and `template-check.sh` run `just bump` with `UV_EXCLUDE_NEWER` set to today, so a new uv minor does not fail unrelated PRs. They test that the edits land, not the cutoff check.

## When to revisit

Revisit if uv drops `exclude-newer` from build requirements, which would make an exact floor workable again, or if `uv_build` breaks compatibility within a minor.
