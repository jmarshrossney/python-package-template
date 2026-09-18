#!/usr/bin/env bash
# Tag a release and push it.
#
# Usage: scripts/release.sh vX.Y
#
# Copier resolves `gh:` shorthand to the latest PEP 440 tag, so template
# changes reach nobody until this runs.
set -euo pipefail

version="${1:-}"
if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "version must look like v1.2 or v1.2.3, got '$version'" >&2
    exit 2
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "working tree is dirty; commit first" >&2
    exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$branch" != "main" ]; then
    echo "on '$branch', not main: Copier resolves gh: shorthand to the latest" >&2
    echo "tag, so a tag off main would ship that branch to users." >&2
    exit 1
fi

if git rev-parse -q --verify "refs/tags/$version" >/dev/null; then
    echo "tag $version already exists" >&2
    exit 1
fi

python3 "$root/scripts/check_versions.py"
git tag -a "$version" -m "$version"
git push origin "$version"
echo "pushed $version"
