// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Swift port of src/CalcViewModel/StandardCalculatorViewModel.cpp (core logic).
// Programmer-mode specifics arrive in Phase 2.

import AppKit
import CalcManagerBridge
import Foundation

enum CalculatorMode {
    case standard
    case scientific
    case programmer
    /// 日期计算：不走计算引擎，用 Foundation.Calendar 自成一体。
    case date
    /// 单位换算：不走计算引擎，用 UnitConverterData 静态换算。
    case converter
    /// 绘图：不走 CalcManager，用 GraphExpression(Mock)/Giac 求值与自研渲染。
    case graphing

    /// 是否为引擎驱动的计算模式（日期计算/单位换算/绘图不使用 CalcManager）。
    var usesEngine: Bool { self == .standard || self == .scientific || self == .programmer }

    var precision: Int {
        switch self {
        case .standard: return 16
        case .scientific: return 32
        case .programmer: return 64
        case .date: return 16
        case .converter: return 16
        case .graphing: return 32
        }
    }

    var modeCommand: EngineCommand {
        switch self {
        case .standard: return .modeBasic
        case .scientific: return .modeScientific
        case .programmer: return .modeProgrammer
        case .date: return .modeBasic
        case .converter: return .modeBasic
        case .graphing: return .modeBasic
        }
    }
}

/// 程序员模式的进制（对应原版 NumberBase / RadixType）。
/// rawValue 与 bridge `setRadix:` 约定一致：0=Hex 1=Decimal 2=Octal 3=Binary。
enum RadixKind: Int, CaseIterable, Identifiable {
    case hex = 0
    case dec = 1
    case oct = 2
    case bin = 3

    var id: Int { rawValue }

    /// 传给 `resultForRadix:` 的实际基数。
    var radixValue: Int {
        switch self {
        case .hex: return 16
        case .dec: return 10
        case .oct: return 8
        case .bin: return 2
        }
    }

    var label: String {
        switch self {
        case .hex: return "HEX"
        case .dec: return "DEC"
        case .oct: return "OCT"
        case .bin: return "BIN"
        }
    }
}

/// 程序员模式的字长（对应原版 BitLength）。
enum WordSize: CaseIterable {
    case qword
    case dword
    case word
    case byte

    var label: String {
        switch self {
        case .qword: return "QWORD"
        case .dword: return "DWORD"
        case .word: return "WORD"
        case .byte: return "BYTE"
        }
    }

    /// 该字长对应的引擎命令。
    var command: EngineCommand {
        switch self {
        case .qword: return .qword
        case .dword: return .dword
        case .word: return .word
        case .byte: return .byte
        }
    }

    /// 位翻转面板显示的位数。
    var bitCount: Int {
        switch self {
        case .qword: return 64
        case .dword: return 32
        case .word: return 16
        case .byte: return 8
        }
    }

    /// 单击字长按钮时循环到的下一档（对应原版单按钮循环）。
    var next: WordSize {
        switch self {
        case .qword: return .dword
        case .dword: return .word
        case .word: return .byte
        case .byte: return .qword
        }
    }
}

/// 程序员模式移位类型（对应原版 BitShiftFlyout 的单选组，
/// CalculatorProgrammerRadixOperators.xaml:368-483：选中项决定键盘行两枚移位键的标签与命令）。
enum BitShiftMode: CaseIterable, Identifiable {
    case arithmetic
    case logical
    case rotate
    case rotateCarry

    var id: Self { self }

    var label: String {
        switch self {
        case .arithmetic: return "算术移位"
        case .logical: return "逻辑移位"
        case .rotate: return "循环移位"
        case .rotateCarry: return "带进位循环移位"
        }
    }

    /// 键盘行左移键：(显示文字, 引擎命令)。
    var leftKey: (label: String, command: EngineCommand) {
        switch self {
        case .arithmetic, .logical: return ("«", .lshf)
        case .rotate: return ("RoL", .rol)
        case .rotateCarry: return ("RoLC", .rolc)
        }
    }

