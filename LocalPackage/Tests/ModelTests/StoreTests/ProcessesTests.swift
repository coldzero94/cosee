import AllocatedUnfairLock
import DataSource
import Testing
@testable import Model

struct ProcessesTests {
    @MainActor @Test func attention_summary_includes_unassigned_processes_in_all_scope() async {
        let store = Processes(.testDependencies())
        store.report = .init(
            timestamp: 1,
            applications: [
                .init(
                    id: .init(pid: 456, startMicroseconds: 100),
                    name: "Worker",
                    application: nil,
                    processCount: 1,
                    cpuPercent: 90,
                    footprintBytes: 100,
                    sustainedCPUSeconds: 65
                )
            ]
        )
        #expect(store.attentionCount == 0)
        await store.send(.scopeSelected(.all))
        #expect(store.attentionCount == 1)
    }

    @MainActor @Test func search_matches_helpers_and_distinguishes_loading_empty_and_error() async {
        let store = Processes(.testDependencies())
        #expect(store.listState == .loading)
        store.report = .init(timestamp: 1)
        #expect(store.listState == .empty)
        store.report.applications = [usage(history: [])]
        await store.send(.searchChanged("helper"))
        #expect(store.rows.count == 1)
        await store.send(.searchChanged("missing"))
        #expect(store.listState == .filteredEmpty)
        store.report.errorCode = 1
        #expect(store.listState == .unavailable)
    }

    @MainActor @Test func memory_growth_requires_two_minutes_significant_increase_and_complete_readings() {
        let store = Processes(.testDependencies())
        let gib: UInt64 = 1_024 * 1_024 * 1_024
        let points = [
            ProcessHistoryPoint(timestamp: 1, cpuPercent: 0, footprintBytes: gib),
            ProcessHistoryPoint(timestamp: 61, cpuPercent: 0, footprintBytes: gib + gib / 8),
            ProcessHistoryPoint(timestamp: 121, cpuPercent: 0, footprintBytes: gib + gib / 2),
        ]
        #expect(store.memoryGrowth(for: usage(history: points)) == gib / 2)
        #expect(store.insight(for: usage(history: points)) == .memoryGrowing)
        #expect(store.memoryGrowth(for: usage(history: Array(points.dropFirst()))) == nil)
        var partial = points
        partial[1].isMemoryComplete = false
        #expect(store.memoryGrowth(for: usage(history: partial)) == nil)
        var small = points
        small[2].footprintBytes = gib + gib / 8
        #expect(store.memoryGrowth(for: usage(history: small)) == nil)
        var gap = points
        gap[2].timestamp = 160
        #expect(store.memoryGrowth(for: usage(history: gap)) == nil)
    }

    private func usage(history: [ProcessHistoryPoint]) -> AppProcessUsage {
        .init(
            id: .init(pid: 123, startMicroseconds: 100),
            name: "Editor",
            application: .init(
                pid: 123,
                name: "Editor",
                bundleIdentifier: "test.editor",
                bundlePath: "/Applications/Editor.app"
            ),
            processCount: 1,
            cpuPercent: 0,
            footprintBytes: 1_024 * 1_024 * 1_024,
            members: [
                .init(
                    id: .init(pid: 124, startMicroseconds: 100),
                    name: "Editor Helper",
                    cpuPercent: 0,
                    footprintBytes: 1
                )
            ],
            history: history
        )
    }

    @MainActor @Test func quit_confirmation_survives_alert_dismissal_before_the_button_action() async {
        let requests = AllocatedUnfairLock<Int>(initialState: 0)
        let app = RunningAppDescriptor(
            pid: 123,
            name: "Editor",
            bundleIdentifier: "test.editor",
            bundlePath: "/Applications/Editor.app"
        )
        let store = Processes(
            .testDependencies(
                processSnapshotClient: .init(
                    read: { .init(timestamp: 0, samples: []) },
                    currentUserID: { 501 },
                    startMicroseconds: { _ in 100 }
                ),
                applicationControlClient: .init(
                    runningApplications: { [app] },
                    requestTermination: { _ in
                        requests.withLock { $0 += 1 }; return false
                    }
                )
            )
        )
        let usage = AppProcessUsage(
            id: .init(pid: 123, startMicroseconds: 100),
            name: "Editor",
            application: app,
            processCount: 1,
            cpuPercent: 90,
            footprintBytes: 100,
            canQuit: true
        )
        store.report = .init(applications: [usage])
        await store.send(.quitRequested(usage.id))
        await store.send(.confirmationDismissed)
        await store.send(.quitConfirmed)
        #expect(requests.withLock { $0 } == 1)
        #expect(store.quitResult == .requestRejected)
    }

    @MainActor @Test func insight_memory_candidate_requires_system_pressure_and_significant_usage() {
        let store = Processes(.testDependencies(), physicalMemory: 1000)
        let usage = AppProcessUsage(
            id: .init(pid: 123, startMicroseconds: 100),
            name: "Editor",
            application: nil,
            processCount: 1,
            cpuPercent: 0,
            footprintBytes: 200
        )
        store.report = .init(pressure: .normal)
        #expect(store.insight(for: usage) == .currentReading)
        store.report = .init(pressure: .warning)
        #expect(store.insight(for: usage) == .memoryPressure)
    }
}
