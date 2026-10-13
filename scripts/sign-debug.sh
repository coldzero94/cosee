#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/DerivedData/Build/Products/Debug/Cosee.app"
# Debug's injected libraries are unsigned when CODE_SIGNING_ALLOWED=NO.
# Sign nested code first; Hardened Runtime remains enabled for Release packaging.
while IFS= read -r -d '' library; do
    codesign --force --sign - --options 0 --timestamp=none "$library"
done < <(find "$app/Contents" -type f -name '*.dylib' -print0)
codesign --force --sign - --options 0 --timestamp=none \
    --entitlements "$root/Cosee/Cosee.entitlements" "$app"
codesign --verify --deep --strict "$app"
