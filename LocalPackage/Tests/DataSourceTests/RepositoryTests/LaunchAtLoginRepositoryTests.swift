import AllocatedUnfairLock
import ServiceManagement
import Testing

@testable import DataSource

struct LaunchAtLoginRepositoryTests {
    @Test
    func switchStatus_reports_required_approval_after_registration() {
        let client = testDependency(of: SMAppServiceClient.self) {
            $0.status = { .requiresApproval }
        }
        let sut = LaunchAtLoginRepository(client)
        #expect(sut.status == .requiresApproval)
        #expect(!sut.isEnabled)
        #expect(throws: LaunchAtLoginRepository.OperationError.requiresApproval) {
            try sut.switchStatus(true).get()
        }
    }

    @Test
    func switchStatus_reports_failure_when_registration_does_not_enable_login_item() {
        let client = testDependency(of: SMAppServiceClient.self) {
            $0.status = { .notRegistered }
        }
        let sut = LaunchAtLoginRepository(client)
        #expect(throws: LaunchAtLoginRepository.OperationError.switchFailed(false)) {
            try sut.switchStatus(true).get()
        }
    }

    @Test
    func openLoginItemsSettings_opens_settings_through_dependency() {
        let calls = AllocatedUnfairLock(initialState: 0)
        let client = testDependency(of: SMAppServiceClient.self) {
            $0.openLoginItemsSettings = { calls.withLock { $0 += 1 } }
        }
        LaunchAtLoginRepository(client).openLoginItemsSettings()
        #expect(calls.withLock(\.self) == 1)
    }

    @Test
    func switchStatus_success_register() async {
        let status = AllocatedUnfairLock(initialState: false)
        let smAppServiceClient = testDependency(of: SMAppServiceClient.self) {
            $0.status = {
                status.withLock(\.self) ? .enabled : .notRegistered
            }
            $0.register = {
                status.withLock { $0 = true }
            }
        }
        let sut = LaunchAtLoginRepository(smAppServiceClient)
        #expect(throws: Never.self) {
            try sut.switchStatus(true).get()
        }
    }

    @Test
    func switchStatus_success_unregister() async {
        let status = AllocatedUnfairLock(initialState: true)
        let smAppServiceClient = testDependency(of: SMAppServiceClient.self) {
            $0.status = {
                status.withLock(\.self) ? .enabled : .notRegistered
            }
            $0.unregister = {
                status.withLock { $0 = false }
            }
        }
        let sut = LaunchAtLoginRepository(smAppServiceClient)
        #expect(throws: Never.self) {
            try sut.switchStatus(false).get()
        }
    }

    @Test
    func switchStatus_failure_register() async {
        let status = AllocatedUnfairLock(initialState: false)
        let smAppServiceClient = testDependency(of: SMAppServiceClient.self) {
            $0.status = {
                status.withLock(\.self) ? .enabled : .notRegistered
            }
            $0.register = {
                throw NSError(
                    domain: SMAppServiceErrorDomain,
                    code: kSMErrorAuthorizationFailure
                )
            }
        }
        let sut = LaunchAtLoginRepository(smAppServiceClient)
        #expect(throws: LaunchAtLoginRepository.OperationError.switchFailed(false)) {
            try sut.switchStatus(true).get()
        }
    }

    @Test
    func switchStatus_failure_unregister() async {
        let status = AllocatedUnfairLock(initialState: true)
        let smAppServiceClient = testDependency(of: SMAppServiceClient.self) {
            $0.status = {
                status.withLock(\.self) ? .enabled : .notRegistered
            }
            $0.unregister = {
                throw NSError(
                    domain: SMAppServiceErrorDomain,
                    code: kSMErrorAuthorizationFailure
                )
            }
        }
        let sut = LaunchAtLoginRepository(smAppServiceClient)
        #expect(throws: LaunchAtLoginRepository.OperationError.switchFailed(true)) {
            try sut.switchStatus(false).get()
        }
    }
}
