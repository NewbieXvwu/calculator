// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

import SwiftUI

@main
struct MacCalculatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("计算器") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 322, height: 500)
    }
}

// SPM 可执行文件没有 app bundle，需手动把进程提升为前台常规应用，
// 否则 `swift run` 启动时窗口不会出现在前台。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
