// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// S6 规格表下沉：模式元数据的唯一事实源（对应 spec/modes.json，跨平台规格）。
// 此前 usesEngine / precision / persistenceKey / 三个窗口尺寸 switch / ⌘1-6 / 图标
// 散在 StandardCalculatorViewModel.swift、ContentView.swift、CalculatorChrome.swift、
// MacCalculatorApp.swift 四处，每处一个平行 switch；现收敛为一张表。
// spec/modes.json 与本表由 SpecTableTests 双向防漂移。

import CoreGraphics

struct ModeDescriptor {
    let mode: CalculatorMode
    /// 跨启动持久化的稳定标识（对应原版 ApplicationDataContainer）。
    let persistenceKey: String
    /// 模式显示名的 String Catalog 键。
    let l10nKey: String
    /// 是否为 CalcManager 引擎驱动模式（日期/换算/绘图不走引擎）。
    let usesEngine: Bool
    let precision: Int
    /// 进入模式时发送的引擎命令（非引擎模式沿用 modeBasic，与历史行为一致）。
    let modeCommand: EngineCommand
    let minBodyWidth: CGFloat
    let minWindowWidth: CGFloat
    let minWindowHeight: CGFloat
    /// 「显示」菜单 ⌘1-6 的数字。
    let menuShortcutDigit: Int
    /// spec/icons.json 中的语义图标名。
    let iconSemantic: String
    /// macOS 后端 SF Symbol 名（其余平台按 iconSemantic 自行映射）。
    let sfSymbol: String

    /// 表序即 ⌘1-6 / 模式菜单顺序。
    static let all: [ModeDescriptor] = [
        ModeDescriptor(mode: .standard, persistenceKey: "standard", l10nKey: "StandardModeText",
                       usesEngine: true, precision: 16, modeCommand: .modeBasic,
                       minBodyWidth: 280, minWindowWidth: 322, minWindowHeight: 360,
                       menuShortcutDigit: 1, iconSemantic: "mode.standard", sfSymbol: "plus.slash.minus"),
        ModeDescriptor(mode: .scientific, persistenceKey: "scientific", l10nKey: "ScientificModeText",
                       usesEngine: true, precision: 32, modeCommand: .modeScientific,
                       minBodyWidth: 360, minWindowWidth: 400, minWindowHeight: 560,
                       menuShortcutDigit: 2, iconSemantic: "mode.scientific", sfSymbol: "function"),
        ModeDescriptor(mode: .programmer, persistenceKey: "programmer", l10nKey: "ProgrammerModeText",
                       usesEngine: true, precision: 64, modeCommand: .modeProgrammer,
                       minBodyWidth: 340, minWindowWidth: 380, minWindowHeight: 600,
                       menuShortcutDigit: 3, iconSemantic: "mode.programmer", sfSymbol: "cpu"),
        ModeDescriptor(mode: .date, persistenceKey: "date", l10nKey: "DateCalculationModeText",
                       usesEngine: false, precision: 16, modeCommand: .modeBasic,
                       minBodyWidth: 300, minWindowWidth: 340, minWindowHeight: 460,
                       menuShortcutDigit: 4, iconSemantic: "mode.date", sfSymbol: "calendar"),
        ModeDescriptor(mode: .converter, persistenceKey: "converter", l10nKey: "ConverterModeText",
                       usesEngine: false, precision: 16, modeCommand: .modeBasic,
                       minBodyWidth: 300, minWindowWidth: 340, minWindowHeight: 520,
                       menuShortcutDigit: 5, iconSemantic: "mode.converter", sfSymbol: "arrow.left.arrow.right"),
        ModeDescriptor(mode: .graphing, persistenceKey: "graphing", l10nKey: "GraphingCalculatorModeText",
                       usesEngine: false, precision: 32, modeCommand: .modeBasic,
                       minBodyWidth: 480, minWindowWidth: 560, minWindowHeight: 520,
                       menuShortcutDigit: 6, iconSemantic: "mode.graphing", sfSymbol: "chart.xyaxis.line"),
    ]

    static func descriptor(for mode: CalculatorMode) -> ModeDescriptor {
        all.first { $0.mode == mode }!
    }

    static func descriptor(persistenceKey: String) -> ModeDescriptor? {
        all.first { $0.persistenceKey == persistenceKey }
    }
}
