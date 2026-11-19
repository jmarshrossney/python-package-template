#!/usr/bin/env bash
# Render the latest tag, then `copier update` it to the working tree.
#
# Usage: scripts/template-update-check.sh [copier args for the old render...]
#   e.g. scripts/template-update-check.sh --data release=github
#
# Needed when a change touches questions or answers, since `copier update` is
# how existing projects receive it. CI does not run this. Pass `--data` for
# the old answers whose handling changed. The scratch project is kept so the
# diff can be inspected; its path is printed at the end.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

tag="$(git describe --tags --abbrev=0)"
dst="$(mktemp -d)/old"

uvx copier copy --defaults --vcs-ref="$tag" \
    --data project_name=demo-pkg \
    --data project_description="Does a thing." \
    --data github_owner=someone-else \
    --data author_name="Ada Lovelace" \
    --data author_email=ada@example.com \
    "$@" \
    . "$dst"

# Rendering from `.` (to keep absolute paths out of the leak check) records
# `_src_path: .`, which `update` resolves relative to the project and fails
# with `Unknown revision`. The absolute path stays in the scratch project.
sed -i.bak "s|^_src_path: .*|_src_path: $root|" "$dst/.copier-answers.yml"
rm "$dst/.copier-answers.yml.bak"

# `update` refuses a destination that is not a clean git repository. The
# identity and signing flags keep this independent of the user's git config.
cd "$dst"
git init -q
git add -A
git -c user.name=scratch -c user.email=scratch@example.com \
    commit -qm "render $tag" --no-gpg-sign

# --defaults answers new questions with their defaults, which is what
# exercises a default derived from an old answer. The dirty-state warning
# from --vcs-ref=HEAD is expected.
uvx copier update --defaults --vcs-ref=HEAD

# Includes .copier-answers.yml, which shows how the answers were replayed.
git --no-pager diff
echo
echo "updated from $tag; scratch project kept at $dst"
