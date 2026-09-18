# /// script
# requires-python = ">=3.13"
# dependencies = ["packaging>=25.0"]
# ///
"""Pin uv to the newest release the generated project's cutoff allows.

`pre-commit autoupdate` jumps to the newest release, which may be hours old.
That breaks the generated project for a week, so this runs after it and writes
a version that is actually installable to both places uv is named.
"""

import sys

import uv_pins


def main():
    try:
        chosen, newest = uv_pins.newest_allowed()
        high = uv_pins.cap_for(chosen)
        uv_pins.write_hook_rev(chosen)
        uv_pins.write_uv_build(chosen, high)
    except uv_pins.PinError as error:
        sys.exit(f"error: {error}")

    print(f"uv pinned to {chosen}, capped below {high}")
    if newest != chosen:
        print(f"(uv {newest} exists but is newer than the one-week cutoff)")


if __name__ == "__main__":
    main()