    /// 键盘行右移键：(显示文字, 引擎命令)。
    var rightKey: (label: String, command: EngineCommand) {
        switch self {
        case .arithmetic: return ("»", .rshf)
        case .logical: return ("»", .rshfl)
        case .rotate: return ("RoR", .ror)
        case .rotateCarry: return ("RoRC", .rorc)
        }
    }
}

struct ExpressionToken: Identifiable, Equatable {
    let id: Int
    let text: String
    let isEditable: Bool
}

struct HistoryItem: Identifiable, Equatable {
    let id: Int
    let expression: String
    let result: String
}

struct MemorySlot: Identifiable, Equatable {
    let id: Int
    let value: String
}

@MainActor
final class StandardCalculatorViewModel: ObservableObject {
    @Published private(set) var displayValue = "0"
    @Published private(set) var isInError = false
    @Published private(set) var expressionTokens: [ExpressionToken] = []
    @Published private(set) var openParenthesisCount: UInt = 0
    @Published private(set) var isInputEmpty = true
    @Published private(set) var memorizedNumbers: [MemorySlot] = []
    @Published private(set) var isMemoryEmpty = true
    @Published private(set) var historyItems: [HistoryItem] = []
    @Published private(set) var mode: CalculatorMode = .standard
    @Published private(set) var currentAngleType: EngineCommand = .deg
    @Published var isFToEChecked = false
    @Published private(set) var isFToEEnabled = true
    /// 科学模式左侧函数列的 2nd/Shift 态（对应原版 ShiftButton）：切换 x²↔x³ 等。
    @Published private(set) var isInvChecked = false
    // MARK: 程序员模式状态
    /// 当前进制（对应原版 CurrentRadixType）。
    @Published private(set) var currentRadix: RadixKind = .dec
    /// 当前字长（对应原版 ValueBitLength）。
    @Published private(set) var wordSize: WordSize = .qword
    /// 是否处于位翻转（Bit Flip）键盘（对应原版 IsBitFlipChecked）。
    @Published var isBitFlipChecked = false

    /// 当前移位类型（对应原版 BitShiftFlyout 单选，决定键盘行移位键）。
    @Published var shiftMode: BitShiftMode = .arithmetic
    /// 四个进制的转换显示（对应原版 Hex/Dec/Oct/BinaryDisplayValue）。
    @Published private(set) var hexDisplay = "0"
    @Published private(set) var decDisplay = "0"
    @Published private(set) var octDisplay = "0"
    @Published private(set) var binDisplay = "0"
    /// 位翻转面板的 64 位（bit 0 在数组首位），随显示更新。
    @Published private(set) var binaryBits: [Bool] = Array(repeating: false, count: 64)
    /// A–F 十六进制按钮是否可用（仅 HEX 进制下可用，对应原版 AreHEXButtonsEnabled）。
    var areHexButtonsEnabled: Bool { currentRadix == .hex }
    /// 物理键盘命中的按键，用于瞬时闪动高亮；短暂置位后自动清空。
    @Published private(set) var flashedCommand: EngineCommand?

    private let bridge = CalcManagerBridge()

    var decimalSeparator: String {
        bridge.decimalSeparator()
    }

    init() {
        wireCallbacks()
        setCalculatorType(.standard)
    }

    // MARK: - Button dispatch (mirrors OnButtonPressed)

    func buttonPressed(_ command: EngineCommand) {
        if isInError {
            bridge.sendCommand(EngineCommand.clear.rawValue)
            if !isRecoverableCommand(command) {
                return
            }
        }

        switch command {
        case .modeBasic:
            setCalculatorType(.standard)
            return
        case .modeScientific:
            setCalculatorType(.scientific)
            return
        case .modeProgrammer:
            setCalculatorType(.programmer)
            return
        default:
            break
        }

        // On Clear('C')/'CE' the F-E toggle resets, matching the original.
        if command == .clear || command == .clearEntry {
            if isFToEChecked {
                isFToEChecked = false
            }
        }

        if command == .deg || command == .rad || command == .grad {
            currentAngleType = command
        }

        bridge.sendCommand(command.rawValue)
    }

