// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 排版对照 Views/UnitConverter.xaml 的行结构：
//   顶栏（模式菜单，与其它模式共用 CalculatorHeader）
//   类别选择（对应原版顶部导航中的换算类别）
//   数值1（活动可点）+ 单位1 下拉
//   ⇅ 交换
//   数值2（活动可点）+ 单位2 下拉
//   补充结果（其它单位换算值，对应 SupplementaryResults）
//   数字键盘（0-9 . ⌫ C ±）
// 视觉沿用 macOS 原生 Liquid Glass；数值/结果为内容层（不加玻璃）。

import AppKit
import SwiftUI

struct UnitConverterView: View {
    @ObservedObject var model: StandardCalculatorViewModel
    @StateObject private var converter = UnitConverterViewModel()

    var showsHistoryButton: Bool = false
    @State private var historyPopoverShown = false

    var body: some View {
        VStack(spacing: 0) {
            CalculatorHeader(model: model, showsHistoryButton: showsHistoryButton, historyPopoverShown: $historyPopoverShown)

            categoryPicker
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            if converter.currentCategory.id == UnitConverterViewModel.currencyCategoryID {
                currencyStatusBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }

            valueRow(
                display: converter.fromDisplay,
                unit: converter.fromUnit,
                isActive: converter.isFromActive,
                units: converter.currentCategory.units,
                onSelectUnit: converter.selectFromUnit,
                onActivate: { converter.setActive(fromActive: true) })

            swapButton

            valueRow(
                display: converter.toDisplay,
                unit: converter.toUnit,
                isActive: !converter.isFromActive,
                units: converter.currentCategory.units,
                onSelectUnit: converter.selectToUnit,
                onActivate: { converter.setActive(fromActive: false) })

            supplementaryRow

            Spacer(minLength: 4)

            keypad
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .converterKeyMonitor(converter: converter, supportsNegative: converter.currentCategory.supportsNegative)
    }

    // MARK: - 类别选择

    private var categoryPicker: some View {
        Picker("类别", selection: Binding(
            get: { converter.currentCategory.id },
            set: { newID in
                if let category = converter.categories.first(where: { $0.id == newID }) {
                    converter.selectCategory(category)
                }
            })) {
            ForEach(converter.categories) { category in
                Text(category.name).tag(category.id)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private var currencyStatusBar: some View {
        HStack(spacing: 8) {
            Text(converter.currencyStatus)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button {
                Task { await converter.refreshCurrencies() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("刷新汇率")
            .accessibilityLabel("刷新汇率")
        }
    }

    private func valueRow(
        display: String,
        unit: ConverterUnit,
        isActive: Bool,
        units: [ConverterUnit],
        onSelectUnit: @escaping (ConverterUnit) -> Void,
        onActivate: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(display)
                .font(.system(size: 36, weight: .light))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.7))
                .textSelection(.enabled)
                .contentShape(Rectangle())
                .onTapGesture(perform: onActivate)
                .accessibilityLabel("数值")
                .accessibilityValue(display)

            Picker("单位", selection: Binding(
                get: { unit.id },
                set: { newID in
                    if let u = units.first(where: { $0.id == newID }) { onSelectUnit(u) }
                })) {
                ForEach(units) { u in
                    Text("\(u.name)（\(u.abbreviation)）").tag(u.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? Color.orange.opacity(0.12) : Color.clear)
        )
        .padding(.horizontal, 8)
    }

    private var swapButton: some View {
        Button(action: converter.swapUnits) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 13, weight: .semibold))
        }
        .buttonStyle(.glass)
        .controlSize(.small)
        .help("交换单位")
        .accessibilityLabel("交换单位")
        .padding(.vertical, 2)
    }

    // MARK: - 补充结果

    private var supplementaryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(converter.supplementaryResults) { result in
                    VStack(spacing: 1) {
                        Text(result.value)
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .lineLimit(1)
                        Text(result.abbreviation)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
    }

    // MARK: - 数字键盘

    private var keypad: some View {
        GlassEffectContainer(spacing: 6) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    digitKey(7)
                    digitKey(8)
                    digitKey(9)
                    CalcKey(symbol: "delete.left", style: .function, a11yLabel: "退格") { converter.inputBackspace() }
                }
                GridRow {
                    digitKey(4)
                    digitKey(5)
                    digitKey(6)
                    CalcKey("C", style: .function, fontSize: 14, a11yLabel: "清除") { converter.clear() }
                }
                GridRow {
                    digitKey(1)
                    digitKey(2)
                    digitKey(3)
                    CalcKey(symbol: "plus.forwardslash.minus", style: .function,
                            disabled: !converter.currentCategory.supportsNegative, a11yLabel: "正负号") { converter.toggleSign() }
                }
                GridRow {
                    digitKey(0)
                        .gridCellColumns(2)
                    CalcKey(model.decimalSeparator, style: .digit, fontSize: 18, a11yLabel: "小数点") { converter.inputDecimal() }
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                }
            }
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        CalcKey("\(digit)", style: .digit, fontSize: 18, a11yLabel: "\(digit)") {
            converter.inputDigit(digit)
        }
    }
}

/// 单位换算模式的物理键盘监听：数字/小数点/退格/清除/正负号直接路由到换算 ViewModel。
private struct ConverterKeyMonitor: ViewModifier {
    @ObservedObject var converter: UnitConverterViewModel
    var supportsNegative: Bool
    @State private var keyMonitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear { install() }
            .onDisappear { remove() }
    }

    private func install() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard !event.modifierFlags.contains(.command) else { return event }
            let chars = event.charactersIgnoringModifiers ?? ""
            switch event.keyCode {
            case 51, 117: // Delete / Forward-Delete
                converter.inputBackspace()
                return nil
            case 53: // Esc → 清除
                converter.clear()
                return nil
            default:
                break
            }
            if let ch = chars.first {
                if ch.isNumber, let d = ch.wholeNumberValue, d >= 0, d <= 9 {
                    converter.inputDigit(d)
                    return nil
                }
                if ch == "." || ch == "," {
                    converter.inputDecimal()
                    return nil
                }
                if ch == "-" && supportsNegative {
                    converter.toggleSign()
                    return nil
                }
            }
            return event
        }
    }

    private func remove() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}

private extension View {
    func converterKeyMonitor(converter: UnitConverterViewModel, supportsNegative: Bool) -> some View {
        modifier(ConverterKeyMonitor(converter: converter, supportsNegative: supportsNegative))
    }
}
