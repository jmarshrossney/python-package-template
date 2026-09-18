"""Read and write the uv version that the template pins in two places.

The uv-pre-commit hook writes ``uv.lock`` and the ``uv_build`` backend consumes
it, so both must name the same uv release. Everything that reads or writes that
pairing lives here, so ``check_versions.py`` and ``pin_uv.py`` cannot disagree
about what the files look like.
"""

import json
import re
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRE_COMMIT_CONFIG = ROOT / "template/.pre-commit-config.yaml"
PYPROJECT = ROOT / "template/pyproject.toml.jinja"

# The rev line belonging to the uv-pre-commit repo specifically, tolerating the
# comment lines between `repo:` and `rev:`. Group 1 is everything up to the
# version, so a substitution can keep it and replace only the version.
_HOOK_REV = re.compile(
    r"(repo:\s*https://github\.com/astral-sh/uv-pre-commit\s*\n"
    r"(?:\s*#.*\n)*"
    r"\s*rev:\s*)v?(\d+\.\d+\.\d+)"
)
_UV_BUILD = re.compile(r"uv_build>=(\d+\.\d+\.\d+),<(\d+\.\d+\.\d+)")

_FINAL_VERSION = re.compile(r"^\d+\.\d+\.\d+$")


class PinError(Exception):
    """A pin could not be read or written as expected."""


def _key(version):
    return tuple(int(part) for part in version.split("."))


def cap_for(version):
    """The upper bound paired with ``version``: one minor above it."""
    major, minor, _ = _key(version)
    return f"{major}.{minor + 1}.0"


def read_hook_rev():
    match = _HOOK_REV.search(PRE_COMMIT_CONFIG.read_text())
    if match is None:
        raise PinError(f"no uv-pre-commit rev in {PRE_COMMIT_CONFIG.name}")
    return match.group(2)


def read_uv_build():
    match = _UV_BUILD.search(PYPROJECT.read_text())
    if match is None:
        raise PinError(f"no uv_build requirement in {PYPROJECT.name}")
    return match.group(1), match.group(2)


def write_hook_rev(version):
    text = PRE_COMMIT_CONFIG.read_text()
    text, count = _HOOK_REV.subn(lambda m: m.group(1) + version, text)
    if count != 1:
        raise PinError(f"expected 1 uv-pre-commit rev, found {count}")
    PRE_COMMIT_CONFIG.write_text(text)


def write_uv_build(low, high):
    text = PYPROJECT.read_text()
    text, count = _UV_BUILD.subn(f"uv_build>={low},<{high}", text)
    if count != 1:
        raise PinError(f"expected 1 uv_build requirement, found {count}")
    PYPROJECT.write_text(text)


def released_uv_builds():
    """Final uv-build releases on PyPI, as {version: first upload time}."""
    url = "https://pypi.org/pypi/uv-build/json"
    with urllib.request.urlopen(url, timeout=30) as response:
        releases = json.load(response)["releases"]

    uploads = {}
    for version, files in releases.items():
        if not _FINAL_VERSION.match(version) or not files:
            continue
        # .replace for the trailing Z: fromisoformat only accepts it on 3.11+,
        # and this runs under whatever python3 is on PATH.
        uploads[version] = min(
            datetime.fromisoformat(item["upload_time_iso_8601"].replace("Z", "+00:00"))
            for item in files
        )
    return uploads


def newest_allowed(days=7):
    """The newest uv-build at least ``days`` old, and the newest overall.

    The generated project sets ``exclude-newer = "1 week"``, and that applies to
    ``build-system.requires`` as well as the dependency groups. A ``uv_build``
    floor naming a release published inside that window makes every fresh
    ``uv sync`` fail until the cutoff catches up, so the pin has to lag.
    """
    uploads = released_uv_builds()
    if not uploads:
        raise PinError("PyPI returned no final uv-build releases")

    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    eligible = [v for v, uploaded in uploads.items() if uploaded <= cutoff]
    if not eligible:
        raise PinError(f"no uv-build release is more than {days} days old")

    return max(eligible, key=_key), max(uploads, key=_key)
