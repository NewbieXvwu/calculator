// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// S6/D8 规格表下沉：图标语义名 → SF Symbol 的唯一事实源（对应 spec/icons.json）。
// 视图层只引用语义常量，不写 SF Symbol 字面量；SpecTableTests 与 JSON 双向防漂移。
// key.* 常量由键盘布局表（spec/keyboard-layout.json）引用，键面渲染仍经 CalcKey(symbol:)。

struct AppIcon {
    let semantic: String
    let sfSymbol: String

    // MARK: chrome
    static let sidebarHistory = AppIcon(semantic: "chrome.sidebar.history", sfSymbol: "sidebar.leading")
    /// SF 公共库无 calculator 字形，暂以九宫格兜底。
    static let modeMenu = AppIcon(semantic: "chrome.mode.menu", sfSymbol: "circle.grid.3x3")

    // MARK: 历史/记忆面板
    static let historyEmpty = AppIcon(semantic: "panel.history.empty", sfSymbol: "clock.arrow.circlepath")
    static let memoryEmpty = AppIcon(semantic: "panel.memory.empty", sfSymbol: "memorychip")
    static let itemDelete = AppIcon(semantic: "panel.item.delete", sfSymbol: "trash")

    // MARK: 键面符号
    static let keyBackspace = AppIcon(semantic: "key.backspace", sfSymbol: "delete.left")
    static let keyDivide = AppIcon(semantic: "key.divide", sfSymbol: "divide")
    static let keyMultiply = AppIcon(semantic: "key.multiply", sfSymbol: "multiply")
    static let keySubtract = AppIcon(semantic: "key.subtract", sfSymbol: "minus")
    static let keyAdd = AppIcon(semantic: "key.add", sfSymbol: "plus")
    static let keyEquals = AppIcon(semantic: "key.equals", sfSymbol: "equal")
    static let keyNegate = AppIcon(semantic: "key.negate", sfSymbol: "plus.forwardslash.minus")
    static let keyPercent = AppIcon(semantic: "key.percent", sfSymbol: "percent")

    // MARK: 科学模式
    static let sciTrigMenu = AppIcon(semantic: "sci.menu.trig", sfSymbol: "angle")
    static let sciFuncMenu = AppIcon(semantic: "sci.menu.func", sfSymbol: "f.cursive")

    // MARK: 程序员模式
    static let progKeypadFull = AppIcon(semantic: "prog.keypad.full", sfSymbol: "square.grid.3x3")
    static let progKeypadBitFlip = AppIcon(semantic: "prog.keypad.bitflip", sfSymbol: "01.square")
    static let progBitwiseMenu = AppIcon(semantic: "prog.menu.bitwise", sfSymbol: "point.3.filled.connected.trianglepath.dotted")
    static let progShiftMenu = AppIcon(semantic: "prog.menu.shift", sfSymbol: "chevron.right.2")

    // MARK: 单位换算
    static let convCurrencyRefresh = AppIcon(semantic: "conv.currency.refresh", sfSymbol: "arrow.clockwise")
    static let convUnitsSwap = AppIcon(semantic: "conv.units.swap", sfSymbol: "arrow.up.arrow.down")

    // MARK: 绘图
    static let graphEquationAdd = AppIcon(semantic: "graph.equation.add", sfSymbol: "plus")
    static let graphEquationError = AppIcon(semantic: "graph.equation.error", sfSymbol: "exclamationmark.circle.fill")
    static let graphEquationRemove = AppIcon(semantic: "graph.equation.remove", sfSymbol: "xmark")
    static let graphParamStepMinus = AppIcon(semantic: "graph.param.step.minus", sfSymbol: "minus.circle")
    static let graphParamStepPlus = AppIcon(semantic: "graph.param.step.plus", sfSymbol: "plus.circle")
    static let graphParamRange = AppIcon(semantic: "graph.param.range", sfSymbol: "slider.horizontal.3")
    static let graphTrace = AppIcon(semantic: "graph.trace", sfSymbol: "scope")
    static let graphExport = AppIcon(semantic: "graph.export", sfSymbol: "square.and.arrow.up")
    static let graphSettings = AppIcon(semantic: "graph.settings", sfSymbol: "gearshape")
    static let graphZoomIn = AppIcon(semantic: "graph.zoom.in", sfSymbol: "plus.magnifyingglass")
    static let graphZoomOut = AppIcon(semantic: "graph.zoom.out", sfSymbol: "minus.magnifyingglass")
    static let graphZoomReset = AppIcon(semantic: "graph.zoom.reset", sfSymbol: "arrow.up.left.and.down.right.magnifyingglass")

    /// 全量表（含模式图标，模式行来自 ModeDescriptor 避免双写）。顺序与 spec/icons.json 一致。
    static var all: [AppIcon] {
        var icons: [AppIcon] = [sidebarHistory, modeMenu]
        icons += ModeDescriptor.all.map { AppIcon(semantic: $0.iconSemantic, sfSymbol: $0.sfSymbol) }
        icons += [
            historyEmpty, memoryEmpty, itemDelete,
            keyBackspace, keyDivide, keyMultiply, keySubtract, keyAdd, keyEquals, keyNegate, keyPercent,
            sciTrigMenu, sciFuncMenu,
            progKeypadFull, progKeypadBitFlip, progBitwiseMenu, progShiftMenu,
            convCurrencyRefresh, convUnitsSwap,
            graphEquationAdd, graphEquationError, graphEquationRemove,
            graphParamStepMinus, graphParamStepPlus, graphParamRange,
            graphTrace, graphExport, graphSettings, graphZoomIn, graphZoomOut, graphZoomReset,
        ]
        return icons
    }
}
