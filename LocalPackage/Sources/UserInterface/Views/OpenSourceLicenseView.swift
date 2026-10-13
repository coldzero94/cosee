/*
 Modified for Cosee: independent app configuration, resource monitoring, distribution support, or formatting.
 OpenSourceLicenseView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/06/10.
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

import SwiftUI

struct OpenSourceLicenseView: View {
    var body: some View {
        LocalDocumentView(resource: "ThirdPartyNotices", titleKey: "processes.notices")
    }
}

struct LocalDocumentView: View {
    let resource: String
    let titleKey: LocalizedStringKey

    private var text: String {
        Bundle.module.url(forResource: resource, withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleKey, bundle: .module).font(.title2)
            ScrollView {
                Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(minWidth: 560, idealWidth: 600, minHeight: 360, idealHeight: 460)
    }
}
