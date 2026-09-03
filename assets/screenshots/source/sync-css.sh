#!/usr/bin/env bash
# Copy one page directory's frame.css over the other five.
#
# The renderer refuses a stylesheet linked outside the page's own directory, so each set carries
# its own copy of the shared design. Edit whichever one you are iterating in, then run this to
# propagate it.
#
# Usage: sync-css.sh <path to the frame.css you edited>
set -euo pipefail

fail() { printf '%s: error: %s\n' "${0##*/}" "$*" >&2; exit 1; }

master="${1:-}"
[[ -f $master ]] || fail "usage: sync-css.sh <path to the frame.css you edited>"
master="$(cd "$(dirname "$master")" && pwd -P)/$(basename "$master")"

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
pages="$source_dir/pages"

copied=0
while IFS= read -r target; do
    [[ $target != "$master" ]] || continue
    cmp -s "$master" "$target" && continue
    cp "$master" "$target"
    printf '  updated %s\n' "${target#"$(dirname "$pages")"/}"
    copied=$((copied + 1))
done < <(find "$pages" -mindepth 2 -maxdepth 2 -name frame.css | sort)

printf '==> %d copy/copies brought in line with %s\n' "$copied" "${master##*/pages/}"
