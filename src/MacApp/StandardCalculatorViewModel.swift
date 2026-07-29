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

    var precision: Int {
        switch self {
        case .standard: return 16
        case .scientific: return 32
        case .programmer: return 64
        }
    }

    var modeCommand: EngineCommand {
        switch self {
        case .standard: return .modeBasic
        case .scientific: return .modeScientific
        case .programmer: return .modeProgrammer
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

    // MARK: - Mode switching (mirrors SetCalculatorType)

    func setCalculatorType(_ newMode: CalculatorMode) {
        isInError = false
        if isFToEChecked {
            isFToEChecked = false
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
