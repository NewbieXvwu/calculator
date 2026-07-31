// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// S6 规格表下沉：键盘布局的 Swift 镜像表（对应 spec/keyboard-layout.json）。
// 本表即四键盘的运行时唯一事实源——四个 *CalculatorView 的键盘网格由 KeypadGrid
// 数据驱动渲染，不再各自硬编码 GridRow。字号/间距属平台样式，不入 JSON
// （标准模式分档见 spec/layout-tiers.json）。SpecTableTests 与 JSON 双向防漂移。

import SwiftUI

// MARK: - 键定义模型（JSON 五元组的 Swift 形态 + 平台字号）

/// 键的动态行为角色：静态引擎命令、数字、以及随状态切换的动态键。
enum KeyRole {
    case command(EngineCommand)                             // 静态引擎命令键
    case digit(Int)                                         // 引擎数字键 → digitPressed
    case decimalSeparator                                   // 小数点（随 locale 显示，命令 .point）
    case clearOrClearEntry                                  // 有输入显示 CE 否则 C
    case invToggle                                          // 科学 2nd 切换
    case invPair(normal: InvHalf, inverted: InvHalf)        // 随 2nd 态切换的左列函数
    case shiftLeft                                          // 程序员移位左键（随移位模式）
    case shiftRight                                         // 程序员移位右键（随移位模式）
    case spacer                                             // 占位空位
    case converterDigit(Int)                                // 换算数字键 → inputDigit
    case converterAction(ConverterAction)                   // 换算动作键
    case converterDecimal                                   // 换算小数点 → inputDecimal

    struct InvHalf {
        let label: String
        let command: EngineCommand
    }

    /// spec/keyboard-layout.json 的 kind 字段（静态命令/数字键无 kind → nil）。
    var jsonKind: String? {
        switch self {
        case .command, .digit, .converterDigit, .converterAction: return nil
        case .decimalSeparator, .converterDecimal: return "decimalSeparator"
        case .clearOrClearEntry: return "clearOrClearEntry"
        case .invToggle: return "invToggle"
        case .invPair: return "invPair"
        case .shiftLeft: return "shiftLeft"
        case .shiftRight: return "shiftRight"
        case .spacer: return "spacer"
        }
    }

    /// 静态可判定的引擎命令（动态键返回 nil，invPair 两态另行比对）。
    var jsonEngineCommand: EngineCommand? {
        switch self {
        case .command(let c): return c
        case .digit(let n): return .digit(n)
        case .decimalSeparator: return .point
        default: return nil
        }
    }

    /// 换算键盘动作名（对应 JSON command 字段）。
    var jsonConverterCommand: String? {
        switch self {
        case .converterDigit: return "inputDigit"
        case .converterDecimal: return "inputDecimal"
        case .converterAction(let a):
            switch a {
            case .backspace: return "inputBackspace"
            case .clear: return "clear"
            case .toggleSign: return "toggleSign"
            }
        default: return nil
        }
    }
}

enum ConverterAction {
    case backspace
    case clear
    case toggleSign
}

/// 键面：字面文字 / 语义图标 / 数字 / 动态（标签由 kind 运行时决定）。
enum KeyFace {
    case text(String)
    case icon(AppIcon)
    case digit(Int)
    case none
}

/// 无障碍标签来源（对应 JSON a11y / a11yLiteral / 动态）。
enum KeyA11y {
    case button(String)        // L10n.button(key)
    case literal(String)       // 直接字面量（换算数字）
    case shiftFormat(String)   // L10n.format(key, shiftMode.label)
    case dynamic               // 由 kind 决定（clearOrClearEntry 用 C/CE，invPair 用标签）
    case none                  // spacer
}

/// 禁用规则（对应 JSON disabled 词表）。
enum KeyDisabled {
    case never
    case onError
    case onErrorOrHexDisabled
    case onErrorOrDigitDisallowed
    case unlessSupportsNegative

