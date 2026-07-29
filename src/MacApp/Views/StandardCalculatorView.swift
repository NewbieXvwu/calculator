// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 排版 1:1 对照 Views/CalculatorStandardOperators.xaml + Views/Calculator.xaml：
//   顶栏（模式标题 + 历史按钮）
//   表达式行 + 主显示
//   记忆栏 MC MR M+ M− MS
//   6 行 × 4 列键盘：
//     %   CE  C   ⌫
//     ¹⁄ₓ  x²  ²√x ÷
//     7   8   9   ×
//     4   5   6   −
//     1   2   3   +
//     ±   0   .   =
// 视觉使用 macOS 原生语言（SF Symbols、系统色、悬停态）。

import SwiftUI

struct StandardCalculatorView: View {
    @ObservedObject var model: StandardCalculatorViewModel

    /// 窗口过窄放不下停靠面板时，顶栏显示历史弹出按钮（对应原版 HistoryButton）。
    var showsHistoryButton: Bool = false

    @State private var historyPopoverShown = false

    var body: some View {
        VStack(spacing: 0) {
            header
            DisplayArea(model: model)
            MemoryBar(model: model)
                .padding(.horizontal, 6)
                .padding(.bottom, 2)
            keypad
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
    }

    // 原版顶栏：☰ + 模式名；右侧历史按钮。macOS 下汉堡菜单由工具栏/侧栏替代，
    // 这里保留模式标题与历史按钮的位置关系。
    private var header: some View {
        HStack {
            Text("标准")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            if showsHistoryButton {
                Button {
                    historyPopoverShown.toggle()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderless)
                .help("历史记录")
                .popover(isPresented: $historyPopoverShown, arrowEdge: .bottom) {
                    HistoryListView(model: model)
                        .frame(width: 280, height: 320)
                }
            }
        }
        .padding(.leading, 76) // 隐藏标题栏后为左上角红绿灯按钮留位
        .padding(.trailing, 12)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private var keypad: some View {
        GlassEffectContainer(spacing: 4) {
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                CalcKey(symbol: "percent", style: .function, disabled: model.isInError) { model.buttonPressed(.percent) }
                CalcKey("CE", style: .function, fontSize: 14) { model.buttonPressed(.clearEntry) }
                CalcKey("C", style: .function, fontSize: 14) { model.buttonPressed(.clear) }
                CalcKey(symbol: "delete.left", style: .function) { model.buttonPressed(.backspace) }
            }
            GridRow {
                CalcKey("¹⁄ₓ", style: .function, disabled: model.isInError) { model.buttonPressed(.reciprocal) }
                CalcKey("x²", style: .function, disabled: model.isInError) { model.buttonPressed(.sqr) }
                CalcKey("²√x", style: .function, disabled: model.isInError) { model.buttonPressed(.sqrt) }
                CalcKey(symbol: "divide", style: .function, disabled: model.isInError) { model.buttonPressed(.divide) }
            }
            GridRow {
                digitKey(7)
                digitKey(8)
                digitKey(9)
                CalcKey(symbol: "multiply", style: .function, disabled: model.isInError) { model.buttonPressed(.multiply) }
            }
            GridRow {
                digitKey(4)
                digitKey(5)
                digitKey(6)
                CalcKey(symbol: "minus", style: .function, disabled: model.isInError) { model.buttonPressed(.subtract) }
            }
            GridRow {
                digitKey(1)
                digitKey(2)
                digitKey(3)
                CalcKey(symbol: "plus", style: .function, disabled: model.isInError) { model.buttonPressed(.add) }
            }
            GridRow {
                CalcKey(symbol: "plus.forwardslash.minus", style: .digit, disabled: model.isInError) { model.buttonPressed(.sign) }
                digitKey(0)
                CalcKey(model.decimalSeparator, style: .digit, fontSize: 18) { model.buttonPressed(.point) }
                CalcKey(symbol: "equal", style: .accent) { model.buttonPressed(.equals) }
            }
            }
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        CalcKey("\(digit)", style: .digit, fontSize: 18) { model.digitPressed(digit) }
    }
}

struct DisplayArea: View {
    @ObservedObject var model: StandardCalculatorViewModel

    var body: some View {
        VStack(spacing: 0) {
            Text(model.expressionTokens.map(\.text).joined())
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(.secondary)
                .frame(height: 18)
                .accessibilityIdentifier("expressionDisplay")

            Text(model.displayValue)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("primaryDisplay")
                .textSelection(.enabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}

/// 显示区下方的记忆栏：MC MR M+ M− MS（对应 Views/Calculator.xaml MemoryPanel）。
struct MemoryBar: View {
    @ObservedObject var model: StandardCalculatorViewModel

    var body: some View {
        HStack(spacing: 2) {
            memoryKey("MC", disabled: model.isMemoryEmpty) { model.clearMemory() }
            memoryKey("MR", disabled: model.isMemoryEmpty) { model.memoryItemPressed(0) }
            memoryKey("M+", disabled: model.isInError) { model.memoryAdd(0) }
            memoryKey("M−", disabled: model.isInError) { model.memorySubtract(0) }
            memoryKey("MS", disabled: model.isInError) { model.memorizeNumber() }
        }
        .frame(height: 26)
    }

    private func memoryKey(_ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(disabled ? Color.primary.opacity(0.25) : Color.primary.opacity(0.75))
        .disabled(disabled)
    }
}
