/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
import SwiftUI

public struct PrivacyWindowScene: Scene {
    public init() {}

    public var body: some Scene {
        WindowGroup(id: "privacy", for: Int.self) { _ in
            LocalDocumentView(
                resource: String(localized: "processes.privacyResource", bundle: .module),
                titleKey: "processes.privacy"
            )
        } defaultValue: {
            .zero
        }
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)
    }
}
