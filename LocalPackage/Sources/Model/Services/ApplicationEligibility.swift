/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
import DataSource
import Foundation

enum ApplicationEligibility {
    private static let protectedBundles: Set<String> = [
        "com.apple.finder",
        "com.apple.loginwindow",
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.controlcenter",
    ]

    static func recognizes(_ application: RunningAppDescriptor) -> Bool {
        if application.isRegular { return true }
        guard application.isAccessory else { return false }
        let components = URL(fileURLWithPath: application.bundlePath).standardized.pathComponents
        return components.last?.hasSuffix(".app") == true
            && !components.dropLast().contains(where: { $0.hasSuffix(".app") })
    }

    static func permitsQuit(_ application: RunningAppDescriptor, ownPID: Int32) -> Bool {
        recognizes(application) && application.pid != ownPID
            && !protectedBundles.contains(application.bundleIdentifier.lowercased())
            && !(application.isAccessory && application.bundlePath.hasPrefix("/System/Library/"))
    }
}
