# This is the *template repository's* justfile, for maintaining the template.
# The one shipped to generated projects is template/justfile.jinja.

_default:
    @just --list

# Mirrors the `render` job in .github/workflows/test-template.yml. When that
# workflow changes, change this too: a local check that is a subset of CI gives
# false confidence.
#
# Renders to a temp directory outside the repository, because the generated
# project's `check-canonical` runs `git diff --exit-code examples/`, which from
# a nested render would walk up to this repository and pass vacuously.

# Render the template and run the generated project's suite. variant: full|minimal
template-check variant="full":
    #!/usr/bin/env bash
    set -euo pipefail

    if [ "{{ variant }}" != "full" ] && [ "{{ variant }}" != "minimal" ]; then
        echo "variant must be 'full' or 'minimal', got '{{ variant }}'" >&2
        exit 2
    fi

    dst="$(mktemp -d)"
    trap 'rm -rf "$dst"' EXIT

    if [ "{{ variant }}" = "full" ]; then
        flags=(--data with_pypi=true --data with_cli=true --data with_license=true)
    else
        flags=(--data with_pypi=false --data with_cli=false --data with_license=false)
    fi

    # Rendered from `.` inside the repository, exactly as CI does, not from an
    # absolute path: Copier records the source in .copier-answers.yml, and an
    # absolute path here would trip the owner-leak check below on any machine
    # whose home directory happens to contain the owner's name.
    cd "{{ justfile_directory() }}"

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

    # The same three assertions CI makes. See the workflow for why each
    # exclusion is there; the marimo-md-export URL is a real third-party link.
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

    if [ "{{ variant }}" = "full" ]; then
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

# Run template-check for both variants.
template-check-all: (template-check "full") (template-check "minimal")

# The uv-pre-commit hook and the uv_build build requirement must name the same
# uv release: the hook writes uv.lock, the build backend consumes it, and a
# mismatch is only discovered when someone's lockfile churns on commit. `bump`
# derives one from the other, and this asserts it held.

# Assert uv_build and the uv-pre-commit hook name the same uv release.
check-versions:
    #!/usr/bin/env python3
    import re
    import sys
    from pathlib import Path

    root = Path("{{ justfile_directory() }}")

    config = (root / "template/.pre-commit-config.yaml").read_text()
    match = re.search(
        r"repo:\s*https://github\.com/astral-sh/uv-pre-commit\s*\n"
        r"(?:\s*#.*\n)*"
        r"\s*rev:\s*v?(\d+\.\d+\.\d+)",
        config,
    )
    if match is None:
        sys.exit("could not find the uv-pre-commit rev in .pre-commit-config.yaml")
    hook = match.group(1)

    pyproject = (root / "template/pyproject.toml.jinja").read_text()
    match = re.search(
        r'uv_build>=(\d+\.\d+\.\d+),<(\d+\.\d+\.\d+)', pyproject
    )
    if match is None:
        sys.exit("could not find the uv_build requirement in pyproject.toml.jinja")
    low, high = match.group(1), match.group(2)

    major, minor, _ = (int(part) for part in low.split("."))
    expected_high = f"{major}.{minor + 1}.0"

    problems = []
    if low != hook:
        problems.append(
            f"uv_build lower bound is {low}, but the uv-pre-commit rev is {hook}"
        )
    if high != expected_high:
        problems.append(
            f"uv_build upper bound is {high}, expected {expected_high} "
            f"(one minor above {low})"
        )

    if problems:
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        sys.exit("run `just bump`, or fix template/pyproject.toml.jinja by hand")

    print(f"ok: uv {low}, capped below {high}")

# Updates the pre-commit revs, re-derives the uv_build range from the new uv
# rev so the two cannot drift, then renders and tests both variants. Leaves the
# result uncommitted for you to read: it does not commit, and it does not tag.
# `just release vX.Y` does that once you are happy.

