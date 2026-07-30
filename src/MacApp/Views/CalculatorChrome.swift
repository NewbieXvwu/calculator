// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 各模式共用的窗口 chrome：
//   - 原生工具栏内容（历史侧栏开关 leading + 模式菜单 trailing，Apple 计算器同款布局）
//   - 物理键盘监听修饰符
// 视觉统一走系统工具栏材质；排版职责仍归各具体 View。

import AppKit
import SwiftUI

/// 工具栏模式菜单按钮（trailing 端，Apple 计算器惯例位置）。
/// 按钮字形：SF 公共库无 `calculator`，先以 `circle.grid.3x3` 兜底（TODO P1-3 自绘 symbol）。
struct ModeMenuButton: View {
    @ObservedObject var model: StandardCalculatorViewModel

    var body: some View {
        Menu {
            Picker(L10n.string("Mac_Menu_Mode"), selection: modeBinding) {
                Label(L10n.string("StandardModeText"), systemImage: "plus.slash.minus").tag(CalculatorMode.standard)
                Label(L10n.string("ScientificModeText"), systemImage: "function").tag(CalculatorMode.scientific)
                Label(L10n.string("ProgrammerModeText"), systemImage: "cpu").tag(CalculatorMode.programmer)
                Label(L10n.string("DateCalculationModeText"), systemImage: "calendar").tag(CalculatorMode.date)
                Label(L10n.string("ConverterModeText"), systemImage: "arrow.left.arrow.right").tag(CalculatorMode.converter)
                Label(L10n.string("GraphingCalculatorModeText"), systemImage: "chart.xyaxis.line").tag(CalculatorMode.graphing)
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "circle.grid.3x3")
        }
        .help(L10n.string("Mac_ModeButtonLabel"))
        .accessibilityLabel(L10n.string("Mac_ModeButtonLabel"))
    }

    private var modeBinding: Binding<CalculatorMode> {
        Binding(get: { model.mode }, set: { model.setCalculatorType($0) })
    }
}

/// 物理键盘监听：把系统按键事件转给 ViewModel，命中即消费。
private struct KeyMonitor: ViewModifier {
    @ObservedObject var model: StandardCalculatorViewModel
    @State private var keyMonitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear { install() }
            .onDisappear { remove() }
    }

    private func install() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // 文本输入/网页视图聚焦时放行：MathLive(WKWebView)、日期/换算的 NSTextField
            // 需要原样收到按键，否则计算器按键映射会吞掉输入。
            if KeyMonitor.isTextInputFocused { return event }
            let flags = event.modifierFlags
            let consumed = model.handleKey(
                chars: event.charactersIgnoringModifiers ?? "",
                keyCode: event.keyCode,
                modifiers: .init(
                    command: flags.contains(.command),
                    shift: flags.contains(.shift),
                    control: flags.contains(.control)
                )
            )
            return consumed ? nil : event
        }
    }

    private func remove() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    /// 当前第一响应者是否为文本输入或网页内容视图（此时放行按键，不做计算器映射）。
    static var isTextInputFocused: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        // NSText 覆盖 NSTextField 的 field editor 与 NSTextView。
        if responder is NSText { return true }
        // WKWebView 的内容视图为 WebKit 私有类（如 WKContentView / WKWebView）。
        let className = NSStringFromClass(type(of: responder))
        return className.hasPrefix("WK") || className.contains("WebKit")
    }
}

extension View {
    /// 安装物理键盘监听（标准/科学模式共用）。
    func calculatorKeyMonitor(model: StandardCalculatorViewModel) -> some View {
        modifier(KeyMonitor(model: model))
    }
}
