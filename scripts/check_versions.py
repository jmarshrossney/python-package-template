"""Assert uv_build and the uv-pre-commit hook name the same uv release.

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

    expected_high = uv_pins.cap_for(low)

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


if __name__ == "__main__":
    main()
