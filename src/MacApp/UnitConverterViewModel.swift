// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Swift 重写 src/CalcViewModel/UnitConverterViewModel.cpp 的核心行为：
//   - 类别选择、from/to 单位选择、活动输入框切换（SwitchActive）。
//   - 数字/小数点/退格/清除/正负号输入（对应原版 SendCommand 的数字键处理）。
//   - 换算与补充结果（CalculateSuggested）。
// 换算数据与算法在 UnitConverterData 中（静态单位；货币后续单独接入）。

import Foundation

@MainActor
final class UnitConverterViewModel: ObservableObject {
    /// 单个补充结果（其它单位的换算值，对应原版 SupplementaryResult）。
    struct SupplementaryResult: Identifiable {
        let id: Int
        let value: String
        let abbreviation: String
    }

    let categories = UnitConverterData.categories

    @Published private(set) var currentCategory: ConverterCategory
    @Published private(set) var fromUnit: ConverterUnit
    @Published private(set) var toUnit: ConverterUnit

    /// 活动输入框：true=编辑 from（上框），false=编辑 to（下框）。
    @Published private(set) var isFromActive = true

    /// 两个框的显示字符串。非活动框为换算结果。
    @Published private(set) var fromDisplay = "0"
    @Published private(set) var toDisplay = "0"

    @Published private(set) var supplementaryResults: [SupplementaryResult] = []

    /// 活动框正在编辑的原始输入串。
    private var inputBuffer = "0"

    private let maxDigits = 15

    init() {
        let category = UnitConverterData.categories[0]
        currentCategory = category
        fromUnit = category.units[0]
        toUnit = category.units.count > 1 ? category.units[1] : category.units[0]
        recalculate()
    }

    // MARK: - 类别 / 单位选择

    func selectCategory(_ category: ConverterCategory) {
        guard category.id != currentCategory.id else { return }
        currentCategory = category
        fromUnit = category.units[0]
        toUnit = category.units.count > 1 ? category.units[1] : category.units[0]
        isFromActive = true
        inputBuffer = "0"
        recalculate()
    }

    func selectFromUnit(_ unit: ConverterUnit) {
        guard unit.id != fromUnit.id else { return }
        fromUnit = unit
        recalculate()
    }

    func selectToUnit(_ unit: ConverterUnit) {
        guard unit.id != toUnit.id else { return }
        toUnit = unit
        recalculate()
    }

    /// 切换活动输入框（对应原版 SwitchActive）。
    func setActive(fromActive: Bool) {
        guard fromActive != isFromActive else { return }
        isFromActive = fromActive
        // 把当前活动框的显示值作为新的输入缓冲。
        inputBuffer = normalizeForInput(fromActive ? fromDisplay : toDisplay)
        recalculate()
    }

    func swapUnits() {
        let tmp = fromUnit
        fromUnit = toUnit
        toUnit = tmp
        recalculate()
    }

    // MARK: - 输入命令

    func inputDigit(_ digit: Int) {
        guard digit >= 0, digit <= 9 else { return }
        let digitCount = inputBuffer.filter { $0.isNumber }.count
        if digitCount >= maxDigits { return }
        if inputBuffer == "0" {
            inputBuffer = "\(digit)"
        } else if inputBuffer == "-0" {
            inputBuffer = "-\(digit)"
        } else {
            inputBuffer.append(Character("\(digit)"))
        }
        recalculate()
    }

    func inputDecimal() {
        if !inputBuffer.contains(".") {
            inputBuffer.append(".")
        }
        recalculate()
    }

    func inputBackspace() {
        var s = inputBuffer
        if !s.isEmpty {
            s.removeLast()
        }
        if s.isEmpty || s == "-" {
            s = "0"
        }
        inputBuffer = s
        recalculate()
    }

    func clear() {
        inputBuffer = "0"
        recalculate()
    }

    /// 正负号（仅温度等 supportsNegative 类别有效）。
    func toggleSign() {
        guard currentCategory.supportsNegative else { return }
        if inputBuffer.hasPrefix("-") {
            inputBuffer.removeFirst()
        } else if inputBuffer != "0" {
            inputBuffer = "-" + inputBuffer
        }
        recalculate()
    }

    // MARK: - 换算

    private func recalculate() {
        let activeUnit = isFromActive ? fromUnit : toUnit
        let otherUnit = isFromActive ? toUnit : fromUnit
        let inputValue = Double(inputBuffer) ?? 0

        let convertedValue = UnitConverterData.convert(
            inputValue, from: activeUnit, to: otherUnit, category: currentCategory)
        let convertedString = Self.format(convertedValue)

        // 活动框显示原始输入串（保留正在输入的小数点/负号），非活动框显示换算结果。
        if isFromActive {
            fromDisplay = inputBuffer
            toDisplay = convertedString
        } else {
            toDisplay = inputBuffer
            fromDisplay = convertedString
        }

        supplementaryResults = buildSupplementaryResults(inputValue: inputValue, activeUnit: activeUnit)
    }

    private func buildSupplementaryResults(inputValue: Double, activeUnit: ConverterUnit) -> [SupplementaryResult] {
        var results: [SupplementaryResult] = []
        for unit in currentCategory.units where unit.id != fromUnit.id && unit.id != toUnit.id {
            let value = UnitConverterData.convert(inputValue, from: activeUnit, to: unit, category: currentCategory)
            results.append(SupplementaryResult(id: unit.id, value: Self.format(value), abbreviation: unit.abbreviation))
        }
        return results
    }

    /// 把结果显示串标准化为可继续输入的缓冲（去掉分组符等）。
    private func normalizeForInput(_ display: String) -> String {
        let cleaned = display.replacingOccurrences(of: ",", with: "")
        return Double(cleaned) != nil ? cleaned : "0"
    }

    // MARK: - 结果格式化

    /// 有效数字格式化：整数直接显示，否则保留合理有效数字并去除末尾 0。
    static func format(_ value: Double) -> String {
        if value == 0 { return "0" }
        if !value.isFinite { return "溢出" }

        let absValue = abs(value)
        // 极大/极小用科学计数法。
        if absValue >= 1e15 || absValue < 1e-6 {
            var s = String(format: "%.6e", value)
            s = trimExponentZeros(s)
            return s
        }

        var s = String(format: "%.10g", value)
        // %g 可能给出科学计数法，统一去尾零。
        if s.contains("e") || s.contains("E") {
            s = trimExponentZeros(s)
        } else if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s
    }

    private static func trimExponentZeros(_ input: String) -> String {
        let parts = input.lowercased().split(separator: "e", maxSplits: 1)
        guard parts.count == 2 else { return input }
        var mantissa = String(parts[0])
        if mantissa.contains(".") {
            while mantissa.hasSuffix("0") { mantissa.removeLast() }
            if mantissa.hasSuffix(".") { mantissa.removeLast() }
        }
        return mantissa + "e" + String(parts[1])
    }
}
