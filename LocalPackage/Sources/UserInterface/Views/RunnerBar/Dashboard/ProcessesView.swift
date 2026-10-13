/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
import AppKit
import Charts
import DataSource
import Model
import SwiftUI

struct ProcessesView: View {
    var store: Processes

    private var attentionRows: [AppProcessUsage] {
        store.rows.filter { usage in
            switch store.insight(for: usage) {
            case .sustainedCPU, .memoryPressure, .memoryGrowing: true
            case .partial, .currentReading: false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.listState == .ready, !attentionRows.isEmpty { attentionSection }
            applicationsSection
            DisclosureGroup(
                isExpanded: Binding(
                    get: { store.showsMeasurementDetails },
                    asyncSet: {
                        await store.send(.measurementDetailsToggled($0))
                    }
                )
            ) {
                Text("processes.explanation", bundle: .module)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 4)
            } label: {
                Text("processes.measurementDetails", bundle: .module).font(.system(size: 11))
            }
            .padding(.horizontal, 3)
        }
        .environment(
            \.processActions,
            ProcessActions(
                quit: { identity in Task { await store.send(.quitRequested(identity)) } },
                quitInFlight: store.quitInFlight,
                sort: store.sort
            )
        )
        .alert(
            String(localized: "processes.confirmTitle", bundle: .module),
            isPresented: Binding(
                get: { store.confirmationVisible },
                asyncSet: {
                    if !$0 { await store.send(.confirmationDismissed) }
                }
            )
        ) {
            Button(role: .cancel) {
                Task { await store.send(.quitCancelled) }
            } label: {
                Text("processes.cancel", bundle: .module)
            }
            Button {
                Task { await store.send(.quitConfirmed) }
            } label: {
                Text("processes.quit", bundle: .module)
            }
        } message: {
            Text("processes.confirmMessage\(store.pendingQuit?.name ?? "")", bundle: .module)
        }
    }

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                Text("dashboard.attention", bundle: .module).fontWeight(.semibold)
                Text("\(attentionRows.count)").monospacedDigit().foregroundStyle(.secondary)
                Spacer()
            }
            .font(.system(size: 12))
            ForEach(Array(attentionRows.prefix(3))) { usage in
                AttentionRowView(
                    usage: usage,
                    insight: store.insight(for: usage),
                    growth: store.memoryGrowth(for: usage)
                )
            }
            Text("dashboard.attentionAdvice", bundle: .module)
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12).dashboardPanel()
    }

    private var applicationsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("processes.title", bundle: .module).font(.system(size: 12, weight: .semibold))
                Spacer()
                Picker(selection: Binding(get: { store.sort }, asyncSet: { await store.send(.sortSelected($0)) })) {
                    Text("processes.cpu", bundle: .module).tag(ProcessSort.cpu)
                    Text("processes.memory", bundle: .module).tag(ProcessSort.memory)
                } label: {
                    Text("processes.sort", bundle: .module)
                }
                .pickerStyle(.segmented).labelsHidden().controlSize(.small).frame(width: 130)
            }
            .padding(.bottom, 10)
            HStack(spacing: 8) {
                TextField(text: Binding(get: { store.searchQuery }, asyncSet: { await store.send(.searchChanged($0)) }))
                {
                    Text("processes.search", bundle: .module)
                }
                .textFieldStyle(.roundedBorder).controlSize(.small)
                Picker(selection: Binding(get: { store.scope }, asyncSet: { await store.send(.scopeSelected($0)) })) {
                    Text("processes.apps", bundle: .module).tag(ProcessScope.applications)
                    Text("processes.all", bundle: .module).tag(ProcessScope.all)
                } label: {
                    Text("processes.scope", bundle: .module)
                }
                .pickerStyle(.menu).labelsHidden().controlSize(.small).frame(width: 126)
            }
            .padding(.bottom, 10)
            HStack(spacing: 8) {
                Text(store.scope == .applications ? "dashboard.appColumn" : "dashboard.processColumn", bundle: .module)
                Spacer()
                columnHeader("processes.cpu", selected: store.sort == .cpu).frame(width: 57, alignment: .trailing)
                columnHeader("processes.memory", selected: store.sort == .memory).frame(width: 67, alignment: .trailing)
                Color.clear.frame(width: 20, height: 1)
            }
            .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            .padding(.bottom, 6)
            Divider()
            switch store.listState {
            case .loading: listMessage("processes.waiting")
            case .unavailable: listMessage("processes.unavailable")
            case .empty: listMessage("processes.empty")
            case .filteredEmpty: listMessage("processes.noResults")
            case .ready:
                LazyVStack(spacing: 0) {
                    ForEach(store.visibleRows) { usage in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { store.expanded.contains(usage.id) },
                                asyncSet: {
                                    await store.send(.expansionChanged(usage.id, $0))
                                }
                            )
                        ) {
                            ProcessDetailsView(usage: usage, sort: store.sort)
                        } label: {
                            ProcessRowView(usage: usage)
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
                if store.hiddenRowCount > 0 {
                    Button {
                        Task { await store.send(.showAllRows) }
                    } label: {
                        Text("processes.showMore\(store.hiddenRowCount)", bundle: .module)
                    }
                    .buttonStyle(.borderless).font(.system(size: 11)).padding(.top, 8)
                }
            }
            if store.scope == .applications, store.unassignedCPUPercent >= 20 {
                Button {
                    Task { await store.send(.scopeSelected(.all)) }
                } label: {
                    Text("dashboard.unassigned", bundle: .module)
                }
                .buttonStyle(.borderless).font(.system(size: 11)).padding(.top, 8)
            }
            Text("dashboard.cpuBasis", bundle: .module)
                .font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, 8)
            if store.quitInFlight {
                Label {
                    Text("processes.quitting", bundle: .module)
                } icon: {
                    Image(systemName: "hourglass")
                }
                .font(.system(size: 11)).padding(.top, 8)
            }
            if let result = store.quitResult {
                Text("\(store.quitName): \(result.localizedText)")
                    .font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 8)
            }
        }
        .padding(12).dashboardPanel()
    }

    private func columnHeader(_ key: LocalizedStringKey, selected: Bool) -> some View {
        HStack(spacing: 3) {
            Text(key, bundle: .module)
            if selected { Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }
        }
    }
    private func listMessage(_ key: LocalizedStringKey) -> some View {
        Text(key, bundle: .module).font(.system(size: 12)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 18)
    }
}

