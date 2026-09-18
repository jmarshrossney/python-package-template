#!/usr/bin/env bash
# The quarterly bump: update the pinned tool versions and verify the result.
#
# Updates the pre-commit revs, re-pins uv to a version the generated project's
# cutoff actually allows, then renders and tests both variants. Stops before
# committing, and does not tag: `just release vX.Y` does that.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scripts="$root/scripts"
cd "$root"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "working tree is dirty; commit or stash first" >&2
    exit 1
fi

echo "==> pre-commit autoupdate"
uvx pre-commit autoupdate -c template/.pre-commit-config.yaml

echo
echo "==> pinning uv to the newest release the cutoff allows"
python3 "$scripts/pin_uv.py"

echo
python3 "$scripts/check_versions.py"

echo
echo "==> what changed"
if git diff --quiet; then
    echo "nothing to bump; everything is already current"
    exit 0
fi
git --no-pager diff --stat
git --no-pager diff

echo
echo "==> verifying both variants"
"$scripts/template-check.sh" full
"$scripts/template-check.sh" minimal

echo
echo "Bump verified. Next:"
echo "  git commit -am 'Bump pinned tool versions'"
echo "  just release vX.Y"
