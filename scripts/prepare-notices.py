#!/usr/bin/env python3
"""Bundle the license texts for the resolved source dependencies."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
checkouts = Path(sys.argv[1])
resolved = root / "Cosee.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if not resolved.exists():
    resolved = root / "LocalPackage/Package.resolved"
pins = json.loads(resolved.read_text())["pins"]
directories = {item.name.lower(): item for item in checkouts.iterdir() if item.is_dir()}
parts = [(root / "NOTICE").read_text(), (root / "LICENSE").read_text()]
for pin in sorted(pins, key=lambda item: item["identity"]):
    identity = pin["identity"].lower()
    if identity not in directories:
        raise SystemExit(f"Missing checkout: {identity}. Resolve packages first.")
    texts = sorted(path for path in directories[identity].iterdir()
                   if path.is_file() and path.name.upper().startswith(("LICENSE", "NOTICE")))
    if not texts:
        raise SystemExit(f"Missing license: {identity}. Add its attribution before distributing.")
    state = pin["state"]
    parts.append(f"\n{identity} {state.get('version', state['revision'])}\n{pin['location']}\n")
    parts.extend(path.read_text() for path in texts)
(root / "LocalPackage/Sources/UserInterface/Resources/ThirdPartyNotices.txt").write_text("\n\n".join(parts))
