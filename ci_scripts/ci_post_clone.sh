#!/bin/zsh

# https://stackoverflow.com/a/78572430
mkdir -p ~/Library/org.swift.swiftpm/security/

# update the macros fingerprints according to the Package.resolved file
PACKAGE_RESOLVED="../PDFArchiver.xcworkspace/xcshareddata/swiftpm/Package.resolved"

# List of "packageIdentity targetName" pairs
PACKAGES="
swift-dependencies DependenciesMacrosPlugin
swift-composable-architecture ComposableArchitectureMacros
swift-case-paths CasePathsMacros
swift-perception PerceptionMacros
"

entries=""

# Loop through packages
echo "$PACKAGES" | while read -r pkg target; do
  [ -z "$pkg" ] && continue

  # Extract fingerprint (revision) using jq
  fingerprint=$(jq -r --arg pkg "$pkg" \
    '.pins[] | select(.identity == $pkg) | .state.revision' \
    "$PACKAGE_RESOLVED")

  if [ -z "$fingerprint" ] || [ "$fingerprint" = "null" ]; then
    echo "Error: Could not find fingerprint for package '$pkg'" >&2
    exit 1
  fi

  # Create JSON entry
  jq -n \
    --arg fp "$fingerprint" \
    --arg pkg "$pkg" \
    --arg target "$target" \
    '{fingerprint: $fp, packageIdentity: $pkg, targetName: $target}'
done | jq -s '.' > macros.json

# copy the new file
cp macros.json ~/Library/org.swift.swiftpm/security/
