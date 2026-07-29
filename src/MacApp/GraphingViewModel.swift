// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Swift 重写 src/CalcViewModel/GraphingCalculator/GraphingCalculatorViewModel + EquationViewModel。
//   - 方程列表：表达式串、色板索引、线型、是否可见、解析是否有效。
//   - 视窗：x/y 范围，支持平移与缩放；设置面板可手动输入范围。
//   - 变量滑块：Value/Min/Max/Step（对应原版 VariableViewModel，默认 -5…5 步长 0.1）。
//   - 图形设置：三角单位（弧度/角度/梯度）、线宽 1–4（对应 GraphingSettings.xaml）。

import SwiftUI

/// 方程线型（对应 GraphControl.EquationLineStyle：Solid/Dash/Dot）。
enum EquationLineStyle: String, CaseIterable {
    case solid, dash, dot

    /// StrokeDashArray 语义：以线宽为单位的 dash 模式（XAML {2,1} / {1}）。
    func dashPattern(lineWidth: CGFloat) -> [CGFloat] {
        switch self {
        case .solid: return []
        case .dash: return [2 * lineWidth, lineWidth]
        case .dot: return [lineWidth, lineWidth]
        }
    }
}

@MainActor
final class GraphingViewModel: ObservableObject {
    /// 单条方程。
    struct Equation: Identifiable {
        /// 编译结果：显式 y=f(x) 走逐列采样；隐式 F(x,y)=0 走 marching squares。
        enum Compiled {
            case explicitFn(GraphExpression)
            case implicitEq(GraphExpression)
        }

        let id = UUID()
        var text: String
        /// 色板索引（0..13，深浅色各解析到对应 EquationBrush）。
        var colorIndex: Int
        var lineStyle: EquationLineStyle = .solid
        var isVisible: Bool = true

        /// MathLive 编辑器的 LaTeX 形式（text 是其 ASCIIMath 等价物，供引擎解析）。
        var latex: String = ""

        /// 已解析的表达式（nil 表示语法错误或空）。
        var compiled: Compiled?
        var hasError: Bool = false

        /// 显式函数表达式（分析面板只支持显式）。
        var explicitExpression: GraphExpression? {
            if case .explicitFn(let expr) = compiled { return expr }
            return nil
        }
    }

    /// 变量滑块（对应原版 GraphControl.Variable：Step 0.1、Min -5、Max 5）。
    struct SliderVariable {
        var value: Double = 1
        var min: Double = -5
        var max: Double = 5
        var step: Double = 0.1
    }

    /// 原版 VariableViewModel 的 DefaultMinMaxRange。
    static let defaultMinMaxRange: Double = 10

    @Published var equations: [Equation] = []

    /// 变量滑块：所有方程引用的参数（a、b、k…）→ 滑块状态。
    @Published var variables: [String: SliderVariable] = [:]

    /// 滑块顺序稳定的参数名列表。
    var parameterNames: [String] { variables.keys.sorted() }

    /// 求值用的参数取值表。
    var parameters: [String: Double] { variables.mapValues(\.value) }

    /// 视窗范围（数学坐标）。
    @Published var xMin: Double = -10
    @Published var xMax: Double = 10
    @Published var yMin: Double = -10
    @Published var yMax: Double = 10

    /// 三角单位（GraphingSettings 的 Radians/Degrees/Gradians）。
    @Published var trigMode: GraphTrigMode = .radians

    /// 线宽（GraphingSettings 的 1.0/2.0/3.0/4.0，默认 2）。
    @Published var lineWidth: Double = 2.0

    /// 14 色方程色板（App.xaml EquationBrush1–14，浅色主题）。
    static let lightPalette: [Color] = [
        Color(hex: 0x0063B1), Color(hex: 0x00B7C3), Color(hex: 0x6600CC), Color(hex: 0x107C10),
        Color(hex: 0x00CC6A), Color(hex: 0x008055), Color(hex: 0x58595B), Color(hex: 0xE81123),
        Color(hex: 0xE3008C), Color(hex: 0xB31564), Color(hex: 0xFFB900), Color(hex: 0xF7630C),
        Color(hex: 0x8E562E), Color(hex: 0x000000),
    ]

