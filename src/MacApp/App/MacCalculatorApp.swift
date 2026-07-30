// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

import SwiftUI

@main
struct MacCalculatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = StandardCalculatorViewModel()
    @State private var alwaysOnTop = UserDefaults.standard.bool(forKey: "AlwaysOnTop")

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
                Button("日期计算") { model.setCalculatorType(.date) }
                    .keyboardShortcut("4", modifiers: .command)
                Button("单位换算") { model.setCalculatorType(.converter) }
                    .keyboardShortcut("5", modifiers: .command)
                Button("绘图") { model.setCalculatorType(.graphing) }
                    .keyboardShortcut("6", modifiers: .command)
            }
            CommandGroup(replacing: .pasteboard) {
                Button("拷贝") { model.copyDisplay() }
                    .keyboardShortcut("c", modifiers: .command)
                Button("粘贴") { model.pasteFromPasteboard() }
                    .keyboardShortcut("v", modifiers: .command)
            }
            // 历史（⌃H/⇧⌃D 和弦的菜单栏可发现性入口）。
            CommandGroup(after: .sidebar) {
                Divider()
                Button("历史记录") { model.toggleHistoryPanel() }
                    .keyboardShortcut("h", modifiers: .control)
                Button("清除历史记录") { model.clearHistory() }
                    .keyboardShortcut("d", modifiers: [.control, .shift])
            }
            // 记忆（对应原版 MC/MR/M+/M−/MS 的 Ctrl 和弦）。
            CommandMenu("记忆") {
                Button("记忆存储 (MS)") { model.memorizeNumber() }
                    .keyboardShortcut("m", modifiers: .control)
                Button("记忆调用 (MR)") { model.memoryItemPressed(0) }
                    .keyboardShortcut("r", modifiers: .control)
                Button("记忆加 (M+)") { model.memoryAdd(0) }
                    .keyboardShortcut("p", modifiers: .control)
                Button("记忆减 (M−)") { model.memorySubtract(0) }
                    .keyboardShortcut("q", modifiers: .control)
                Button("清除记忆 (MC)") { model.clearMemory() }
                    .keyboardShortcut("l", modifiers: .control)
            }
            // 窗口置顶（对应原版 Always-on-Top，Windows 快捷键 Alt+Up 映射为 ⌥⌘↑）。
            CommandGroup(after: .windowArrangement) {
                Toggle("窗口置顶", isOn: Binding(
                    get: { alwaysOnTop },
                    set: { newValue in
                        alwaysOnTop = newValue
                        UserDefaults.standard.set(newValue, forKey: "AlwaysOnTop")
                        for window in NSApp.windows {
                            window.level = newValue ? .floating : .normal
                        }
                        // 对应原版 AlwaysOnTop 播报。
                        AccessibilityAnnouncer.announce(newValue ? "已进入置顶视图" : "已退出置顶视图")
                    }))
                    .keyboardShortcut(.upArrow, modifiers: [.option, .command])
            }
        }

        // 设置/关于（Settings.xaml 对应物，⌘, 打开）。
        Settings {
            SettingsView()
        }
    }
}

// SPM 可执行文件没有 app bundle，需手动把进程提升为前台常规应用，
// 否则 `swift run` 启动时窗口不会出现在前台。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // 恢复外观主题偏好（Settings.xaml ThemeRadioButtons 的持久化语义）。
        NSApp.appearance = AppAppearance.current.nsAppearance
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
