/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
import DataSource
import Foundation

public actor ProcessMonitorService {
    private let processClient: ProcessSnapshotClient
    private let applicationClient: ApplicationControlClient
    private let appStateClient: AppStateClient
    private let preferences: UserDefaultsRepository
    private var aggregation = ProcessAggregation()
    private var monitoringTask: Task<Void, Never>?

    public init(_ dependencies: AppDependencies) {
        processClient = dependencies.processSnapshotClient
        applicationClient = dependencies.applicationControlClient
        appStateClient = dependencies.appStateClient
        preferences = .init(dependencies.userDefaultsClient)
    }

    public func startMonitoring() {
        guard monitoringTask == nil else { return }
        aggregation.reset()
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.capture()
                guard let seconds = await self?.samplingInterval else { return }
                do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            }
        }
    }

    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        aggregation.reset()
    }

    private var samplingInterval: Int { preferences.updateInterval.seconds }

    private func capture() async {
        let applications = await applicationClient.runningApplications()
        guard !Task.isCancelled else { return }
        let snapshot = processClient.read()
        let report = aggregation.aggregate(
            snapshot,
            applications: applications,
            userID: processClient.currentUserID(),
            ownPID: ProcessInfo.processInfo.processIdentifier
        )
        appStateClient.send(\.processReports, report)
    }
}