    func digitPressed(_ digit: Int) {
        buttonPressed(EngineCommand.digit(digit))
    }

    func fToEButtonToggled() {
        buttonPressed(.fe)
    }

    func switchAngleType(_ angleType: EngineCommand) {
        buttonPressed(angleType)
    }

    // MARK: - Scientific mode (mirrors ShiftButton / angle cycle)

    /// 切换左侧函数列的 2nd 态（x²↔x³、√↔∛、log↔logₓ 等）。
    func toggleInv() {
        isInvChecked.toggle()
    }

    /// 按下 2nd 态函数键后自动复位 Shift（对应原版 ShiftButton_Uncheck）。
    func pressInvFunction(_ command: EngineCommand) {
        buttonPressed(command)
        if isInvChecked {
            isInvChecked = false
        }
    }

    /// DEG → RAD → GRAD → DEG 三段循环（对应原版单个循环按钮）。
    func cycleAngle() {
        let next: EngineCommand
        switch currentAngleType {
        case .deg: next = .rad
        case .rad: next = .grad
        default: next = .deg
        }
        buttonPressed(next)
    }

    var angleLabel: String {
        switch currentAngleType {
        case .rad: return "RAD"
        case .grad: return "GRAD"
        default: return "DEG"
        }
    }

    // MARK: - Programmer mode (mirrors SwitchProgrammerModeBase / ValueBitLength)

    /// 切换进制（对应原版 SwitchProgrammerModeBase）。会更新 HEX 按钮可用性与四进制显示。
    func switchRadix(_ radix: RadixKind) {
        guard radix != currentRadix else { return }
        if isInError {
            bridge.sendCommand(EngineCommand.clear.rawValue)
        }
        currentRadix = radix
        bridge.setRadix(radix.rawValue)
        updateProgrammerDisplay()
    }

    /// 单击字长按钮循环 QWORD→DWORD→WORD→BYTE→QWORD（对应原版单个循环按钮）。
    func cycleWordSize() {
        setWordSize(wordSize.next)
    }

    /// 设置指定字长（对应原版 ValueBitLength::set）。
    func setWordSize(_ newSize: WordSize) {
        guard newSize != wordSize else { return }
        wordSize = newSize
        buttonPressed(newSize.command)
        updateProgrammerDisplay()
    }

    /// 在整键盘 / 位翻转键盘之间切换（对应原版 IsBitFlipChecked）。
    func toggleBitFlip() {
        isBitFlipChecked.toggle()
    }

    /// 翻转第 `position` 位（对应原版 BinaryDigit 点击）。
    func flipBit(_ position: Int) {
        guard position >= 0, position < wordSize.bitCount else { return }
        buttonPressed(.bitFlip(position))
        updateProgrammerDisplay()
    }

    /// 当前进制下某个 0–9 数字键是否可用（BIN 只允许 0/1，OCT 允许 0–7）。
    func isDigitAllowed(_ value: Int) -> Bool {
        guard mode == .programmer else { return true }
        return value < currentRadix.radixValue
    }

    /// 重新计算四进制显示与位数组（对应原版 UpdateProgrammerPanelDisplay）。
    func updateProgrammerDisplay() {
        guard mode == .programmer else { return }
        let precision = CalculatorMode.programmer.precision
        if isInError {
            hexDisplay = displayValue
            decDisplay = displayValue
            octDisplay = displayValue
            binDisplay = displayValue
            binaryBits = Array(repeating: false, count: 64)
            return
        }

        let hex = bridge.result(forRadix: 16, precision: precision, groupDigits: true)
        if hex.isEmpty {
            hexDisplay = displayValue
            decDisplay = displayValue
            octDisplay = displayValue
            binDisplay = displayValue
        } else {
            hexDisplay = hex
            decDisplay = bridge.result(forRadix: 10, precision: precision, groupDigits: true)
            octDisplay = bridge.result(forRadix: 8, precision: precision, groupDigits: true)
            binDisplay = bridge.result(forRadix: 2, precision: precision, groupDigits: true)
        }

        // 位数组来自未分组的纯二进制串，bit 0 位于字符串末尾。
        let rawBinary = bridge.result(forRadix: 2, precision: precision, groupDigits: false)
        var bits = Array(repeating: false, count: 64)
        for (index, char) in rawBinary.reversed().enumerated() where index < 64 {
            bits[index] = (char == "1")
        }
        binaryBits = bits
    }