    var jsonName: String {
        switch self {
        case .never: return "never"
        case .onError: return "onError"
        case .onErrorOrHexDisabled: return "onErrorOrHexDisabled"
        case .onErrorOrDigitDisallowed: return "onErrorOrDigitDisallowed"
        case .unlessSupportsNegative: return "unlessSupportsNegative"
        }
    }
}

/// 单个键的完整规格。fontSize 为平台样式（nil = 标准分档或移位键按标签长度动态决定）。
struct KeySpec {
    let role: KeyRole
    let face: KeyFace
    let style: CalcKeyStyle
    let a11y: KeyA11y
    let disabled: KeyDisabled
    let colSpan: Int
    let fontSize: CGFloat?

    init(_ role: KeyRole, _ face: KeyFace, _ style: CalcKeyStyle, _ a11y: KeyA11y,
         _ disabled: KeyDisabled = .never, colSpan: Int = 1, font: CGFloat? = nil) {
        self.role = role
        self.face = face
        self.style = style
        self.a11y = a11y
        self.disabled = disabled
        self.colSpan = colSpan
        self.fontSize = font
    }

    /// JSON style 字段名（表内不含 emphasized，emphasized 是运行时 2nd 态）。
    var jsonStyle: String {
        switch style {
        case .digit: return "digit"
        case .function: return "function"
        case .operatorKey: return "operator"
        case .emphasized: return "emphasized"
        }
    }
}

/// 一块键盘的布局。
struct KeypadSpec {
    let columns: Int
    let rows: [[KeySpec]]
    let compactFirstRow: [KeySpec]?

    init(columns: Int, rows: [[KeySpec]], compactFirstRow: [KeySpec]? = nil) {
        self.columns = columns
        self.rows = rows
        self.compactFirstRow = compactFirstRow
    }
}

// MARK: - 构造辅助（保持表体可读）

private func engineText(_ c: EngineCommand, _ text: String, _ style: CalcKeyStyle, _ a11y: String,
                        _ dis: KeyDisabled = .never, font: CGFloat? = nil, span: Int = 1) -> KeySpec {
    KeySpec(.command(c), .text(text), style, .button(a11y), dis, colSpan: span, font: font)
}

private func engineIcon(_ c: EngineCommand, _ icon: AppIcon, _ style: CalcKeyStyle, _ a11y: String,
                        _ dis: KeyDisabled = .never, font: CGFloat? = nil, span: Int = 1) -> KeySpec {
    KeySpec(.command(c), .icon(icon), style, .button(a11y), dis, colSpan: span, font: font)
}

private func digit(_ n: Int, _ dis: KeyDisabled = .never, font: CGFloat? = nil, span: Int = 1) -> KeySpec {
    KeySpec(.digit(n), .digit(n), .digit, .button("num\(n)Button"), dis, colSpan: span, font: font)
}

private func convDigit(_ n: Int, font: CGFloat, span: Int = 1) -> KeySpec {
    KeySpec(.converterDigit(n), .digit(n), .digit, .literal("\(n)"), .never, colSpan: span, font: font)
}

// MARK: - 四键盘镜像表

enum KeyboardLayout {