    /// 14 色方程色板（深色主题）。
    static let darkPalette: [Color] = [
        Color(hex: 0x4D92C8), Color(hex: 0x4DCDD5), Color(hex: 0xA366E0), Color(hex: 0x58A358),
        Color(hex: 0x4DDB97), Color(hex: 0x4DA688), Color(hex: 0x8A8B8C), Color(hex: 0xEF5865),
        Color(hex: 0xEB4DAF), Color(hex: 0xCA5B93), Color(hex: 0xFFCE4D), Color(hex: 0xF99255),
        Color(hex: 0xB0896D), Color(hex: 0xFFFFFF),
    ]

    static func equationColor(index: Int, darkMode: Bool) -> Color {
        let palette = darkMode ? darkPalette : lightPalette
        return palette[((index % palette.count) + palette.count) % palette.count]
    }

    init() {
        addEquation(text: "x^2", latex: "x^2")
        addEquation(text: "sin(x)", latex: "\\sin(x)")
    }

    // MARK: - 方程编辑

    func addEquation(text: String = "", latex: String = "") {
        var eq = Equation(text: text, colorIndex: equations.count % Self.lightPalette.count, latex: latex)
        compile(&eq)
        equations.append(eq)
        syncParameters()
    }

    func removeEquation(id: UUID) {
        equations.removeAll { $0.id == id }
        syncParameters()
    }

    func updateEquation(id: UUID, text: String) {
        guard let index = equations.firstIndex(where: { $0.id == id }) else { return }
        equations[index].text = text
        compile(&equations[index])
        syncParameters()
    }

    /// MathLive 编辑器回调：同时更新 LaTeX 与 ASCIIMath（后者驱动引擎重编译）。
    func updateEquation(id: UUID, ascii: String, latex: String) {
        guard let index = equations.firstIndex(where: { $0.id == id }) else { return }
        equations[index].latex = latex
        equations[index].text = ascii
        compile(&equations[index])
        syncParameters()
    }

    /// 样式面板：改颜色。
    func setColorIndex(id: UUID, _ colorIndex: Int) {
        guard let index = equations.firstIndex(where: { $0.id == id }) else { return }
        equations[index].colorIndex = colorIndex
    }

    /// 样式面板：改线型。
    func setLineStyle(id: UUID, _ style: EquationLineStyle) {
        guard let index = equations.firstIndex(where: { $0.id == id }) else { return }
        equations[index].lineStyle = style
    }

    /// 汇总所有方程引用的参数：新参数按默认滑块建档，未再引用的移除。
    private func syncParameters() {
        var used = Set<String>()
        for eq in equations {
            switch eq.compiled {
            case .explicitFn(let expr), .implicitEq(let expr):
                used.formUnion(expr.parameters)
            case nil:
                break
            }
        }
        for name in used where variables[name] == nil {
            variables[name] = SliderVariable()
        }
        for name in variables.keys where !used.contains(name) {
            variables.removeValue(forKey: name)
        }
    }

    func toggleVisibility(id: UUID) {
        guard let index = equations.firstIndex(where: { $0.id == id }) else { return }
        equations[index].isVisible.toggle()
    }

    // MARK: - 变量滑块编辑（对应 VariableViewModel 的 Min/Max/Step 语义）

    func setVariableValue(_ name: String, _ value: Double) {
        guard var v = variables[name] else { return }
        v.value = value
        variables[name] = v
    }

    /// 设 Min：若 ≥ Max 则 Max 顺延 DefaultMinMaxRange（原版行为）。
    func setVariableMin(_ name: String, _ min: Double) {
        guard var v = variables[name] else { return }
        if min >= v.max {
            v.max = min + Self.defaultMinMaxRange
        }
        v.min = min
        v.value = Swift.min(Swift.max(v.value, v.min), v.max)
        variables[name] = v
    }

    /// 设 Max：若 ≤ Min 则 Min 前移 DefaultMinMaxRange（原版行为）。
    func setVariableMax(_ name: String, _ max: Double) {
        guard var v = variables[name] else { return }
        if max <= v.min {
            v.min = max - Self.defaultMinMaxRange
        }
        v.max = max
        v.value = Swift.min(Swift.max(v.value, v.min), v.max)
        variables[name] = v
    }

    func setVariableStep(_ name: String, _ step: Double) {
        guard var v = variables[name], step > 0 else { return }
        v.step = step
        variables[name] = v
    }

