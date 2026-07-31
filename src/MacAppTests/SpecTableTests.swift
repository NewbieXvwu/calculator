// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// S6 规格表下沉的防漂移测试：spec/*.json 是跨平台唯一事实源，
// macOS 侧的 Swift 镜像表必须与之逐字段一致。任何一侧改动而另一侧未同步即红。

import SwiftUI
import XCTest
@testable import MacCalculator

@MainActor
final class SpecTableTests: XCTestCase {
    /// 仓库根 spec/ 目录（相对本测试文件定位，与 KGFRegressionTests 同法）。
    private static let specDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // MacAppTests
        .deletingLastPathComponent()   // src
        .deletingLastPathComponent()   // repo root
        .appendingPathComponent("spec")

    private func loadJSON<T: Decodable>(_ file: String, as type: T.Type) throws -> T {
        let url = Self.specDir.appendingPathComponent(file)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - spec/modes.json ⇄ ModeDescriptor

    private struct ModesSpec: Decodable {
        struct Mode: Decodable {
            let id: String
            let l10nKey: String
            let usesEngine: Bool
            let precision: Int
            let engineModeCommand: String
            let menuShortcutDigit: Int
            let icon: String
            let minBodyWidth: Double
            let minWindowWidth: Double
            let minWindowHeight: Double
        }
        let modes: [Mode]
    }

    func testModesSpecMatchesModeDescriptorTable() throws {
        let spec = try loadJSON("modes.json", as: ModesSpec.self)
        XCTAssertEqual(spec.modes.count, ModeDescriptor.all.count)

        let commandByName: [String: EngineCommand] = [
            "modeBasic": .modeBasic, "modeScientific": .modeScientific, "modeProgrammer": .modeProgrammer,
        ]

        for (specMode, descriptor) in zip(spec.modes, ModeDescriptor.all) {
            XCTAssertEqual(specMode.id, descriptor.persistenceKey)
            XCTAssertEqual(specMode.l10nKey, descriptor.l10nKey)
            XCTAssertEqual(specMode.usesEngine, descriptor.usesEngine)
            XCTAssertEqual(specMode.precision, descriptor.precision)
            XCTAssertEqual(commandByName[specMode.engineModeCommand], descriptor.modeCommand, specMode.id)
            XCTAssertEqual(specMode.menuShortcutDigit, descriptor.menuShortcutDigit)
            XCTAssertEqual(specMode.icon, descriptor.iconSemantic)
            XCTAssertEqual(CGFloat(specMode.minBodyWidth), descriptor.minBodyWidth, specMode.id)
            XCTAssertEqual(CGFloat(specMode.minWindowWidth), descriptor.minWindowWidth, specMode.id)
            XCTAssertEqual(CGFloat(specMode.minWindowHeight), descriptor.minWindowHeight, specMode.id)
            // 往返：persistenceKey 反查回同一模式。
            XCTAssertEqual(CalculatorMode(persistenceKey: specMode.id), descriptor.mode)
        }

        // ⌘1-6 序号连续且与表序一致。
        XCTAssertEqual(spec.modes.map(\.menuShortcutDigit), Array(1...spec.modes.count))
    }

    // MARK: - spec/layout-tiers.json ⇄ LayoutTier

    private struct TiersSpec: Decodable {
        struct Tier: Decodable {
            let name: String
            let minHeight: Double
            let digitFont: Double
            let opFont: Double
            let funcFont: Double
            let clearFont: Double
            let hideStandardFunctions: Bool
        }
        let standardKeypadTiers: [Tier]
    }

    func testLayoutTiersSpecMatchesLayoutTierTable() throws {
        let spec = try loadJSON("layout-tiers.json", as: TiersSpec.self)
        XCTAssertEqual(spec.standardKeypadTiers.count, LayoutTier.all.count)

        for (specTier, tier) in zip(spec.standardKeypadTiers, LayoutTier.all) {
            XCTAssertEqual(specTier.name, tier.name)
            XCTAssertEqual(CGFloat(specTier.minHeight), tier.minHeight, specTier.name)
            XCTAssertEqual(CGFloat(specTier.digitFont), tier.digitFont, specTier.name)
            XCTAssertEqual(CGFloat(specTier.opFont), tier.opFont, specTier.name)
            XCTAssertEqual(CGFloat(specTier.funcFont), tier.funcFont, specTier.name)
            XCTAssertEqual(CGFloat(specTier.clearFont), tier.clearFont, specTier.name)
            XCTAssertEqual(specTier.hideStandardFunctions, tier.hideStandardFunctions, specTier.name)
        }

        // 降序匹配 + 0 兜底的结构约束。
        let heights = LayoutTier.all.map(\.minHeight)
        XCTAssertEqual(heights, heights.sorted(by: >))
        XCTAssertEqual(heights.last, 0)

        // 行为抽样：阈值边界各归各档。
        XCTAssertEqual(LayoutTier.forKeypadHeight(360).name, "large")
        XCTAssertEqual(LayoutTier.forKeypadHeight(359).name, "medium")
        XCTAssertEqual(LayoutTier.forKeypadHeight(260).name, "medium")
        XCTAssertEqual(LayoutTier.forKeypadHeight(259).name, "compact")
        XCTAssertTrue(LayoutTier.forKeypadHeight(100).hideStandardFunctions)
    }

    // MARK: - spec/graph-colors.json ⇄ GraphingViewModel 色板

    private struct ColorsSpec: Decodable {
        let light: [String]
        let dark: [String]
    }

    private func parseHex(_ text: String) throws -> UInt32 {
        let hex = String(text.dropFirst())  // 去掉 #
        XCTAssertEqual(text.first, "#")
        XCTAssertEqual(hex.count, 6)
        return try XCTUnwrap(UInt32(hex, radix: 16), text)
    }

    func testGraphColorsSpecMatchesPalettes() throws {
        let spec = try loadJSON("graph-colors.json", as: ColorsSpec.self)
        XCTAssertEqual(spec.light.count, 14)
        XCTAssertEqual(spec.dark.count, 14)
        XCTAssertEqual(GraphingViewModel.lightPalette.count, 14)
        XCTAssertEqual(GraphingViewModel.darkPalette.count, 14)

        for (index, hexText) in spec.light.enumerated() {
            XCTAssertEqual(Color(hex: try parseHex(hexText)), GraphingViewModel.lightPalette[index], "light[\(index)]")
        }
        for (index, hexText) in spec.dark.enumerated() {
            XCTAssertEqual(Color(hex: try parseHex(hexText)), GraphingViewModel.darkPalette[index], "dark[\(index)]")
        }

        // 色板取用行为：越界索引回卷。
        XCTAssertEqual(
            GraphingViewModel.equationColor(index: 14, darkMode: false),
            GraphingViewModel.equationColor(index: 0, darkMode: false))
    }

    // MARK: - spec/icons.json ⇄ AppIcon

    private struct IconsSpec: Decodable {
        struct Icon: Decodable {
            let semantic: String
            let macos: String
        }
        let icons: [Icon]
    }

    func testIconsSpecMatchesAppIconTable() throws {
        let spec = try loadJSON("icons.json", as: IconsSpec.self)
        let table = AppIcon.all

        XCTAssertEqual(spec.icons.count, table.count)
        for (specIcon, icon) in zip(spec.icons, table) {
            XCTAssertEqual(specIcon.semantic, icon.semantic)
            XCTAssertEqual(specIcon.macos, icon.sfSymbol, specIcon.semantic)
        }

        // 语义名唯一。
        XCTAssertEqual(Set(table.map(\.semantic)).count, table.count)

        // 模式图标行与 ModeDescriptor 一致（表内即由其生成，此处防结构改动漂移）。
        for descriptor in ModeDescriptor.all {
            let entry = try XCTUnwrap(spec.icons.first { $0.semantic == descriptor.iconSemantic }, descriptor.persistenceKey)
            XCTAssertEqual(entry.macos, descriptor.sfSymbol)
        }
    }

    // MARK: - spec/units.json ⇄ UnitConverterData

    private struct UnitsSpec: Decodable {
        struct Temp: Decodable {
            let celsiusId: Int
            let fahrenheitId: Int
            let kelvinId: Int
        }
        struct Unit: Decodable {
            let id: Int
            let nameKey: String
            let abbreviationKey: String
            let factor: Double
            let isWhimsical: Bool?
        }
        struct Category: Decodable {
            let id: Int
            let nameKey: String
            let supportsNegative: Bool
            let isTemperature: Bool
            let units: [Unit]
        }
        let temperature: Temp
        let categories: [Category]
    }

    func testUnitsSpecMatchesUnitConverterData() throws {
        let spec = try loadJSON("units.json", as: UnitsSpec.self)

        XCTAssertEqual(spec.temperature.celsiusId, UnitConverterData.celsiusID)
        XCTAssertEqual(spec.temperature.fahrenheitId, UnitConverterData.fahrenheitID)
        XCTAssertEqual(spec.temperature.kelvinId, UnitConverterData.kelvinID)

        XCTAssertEqual(spec.categories.count, UnitConverterData.categories.count)
        for (specCat, cat) in zip(spec.categories, UnitConverterData.categories) {
            XCTAssertEqual(specCat.id, cat.id)
            XCTAssertEqual(L10n.string(specCat.nameKey), cat.name, specCat.nameKey)
            XCTAssertEqual(specCat.supportsNegative, cat.supportsNegative, specCat.nameKey)
            XCTAssertEqual(specCat.isTemperature, cat.isTemperature, specCat.nameKey)
            XCTAssertEqual(specCat.units.count, cat.units.count, specCat.nameKey)
            for (specUnit, unit) in zip(specCat.units, cat.units) {
                XCTAssertEqual(specUnit.id, unit.id)
                XCTAssertEqual(L10n.string(specUnit.nameKey), unit.name, specUnit.nameKey)
                XCTAssertEqual(L10n.string(specUnit.abbreviationKey), unit.abbreviation, specUnit.nameKey)
                XCTAssertEqual(specUnit.factor, unit.factor, specUnit.nameKey)  // 位级一致
                XCTAssertEqual(specUnit.isWhimsical ?? false, unit.isWhimsical, specUnit.nameKey)
            }
        }

        // 换算行为抽样：线性因子 + 温度特判。
        let length = UnitConverterData.categories[0]
        let km = try XCTUnwrap(length.units.first { $0.id == 33 })
        let mile = try XCTUnwrap(length.units.first { $0.id == 36 })
        XCTAssertEqual(UnitConverterData.convert(1, from: mile, to: km, category: length), 1.609344, accuracy: 1e-12)

        let temp = UnitConverterData.categories[3]
        let celsius = try XCTUnwrap(temp.units.first { $0.id == UnitConverterData.celsiusID })
        let fahrenheit = try XCTUnwrap(temp.units.first { $0.id == UnitConverterData.fahrenheitID })
        let kelvin = try XCTUnwrap(temp.units.first { $0.id == UnitConverterData.kelvinID })
        XCTAssertEqual(UnitConverterData.convert(100, from: celsius, to: fahrenheit, category: temp), 212, accuracy: 1e-12)
        XCTAssertEqual(UnitConverterData.convert(0, from: celsius, to: kelvin, category: temp), 273.15, accuracy: 1e-12)
        XCTAssertEqual(UnitConverterData.convert(-40, from: fahrenheit, to: celsius, category: temp), -40, accuracy: 1e-12)
    }

    // MARK: - spec/keyboard-layout.json ⇄ 四键盘布局

    private struct LayoutSpec: Decodable {
        struct ShiftKey: Decodable {
            let label: String
            let command: String
        }
        struct ShiftVariant: Decodable {
            let left: ShiftKey
            let right: ShiftKey
        }
        struct Label: Decodable {
            let text: String?
            let icon: String?
            let digit: Int?
        }
        struct InvHalf: Decodable {
            let label: String
            let command: String
        }
        struct Key: Decodable {
            let kind: String?
            let label: Label?
            let style: String?
            let command: String?
            let a11y: String?
            let a11yLiteral: String?
            let disabled: String?
            let colSpan: Int?
            let normal: InvHalf?
            let inverted: InvHalf?
        }
        struct Keypad: Decodable {
            struct CompactRow: Decodable {
                let keys: [Key]
            }
            let columns: Int
            let rows: [[Key]]
            let compactFirstRow: CompactRow?
        }
        let shiftVariants: [String: ShiftVariant]
        let keypads: [String: Keypad]
    }

    /// 引擎命令名解析表（JSON 命令名 → EngineCommand，规格表跨平台可移植的字符串形态）。
    private static let engineCommandByName: [String: EngineCommand] = [
        "percent": .percent, "clearEntry": .clearEntry, "clear": .clear, "backspace": .backspace,
        "reciprocal": .reciprocal, "sqr": .sqr, "sqrt": .sqrt, "cube": .cube, "cubeRoot": .cubeRoot,
        "power": .power, "yroot": .yroot, "pow10": .pow10, "pow2": .pow2, "log": .log, "logBaseY": .logBaseY,
        "ln": .ln, "powE": .powE, "divide": .divide, "multiply": .multiply, "subtract": .subtract, "add": .add,
        "sign": .sign, "point": .point, "equals": .equals, "pi": .pi, "euler": .euler, "abs": .abs,
        "exp": .exp, "mod": .mod, "openParen": .openParen, "closeParen": .closeParen, "factorial": .factorial,
        "digit0": .digit0, "digit1": .digit1, "digit2": .digit2, "digit3": .digit3, "digit4": .digit4,
        "digit5": .digit5, "digit6": .digit6, "digit7": .digit7, "digit8": .digit8, "digit9": .digit9,
        "digitA": .digitA, "digitB": .digitB, "digitC": .digitC, "digitD": .digitD, "digitE": .digitE, "digitF": .digitF,
        "lshf": .lshf, "rshf": .rshf, "rshfl": .rshfl, "rol": .rol, "ror": .ror, "rolc": .rolc, "rorc": .rorc,
        "and": .and, "or": .or, "xor": .xor, "not": .not, "nand": .nand, "nor": .nor,
        "floor": .floor, "ceil": .ceil, "rand": .rand, "dms": .dms, "degrees": .degrees,
        "sin": .sin, "cos": .cos, "tan": .tan, "sec": .sec, "csc": .csc, "cot": .cot,
        "asin": .asin, "acos": .acos, "atan": .atan, "asec": .asec, "acsc": .acsc, "acot": .acot,
        "sinh": .sinh, "cosh": .cosh, "tanh": .tanh, "sech": .sech, "csch": .csch, "coth": .coth,
        "asinh": .asinh, "acosh": .acosh, "atanh": .atanh, "asech": .asech, "acsch": .acsch, "acoth": .acoth,
    ]

    func testKeyboardLayoutSpecMatchesKeypads() throws {
        let spec = try loadJSON("keyboard-layout.json", as: LayoutSpec.self)

        // 四键盘齐备，行数对照各视图网格。
        XCTAssertEqual(Set(spec.keypads.keys), ["standard", "scientific", "programmer", "converter"])
        let standard = try XCTUnwrap(spec.keypads["standard"])
        let scientific = try XCTUnwrap(spec.keypads["scientific"])
        let programmer = try XCTUnwrap(spec.keypads["programmer"])
        let converter = try XCTUnwrap(spec.keypads["converter"])
        XCTAssertEqual(standard.rows.count, 6)
        XCTAssertEqual(scientific.rows.count, 7)
        XCTAssertEqual(programmer.rows.count, 6)
        XCTAssertEqual(converter.rows.count, 4)
        XCTAssertEqual(standard.columns, 4)
        XCTAssertEqual(scientific.columns, 5)
        XCTAssertEqual(programmer.columns, 5)
        XCTAssertEqual(converter.columns, 4)

        let styles: Set<String> = ["digit", "function", "operator", "emphasized"]
        let disabledRules: Set<String> = [
            "never", "onError", "onErrorOrHexDisabled", "onErrorOrDigitDisallowed", "unlessSupportsNegative",
        ]
        let kinds: Set<String> = [
            "clearOrClearEntry", "invToggle", "invPair", "shiftLeft", "shiftRight", "decimalSeparator", "spacer",
        ]
        let converterActions: Set<String> = ["inputDigit", "inputBackspace", "clear", "toggleSign", "inputDecimal"]
        let keyIconSemantics = Set(AppIcon.all.map(\.semantic).filter { $0.hasPrefix("key.") })

        func validate(_ key: LayoutSpec.Key, keypad: String) throws {
            if key.kind == "spacer" { return }
            if let kind = key.kind {
                XCTAssertTrue(kinds.contains(kind), "\(keypad): 未知 kind \(kind)")
            }
            XCTAssertNotNil(key.style, keypad)
            XCTAssertTrue(styles.contains(key.style ?? ""), "\(keypad): 未知 style \(key.style ?? "nil")")
            XCTAssertTrue(disabledRules.contains(key.disabled ?? ""), "\(keypad): 未知 disabled \(key.disabled ?? "nil")")
            if let icon = key.label?.icon {
                XCTAssertTrue(keyIconSemantics.contains(icon), "\(keypad): 图标 \(icon) 不在 icons.json key.* 中")
            }
            if let command = key.command {
                if keypad == "converter" {
                    XCTAssertTrue(converterActions.contains(command), "converter: 未知动作 \(command)")
                } else {
                    XCTAssertNotNil(Self.engineCommandByName[command], "\(keypad): 命令 \(command) 无法解析")
                }
            }
            // 数字键标签与命令一致（引擎键盘 digitN，换算键盘 inputDigit）。
            if let digit = key.label?.digit {
                XCTAssertEqual(key.command, keypad == "converter" ? "inputDigit" : "digit\(digit)", keypad)
            }
            // invPair 两态命令均可解析。
            if key.kind == "invPair" {
                XCTAssertNotNil(Self.engineCommandByName[key.normal?.command ?? ""], keypad)
                XCTAssertNotNil(Self.engineCommandByName[key.inverted?.command ?? ""], keypad)
            }
            // 静态键必有命令；动态键（clearOrClearEntry/invToggle/invPair/shift/spacer）命令由 kind 决定。
            if key.kind == nil || key.kind == "decimalSeparator" {
                XCTAssertNotNil(key.command, keypad)
            }
        }

        for (name, keypad) in spec.keypads {
            for row in keypad.rows {
                let span = row.reduce(0) { $0 + ($1.colSpan ?? 1) }
                XCTAssertEqual(span, keypad.columns, "\(name): 行跨度 \(span) ≠ 列数 \(keypad.columns)")
                for key in row {
                    try validate(key, keypad: name)
                }
            }
        }

        // 标准模式紧凑首行：4 键（CE C ⌫ ÷），仅 standard 有。
        let compact = try XCTUnwrap(standard.compactFirstRow)
        XCTAssertEqual(compact.keys.count, 4)
        XCTAssertEqual(compact.keys.compactMap(\.command), ["clearEntry", "clear", "backspace", "divide"])
        for key in compact.keys {
            try validate(key, keypad: "standard")
        }
        XCTAssertNil(scientific.compactFirstRow)
        XCTAssertNil(programmer.compactFirstRow)
        XCTAssertNil(converter.compactFirstRow)

        // 科学模式左列 invPair ⇄ ScientificCalculatorView.functionColumn 逐项一致。
        let invPairs = scientific.rows.dropFirst().compactMap(\.first)
        XCTAssertEqual(invPairs.count, ScientificCalculatorView.functionColumn.count)
        for (specKey, entry) in zip(invPairs, ScientificCalculatorView.functionColumn) {
            XCTAssertEqual(specKey.kind, "invPair")
            XCTAssertEqual(specKey.normal?.label, entry.0)
            XCTAssertEqual(Self.engineCommandByName[specKey.normal?.command ?? ""], entry.1, entry.0)
            XCTAssertEqual(specKey.inverted?.label, entry.2)
            XCTAssertEqual(Self.engineCommandByName[specKey.inverted?.command ?? ""], entry.3, entry.2)
        }

        // 程序员模式移位键变体 ⇄ BitShiftMode 四态。
        let shiftModeByName: [String: BitShiftMode] = [
            "arithmetic": .arithmetic, "logical": .logical, "rotate": .rotate, "rotateCarry": .rotateCarry,
        ]
        XCTAssertEqual(Set(spec.shiftVariants.keys), Set(shiftModeByName.keys))
        XCTAssertEqual(shiftModeByName.count, BitShiftMode.allCases.count)
        for (name, variant) in spec.shiftVariants {
            let mode = try XCTUnwrap(shiftModeByName[name])
            XCTAssertEqual(variant.left.label, mode.leftKey.label, name)
            XCTAssertEqual(Self.engineCommandByName[variant.left.command], mode.leftKey.command, name)
            XCTAssertEqual(variant.right.label, mode.rightKey.label, name)
            XCTAssertEqual(Self.engineCommandByName[variant.right.command], mode.rightKey.command, name)
        }
    }

    // MARK: - spec/keyboard-shortcuts.json ⇄ handleKey 行为

    private struct ShortcutsSpec: Decodable {
        struct MenuItem: Decodable {
            let keys: String
            let action: String
        }
        struct Special: Decodable {
            let key: String
            let macKeyCode: UInt16
            let command: String
        }
        struct FnKey: Decodable {
            let key: String
            let macKeyCode: UInt16
            let byMode: [String: String]
        }
        struct CharEntry: Decodable {
            let char: String
            let byMode: [String: String]
        }
        struct SciLetters: Decodable {
            let plain: [String: String]
            let shift: [String: String]
            let control: [String: String]
            let controlShift: [String: String]
        }
        /// "engine"/"all" 或模式名列表。
        enum Modes: Decodable {
            case named(String)
            case list([String])

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let name = try? container.decode(String.self) {
                    self = .named(name)
                } else {
                    self = .list(try container.decode([String].self))
                }
            }

            func contains(_ modeName: String) -> Bool {
                switch self {
                case .named: return true  // engine/all 均覆盖三个引擎模式
                case .list(let names): return names.contains(modeName)
                }
            }
        }
        struct Chord: Decodable {
            let key: String
            let shift: Bool?
            let modes: Modes
            let action: String
        }
        let menu: [MenuItem]
        let special: [Special]
        let functionKeys: [FnKey]
        let characters: [CharEntry]
        let scientificLetters: SciLetters
        let controlChords: [Chord]
        let programmerHexLetters: HexLetters

        struct HexLetters: Decodable {
            let letters: String
        }
    }

