import DataSource
import Foundation
import Testing
@testable import Model

struct ProcessAggregationTests {
    let app = RunningAppDescriptor(
        pid: 10,
        name: "Editor",
        bundleIdentifier: "test.editor",
        bundlePath: "/Applications/Editor.app"
    )

    func sample(
        _ pid: Int32,
        parent: Int32 = 1,
        start: UInt64 = 100,
        uid: UInt32 = 501,
        path: String = "",
        cpu: Double? = 0,
        memory: UInt64? = 100
    ) -> ProcessSample {
        .init(
            identity: .init(pid: pid, startMicroseconds: start),
            parentPID: parent,
            userID: uid,
            name: "Process",
            executablePath: path,
            cpuSeconds: cpu,
            footprintBytes: memory
        )
    }

    @Test func aggregate_groups_descendants_and_helpers_by_bundle_path() throws {
        var aggregation = ProcessAggregation()
        let processes = [
            sample(10), sample(11, parent: 10), sample(12, path: "/Applications/Editor.app/Contents/Frameworks/Helper"),
        ]
        let report = aggregation.aggregate(
            .init(timestamp: 1, samples: processes),
            applications: [app],
            userID: 501,
            ownPID: 99
        )
        let row = try #require(report.applications.first)
        #expect(report.applications.count == 1)
        #expect(row.processCount == 3)
        #expect(row.footprintBytes == 300)
        #expect(row.cpuPercent == nil)
        #expect(row.canQuit)
        let initialPoint = try #require(row.history.last)
        #expect(initialPoint.isMemoryComplete)
    }