    /// 步进按钮：±Step，夹在 [Min, Max]。
    func stepVariable(_ name: String, direction: Double) {
        guard var v = variables[name] else { return }
        v.value = Swift.min(Swift.max(v.value + direction * v.step, v.min), v.max)
        variables[name] = v
    }

    // MARK: - 视窗操作

    var xSpan: Double { xMax - xMin }
    var ySpan: Double { yMax - yMin }

    /// 以数学坐标位移平移视窗。
    func pan(dxMath: Double, dyMath: Double) {
        xMin -= dxMath; xMax -= dxMath
        yMin -= dyMath; yMax -= dyMath
    }

    /// 以视窗中心为锚缩放（factor<1 放大，>1 缩小）。
    func zoom(factor: Double) {
        let cx = (xMin + xMax) / 2, cy = (yMin + yMax) / 2
        let hx = xSpan / 2 * factor, hy = ySpan / 2 * factor
        xMin = cx - hx; xMax = cx + hx
        yMin = cy - hy; yMax = cy + hy
    }

    /// 以指定数学坐标点为锚缩放（滚轮/捏合手势用）。
    func zoom(factor: Double, anchorX: Double, anchorY: Double) {
        xMin = anchorX + (xMin - anchorX) * factor
        xMax = anchorX + (xMax - anchorX) * factor
        yMin = anchorY + (yMin - anchorY) * factor
        yMax = anchorY + (yMax - anchorY) * factor
    }

    func resetView() {
        xMin = -10; xMax = 10; yMin = -10; yMax = 10
    }

    /// 设置面板手动输入范围：仅在 min < max 时生效，返回是否接受。
    @discardableResult
    func applyRange(xMin: Double, xMax: Double, yMin: Double, yMax: Double) -> Bool {
        guard xMin < xMax, yMin < yMax,
              xMin.isFinite, xMax.isFinite, yMin.isFinite, yMax.isFinite else { return false }
        self.xMin = xMin; self.xMax = xMax
        self.yMin = yMin; self.yMax = yMax
        return true
    }

    /// 解析输入：
    ///   - "y=…"/"f(x)=…" 或不含 "=" 的单变量表达式 → 显式 y=f(x)
    ///   - 其余含 "=" 的（如 x^2+y^2=25、x=5）→ 隐式 F(x,y)=LHS-RHS=0
    ///   - 不含 "=" 但引用 y 的（如 x^2+y^2-25）→ 隐式 F(x,y)=0
    private func compile(_ eq: inout Equation) {
        let trimmed = eq.text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            eq.compiled = nil
            eq.hasError = false
            return
        }

        let lower = trimmed.lowercased()
        var result: Equation.Compiled?

        if lower.hasPrefix("y=") || lower.hasPrefix("f(x)=") {
            let rest = String(trimmed.dropFirst(lower.hasPrefix("y=") ? 2 : 5))
            if rest.contains("=") {
                result = nil // 多个等号
            } else if rest.lowercased().contains("y") {
                // y = 含 y 的式子 → 化为隐式 (rest)-(y)=0
                result = GraphExpression(rawTwoVariable: "(\(rest))-(y)").map { .implicitEq($0) }
            } else {
                result = GraphExpression(rest).map { .explicitFn($0) }
            }
        } else if let eqIndex = trimmed.firstIndex(of: "=") {
            let lhs = String(trimmed[..<eqIndex])
            let rhs = String(trimmed[trimmed.index(after: eqIndex)...])
            if lhs.trimmingCharacters(in: .whitespaces).isEmpty
                || rhs.trimmingCharacters(in: .whitespaces).isEmpty || rhs.contains("=") {
                result = nil
            } else {
                result = GraphExpression(rawTwoVariable: "(\(lhs))-(\(rhs))").map { .implicitEq($0) }
            }
        } else if lower.contains("y") {
            // 无等号但引用 y：按 F(x,y)=0 处理（GeoGebra 惯例）。
            result = GraphExpression(rawTwoVariable: trimmed).map { .implicitEq($0) }
        } else {
            result = GraphExpression(trimmed).map { .explicitFn($0) }
        }

        eq.compiled = result
        eq.hasError = result == nil
    }
}

extension Color {
    /// 由 0xRRGGBB 字面量构造。
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}
