// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Swift 重写 src/CalcViewModel/UnitConverterViewModel.cpp 的核心行为：
//   - 类别选择、from/to 单位选择、活动输入框切换（SwitchActive）。
//   - 数字/小数点/退格/清除/正负号输入（对应原版 SendCommand 的数字键处理）。
//   - 换算与补充结果（CalculateSuggested）。
// 换算数据与算法在 UnitConverterData 中（静态单位表 + 动态货币汇率；货币经 CurrencyService 加载）。

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class UnitConverterViewModel {
    /// 单个补充结果（其它单位的换算值，对应原版 SupplementaryResult）。
    struct SupplementaryResult: Identifiable {
        let id: Int
        let value: String
        let abbreviation: String
    }

    /// 货币类别 id / 货币单位 id 偏移（避开静态单位 id，静态最大 168）。
    static let currencyCategoryID = 100
    static let currencyUnitIDBase = 10000

    /// 动态货币类别（汇率加载成功后填充）。
private(set) var currencyCategory: ConverterCategory?
    /// 货币数据状态提示（加载中 / 日期 / 失败）。
private(set) var currencyStatus = L10n.string("Mac_Currency_Loading")

    /// 全部类别 = 静态单位 + （已加载的）货币。
    var categories: [ConverterCategory] {
        UnitConverterData.categories + (currencyCategory.map { [$0] } ?? [])
    }

private(set) var currentCategory: ConverterCategory
private(set) var fromUnit: ConverterUnit
private(set) var toUnit: ConverterUnit

    /// 活动输入框：true=编辑 from（上框），false=编辑 to（下框）。
private(set) var isFromActive = true

    /// 两个框的显示字符串。非活动框为换算结果。
private(set) var fromDisplay = "0"
private(set) var toDisplay = "0"

private(set) var supplementaryResults: [SupplementaryResult] = []

    /// 活动框正在编辑的原始输入串。
    private var inputBuffer = "0"

    private let maxDigits = 15

    init() {
        let category = UnitConverterData.categories[0]
        currentCategory = category
        let selectable = category.selectableUnits
        fromUnit = selectable[0]
        toUnit = selectable.count > 1 ? selectable[1] : selectable[0]
        recalculate()
        Task { await loadCurrencies() }
    }

    // MARK: - 货币（动态汇率）

    /// 常用货币优先排序，其余按代码字母序。
    private static let majorCurrencyOrder = ["USD", "EUR", "GBP", "JPY", "CNY", "HKD", "CAD", "AUD", "CHF", "KRW"]

    func loadCurrencies() async {
        guard let rates = await CurrencyService.loadRates() else {
            currencyStatus = L10n.string("Mac_Currency_LoadFailed")
            return
        }
        applyRates(rates)
    }

    /// 手动刷新汇率。
    func refreshCurrencies() async {
        currencyStatus = L10n.string("Mac_Currency_Refreshing")
        if let rates = await CurrencyService.refreshFromNetwork() {
            applyRates(rates)
            // 对应原版 UpdateCurrencyRates 播报。
            AccessibilityAnnouncer.announce(L10n.string("CurrencyRatesUpdated"), highPriority: false)
        } else {
            currencyStatus = L10n.string("Mac_Currency_RefreshFailedKept")
            AccessibilityAnnouncer.announce(L10n.string("CurrencyRatesUpdateFailed"), highPriority: false)
        }
    }

    private func applyRates(_ rates: CurrencyRates) {
        let category = Self.buildCurrencyCategory(from: rates)
        currencyCategory = category
        currencyStatus = L10n.format("Mac_Currency_UpdatedAt", rates.date)
        // 若当前正处于货币类别，刷新其单位引用（保持代码不变的前提下更新 factor）。
        if currentCategory.id == Self.currencyCategoryID {
            let from = category.units.first { $0.abbreviation == fromUnit.abbreviation } ?? category.units[0]
            let to = category.units.first { $0.abbreviation == toUnit.abbreviation }
                ?? (category.units.count > 1 ? category.units[1] : category.units[0])
            currentCategory = category
            fromUnit = from
            toUnit = to
            recalculate()
        }
    }

    private static func buildCurrencyCategory(from rates: CurrencyRates) -> ConverterCategory {
        let known = Set(Locale.commonISOCurrencyCodes)
        let locale = Locale.current
        // 仅保留有元数据的 ISO 货币，避免混入加密货币等。
        let codes = rates.rates.keys.filter { known.contains($0) && (rates.rates[$0] ?? 0) > 0 }

        let sorted = codes.sorted { a, b in
            let ia = majorCurrencyOrder.firstIndex(of: a)
            let ib = majorCurrencyOrder.firstIndex(of: b)
            switch (ia, ib) {
            case let (.some(x), .some(y)): return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            default: return a < b
            }
        }

        var units: [ConverterUnit] = []
        for (index, code) in sorted.enumerated() {
            guard let rate = rates.rates[code], rate > 0 else { continue }
            let name = locale.localizedString(forCurrencyCode: code) ?? code
            // factor = 1/rate（相对 USD 的价值），复用普通类别的 value*(fromFactor/toFactor)。
            units.append(ConverterUnit(
                id: currencyUnitIDBase + index,
                name: name,
                abbreviation: code,
                factor: 1.0 / rate))
        }

        return ConverterCategory(
            id: currencyCategoryID, name: L10n.string("CategoryName_CurrencyText"),
            supportsNegative: false, isTemperature: false, units: units)
    }

    // MARK: - 类别 / 单位选择

    func selectCategory(_ category: ConverterCategory) {
        guard category.id != currentCategory.id else { return }
        currentCategory = category
        let selectable = category.selectableUnits
        fromUnit = selectable[0]
        toUnit = selectable.count > 1 ? selectable[1] : selectable[0]
        isFromActive = true
        inputBuffer = "0"
        recalculate()
        // 对应原版 CategoryNameChanged 播报。
        AccessibilityAnnouncer.announce(category.name, highPriority: false)
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

    // MARK: - 复制 / 粘贴（对应原版 OnCopyCommand / OnPaste）

    /// 拷贝活动框的值。
    func copyToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(isFromActive ? fromDisplay : toDisplay, forType: .string)
    }

    /// 粘贴：CopyPasteManager 校验（换算器只收纯数字），非法整体拒绝。
    func pasteFromPasteboard() {
        guard let raw = NSPasteboard.general.string(forType: .string) else { return }
        guard let validated = CopyPasteManager.validate(raw, mode: .converter) else { return }
        onPaste(validated)
    }

    /// 对应原版 UnitConverterViewModel::OnPaste：首个合法字符前先清空，
    /// 前导负号延迟到有数字后再应用。
    func onPaste(_ text: String) {
        var isFirstLegalChar = true
        var pendingNegate = false

        for ch in text {
            let digit: Int? = ("0"..."9").contains(ch) ? ch.wholeNumberValue : nil
            let isDecimal = (ch == ".")
            let isNegate = (ch == "-")
            guard digit != nil || isDecimal || isNegate else { continue }

            if isFirstLegalChar {
                clear()
                isFirstLegalChar = false
                if isNegate {
                    pendingNegate = true
                    continue
                }
            }

            if let digit {
                inputDigit(digit)
            } else if isDecimal {
                inputDecimal()
            }
        }

        if pendingNegate {
            toggleSign()
        }
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
            fromDisplay = Self.localizedDisplay(inputBuffer)
            toDisplay = Self.localizedDisplay(convertedString)
        } else {
            toDisplay = Self.localizedDisplay(inputBuffer)
            fromDisplay = Self.localizedDisplay(convertedString)
        }

        supplementaryResults = buildSupplementaryResults(inputValue: inputValue, activeUnit: activeUnit)
    }

    // 对应 UnitConverter::CalculateSuggested：普通与趣味单位分开，
    // 各按 |log10(值)| 升序排序（同量级取正），四舍五入后剔除 0 值，
    // 普通结果在前，末尾只追加第一个趣味结果。
    private func buildSupplementaryResults(inputValue: Double, activeUnit: ConverterUnit) -> [SupplementaryResult] {
        var normal: [(magnitude: Double, value: Double, unit: ConverterUnit)] = []
        var whimsical: [(magnitude: Double, value: Double, unit: ConverterUnit)] = []
        for unit in currentCategory.units where unit.id != fromUnit.id && unit.id != toUnit.id {
            let value = UnitConverterData.convert(inputValue, from: activeUnit, to: unit, category: currentCategory)
            let entry = (magnitude: log10(value), value: value, unit: unit)
            if unit.isWhimsical { whimsical.append(entry) } else { normal.append(entry) }
        }

        let byMagnitude: ((Double, Double, ConverterUnit), (Double, Double, ConverterUnit)) -> Bool = {
            abs($0.0) == abs($1.0) ? $0.0 > $1.0 : abs($0.0) < abs($1.0)
        }
        normal.sort(by: byMagnitude)
        whimsical.sort(by: byMagnitude)

        var results: [SupplementaryResult] = []
        for entry in normal {
            let rounded = Self.roundSuggested(entry.value)
            if Double(rounded) != 0 || currentCategory.supportsNegative {
                results.append(SupplementaryResult(id: entry.unit.id, value: Self.localizedDisplay(rounded), abbreviation: entry.unit.abbreviation))
            }
        }
        for entry in whimsical {
            let rounded = Self.roundSuggested(entry.value)
            if Double(rounded) != 0 {
                results.append(SupplementaryResult(id: entry.unit.id, value: Self.localizedDisplay(rounded), abbreviation: entry.unit.abbreviation))
                break
            }
        }
        return results
    }

    /// 对应 RoundSignificantDigits + TrimTrailingZeros：<100 两位小数、<1000 一位、其余取整。
    private static func roundSuggested(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        var s: String
        if abs(value) < 100 {
            s = String(format: "%.2f", value)
        } else if abs(value) < 1000 {
            s = String(format: "%.1f", value)
        } else {
            s = String(format: "%.0f", value)
        }
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s
    }

    /// 把结果显示串标准化为可继续输入的缓冲（去掉分组符、本地化小数点还原为 "."）。
    private func normalizeForInput(_ display: String) -> String {
        var cleaned = display.replacingOccurrences(of: Self.localeGrouping, with: "")
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        if Self.localeDecimal != "." {
            cleaned = cleaned.replacingOccurrences(of: Self.localeDecimal, with: ".")
        }
        return Double(cleaned) != nil ? cleaned : "0"
    }

    // MARK: - 结果格式化

    /// 当前 Locale 的小数点与千分位分隔符（对应原版 LocalizationSettings）。
    static var localeDecimal: String { Locale.current.decimalSeparator ?? "." }
    static var localeGrouping: String { Locale.current.groupingSeparator ?? "," }

    /// 把内部 "."-制数值串按当前 Locale 呈现：整数部分插入千分位，小数点本地化。
    /// 科学计数法/非数字（如“溢出”）只做小数点替换，不分组。
    static func localizedDisplay(_ internalValue: String) -> String {
        if internalValue.contains("e") || internalValue.contains("E")
            || Double(internalValue) == nil {
            return localeDecimal == "." ? internalValue
                : internalValue.replacingOccurrences(of: ".", with: localeDecimal)
        }
        var s = internalValue
        var sign = ""
        if s.hasPrefix("-") { sign = "-"; s.removeFirst() }
        let hasTrailingDot = s.hasSuffix(".")
        let parts = s.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let intPart = parts.first.map(String.init) ?? ""
        let fracPart = parts.count > 1 ? String(parts[1]) : ""
        var result = sign + insertGrouping(intPart)
        if !fracPart.isEmpty {
            result += localeDecimal + fracPart
        } else if hasTrailingDot {
            result += localeDecimal
        }
        return result
    }

    /// 从右向左每 3 位插入千分位分隔符（对应原版数字分组）。
    private static func insertGrouping(_ digits: String) -> String {
        guard digits.count > 3 else { return digits }
        var result = ""
        var count = 0
        for ch in digits.reversed() {
            if count != 0 && count % 3 == 0 { result = localeGrouping + result }
            result = String(ch) + result
            count += 1
        }
        return result
    }

    /// 有效数字格式化：整数直接显示，否则保留合理有效数字并去除末尾 0。
    static func format(_ value: Double) -> String {
        if value == 0 { return "0" }
        if !value.isFinite { return L10n.string("Mac_Overflow") }

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
