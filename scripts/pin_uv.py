# /// script
# requires-python = ">=3.13"
# dependencies = ["packaging>=25.0"]
# ///
"""Pin uv to the newest release the generated project's cutoff allows.

`pre-commit autoupdate` jumps to the newest release, which may be hours old.
This runs after it, pins the hook to a release past the cutoff, and sets the
uv_build range to that release's whole minor.
"""

import sys

import uv_pins


def main():
    try:
        chosen, newest = uv_pins.newest_allowed()
        low, high = uv_pins.floor_for(chosen), uv_pins.cap_for(chosen)
        uv_pins.write_hook_rev(chosen)
        uv_pins.write_uv_build(low, high)
    except uv_pins.PinError as error:
        sys.exit(f"error: {error}")

    print(f"uv pinned to {chosen}, uv_build >={low},<{high}")
    if newest != chosen:
        print(f"(uv {newest} exists but is newer than the one-week cutoff)")


if __name__ == "__main__":
    main()
