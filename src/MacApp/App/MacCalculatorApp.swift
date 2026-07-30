// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

import AppKit
import SwiftUI

@main
struct MacCalculatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = StandardCalculatorViewModel()
    @State private var alwaysOnTop = UserDefaults.standard.bool(forKey: "AlwaysOnTop")

    var body: some Scene {
        WindowGroup(L10n.string("AppName")) {
            ContentView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
        // 工具栏收紧为 Apple 计算器同款紧凑高度（不显示窗口标题文本）。
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .windowResizability(.contentSize)
        .defaultSize(width: 322, height: 500)
        .commands {
            // 关于面板（macOS 惯例：应用菜单内，展示版权/第三方声明——静态链 Giac 的 GPLv3 合规提示）。
            CommandGroup(replacing: .appInfo) {
                Button(L10n.format("Mac_Menu_About", L10n.string("AppName"))) {
                    Self.showAboutPanel()
                }
            }
            // 模式切换并入 macOS 惯例的"显示"菜单（对齐 Apple 计算器 ⌘1..⌘6）。
            CommandMenu(L10n.string("Mac_Menu_View")) {
                Button(L10n.string("StandardModeText")) { model.setCalculatorType(.standard) }
                    .keyboardShortcut("1", modifiers: .command)
                Button(L10n.string("ScientificModeText")) { model.setCalculatorType(.scientific) }
                    .keyboardShortcut("2", modifiers: .command)
                Button(L10n.string("ProgrammerModeText")) { model.setCalculatorType(.programmer) }
                    .keyboardShortcut("3", modifiers: .command)
                Button(L10n.string("DateCalculationModeText")) { model.setCalculatorType(.date) }
                    .keyboardShortcut("4", modifiers: .command)
                Button(L10n.string("ConverterModeText")) { model.setCalculatorType(.converter) }
                    .keyboardShortcut("5", modifiers: .command)
                Button(L10n.string("GraphingCalculatorModeText")) { model.setCalculatorType(.graphing) }
                    .keyboardShortcut("6", modifiers: .command)
            }
            CommandGroup(replacing: .pasteboard) {
                Button(L10n.string("Mac_Menu_Copy")) { model.copyDisplay() }
                    .keyboardShortcut("c", modifiers: .command)
                Button(L10n.string("Mac_Menu_Paste")) { model.pasteFromPasteboard() }
                    .keyboardShortcut("v", modifiers: .command)
            }
            // 历史（⌃H/⇧⌃D 和弦的菜单栏可发现性入口）。
            CommandGroup(after: .sidebar) {
                Divider()
                Button(L10n.string("HistoryLabel.Text")) { model.toggleHistoryPanel() }
                    .keyboardShortcut("h", modifiers: .control)
                Button(L10n.string("Mac_Menu_ClearHistory")) { model.clearHistory() }
                    .keyboardShortcut("d", modifiers: [.control, .shift])
            }
            // 记忆（对应原版 MC/MR/M+/M−/MS 的 Ctrl 和弦）。
            CommandMenu(L10n.string("MemoryLabel.Text")) {
                Button(L10n.string("Mac_Menu_MS")) { model.memorizeNumber() }
                    .keyboardShortcut("m", modifiers: .control)
                Button(L10n.string("Mac_Menu_MR")) { model.memoryItemPressed(0) }
                    .keyboardShortcut("r", modifiers: .control)
                Button(L10n.string("Mac_Menu_MPlus")) { model.memoryAdd(0) }
                    .keyboardShortcut("p", modifiers: .control)
                Button(L10n.string("Mac_Menu_MMinus")) { model.memorySubtract(0) }
                    .keyboardShortcut("q", modifiers: .control)
                Button(L10n.string("Mac_Menu_MC")) { model.clearMemory() }
                    .keyboardShortcut("l", modifiers: .control)
            }
            // 窗口置顶（对应原版 Always-on-Top，Windows 快捷键 Alt+Up 映射为 ⌥⌘↑）。
            CommandGroup(after: .windowArrangement) {
                Toggle(L10n.string("Mac_Menu_AlwaysOnTop"), isOn: Binding(
                    get: { alwaysOnTop },
                    set: { newValue in
                        alwaysOnTop = newValue
                        UserDefaults.standard.set(newValue, forKey: "AlwaysOnTop")
                        for window in NSApp.windows {
                            window.level = newValue ? .floating : .normal
                        }
                        // 对应原版 AlwaysOnTop 播报。
                        AccessibilityAnnouncer.announce(newValue ? L10n.string("Mac_Ann_AOTOn") : L10n.string("Mac_Ann_AOTOff"))
                    }))
                    .keyboardShortcut(.upArrow, modifiers: [.option, .command])
            }
        }

        // 设置/关于（Settings.xaml 对应物，⌘, 打开）。
        Settings {
            SettingsView()
        }
    }

    /// 标准关于面板：版本自 Info.plist 自动填充，附版权与第三方许可声明（GPLv3 合规可见性）。
    static func showAboutPanel() {
        let creditsText = L10n.string("Mac_LicenseCopyright") + "\n\n" + L10n.string("Mac_ThirdParty")
        let credits = NSAttributedString(
            string: creditsText,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
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
