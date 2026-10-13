/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
import DataSource
import Foundation

public enum TerminationResult: Equatable, Sendable {
    case exited
    case stillRunning
    case requestRejected
    case noLongerMatches
    case notAllowed
}

@MainActor
public struct ApplicationTerminationService {
    private let processClient: ProcessSnapshotClient
    private let applicationClient: ApplicationControlClient

    public init(_ dependencies: AppDependencies) {
        processClient = dependencies.processSnapshotClient
        applicationClient = dependencies.applicationControlClient
    }

    public func requestQuit(_ usage: AppProcessUsage) -> TerminationResult? {
        guard usage.canQuit, let application = usage.application,
            application.pid == usage.id.pid, usage.id.startMicroseconds != 0,
            ApplicationEligibility.permitsQuit(application, ownPID: ProcessInfo.processInfo.processIdentifier)
        else { return .notAllowed }
        guard processClient.startMicroseconds(application.pid) == usage.id.startMicroseconds,
            let live = applicationClient.runningApplications().first(where: { $0.pid == application.pid }),
            ApplicationEligibility.permitsQuit(live, ownPID: ProcessInfo.processInfo.processIdentifier),
            live.bundleIdentifier == application.bundleIdentifier,
            live.bundlePath == application.bundlePath
        else { return .noLongerMatches }
        guard applicationClient.requestTermination(application.pid) else { return .requestRejected }
        return nil
    }

    public func checkQuit(_ usage: AppProcessUsage) -> TerminationResult {
        guard let application = usage.application else { return .notAllowed }
        let start = processClient.startMicroseconds(application.pid)
        if start == 0 {
            return applicationClient.runningApplications().contains(where: { $0.pid == application.pid })
                ? .stillRunning : .exited
        }
        return start != usage.id.startMicroseconds ? .exited : .stillRunning
    }
}
