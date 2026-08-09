#!/usr/bin/env python3
"""Turn this template into a real project, in place.

Run once, immediately after creating a repository from the template:

    just bootstrap
    just bootstrap --name my-package --description "Does a thing."

Everything is inferred from the git remote where possible. The script rewrites
the template's own name out of every file, renames the package directory,
replaces the README, and finally removes itself and the `bootstrap` recipe.

Stdlib only, and deliberately dumb: it is a whole-word find-and-replace over a
known file list, so `git diff` tells you exactly what happened.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# The strings being replaced. Order matters: longest/most-specific first, so
# that "OWNER/REPO" is handled before the bare repo name.
TEMPLATE_OWNER = "jmarshrossney"
TEMPLATE_REPO = "python-package-template"
TEMPLATE_PKG = "python_package_template"
TEMPLATE_DESCRIPTION = (
    "A template for Python packages built with "
    "uv, just, ruff, pyright, pytest and zensical."
)

# Files rewritten in place. Generated and vendored trees are excluded.
TARGETS = [
    "pyproject.toml",
    "zensical.toml",
    "justfile",
    "CONTRIBUTING.md",
    "AGENTS.md",
    "docs/index.md",
    "docs/getting-started.md",
    "docs/api.md",
    "examples/notebook.py",
    "tests/test_init.py",
]

# Markers around the bootstrap recipe in the justfile.
JUSTFILE_BEGIN = "# --- template bootstrap"
JUSTFILE_END = "# --- end template bootstrap ---"

NEW_README = """# {repo}

{description}

## Installation

```sh
pip install {repo}
```

## Usage

```python
import {pkg}
```

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md). In short: `uv sync`, then `just`.
"""


def git(*args: str) -> str | None:
    """Run a git command, returning stripped stdout or None on failure."""
    try:
        out = subprocess.run(
            ["git", *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    return out.stdout.strip() or None


def infer_from_remote() -> tuple[str | None, str | None]:
    """Return (owner, repo) parsed from the `origin` remote, if available."""
    url = git("remote", "get-url", "origin")
    if not url:
        return None, None
    match = re.search(r"[:/]([^/:]+)/([^/]+?)(?:\.git)?$", url)
    if not match:
        return None, None
    return match.group(1), match.group(2)


def to_package_name(repo: str) -> str:
    """Convert a repository name to an importable package name."""
    pkg = re.sub(r"[^0-9a-zA-Z]+", "_", repo).strip("_").lower()
    if not pkg or not pkg[0].isalpha():
        pkg = f"pkg_{pkg}".rstrip("_")
    return pkg


def prompt(label: str, default: str | None) -> str:
    """Ask for a value, offering a default."""
    suffix = f" [{default}]" if default else ""
    while True:
        answer = input(f"{label}{suffix}: ").strip()
        if answer:
            return answer
        if default:
            return default


def rewrite(path: Path, replacements: list[tuple[str, str]]) -> bool:
    """Apply replacements to a file. Returns True if the file changed."""
    if not path.exists():
        return False
    original = path.read_text()
    updated = original
    for old, new in replacements:
        updated = updated.replace(old, new)
    if updated == original:
        return False
    path.write_text(updated)
    return True


def strip_bootstrap_recipe(justfile: Path) -> None:
    """Remove the bootstrap block from the justfile."""
    lines = justfile.read_text().splitlines(keepends=True)
    start = next(
        (i for i, line in enumerate(lines) if line.startswith(JUSTFILE_BEGIN)), None
    )
    end = next(
        (i for i, line in enumerate(lines) if line.startswith(JUSTFILE_END)), None
    )
    if start is None or end is None or end < start:
        print("  ! could not locate the bootstrap block; remove it by hand")
        return
    # Also drop the blank line preceding the block, if there is one.
    while start > 0 and not lines[start - 1].strip():
        start -= 1
    justfile.write_text("".join(lines[:start] + lines[end + 1 :]))


def main() -> int:
    """Run the bootstrap."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", help="project (and distribution) name")
    parser.add_argument("--owner", help="GitHub user or organisation")
    parser.add_argument("--description", help="one-line project description")
    parser.add_argument("--package", help="import name (default: derived from --name)")
    parser.add_argument(
        "--yes",
        action="store_true",
        help="accept inferred values without prompting",
    )
    args = parser.parse_args()

    remote_owner, remote_repo = infer_from_remote()

    if remote_repo == TEMPLATE_REPO and remote_owner == TEMPLATE_OWNER:
        print(
            "Refusing to bootstrap: the git remote still points at the template "
            f"itself ({TEMPLATE_OWNER}/{TEMPLATE_REPO}).\n"
            "Create a repository from the template first, or pass --name and "
            "--owner explicitly."
        )
        if not args.name or not args.owner:
            return 1

    repo = args.name or remote_repo
    owner = args.owner or remote_owner

    if args.yes:
        if not repo or not owner:
            print("--yes requires --name and --owner when there is no git remote")
            return 1
        description = args.description or f"The {repo} package."
    else:
        repo = args.name or prompt("Project name", remote_repo)
        owner = args.owner or prompt("GitHub owner", remote_owner)
        description = args.description or prompt("Description", f"The {repo} package.")

    pkg = args.package or to_package_name(repo)

    print(f"\n  name        {repo}")
    print(f"  package     {pkg}")
    print(f"  owner       {owner}")
    print(f"  description {description}")
    print(f"  docs url    https://{owner.lower()}.github.io/{repo}\n")

    if not args.yes and input("Proceed? [y/N]: ").strip().lower() not in ("y", "yes"):
        return 1

    replacements = [
        # Pages URL before the owner/repo pair, which is before the bare names.
        (
            f"https://{TEMPLATE_OWNER}.github.io/{TEMPLATE_REPO}",
            f"https://{owner.lower()}.github.io/{repo}",
        ),
        (f"{TEMPLATE_OWNER}/{TEMPLATE_REPO}", f"{owner}/{repo}"),
        (f"github.com/{TEMPLATE_OWNER}", f"github.com/{owner}"),
        (TEMPLATE_DESCRIPTION, description),
        (TEMPLATE_PKG, pkg),
        (TEMPLATE_REPO, repo),
    ]

    for relpath in TARGETS:
        if rewrite(ROOT / relpath, replacements):
            print(f"  rewrote {relpath}")

    src = ROOT / "src" / TEMPLATE_PKG
    dest = ROOT / "src" / pkg
    if src.exists() and src != dest:
        src.rename(dest)
        print(f"  renamed src/{TEMPLATE_PKG}/ -> src/{pkg}/")

    (ROOT / "README.md").write_text(
        NEW_README.format(repo=repo, pkg=pkg, description=description)
    )
    print("  replaced README.md")

    strip_bootstrap_recipe(ROOT / "justfile")
    print("  removed the bootstrap recipe from the justfile")

    shutil.rmtree(ROOT / "scripts")
    print("  removed scripts/")

    print(
        "\nDone. Next:\n"
        "  1. uv sync                      # regenerate uv.lock under the new name\n"
        "  2. git diff                     # check the rewrites\n"
        "  3. just                         # lint, typecheck, test, docs\n"
        "  4. Update LICENSE, docs/, and the logo in zensical.toml\n"
        "  5. Enable GitHub Pages (Settings -> Pages -> GitHub Actions)\n"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
