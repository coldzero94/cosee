#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
configuration="${1:-Debug}"
case "$configuration" in Debug|Release) ;; *) echo "Use Debug or Release." >&2; exit 1;; esac
cd "$root"
xcodebuild -resolvePackageDependencies -project Cosee.xcodeproj -scheme Cosee -derivedDataPath DerivedData
python3 scripts/prepare-notices.py DerivedData/SourcePackages/checkouts
xcodebuild -project Cosee.xcodeproj -scheme Cosee -configuration "$configuration" \
    -destination 'generic/platform=macOS' -derivedDataPath DerivedData \
    -onlyUsePackageVersionsFromResolvedFile \
    "ARCHS=${COSEE_ARCHS:-arm64 x86_64}" ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO ENABLE_CODE_COVERAGE=NO build
echo "Built: $root/DerivedData/Build/Products/$configuration/Cosee.app"
