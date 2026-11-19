# /// script
# requires-python = ">=3.13"
# dependencies = ["packaging>=25.0"]
# ///
"""Assert the uv_build range is the whole minor of the uv-pre-commit hook.

`bump` derives one from the other, so this only fires on a hand edit that
changed a single side. CI runs it.
"""

import sys

import uv_pins


def main():
    try:
        hook = uv_pins.read_hook_rev()
        low, high = uv_pins.read_uv_build()
    except uv_pins.PinError as error:
        sys.exit(f"error: {error}")

    expected_low = uv_pins.floor_for(hook)
    expected_high = uv_pins.cap_for(hook)

    problems = []
    if low != expected_low:
        problems.append(
            f"uv_build lower bound is {low}, expected {expected_low} "
            f"(the minor of the uv-pre-commit rev, {hook})"
        )
    if high != expected_high:
        problems.append(
            f"uv_build upper bound is {high}, expected {expected_high} "
            f"(the minor after the uv-pre-commit rev, {hook})"
        )

    if problems:
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        sys.exit("run `just bump`, or fix template/pyproject.toml.jinja by hand")

    print(f"ok: uv {hook}, uv_build >={low},<{high}")


if __name__ == "__main__":
    main()
