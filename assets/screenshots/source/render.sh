#!/usr/bin/env bash
# Render every framed screenshot from its page, then rebuild the overview.
#
# The pages under pages/<locale>-<platform>/ ARE the source: edit the HTML or the
# frame.css sitting next to it, reload it in Safari, run this to produce the PNGs. Nothing
# regenerates them, so hand edits survive.
#
# Each page says where it goes and how big it is, so this script holds no table of sets:
#     <meta name="frame-size" content="1320x2868">
#     <meta name="frame-out"  content="de-DE/iphone-6.9">
#
# Pass page paths to render only those; with no arguments it renders all of them.
set -euo pipefail

fail() { printf '%s: error: %s\n' "${0##*/}" "$*" >&2; exit 1; }

scripts="${SKILL_SCRIPTS:-$HOME/.claude/skills/jk/skills/appstore-screenshots/scripts}"
renderer="$scripts/render-frame.swift"
[[ -f $renderer ]] || fail "no render-frame.swift in $scripts"

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(dirname "$source_dir")"
appstore="$root/appstore"

# Compiled once and cached on the renderer's own hash: 30 pages as a script is ~20 s, compiled
# ~9 s. A failed compile is not fatal — the script path still works.
cache="${TMPDIR:-/tmp}/appstore-screenshots-render"
binary="$cache/render-$(shasum -a 256 "$renderer" | cut -c1-16)"
if [[ ! -x $binary ]]; then
    mkdir -p "$cache"
    if swiftc -O "$renderer" -o "$binary.partial" 2>/dev/null; then
        mv -f "$binary.partial" "$binary"
    else
        rm -f "$binary.partial"
        binary="$renderer"
    fi
fi

meta() { sed -n "s/.*<meta name=\"$2\" content=\"\([^\"]*\)\".*/\1/p" "$1" | head -1; }

if [[ $# -gt 0 ]]; then
    pages=("$@")
else
    pages=()
    while IFS= read -r page; do pages+=("$page"); done \
        < <(find "$source_dir/pages" -mindepth 2 -maxdepth 2 -name '*.html' \
            -not -name 'index.html' | sort)
fi
[[ ${#pages[@]} -gt 0 ]] || fail "no pages found under $root/pages"

# Each set carries its own copy of the shared design, because the renderer refuses a stylesheet
# linked outside the page's directory. Divergence is reported, never silently resolved — the copy
# you just edited is the one that should win, and only you know which that is.
diverged=()
canonical=""
while IFS= read -r css; do
    [[ -n $canonical ]] || { canonical="$css"; continue; }
    cmp -s "$canonical" "$css" || diverged+=("$css")
done < <(find "$source_dir/pages" -mindepth 2 -maxdepth 2 -name frame.css | sort)
if [[ ${#diverged[@]} -gt 0 ]]; then
    printf 'note: frame.css differs between sets:\n' >&2
    for css in "${diverged[@]}"; do printf '  %s\n' "${css#"$root"/}" >&2; done
    printf '      run  ./sync-css.sh <the one you edited>  to bring them in line\n' >&2
fi

rendered=0
for page in "${pages[@]}"; do
    [[ -f $page ]] || fail "no such page: $page"
    size="$(meta "$page" frame-size)"
    out="$(meta "$page" frame-out)"
    [[ $size =~ ^([0-9]+)x([0-9]+)$ ]] \
        || fail "${page##*/} has no usable <meta name=\"frame-size\"> (got '$size')"
    [[ -n $out ]] || fail "${page##*/} has no <meta name=\"frame-out\">"
    name="$(basename "$page" .html)"
    mkdir -p "$appstore/$out"
    "$binary" --in "$page" --out "$appstore/$out/$name.png" \
        --width "${BASH_REMATCH[1]}" --height "${BASH_REMATCH[2]}"
    rendered=$((rendered + 1))
done
printf '==> %d page(s) rendered\n' "$rendered"

# Derived from the pages, so a set can never be checked against a size it no longer renders at.
python3 - "$source_dir/pages" "$appstore/plan.json" <<'PY'
import json, pathlib, re, sys

build, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
sets = {}
for page in sorted(build.glob("*/*.html")):
    if page.name == "index.html":
        continue
    text = page.read_text()[:600]
    size = re.search(r'name="frame-size" content="([^"]+)"', text)
    target = re.search(r'name="frame-out" content="([^"]+)"', text)
    if not size or not target:
        continue
    entry = sets.setdefault(target.group(1), {"dir": target.group(1),
                                              "size": size.group(1), "frames": 0})
    entry["frames"] += 1

# The overview follows this order, so it reads the way the platforms are worked on rather than
# the way their directory names happen to sort (`ipad` before `iphone`).
ORDER = ["iphone", "ipad", "mac"]


def rank(entry):
    platform = entry["dir"].split("/")[-1]
    position = next((i for i, name in enumerate(ORDER) if platform.startswith(name)), len(ORDER))
    return position, entry["dir"]


out.write_text(json.dumps({"sets": sorted(sets.values(), key=rank)}, indent=2) + "\n")
PY

"$scripts/build-index.sh" "$appstore" "$source_dir/index.html"