    // 标准（4 列，字号交给 LayoutTier 分档；flashing 开启）。
    static let standard = KeypadSpec(
        columns: 4,
        rows: [
            [
                engineIcon(.percent, .keyPercent, .function, "percentButton", .onError),
                engineText(.clearEntry, "CE", .function, "clearEntryButton"),
                engineText(.clear, "C", .function, "clearButton"),
                engineIcon(.backspace, .keyBackspace, .function, "backSpaceButton"),
            ],
            [
                engineText(.reciprocal, "¹⁄ₓ", .function, "invertButton", .onError),
                engineText(.sqr, "x²", .function, "xpower2Button", .onError),
                engineText(.sqrt, "²√x", .function, "squareRootButton", .onError),
                engineIcon(.divide, .keyDivide, .operatorKey, "divideButton", .onError),
            ],
            [digit(7), digit(8), digit(9), engineIcon(.multiply, .keyMultiply, .operatorKey, "multiplyButton", .onError)],
            [digit(4), digit(5), digit(6), engineIcon(.subtract, .keySubtract, .operatorKey, "minusButton", .onError)],
            [digit(1), digit(2), digit(3), engineIcon(.add, .keyAdd, .operatorKey, "plusButton", .onError)],
            [
                engineIcon(.sign, .keyNegate, .digit, "negateButton", .onError),
                digit(0),
                KeySpec(.decimalSeparator, .none, .digit, .button("decimalSeparatorButton")),
                engineIcon(.equals, .keyEquals, .operatorKey, "equalButton"),
            ],
        ],
        compactFirstRow: [
            engineText(.clearEntry, "CE", .function, "clearEntryButton"),
            engineText(.clear, "C", .function, "clearButton"),
            engineIcon(.backspace, .keyBackspace, .function, "backSpaceButton"),
            engineIcon(.divide, .keyDivide, .operatorKey, "divideButton", .onError),
        ])

    // 科学（5 列，定长字号；左列 invPair 随 2nd 切换）。
    static let scientific = KeypadSpec(
        columns: 5,
        rows: [
            [
                KeySpec(.invToggle, .text("2ⁿᵈ"), .function, .button("shiftButton"), .onError, font: 14),
                engineText(.pi, "π", .function, "piButton", .onError, font: 16),
                engineText(.euler, "e", .function, "eulerButton", .onError, font: 16),
                KeySpec(.clearOrClearEntry, .none, .function, .dynamic, .never, font: 14),
                engineIcon(.backspace, .keyBackspace, .function, "backSpaceButton", font: 15),
            ],
            [
                invPair("x²", .sqr, "x³", .cube),
                engineText(.reciprocal, "¹⁄ₓ", .function, "invertButton", .onError, font: 16),
                engineText(.abs, "|x|", .function, "absButton", .onError, font: 16),
                engineText(.exp, "exp", .function, "expButton", .onError, font: 16),
                engineText(.mod, "mod", .function, "modButton", .onError, font: 16),
            ],
            [
                invPair("√x", .sqrt, "∛x", .cubeRoot),
                engineText(.openParen, "(", .function, "openParenthesisButton", .onError, font: 18),
                engineText(.closeParen, ")", .function, "closeParenthesisButton", .onError, font: 18),
                engineText(.factorial, "n!", .function, "factorialButton", .onError, font: 16),
                engineIcon(.divide, .keyDivide, .operatorKey, "divideButton", .onError, font: 15),
            ],
            [
                invPair("xʸ", .power, "ʸ√x", .yroot),
                digit(7, font: 18), digit(8, font: 18), digit(9, font: 18),
                engineIcon(.multiply, .keyMultiply, .operatorKey, "multiplyButton", .onError, font: 15),
            ],
            [
                invPair("10ˣ", .pow10, "2ˣ", .pow2),
                digit(4, font: 18), digit(5, font: 18), digit(6, font: 18),
                engineIcon(.subtract, .keySubtract, .operatorKey, "minusButton", .onError, font: 15),
            ],
            [
                invPair("log", .log, "logᵧ", .logBaseY),
                digit(1, font: 18), digit(2, font: 18), digit(3, font: 18),
                engineIcon(.add, .keyAdd, .operatorKey, "plusButton", .onError, font: 15),
            ],
            [
                invPair("ln", .ln, "eˣ", .powE),
                engineIcon(.sign, .keyNegate, .digit, "negateButton", .onError, font: 15),
                digit(0, font: 18),
                KeySpec(.decimalSeparator, .none, .digit, .button("decimalSeparatorButton"), .never, font: 18),
                engineIcon(.equals, .keyEquals, .operatorKey, "equalButton", font: 15),
            ],
        ])

