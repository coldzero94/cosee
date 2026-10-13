/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
import AppKit

public struct ApplicationControlClient: DependencyClient {
    public var runningApplications: @MainActor @Sendable () -> [RunningAppDescriptor]
    public var requestTermination: @MainActor @Sendable (Int32) -> Bool

    public init(
        runningApplications: @escaping @MainActor @Sendable () -> [RunningAppDescriptor],
        requestTermination: @escaping @MainActor @Sendable (Int32) -> Bool
    ) {
        self.runningApplications = runningApplications
        self.requestTermination = requestTermination
    }

    public static let liveValue = Self(
        runningApplications: {
            NSWorkspace.shared.runningApplications.map {
                RunningAppDescriptor(
                    pid: $0.processIdentifier,
                    name: $0.localizedName ?? $0.bundleIdentifier ?? "Application",
                    bundleIdentifier: $0.bundleIdentifier ?? "",
                    bundlePath: $0.bundleURL?.path ?? "",
                    isRegular: $0.activationPolicy == .regular,
                    isAccessory: $0.activationPolicy == .accessory,
                    isActive: $0.isActive
                )
            }
        },
        requestTermination: { NSRunningApplication(processIdentifier: $0)?.terminate() ?? false }
    )

    public static let testValue = Self(
        runningApplications: { [] },
        requestTermination: { _ in false }
    )
}