# The quarterly bump. Run it when the canary goes red, or every few months.
bump:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ justfile_directory() }}"

    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "working tree is dirty; commit or stash first" >&2
        exit 1
    fi

    echo "==> pre-commit autoupdate"
    uvx pre-commit autoupdate -c template/.pre-commit-config.yaml

    echo
    echo "==> pinning uv to the newest release the cutoff allows"
    python3 - <<'PY'
    import json
    import re
    import sys
    import urllib.request
    from datetime import datetime, timedelta, timezone
    from pathlib import Path

    # The generated project sets `exclude-newer = "1 week"`, and that applies to
    # `build-system.requires` as well as the dependency groups. So uv_build
    # cannot name a release younger than the cutoff, or every fresh `uv sync`
    # fails for a week. `pre-commit autoupdate` has no idea about this and will
    # happily jump to a release published today, so both the rev and the
    # requirement get pinned to the newest uv-build that is at least a week old.
    cutoff = datetime.now(timezone.utc) - timedelta(days=7)

    with urllib.request.urlopen("https://pypi.org/pypi/uv-build/json", timeout=30) as f:
        releases = json.load(f)["releases"]

    final = re.compile(r"^\d+\.\d+\.\d+$")
    eligible = []
    for version, files in releases.items():
        if not final.match(version) or not files:
            continue
        # .replace for the trailing Z: fromisoformat only accepts it on 3.11+,
        # and this runs under whatever python3 is on PATH.
        uploaded = min(
            datetime.fromisoformat(item["upload_time_iso_8601"].replace("Z", "+00:00"))
            for item in files
        )
        if uploaded <= cutoff:
            eligible.append((tuple(int(p) for p in version.split(".")), version))

    if not eligible:
        sys.exit("no uv-build release is older than the cutoff")
    low = max(eligible)[1]
    major, minor, _ = (int(part) for part in low.split("."))
    high = f"{major}.{minor + 1}.0"

    config_path = Path("template/.pre-commit-config.yaml")
    config = config_path.read_text()
    pattern = re.compile(
        r"(repo:\s*https://github\.com/astral-sh/uv-pre-commit\s*\n"
        r"(?:\s*#.*\n)*"
        r"\s*rev:\s*)v?\d+\.\d+\.\d+"
    )
    config, count = pattern.subn(lambda m: m.group(1) + low, config)
    if count != 1:
        sys.exit(f"expected exactly one uv-pre-commit rev, found {count}")
    config_path.write_text(config)

    pyproject_path = Path("template/pyproject.toml.jinja")
    pyproject = pyproject_path.read_text()
    pyproject, count = re.subn(
        r"uv_build>=\d+\.\d+\.\d+,<\d+\.\d+\.\d+",
        f"uv_build>={low},<{high}",
        pyproject,
    )
    if count != 1:
        sys.exit(f"expected exactly one uv_build requirement, found {count}")
    pyproject_path.write_text(pyproject)

    newest = max(
        (tuple(int(p) for p in v.split(".")), v)
        for v in releases
        if final.match(v) and releases[v]
    )[1]
    print(f"uv pinned to {low}, capped below {high}")
    if newest != low:
        print(f"(uv {newest} exists but is newer than the one-week cutoff)")
    PY

    echo
    just check-versions

    echo
    echo "==> what changed"
    git --no-pager diff --stat
    if git diff --quiet; then
        echo "nothing to bump; everything is already current"
        exit 0
    fi
    git --no-pager diff

    echo
    echo "==> verifying both variants"
    just template-check-all

    echo
    echo "Bump verified. Next:"
    echo "  git commit -am 'Bump pinned tool versions'"
    echo "  just release vX.Y"

# Tag a release and push it. Template changes reach nobody until this runs.
release version:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ justfile_directory() }}"

    if [[ ! "{{ version }}" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        echo "version must look like v1.2 or v1.2.3, got '{{ version }}'" >&2
        exit 2
    fi
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "working tree is dirty; commit first" >&2
        exit 1
    fi

    branch="$(git rev-parse --abbrev-ref HEAD)"
    if [ "$branch" != "main" ]; then
        echo "on '$branch', not main: Copier resolves gh: shorthand to the" >&2
        echo "latest tag, so a tag off main would ship that branch to users." >&2
        exit 1
    fi
    if git rev-parse -q --verify "refs/tags/{{ version }}" >/dev/null; then
        echo "tag {{ version }} already exists" >&2
        exit 1
    fi

    just check-versions
    git tag -a "{{ version }}" -m "{{ version }}"
    git push origin "{{ version }}"
    echo "pushed {{ version }}"
