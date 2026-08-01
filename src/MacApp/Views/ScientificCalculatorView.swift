// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 排版 1:1 对照 Views/CalculatorScientificOperators.xaml + CalculatorScientificAngleButtons.xaml：
//   顶栏（历史圆钮 + 模式菜单）
//   表达式行 + 主显示
//   记忆栏 MC MR M+ M− MS
//   角度/F-E 切换栏：[DEG/RAD/GRAD 循环]  [F-E]
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
    let model: StandardCalculatorViewModel

    // 左侧函数列：(常规文字, 常规命令, 2nd 文字, 2nd 命令)，行 2-7 各一项。
    // 由 KeyboardLayout.scientific 的 invPair 键派生（S6 规格表单一事实源），
    // SpecTableTests 与 spec/keyboard-layout.json 双向防漂移。
    static let functionColumn: [(String, EngineCommand, String, EngineCommand)] =
        KeyboardLayout.scientific.rows.dropFirst().compactMap { row in
            guard case .invPair(let normal, let inverted)? = row.first?.role else { return nil }
            return (normal.label, normal.command, inverted.label, inverted.command)
        }

    var body: some View {
        VStack(spacing: 0) {
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
            .glassButtonStyle()
            .controlSize(.small)
            .disabled(model.isInError)
            .help(L10n.string("Mac_AngleUnitHelp"))
            .accessibilityLabel(L10n.format("Mac_AngleUnit", model.angleLabel))

            Button {
                model.isFToEChecked.toggle()
                model.fToEButtonToggled()
            } label: {
                Text("F-E")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .glassButtonStyle()
            .controlSize(.small)
            .tint(model.isFToEChecked ? Color.orange : nil)
            .disabled(model.isInError || !model.isFToEEnabled)
            .accessibilityLabel(L10n.string("Mac_SciNotationToggle"))

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
                Menu(L10n.string("Mac_InverseTrig")) {
                    trigItem("sin⁻¹", .asin); trigItem("cos⁻¹", .acos); trigItem("tan⁻¹", .atan)
                    trigItem("sec⁻¹", .asec); trigItem("csc⁻¹", .acsc); trigItem("cot⁻¹", .acot)
                }
                Menu(L10n.button("hypButton")) {
                    trigItem("sinh", .sinh); trigItem("cosh", .cosh); trigItem("tanh", .tanh)
                    trigItem("sech", .sech); trigItem("csch", .csch); trigItem("coth", .coth)
                }
                Menu(L10n.string("Mac_InverseHyp")) {
                    trigItem("sinh⁻¹", .asinh); trigItem("cosh⁻¹", .acosh); trigItem("tanh⁻¹", .atanh)
                    trigItem("sech⁻¹", .asech); trigItem("csch⁻¹", .acsch); trigItem("coth⁻¹", .acoth)
                }
            } label: {
                Label(L10n.string("Mac_Trig"), systemImage: AppIcon.sciTrigMenu.sfSymbol)
            }
            .menuStyle(.button)
            .glassButtonStyle()
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
                Label(L10n.string("funcButton.Text"), systemImage: AppIcon.sciFuncMenu.sfSymbol)
            }
            .menuStyle(.button)
            .glassButtonStyle()
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

    // 键面定义下沉至 KeyboardLayout.scientific（S6 规格表），此处只做数据驱动渲染。
    private var keypad: some View {
        KeypadGrid(rows: KeyboardLayout.scientific.rows, renderer: KeypadRenderer(model: model))
    }
}
