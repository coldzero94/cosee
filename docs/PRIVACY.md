# Privacy

Cosee also displays system CPU load, memory, storage capacity, battery status, and local network status.

Cosee reads process names, identifiers, application paths, CPU counters, and memory footprint locally to show resource use. Recent readings are held in memory for up to five minutes and cleared when the app quits. They are not uploaded or written to diagnostic logs. There are no accounts, analytics, cloud processing, or automatic updates.

Preferences use `io.cosee.mac`. Imported custom runners are stored in `~/Library/Application Support/Cosee`. Custom metrics read the local JSON files selected by the user.

App termination requires an explicit selection and confirmation. Cosee requests a normal quit; the selected app may ask to save work or decline the request. External links open only after a user action and follow the destination website's policies.

The optional `--diagnose` command prints aggregate measurement availability, not process names or paths. Users choose whether to share its output.

This notice describes the current source. Review it when adding networking, crash reporting, updates, or new storage behavior. An offline copy is available through the app's Privacy menu.
