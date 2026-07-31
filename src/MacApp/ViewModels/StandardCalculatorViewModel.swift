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

    /// 模式元数据统一查 ModeDescriptor 表（S6 规格表下沉，唯一事实源）。
    var descriptor: ModeDescriptor { ModeDescriptor.descriptor(for: self) }

    /// 是否为引擎驱动的计算模式（日期计算/单位换算/绘图不使用 CalcManager）。
    var usesEngine: Bool { descriptor.usesEngine }

    /// VoiceOver 播报用的模式名称。
    var announcementLabel: String { L10n.string(descriptor.l10nKey) }

    var precision: Int { descriptor.precision }

    var modeCommand: EngineCommand { descriptor.modeCommand }

    /// 跨启动持久化的稳定标识（对应原版 ApplicationDataContainer 记忆当前模式）。
    var persistenceKey: String { descriptor.persistenceKey }

    init?(persistenceKey: String) {
        guard let descriptor = ModeDescriptor.descriptor(persistenceKey: persistenceKey) else { return nil }
        self = descriptor.mode
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
        case .arithmetic: return L10n.string("arithmeticShiftButton.Content")
        case .logical: return L10n.string("logicalShiftButton.Content")
        case .rotate: return L10n.string("rotateCircularButton.Content")
        case .rotateCarry: return L10n.string("rotateCarryShiftButton.Content")
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
    /// S10 精度闸门（M4）：结果谱系中发生过有理数强制截断 → 显示为近似值提示。
    @Published private(set) var isPrecisionLimited = false
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
    @Published var shiftMode: BitShiftMode = .arithmetic {
        didSet {
            // 对应原版 BitShiftRadioButtonContent 播报。
            if oldValue != shiftMode {
                AccessibilityAnnouncer.announce(shiftMode.label, highPriority: false)
            }
        }
    }
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
    /// 下一次显示回调需向 VoiceOver 播报(对应原版 DisplayUpdated)。
    private var announceNextDisplayChange = false

    var decimalSeparator: String {
        bridge.decimalSeparator()
    }

    init() {
        wireCallbacks()
        // 恢复上次退出时的模式（对应原版记忆当前模式）；无记录则默认标准。
        let savedMode = UserDefaults.standard.string(forKey: Self.lastModeKey)
            .flatMap(CalculatorMode.init(persistenceKey:)) ?? .standard
        setCalculatorType(savedMode)
    }

    /// 记忆当前模式的 UserDefaults 键。
    private static let lastModeKey = "LastCalculatorMode"

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
            // S10 精度闸门：新算式开始，清掉引擎的粘滞截断标志。
            bridge.clearPrecisionLimited()
            isPrecisionLimited = false
        }

        if command == .deg || command == .rad || command == .grad {
            currentAngleType = command
            AccessibilityAnnouncer.announce(angleAnnouncementLabel(command))
        }

        // 对应原版 DisplayUpdated 播报(等号/清除/退格后)。
        if command == .equals || command == .clear || command == .clearEntry || command == .backspace {
            announceNextDisplayChange = true
        }

        bridge.sendCommand(command.rawValue)
        refreshPrecisionLimited()
    }

    /// S10（M4）：读取引擎粘滞标志——有理数超限被截断后 UI 必须如实标注近似。
    private func refreshPrecisionLimited() {
        let limited = bridge.precisionLimited()
        if limited != isPrecisionLimited {
            isPrecisionLimited = limited
            if limited {
                AccessibilityAnnouncer.announce(L10n.string("Mac_PrecisionLimited"))
            }
        }
    }

    private func angleAnnouncementLabel(_ command: EngineCommand) -> String {
        switch command {
        case .rad: return L10n.string("TrigModeRadians.Content")
        case .grad: return L10n.string("TrigModeGradians.Content")
        default: return L10n.string("TrigModeDegrees.Content")
        }
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
        AccessibilityAnnouncer.announce(isInvChecked ? L10n.string("Mac_Ann_2ndOn") : L10n.string("Mac_Ann_2ndOff"), highPriority: false)
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
        AccessibilityAnnouncer.announce(radixAnnouncementLabel(radix))
    }

    private func radixAnnouncementLabel(_ radix: RadixKind) -> String {
        switch radix {
        case .hex: return L10n.string("Mac_Radix_Hex")
        case .dec: return L10n.string("Mac_Radix_Dec")
        case .oct: return L10n.string("Mac_Radix_Oct")
        case .bin: return L10n.string("Mac_Radix_Bin")
        }
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
        AccessibilityAnnouncer.announce(newSize.label)
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
        // 记忆当前模式，供下次启动恢复（原版 ApplicationDataContainer 语义）。
        UserDefaults.standard.set(newMode.persistenceKey, forKey: Self.lastModeKey)

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
        // 对应原版模式切换播报(含 GraphModeChanged)。
        AccessibilityAnnouncer.announce(L10n.format("Mac_Ann_SwitchedTo", newMode.announcementLabel), highPriority: false)
    }

    private func resetRadixAndUpdateMemory(resetRadix: Bool) {
        if resetRadix {
            bridge.setRadix(1) // RadixType::Decimal
        }
    }

    // MARK: - Memory (mirrors OnMemory*)

    func memorizeNumber() {
        bridge.memorizeNumber()
        AccessibilityAnnouncer.announce(L10n.string("Mac_Ann_MemStored"), highPriority: false)
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
        AccessibilityAnnouncer.announce(L10n.string("Mac_Ann_MemCleared"))
    }

    // MARK: - History

    func removeHistoryItem(_ index: Int) {
        if bridge.removeHistoryItem(UInt(index)) {
            refreshHistory()
            AccessibilityAnnouncer.announce(L10n.string("Mac_Ann_HistItemDeleted"))
        }
    }

    func clearHistory() {
        bridge.clearHistory()
        refreshHistory()
        AccessibilityAnnouncer.announce(L10n.string("Mac_Ann_HistCleared"), highPriority: false)
    }

    /// 历史面板开关（⌃H / 菜单栏）；程序员模式无历史。
    func toggleHistoryPanel() {
        guard mode != .programmer else { return }
        historyTogglePulse += 1
    }

    private func refreshHistory() {
        historyItems = bridge.historyEntries().enumerated().map { index, entry in
            HistoryItem(id: index, expression: entry.expression, result: entry.result)
        }
    }

    // MARK: - 表达式 token 编辑(对应原版 UpdateOperand + Recalculate)

    func isOperandTokenEditable(_ tokenIndex: Int) -> Bool {
        tokenIndex >= 0 && bridge.isOperandToken(at: UInt(tokenIndex))
    }

    /// 编辑表达式中的操作数并整体重放引擎命令;失败时引擎恢复原表达式。
    @discardableResult
    func updateOperand(tokenIndex: Int, newText: String) -> Bool {
        guard mode != .programmer, tokenIndex >= 0 else { return false }
        let englishText = newText
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: decimalSeparator, with: ".")
        return bridge.updateOperand(
            atToken: UInt(tokenIndex),
            text: englishText,
            scientific: mode == .scientific,
            fToEChecked: isFToEChecked)
    }

    // MARK: - Engine callbacks

    private func wireCallbacks() {
        bridge.onDisplayChanged = { [weak self] text, isError in
            Task { @MainActor in
                guard let self else { return }
                self.displayValue = text
                self.isInError = isError
                self.updateProgrammerDisplay()
                // 对应原版 DisplayUpdated 播报;错误文本始终播报。
                if isError {
                    self.announceNextDisplayChange = false
                    AccessibilityAnnouncer.announce(text)
                } else if self.announceNextDisplayChange {
                    self.announceNextDisplayChange = false
                    AccessibilityAnnouncer.announce(text)
                }
            }
        }
        bridge.onIsInErrorChanged = { [weak self] isError in
            Task { @MainActor in
                self?.isInError = isError
            }
        }
        // 对应原版 OnBinaryOperatorReceived → DisplayUpdated 播报。
        bridge.onBinaryOperatorReceived = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                AccessibilityAnnouncer.announce(self.displayValue)
            }
        }
        // 对应原版 MaxDigitsReached 播报。
        bridge.onMaxDigitsReached = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                AccessibilityAnnouncer.announce(L10n.format("Mac_Ann_MaxDigits", self.displayValue))
            }
        }
        // 对应原版 NoParenthesisAdded 播报。
        bridge.onNoRightParenAdded = {
            Task { @MainActor in
                AccessibilityAnnouncer.announce(L10n.string("Mac_Ann_NoParen"))
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
                guard let self else { return }
                // 对应原版 OpenParenthesisCountChanged 播报(仅计数变化时)。
                if count != self.openParenthesisCount {
                    AccessibilityAnnouncer.announce(L10n.format("Mac_Ann_OpenParenCount", "\(count)"), highPriority: false)
                }
                self.openParenthesisCount = count
            }
        }
        bridge.onMemoryChanged = { [weak self] values in
            Task { @MainActor in
                guard let self else { return }
                self.memorizedNumbers = values.enumerated().map { MemorySlot(id: $0.offset, value: $0.element) }
                self.isMemoryEmpty = self.memorizedNumbers.isEmpty
            }
        }
        // 对应原版 MemoryItemChanged 播报(M+/M− 后)。
        bridge.onMemoryItemChanged = { [weak self] index in
            Task { @MainActor in
                guard let self, Int(index) < self.memorizedNumbers.count else { return }
                AccessibilityAnnouncer.announce(L10n.format("Mac_Ann_MemoryUpdated", self.memorizedNumbers[Int(index)].value), highPriority: false)
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

    /// 物理键盘修饰键（⌘ 放行菜单栏；⌃/⇧ 参与原版 Ctrl/Shift 和弦）。
    struct KeyModifiers {
        var command = false
        var shift = false
        var control = false
    }

    /// Ctrl+H 历史面板开关脉冲（视图 onChange 监听后翻转 popover）。
    @Published private(set) var historyTogglePulse = 0

    /// 完整键盘映射，对照原版 Resources.resw 的 KeyboardShortcutManager 词条（129 条）。
    /// Character/VirtualKey/Shift/Ctrl(=macOS ⌃)/Ctrl+Shift 五类和弦；按当前模式分发。
    /// 返回是否已消费该事件。
    func handleKey(chars: String, keyCode: UInt16, modifiers: KeyModifiers) -> Bool {
        // ⌘ 组合交给菜单栏快捷键，这里不拦截。
        if modifiers.command { return false }

        let upper = chars.uppercased().first

        if modifiers.control {
            return handleControlChord(upper, shift: modifiers.shift)
        }

        // 特殊物理键（keyCode 与字符无关）。
        switch keyCode {
        case 53: dispatchFromKeyboard(.clear); return true        // Escape → C
        case 51: dispatchFromKeyboard(.backspace); return true    // Delete → ⌫（对应 Windows Back）
        case 117: dispatchFromKeyboard(.clearEntry); return true  // Fn+Delete → CE（对应 Windows Delete）
        case 36, 76: dispatchFromKeyboard(.equals); return true   // Return / Enter → =
        default: break
        }
        if handleFunctionKey(keyCode) { return true }

        guard let ch = chars.first else { return false }

        // 数字（程序员模式按当前进制过滤，等价禁用键）。
        if let d = ch.wholeNumberValue, ch.isNumber, d <= 9 {
            guard keyboardDigitAllowed(d) else { return true }
            dispatchFromKeyboard(.digit(d))
            return true
        }

        // Character 词条（标点，按模式分发）。
        switch ch {
        case "+": dispatchFromKeyboard(.add); return true
        case "-": dispatchFromKeyboard(.subtract); return true
        case "*": dispatchFromKeyboard(.multiply); return true
        case "/": dispatchFromKeyboard(.divide); return true
        case "=": dispatchFromKeyboard(.equals); return true
        case "%":
            dispatchFromKeyboard(mode == .programmer ? .mod : .percent)
            return true
        case ".", ",":
            // 程序员模式小数点禁用，"." 是 NAND 的快捷键（nandButton Character "."）。
            if mode == .programmer {
                if ch == "." { dispatchFromKeyboard(.nand); return true }
                return true
            }
            dispatchFromKeyboard(.point)
            return true
        case "(" where mode != .standard: dispatchFromKeyboard(.openParen); return true
        case ")" where mode != .standard: dispatchFromKeyboard(.closeParen); return true
        case "@" where mode != .programmer: dispatchFromKeyboard(.sqrt); return true
        case "!" where mode == .scientific: dispatchFromKeyboard(.factorial); return true
        case "#" where mode == .scientific: dispatchFromKeyboard(.cube); return true
        case "^":
            if mode == .scientific { dispatchFromKeyboard(.power); return true }
            if mode == .programmer { dispatchFromKeyboard(.xor); return true }
            return false
        case "|":
            if mode == .programmer { dispatchFromKeyboard(.or); return true }
            if mode == .scientific { dispatchFromKeyboard(.abs); return true }
            return false
        case "&" where mode == .programmer: dispatchFromKeyboard(.and); return true
        case "~" where mode == .programmer: dispatchFromKeyboard(.not); return true
        case "\\" where mode == .programmer: dispatchFromKeyboard(.nor); return true
        case "[" where mode == .scientific: dispatchFromKeyboard(.floor); return true
        case "]" where mode == .scientific: dispatchFromKeyboard(.ceil); return true
        case "<" where mode == .programmer:
            dispatchFromKeyboard(shiftMode.leftKey.command)
            return true
        case ">" where mode == .programmer:
            dispatchFromKeyboard(shiftMode.rightKey.command)
            return true
        default:
            break
        }

        // 本地化小数点分隔符（如 ','）。
        if String(ch) == decimalSeparator, mode != .programmer {
            dispatchFromKeyboard(.point)
            return true
        }

        // 字母 VirtualKey 词条。
        guard let u = upper, u.isLetter else { return false }

        // 程序员模式：A–F 十六进制数字（仅 HEX 进制可用；Shift 同映射）。
        if mode == .programmer {
            if let offset = "ABCDEF".firstIndex(of: u) {
                guard currentRadix == .hex else { return true }
                let i = "ABCDEF".distance(from: "ABCDEF".startIndex, to: offset)
                dispatchFromKeyboard(EngineCommand(rawValue: EngineCommand.digitA.rawValue + i)!)
                return true
            }
            return false
        }

        guard mode == .scientific else { return false }

        if modifiers.shift {
            switch u {
            case "S": dispatchFromKeyboard(.asin); return true
            case "O": dispatchFromKeyboard(.acos); return true
            case "T": dispatchFromKeyboard(.atan); return true
            case "U": dispatchFromKeyboard(.asec); return true
            case "I": dispatchFromKeyboard(.acsc); return true
            case "J": dispatchFromKeyboard(.acot); return true
            case "L": dispatchFromKeyboard(.logBaseY); return true
            case "R": dispatchFromKeyboard(.rand); return true
            case "E": dispatchFromKeyboard(.euler); return true
            default: return false
            }
        }

        switch u {
        case "S": dispatchFromKeyboard(.sin); return true
        case "O": dispatchFromKeyboard(.cos); return true
        case "T": dispatchFromKeyboard(.tan); return true
        case "U": dispatchFromKeyboard(.sec); return true
        case "I": dispatchFromKeyboard(.csc); return true
        case "J": dispatchFromKeyboard(.cot); return true
        case "L": dispatchFromKeyboard(.log); return true
        case "N": dispatchFromKeyboard(.ln); return true
        case "X": dispatchFromKeyboard(.exp); return true
        case "R": dispatchFromKeyboard(.reciprocal); return true
        case "Q": dispatchFromKeyboard(.sqr); return true
        case "B": dispatchFromKeyboard(.cubeRoot); return true
        case "Y": dispatchFromKeyboard(.power); return true
        case "G": dispatchFromKeyboard(.pow2); return true
        case "P": dispatchFromKeyboard(.pi); return true
        case "M": dispatchFromKeyboard(.dms); return true
        case "V":
            guard isFToEEnabled, !isInError else { return true }
            isFToEChecked.toggle()
            fToEButtonToggled()
            return true
        default:
            return false
        }
    }

    /// Ctrl（macOS ⌃）与 Ctrl+Shift 和弦。
    private func handleControlChord(_ upper: Character?, shift: Bool) -> Bool {
        guard let u = upper else { return false }

        if shift {
            if u == "D" { clearHistory(); return true } // Ctrl+Shift+D 清除历史
            guard mode == .scientific else { return false }
            switch u { // 反双曲
            case "S": dispatchFromKeyboard(.asinh); return true
            case "O": dispatchFromKeyboard(.acosh); return true
            case "T": dispatchFromKeyboard(.atanh); return true
            case "U": dispatchFromKeyboard(.asech); return true
            case "I": dispatchFromKeyboard(.acsch); return true
            case "J": dispatchFromKeyboard(.acoth); return true
            default: return false
            }
        }

        // 记忆/历史（全引擎模式）。
        switch u {
        case "L": clearMemory(); return true                       // MC
        case "R":
            guard !memorizedNumbers.isEmpty else { return true }
            memoryItemPressed(0)                                   // MR
            return true
        case "P": memoryAdd(0); return true                        // M+
        case "Q": memorySubtract(0); return true                   // M−
        case "M": memorizeNumber(); return true                    // MS
        case "H":
            guard mode != .programmer else { return false }        // 程序员模式无历史
            toggleHistoryPanel()
            return true
        default: break
        }

        guard mode == .scientific else { return false }
        switch u { // 双曲及 Ctrl 变体
        case "S": dispatchFromKeyboard(.sinh); return true
        case "O": dispatchFromKeyboard(.cosh); return true
        case "T": dispatchFromKeyboard(.tanh); return true
        case "U": dispatchFromKeyboard(.sech); return true
        case "I": dispatchFromKeyboard(.csch); return true
        case "J": dispatchFromKeyboard(.coth); return true
        case "N": dispatchFromKeyboard(.powE); return true         // eˣ
        case "G": dispatchFromKeyboard(.pow10); return true        // 10ˣ
        case "Y": dispatchFromKeyboard(.yroot); return true        // y√x
        case "D": dispatchFromKeyboard(.degrees); return true      // deg 转换
        default: return false
        }
    }

    /// F2–F12 功能键（macOS keyCode），按模式分发。
    private func handleFunctionKey(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case 120: // F2 → QWORD
            guard mode == .programmer else { return false }
            setWordSize(.qword)
            return true
        case 99: // F3 → DWORD / GRAD
            if mode == .programmer { setWordSize(.dword); return true }
            if mode == .scientific { switchAngleType(.grad); return true }
            return false
        case 118: // F4 → WORD / DEG
            if mode == .programmer { setWordSize(.word); return true }
            if mode == .scientific { switchAngleType(.deg); return true }
            return false
        case 96: // F5 → HEX / RAD
            if mode == .programmer { switchRadix(.hex); return true }
            if mode == .scientific { switchAngleType(.rad); return true }
            return false
        case 97: // F6 → DEC
            guard mode == .programmer else { return false }
            switchRadix(.dec)
            return true
        case 98: // F7 → OCT
            guard mode == .programmer else { return false }
            switchRadix(.oct)
            return true
        case 100: // F8 → BIN
            guard mode == .programmer else { return false }
            switchRadix(.bin)
            return true
        case 101: // F9 → ±
            dispatchFromKeyboard(.sign)
            return true
        case 111: // F12 → BYTE
            guard mode == .programmer else { return false }
            setWordSize(.byte)
            return true
        default:
            return false
        }
    }

    /// 程序员模式下按当前进制过滤数字键（等价原版禁用按钮）。
    private func keyboardDigitAllowed(_ digit: Int) -> Bool {
        guard mode == .programmer else { return true }
        switch currentRadix {
        case .hex, .dec: return true
        case .oct: return digit < 8
        case .bin: return digit < 2
        }
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
        if mode == .converter {
            NotificationCenter.default.post(name: .converterCopyRequested, object: nil)
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(displayValue, forType: .string)
        AccessibilityAnnouncer.announce(L10n.string("Mac_Ann_Copied"))
    }

    /// 粘贴入口（对应原版 OnPasteCommand）：按模式选择校验规则，
    /// 非法输入整体拒绝并显示引擎错误（DisplayPasteError），合法则逐字符送引擎。
    func pasteFromPasteboard() {
        switch mode {
        case .converter:
            NotificationCenter.default.post(name: .converterPasteRequested, object: nil)
            return
        case .date, .graphing:
            return // 原版这两个模式不支持粘贴
        case .standard, .scientific, .programmer:
            break
        }

        guard let raw = NSPasteboard.general.string(forType: .string) else { return }

        let pasteMode: CopyPasteManager.PasteMode
        switch mode {
        case .scientific: pasteMode = .scientific
        case .programmer: pasteMode = .programmer
        default: pasteMode = .standard
        }

        guard let validated = CopyPasteManager.validate(raw, mode: pasteMode, radix: currentRadix, wordSize: wordSize) else {
            bridge.displayPasteError()
            return
        }
        onPaste(validated)
    }

    private struct PasteButtonInfo {
        var command: EngineCommand?
        var canSendNegate = false
    }

    /// 对应原版 MapCharacterToButtonId：把粘贴字符映射为引擎命令。
    private func mapCharacterToButtonId(_ ch: Character) -> PasteButtonInfo {
        var result = PasteButtonInfo(command: nil, canSendNegate: false)

        switch ch {
        case "0"..."9":
            result.command = EngineCommand.digit(ch.wholeNumberValue!)
            result.canSendNegate = true
        case "*":
            result.command = .multiply
        case "+":
            result.command = .add
        case "-":
            result.command = .subtract
        case "/":
            result.command = .divide
        case "^":
            if mode == .scientific {
                result.command = .power
            }
        case "%":
            if mode == .scientific || mode == .programmer {
                result.command = .mod
            }
        case "=":
            result.command = .equals
        case "(":
            result.command = .openParen
        case ")":
            result.command = .closeParen
        case "a", "A":
            result.command = .digitA
        case "b", "B":
            result.command = .digitB
        case "c", "C":
            result.command = .digitC
        case "d", "D":
            result.command = .digitD
        case "e", "E":
            // 科学计数法只在非程序员模式下生效
            result.command = (mode == .programmer) ? .digitE : .exp
        case "f", "F":
            result.command = .digitF
        default:
            if String(ch) == decimalSeparator {
                result.command = .point
            }
        }

        // 前导零不能发送正负号
        if result.command == .digit(0) {
            result.canSendNegate = false
        }

        return result
    }

    /// 对应原版 OnPaste：逐字符把已通过校验的文本送引擎，
    /// 处理符号前缀延迟发送、括号负号栈与 e±n 指数符号。
    func onPaste(_ pastedString: String) {
        var isFirstLegalChar = true
        bridge.sendCommand(EngineCommand.clearEntry.rawValue)
        var sendNegate = false
        var isPreviousOperator = false
        var negateStack: [Bool] = []

        let chars = Array(pastedString)
        var i = 0
        while i < chars.count {
            var sendCommand = true
            let buttonInfo = mapCharacterToButtonId(chars[i])

            guard let mappedNumOp = buttonInfo.command else {
                i += 1
                continue
            }
            var canSendNegate = buttonInfo.canSendNegate

            if isFirstLegalChar || isPreviousOperator {
                isFirstLegalChar = false
                isPreviousOperator = false

                // '-' 前缀要等下一个合法字符发出后再补 negate，现在发会被引擎忽略。
                if mappedNumOp == .subtract {
                    sendNegate = true
                    sendCommand = false
                }
                // 支持 '+' 号前缀
                if mappedNumOp == .add {
                    sendCommand = false
                }
            }

            switch mappedNumOp {
            case .openParen:
                // 开括号开新表达式，把当前负号状态压栈
                negateStack.append(sendNegate)
                sendNegate = false
            case .closeParen:
                if let restored = negateStack.popLast() {
                    sendNegate = restored
                    canSendNegate = true
                } else {
                    // 没有配对的开括号就不发送闭括号
                    sendCommand = false
                }
            case .add, .subtract, .multiply, .divide:
                isPreviousOperator = true
            default:
                break
            }

            if sendCommand {
                bridge.sendCommand(mappedNumOp.rawValue)

                if sendNegate {
                    if canSendNegate {
                        bridge.sendCommand(EngineCommand.sign.rawValue)
                    }
                    // 前导零上发不了 negate，推迟到合适的字符再发。
                    if mappedNumOp != .digit(0), mappedNumOp != .point {
                        sendNegate = false
                    }
                }
            }

            // 处理指数与指数符号（...e+... / ...e-... / ...e...）
            if mappedNumOp == .exp, i + 1 < chars.count {
                switch mapCharacterToButtonId(chars[i + 1]).command {
                case .some(.subtract):
                    bridge.sendCommand(EngineCommand.sign.rawValue)
                    i += 1
                case .some(.add):
                    i += 1
                default:
                    break
                }
            }

            i += 1
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

extension Notification.Name {
    /// 换算器模式下菜单「粘贴/拷贝」的转发通知（换算 VM 归 UnitConverterView 持有）。
    static let converterPasteRequested = Notification.Name("MacCalculator.converterPasteRequested")
    static let converterCopyRequested = Notification.Name("MacCalculator.converterCopyRequested")
}
