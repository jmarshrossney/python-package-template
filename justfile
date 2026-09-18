# This is the *template repository's* justfile, for maintaining the template.
# The one shipped to generated projects is template/justfile.jinja.
#
# The recipes are thin: the work lives in scripts/, which keeps it lintable and
# runnable without just. Each script also takes its own arguments, so
# `scripts/template-check.sh minimal` does what `just template-check minimal`
# does.

_default:
    @just --list

# Render the template and run the generated project's suite. variant: full|minimal
template-check variant="full":
    @scripts/template-check.sh {{ variant }}

# Run template-check for both variants.
template-check-all: (template-check "full") (template-check "minimal")

# Assert uv_build and the uv-pre-commit hook name the same uv release.
check-versions:
    @python3 scripts/check_versions.py

# The quarterly bump. Run it when the canary goes red, or every few months.
bump:
    @scripts/bump.sh

# Tag a release and push it. Template changes reach nobody until this runs.
release version:
    @scripts/release.sh {{ version }}
