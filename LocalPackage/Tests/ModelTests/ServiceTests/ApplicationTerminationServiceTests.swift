import AllocatedUnfairLock
import DataSource
import Foundation
import Testing
@testable import Model

struct ApplicationTerminationServiceTests {
    let app = RunningAppDescriptor(
        pid: 123,
        name: "Editor",
        bundleIdentifier: "test.editor",
        bundlePath: "/Applications/Editor.app"
    )

    var usage: AppProcessUsage {
        .init(
            id: .init(pid: 123, startMicroseconds: 100),
            name: "Editor",
            application: app,
            processCount: 1,
            cpuPercent: 90,
            footprintBytes: 100,
            canQuit: true
        )
    }

    @MainActor @Test func requestQuit_does_not_terminate_a_reused_pid() {
        let requests = AllocatedUnfairLock<Int>(initialState: 0)
        let app = app
        let service = ApplicationTerminationService(
            .testDependencies(
                processSnapshotClient: .init(
                    read: { .init(timestamp: 0, samples: []) },
                    currentUserID: { 501 },
                    startMicroseconds: { _ in 200 }
                ),
                applicationControlClient: .init(
                    runningApplications: { [app] },
                    requestTermination: { _ in
                        requests.withLock { $0 += 1 }; return true
                    }
                )
            )
        )
        #expect(service.requestQuit(usage) == .noLongerMatches)
        #expect(requests.withLock { $0 } == 0)
    }

    @MainActor @Test func requestQuit_acceptance_does_not_report_success_before_exit() {
        let app = app
        let service = ApplicationTerminationService(
            .testDependencies(
                processSnapshotClient: .init(
                    read: { .init(timestamp: 0, samples: []) },
                    currentUserID: { 501 },
                    startMicroseconds: { _ in 100 }
                ),
                applicationControlClient: .init(runningApplications: { [app] }, requestTermination: { _ in true })
            )
        )
        #expect(service.requestQuit(usage) == nil)
        #expect(service.checkQuit(usage) == .stillRunning)
    }

    @MainActor @Test func checkQuit_missing_read_permission_is_not_mistaken_for_exit() {
        let app = app
        let service = ApplicationTerminationService(
            .testDependencies(
                applicationControlClient: .init(runningApplications: { [app] }, requestTermination: { _ in false })
            )
        )
        #expect(service.checkQuit(usage) == .stillRunning)
    }

    @MainActor @Test func requestQuit_protected_application_is_rejected_even_with_a_stale_allowed_flag() {
        var candidate = usage
        candidate.application?.bundleIdentifier = "com.apple.finder"
        #expect(ApplicationTerminationService(.testDependencies()).requestQuit(candidate) == .notAllowed)
    }

    @MainActor @Test func requestQuit_accepts_standalone_menu_bar_apps_after_live_identity_checks() throws {
        var candidate = usage
        candidate.application?.isRegular = false
        candidate.application?.isAccessory = true
        let menuBarApp = try #require(candidate.application)
        let requests = AllocatedUnfairLock<Int>(initialState: 0)
        let service = ApplicationTerminationService(
            .testDependencies(
                processSnapshotClient: .init(
                    read: { .init(timestamp: 0, samples: []) },
                    currentUserID: { 501 },
                    startMicroseconds: { _ in 100 }
                ),
                applicationControlClient: .init(
                    runningApplications: { [menuBarApp] },
                    requestTermination: { _ in
                        requests.withLock { $0 += 1 }
                        return true
                    }
                )
            )
        )
        #expect(service.requestQuit(candidate) == nil)
        #expect(requests.withLock { $0 } == 1)
    }

    @MainActor @Test func requestQuit_rejects_embedded_helpers_even_with_a_stale_allowed_flag() {
        var candidate = usage
        candidate.application?.isRegular = false
        candidate.application?.isAccessory = true
        candidate.application?.bundlePath = "/Applications/Editor.app/Contents/Frameworks/Helper.app"
        #expect(ApplicationTerminationService(.testDependencies()).requestQuit(candidate) == .notAllowed)
    }
}