    // 程序员（5 列，定长字号；col0=A–F，移位键随移位模式）。
    static let programmer = KeypadSpec(
        columns: 5,
        rows: [
            [
                engineText(.digitA, "A", .function, "aButton", .onErrorOrHexDisabled, font: 16),
                KeySpec(.shiftLeft, .none, .function, .shiftFormat("Mac_ShiftLeft"), .onError),
                KeySpec(.shiftRight, .none, .function, .shiftFormat("Mac_ShiftRight"), .onError),
                KeySpec(.clearOrClearEntry, .none, .function, .dynamic, .never, font: 14),
                engineIcon(.backspace, .keyBackspace, .function, "backSpaceButton", font: 15),
            ],
            [
                engineText(.digitB, "B", .function, "bButton", .onErrorOrHexDisabled, font: 16),
                engineText(.openParen, "(", .function, "openParenthesisButton", .onError, font: 18),
                engineText(.closeParen, ")", .function, "closeParenthesisButton", .onError, font: 18),
                engineText(.mod, "%", .function, "modButton", .onError, font: 16),
                engineIcon(.divide, .keyDivide, .operatorKey, "divideButton", .onError, font: 15),
            ],
            [
                engineText(.digitC, "C", .function, "cButton", .onErrorOrHexDisabled, font: 16),
                digit(7, .onErrorOrDigitDisallowed, font: 18),
                digit(8, .onErrorOrDigitDisallowed, font: 18),
                digit(9, .onErrorOrDigitDisallowed, font: 18),
                engineIcon(.multiply, .keyMultiply, .operatorKey, "multiplyButton", .onError, font: 15),
            ],
            [
                engineText(.digitD, "D", .function, "dButton", .onErrorOrHexDisabled, font: 16),
                digit(4, .onErrorOrDigitDisallowed, font: 18),
                digit(5, .onErrorOrDigitDisallowed, font: 18),
                digit(6, .onErrorOrDigitDisallowed, font: 18),
                engineIcon(.subtract, .keySubtract, .operatorKey, "minusButton", .onError, font: 15),
            ],
            [
                engineText(.digitE, "E", .function, "eButton", .onErrorOrHexDisabled, font: 16),
                digit(1, .onErrorOrDigitDisallowed, font: 18),
                digit(2, .onErrorOrDigitDisallowed, font: 18),
                digit(3, .onErrorOrDigitDisallowed, font: 18),
                engineIcon(.add, .keyAdd, .operatorKey, "plusButton", .onError, font: 15),
            ],
            [
                engineText(.digitF, "F", .function, "fButton", .onErrorOrHexDisabled, font: 16),
                engineIcon(.sign, .keyNegate, .digit, "negateButton", .onError, font: 15),
                digit(0, .onErrorOrDigitDisallowed, font: 18),
                engineIcon(.equals, .keyEquals, .operatorKey, "equalButton", font: 15, span: 2),
            ],
        ])

    // 换算（4 列，定长字号；动作走 UnitConverterViewModel）。
    static let converter = KeypadSpec(
        columns: 4,
        rows: [
            [
                convDigit(7, font: 18), convDigit(8, font: 18), convDigit(9, font: 18),
                KeySpec(.converterAction(.backspace), .icon(.keyBackspace), .function, .button("backSpaceButton"), .never, font: 15),
            ],
            [
                convDigit(4, font: 18), convDigit(5, font: 18), convDigit(6, font: 18),
                KeySpec(.converterAction(.clear), .text("C"), .function, .button("clearButton"), .never, font: 14),
            ],
            [
                convDigit(1, font: 18), convDigit(2, font: 18), convDigit(3, font: 18),
                KeySpec(.converterAction(.toggleSign), .icon(.keyNegate), .function, .button("negateButton"), .unlessSupportsNegative, font: 15),
            ],
            [
                convDigit(0, font: 18, span: 2),
                KeySpec(.converterDecimal, .none, .digit, .button("decimalSeparatorButton"), .never, font: 18),
                KeySpec(.spacer, .none, .digit, .none),
            ],
        ])
}

