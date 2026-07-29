// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Swift port of src/CalcViewModel/StandardCalculatorViewModel.cpp (core logic).
// Programmer-mode specifics arrive in Phase 2.

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
