#!/usr/bin/env bash
# Render the template and run the generated project's suite.
#
# Usage: scripts/template-check.sh [full|minimal]
#
# Mirrors the `render` job in .github/workflows/test-template.yml. When that
# workflow changes, change this too: a local check that is a subset of CI gives
# false confidence.
set -euo pipefail

variant="${1:-full}"
if [ "$variant" != "full" ] && [ "$variant" != "minimal" ]; then
    echo "variant must be 'full' or 'minimal', got '$variant'" >&2
    exit 2
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Renders outside the repository: the generated project's `check-canonical`
# runs `git diff --exit-code examples/`, which from a nested render would walk
# up to this repository and pass vacuously.
dst="$(mktemp -d)"
trap 'rm -rf "$dst"' EXIT

if [ "$variant" = "full" ]; then
    flags=(--data with_pypi=true --data with_cli=true --data with_license=true)
else
    flags=(--data with_pypi=false --data with_cli=false --data with_license=false)
fi

# Rendered from `.` inside the repository, exactly as CI does, not from an
# absolute path: Copier records the source in .copier-answers.yml, and an
# absolute path would trip the owner-leak check below on any machine whose home
# directory happens to contain the owner's name.
cd "$root"

# --vcs-ref=HEAD tests the working tree rather than the last release. The
# dirty-state warning Copier prints is expected.
uvx copier copy --defaults --vcs-ref=HEAD \
    --data project_name=demo-pkg \
    --data project_description="Does a thing." \
    --data github_owner=someone-else \
    --data author_name="Ada Lovelace" \
    --data author_email=ada@example.com \
    "${flags[@]}" \
    . "$dst/rendered"

cd "$dst/rendered"

# The same three assertions CI makes. See the workflow for why each exclusion
# is there; the marimo-md-export URL is a real third-party link.
fail=0
if grep -rnP '(?<!\$)\{\{|\{%' . --exclude-dir=.git --exclude=uv.lock; then
    echo "error: unrendered Jinja delimiters in generated project" >&2
    fail=1
fi
if grep -rn 'python_package_template\|python-package-template' . \
    --exclude-dir=.git --exclude=uv.lock --exclude=.copier-answers.yml; then
    echo "error: template name leaked into generated project" >&2
    fail=1
fi
if grep -rn 'jmarshrossney' . --exclude-dir=.git --exclude=uv.lock \
    | grep -v 'jmarshrossney/marimo-md-export'; then
    echo "error: template owner leaked into generated project" >&2
    fail=1
fi

if [ "$variant" = "full" ]; then
    test -f .github/workflows/publish.yml
    test -f src/demo_pkg/cli.py
    test -f tests/test_cli.py
    test -f LICENSE
    grep -q '^license = "MIT"$' pyproject.toml
else
    test ! -e .github/workflows/publish.yml
    test ! -e src/demo_pkg/cli.py
    test ! -e tests/test_cli.py
    test ! -e LICENSE
    grep -q '^license = "LicenseRef-TODO-CHOOSE-A-LICENSE"$' pyproject.toml
fi

[ "$fail" -eq 0 ] || exit 1

# check-canonical diffs the working tree, so it needs to be a repo. Not
# `uv sync --locked`: a fresh render has no uv.lock, this call writes it.
git init -q .
git add -A
uv sync --group dev
uv run just lint-check
uv run just check-canonical
uv run just typecheck
uv run just test-cov
uv run just check-examples
uv build
