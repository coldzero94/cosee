/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
import AppKit
import DataSource
import Model
import SwiftUI

enum CoseePalette {
    static let accent = Color(
        nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.43, green: 0.80, blue: 0.82, alpha: 1)
                : NSColor(red: 0.13, green: 0.43, blue: 0.46, alpha: 1)
        }
    )
    static let background = Color(
        nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.12, green: 0.14, blue: 0.17, alpha: 1)
                : NSColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1)
        }
    )
    static let panel = Color(
        nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.17, green: 0.19, blue: 0.22, alpha: 1) : .white
        }
    )
}

extension View {
    func dashboardPanel() -> some View {
        background(CoseePalette.panel, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.07)))
    }
}

struct DashboardSummaryView: View {
    var store: Dashboard

    private var cpu: Double? { store.systemInfoBundle.cpuInfo.map { Double($0.percentage.value) } }
    private var memory: Double? { store.systemInfoBundle.memoryInfo.map { Double($0.percentage.value) } }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            metric(title: "dashboard.systemCPU", symbol: "cpu", value: cpu) {
                HStack {
                    Text(cpuState, bundle: .module).foregroundStyle(CoseePalette.accent)
                    Spacer(minLength: 2)
                    if store.processes.unassignedCPUPercent >= 20 {
                        Button {
                            Task { await store.processes.send(.scopeSelected(.all)) }
                        } label: {
                            Image(systemName: "list.bullet")
                        }
                        .buttonStyle(.plain)
                        .help(String(localized: "dashboard.unassigned", bundle: .module))
                        .accessibilityLabel(Text("dashboard.unassigned", bundle: .module))
                    }
                }
            } graph: {
                SummarySparkline(values: store.cpuRingBuffer.values, color: CoseePalette.accent)
            }
            metric(title: "processes.memory", symbol: "memorychip", value: memory) {
                Label {
                    Text(pressureState, bundle: .module)
                } icon: {
                    Image(systemName: store.processes.report.pressure == .normal ? "checkmark.circle" : "circle.fill")
                        .font(.system(size: 8))
                }
                .foregroundStyle(pressureColor)
            } graph: {
                SummarySparkline(values: store.memoryRingBuffer.values, color: pressureColor)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var cpuState: LocalizedStringKey {
        guard let cpu else { return "dashboard.reading" }
        if cpu < 15 { return "dashboard.quiet" }
        if cpu < 55 { return "dashboard.active" }
        return "dashboard.busy"
    }
    private var pressureState: LocalizedStringKey {
        switch store.processes.report.pressure {
        case .normal: "dashboard.pressureNormal"
        case .warning: "dashboard.pressureWarning"
        case .critical: "dashboard.pressureCritical"
        case .unknown: "dashboard.reading"
        }
    }
    private var pressureColor: Color {
        switch store.processes.report.pressure {
        case .normal: CoseePalette.accent
        case .warning: .orange
        case .critical: .red
        case .unknown: .secondary
        }
    }

    private func metric<Status: View, Graph: View>(
        title: LocalizedStringKey,
        symbol: String,
        value: Double?,
        @ViewBuilder status: () -> Status,
        @ViewBuilder graph: () -> Graph
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label {
                    Text(title, bundle: .module)
                } icon: {
                    Image(systemName: symbol)
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                graph().frame(width: 56, height: 18).accessibilityHidden(true)
            }
            Text(value.map { String(format: "%.1f%%", $0) } ?? "—")
                .font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(.primary)
            status().font(.system(size: 11, weight: .medium)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).dashboardPanel()
    }
}

private struct SummarySparkline: View {
    var values: [Double]
    var color: Color
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard values.count > 1 else { return }
                for (index, value) in values.enumerated() {
                    let point = CGPoint(
                        x: Double(index) / Double(values.count - 1) * geometry.size.width,
                        y: (1 - min(100, max(0, value)) / 100) * (geometry.size.height - 2) + 1
                    )
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}
