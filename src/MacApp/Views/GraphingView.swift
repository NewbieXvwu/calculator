// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 排版对照 Views/GraphingCalculator/GraphingCalculator.xaml：
//   左侧图形画布（2* 宽，自研渲染器）＋ 右侧方程输入区（1* 宽）。
//   顶栏与其它模式共用 CalculatorHeader。
// 渲染器为自研：SwiftUI Canvas(CoreGraphics) 逐像素列自适应采样 +
// 间断点检测 + 网格/坐标轴；平移用拖拽、缩放用捏合与按钮。
// 数学求值当前走 GraphExpression（Mock），后续替换为 Giac。

import SwiftUI

struct GraphingView: View {
    @ObservedObject var model: StandardCalculatorViewModel
    @StateObject private var graph = GraphingViewModel()

    var showsHistoryButton: Bool = false
    @State private var historyPopoverShown = false
    @State private var showAnalysis = false

    var body: some View {
        VStack(spacing: 0) {
            CalculatorHeader(model: model, showsHistoryButton: showsHistoryButton, historyPopoverShown: $historyPopoverShown)

            HStack(spacing: 0) {
                GraphCanvas(graph: graph)
                    .frame(minWidth: 260)
                    .layoutPriority(2)

                Divider()

                equationPanel
                    .frame(width: 220)
            }
        }
    }

    // MARK: - 方程输入区

