# ADR 0001: Dependency floors, a one-week cutoff and a canary, not a bot

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-09-18, recorded 2026-11-19 |
| **Discussion** | Commit `c0844c4` |

## Context

A generated project names dependency versions in several places: `[dependency-groups]` bounds, pre-commit `rev:` pins, the `uv_build` requirement, Action versions and Python versions.
The usual answer is a bot that opens a PR whenever any of them falls behind.

Two features of the template change what that would buy:

- `uv sync` resolves each dependency to the newest version its bound allows, so a bound that looks stale does not make anyone's environment stale.
- `[tool.uv] exclude-newer = "1 week"` resolves against the index as it was a week ago, so a broken same-day release cannot break a fresh `uv sync`.

What actually hurts users is a release that breaks the generated project, and nothing detected that before a user hit it.

## Decision

1. **`[dependency-groups]` bounds are floors, kept low.** They are raised only to reach a feature the template needs.
2. **Generated projects resolve with `exclude-newer = "1 week"`.** `exclude-newer-package` exempts the few dependencies worth picking up the day they land.
3. **A weekly `canary` job renders the template with the cutoff lifted** (`UV_EXCLUDE_NEWER` set to today) and runs the generated suite. It is `continue-on-error`, and its step summary lists what resolved.
4. **Everything else is bumped by hand with `just bump`.** That is the short list in `AGENTS.md`, none of it weekly.

## Reasons

### Raising a floor changes nothing, or breaks resolution

A floor at or below the version that existed a week ago changes no one's environment, because resolution already goes past it.
A floor above it fails resolution outright, because the cutoff hides every version that would satisfy it.
A bot raising floors to the newest release therefore produces PRs that are either no-ops or failures.

### The canary sees breakage a week before users

Users resolve against last week's index, while the canary resolves against today's.
A release that breaks the generated project turns the canary red about a week before it reaches any `uv sync`.
Red means "something shipped that breaks generated projects", which is information, not a broken branch, so nothing depends on the job.

### Nothing reaches users until a tag

Copier renders the latest tag, so a merged bump is invisible to users until `just release`.
A bot's weekly PRs would end at that step anyway, and the tag is the step that is easy to forget.

## Alternatives

| Alternative | Why not |
|---|---|
| Dependabot or Renovate on `template/` | Floor bumps are no-ops or failures, as above. The remaining pins change monthly at most, and nothing ships without a tag |
| Pin exact versions and bump them weekly | Pins in a template become every generated project's pins, and go stale there with no bot to move them |
| No cutoff | A broken same-day release breaks every fresh `uv sync` |

## Consequences

- **Floors look old:** they trail the latest releases by design, and the comment above `[dependency-groups]` says so, to stop well-meant "freshening".
- **Raising a floor needs care:** it must name a version at least a week old.
- **Some pins still go stale:** pre-commit revs, the `uv_build` range, Action versions and Python versions need `just bump` or a hand edit.
  [ADR 0002](0002-uv-build-range-follows-installed-uv.md) lets generated projects move the uv-related ones themselves.
- **The canary needs reading:** a red run is only useful if someone looks at it.

## When to revisit

Reconsider a bot if the hand-maintained list grows past a few items, or if their cadence becomes weekly.
