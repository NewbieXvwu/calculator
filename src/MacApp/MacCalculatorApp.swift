// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

import SwiftUI

@main
struct MacCalculatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = StandardCalculatorViewModel()

    var body: some Scene {
        WindowGroup("计算器") {
            ContentView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 322, height: 500)
        .commands {
            // 模式切换（对齐 Apple 计算器 ⌘1/2/3）。
            CommandMenu("模式") {
                Button("标准") { model.setCalculatorType(.standard) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("科学") { model.setCalculatorType(.scientific) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("程序员") { model.setCalculatorType(.programmer) }
                    .keyboardShortcut("3", modifiers: .command)
            }
            CommandGroup(replacing: .pasteboard) {
                Button("拷贝") { model.copyDisplay() }
                    .keyboardShortcut("c", modifiers: .command)
                Button("粘贴") { model.pasteFromPasteboard() }
                    .keyboardShortcut("v", modifiers: .command)
            }
        }
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
