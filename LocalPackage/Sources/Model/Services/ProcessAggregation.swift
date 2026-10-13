/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
import DataSource
import Foundation

public struct ProcessAggregation: Sendable {
    private var previous: ProcessSnapshot?
    private var highCPUStarted = [ProcessIdentity: Double]()
    private var history = [ProcessIdentity: [ProcessHistoryPoint]]()

    public init() {}

    public mutating func reset() {
        previous = nil
        highCPUStarted.removeAll()
        history.removeAll()
    }

    public mutating func aggregate(
        _ snapshot: ProcessSnapshot,
        applications: [RunningAppDescriptor],
        userID: UInt32,
        ownPID: Int32
    ) -> ProcessReport {
        guard snapshot.errorCode == 0 else {
            reset()
            return .init(timestamp: snapshot.timestamp, pressure: snapshot.pressure, errorCode: snapshot.errorCode)
        }
        let byPID = Dictionary(
            snapshot.samples.map { ($0.identity.pid, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let recognizedApps = applications.filter(ApplicationEligibility.recognizes)
        let appsByPID = Dictionary(recognizedApps.map { ($0.pid, $0) }, uniquingKeysWith: { _, latest in latest })
        let previousByIdentity = Dictionary(
            (previous?.samples ?? []).map { ($0.identity, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let elapsed = snapshot.timestamp - (previous?.timestamp ?? snapshot.timestamp)
        let isContinuous = elapsed > 0 && elapsed <= 15
        if !isContinuous { history.removeAll() }
        var groups = [ProcessIdentity: (RunningAppDescriptor?, [ProcessUsage], Int)]()
        for sample in snapshot.samples {
            let application = owner(
                of: sample,
                processes: byPID,
                applications: recognizedApps,
                appsByPID: appsByPID,
                userID: userID
            )
            let identity = application.flatMap { byPID[$0.pid]?.identity } ?? sample.identity
            var cpuPercent: Double?
            if isContinuous, let prior = previousByIdentity[sample.identity],
                let currentTime = sample.cpuSeconds, let priorTime = prior.cpuSeconds,
                currentTime >= priorTime
            {
                cpuPercent = (currentTime - priorTime) / elapsed * 100
            }
            let member = ProcessUsage(
                id: sample.identity,
                name: sample.name,
                cpuPercent: cpuPercent,
                footprintBytes: sample.footprintBytes
            )
            var group = groups[identity] ?? (application, [], 0)
            group.1.append(member)
            if sample.cpuSeconds == nil || sample.footprintBytes == nil { group.2 += 1 }
            groups[identity] = group
        }
        var rows = [AppProcessUsage]()
        var nextStarts = [ProcessIdentity: Double]()
        var nextHistory = [ProcessIdentity: [ProcessHistoryPoint]]()
        for (identity, group) in groups {
            let cpuValues = group.1.compactMap(\.cpuPercent)
            let memoryValues = group.1.compactMap(\.footprintBytes)
            let cpu = cpuValues.isEmpty ? nil : cpuValues.reduce(0, +)
            var sustained: Double = 0
            if isContinuous, let cpu, cpu >= 80 {
                let start = highCPUStarted[identity] ?? snapshot.timestamp
                nextStarts[identity] = start
                sustained = max(0, snapshot.timestamp - start)
            }
            let root = byPID[identity.pid]
            let memory = memoryValues.isEmpty ? nil : memoryValues.reduce(0, +)
            var points = (history[identity] ?? []).filter { $0.timestamp >= snapshot.timestamp - 300 }
            points.append(
                .init(
                    timestamp: snapshot.timestamp,
                    cpuPercent: cpu,
                    footprintBytes: memory,
                    isMemoryComplete: group.2 == 0 && memory != nil
                )
            )
            nextHistory[identity] = points
            let canQuit =
                group.0.map {
                    ApplicationEligibility.permitsQuit($0, ownPID: ownPID) && root?.userID == userID
                        && identity.startMicroseconds != 0
                } ?? false
            rows.append(
                AppProcessUsage(
                    id: identity,
                    name: group.0?.name ?? root?.name ?? "Process",
                    application: group.0,
                    processCount: group.1.count,
                    cpuPercent: cpu,
                    footprintBytes: memory,
                    unavailableCount: group.2,
                    sustainedCPUSeconds: sustained,
                    canQuit: canQuit,
                    members: group.1.sorted { ($0.cpuPercent ?? -1) > ($1.cpuPercent ?? -1) },
                    hasPartialCPU: cpuValues.count != group.1.count,
                    history: points
                )
            )
        }
        previous = snapshot
        highCPUStarted = nextStarts
        history = nextHistory
        return .init(timestamp: snapshot.timestamp, applications: rows, pressure: snapshot.pressure)
    }

    private func owner(
        of sample: ProcessSample,
        processes: [Int32: ProcessSample],
        applications: [RunningAppDescriptor],
        appsByPID: [Int32: RunningAppDescriptor],
        userID: UInt32
    ) -> RunningAppDescriptor? {
        guard sample.userID == userID else { return nil }
        if let direct = appsByPID[sample.identity.pid] { return direct }
        var current = sample
        var visited = Set<Int32>()
        while current.parentPID > 1, visited.insert(current.identity.pid).inserted {
            guard let parent = processes[current.parentPID], parent.userID == userID,
                parent.identity.startMicroseconds <= current.identity.startMicroseconds
            else { break }
            if let application = appsByPID[parent.identity.pid] { return application }
            current = parent
        }
        let matches = applications.filter { app in
            !app.bundlePath.isEmpty && sample.executablePath.hasPrefix(app.bundlePath + "/")
                && processes[app.pid]?.userID == userID
        }
        guard let longestPath = matches.map(\.bundlePath.count).max() else { return nil }
        let mostSpecific = matches.filter { $0.bundlePath.count == longestPath }
        return mostSpecific.count == 1 ? mostSpecific[0] : nil
    }
}
