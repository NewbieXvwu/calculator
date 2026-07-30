// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 排版 1:1 对照 Views/CalculatorScientificOperators.xaml + CalculatorScientificAngleButtons.xaml：
//   顶栏（历史圆钮 + 模式菜单）
//   表达式行 + 主显示
//   记忆栏 MC MR M+ M− MS
//   角度/进制切换栏：[DEG/RAD/GRAD 循环]  [F-E]
//   运算面板栏：[三角 ▾]  [函数 ▾]
//   科学键盘（外层 8 行 × 5 列，此处按 1 + 6 行铺开）：
//     行1：  2nd(INV) | π | e | CE/C | ⌫
//     左列（行2-7，随 2nd 切换）：x² √x xʸ 10ˣ log ln  ↔  x³ ∛x ʸ√x 2ˣ logᵧ eˣ
//     行2：  ·左· | 1/x | |x| | exp | mod
//     行3：  ·左· |  (  |  )  |  n! | ÷
//     行4：  ·左· |  7  |  8  |  9  | ×
//     行5：  ·左· |  4  |  5  |  6  | −
//     行6：  ·左· |  1  |  2  |  3  | +
//     行7：  ·左· |  ±  |  0  |  .  | =
// 视觉沿用 Liquid Glass：数字最亮灰阶、函数深灰、右侧运算符列系统橙、2nd/角度态用强调橙。

import SwiftUI

struct ScientificCalculatorView: View {
    @ObservedObject var model: StandardCalculatorViewModel

    var showsHistoryButton: Bool = false

    @State private var historyPopoverShown = false

    // 左侧函数列：(常规文字, 常规命令, 2nd 文字, 2nd 命令)，行 2-7 各一项。
    private let functionColumn: [(String, EngineCommand, String, EngineCommand)] = [
        ("x²", .sqr, "x³", .cube),
        ("√x", .sqrt, "∛x", .cubeRoot),
        ("xʸ", .power, "ʸ√x", .yroot),
        ("10ˣ", .pow10, "2ˣ", .pow2),
        ("log", .log, "logᵧ", .logBaseY),
        ("ln", .ln, "eˣ", .powE),
    ]

