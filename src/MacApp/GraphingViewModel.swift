// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Swift 重写 src/CalcViewModel/GraphingCalculator/GraphingCalculatorViewModel + EquationViewModel。
// 当前阶段用 GraphExpression（Mock 引擎）跑通绘图 UI 架构：
//   - 方程列表：每条含表达式串、颜色、是否可见、解析是否有效。
//   - 视窗：x/y 范围，支持平移与缩放。
// 后续用 Giac 替换求值/分析后，本 ViewModel 接口保持稳定。

import SwiftUI

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
        var color: Color
        var isVisible: Bool = true

        /// 已解析的表达式（nil 表示语法错误或空）。
        var compiled: Compiled?
        var hasError: Bool = false

        /// 显式函数表达式（分析面板只支持显式）。
        var explicitExpression: GraphExpression? {
            if case .explicitFn(let expr) = compiled { return expr }
            return nil
        }
    }

    @Published var equations: [Equation] = []

    /// 变量滑块：所有方程引用的参数（a、b、k…）→ 当前取值。
    @Published var parameters: [String: Double] = [:]

    /// 滑块顺序稳定的参数名列表。
    var parameterNames: [String] { parameters.keys.sorted() }

    /// 视窗范围（数学坐标）。
    @Published var xMin: Double = -10
    @Published var xMax: Double = 10
    @Published var yMin: Double = -10
    @Published var yMax: Double = 10

    /// 方程配色循环（对应原版 EquationStylePanel 的默认色板）。
    private static let palette: [Color] = [
        .blue, .red, .green, .orange, .purple, .pink, .teal, .indigo,
    ]

    init() {
        addEquation(text: "x^2")
        addEquation(text: "sin(x)")
    }

    // MARK: - 方程编辑

    func addEquation(text: String = "") {
        let color = Self.palette[equations.count % Self.palette.count]
        var eq = Equation(text: text, color: color)
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

    /// 汇总所有方程引用的参数：新参数默认 1，未再引用的移除。
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
        for name in used where parameters[name] == nil {
            parameters[name] = 1
        }
        for name in parameters.keys where !used.contains(name) {
            parameters.removeValue(forKey: name)
        }
    }

    func toggleVisibility(id: UUID) {
        guard let index = equations.firstIndex(where: { $0.id == id }) else { return }
        equations[index].isVisible.toggle()
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
}