private struct ProcessAppIcon: View {
    var usage: AppProcessUsage
    var size: CGFloat = 22
    @State private var icon: NSImage?
    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "terminal").resizable().scaledToFit().foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size).accessibilityHidden(true)
        .task(id: usage.application?.bundlePath) {
            if let path = usage.application?.bundlePath { icon = NSWorkspace.shared.icon(forFile: path) }
        }
    }
}

private struct ProcessRowView: View {
    @Environment(\.processActions) private var actions
    let usage: AppProcessUsage

    var body: some View {
        HStack(spacing: 8) {
            ProcessAppIcon(usage: usage)
            Text(usage.name).font(.system(size: 12, weight: .medium)).foregroundStyle(.primary)
                .lineLimit(1).help(usage.name)
            if usage.application?.isActive == true {
                Circle().fill(CoseePalette.accent).frame(width: 4, height: 4)
                    .help(String(localized: "processes.foreground", bundle: .module))
            }
            Spacer(minLength: 0)
            Text(usage.cpuText).foregroundStyle(actions.sort == .cpu ? Color.primary : .secondary)
                .frame(width: 57, alignment: .trailing)
            Text(usage.memoryText).foregroundStyle(actions.sort == .memory ? Color.primary : .secondary)
                .frame(width: 67, alignment: .trailing)
            Group {
                if usage.canQuit {
                    Button {
                        actions.quit(usage.id)
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless).foregroundStyle(.secondary)
                    .disabled(actions.quitInFlight)
                    .help(String(localized: "processes.quit", bundle: .module))
                    .accessibilityLabel(Text("processes.quitNamed\(usage.name)", bundle: .module))
                } else {
                    Color.clear
                }
            }
            .frame(width: 20, height: 20)
        }
        .font(.system(size: 11)).monospacedDigit()
    }
}

private struct AttentionRowView: View {
    @Environment(\.processActions) private var actions
    let usage: AppProcessUsage
    let insight: ProcessInsight
    let growth: UInt64?
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ProcessAppIcon(usage: usage)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(usage.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Spacer()
                    Text(insight == .sustainedCPU ? usage.cpuText : usage.memoryText)
                        .font(.system(size: 11, weight: .medium)).monospacedDigit()
                }
                Text(insight.text(for: usage, growth: growth))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if usage.canQuit {
                Button {
                    actions.quit(usage.id)
                } label: {
                    Text("dashboard.quit", bundle: .module)
                }
                .controlSize(.small).buttonStyle(.bordered).disabled(actions.quitInFlight)
                .accessibilityLabel(Text("processes.quitNamed\(usage.name)", bundle: .module))
            }
        }
    }
}