    func testKeyboardShortcutsSpecMatchesHandleKey() throws {
        let spec = try loadJSON("keyboard-shortcuts.json", as: ShortcutsSpec.self)
        let model = StandardCalculatorViewModel()
        let engineModes: [(name: String, mode: CalculatorMode)] = [
            ("standard", .standard), ("scientific", .scientific), ("programmer", .programmer),
        ]

        @discardableResult
        func press(_ chars: String, keyCode: UInt16 = 0, shift: Bool = false, control: Bool = false) -> Bool {
            var modifiers = StandardCalculatorViewModel.KeyModifiers()
            modifiers.shift = shift
            modifiers.control = control
            return model.handleKey(chars: chars, keyCode: keyCode, modifiers: modifiers)
        }

        /// 打入哨兵命令，随后断言目标键的分发结果（expected=nil 表示消费但不分发）。
        func assertDispatch(_ chars: String, keyCode: UInt16 = 0, shift: Bool = false, control: Bool = false,
                            expected: EngineCommand?, consumed: Bool = true, _ message: String) {
            press("5")
            XCTAssertEqual(model.flashedCommand, .digit5, "哨兵失败: \(message)")
            XCTAssertEqual(press(chars, keyCode: keyCode, shift: shift, control: control), consumed, message)
            XCTAssertEqual(model.flashedCommand, expected ?? .digit5, message)
        }

        // 菜单快捷键：动作词汇合法（分发由 SwiftUI 菜单系统承担，此处锁词表与模式 id）。
        let namedActions: Set<String> = [
            "copy", "paste", "toggleHistory", "clearHistory", "toggleAlwaysOnTop",
            "memoryStore", "memoryRecall", "memoryAdd", "memorySubtract", "memoryClear",
        ]
        for item in spec.menu {
            if item.action.hasPrefix("setMode:") {
                let id = String(item.action.dropFirst("setMode:".count))
                XCTAssertNotNil(CalculatorMode(persistenceKey: id), item.keys)
            } else {
                XCTAssertTrue(namedActions.contains(item.action), "\(item.keys): 未知动作 \(item.action)")
            }
        }
        XCTAssertEqual(spec.menu.filter { $0.action.hasPrefix("setMode:") }.count, ModeDescriptor.all.count)

        // 特殊物理键：全引擎模式分发对应命令。
        for entry in spec.special {
            let command = try XCTUnwrap(Self.engineCommandByName[entry.command], entry.key)
            for (name, mode) in engineModes {
                model.setCalculatorType(mode)
                assertDispatch("", keyCode: entry.macKeyCode, expected: command, "special \(entry.key) @\(name)")
            }
        }

        // 字符词条：逐模式比对分发；未列出的模式不改变哨兵（','在程序员模式消费不分发）。
        model.setCalculatorType(.programmer)
        XCTAssertEqual(model.currentRadix, .dec)
        for entry in spec.characters {
            for (name, mode) in engineModes {
                model.setCalculatorType(mode)
                let expected: EngineCommand?
                switch entry.byMode[name] {
                case "shiftLeft": expected = model.shiftMode.leftKey.command
                case "shiftRight": expected = model.shiftMode.rightKey.command
                case let action?: expected = try XCTUnwrap(Self.engineCommandByName[action], "\(entry.char)@\(name)")
                case nil: expected = nil
                }
                // 未列出的模式可能不消费（如标准模式 '('），仅在有映射时断言消费。
                if let expected {
                    assertDispatch(entry.char, expected: expected, "char \(entry.char) @\(name)")
                } else {
                    press("5")
                    _ = press(entry.char)
                    XCTAssertEqual(model.flashedCommand, .digit5, "char \(entry.char) @\(name) 不应分发")
                }
            }
        }

        // 科学模式字母四类和弦。
        model.setCalculatorType(.scientific)
        for (letter, action) in spec.scientificLetters.plain {
            if action == "fToEToggle" {
                XCTAssertTrue(press(letter), letter)
                continue
            }
            let command = try XCTUnwrap(Self.engineCommandByName[action], letter)
            assertDispatch(letter, expected: command, "sci plain \(letter)")
        }
        for (letter, action) in spec.scientificLetters.shift {
            let command = try XCTUnwrap(Self.engineCommandByName[action], letter)
            assertDispatch(letter, shift: true, expected: command, "sci shift \(letter)")
        }
        for (letter, action) in spec.scientificLetters.control {
            let command = try XCTUnwrap(Self.engineCommandByName[action], letter)
            assertDispatch(letter, control: true, expected: command, "sci ctrl \(letter)")
        }
        for (letter, action) in spec.scientificLetters.controlShift {
            let command = try XCTUnwrap(Self.engineCommandByName[action], letter)
            assertDispatch(letter, shift: true, control: true, expected: command, "sci ctrl+shift \(letter)")
        }

        // 程序员模式 A-F：仅 HEX 分发，其余进制消费不分发。
        model.setCalculatorType(.programmer)
        XCTAssertEqual(spec.programmerHexLetters.letters, "ABCDEF")
        model.switchRadix(.dec)
        press("5")
        XCTAssertTrue(press("A"))
        XCTAssertEqual(model.flashedCommand, .digit5, "DEC 下 A 不应分发")
        model.switchRadix(.hex)
        assertDispatch("A", expected: .digitA, "HEX 下 A → digitA")
        model.switchRadix(.dec)

        // Ctrl 和弦（记忆/历史）：按模式表消费。
        for chord in spec.controlChords {
            for (name, mode) in engineModes {
                model.setCalculatorType(mode)
                let consumed = press(chord.key, shift: chord.shift ?? false, control: true)
                XCTAssertEqual(consumed, chord.modes.contains(name), "ctrl \(chord.key) @\(name)")
            }
        }

        // 功能键：按模式表分发（sign 引擎命令、radix/angle 验证状态、无映射不消费）。
        for entry in spec.functionKeys {
            for (name, mode) in engineModes {
                model.setCalculatorType(mode)
                let action = entry.byMode[name]
                let consumed = press("", keyCode: entry.macKeyCode)
                XCTAssertEqual(consumed, action != nil, "\(entry.key) @\(name)")
                switch action {
                case "sign":
                    XCTAssertEqual(model.flashedCommand, .sign, entry.key)
                case "radix:hex": XCTAssertEqual(model.currentRadix, .hex, entry.key)
                case "radix:dec": XCTAssertEqual(model.currentRadix, .dec, entry.key)
                case "radix:oct": XCTAssertEqual(model.currentRadix, .oct, entry.key)
                case "radix:bin": XCTAssertEqual(model.currentRadix, .bin, entry.key)
                case "angle:deg": XCTAssertEqual(model.currentAngleType, .deg, entry.key)
                case "angle:rad": XCTAssertEqual(model.currentAngleType, .rad, entry.key)
                case "angle:grad": XCTAssertEqual(model.currentAngleType, .grad, entry.key)
                case "wordSize:qword": XCTAssertEqual(model.wordSize, .qword, entry.key)
                case "wordSize:dword": XCTAssertEqual(model.wordSize, .dword, entry.key)
                case "wordSize:word": XCTAssertEqual(model.wordSize, .word, entry.key)
                case "wordSize:byte": XCTAssertEqual(model.wordSize, .byte, entry.key)
                case nil: break
                default: XCTFail("\(entry.key): 未知动作 \(action ?? "")")
                }
            }
            // 复位程序员模式状态，避免进制过滤影响后续（哨兵是数字键）。
            model.setCalculatorType(.programmer)
            model.switchRadix(.dec)
            model.setWordSize(.qword)
        }
    }

