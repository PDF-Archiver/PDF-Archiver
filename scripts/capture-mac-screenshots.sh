#!/bin/bash
# Captures the macOS App Store screenshots from the running app.
#
# The Mac shots cannot come from the snapshot tests: an offscreen render through `cacheDisplay`
# does not traverse the macOS 26 glass sidebar and leaves a blank white block. The app therefore
# captures its own window from the window server, which needs no Screen Recording permission.
#
# Usage: scripts/capture-mac-screenshots.sh <output-directory> [receipt.pdf]

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "usage: $0 <output-directory> [receipt.pdf]" >&2
    exit 2
fi

output_directory=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
receipt=${2:-}
repository=$(cd "$(dirname "$0")/.." && pwd)
derived_data=${DERIVED_DATA:-$repository/.build/mac-screenshots}

mkdir -p "$output_directory"

echo "==> Building the macOS app"
xcodebuild build \
    -workspace "$repository/PDFArchiver.xcworkspace" \
    -scheme macOS \
    -destination 'platform=macOS' \
    -derivedDataPath "$derived_data" \
    -quiet

app=$(find "$derived_data/Build/Products" -maxdepth 2 -name '*.app' | head -1)
if [ -z "$app" ]; then
    echo "error: no built app found under $derived_data/Build/Products" >&2
    exit 1
fi

# Scene identifier : output file name, per the marketing shot list.
scenes=(
    "mac:01-archive"
    "macTagging:02-tagging"
    "macDocument:03-document"
)

for entry in "${scenes[@]}"; do
    scene=${entry%%:*}
    name=${entry##*:}
    destination="$output_directory/$name.png"
    rm -f "$destination"

    echo "==> Capturing $scene"
    arguments=(-screenshotScene "$scene" -screenshotOutput "$destination")
    if [ -n "$receipt" ]; then
        arguments+=(-screenshotAsset "$receipt")
    fi

    # `open` rather than the executable directly, so the app activates and the window server
    # composites it; the app writes the PNG and quits itself.
    open -n -a "$app" --args "${arguments[@]}"

    for _ in $(seq 60); do
        [ -s "$destination" ] && break
        sleep 0.5
    done

    if [ ! -s "$destination" ]; then
        echo "error: $scene produced no file — nothing was written to $destination" >&2
        exit 1
    fi
    echo "    $(sips -g pixelWidth -g pixelHeight "$destination" | awk '/pixel/{printf "%s ", $2}')-> $destination"
done

echo "==> Done: $(find "$output_directory" -name '*.png' | wc -l | tr -d ' ') files in $output_directory"