    private var equationPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("函数")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    showAnalysis.toggle()
                } label: {
                    Image(systemName: showAnalysis ? "chart.bar.doc.horizontal.fill" : "chart.bar.doc.horizontal")
                }
                .buttonStyle(.borderless)
                .help("函数分析")
                .accessibilityLabel("函数分析")
                Button {
                    graph.addEquation()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("添加函数")
                .accessibilityLabel("添加函数")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(spacing: 6) {
                    ForEach($graph.equations) { $eq in
                        equationRow($eq)
                    }
                }
                .padding(10)
            }

            if showAnalysis {
                Divider()
                analysisSection
            }

            Divider()
            viewControls
        }
    }

    // MARK: - 函数分析（数值：零点/y 截距/极值）

    private var analysisSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(graph.equations) { eq in
                    if eq.isVisible, let expr = eq.compiled {
                        analysisRow(eq: eq, expr: expr)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 180)
    }

    private func analysisRow(eq: GraphingViewModel.Equation, expr: GraphExpression) -> some View {
        let analysis = GraphAnalyzer.analyze(expr, xMin: graph.xMin, xMax: graph.xMax)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(eq.color).frame(width: 8, height: 8)
                Text("y=\(eq.text)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }
            if analysis.isEmpty {
                Text("当前视窗无可报告特征")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                if let y0 = analysis.yIntercept {
                    analysisLine("y 截距", "(0, \(fmt(y0)))")
                }
                if !analysis.zeros.isEmpty {
                    analysisLine("零点", analysis.zeros.prefix(6).map { "\(fmt($0))" }.joined(separator: ", "))
                }
                if !analysis.maxima.isEmpty {
                    analysisLine("极大值", analysis.maxima.prefix(4).map { "(\(fmt($0.x)), \(fmt($0.y)))" }.joined(separator: " "))
                }
                if !analysis.minima.isEmpty {
                    analysisLine("极小值", analysis.minima.prefix(4).map { "(\(fmt($0.x)), \(fmt($0.y)))" }.joined(separator: " "))
                }
            }
        }
    }

    private func analysisLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fmt(_ v: Double) -> String {
        if abs(v) < 5e-7 { return "0" }
        return String(format: "%.4g", v)
    }

    private func equationRow(_ eq: Binding<GraphingViewModel.Equation>) -> some View {
        HStack(spacing: 6) {
            Button {
                graph.toggleVisibility(id: eq.wrappedValue.id)
            } label: {
                Circle()
                    .fill(eq.wrappedValue.isVisible ? eq.wrappedValue.color : Color.secondary.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .help(eq.wrappedValue.isVisible ? "隐藏" : "显示")

            HStack(spacing: 2) {
                Text("y=")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                TextField("表达式", text: Binding(
                    get: { eq.wrappedValue.text },
                    set: { graph.updateEquation(id: eq.wrappedValue.id, text: $0) }))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(eq.wrappedValue.hasError ? Color.red : Color.primary)
            }

            Button {
                graph.removeEquation(id: eq.wrappedValue.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("删除")
            .accessibilityLabel("删除函数")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private var viewControls: some View {
        HStack(spacing: 8) {
            Button { graph.zoom(factor: 0.8) } label: { Image(systemName: "plus.magnifyingglass") }
                .help("放大").accessibilityLabel("放大")
            Button { graph.zoom(factor: 1.25) } label: { Image(systemName: "minus.magnifyingglass") }
                .help("缩小").accessibilityLabel("缩小")
            Button { graph.resetView() } label: { Image(systemName: "scope") }
                .help("重置视图").accessibilityLabel("重置视图")
            Spacer()
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// 自研图形渲染器：网格 + 坐标轴 + 逐像素列自适应采样曲线 + 间断检测。
private struct GraphCanvas: View {
    @ObservedObject var graph: GraphingViewModel

    @State private var dragAccum: CGSize = .zero
    @GestureState private var magnify: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Canvas { context, canvasSize in
                drawGrid(context: context, size: canvasSize)
                drawAxes(context: context, size: canvasSize)
                for eq in graph.equations where eq.isVisible {
                    if let expr = eq.compiled {
                        drawCurve(expr, color: eq.color, context: context, size: canvasSize)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .contentShape(Rectangle())
            .gesture(dragGesture(size: size))
            .gesture(magnifyGesture)
        }
    }

    // MARK: - 手势

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let dx = value.translation.width - dragAccum.width
                let dy = value.translation.height - dragAccum.height
                dragAccum = value.translation
                let mathDx = Double(dx) / Double(size.width) * graph.xSpan
                // 屏幕 y 向下，数学 y 向上：正的屏幕位移对应数学 y 增加。
                let mathDy = Double(dy) / Double(size.height) * graph.ySpan
                graph.pan(dxMath: mathDx, dyMath: -mathDy)
            }
            .onEnded { _ in dragAccum = .zero }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .updating($magnify) { current, state, _ in
                let delta = current / state
                state = current
                graph.zoom(factor: 1 / Double(delta))
            }
    }

    // MARK: - 坐标映射

    private func toScreenX(_ x: Double, _ size: CGSize) -> CGFloat {
        CGFloat((x - graph.xMin) / graph.xSpan) * size.width
    }

    private func toScreenY(_ y: Double, _ size: CGSize) -> CGFloat {
        // 数学 y 向上翻转到屏幕 y 向下。
        size.height - CGFloat((y - graph.yMin) / graph.ySpan) * size.height
    }

    // MARK: - 绘制

    private func niceStep(_ span: Double, target: Int) -> Double {
        let rough = span / Double(target)
        let mag = pow(10, floor(log10(rough)))
        let norm = rough / mag
        let step: Double
        if norm < 1.5 { step = 1 } else if norm < 3 { step = 2 } else if norm < 7 { step = 5 } else { step = 10 }
        return step * mag
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let stepX = niceStep(graph.xSpan, target: 10)
        let stepY = niceStep(graph.ySpan, target: 10)
        let gridColor = Color.secondary.opacity(0.15)

        var x = (graph.xMin / stepX).rounded(.up) * stepX
        while x <= graph.xMax {
            let sx = toScreenX(x, size)
            var path = Path()
            path.move(to: CGPoint(x: sx, y: 0))
            path.addLine(to: CGPoint(x: sx, y: size.height))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
            x += stepX
        }

        var y = (graph.yMin / stepY).rounded(.up) * stepY
        while y <= graph.yMax {
            let sy = toScreenY(y, size)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: sy))
            path.addLine(to: CGPoint(x: size.width, y: sy))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
            y += stepY
        }
    }

    private func drawAxes(context: GraphicsContext, size: CGSize) {
        let axisColor = Color.secondary.opacity(0.6)
        // Y 轴（x=0）
        if graph.xMin <= 0 && graph.xMax >= 0 {
            let sx = toScreenX(0, size)
            var path = Path()
            path.move(to: CGPoint(x: sx, y: 0))
            path.addLine(to: CGPoint(x: sx, y: size.height))
            context.stroke(path, with: .color(axisColor), lineWidth: 1)
        }
        // X 轴（y=0）
        if graph.yMin <= 0 && graph.yMax >= 0 {
            let sy = toScreenY(0, size)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: sy))
            path.addLine(to: CGPoint(x: size.width, y: sy))
            context.stroke(path, with: .color(axisColor), lineWidth: 1)
        }
    }

    private func drawCurve(_ expr: GraphExpression, color: Color, context: GraphicsContext, size: CGSize) {
        guard size.width > 1 else { return }
        var path = Path()
        var penDown = false
        var lastScreenY: CGFloat = 0
        // 间断阈值：单像素列 y 跳变超过画布高度视为断裂（垂直渐近线等）。
        let jumpThreshold = size.height * 1.5

        let columns = Int(size.width)
        for column in 0...columns {
            let sx = CGFloat(column)
            let mathX = graph.xMin + Double(sx) / Double(size.width) * graph.xSpan
            guard let mathY = expr.evaluate(x: mathX) else {
                penDown = false
                continue
            }
            let sy = toScreenY(mathY, size)

            if penDown && abs(sy - lastScreenY) > jumpThreshold {
                penDown = false // 断裂
            }

            if penDown {
                path.addLine(to: CGPoint(x: sx, y: sy))
            } else {
                path.move(to: CGPoint(x: sx, y: sy))
                penDown = true
            }
            lastScreenY = sy
        }

        context.stroke(path, with: .color(color), lineWidth: 1.8)
    }
}