    // MARK: - spec/shortcut-conflicts.json ⇄ keyboard-shortcuts.json（S12 冲突矩阵）

    private struct ConflictsSpec: Decodable {
        struct Tiers: Decodable {
            let safe: String
            let platformConflict: String
            let userOverridable: String
        }
        struct Platform: Decodable {
            let status: String
            let reserved: [String]
            let notes: String
        }
        struct IME: Decodable {
            let rule: String
            let affects: [String]
        }
        struct Ref: Decodable {
            let section: String
            let id: String
        }
        enum Remap: Decodable {
            case one(String)
            case many([String])

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let single = try? container.decode(String.self) {
                    self = .one(single)
                } else {
                    self = .many(try container.decode([String].self))
                }
            }

            var targets: [String] {
                switch self {
                case .one(let target): return [target]
                case .many(let targets): return targets
                }
            }
        }
        struct Resolution: Decodable {
            let resolution: String
            let remap: Remap?
            let note: String?
        }
        struct Conflict: Decodable {
            let refs: [Ref]
            let reason: String
            let platforms: [String: Resolution]
        }
        let tiers: Tiers
        let platforms: [String: Platform]
        let imeConstraint: IME
        let conflicts: [Conflict]
    }

    /// 组合键规范化：cmd→ctrl、opt→alt，修饰键固定 ctrl,alt,shift 序，键名小写。
    private func normalizeCombo(_ keys: String) -> String {
        var parts = keys.lowercased().split(separator: "+").map(String.init)
        let key = parts.removeLast()
        var mods = Set(parts.map { $0 == "cmd" ? "ctrl" : ($0 == "opt" ? "alt" : $0) })
        var out: [String] = []
        for mod in ["ctrl", "alt", "shift"] where mods.remove(mod) != nil {
            out.append(mod)
        }
        XCTAssertTrue(mods.isEmpty, "未知修饰键: \(keys)")
        return (out + [key]).joined(separator: "+")
    }

    func testShortcutConflictMatrixCrossReferencesBindings() throws {
        let matrix = try loadJSON("shortcut-conflicts.json", as: ConflictsSpec.self)
        let shortcuts = try loadJSON("keyboard-shortcuts.json", as: ShortcutsSpec.self)

        // 平台集合齐备；macOS 已解决且不再出现在 conflicts 中。
        XCTAssertEqual(Set(matrix.platforms.keys), ["web", "android", "ohos", "linux", "macos"])
        let macos = try XCTUnwrap(matrix.platforms["macos"])
        XCTAssertEqual(macos.status, "resolved")
        XCTAssertTrue(macos.reserved.isEmpty)
        for (name, platform) in matrix.platforms where name != "macos" {
            XCTAssertEqual(platform.status, "open", name)
            XCTAssertFalse(platform.reserved.isEmpty, name)
        }

        // IME 约束覆盖全部字符类分发通道。
        let charSections: Set<String> = [
            "digits", "characters", "localeDecimalSeparator", "scientificLetters", "programmerHexLetters",
        ]
        XCTAssertEqual(Set(matrix.imeConstraint.affects), charSections)
        XCTAssertFalse(matrix.imeConstraint.rule.isEmpty)

        // ref 必须指向 keyboard-shortcuts.json 中真实存在的绑定。
        let sciByCategory: [String: [String: String]] = [
            "plain": shortcuts.scientificLetters.plain,
            "shift": shortcuts.scientificLetters.shift,
            "control": shortcuts.scientificLetters.control,
            "controlShift": shortcuts.scientificLetters.controlShift,
        ]
        func bindingExists(_ ref: ConflictsSpec.Ref) -> Bool {
            switch ref.section {
            case "menu": return shortcuts.menu.contains { $0.keys == ref.id }
            case "special": return shortcuts.special.contains { $0.key == ref.id }
            case "functionKeys": return shortcuts.functionKeys.contains { $0.key == ref.id }
            case "characters": return shortcuts.characters.contains { $0.char == ref.id }
            case "controlChords":
                if let letter = ref.id.split(separator: "+").last.map(String.init), ref.id.hasPrefix("shift+") {
                    return shortcuts.controlChords.contains { $0.key == letter && $0.shift == true }
                }
                return shortcuts.controlChords.contains { $0.key == ref.id && $0.shift != true }
            case "scientificLetters":
                let pieces = ref.id.split(separator: ":").map(String.init)
                guard pieces.count == 2, let category = sciByCategory[pieces[0]] else { return false }
                return category[pieces[1]] != nil
            default: return false
            }
        }

        let resolutions: Set<String> = ["remap", "requiresFn", "menuOnly", "notApplicable"]
        var coveredWebRefs: Set<String> = []
        var remapsByPlatform: [String: [String]] = [:]
        for conflict in matrix.conflicts {
            XCTAssertFalse(conflict.refs.isEmpty, conflict.reason)
            XCTAssertFalse(conflict.platforms.isEmpty, conflict.reason)
            for ref in conflict.refs {
                XCTAssertTrue(bindingExists(ref), "\(ref.section):\(ref.id) 不存在于 keyboard-shortcuts.json")
            }
            for (platformName, entry) in conflict.platforms {
                XCTAssertNotEqual(platformName, "macos", "macOS 已解决，不应再登记冲突: \(conflict.reason)")
                XCTAssertNotNil(matrix.platforms[platformName], platformName)
                XCTAssertTrue(resolutions.contains(entry.resolution), "\(platformName): 未知 resolution \(entry.resolution)")
                XCTAssertEqual(entry.remap != nil, entry.resolution == "remap", "\(platformName): remap 字段与 resolution 不符")
                if case .many(let targets)? = entry.remap {
                    XCTAssertEqual(targets.count, conflict.refs.count, "\(platformName): remap 数组须与 refs 一一对应")
                }
                if let remap = entry.remap {
                    remapsByPlatform[platformName, default: []].append(contentsOf: remap.targets.map(normalizeCombo))
                }
                if platformName == "web" {
                    for ref in conflict.refs {
                        coveredWebRefs.insert("\(ref.section):\(ref.id)")
                    }
                }
            }
        }

        // Web 保留集合与现有绑定的碰撞必须全部被 conflicts 覆盖（Web 是最严重平台）。
        let webReserved = Set(try XCTUnwrap(matrix.platforms["web"]).reserved.map(normalizeCombo))
        var webBindings: [(refKey: String, combo: String)] = []
        for item in shortcuts.menu {
            webBindings.append(("menu:\(item.keys)", normalizeCombo(item.keys)))
        }
        for entry in shortcuts.functionKeys {
            webBindings.append(("functionKeys:\(entry.key)", normalizeCombo(entry.key)))
        }
        for chord in shortcuts.controlChords {
            let shifted = chord.shift == true
            let refKey = "controlChords:\(shifted ? "shift+" : "")\(chord.key)"
            webBindings.append((refKey, normalizeCombo("ctrl+\(shifted ? "shift+" : "")\(chord.key)")))
        }
        for (letter, _) in shortcuts.scientificLetters.control {
            webBindings.append(("scientificLetters:control:\(letter)", normalizeCombo("ctrl+\(letter)")))
        }
        for (letter, _) in shortcuts.scientificLetters.controlShift {
            webBindings.append(("scientificLetters:controlShift:\(letter)", normalizeCombo("ctrl+shift+\(letter)")))
        }
        for binding in webBindings where webReserved.contains(binding.combo) {
            XCTAssertTrue(
                coveredWebRefs.contains(binding.refKey),
                "\(binding.refKey)（\(binding.combo)）落入 Web 保留集合但未被冲突矩阵覆盖")
        }

        // remap 目标不得落回所在平台保留集合，且平台内互不重复、不与该平台幸存绑定撞车。
        for (platformName, targets) in remapsByPlatform {
            let reserved = Set(try XCTUnwrap(matrix.platforms[platformName]).reserved.map(normalizeCombo))
            XCTAssertEqual(Set(targets).count, targets.count, "\(platformName): remap 目标重复")
            for target in targets {
                XCTAssertFalse(reserved.contains(target), "\(platformName): remap 目标 \(target) 落回保留集合")
            }
            if platformName == "web" {
                let surviving = Set(webBindings.filter { !coveredWebRefs.contains($0.refKey) }.map(\.combo))
                for target in targets {
                    XCTAssertFalse(surviving.contains(target), "web: remap 目标 \(target) 与幸存绑定撞车")
                }
            }
        }
    }
}