    var body: some View {
        VStack(spacing: 0) {
            CalculatorHeader(model: model, showsHistoryButton: showsHistoryButton, historyPopoverShown: $historyPopoverShown)
            DisplayArea(model: model)
            MemoryBar(model: model)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
            angleBar
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
            operatorPanelBar
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            keypad
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .calculatorKeyMonitor(model: model)
        .onChange(of: model.historyTogglePulse) {
            if showsHistoryButton { historyPopoverShown.toggle() }
        }
        .onChange(of: historyPopoverShown) {
            AccessibilityAnnouncer.announce(historyPopoverShown ? "历史记录面板已打开" : "历史记录面板已关闭", highPriority: false)
        }
    }

    // MARK: - 角度 / F-E 栏

    private var angleBar: some View {
        HStack(spacing: 6) {
            Button {
                model.cycleAngle()
            } label: {
                Text(model.angleLabel)
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(model.isInError)
            .help("角度单位（点按循环 DEG / RAD / GRAD）")
            .accessibilityLabel("角度单位 \(model.angleLabel)")

            Button {
                model.isFToEChecked.toggle()
                model.fToEButtonToggled()
            } label: {
                Text("F-E")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .tint(model.isFToEChecked ? Color.orange : nil)
            .disabled(model.isInError || !model.isFToEEnabled)
            .accessibilityLabel("科学计数法切换")

            Spacer(minLength: 0)
        }
        .frame(height: 24)
    }

    // MARK: - 三角 / 函数 下拉面板

    private var operatorPanelBar: some View {
        HStack(spacing: 6) {
            Menu {
                trigItem("sin", .sin); trigItem("cos", .cos); trigItem("tan", .tan)
                trigItem("sec", .sec); trigItem("csc", .csc); trigItem("cot", .cot)
                Menu("反三角函数") {
                    trigItem("sin⁻¹", .asin); trigItem("cos⁻¹", .acos); trigItem("tan⁻¹", .atan)
                    trigItem("sec⁻¹", .asec); trigItem("csc⁻¹", .acsc); trigItem("cot⁻¹", .acot)
                }
                Menu("双曲函数") {
                    trigItem("sinh", .sinh); trigItem("cosh", .cosh); trigItem("tanh", .tanh)
                    trigItem("sech", .sech); trigItem("csch", .csch); trigItem("coth", .coth)
                }
                Menu("反双曲函数") {
                    trigItem("sinh⁻¹", .asinh); trigItem("cosh⁻¹", .acosh); trigItem("tanh⁻¹", .atanh)
                    trigItem("sech⁻¹", .asech); trigItem("csch⁻¹", .acsch); trigItem("coth⁻¹", .acoth)
                }
            } label: {
                Label("三角", systemImage: "angle")
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .controlSize(.regular)
            .disabled(model.isInError)

            Menu {
                trigItem("|x|", .abs)
                trigItem("⌊x⌋", .floor)
                trigItem("⌈x⌉", .ceil)
                trigItem("rand", .rand)
                trigItem("dms", .dms)
                trigItem("deg", .degrees)
            } label: {
                Label("函数", systemImage: "f.cursive")
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .controlSize(.regular)
            .disabled(model.isInError)

            Spacer(minLength: 0)
        }
        .frame(height: 30)
    }

    private func trigItem(_ title: String, _ command: EngineCommand) -> some View {
        Button(title) { model.buttonPressed(command) }
    }

    // MARK: - 科学键盘

    private var keypad: some View {
        GlassEffectContainer(spacing: 6) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                // 行 1：2nd | π | e | CE/C | ⌫
                GridRow {
                    CalcKey("2ⁿᵈ", style: model.isInvChecked ? .emphasized : .function, fontSize: 14, disabled: model.isInError, a11yLabel: "第二功能") {
                        model.toggleInv()
                    }
                    CalcKey("π", style: .function, disabled: model.isInError, a11yLabel: "圆周率") { model.buttonPressed(.pi) }
                    CalcKey("e", style: .function, disabled: model.isInError, a11yLabel: "自然常数 e") { model.buttonPressed(.euler) }
                    clearKey
                    CalcKey(symbol: "delete.left", style: .function, a11yLabel: "退格") { model.buttonPressed(.backspace) }
                }
                // 行 2：左列 | 1/x | |x| | exp | mod
                GridRow {
                    functionColumnKey(row: 0)
                    CalcKey("¹⁄ₓ", style: .function, disabled: model.isInError, a11yLabel: "倒数") { model.buttonPressed(.reciprocal) }
                    CalcKey("|x|", style: .function, disabled: model.isInError, a11yLabel: "绝对值") { model.buttonPressed(.abs) }
                    CalcKey("exp", style: .function, disabled: model.isInError, a11yLabel: "指数") { model.buttonPressed(.exp) }
                    CalcKey("mod", style: .function, disabled: model.isInError, a11yLabel: "取模") { model.buttonPressed(.mod) }
                }
                // 行 3：左列 | ( | ) | n! | ÷
                GridRow {
                    functionColumnKey(row: 1)
                    CalcKey("(", style: .function, fontSize: 18, disabled: model.isInError, a11yLabel: "左括号") { model.buttonPressed(.openParen) }
                    CalcKey(")", style: .function, fontSize: 18, disabled: model.isInError, a11yLabel: "右括号") { model.buttonPressed(.closeParen) }
                    CalcKey("n!", style: .function, disabled: model.isInError, a11yLabel: "阶乘") { model.buttonPressed(.factorial) }
                    CalcKey(symbol: "divide", style: .operatorKey, disabled: model.isInError, a11yLabel: "除") { model.buttonPressed(.divide) }
                }
                // 行 4：左列 | 7 | 8 | 9 | ×
                GridRow {
                    functionColumnKey(row: 2)
                    digitKey(7); digitKey(8); digitKey(9)
                    CalcKey(symbol: "multiply", style: .operatorKey, disabled: model.isInError, a11yLabel: "乘") { model.buttonPressed(.multiply) }
                }
                // 行 5：左列 | 4 | 5 | 6 | −
                GridRow {
                    functionColumnKey(row: 3)
                    digitKey(4); digitKey(5); digitKey(6)
                    CalcKey(symbol: "minus", style: .operatorKey, disabled: model.isInError, a11yLabel: "减") { model.buttonPressed(.subtract) }
                }
                // 行 6：左列 | 1 | 2 | 3 | +
                GridRow {
                    functionColumnKey(row: 4)
                    digitKey(1); digitKey(2); digitKey(3)
                    CalcKey(symbol: "plus", style: .operatorKey, disabled: model.isInError, a11yLabel: "加") { model.buttonPressed(.add) }
                }
                // 行 7：左列 | ± | 0 | . | =
                GridRow {
                    functionColumnKey(row: 5)
                    CalcKey(symbol: "plus.forwardslash.minus", style: .digit, disabled: model.isInError, a11yLabel: "正负号") { model.buttonPressed(.sign) }
                    digitKey(0)
                    CalcKey(model.decimalSeparator, style: .digit, fontSize: 18, a11yLabel: "小数点") { model.buttonPressed(.point) }
                    CalcKey(symbol: "equal", style: .operatorKey, a11yLabel: "等于") { model.buttonPressed(.equals) }
                }
            }
        }
    }

    /// CE/C：有输入时显示 CE，否则显示 C（对应原版可见性切换）。
    @ViewBuilder
    private var clearKey: some View {
        if model.isInputEmpty {
            CalcKey("C", style: .function, fontSize: 14, a11yLabel: "清除") { model.buttonPressed(.clear) }
        } else {
            CalcKey("CE", style: .function, fontSize: 14, a11yLabel: "清除输入") { model.buttonPressed(.clearEntry) }
        }
    }

    private func functionColumnKey(row: Int) -> some View {
        let entry = functionColumn[row]
        let inv = model.isInvChecked
        let label = inv ? entry.2 : entry.0
        let command = inv ? entry.3 : entry.1
        return CalcKey(label, style: inv ? .emphasized : .function, fontSize: 14, disabled: model.isInError, a11yLabel: label) {
            model.pressInvFunction(command)
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        CalcKey("\(digit)", style: .digit, fontSize: 18, a11yLabel: "\(digit)") {
            model.digitPressed(digit)
        }
    }
}
