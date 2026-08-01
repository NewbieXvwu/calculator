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
    let model: StandardCalculatorViewModel

    var body: some View {
        VStack(spacing: 0) {
            DisplayArea(model: model)
            MemoryBar(model: model)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
            keypad
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .calculatorKeyMonitor(model: model)
    }

    private var keypad: some View {
        // 对照 CalculatorStandardOperators.xaml 的 Large/Medium/Small/Tiny 分档与
        // ShowStandardFunctions/HideStandardFunctions：按键盘可用高度选字号档，
        // 窄高度隐藏「函数行(¹⁄ₓ x² ²√x)+百分号」并保留全部运算符（compactFirstRow）。
        // 键面定义下沉至 KeyboardLayout.standard（S6 规格表），此处只负责分档与选行。
        GeometryReader { geo in
            let tier = LayoutTier.forKeypadHeight(geo.size.height)
            let spec = KeyboardLayout.standard
            let rows: [[KeySpec]] = tier.hideStandardFunctions
                ? [spec.compactFirstRow ?? spec.rows[0]] + Array(spec.rows.dropFirst(2))
                : spec.rows
            KeypadGrid(rows: rows, renderer: KeypadRenderer(model: model, tier: tier, flashes: true))
        }
    }
}

/// 响应式字号分档，对照原版 CalculatorStandardOperators.xaml 的 Large/Medium/Small/Tiny +
/// HideStandardFunctions（窄高度隐藏函数行/百分号）。阈值按 macOS 版较小窗体等比收敛。
/// 分档数据是唯一事实源（对应 spec/layout-tiers.json，S6 规格表下沉）。
struct LayoutTier {
    let name: String
    let minHeight: CGFloat
    let digitFont: CGFloat
    let opFont: CGFloat
    let funcFont: CGFloat
    let clearFont: CGFloat
    let hideStandardFunctions: Bool

    /// 按 minHeight 降序；最后一档 minHeight 0 兜底（compact + HideStandardFunctions，对应原版 Tiny 档）。
    static let all: [LayoutTier] = [
        LayoutTier(name: "large", minHeight: 360, digitFont: 26, opFont: 24, funcFont: 18, clearFont: 16, hideStandardFunctions: false),
        LayoutTier(name: "medium", minHeight: 260, digitFont: 18, opFont: 16, funcFont: 14, clearFont: 14, hideStandardFunctions: false),
        LayoutTier(name: "compact", minHeight: 0, digitFont: 16, opFont: 15, funcFont: 13, clearFont: 13, hideStandardFunctions: true),
    ]

    static func forKeypadHeight(_ height: CGFloat) -> LayoutTier {
        all.first { height >= $0.minHeight } ?? all.last!
    }
}

struct DisplayArea: View {
    let model: StandardCalculatorViewModel
    @State private var editingTokenID: Int?
    @State private var editingText = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(model.expressionTokens) { token in
                        tokenView(token)
                    }
                }
            }
            .defaultScrollAnchor(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .frame(height: 20)
            .accessibilityIdentifier("expressionDisplay")
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L10n.string("Mac_Expression"))
            .accessibilityValue(model.expressionTokens.map(\.text).joined())

            Text(model.displayValue)
                .font(.system(size: 48, weight: .light))
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.18), value: model.displayValue)
                .accessibilityIdentifier("primaryDisplay")
                .accessibilityLabel(L10n.string("Mac_Display"))
                .accessibilityValue(model.displayValue)
                .textSelection(.enabled)
                .overlay(alignment: .leading) {
                    // S10 精度闸门（M4）：截断过就明示近似，不装精确。
                    if model.isPrecisionLimited {
                        Text("≈")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(.secondary)
                            .help(L10n.string("Mac_PrecisionLimited"))
                            .accessibilityLabel(L10n.string("Mac_PrecisionLimited"))
                            .accessibilityIdentifier("precisionLimitedBadge")
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// 对应原版表达式区可点击 token(SaveEditedCommand/UpdateOperand):操作数可点击弹出编辑。
    @ViewBuilder
    private func tokenView(_ token: ExpressionToken) -> some View {
        if !model.isInError, model.mode != .programmer, model.isOperandTokenEditable(token.id) {
            Button {
                editingText = token.text
                editingTokenID = token.id
            } label: {
                Text(token.text)
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .underline(editingTokenID == token.id)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.format("Mac_EditOperand", token.text))
            .popover(isPresented: Binding(
                get: { editingTokenID == token.id },
                set: { if !$0 { editingTokenID = nil } }
            )) {
                operandEditor
            }
        } else {
            Text(token.text)
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var operandEditor: some View {
        VStack(spacing: 8) {
            TextField(L10n.string("Mac_Operand"), text: $editingText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
                .onSubmit(commitOperandEdit)
            HStack {
                Button(L10n.string("Mac_Cancel")) { editingTokenID = nil }
                Button(L10n.string("ErrorButtonOk"), action: commitOperandEdit)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
    }

    private func commitOperandEdit() {
        if let id = editingTokenID {
            model.updateOperand(tokenIndex: id, newText: editingText)
        }
        editingTokenID = nil
    }
}

/// 显示区下方的记忆栏：MC MR M+ M− MS（对应 Views/Calculator.xaml MemoryPanel）。
struct MemoryBar: View {
    let model: StandardCalculatorViewModel

    var body: some View {
        HStack(spacing: 2) {
            memoryKey("MC", disabled: model.isMemoryEmpty, a11y: L10n.string("Mac_MemClear")) { model.clearMemory() }
            memoryKey("MR", disabled: model.isMemoryEmpty, a11y: L10n.string("Mac_MemRecall")) { model.memoryItemPressed(0) }
            memoryKey("M+", disabled: model.isInError, a11y: L10n.string("Mac_MemAdd")) { model.memoryAdd(0) }
            memoryKey("M−", disabled: model.isInError, a11y: L10n.string("Mac_MemSubtract")) { model.memorySubtract(0) }
            memoryKey("MS", disabled: model.isInError, a11y: L10n.string("Mac_MemStore")) { model.memorizeNumber() }
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
