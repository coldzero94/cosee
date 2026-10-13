/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
import DataSource
import Foundation
import SystemInfoKit

public enum CoseeDiagnostics {
    enum ReadError: Error { case unavailable }

    #if DEBUG
    public static func injectRunnerCPU(percent: Double) -> Float? {
        RunnerService(.shared).updateRunnerSpeed(
            from: CPUInfo(
                percentage: .init(rawValue: percent / 100),
                system: .zero,
                user: .zero,
                idle: .zero
            )
        )
        return AppStateClient.liveValue.withLock(\.runnerSpeeds.latestValue)
    }
    #endif

    @MainActor
    public static func capture() throws -> Data {
        let client = ProcessSnapshotClient.liveValue
        let first = client.read()
        Thread.sleep(forTimeInterval: 0.15)
        let second = client.read()
        guard first.errorCode == 0, second.errorCode == 0,
            second.samples.contains(where: {
                $0.identity.pid == ProcessInfo.processInfo.processIdentifier && $0.cpuSeconds != nil
            })
        else {
            throw ReadError.unavailable
        }
        let applications = ApplicationControlClient.liveValue.runningApplications()
        var aggregation = ProcessAggregation()
        _ = aggregation.aggregate(
            first,
            applications: applications,
            userID: client.currentUserID(),
            ownPID: ProcessInfo.processInfo.processIdentifier
        )
        let report = aggregation.aggregate(
            second,
            applications: applications,
            userID: client.currentUserID(),
            ownPID: ProcessInfo.processInfo.processIdentifier
        )
        return try JSONSerialization.data(
            withJSONObject: [
                "macOS": ProcessInfo.processInfo.operatingSystemVersionString,
                "logicalCPUCount": ProcessInfo.processInfo.activeProcessorCount,
                "processesRead": second.samples.count,
                "currentUserProcesses": second.samples.filter { $0.userID == client.currentUserID() }.count,
                "usageAccessible": second.samples.filter { $0.cpuSeconds != nil }.count,
                "applicationGroups": report.applications.filter { $0.application != nil }.count,
                "groupsWithCPUDeltas": report.applications.filter { $0.cpuPercent != nil }.count,
                "memoryPressureLevel": second.pressure.rawValue,
            ],
            options: [.prettyPrinted, .sortedKeys]
        )
    }
}
