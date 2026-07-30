// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 排版对照 Views/CalculatorProgrammerRadixOperators.xaml + CalculatorProgrammerOperators.xaml
// + CalculatorProgrammerDisplayPanel.xaml：
//   顶栏（历史圆钮 + 模式菜单）
//   表达式行 + 主显示
//   四进制转换行 HEX / DEC / OCT / BIN（点按切换当前进制，对应左侧 RadixButton 组）
//   控制栏：[整键盘 / 位翻转 分段] [字长循环按钮 QWORD…BYTE]
//   记忆栏 MC MR M+ M− MS
//   整键盘：位运算 ▾ / 移位 ▾ 菜单栏 + 键盘网格（A–F 列 + 数字 + 运算符）
//   位翻转键盘：按字长显示 64/32/16/8 位开关
// 视觉沿用 Liquid Glass；右侧运算符列系统橙；HEX 字母键随进制启用/禁用。

import SwiftUI

struct ProgrammerCalculatorView: View {
    @ObservedObject var model: StandardCalculatorViewModel

    var showsHistoryButton: Bool = false

    @State private var historyPopoverShown = false

    var body: some View {
        VStack(spacing: 0) {
            CalculatorHeader(model: model, showsHistoryButton: showsHistoryButton, historyPopoverShown: $historyPopoverShown)
            DisplayArea(model: model)
            radixRows
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            controlBar
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
            MemoryBar(model: model)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)
            if model.isBitFlipChecked {
                bitFlipPanel
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            } else {
                operatorPanelBar
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                keypad
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .calculatorKeyMonitor(model: model)
    }

    // MARK: - 四进制转换行

    private var radixRows: some View {
        VStack(spacing: 2) {
            radixRow(.hex, value: model.hexDisplay)
            radixRow(.dec, value: model.decDisplay)
            radixRow(.oct, value: model.octDisplay)
            radixRow(.bin, value: model.binDisplay)
        }
    }

    private func radixRow(_ radix: RadixKind, value: String) -> some View {
        let selected = model.currentRadix == radix
        return Button {
            model.switchRadix(radix)
        } label: {
            HStack(spacing: 8) {
                Text(radix.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(selected ? Color.orange : .secondary)
                    .frame(width: 40, alignment: .leading)
                Text(value.isEmpty ? "0" : value)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? Color.orange.opacity(0.12) : Color.clear)
        )
        .disabled(model.isInError)
        .accessibilityLabel("\(radix.label) \(value)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - 整键盘 / 位翻转 + 字长 控制栏

    private var controlBar: some View {
        HStack(spacing: 6) {
            Picker("", selection: keypadModeBinding) {
                Image(systemName: "square.grid.3x3").tag(false)
                Image(systemName: "switch.2").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 96)
            .help("整键盘 / 位翻转")

            Button {
                model.cycleWordSize()
            } label: {
                Text(model.wordSize.label)
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .glassButtonStyle()
            .controlSize(.small)
            .help("字长（点按循环 QWORD / DWORD / WORD / BYTE）")
            .accessibilityLabel("字长 \(model.wordSize.label)")

            Spacer(minLength: 0)
        }
        .frame(height: 24)
    }

    private var keypadModeBinding: Binding<Bool> {
        Binding(get: { model.isBitFlipChecked }, set: { _ in model.toggleBitFlip() })
    }

    // MARK: - 位运算 / 移位 菜单栏

    private var operatorPanelBar: some View {
        HStack(spacing: 6) {
            Menu {
                opItem("AND", .and); opItem("OR", .or); opItem("XOR", .xor)
                opItem("NOT", .not); opItem("NAND", .nand); opItem("NOR", .nor)
            } label: {
                Label("位运算", systemImage: "logo.playstation")
            }
            .menuStyle(.button)
            .glassButtonStyle()
            .controlSize(.regular)
            .disabled(model.isInError)

            Menu {
                Picker("移位类型", selection: $model.shiftMode) {
                    ForEach(BitShiftMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Label("移位", systemImage: "arrow.left.arrow.right")
            }
            .menuStyle(.button)
            .glassButtonStyle()
            .controlSize(.regular)
            .disabled(model.isInError)

            Spacer(minLength: 0)
        }
        .frame(height: 30)
    }

    private func opItem(_ title: String, _ command: EngineCommand) -> some View {
        Button(title) { model.buttonPressed(command) }
    }

    // MARK: - 整键盘网格
    // 布局（6 行 × 5 列，col0 = A–F，col4 = 运算符）：
    //   A | Lsh | Rsh | CE/C | ⌫
    //   B |  (  |  )  |  %   | ÷
    //   C |  7  |  8  |  9   | ×
    //   D |  4  |  5  |  6   | −
    //   E |  1  |  2  |  3   | +
    //   F |  ±  |  0  |     =(跨列)

    private var keypad: some View {
        GlassKeypadContainer(spacing: 6) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    hexKey("A", .digitA)
                    CalcKey(model.shiftMode.leftKey.label, style: .function, fontSize: model.shiftMode.leftKey.label.count > 1 ? 12 : 16, disabled: model.isInError, a11yLabel: "左移（\(model.shiftMode.label)）") { model.buttonPressed(model.shiftMode.leftKey.command) }
                    CalcKey(model.shiftMode.rightKey.label, style: .function, fontSize: model.shiftMode.rightKey.label.count > 1 ? 12 : 16, disabled: model.isInError, a11yLabel: "右移（\(model.shiftMode.label)）") { model.buttonPressed(model.shiftMode.rightKey.command) }
                    clearKey
                    CalcKey(symbol: "delete.left", style: .function, a11yLabel: L10n.button("backSpaceButton")) { model.buttonPressed(.backspace) }
                }
                GridRow {
                    hexKey("B", .digitB)
                    CalcKey("(", style: .function, fontSize: 18, disabled: model.isInError, a11yLabel: L10n.button("openParenthesisButton")) { model.buttonPressed(.openParen) }
                    CalcKey(")", style: .function, fontSize: 18, disabled: model.isInError, a11yLabel: L10n.button("closeParenthesisButton")) { model.buttonPressed(.closeParen) }
                    CalcKey("%", style: .function, disabled: model.isInError, a11yLabel: L10n.button("modButton")) { model.buttonPressed(.mod) }
                    CalcKey(symbol: "divide", style: .operatorKey, disabled: model.isInError, a11yLabel: L10n.button("divideButton")) { model.buttonPressed(.divide) }
                }
                GridRow {
                    hexKey("C", .digitC)
                    digitKey(7); digitKey(8); digitKey(9)
                    CalcKey(symbol: "multiply", style: .operatorKey, disabled: model.isInError, a11yLabel: L10n.button("multiplyButton")) { model.buttonPressed(.multiply) }
                }
                GridRow {
                    hexKey("D", .digitD)
                    digitKey(4); digitKey(5); digitKey(6)
                    CalcKey(symbol: "minus", style: .operatorKey, disabled: model.isInError, a11yLabel: L10n.button("minusButton")) { model.buttonPressed(.subtract) }
                }
                GridRow {
                    hexKey("E", .digitE)
                    digitKey(1); digitKey(2); digitKey(3)
                    CalcKey(symbol: "plus", style: .operatorKey, disabled: model.isInError, a11yLabel: L10n.button("plusButton")) { model.buttonPressed(.add) }
                }
                GridRow {
                    hexKey("F", .digitF)
                    CalcKey(symbol: "plus.forwardslash.minus", style: .digit, disabled: model.isInError, a11yLabel: L10n.button("negateButton")) { model.buttonPressed(.sign) }
                    digitKey(0)
                    CalcKey(symbol: "equal", style: .operatorKey, a11yLabel: L10n.button("equalButton")) { model.buttonPressed(.equals) }
                        .gridCellColumns(2)
                }
            }
        }
    }

    /// CE/C：有输入时显示 CE，否则显示 C（对应原版可见性切换）。
    @ViewBuilder
    private var clearKey: some View {
        if model.isInputEmpty {
            CalcKey("C", style: .function, fontSize: 14, a11yLabel: L10n.button("clearButton")) { model.buttonPressed(.clear) }
        } else {
            CalcKey("CE", style: .function, fontSize: 14, a11yLabel: L10n.button("clearEntryButton")) { model.buttonPressed(.clearEntry) }
        }
    }

    /// A–F 十六进制键：仅 HEX 进制下可用（对应 AreHEXButtonsEnabled）。
    private func hexKey(_ label: String, _ command: EngineCommand) -> some View {
        CalcKey(label, style: .function, fontSize: 16, disabled: model.isInError || !model.areHexButtonsEnabled, a11yLabel: L10n.button("\(label.lowercased())Button")) {
            model.buttonPressed(command)
        }
    }

    /// 0–9 数字键：按当前进制启用/禁用。
    private func digitKey(_ digit: Int) -> some View {
        CalcKey("\(digit)", style: .digit, fontSize: 18, disabled: model.isInError || !model.isDigitAllowed(digit), a11yLabel: L10n.button("num\(digit)Button")) {
            model.digitPressed(digit)
        }
    }

    // MARK: - 位翻转面板

    // 对应 CalculatorProgrammerBitFlipPanel.xaml：固定 64 位，4 行 × 16 位，
    // 每 4 位一个半字节组（组间 gutter），组下方标注该组最低位序号（60/56/…/0）；
    // 超出当前字长的位禁用而非隐藏（ShouldEnableBit）。
    private var bitFlipPanel: some View {
        let enabledCount = model.wordSize.bitCount
        return VStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { rowIndex in
                let rowHigh = 63 - rowIndex * 16
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { group in
                            HStack(spacing: 2) {
                                ForEach(0..<4, id: \.self) { i in
                                    bitToggle(rowHigh - group * 4 - i, enabled: rowHigh - group * 4 - i < enabledCount)
                                }
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { group in
                            HStack(spacing: 2) {
                                ForEach(0..<4, id: \.self) { i in
                                    Text(i == 3 ? "\(rowHigh - group * 4 - 3)" : "")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func bitToggle(_ position: Int, enabled: Bool) -> some View {
        let on = enabled && position < model.binaryBits.count && model.binaryBits[position]
        return Button {
            model.flipBit(position)
        } label: {
            Text(on ? "1" : "0")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(!enabled ? AnyShapeStyle(.tertiary)
                                 : on ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.primary))
                .frame(maxWidth: .infinity, minHeight: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(on ? Color.orange.opacity(0.15) : Color.primary.opacity(0.04))
        )
        .disabled(model.isInError || !enabled)
        .accessibilityLabel("第 \(position) 位")
        .accessibilityValue(on ? "1" : "0")
    }
}
