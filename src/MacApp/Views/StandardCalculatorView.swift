// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 1:1 SwiftUI translation of Views/CalculatorStandardOperators.xaml +
// the display/memory chrome from Views/Calculator.xaml.

import SwiftUI

struct StandardCalculatorView: View {
    @ObservedObject var model: StandardCalculatorViewModel

    var body: some View {
        VStack(spacing: 4) {
            DisplayArea(model: model)
            MemoryBar(model: model)
            keypad
        }
        .padding(8)
    }

    // Grid mirrors the XAML: rows 0-5, columns %/CE/C/⌫ … ±/0/./=
    private var keypad: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                CalcKey("%", style: .function, disabled: model.isInError) { model.buttonPressed(.percent) }
                CalcKey("CE", style: .function) { model.buttonPressed(.clearEntry) }
                CalcKey("C", style: .function) { model.buttonPressed(.clear) }
                CalcKey("⌫", style: .function) { model.buttonPressed(.backspace) }
            }
            GridRow {
                CalcKey("¹⁄ₓ", style: .function, disabled: model.isInError) { model.buttonPressed(.reciprocal) }
                CalcKey("x²", style: .function, disabled: model.isInError) { model.buttonPressed(.sqr) }
                CalcKey("²√x", style: .function, disabled: model.isInError) { model.buttonPressed(.sqrt) }
                CalcKey("÷", style: .function, disabled: model.isInError) { model.buttonPressed(.divide) }
            }
            GridRow {
                CalcKey("7", style: .digit) { model.digitPressed(7) }
                CalcKey("8", style: .digit) { model.digitPressed(8) }
                CalcKey("9", style: .digit) { model.digitPressed(9) }
                CalcKey("×", style: .function, disabled: model.isInError) { model.buttonPressed(.multiply) }
            }
            GridRow {
                CalcKey("4", style: .digit) { model.digitPressed(4) }
                CalcKey("5", style: .digit) { model.digitPressed(5) }
                CalcKey("6", style: .digit) { model.digitPressed(6) }
                CalcKey("−", style: .function, disabled: model.isInError) { model.buttonPressed(.subtract) }
            }
            GridRow {
                CalcKey("1", style: .digit) { model.digitPressed(1) }
                CalcKey("2", style: .digit) { model.digitPressed(2) }
                CalcKey("3", style: .digit) { model.digitPressed(3) }
                CalcKey("+", style: .function, disabled: model.isInError) { model.buttonPressed(.add) }
            }
            GridRow {
                CalcKey("±", style: .digit, disabled: model.isInError) { model.buttonPressed(.sign) }
                CalcKey("0", style: .digit) { model.digitPressed(0) }
                CalcKey(model.decimalSeparator, style: .digit) { model.buttonPressed(.point) }
                CalcKey("=", style: .accent) { model.buttonPressed(.equals) }
            }
        }
    }
}

struct DisplayArea: View {
    @ObservedObject var model: StandardCalculatorViewModel

    var body: some View {
        VStack(spacing: 0) {
            Text(model.expressionTokens.map(\.text).joined())
                .font(.system(size: 14))
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(.secondary)
                .frame(height: 20)
                .accessibilityIdentifier("expressionDisplay")

            Text(model.displayValue)
                .font(.system(size: 46, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("primaryDisplay")
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }
}

/// Memory bar under the display: MC MR M+ M− MS (Views/Calculator.xaml MemoryPanel).
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
        .frame(height: 28)
    }

    private func memoryKey(_ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
    }
}

enum CalcKeyStyle {
    case digit
    case function
    case accent
}

struct CalcKey: View {
    let label: String
    let style: CalcKeyStyle
    let disabled: Bool
    let action: () -> Void

    init(_ label: String, style: CalcKeyStyle, disabled: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.style = style
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: style == .digit ? 20 : 16, weight: style == .digit ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: .infinity)
        }
        .buttonStyle(CalcKeyButtonStyle(style: style))
        .disabled(disabled)
    }
}

private struct CalcKeyButtonStyle: ButtonStyle {
    let style: CalcKeyStyle
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background(configuration))
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(RoundedRectangle(cornerRadius: 4))
    }

    private var foreground: Color {
        if !isEnabled {
            return Color.primary.opacity(0.3)
        }
        return style == .accent ? Color.white : Color.primary
    }

    private func background(_ configuration: Configuration) -> some ShapeStyle {
        let pressed = configuration.isPressed
        switch style {
        case .digit:
            return AnyShapeStyle(Color.primary.opacity(pressed ? 0.16 : 0.08))
        case .function:
            return AnyShapeStyle(Color.primary.opacity(pressed ? 0.12 : 0.04))
        case .accent:
            return AnyShapeStyle(Color.accentColor.opacity(isEnabled ? (pressed ? 0.75 : 1.0) : 0.4))
        }
    }
}
