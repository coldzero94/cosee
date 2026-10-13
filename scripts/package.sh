#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mode="${1:-development}"
case "$mode" in development|release) ;; *) echo "Use development or release." >&2; exit 1;; esac
if [[ "$mode" == release ]]; then
    : "${COSEE_SIGN_ID:?Set COSEE_SIGN_ID to your Developer ID Application identity.}"
    : "${COSEE_NOTARY_PROFILE:?Set COSEE_NOTARY_PROFILE to a notarytool Keychain profile.}"
    [[ "$COSEE_SIGN_ID" == 'Developer ID Application: '* ]] || { echo "A Developer ID Application certificate is required." >&2; exit 1; }
fi
"$root/scripts/build.sh" Release
app="$root/DerivedData/Build/Products/Release/Cosee.app"
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")"
output="$root/artifacts/$mode"
mkdir -p "$output"
stage="$(mktemp -d "${TMPDIR:-/tmp}/cosee-package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Cosee.app"
app="$stage/Cosee.app"
if [[ "$mode" == release ]]; then
    codesign --force --sign "$COSEE_SIGN_ID" --options runtime --timestamp \
        --entitlements "$root/Cosee/Cosee.entitlements" "$app"
else
    codesign --force --sign - --options runtime --timestamp=none \
        --entitlements "$root/Cosee/Cosee.entitlements" "$app"
fi
codesign --verify --deep --strict --verbose=2 "$app"
"$app/Contents/MacOS/Cosee" --diagnose > "$output/diagnostics.json"
stem="Cosee-$version"
if [[ "$mode" == development ]]; then stem="$stem-local"; fi
zip="$output/$stem.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
if [[ "$mode" == release ]]; then
    xcrun notarytool submit "$zip" --keychain-profile "$COSEE_NOTARY_PROFILE" --wait --output-format json > "$output/app-notarization.json"
    python3 -c 'import json,sys; result=json.load(open(sys.argv[1])); sys.exit(0 if result.get("status")=="Accepted" else "App notarization failed; inspect the report and request its log with notarytool.")' "$output/app-notarization.json"
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
    spctl --assess --type execute --verbose=2 "$app"
    ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
fi
image_source="$stage/image"
mkdir -p "$image_source"
ditto "$app" "$image_source/Cosee.app"
ln -s /Applications "$image_source/Applications"
cp "$root/LICENSE" "$root/NOTICE" "$image_source/"
cp "$root/LocalPackage/Sources/UserInterface/Resources/Privacy.txt" "$image_source/Privacy.txt"
dmg="$output/$stem.dmg"
hdiutil create -volname Cosee -srcfolder "$image_source" -ov -format UDZO "$dmg"
if [[ "$mode" == release ]]; then
    codesign --force --sign "$COSEE_SIGN_ID" --timestamp "$dmg"
    xcrun notarytool submit "$dmg" --keychain-profile "$COSEE_NOTARY_PROFILE" --wait --output-format json > "$output/dmg-notarization.json"
    python3 -c 'import json,sys; result=json.load(open(sys.argv[1])); sys.exit(0 if result.get("status")=="Accepted" else "DMG notarization failed; inspect the report and request its log with notarytool.")' "$output/dmg-notarization.json"
    xcrun stapler staple "$dmg"
    xcrun stapler validate "$dmg"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
fi
(cd "$output" && shasum -a 256 "$stem.zip" "$stem.dmg" > SHA256SUMS)
echo "Packages: $output"
if [[ "$mode" == development ]]; then echo "Local development packages are ad hoc signed and are not notarized for public distribution."; fi
