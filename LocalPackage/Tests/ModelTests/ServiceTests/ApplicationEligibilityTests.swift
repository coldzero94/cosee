import DataSource
import Testing
@testable import Model

struct ApplicationEligibilityTests {
    func accessory(path: String, identifier: String = "test.menubar") -> RunningAppDescriptor {
        .init(
            pid: 10,
            name: "Menu Bar App",
            bundleIdentifier: identifier,
            bundlePath: path,
            isRegular: false,
            isAccessory: true
        )
    }

    @Test func recognizes_standalone_accessory_bundles() {
        #expect(ApplicationEligibility.recognizes(accessory(path: "/Applications/MenuBar.app")))
    }

    @Test func recognizes_excludes_embedded_helpers_missing_bundles_and_non_app_paths() {
        for path in ["", "/usr/bin/helper", "/Applications/Main.app/Contents/Frameworks/Helper.app"] {
            #expect(!ApplicationEligibility.recognizes(accessory(path: path)))
        }
        var prohibited = accessory(path: "/Applications/Agent.app")
        prohibited.isAccessory = false
        #expect(!ApplicationEligibility.recognizes(prohibited))
    }

    @Test func permits_quit_protects_system_menu_bar_apps_and_the_own_process() {
        let menuBarApp = accessory(path: "/Applications/MenuBar.app")
        #expect(ApplicationEligibility.permitsQuit(menuBarApp, ownPID: 99))
        #expect(!ApplicationEligibility.permitsQuit(menuBarApp, ownPID: 10))
        #expect(
            !ApplicationEligibility.permitsQuit(
                accessory(path: "/System/Library/CoreServices/Dock.app", identifier: "com.apple.dock"),
                ownPID: 99
            )
        )
    }

    @Test func permits_quit_protects_system_ui_identifiers_and_system_accessory_agents() {
        for identifier in ["com.apple.SystemUIServer", "com.apple.systemuiserver"] {
            #expect(
                !ApplicationEligibility.permitsQuit(
                    accessory(path: "/Applications/SystemUIServer.app", identifier: identifier),
                    ownPID: 99
                )
            )
        }
        #expect(
            !ApplicationEligibility.permitsQuit(
                accessory(
                    path: "/System/Library/CoreServices/WindowManager.app",
                    identifier: "com.apple.WindowManager"
                ),
                ownPID: 99
            )
        )
    }
}
