/*
 Modified for Cosee: independent app configuration, resource monitoring, distribution support, or formatting.
 DashboardView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/08.
 Copyright 2026 Kyome22 (Takuto Nakamura)

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Model
import SwiftUI

struct DashboardView: View {
    @Environment(\.appDependencies) private var appDependencies
    @StateObject var store: Dashboard

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: NSImage(resource: .init(name: "orbit-frame-2", bundle: .module)))
                    .renderingMode(.template).resizable().scaledToFit()
                    .frame(width: 28, height: 18).foregroundStyle(CoseePalette.accent)
                    .accessibilityHidden(true)
                Text(store.appName).font(.system(size: 14, weight: .semibold))
                Spacer()
                MenuView(store: store)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            DashboardSummaryView(store: store).padding(.horizontal, 12).padding(.bottom, 12)
            Divider()
            ScrollView {
                VStack(spacing: 14) {
                    ProcessesView(store: store.processes)
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { store.showsSystemDetails },
                            asyncSet: { await store.send(.systemDetailsToggled($0)) }
                        )
                    ) {
                        SystemInfoStackView(
                            systemInfoBundle: store.systemInfoBundle,
                            cpuRingBuffer: store.cpuRingBuffer,
                            memoryRingBuffer: store.memoryRingBuffer,
                            isPreview: store.isPreview
                        )
                    } label: {
                        Label {
                            Text("processes.systemDetails", bundle: .module)
                        } icon: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .padding(12).dashboardPanel()
                    ForEach(store.customMetricsBundles) { customMetricsBundle in
                        CustomMetricsCardView(
                            customMetricsBundle: customMetricsBundle,
                            displayedDate: store.displayedDate
                        )
                    }
                }
                .padding(12)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: DashboardHeightKey.self, value: proxy.size.height)
                    }
                )
            }
            .scrollIndicators(.visible)
            .frame(
                height: min(store.contentHeight, max(260, min(480, (NSScreen.main?.visibleFrame.height ?? 800) - 250)))
            )
            .onPreferenceChange(DashboardHeightKey.self) { value in
                Task { await store.send(.contentHeightChanged(value)) }
            }
        }
        .frame(width: 440)
        .background(CoseePalette.background)
        .tint(CoseePalette.accent)
        .task { await store.send(.viewAppeared(String(describing: Self.self))) }
        .onDisappear { Task { await store.send(.viewDisappeared) } }
    }
}

extension Dashboard: ObservableObject {}

private struct DashboardHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 520
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