    @Test func aggregate_uses_cpu_deltas_instead_of_process_lifetime_average() throws {
        var aggregation = ProcessAggregation()
        _ = aggregation.aggregate(
            .init(timestamp: 10, samples: [sample(10, cpu: 100)]),
            applications: [app],
            userID: 501,
            ownPID: 99
        )
        let row = try #require(
            aggregation.aggregate(
                .init(timestamp: 12, samples: [sample(10, cpu: 104)]),
                applications: [app],
                userID: 501,
                ownPID: 99
            ).applications.first
        )
        #expect(row.cpuPercent == 200)
        #expect(!row.hasPartialCPU)
    }

    @Test func aggregate_pid_reuse_starts_a_new_measurement() throws {
        var aggregation = ProcessAggregation()
        _ = aggregation.aggregate(
            .init(timestamp: 10, samples: [sample(10, start: 100, cpu: 100)]),
            applications: [app],
            userID: 501,
            ownPID: 99
        )
        let row = try #require(
            aggregation.aggregate(
                .init(timestamp: 12, samples: [sample(10, start: 200, cpu: 1)]),
                applications: [app],
                userID: 501,
                ownPID: 99
            ).applications.first
        )
        #expect(row.cpuPercent == nil)
        #expect(row.history.count == 1)
        #expect(row.sustainedCPUSeconds == 0)
    }

    @Test func aggregate_partial_readings_are_identified_as_partial() throws {
        var aggregation = ProcessAggregation()
        _ = aggregation.aggregate(
            .init(timestamp: 1, samples: [sample(10), sample(11, parent: 10, cpu: nil, memory: nil)]),
            applications: [app],
            userID: 501,
            ownPID: 99
        )
        let row = try #require(
            aggregation.aggregate(
                .init(timestamp: 4, samples: [sample(10, cpu: 3), sample(11, parent: 10, cpu: nil, memory: nil)]),
                applications: [app],
                userID: 501,
                ownPID: 99
            ).applications.first
        )
        #expect(row.cpuPercent == 100)
        #expect(row.footprintBytes == 100)
        #expect(row.unavailableCount == 1)
        let partialPoint = try #require(row.history.last)
        #expect(!partialPoint.isMemoryComplete)
        #expect(row.hasPartialCPU)
        #expect(row.sustainedCPUSeconds == 0)
    }

    @Test func aggregate_does_not_group_different_users_or_similar_path_prefixes() {
        var aggregation = ProcessAggregation()
        let processes = [
            sample(10), sample(11, parent: 10, uid: 0), sample(12, path: "/Applications/Editor.app.backup/Helper"),
        ]
        let report = aggregation.aggregate(
            .init(timestamp: 1, samples: processes),
            applications: [app],
            userID: 501,
            ownPID: 99
        )
        #expect(report.applications.count == 3)
        #expect(report.applications.filter(\.canQuit).count == 1)
    }

    @Test func aggregate_parent_cycles_remain_separate_processes() {
        var aggregation = ProcessAggregation()
        let report = aggregation.aggregate(
            .init(timestamp: 1, samples: [sample(11, parent: 12), sample(12, parent: 11)]),
            applications: [app],
            userID: 501,
            ownPID: 99
        )
        #expect(report.applications.count == 2)
        #expect(report.applications.allSatisfy { !$0.canQuit })
    }

    @Test func aggregate_sustained_cpu_requires_continuous_readings_and_resets_on_a_gap() throws {
        var aggregation = ProcessAggregation()
        for timestamp in stride(from: 0, through: 66, by: 3) {
            _ = aggregation.aggregate(
                .init(timestamp: Double(timestamp), samples: [sample(10, cpu: Double(timestamp))]),
                applications: [app],
                userID: 501,
                ownPID: 99
            )
        }
        let sustained = try #require(
            aggregation.aggregate(
                .init(timestamp: 69, samples: [sample(10, cpu: 69)]),
                applications: [app],
                userID: 501,
                ownPID: 99
            ).applications.first
        )
        #expect(sustained.sustainedCPUSeconds == 66)
        let afterGap = try #require(
            aggregation.aggregate(
                .init(timestamp: 100, samples: [sample(10, cpu: 100)]),
                applications: [app],
                userID: 501,
                ownPID: 99
            ).applications.first
        )
        #expect(afterGap.cpuPercent == nil)
        #expect(afterGap.sustainedCPUSeconds == 0)
        #expect(afterGap.history.count == 1)
    }

    @Test func aggregate_bounds_history_to_five_minutes() throws {
        var aggregation = ProcessAggregation()
        var report = ProcessReport()
        for timestamp in stride(from: 0, through: 600, by: 3) {
            report = aggregation.aggregate(
                .init(timestamp: Double(timestamp), samples: [sample(10, cpu: Double(timestamp))]),
                applications: [app],
                userID: 501,
                ownPID: 99
            )
        }
        let row = try #require(report.applications.first)
        #expect(row.history.count == 101)
        #expect(row.history.first?.timestamp == 300)
    }

    @Test func aggregate_protects_finder_and_its_own_application() throws {
        var aggregation = ProcessAggregation()
        let finder = RunningAppDescriptor(
            pid: 10,
            name: "Finder",
            bundleIdentifier: "com.apple.finder",
            bundlePath: "/System/Library/CoreServices/Finder.app"
        )
        let finderRow = try #require(
            aggregation.aggregate(
                .init(timestamp: 1, samples: [sample(10)]),
                applications: [finder],
                userID: 501,
                ownPID: 99
            ).applications.first
        )
        #expect(!finderRow.canQuit)
        let ownRow = try #require(
            aggregation.aggregate(
                .init(timestamp: 2, samples: [sample(10)]),
                applications: [app],
                userID: 501,
                ownPID: 10
            ).applications.first
        )
        #expect(!ownRow.canQuit)
    }

    @Test func aggregate_groups_standalone_menu_bar_apps_and_embedded_helpers() throws {
        let menuBarApp = RunningAppDescriptor(
            pid: 10,
            name: "Menu Bar App",
            bundleIdentifier: "test.menubar",
            bundlePath: "/Applications/MenuBar.app",
            isRegular: false,
            isAccessory: true
        )
        let helper = RunningAppDescriptor(
            pid: 11,
            name: "Helper",
            bundleIdentifier: "test.menubar.helper",
            bundlePath: "/Applications/MenuBar.app/Contents/Frameworks/Helper.app",
            isRegular: false,
            isAccessory: true
        )
        var aggregation = ProcessAggregation()
        let report = aggregation.aggregate(
            .init(
                timestamp: 1,
                samples: [
                    sample(10),
                    sample(11, parent: 10, path: helper.bundlePath + "/Contents/MacOS/Helper"),
                ]
            ),
            applications: [menuBarApp, helper],
            userID: 501,
            ownPID: 99
        )
        let row = try #require(report.applications.first)
        #expect(report.applications.count == 1)
        #expect(row.application == menuBarApp)
        #expect(row.processCount == 2)
        #expect(row.canQuit)
    }

    @Test func aggregate_menu_bar_apps_keep_user_and_self_quit_protection() throws {
        var menuBarApp = app
        menuBarApp.isRegular = false
        menuBarApp.isAccessory = true
        var aggregation = ProcessAggregation()
        let otherUser = aggregation.aggregate(
            .init(timestamp: 1, samples: [sample(10, uid: 502)]),
            applications: [menuBarApp],
            userID: 501,
            ownPID: 99
        )
        #expect(otherUser.applications.allSatisfy { !$0.canQuit && $0.application == nil })
        let own = aggregation.aggregate(
            .init(timestamp: 2, samples: [sample(10)]),
            applications: [menuBarApp],
            userID: 501,
            ownPID: 10
        )
        #expect(!(try #require(own.applications.first)).canQuit)
    }

    @Test func aggregate_prefers_parent_identity_for_multiple_instances_of_one_bundle() throws {
        var secondApp = app
        secondApp.pid = 20
        for applications in [[app, secondApp], [secondApp, app]] {
            var aggregation = ProcessAggregation()
            let report = aggregation.aggregate(
                .init(
                    timestamp: 1,
                    samples: [
                        sample(10), sample(20),
                        sample(21, parent: 20, path: app.bundlePath + "/Contents/Frameworks/Helper"),
                    ]
                ),
                applications: applications,
                userID: 501,
                ownPID: 99
            )
            let owner = try #require(report.applications.first { $0.members.contains { $0.id.pid == 21 } })
            #expect(owner.id.pid == 20)
            #expect(owner.processCount == 2)
        }
    }

    @Test func aggregate_leaves_ambiguous_bundle_instances_unassigned_without_parent_evidence() throws {
        var secondApp = app
        secondApp.pid = 20
        var aggregation = ProcessAggregation()
        let report = aggregation.aggregate(
            .init(
                timestamp: 1,
                samples: [
                    sample(10), sample(20),
                    sample(21, path: app.bundlePath + "/Contents/Frameworks/Helper"),
                ]
            ),
            applications: [app, secondApp],
            userID: 501,
            ownPID: 99
        )
        let helper = try #require(report.applications.first { $0.id.pid == 21 })
        #expect(helper.application == nil)
        #expect(!helper.canQuit)
    }

    @Test func aggregate_sustained_cpu_uses_a_high_measured_lower_bound_when_helpers_change() throws {
        var aggregation = ProcessAggregation()
        var report = ProcessReport()
        for timestamp in stride(from: 0, through: 69, by: 3) {
            report = aggregation.aggregate(
                .init(
                    timestamp: Double(timestamp),
                    samples: [
                        sample(10, cpu: Double(timestamp)),
                        sample(Int32(timestamp + 100), parent: 10),
                    ]
                ),
                applications: [app],
                userID: 501,
                ownPID: 99
            )
        }
        let row = try #require(report.applications.first)
        #expect(row.cpuPercent == 100)
        #expect(row.hasPartialCPU)
        #expect(row.sustainedCPUSeconds == 66)
    }

    @Test func aggregate_partial_cpu_below_the_threshold_resets_sustained_evidence() throws {
        var aggregation = ProcessAggregation()
        for timestamp in stride(from: 0, through: 69, by: 3) {
            _ = aggregation.aggregate(
                .init(timestamp: Double(timestamp), samples: [sample(10, cpu: Double(timestamp))]),
                applications: [app],
                userID: 501,
                ownPID: 99
            )
        }
        let report = aggregation.aggregate(
            .init(timestamp: 72, samples: [sample(10, cpu: 70), sample(11, parent: 10, cpu: nil)]),
            applications: [app],
            userID: 501,
            ownPID: 99
        )
        let row = try #require(report.applications.first)
        #expect(row.hasPartialCPU)
        #expect(row.sustainedCPUSeconds == 0)
    }
}
