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
        let id = UUID()
        var text: String
        var color: Color
        var isVisible: Bool = true

        /// 已解析的表达式（nil 表示语法错误或空）。
        var compiled: GraphExpression?
        var hasError: Bool = false
    }

    @Published var equations: [Equation] = []

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
    }

    func removeEquation(id: UUID) {
        equations.removeAll { $0.id == id }
    }

    func updateEquation(id: UUID, text: String) {
        guard let index = equations.firstIndex(where: { $0.id == id }) else { return }
        equations[index].text = text
        compile(&equations[index])
    }

    func toggleVisibility(id: UUID) {
        guard let index = equations.firstIndex(where: { $0.id == id }) else { return }
        equations[index].isVisible.toggle()
    }

    private func compile(_ eq: inout Equation) {
        let trimmed = eq.text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            eq.compiled = nil
            eq.hasError = false
            return
        }
        if let expr = GraphExpression(trimmed) {
            eq.compiled = expr
            eq.hasError = false
        } else {
            eq.compiled = nil
            eq.hasError = true
        }
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