/// invPair 键构造：两态标签 + 命令，样式基线 function（2nd 态运行时改 emphasized）。
private func invPair(_ normalLabel: String, _ normalCmd: EngineCommand,
                     _ invLabel: String, _ invCmd: EngineCommand) -> KeySpec {
    KeySpec(
        .invPair(normal: .init(label: normalLabel, command: normalCmd),
                 inverted: .init(label: invLabel, command: invCmd)),
        .none, .function, .dynamic, .onError, font: 14)
}

// MARK: - 数据驱动渲染

/// 已解析为可直接渲染的按键参数（把 role/state 解释为 CalcKey 的具体入参）。
struct ResolvedKey {
    let label: CalcKeyLabel
    let style: CalcKeyStyle
    let fontSize: CGFloat
    let disabled: Bool
    let flashing: Bool
    let a11y: String
    let action: () -> Void
}

/// 把 KeySpec + 当前 ViewModel 状态解释成 ResolvedKey。引擎三模式共用 model；
/// 换算模式额外持有 converter；标准模式传入 tier 走分档字号并开启 flashing。
@MainActor
struct KeypadRenderer {
    let model: StandardCalculatorViewModel
    var converter: UnitConverterViewModel?
    var tier: LayoutTier?
    var flashes: Bool = false

    func resolve(_ key: KeySpec) -> ResolvedKey {
        let label = resolveLabel(key)
        let text = labelText(label)
        return ResolvedKey(
            label: label,
            style: resolveStyle(key),
            fontSize: resolveFont(key, text: text),
            disabled: resolveDisabled(key),
            flashing: resolveFlashing(key),
            a11y: resolveA11y(key, text: text),
            action: resolveAction(key))
    }

    private func labelText(_ label: CalcKeyLabel) -> String {
        if case .text(let t) = label { return t }
        return ""
    }

    private func resolveLabel(_ key: KeySpec) -> CalcKeyLabel {
        switch key.role {
        case .digit(let n), .converterDigit(let n):
            return .text("\(n)")
        case .decimalSeparator, .converterDecimal:
            return .text(model.decimalSeparator)
        case .clearOrClearEntry:
            return .text(model.isInputEmpty ? "C" : "CE")
        case .invPair(let normal, let inverted):
            return .text(model.isInvChecked ? inverted.label : normal.label)
        case .shiftLeft:
            return .text(model.shiftMode.leftKey.label)
        case .shiftRight:
            return .text(model.shiftMode.rightKey.label)
        case .spacer:
            return .text("")
        case .command, .invToggle, .converterAction:
            switch key.face {
            case .text(let t): return .text(t)
            case .icon(let icon): return .symbol(icon.sfSymbol)
            case .digit(let n): return .text("\(n)")
            case .none: return .text("")
            }
        }
    }

    private func resolveStyle(_ key: KeySpec) -> CalcKeyStyle {
        switch key.role {
        case .invToggle, .invPair:
            return model.isInvChecked ? .emphasized : key.style
        default:
            return key.style
        }
    }

    private func resolveFont(_ key: KeySpec, text: String) -> CGFloat {
        if let tier {
            switch key.style {
            case .operatorKey:
                return tier.opFont
            case .digit:
                return tier.digitFont
            case .function, .emphasized:
                if case .command(let c) = key.role, c == .clear || c == .clearEntry {
                    return tier.clearFont
                }
                return tier.funcFont
            }
        }
        switch key.role {
        case .shiftLeft, .shiftRight:
            return text.count > 1 ? 12 : 16
        default:
            return key.fontSize ?? 16
        }
    }