private struct ProcessDetailsView: View {
    let usage: AppProcessUsage
    let sort: ProcessSort

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let application = usage.application {
                Text(application.isActive ? "processes.foreground" : "processes.background", bundle: .module)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack {
                Text("processes.memberCount\(usage.processCount)", bundle: .module)
                Spacer()
                Text("PID \(usage.id.pid)")
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            Text(sort == .cpu ? "processes.history" : "processes.memoryHistory", bundle: .module).font(.caption)
            Chart(usage.history) { point in
                if sort == .cpu, let cpu = point.cpuPercent {
                    LineMark(
                        x: .value("Seconds", point.timestamp - (usage.history.last?.timestamp ?? 0)),
                        y: .value("CPU %", cpu)
                    )
                } else if sort == .memory, let memory = point.footprintBytes, point.isMemoryComplete {
                    LineMark(
                        x: .value("Seconds", point.timestamp - (usage.history.last?.timestamp ?? 0)),
                        y: .value("GiB", Double(memory) / 1_073_741_824)
                    )
                }
            }
            .chartXScale(domain: -300.0...0.0)
            .chartXAxis {
                AxisMarks(values: [-300.0, -150.0, 0.0]) { value in
                    AxisValueLabel(
                        anchor: value.as(Double.self) == -300
                            ? .topLeading
                            : value.as(Double.self) == 0 ? .topTrailing : .top
                    ) {
                        if let seconds = value.as(Double.self) {
                            Text("processes.secondsAgo\(Int(abs(seconds)))", bundle: .module)
                        }
                    }
                }
            }
            .foregroundStyle(CoseePalette.accent)
            .frame(height: 85)
            .accessibilityLabel(Text(sort == .cpu ? "processes.history" : "processes.memoryHistory", bundle: .module))
            Text("processes.memberCount\(usage.processCount)", bundle: .module).font(.caption)
            ForEach(usage.members) { member in
                HStack {
                    Text("\(member.name) · \(member.id.pid)").lineLimit(1)
                    Spacer()
                    Text(member.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "—").monospacedDigit()
                    Text(
                        member.footprintBytes.map {
                            ByteCountFormatter.string(fromByteCount: Int64(clamping: $0), countStyle: .memory)
                        } ?? "—"
                    )
                    .monospacedDigit().frame(minWidth: 55, alignment: .trailing)
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
}

private struct ProcessActions {
    var quit: (ProcessIdentity) -> Void = { _ in }
    var quitInFlight = false
    var sort = ProcessSort.cpu
}

private extension EnvironmentValues {
    @Entry var processActions = ProcessActions()
}

private extension AppProcessUsage {
    var cpuText: String { cpuPercent.map { (hasPartialCPU ? "≥ " : "") + String(format: "%.1f%%", $0) } ?? "—" }
    var memoryText: String {
        footprintBytes.map {
            (unavailableCount > 0 ? "≥ " : "")
                + ByteCountFormatter.string(fromByteCount: Int64(clamping: $0), countStyle: .memory)
        } ?? "—"
    }
}

private extension MemoryPressure {
    var localizationKey: LocalizedStringKey {
        switch self {
        case .normal: "processes.pressureNormal"
        case .warning: "processes.pressureWarning"
        case .critical: "processes.pressureCritical"
        case .unknown: "processes.pressureUnknown"
        }
    }
    var tint: Color {
        switch self {
        case .normal: .secondary
        case .warning: .orange
        case .critical: .red
        case .unknown: .secondary
        }
    }
}

private extension ProcessInsight {
    func text(for usage: AppProcessUsage, growth: UInt64?) -> String {
        switch self {
        case .sustainedCPU:
            String(localized: "processes.sustainedCPU\(Int(usage.sustainedCPUSeconds))", bundle: .module)
        case .memoryPressure:
            String(localized: "processes.memoryCandidate", bundle: .module)
        case .memoryGrowing:
            String(
                localized:
                    "processes.memoryGrowth\(growth.map { ByteCountFormatter.string(fromByteCount: Int64(clamping: $0), countStyle: .memory) } ?? "")",
                bundle: .module
            )
        case .partial: String(localized: "processes.partial", bundle: .module)
        case .currentReading: String(localized: "processes.currentReading", bundle: .module)
        }
    }

    var tint: Color {
        switch self {
        case .sustainedCPU, .memoryPressure, .memoryGrowing: .orange
        case .partial, .currentReading: .secondary
        }
    }
}

private extension TerminationResult {
    var localizedText: String {
        switch self {
        case .exited: String(localized: "processes.exited", bundle: .module)
        case .stillRunning: String(localized: "processes.stillRunning", bundle: .module)
        case .requestRejected: String(localized: "processes.rejected", bundle: .module)
        case .noLongerMatches: String(localized: "processes.changed", bundle: .module)
        case .notAllowed: String(localized: "processes.notAllowed", bundle: .module)
        }
    }
}
