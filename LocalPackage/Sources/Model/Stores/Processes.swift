/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
import DataSource
import Foundation
import Observation

public enum ProcessSort: Hashable, Sendable { case cpu, memory }
public enum ProcessScope: Hashable, Sendable { case applications, all }
public enum ProcessInsight: Sendable { case sustainedCPU, memoryPressure, memoryGrowing, partial, currentReading }
public enum ProcessListState: Sendable { case loading, unavailable, empty, filteredEmpty, ready }

@MainActor @Observable
public final class Processes: Composable {
    private let appStateClient: AppStateClient
    private let terminationService: ApplicationTerminationService
    private let physicalMemory: UInt64
    @ObservationIgnored private var observingTask: Task<Void, Never>?
    @ObservationIgnored private var terminationTask: Task<Void, Never>?

    public var report = ProcessReport()
    public var sort = ProcessSort.cpu
    public var scope = ProcessScope.applications
    public var searchQuery = ""
    public var showsAllRows = false
    public var showsMeasurementDetails = false
    public var pendingQuit: AppProcessUsage?
    public var confirmationVisible = false
    public var quitInFlight = false
    public var quitName = ""
    public var quitResult: TerminationResult?
    public var expanded = Set<ProcessIdentity>()
    public let action: (Action) async -> Void

    public var rows: [AppProcessUsage] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = report.applications.filter {
            (scope == .all || $0.application != nil)
                && (query.isEmpty || $0.name.localizedStandardContains(query)
                    || $0.members.contains(where: { $0.name.localizedStandardContains(query) }))
        }
        return filtered.sorted { lhs, rhs in
            switch sort {
            case .cpu:
                if lhs.cpuPercent != rhs.cpuPercent { return (lhs.cpuPercent ?? -1) > (rhs.cpuPercent ?? -1) }
            case .memory:
                if lhs.footprintBytes != rhs.footprintBytes {
                    return (lhs.footprintBytes ?? 0) > (rhs.footprintBytes ?? 0)
                }
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    public var visibleRows: [AppProcessUsage] { showsAllRows ? rows : Array(rows.prefix(8)) }
    public var hiddenRowCount: Int { max(0, rows.count - visibleRows.count) }
    public var unassignedCPUPercent: Double {
        report.applications.filter { $0.application == nil }.compactMap(\.cpuPercent).reduce(0, +)
    }
    public var listState: ProcessListState {
        if report.errorCode != 0 { return .unavailable }
        if report.timestamp == 0 { return .loading }
        if rows.isEmpty { return searchQuery.isEmpty ? .empty : .filteredEmpty }
        return .ready
    }
    public var attentionCount: Int {
        rows.filter {
            switch insight(for: $0) {
            case .sustainedCPU, .memoryPressure, .memoryGrowing: return true
            case .partial, .currentReading: return false
            }
        }.count
    }

    public func memoryGrowth(for usage: AppProcessUsage) -> UInt64? {
        guard let latest = usage.history.last, latest.isMemoryComplete,
            let current = latest.footprintBytes,
            let earlier = usage.history.last(where: { $0.timestamp <= latest.timestamp - 120 }),
            latest.timestamp - earlier.timestamp <= 135, earlier.isMemoryComplete,
            let baseline = earlier.footprintBytes, current >= baseline,
            usage.history.filter({ $0.timestamp >= earlier.timestamp }).allSatisfy(\.isMemoryComplete)
        else { return nil }
        let increase = current - baseline
        return increase >= 256 * 1_024 * 1_024 && Double(increase) >= Double(baseline) * 0.2 ? increase : nil
    }

    public init(
        _ dependencies: AppDependencies,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
        action: @escaping (Action) async -> Void = { _ in }
    ) {
        appStateClient = dependencies.appStateClient
        terminationService = .init(dependencies)
        self.physicalMemory = physicalMemory
        self.action = action
    }

    public func insight(for usage: AppProcessUsage) -> ProcessInsight {
        if usage.sustainedCPUSeconds >= 60 { return .sustainedCPU }
        if report.pressure == .warning || report.pressure == .critical,
            let bytes = usage.footprintBytes, Double(bytes) >= Double(physicalMemory) * 0.1
        {
            return .memoryPressure
        }
        if memoryGrowth(for: usage) != nil { return .memoryGrowing }
        if usage.unavailableCount > 0 || usage.hasPartialCPU { return .partial }
        return .currentReading
    }

    public func reduce(_ action: Action) async {
        switch action {
        case .viewAppeared:
            if let latest = appStateClient.withLock(\.processReports.latestValue) { report = latest }
            observingTask?.cancel()
            observingTask = Task { [weak self, appStateClient] in
                let stream = appStateClient.withLock(\.processReports.stream)
                for await value in stream {
                    guard !Task.isCancelled else { return }
                    self?.report = value
                }
            }
        case .viewDisappeared:
            observingTask?.cancel()
            observingTask = nil
        case let .sortSelected(value): sort = value
        case let .scopeSelected(value): scope = value
        case let .searchChanged(value): searchQuery = value
        case .showAllRows: showsAllRows = true
        case let .measurementDetailsToggled(value): showsMeasurementDetails = value
        case let .expansionChanged(identity, isExpanded):
            if isExpanded { expanded.insert(identity) } else { expanded.remove(identity) }
        case let .quitRequested(identity):
            guard !quitInFlight, let usage = report.applications.first(where: { $0.id == identity }), usage.canQuit
            else { return }
            pendingQuit = usage
            confirmationVisible = true
        case .quitCancelled:
            pendingQuit = nil
            confirmationVisible = false
        case .confirmationDismissed: confirmationVisible = false
        case .quitConfirmed:
            guard !quitInFlight, let usage = pendingQuit else { return }
            pendingQuit = nil
            confirmationVisible = false
            quitName = usage.name
            quitResult = nil
            if let result = terminationService.requestQuit(usage) {
                quitResult = result
                return
            }
            quitInFlight = true
            terminationTask = Task { [weak self, terminationService] in
                for _ in 0..<6 {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    if terminationService.checkQuit(usage) == .exited {
                        self?.quitResult = .exited
                        self?.quitInFlight = false
                        return
                    }
                }
                self?.quitResult = .stillRunning
                self?.quitInFlight = false
            }
        }
    }

    public enum Action: Sendable {
        case viewAppeared
        case viewDisappeared
        case sortSelected(ProcessSort)
        case scopeSelected(ProcessScope)
        case searchChanged(String)
        case showAllRows
        case measurementDetailsToggled(Bool)
        case expansionChanged(ProcessIdentity, Bool)
        case quitRequested(ProcessIdentity)
        case quitCancelled
        case confirmationDismissed
        case quitConfirmed
    }
}
