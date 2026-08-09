# Run the full check suite: lint, typecheck, test, run examples, docs.
_:
  @just lint typecheck test check-examples docs

# Format and lint the package using ruff, and lint the examples using marimo.
# Order matters: `marimo check --fix` prunes names from cell return tuples,
# which can strand an import, so `ruff check` must run *after* it to catch the
# resulting F401. The reverse order needs a second pass to reach a fixed point.
lint:
  ruff format
  marimo check --fix examples/
  ruff check --fix
  marimo check --strict examples/

# Variant of `lint` that doesn't cause any changes to files (for CI).
# `--strict` is required: without it, `marimo check` exits 0 on everything
# except a broken dependency graph, so runtime and formatting issues pass.
lint-check:
  ruff format --check
  ruff check
  marimo check --strict examples/

# Assert the example notebooks are in marimo's canonical form. Plain
# `marimo check` reports nothing about drifted cell signatures -- only `--fix`
# touches those -- so the only way to gate on canonical form is to apply the
# fix and assert nothing changed. A no-op on a clean tree.
check-canonical:
  marimo check --fix examples/
  git diff --exit-code examples/

# Confirm the example notebooks actually run. Nothing else does: linting never
# executes cells, and `marimo-md-export` prints an error but still exits 0 (and
# still writes the markdown) when a cell raises -- verified against 0.9.0.
check-examples:
  python examples/notebook.py

# Run static type checker.
typecheck:
  pyright

# Run the test suite using pytest.
test:
  pytest

# Run tests with coverage report.
test-cov:
  pytest --cov=python_package_template --cov-report=term-missing --cov-fail-under=90

# Run doctest examples embedded in source docstrings.
doctest:
  pytest --doctest-modules src/python_package_template

# Export the example notebooks, then build the documentation using Zensical.
docs: docs-examples
  zensical build

# Export the example notebooks to markdown with their rendered outputs.
docs-examples:
  marimo-md-export examples/notebook.py docs/example.md --figures-dir figures
  ruff format examples/  # override marimo's reformatting

# Serve the documentation locally with live reload.
docs-serve: docs-examples
  zensical serve

# --- template bootstrap (this block is removed by `just bootstrap`) ---

# Rename this template to a real project. Infers owner/repo from the git remote.
bootstrap *args:
  python3 scripts/bootstrap.py {{args}}

# --- end template bootstrap ---