    private func resolveDisabled(_ key: KeySpec) -> Bool {
        switch key.disabled {
        case .never:
            return false
        case .onError:
            return model.isInError
        case .onErrorOrHexDisabled:
            return model.isInError || !model.areHexButtonsEnabled
        case .onErrorOrDigitDisallowed:
            let n = digitValue(key.role) ?? 0
            return model.isInError || !model.isDigitAllowed(n)
        case .unlessSupportsNegative:
            return !(converter?.currentCategory.supportsNegative ?? false)
        }
    }

    private func resolveFlashing(_ key: KeySpec) -> Bool {
        guard flashes else { return false }
        let command: EngineCommand?
        switch key.role {
        case .digit(let n): command = .digit(n)
        case .decimalSeparator: command = .point
        case .command(let c): command = c
        default: command = nil
        }
        return command != nil && model.flashedCommand == command
    }

    private func resolveA11y(_ key: KeySpec, text: String) -> String {
        switch key.a11y {
        case .button(let k):
            return L10n.button(k)
        case .literal(let s):
            return s
        case .shiftFormat(let k):
            return L10n.format(k, model.shiftMode.label)
        case .dynamic:
            if case .clearOrClearEntry = key.role {
                return L10n.button(model.isInputEmpty ? "clearButton" : "clearEntryButton")
            }
            return text  // invPair：无障碍取当前可见标签
        case .none:
            return ""
        }
    }

    private func resolveAction(_ key: KeySpec) -> () -> Void {
        let model = model
        let converter = converter
        switch key.role {
        case .command(let c):
            return { model.buttonPressed(c) }
        case .digit(let n):
            return { model.digitPressed(n) }
        case .decimalSeparator:
            return { model.buttonPressed(.point) }
        case .clearOrClearEntry:
            return { model.buttonPressed(model.isInputEmpty ? .clear : .clearEntry) }
        case .invToggle:
            return { model.toggleInv() }
        case .invPair(let normal, let inverted):
            let command = model.isInvChecked ? inverted.command : normal.command
            return { model.pressInvFunction(command) }
        case .shiftLeft:
            return { model.buttonPressed(model.shiftMode.leftKey.command) }
        case .shiftRight:
            return { model.buttonPressed(model.shiftMode.rightKey.command) }
        case .spacer:
            return {}
        case .converterDigit(let n):
            return { converter?.inputDigit(n) }
        case .converterAction(let a):
            return {
                switch a {
                case .backspace: converter?.inputBackspace()
                case .clear: converter?.clear()
                case .toggleSign: converter?.toggleSign()
                }
            }
        case .converterDecimal:
            return { converter?.inputDecimal() }
        }
    }

    private func digitValue(_ role: KeyRole) -> Int? {
        switch role {
        case .digit(let n), .converterDigit(let n): return n
        default: return nil
        }
    }
}

/// 数据驱动键盘网格：外套 GlassKeypadContainer，逐行逐键经 KeypadRenderer 渲染。
struct KeypadGrid: View {
    let rows: [[KeySpec]]
    let renderer: KeypadRenderer

    var body: some View {
        GlassKeypadContainer(spacing: 6) {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                            cell(key)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ key: KeySpec) -> some View {
        if case .spacer = key.role {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
        } else {
            let resolved = renderer.resolve(key)
            calcKey(resolved)
                .gridCellColumns(key.colSpan)
        }
    }

    @ViewBuilder
    private func calcKey(_ r: ResolvedKey) -> some View {
        switch r.label {
        case .text(let t):
            CalcKey(t, style: r.style, fontSize: r.fontSize, disabled: r.disabled,
                    flashing: r.flashing, a11yLabel: r.a11y, action: r.action)
        case .symbol(let s):
            CalcKey(symbol: s, style: r.style, fontSize: r.fontSize, disabled: r.disabled,
                    flashing: r.flashing, a11yLabel: r.a11y, action: r.action)
        }
    }
}
