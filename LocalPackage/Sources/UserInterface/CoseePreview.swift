/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
#if DEBUG
import AppKit
import DataSource
import Model
import SwiftUI
import SystemInfoKit

public enum CoseePreview {
    enum RenderError: Error { case unavailable }

    @MainActor
    public static func render(to url: URL) throws {
        _ = NSApplication.shared
        let dependencies = AppDependencies.testDependencies()
        var bundle = SystemInfoBundle.cpuZero()
        bundle.cpuInfo = .init(
            percentage: .init(rawValue: 0.18),
            system: .init(rawValue: 0.04),
            user: .init(rawValue: 0.14),
            idle: .init(rawValue: 0.82)
        )
        bundle.memoryInfo = .init(
            percentage: .init(rawValue: 0.60),
            pressure: .init(rawValue: 0.175),
            app: .init(byteCount: 6_800_000_000),
            wired: .init(byteCount: 1_800_000_000),
            compressed: .init(byteCount: 1_000_000_000)
        )
        let dashboard = Dashboard(dependencies, appName: "Cosee", systemInfoBundle: bundle, isPreview: true)
        dashboard.cpuRingBuffer.append((0..<61).map { 18 + sin(Double($0) / 5) * 8 })
        dashboard.memoryRingBuffer.append((0..<61).map { 50 + Double($0) / 6 })
        let editor = RunningAppDescriptor(
            pid: 100,
            name: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            bundlePath: NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.dt.Xcode")?.path
                ?? "/Applications/Xcode.app"
        )
        let browser = RunningAppDescriptor(
            pid: 200,
            name: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundlePath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
        )
        let docker = RunningAppDescriptor(
            pid: 400,
            name: "Docker",
            bundleIdentifier: "com.docker.docker",
            bundlePath: "/Applications/Docker.app",
            isRegular: false,
            isAccessory: true
        )
        func history(base: UInt64, growth: UInt64, cpu: Double) -> [ProcessHistoryPoint] {
            (0...60).map { (step: Int) -> ProcessHistoryPoint in
                let elapsed = Double(step)
                let progress = elapsed / 60
                let variation = sin(elapsed / 4) * 0.15
                let activity = cpu + cpu * variation
                let memory = base + UInt64(Double(growth) * progress)
                return ProcessHistoryPoint(
                    timestamp: Double(step * 5),
                    cpuPercent: activity,
                    footprintBytes: memory
                )
            }
        }
        func members(pid: Int32, names: [String], cpu: Double, memory: UInt64) -> [ProcessUsage] {
            names.enumerated().map { offset, name in
                .init(
                    id: .init(pid: pid + Int32(offset), startMicroseconds: 100),
                    name: name,
                    cpuPercent: cpu / Double(names.count),
                    footprintBytes: memory / UInt64(names.count)
                )
            }
        }
        let identity = ProcessIdentity(pid: 100, startMicroseconds: 100)
        dashboard.processes.report = .init(
            timestamp: 300,
            applications: [
                .init(
                    id: identity,
                    name: "Xcode",
                    application: editor,
                    processCount: 4,
                    cpuPercent: 112.4,
                    footprintBytes: 2_100_000_000,
                    sustainedCPUSeconds: 72,
                    canQuit: true,
                    members: members(
                        pid: 100,
                        names: ["Xcode", "SourceKitService", "swift-frontend", "SourceKitService"],
                        cpu: 112.4,
                        memory: 2_100_000_000
                    ),
                    history: history(base: 1_900_000_000, growth: 200_000_000, cpu: 112.4)
                ),
                .init(
                    id: .init(pid: 200, startMicroseconds: 200),
                    name: "Safari",
                    application: browser,
                    processCount: 3,
                    cpuPercent: 8.2,
                    footprintBytes: 1_200_000_000,
                    canQuit: true,
                    members: members(
                        pid: 200,
                        names: ["Safari", "Safari Web Content", "Safari Networking"],
                        cpu: 8.2,
                        memory: 1_200_000_000
                    ),
                    history: history(base: 1_150_000_000, growth: 50_000_000, cpu: 8.2)
                ),
                .init(
                    id: .init(pid: 400, startMicroseconds: 400),
                    name: "Docker",
                    application: docker,
                    processCount: 2,
                    cpuPercent: 4.5,
                    footprintBytes: 3_500_000_000,
                    canQuit: true,
                    members: members(
                        pid: 400,
                        names: ["Docker", "com.docker.backend"],
                        cpu: 4.5,
                        memory: 3_500_000_000
                    ),
                    history: history(base: 1_000_000_000, growth: 2_500_000_000, cpu: 4.5)
                ),
            ],
            pressure: .normal
        )
        if CommandLine.arguments.contains("--preview-pressure") { dashboard.processes.report.pressure = .warning }
        if CommandLine.arguments.contains("--preview-memory") { dashboard.processes.sort = .memory }
        if CommandLine.arguments.contains("--preview-expanded") {
            dashboard.processes.expanded.insert(
                dashboard.processes.sort == .memory ? .init(pid: 400, startMicroseconds: 400) : identity
            )
        }
        let host = NSHostingView(
            rootView: DashboardView(store: dashboard)
                .environment(\.appDependencies, dependencies)
                .background(Color(nsColor: .windowBackgroundColor))
        )
        let window = NSWindow(
            contentRect: .init(x: 0, y: 0, width: 440, height: 600),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: CommandLine.arguments.contains("--preview-dark") ? .darkAqua : .aqua)
        window.contentView = host
        window.setContentSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        window.setContentSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        window.setContentSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw RenderError.unavailable }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw RenderError.unavailable }
        try png.write(to: url)
    }
}
#endif