    // MARK: - Mode switching (mirrors SetCalculatorType)

    func setCalculatorType(_ newMode: CalculatorMode) {
        isInError = false
        if isFToEChecked {
            isFToEChecked = false
        }
        if isInvChecked {
            isInvChecked = false
        }
        mode = newMode

        switch newMode {
        case .standard:
            bridge.setStandardMode()
            resetRadixAndUpdateMemory(resetRadix: true)
            bridge.setPrecision(newMode.precision)
            bridge.updateMaxIntDigits()
        case .scientific:
            bridge.setScientificMode()
            resetRadixAndUpdateMemory(resetRadix: true)
            bridge.setPrecision(newMode.precision)
        case .programmer:
            bridge.setProgrammerMode()
            resetRadixAndUpdateMemory(resetRadix: false)
            bridge.setPrecision(newMode.precision)
            currentRadix = .dec
            wordSize = .qword
            isBitFlipChecked = false
            bridge.setRadix(RadixKind.dec.rawValue)
            updateProgrammerDisplay()
        case .date:
            // 日期计算不触碰计算引擎，仅切换视图。
            break
        case .converter:
            // 单位换算不触碰计算引擎，仅切换视图。
            break
        case .graphing:
            // 绘图不触碰计算引擎，仅切换视图。
            break
        }

        refreshHistory()
        refreshInputEmpty()
    }

    private func resetRadixAndUpdateMemory(resetRadix: Bool) {
        if resetRadix {
            bridge.setRadix(1) // RadixType::Decimal
        }
    }

    // MARK: - Memory (mirrors OnMemory*)

    func memorizeNumber() {
        bridge.memorizeNumber()
    }

    func memoryItemPressed(_ index: Int) {
        guard !memorizedNumbers.isEmpty else { return }
        bridge.memoryLoad(UInt(index))
    }

    func memoryAdd(_ index: Int) {
        bridge.memoryAdd(UInt(index))
    }

    func memorySubtract(_ index: Int) {
        bridge.memorySubtract(UInt(index))
    }

    func memoryClear(_ index: Int) {
        guard index >= 0, index < memorizedNumbers.count else { return }
        bridge.memoryClear(UInt(index))
        memorizedNumbers.remove(at: index)
        isMemoryEmpty = memorizedNumbers.isEmpty
    }

    func clearMemory() {
        bridge.memoryClearAll()
    }

    // MARK: - History

    func removeHistoryItem(_ index: Int) {
        if bridge.removeHistoryItem(UInt(index)) {
            refreshHistory()
        }
    }

    func clearHistory() {
        bridge.clearHistory()
        refreshHistory()
    }

    private func refreshHistory() {
        historyItems = bridge.historyEntries().enumerated().map { index, entry in
            HistoryItem(id: index, expression: entry.expression, result: entry.result)
        }
    }

    // MARK: - Engine callbacks

