/*
 Modified for Cosee: independent app configuration, resource monitoring, distribution support, or formatting.
 CoseeApp.swift
 Cosee

 Created by Takuto Nakamura on 2026/01/15.
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

import DataSource
import Model
import SwiftUI
import UserInterface

struct CoseeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(.showsMetricsBar) private var showsMetricsBar = false

    var body: some Scene {
        RunnerBarScene()
        MetricsBarScene(isInserted: $showsMetricsBar)
        SettingsWindowScene()
        OpenSourceLicenseWindowScene()
        PrivacyWindowScene()
    }
}

@main
enum CoseeLauncher {
    static func main() {
        if CommandLine.arguments.contains("--diagnose") {
            do {
                let data = try CoseeDiagnostics.capture()
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data("\n".utf8))
            } catch {
                FileHandle.standardError.write(Data("Cosee could not read process metrics.\n".utf8))
                exit(1)
            }
            return
        }
        #if DEBUG
        if let index = CommandLine.arguments.firstIndex(of: "--render-preview"),
            CommandLine.arguments.indices.contains(index + 1)
        {
            do {
                try CoseePreview.render(to: URL(filePath: CommandLine.arguments[index + 1]))
            } catch {
                FileHandle.standardError.write(Data("Preview rendering failed.\n".utf8))
                exit(1)
            }
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--audit-runner"),
            CommandLine.arguments.indices.contains(index + 1)
        {
            var runnerKind: RunnerKind?
            if let kindIndex = CommandLine.arguments.firstIndex(of: "--audit-runner-kind") {
                guard CommandLine.arguments.indices.contains(kindIndex + 1),
                    let kind = RunnerKind(rawValue: CommandLine.arguments[kindIndex + 1])
                else {
                    FileHandle.standardError.write(Data("Unknown runner kind for audit.\n".utf8))
                    exit(1)
                }
                runnerKind = kind
            }
            CoseeRunnerAudit.schedule(to: URL(filePath: CommandLine.arguments[index + 1]), runnerKind: runnerKind)
        }
        #endif
        CoseeApp.main()
    }
}
