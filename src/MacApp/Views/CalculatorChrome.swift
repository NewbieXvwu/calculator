// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 标准/科学模式共用的窗口 chrome：
//   - 顶栏（历史圆钮 + 模式菜单，macOS 惯例，取代原版汉堡导航）
//   - 物理键盘监听修饰符
// 视觉统一走 Liquid Glass；排版职责仍归各具体 View。

import AppKit
import SwiftUI

/// 顶栏：左历史圆钮（窄窗时），右模式菜单，均为系统玻璃按钮。
struct CalculatorHeader: View {
    @ObservedObject var model: StandardCalculatorViewModel
    var showsHistoryButton: Bool
    @Binding var historyPopoverShown: Bool

    var body: some View {
        HStack(spacing: 8) {
            if showsHistoryButton {
                Button {
                    historyPopoverShown.toggle()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                .help("历史记录")
                .accessibilityLabel("历史记录")
                .popover(isPresented: $historyPopoverShown, arrowEdge: .bottom) {
                    HistoryListView(model: model)
                        .frame(width: 280, height: 320)
                }
            }

            Spacer()

            Menu {
                Picker("模式", selection: modeBinding) {
                    Label("标准", systemImage: "plusminus").tag(CalculatorMode.standard)
                    Label("科学", systemImage: "function").tag(CalculatorMode.scientific)
                    Label("程序员", systemImage: "chevron.left.forwardslash.chevron.right").tag(CalculatorMode.programmer)
                    Label("日期计算", systemImage: "calendar").tag(CalculatorMode.date)
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: modeIcon)
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .controlSize(.large)
            .fixedSize()
            .help("计算器模式")
            .accessibilityLabel("计算器模式")
        }
        .padding(.leading, 76) // 隐藏标题栏后为左上角红绿灯按钮留位
        .padding(.trailing, 12)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private var modeIcon: String {
        switch model.mode {
        case .scientific: return "function"
        case .programmer: return "chevron.left.forwardslash.chevron.right"
        case .standard: return "square.grid.2x2"
        case .date: return "calendar"
        }
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
            let hasCommand = event.modifierFlags.contains(.command)
            let consumed = model.handleKey(
                chars: event.charactersIgnoringModifiers ?? "",
                keyCode: event.keyCode,
                hasCommand: hasCommand
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
}

extension View {
    /// 安装物理键盘监听（标准/科学模式共用）。
    func calculatorKeyMonitor(model: StandardCalculatorViewModel) -> some View {
        modifier(KeyMonitor(model: model))
    }
}
