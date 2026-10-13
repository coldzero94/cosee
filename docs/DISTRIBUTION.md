# Direct distribution

Cosee is built for direct installation on macOS 26+. It uses Hardened Runtime and operates with the current user's permissions. App Sandbox is disabled because the app reads process usage and requests normal termination of selected apps. It installs no privileged helper and requests neither Accessibility nor Full Disk Access.

## Local packages

Run `make package`. The output in `artifacts/development/` contains an ad hoc signed app in a ZIP and a DMG with an Applications shortcut. Use these artifacts for local development. `diagnostics.json` verifies that the packaged executable can read process metrics without listing names or application paths.

## Public release

Before the first public release, choose the final bundle identifier, app name, support destination, and version. The current development identifier is `io.cosee.mac`; preserve the chosen identifier across releases so preferences and login items keep working.

Install a **Developer ID Application** signing certificate in your Keychain and create a notarization credential profile:

```sh
xcrun notarytool store-credentials cosee-notary
```

Enter credentials interactively. Do not put private keys or passwords into the repository. Then run:

```sh
COSEE_SIGN_ID='Developer ID Application: Your Name (TEAMID)' \
COSEE_NOTARY_PROFILE='cosee-notary' make release
```

The release command builds both architectures, signs with Hardened Runtime and a secure timestamp, verifies signatures, submits the app to Apple, staples its ticket, recreates the ZIP, builds and signs a DMG, notarizes and staples that image, and writes SHA-256 checksums. It stops on failed signing, notarization, or Gatekeeper assessment. Artifacts land in `artifacts/release/`; nothing is uploaded to a public hosting service.

For a rejected notarization request, use the submission ID in `app-notarization.json` or `dmg-notarization.json` to retrieve the log:

```sh
xcrun notarytool log SUBMISSION_ID --keychain-profile cosee-notary
```

Apple documents the requirements in [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Acceptance before publishing

- Download the notarized artifact through a browser on a separate Mac account or machine. Verify Gatekeeper accepts it and installation is a drag to Applications.
- Check macOS 26 and current macOS; check Intel hardware before advertising Intel runtime support.
- Compare CPU deltas and memory trends with Activity Monitor during idle and active work. Inspect grouped helpers and unassigned processes.
- Check normal quit, save dialogs, rejected quit requests, app relaunch, sleep/wake, dark/light appearance, and Korean/English labels.
- Measure Release-build CPU and memory overhead with the dashboard open and closed over at least 30 minutes.
- Verify Launch at Login after moving the app to Applications, quitting and logging in again. Test upgrades using the same bundle identifier.
- Verify privacy and license notices are available offline. Publish version notes, system requirements, checksums, and a support contact alongside the artifact.

## Updates and removal

The first version uses manual updates: quit Cosee, replace its app in Applications, and reopen it. Automatic updates require a separate signed update feed and are not yet implemented. To uninstall, disable Launch at Login, quit the app, and remove it from Applications. Users can remove preferences and imported custom data separately.
