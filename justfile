# This is the *template repository's* justfile, for maintaining the template.

_default:
    @just --list

# Render the template and run the generated project's suite. variant: full|minimal
template-check variant="full":
    @scripts/template-check.sh {{ variant }}

# Run template-check for both variants.
template-check-all: (template-check "full") (template-check "minimal")

# Assert uv_build and the uv-pre-commit hook name the same uv release.
check-versions:
    @uv run --quiet scripts/check_versions.py

# Bump dependency versions.
bump:
    @scripts/bump.sh

# Tag a release and push it.
release version:
    @scripts/release.sh {{ version }}
