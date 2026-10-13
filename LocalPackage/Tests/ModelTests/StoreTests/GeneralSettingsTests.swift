import AllocatedUnfairLock
import Foundation
import Testing

@testable import DataSource
@testable import Model

struct GeneralSettingsTests {
    @MainActor @Test
    func send_updateIntervalPickerSelected_persists_and_restarts_monitoring() async {
        let setCallStack = AllocatedUnfairLock<[String]>(initialState: [])
        let monitoringEvents = AllocatedUnfairLock<[String]>(initialState: [])
        let sut = GeneralSettings(
            .testDependencies(
                systemInfoObserverClient: testDependency(of: SystemInfoObserverClient.self) {
                    $0.stopMonitoring = {
                        monitoringEvents.withLock { $0.append("stop") }
                    }
                    $0.startMonitoring = { interval in
                        monitoringEvents.withLock { $0.append("start: \(interval)") }
                    }
                },
                userDefaultsClient: testDependency(of: UserDefaultsClient.self) {
                    $0.integer = { _ in 3 }
                    $0.set = { value, key in
                        let entry = "set: \(key) = \(value ?? "nil")"
                        setCallStack.withLock { $0.append(entry) }
                    }
                }
            )
        )
        await sut.send(.updateIntervalPickerSelected(.threeSeconds))
        #expect(sut.updateInterval == .threeSeconds)
        #expect(setCallStack.withLock(\.self) == ["set: UPDATE_INTERVAL = 3"])
        #expect(monitoringEvents.withLock(\.self) == ["stop", "start: 3.0"])
    }

    @MainActor @Test
    func send_launchAtLoginToggleSwitched_enables_when_register_succeeds() async {
        let registered = AllocatedUnfairLock(initialState: false)
        let sut = GeneralSettings(
            .testDependencies(
                smAppServiceClient: testDependency(of: SMAppServiceClient.self) {
                    $0.status = { registered.withLock(\.self) ? .enabled : .notRegistered }
                    $0.register = { registered.withLock { $0 = true } }
                }
            )
        )
        await sut.send(.launchAtLoginToggleSwitched(true))
        #expect(sut.launchesAtLogin)
        #expect(sut.launchAtLoginNotice == nil)
    }

    @MainActor @Test
    func send_launchAtLoginToggleSwitched_keeps_actual_status_when_register_fails() async {
        let sut = GeneralSettings(
            .testDependencies(
                smAppServiceClient: testDependency(of: SMAppServiceClient.self) {
                    $0.status = { .notRegistered }
                    $0.register = { throw URLError(.unknown) }
                }
            )
        )
        await sut.send(.launchAtLoginToggleSwitched(true))
        #expect(!sut.launchesAtLogin)
        #expect(sut.launchAtLoginNotice == .operationFailed)
    }

    @MainActor @Test
    func send_launchAtLoginToggleSwitched_explains_approval_pending_without_claiming_enabled() async {
        let registered = AllocatedUnfairLock(initialState: false)
        let sut = GeneralSettings(
            .testDependencies(
                smAppServiceClient: testDependency(of: SMAppServiceClient.self) {
                    $0.status = { registered.withLock(\.self) ? .requiresApproval : .notRegistered }
                    $0.register = { registered.withLock { $0 = true } }
                }
            )
        )
        await sut.send(.launchAtLoginToggleSwitched(true))
        #expect(!sut.launchesAtLogin)
        #expect(sut.launchAtLoginNotice == .approvalRequired)
    }

    @MainActor @Test
    func send_refreshLaunchAtLoginStatus_detects_approval_granted_in_system_settings() async {
        let approved = AllocatedUnfairLock(initialState: false)
        let sut = GeneralSettings(
            .testDependencies(
                smAppServiceClient: testDependency(of: SMAppServiceClient.self) {
                    $0.status = { approved.withLock(\.self) ? .enabled : .requiresApproval }
                }
            )
        )
        #expect(sut.launchAtLoginNotice == .approvalRequired)
        approved.withLock { $0 = true }
        await sut.send(.refreshLaunchAtLoginStatus)
        #expect(sut.launchesAtLogin)
        #expect(sut.launchAtLoginNotice == nil)
    }

    @MainActor @Test
    func send_viewAppeared_detects_login_item_disabled_in_system_settings() async {
        let enabled = AllocatedUnfairLock(initialState: true)
        let sut = GeneralSettings(
            .testDependencies(
                smAppServiceClient: testDependency(of: SMAppServiceClient.self) {
                    $0.status = { enabled.withLock(\.self) ? .enabled : .notRegistered }
                }
            )
        )
        enabled.withLock { $0 = false }
        await sut.send(.viewAppeared("GeneralSettingsView"))
        #expect(!sut.launchesAtLogin)
        #expect(sut.launchAtLoginNotice == nil)
    }

    @MainActor @Test
    func send_launchAtLoginToggleSwitched_explains_failed_disable_and_preserves_enabled_status() async {
        let sut = GeneralSettings(
            .testDependencies(
                smAppServiceClient: testDependency(of: SMAppServiceClient.self) {
                    $0.status = { .enabled }
                    $0.unregister = { throw URLError(.unknown) }
                }
            )
        )
        await sut.send(.launchAtLoginToggleSwitched(false))
        #expect(sut.launchesAtLogin)
        #expect(sut.launchAtLoginNotice == .operationFailed)
    }

    @MainActor @Test
    func send_openLoginItemsSettings_opens_settings_through_dependency() async {
        let calls = AllocatedUnfairLock(initialState: 0)
        let sut = GeneralSettings(
            .testDependencies(
                smAppServiceClient: testDependency(of: SMAppServiceClient.self) {
                    $0.openLoginItemsSettings = { calls.withLock { $0 += 1 } }
                }
            )
        )
        await sut.send(.openLoginItemsSettings)
        #expect(calls.withLock(\.self) == 1)
    }
}