    private func wireCallbacks() {
        bridge.onDisplayChanged = { [weak self] text, isError in
            Task { @MainActor in
                guard let self else { return }
                self.displayValue = text
                self.isInError = isError
                self.updateProgrammerDisplay()
            }
        }
        bridge.onIsInErrorChanged = { [weak self] isError in
            Task { @MainActor in
                self?.isInError = isError
            }
        }
        bridge.onExpressionChanged = { [weak self] tokens in
            Task { @MainActor in
                self?.expressionTokens = tokens.enumerated().map { index, token in
                    ExpressionToken(id: index, text: token.text, isEditable: token.commandIndex != -1)
                }
            }
        }
        bridge.onParenthesisCountChanged = { [weak self] count in
            Task { @MainActor in
                self?.openParenthesisCount = count
            }
        }
        bridge.onMemoryChanged = { [weak self] values in
            Task { @MainActor in
                guard let self else { return }
                self.memorizedNumbers = values.enumerated().map { MemorySlot(id: $0.offset, value: $0.element) }
                self.isMemoryEmpty = self.memorizedNumbers.isEmpty
            }
        }
        bridge.onHistoryItemAdded = { [weak self] _ in
            Task { @MainActor in
                self?.refreshHistory()
            }
        }
        bridge.onInputChanged = { [weak self] in
            Task { @MainActor in
                self?.refreshInputEmpty()
            }
        }
    }

    private func refreshInputEmpty() {
        isInputEmpty = bridge.isInputEmpty()
    }

    // MARK: - Physical keyboard (mirrors Windows keyboard accelerators)

    /// 把物理按键映射到引擎命令，命中即闪动对应屏幕键。返回是否已消费该事件。
    func handleKey(chars: String, keyCode: UInt16, hasCommand: Bool) -> Bool {
        // ⌘ 组合交给菜单栏快捷键，这里不拦截。
        if hasCommand { return false }

        // 先处理特殊物理键（keyCode 与字符无关）。
        switch keyCode {
        case 53: dispatchFromKeyboard(.clear); return true       // Escape
        case 51, 117: dispatchFromKeyboard(.backspace); return true // Delete / Forward-Delete
        case 36, 76: dispatchFromKeyboard(.equals); return true  // Return / Enter
        default: break
        }

        guard let ch = chars.first else { return false }
        switch ch {
        case "0"..."9":
            dispatchFromKeyboard(.digit(Int(String(ch))!))
        case "+": dispatchFromKeyboard(.add)
        case "-": dispatchFromKeyboard(.subtract)
        case "*": dispatchFromKeyboard(.multiply)
        case "/": dispatchFromKeyboard(.divide)
        case "=": dispatchFromKeyboard(.equals)
        case "%": dispatchFromKeyboard(.percent)
        case ".", ",": dispatchFromKeyboard(.point)
        default:
            // 小数点分隔符可能是本地化字符（如 ','）。
            if String(ch) == decimalSeparator {
                dispatchFromKeyboard(.point)
            } else {
                return false
            }
        }
        return true
    }

    private func dispatchFromKeyboard(_ command: EngineCommand) {
        buttonPressed(command)
        flash(command)
    }

    private func flash(_ command: EngineCommand) {
        flashedCommand = command
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            if self.flashedCommand == command {
                self.flashedCommand = nil
            }
        }
    }

    // MARK: - Copy / paste

    func copyDisplay() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(displayValue, forType: .string)
    }

    /// 基础粘贴：把剪贴板里的合法数字逐字符送入引擎。
    /// 完整的 CopyPasteManager 解析规则（表达式/进制/科学计数）在后续单独条目补全。
    func pasteFromPasteboard() {
        guard let raw = NSPasteboard.general.string(forType: .string) else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        buttonPressed(.clear)
        var isFirst = true
        for ch in trimmed {
            switch ch {
            case "0"..."9":
                digitPressed(Int(String(ch))!)
            case ".":
                buttonPressed(.point)
            case "-" where isFirst:
                buttonPressed(.sign)
            default:
                break // 忽略无法识别的字符
            }
            isFirst = false
        }
    }

    // MARK: - Command classification (mirrors Is*Op helpers)

    private func isOperand(_ command: EngineCommand) -> Bool {
        (EngineCommand.digit0.rawValue...EngineCommand.digit9.rawValue).contains(command.rawValue) || command == .point
    }

    private func isRecoverableCommand(_ command: EngineCommand) -> Bool {
        if isOperand(command) {
            return true
        }
        switch command {
        case .digitA, .digitB, .digitC, .digitD, .digitE, .digitF:
            return true
        default:
            return command.rawValue >= 700 && command.rawValue <= 763 // bit-flip range
        }
    }
}
