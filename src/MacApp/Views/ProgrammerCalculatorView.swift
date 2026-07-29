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
            .buttonStyle(.glass)
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
            .buttonStyle(.glass)
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
            .buttonStyle(.glass)
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
        GlassEffectContainer(spacing: 6) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    hexKey("A", .digitA)
                    CalcKey(model.shiftMode.leftKey.label, style: .function, fontSize: model.shiftMode.leftKey.label.count > 1 ? 12 : 16, disabled: model.isInError, a11yLabel: "左移（\(model.shiftMode.label)）") { model.buttonPressed(model.shiftMode.leftKey.command) }
                    CalcKey(model.shiftMode.rightKey.label, style: .function, fontSize: model.shiftMode.rightKey.label.count > 1 ? 12 : 16, disabled: model.isInError, a11yLabel: "右移（\(model.shiftMode.label)）") { model.buttonPressed(model.shiftMode.rightKey.command) }
                    clearKey
                    CalcKey(symbol: "delete.left", style: .function, a11yLabel: "退格") { model.buttonPressed(.backspace) }
                }
                GridRow {
                    hexKey("B", .digitB)
                    CalcKey("(", style: .function, fontSize: 18, disabled: model.isInError, a11yLabel: "左括号") { model.buttonPressed(.openParen) }
                    CalcKey(")", style: .function, fontSize: 18, disabled: model.isInError, a11yLabel: "右括号") { model.buttonPressed(.closeParen) }
                    CalcKey("%", style: .function, disabled: model.isInError, a11yLabel: "取模") { model.buttonPressed(.mod) }
                    CalcKey(symbol: "divide", style: .operatorKey, disabled: model.isInError, a11yLabel: "除") { model.buttonPressed(.divide) }
                }
                GridRow {
                    hexKey("C", .digitC)
                    digitKey(7); digitKey(8); digitKey(9)
                    CalcKey(symbol: "multiply", style: .operatorKey, disabled: model.isInError, a11yLabel: "乘") { model.buttonPressed(.multiply) }
                }
                GridRow {
                    hexKey("D", .digitD)
                    digitKey(4); digitKey(5); digitKey(6)
                    CalcKey(symbol: "minus", style: .operatorKey, disabled: model.isInError, a11yLabel: "减") { model.buttonPressed(.subtract) }
                }
                GridRow {
                    hexKey("E", .digitE)
                    digitKey(1); digitKey(2); digitKey(3)
                    CalcKey(symbol: "plus", style: .operatorKey, disabled: model.isInError, a11yLabel: "加") { model.buttonPressed(.add) }
                }
                GridRow {
                    hexKey("F", .digitF)
                    CalcKey(symbol: "plus.forwardslash.minus", style: .digit, disabled: model.isInError, a11yLabel: "正负号") { model.buttonPressed(.sign) }
                    digitKey(0)
                    CalcKey(symbol: "equal", style: .operatorKey, a11yLabel: "等于") { model.buttonPressed(.equals) }
                        .gridCellColumns(2)
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

    /// A–F 十六进制键：仅 HEX 进制下可用（对应 AreHEXButtonsEnabled）。
    private func hexKey(_ label: String, _ command: EngineCommand) -> some View {
        CalcKey(label, style: .function, fontSize: 16, disabled: model.isInError || !model.areHexButtonsEnabled, a11yLabel: label) {
            model.buttonPressed(command)
        }
    }

    /// 0–9 数字键：按当前进制启用/禁用。
    private func digitKey(_ digit: Int) -> some View {
        CalcKey("\(digit)", style: .digit, fontSize: 18, disabled: model.isInError || !model.isDigitAllowed(digit), a11yLabel: "\(digit)") {
            model.digitPressed(digit)
        }
    }

    // MARK: - 位翻转面板

    private var bitFlipPanel: some View {
        let bitCount = model.wordSize.bitCount
        // 每行 8 位，MSB 在最上；每 4 位一组间隔以区分半字节。
        let rows = stride(from: bitCount - 1, through: 0, by: -8).map { high in
            Array(stride(from: high, through: max(high - 7, 0), by: -1))
        }
        return VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(row, id: \.self) { position in
                        bitToggle(position)
                        if position % 4 == 0 && position != row.last {
                            Spacer(minLength: 4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func bitToggle(_ position: Int) -> some View {
        let on = position < model.binaryBits.count && model.binaryBits[position]
        return Button {
            model.flipBit(position)
        } label: {
            VStack(spacing: 1) {
                Text(on ? "1" : "0")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(on ? Color.orange : .primary)
                Text("\(position)")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(on ? Color.orange.opacity(0.15) : Color.primary.opacity(0.04))
        )
        .disabled(model.isInError)
        .accessibilityLabel("第 \(position) 位")
        .accessibilityValue(on ? "1" : "0")
    }
}
