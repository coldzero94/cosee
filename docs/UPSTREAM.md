# Upstream baseline

This repository imports RunCat Neo from https://github.com/runcat-dev/RunCatNeo at commit `b3b1543049ea0a051ecb78654a45f144724ea737`.

The Xcode project and app shell have been renamed to Cosee. The original layered Swift package, runner artwork, system dashboard, settings, custom metrics and existing tests form the baseline. Original copyright and Apache-2.0 notices are retained. Files modified for Cosee carry a modification notice.

Cosee adds a native process boundary, app attribution, CPU deltas, partial-measurement handling, five-minute history, resource insights, and confirmed normal termination. It replaces the upstream donation integration and license-generation plugin with offline attribution and privacy resources, independent application identity, and local build and distribution scripts.

Upstream's `DataSource → Model → UserInterface` layering is retained. `ProcessBridge` is a leaf C target used by `DataSource`. Real counter-unit and permission checks live in `ProcessSnapshotIntegrationTests`; grouping and termination behavior use deterministic fixtures and mocked effects. The tests do not quit applications on the developer's Mac.

When updating the baseline, review upstream changes before importing, preserve Cosee's bundle identity and support paths, regenerate dependency notices, and run the tests and package build.
