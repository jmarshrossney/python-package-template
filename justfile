# This is the *template repository's* justfile, for maintaining the template.

_default:
    @just --list

# Render the template and run the generated project's suite. variant: full|github|minimal
template-check variant="full":
    @scripts/template-check.sh {{ variant }}

# Run template-check for every variant.
template-check-all: (template-check "full") (template-check "github") (template-check "minimal")

# Render the latest tag and `copier update` it to the working tree. args: extra copier args for the old render
[positional-arguments]
template-update-check *args:
    @scripts/template-update-check.sh "$@"

# Assert the uv_build range is the whole minor of the uv-pre-commit rev.
check-versions:
    @uv run --quiet scripts/check_versions.py

# Bump dependency versions.
bump:
    @scripts/bump.sh

# Print the latest release tag, which Copier serves, and how far HEAD is past it.
version:
    #!/usr/bin/env bash
    set -euo pipefail
    tag=$(git tag --list 'v*' --sort=-v:refname | head -n1)
    n=$(git rev-list --count "$tag"..HEAD)
    echo "$tag"
    [ "$n" -eq 0 ] || echo "HEAD is $n commit(s) past $tag, unreleased"

# Tag a release and push it.
release version:
    @scripts/release.sh {{ version }}
