// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 排版 1:1 对照 Views/CalculatorStandardOperators.xaml + Views/Calculator.xaml：
//   顶栏（历史圆钮 + 模式菜单，取代原版汉堡导航，macOS 惯例 chrome）
//   表达式行 + 主显示
//   记忆栏 MC MR M+ M− MS
//   6 行 × 4 列键盘：
//     %   CE  C   ⌫
//     ¹⁄ₓ  x²  ²√x ÷
//     7   8   9   ×
//     4   5   6   −
//     1   2   3   +
//     ±   0   .   =
// 视觉使用 macOS 原生 Liquid Glass；右侧运算符列用系统橙（Apple 计算器语义）。

import AppKit
import SwiftUI

struct StandardCalculatorView: View {
    @ObservedObject var model: StandardCalculatorViewModel

    /// 窗口过窄放不下停靠面板时，顶栏显示历史弹出按钮（对应原版 HistoryButton）。
    var showsHistoryButton: Bool = false

    @State private var historyPopoverShown = false

    var body: some View {
        VStack(spacing: 0) {
            CalculatorHeader(model: model, showsHistoryButton: showsHistoryButton, historyPopoverShown: $historyPopoverShown)
            DisplayArea(model: model)
            MemoryBar(model: model)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
            keypad
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .calculatorKeyMonitor(model: model)
        .onChange(of: model.historyTogglePulse) {
            if showsHistoryButton { historyPopoverShown.toggle() }
        }
    }

    private var keypad: some View {
        GlassEffectContainer(spacing: 6) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    CalcKey(symbol: "percent", style: .function, disabled: model.isInError, flashing: flashing(.percent), a11yLabel: "百分比") { model.buttonPressed(.percent) }
                    CalcKey("CE", style: .function, fontSize: 14, flashing: flashing(.clearEntry), a11yLabel: "清除输入") { model.buttonPressed(.clearEntry) }
                    CalcKey("C", style: .function, fontSize: 14, flashing: flashing(.clear), a11yLabel: "清除") { model.buttonPressed(.clear) }
                    CalcKey(symbol: "delete.left", style: .function, flashing: flashing(.backspace), a11yLabel: "退格") { model.buttonPressed(.backspace) }
                }
                GridRow {
                    CalcKey("¹⁄ₓ", style: .function, disabled: model.isInError, flashing: flashing(.reciprocal), a11yLabel: "倒数") { model.buttonPressed(.reciprocal) }
                    CalcKey("x²", style: .function, disabled: model.isInError, flashing: flashing(.sqr), a11yLabel: "平方") { model.buttonPressed(.sqr) }
                    CalcKey("²√x", style: .function, disabled: model.isInError, flashing: flashing(.sqrt), a11yLabel: "平方根") { model.buttonPressed(.sqrt) }
                    CalcKey(symbol: "divide", style: .operatorKey, disabled: model.isInError, flashing: flashing(.divide), a11yLabel: "除") { model.buttonPressed(.divide) }
                }
                GridRow {
                    digitKey(7)
                    digitKey(8)
                    digitKey(9)
                    CalcKey(symbol: "multiply", style: .operatorKey, disabled: model.isInError, flashing: flashing(.multiply), a11yLabel: "乘") { model.buttonPressed(.multiply) }
                }
                GridRow {
                    digitKey(4)
                    digitKey(5)
                    digitKey(6)
                    CalcKey(symbol: "minus", style: .operatorKey, disabled: model.isInError, flashing: flashing(.subtract), a11yLabel: "减") { model.buttonPressed(.subtract) }
                }
                GridRow {
                    digitKey(1)
                    digitKey(2)
                    digitKey(3)
                    CalcKey(symbol: "plus", style: .operatorKey, disabled: model.isInError, flashing: flashing(.add), a11yLabel: "加") { model.buttonPressed(.add) }
                }
                GridRow {
                    CalcKey(symbol: "plus.forwardslash.minus", style: .digit, disabled: model.isInError, flashing: flashing(.sign), a11yLabel: "正负号") { model.buttonPressed(.sign) }
                    digitKey(0)
                    CalcKey(model.decimalSeparator, style: .digit, fontSize: 18, flashing: flashing(.point), a11yLabel: "小数点") { model.buttonPressed(.point) }
                    CalcKey(symbol: "equal", style: .operatorKey, flashing: flashing(.equals), a11yLabel: "等于") { model.buttonPressed(.equals) }
                }
            }
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        CalcKey("\(digit)", style: .digit, fontSize: 18, flashing: flashing(.digit(digit)), a11yLabel: "\(digit)") {
            model.digitPressed(digit)
        }
    }

    private func flashing(_ command: EngineCommand) -> Bool {
        model.flashedCommand == command
    }
}

struct DisplayArea: View {
    @ObservedObject var model: StandardCalculatorViewModel

    var body: some View {
        VStack(spacing: 0) {
            Text(model.expressionTokens.map(\.text).joined())
                .font(.system(size: 13))
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(.secondary)
                .frame(height: 18)
                .accessibilityIdentifier("expressionDisplay")

            Text(model.displayValue)
                .font(.system(size: 48, weight: .light))
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.18), value: model.displayValue)
                .accessibilityIdentifier("primaryDisplay")
                .accessibilityLabel("显示")
                .accessibilityValue(model.displayValue)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

/// 显示区下方的记忆栏：MC MR M+ M− MS（对应 Views/Calculator.xaml MemoryPanel）。
struct MemoryBar: View {
    @ObservedObject var model: StandardCalculatorViewModel

    var body: some View {
        HStack(spacing: 2) {
            memoryKey("MC", disabled: model.isMemoryEmpty, a11y: "清除内存") { model.clearMemory() }
            memoryKey("MR", disabled: model.isMemoryEmpty, a11y: "读取内存") { model.memoryItemPressed(0) }
            memoryKey("M+", disabled: model.isInError, a11y: "内存加") { model.memoryAdd(0) }
            memoryKey("M−", disabled: model.isInError, a11y: "内存减") { model.memorySubtract(0) }
            memoryKey("MS", disabled: model.isInError, a11y: "存入内存") { model.memorizeNumber() }
        }
        .frame(height: 26)
    }

    private func memoryKey(_ label: String, disabled: Bool, a11y: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(disabled ? Color.primary.opacity(0.25) : Color.primary.opacity(0.75))
        .disabled(disabled)
        .accessibilityLabel(a11y)
    }
}
