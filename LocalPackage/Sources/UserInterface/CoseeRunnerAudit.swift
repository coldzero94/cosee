/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
#if DEBUG
import AppKit
import DataSource
import Foundation
import Model

public enum CoseeRunnerAudit {
    @MainActor
    public static func schedule(to url: URL, runnerKind: RunnerKind? = nil) {
        Task { @MainActor in
            var report = Report(processID: ProcessInfo.processInfo.processIdentifier)
            report.requestedRunnerID = runnerKind?.id
            for _ in 0..<50 {
                try? await Task.sleep(for: .milliseconds(100))
                if let button = runnerButton(), let layer = runnerLayer(in: button.layer), animation(in: layer) != nil {
                    if let runnerKind {
                        let runner = Runner(kind: runnerKind)
                        let frames = runner.resourceNames().map(Frame.preset)
                        AppStateClient.liveValue.send(\.runnerBundles, RunnerBundle(runner: runner, frames: frames))
                        if runnerKind == .orbit {
                            let cpu =
                                AppStateClient.liveValue.withLock(\.metrics.latestValue)?
                                .systemInfoBundle.cpuInfo?.percentage.value ?? 0
                            _ = CoseeDiagnostics.injectRunnerCPU(percent: cpu)
                        }
                        for _ in 0..<20 {
                            try? await Task.sleep(for: .milliseconds(50))
                            if animation(in: layer)?.values?.count == frames.count { break }
                        }
                    }
                    report.buttonFound = true
                    report.buttonWidth = button.bounds.width
                    report.buttonHeight = button.bounds.height
                    report.runnerLayerFound = true
                    report.runnerWidth = layer.bounds.width
                    report.runnerHeight = layer.bounds.height
                    let animatedLayer = layer.mask ?? layer
                    for _ in 0..<10 {
                        try? await Task.sleep(for: .milliseconds(50))
                        if let systemSpeed = AppStateClient.liveValue.withLock(\.runnerSpeeds.latestValue),
                            animatedLayer.speed == systemSpeed
                        {
                            report.systemCPUSpeedApplied = true
                            break
                        }
                    }
                    let keyframes = animation(in: layer)
                    report.frameCount = keyframes?.values?.count ?? 0
                    report.animationDuration = keyframes?.duration ?? 0
                    report.repeatsContinuously = keyframes?.repeatCount.isInfinite ?? false
                    report.initialSpeed = animatedLayer.speed
                    report.usesTemplateMask = layer.mask != nil
                    report.usesStaticFallback = layer.isHidden
                    let runnerBundle = AppStateClient.liveValue.withLock(\.runnerBundles.latestValue)
                    report.runnerID = runnerBundle?.runner.id
                    if case let .keyFrameAnimation(frames) = runnerBundle?.displayFormat {
                        report.expectedFrameCount = frames.count
                    }
                    report.systemCPUSpeed = AppStateClient.liveValue.withLock(\.runnerSpeeds.latestValue)
                    SystemInfoObserverClient.liveValue.stopMonitoring()
                    report.reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                    if report.runnerID == RunnerKind.orbit.id {
                        let samples: [(Double, String)] = [
                            (0, "orbit-idle-frame-0"),
                            (35, "orbit-frame-0"),
                            (85, "orbit-boost-frame-0"),
                        ]
                        for (cpu, expectedResource) in samples {
                            let previousResource = firstResourceName()
                            let previousRevision = layer.frameRevision
                            let expectedSpeed = CoseeDiagnostics.injectRunnerCPU(percent: cpu) ?? 0
                            for _ in 0..<20 {
                                try? await Task.sleep(for: .milliseconds(50))
                                if animatedLayer.speed == expectedSpeed,
                                    previousResource == expectedResource || layer.frameRevision > previousRevision
                                {
                                    break
                                }
                            }
                            report.cpuLoadChecks.append(
                                .init(
                                    cpuPercent: cpu,
                                    firstFrameResource: firstResourceName(),
                                    observedSpeed: animatedLayer.speed,
                                    framesPerSecond: 12 * Double(animatedLayer.speed),
                                    framePhaseError: layer.lastFramePhaseError,
                                    speedPhaseError: layer.lastSpeedPhaseError,
                                    passed: firstResourceName() == expectedResource
                                        && animatedLayer.speed == expectedSpeed
                                        && (previousResource == expectedResource
                                            || layer.frameRevision > previousRevision)
                                        && layer.lastFramePhaseError < 0.0001 && layer.lastSpeedPhaseError < 0.0001
                                )
                            )
                        }
                    }
                    for requestedSpeed: Float in [1, 8, 20] {
                        AppStateClient.liveValue.send(\.runnerSpeeds, requestedSpeed)
                        try? await Task.sleep(for: .milliseconds(100))
                        let observedSpeed = animatedLayer.speed
                        let beginning = animatedLayer.convertTime(CACurrentMediaTime(), from: nil)
                        let wallBeginning = CACurrentMediaTime()
                        try? await Task.sleep(for: .milliseconds(150))
                        let wallElapsed = CACurrentMediaTime() - wallBeginning
                        let animationElapsed = animatedLayer.convertTime(CACurrentMediaTime(), from: nil) - beginning
                        report.speedChecks.append(
                            .init(
                                requested: requestedSpeed,
                                observed: observedSpeed,
                                animationClockRatio: animationElapsed / wallElapsed,
                                phaseError: layer.lastSpeedPhaseError,
                                passed: observedSpeed == requestedSpeed
                                    && abs(animationElapsed / wallElapsed - Double(requestedSpeed)) < 0.25
                                    && layer.lastSpeedPhaseError < 0.0001
                            )
                        )
                    }
                    report.passed =
                        report.frameCount > 1 && report.frameCount == report.expectedFrameCount
                        && report.animationDuration
                            == Double(report.expectedFrameCount) / (report.runnerID == RunnerKind.orbit.id ? 12 : 2)
                        && report.repeatsContinuously && report.runnerWidth > 0 && report.runnerHeight > 0
                        && report.systemCPUSpeedApplied
                        && report.speedChecks.allSatisfy(\.passed)
                        && report.cpuLoadChecks.allSatisfy(\.passed)
                    break
                }
            }
            if !report.runnerLayerFound {
                report.buttonFound = !statusButtons().isEmpty
                report.failure =
                    "No initialized RunnerLayer with a running keyframe animation appeared within five seconds."
                report.initializationSource = "RunnerBarView.swift:58 and NSApplication+Extension.swift:26"
                report.windowClasses = NSApp.windows.map { String(describing: type(of: $0)) }
                report.buttonTitles = statusButtons().map(\.title)
            }
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                let data = try encoder.encode(report)
                try data.write(to: url, options: .atomic)
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data("\n".utf8))
            } catch {
                FileHandle.standardError.write(Data("Cosee could not write the runner audit: \(error)\n".utf8))
                exit(1)
            }
            if !report.passed { exit(1) }
            NSApp.terminate(nil)
        }
    }

    @MainActor
    private static func statusButtons() -> [NSStatusBarButton] {
        func find(in view: NSView) -> [NSStatusBarButton] {
            (view as? NSStatusBarButton).map { [$0] } ?? view.subviews.flatMap { find(in: $0) }
        }
        return NSApp.windows.compactMap(\.contentView).flatMap { find(in: $0) }
    }

    @MainActor
    private static func runnerButton() -> NSStatusBarButton? {
        statusButtons().first { runnerLayer(in: $0.layer) != nil }
    }

    @MainActor
    private static func runnerLayer(in layer: CALayer?) -> RunnerLayer? {
        guard let layer else { return nil }
        if let runnerLayer = layer as? RunnerLayer { return runnerLayer }
        return layer.sublayers?.compactMap { runnerLayer(in: $0) }.first
    }

    @MainActor
    private static func animation(in layer: CALayer) -> CAKeyframeAnimation? {
        (layer.mask ?? layer).animation(forKey: "running") as? CAKeyframeAnimation
    }

    private static func firstResourceName() -> String? {
        guard let bundle = AppStateClient.liveValue.withLock(\.runnerBundles.latestValue),
            case let .keyFrameAnimation(frames) = bundle.displayFormat,
            case let .preset(name) = frames.first
        else { return nil }
        return name
    }

    private struct Report: Encodable {
        var processID: Int32
        var passed = false
        var buttonFound = false
        var runnerLayerFound = false
        var buttonWidth: Double = 0
        var buttonHeight: Double = 0
        var runnerWidth: Double = 0
        var runnerHeight: Double = 0
        var frameCount = 0
        var expectedFrameCount = 0
        var defaultRunnerID = Runner.default.id
        var requestedRunnerID: String?
        var animationDuration: Double = 0
        var repeatsContinuously = false
        var usesTemplateMask = false
        var usesStaticFallback = false
        var systemCPUSpeedApplied = false
        var reducesMotion = false
        var initialSpeed: Float?
        var systemCPUSpeed: Float?
        var runnerID: String?
        var speedChecks: [SpeedCheck] = []
        var cpuLoadChecks: [CPULoadCheck] = []
        var failure: String?
        var initializationSource: String?
        var windowClasses: [String] = []
        var buttonTitles: [String] = []
    }

    private struct SpeedCheck: Encodable {
        var requested: Float
        var observed: Float
        var animationClockRatio: Double
        var phaseError: Double
        var passed: Bool
    }

    private struct CPULoadCheck: Encodable {
        var cpuPercent: Double
        var firstFrameResource: String?
        var observedSpeed: Float
        var framesPerSecond: Double
        var framePhaseError: Double
        var speedPhaseError: Double
        var passed: Bool
    }
}
#endif
