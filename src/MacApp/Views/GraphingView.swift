// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 排版对照 Views/GraphingCalculator/GraphingCalculator.xaml：
//   左侧图形画布（2* 宽，自研渲染器）＋ 右侧方程输入区（1* 宽）。
//   顶栏与其它模式共用 CalculatorHeader。
// 渲染器为自研：SwiftUI Canvas(CoreGraphics) 逐像素列自适应采样 +
// 间断点检测 + 网格/坐标轴；平移用拖拽、缩放用捏合与按钮。
// 图形设置（GraphingSettings.xaml）：范围四框 / 三角单位 / 线宽 / 重置。
// 方程样式（EquationStylePanelControl.xaml)：14 色 + 实线/虚线/点线。

import AppKit
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
                        EquationRow(graph: graph, eq: $eq)
                    }
                }
                .padding(10)
            }

            if !graph.parameterNames.isEmpty {
                Divider()
                sliderSection
            }

            if showAnalysis {
                Divider()
                analysisSection
            }
        }
    }

    // MARK: - 变量滑块（表达式中的参数 a、b、k…，可编辑 Min/Max/Step）

    private var sliderSection: some View {
        VStack(spacing: 4) {
            ForEach(graph.parameterNames, id: \.self) { name in
                VariableSliderRow(graph: graph, name: name)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - 函数分析（Giac 符号：零点/极值/拐点/渐近线/奇偶性/定义域）

    private var analysisSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(graph.equations) { eq in
                    if eq.isVisible, let expr = eq.explicitExpression {
                        GiacAnalysisRow(eq: eq, expr: expr, params: graph.parameters, trig: graph.trigMode)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 180)
    }
}

// MARK: - 方程行（可见性圆点=样式入口 + MathLive 输入 + 删除）

private struct EquationRow: View {
    @ObservedObject var graph: GraphingViewModel
    @Binding var eq: GraphingViewModel.Equation
    @Environment(\.colorScheme) private var colorScheme

    @State private var stylePanelShown = false

    private var color: Color {
        GraphingViewModel.equationColor(index: eq.colorIndex, darkMode: colorScheme == .dark)
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                stylePanelShown.toggle()
            } label: {
                Circle()
                    .fill(eq.isVisible ? color : Color.secondary.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .help("线条样式")
            .accessibilityLabel("线条样式")
            .popover(isPresented: $stylePanelShown, arrowEdge: .bottom) {
                EquationStylePanel(graph: graph, eq: eq)
            }

            HStack(spacing: 2) {
                Text("ƒ")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                MathInputField(
                    initialLatex: eq.latex.isEmpty ? eq.text : eq.latex,
                    onChange: { ascii, latex in
                        graph.updateEquation(id: eq.id, ascii: ascii, latex: latex)
                    },
                    onSubmit: {
                        // 原版 Enter 提交（plotButton）：末行非空时补一个空输入行。
                        if graph.equations.last?.id == eq.id,
                           !eq.text.trimmingCharacters(in: .whitespaces).isEmpty {
                            graph.addEquation()
                        }
                    }
                )
                .frame(height: 32)
                if eq.hasError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .help("表达式无法解析")
                }
            }

            Button {
                graph.toggleVisibility(id: eq.id)
            } label: {
                Image(systemName: eq.isVisible ? "eye" : "eye.slash")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(eq.isVisible ? "隐藏" : "显示")
            .accessibilityLabel(eq.isVisible ? "隐藏函数" : "显示函数")

            Button {
                graph.removeEquation(id: eq.id)
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
}

// MARK: - 方程样式面板（EquationStylePanelControl：14 色 + 线型）

private struct EquationStylePanel: View {
    @ObservedObject var graph: GraphingViewModel
    let eq: GraphingViewModel.Equation
    @Environment(\.colorScheme) private var colorScheme

    private var palette: [Color] {
        colorScheme == .dark ? GraphingViewModel.darkPalette : GraphingViewModel.lightPalette
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("线条颜色")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<palette.count, id: \.self) { index in
                    Button {
                        graph.setColorIndex(id: eq.id, index)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(palette[index])
                                .frame(width: 20, height: 20)
                            if index == eq.colorIndex {
                                Circle()
                                    .strokeBorder(Color.accentColor, lineWidth: 2)
                                    .frame(width: 26, height: 26)
                            }
                        }
                        .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("颜色 \(index + 1)")
                }
            }

            Text("线条样式")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(EquationLineStyle.allCases, id: \.self) { style in
                    Button {
                        graph.setLineStyle(id: eq.id, style)
                    } label: {
                        LineStyleSample(style: style)
                            .frame(width: 48, height: 18)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(style == eq.lineStyle ? Color.accentColor : Color.secondary.opacity(0.3),
                                                  lineWidth: style == eq.lineStyle ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(styleName(style))
                    .help(styleName(style))
                }
            }
        }
        .padding(12)
    }

    private func styleName(_ style: EquationLineStyle) -> String {
        switch style {
        case .solid: return "实线"
        case .dash: return "虚线"
        case .dot: return "点线"
        }
    }
}

/// 线型示意小样。
private struct LineStyleSample: View {
    let style: EquationLineStyle

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 4, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width - 4, y: size.height / 2))
            context.stroke(
                path,
                with: .color(.primary),
                style: StrokeStyle(lineWidth: 2, dash: style.dashPattern(lineWidth: 2)))
        }
    }
}

// MARK: - 变量滑块行（值滑块 + ± 步进 + Min/Max/Step 编辑）

private struct VariableSliderRow: View {
    @ObservedObject var graph: GraphingViewModel
    let name: String

    @State private var editorShown = false
    @State private var minText = ""
    @State private var maxText = ""
    @State private var stepText = ""

    private var variable: GraphingViewModel.SliderVariable {
        graph.variables[name] ?? .init()
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("\(name) = \(fmt(variable.value))")
                .font(.system(size: 10, design: .monospaced))
                .frame(width: 64, alignment: .leading)
            Button { graph.stepVariable(name, direction: -1) } label: {
                Image(systemName: "minus.circle").font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .help("减一步")
            .accessibilityLabel("参数 \(name) 减一步")
            Slider(value: Binding(
                get: { variable.value },
                set: { graph.setVariableValue(name, $0) }), in: variable.min...variable.max)
                .controlSize(.mini)
                .accessibilityLabel("参数 \(name)")
            Button { graph.stepVariable(name, direction: 1) } label: {
                Image(systemName: "plus.circle").font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .help("加一步")
            .accessibilityLabel("参数 \(name) 加一步")
            Button {
                minText = fmt(variable.min)
                maxText = fmt(variable.max)
                stepText = fmt(variable.step)
                editorShown.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .help("范围与步长")
            .accessibilityLabel("参数 \(name) 范围与步长")
            .popover(isPresented: $editorShown, arrowEdge: .bottom) {
                editor
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("参数 \(name)")
                .font(.system(size: 11, weight: .semibold))
            HStack(spacing: 6) {
                field("最小", $minText)
                field("最大", $maxText)
                field("步长", $stepText)
            }
            Button("应用") {
                if let v = Double(minText) { graph.setVariableMin(name, v) }
                if let v = Double(maxText) { graph.setVariableMax(name, v) }
                if let v = Double(stepText) { graph.setVariableStep(name, v) }
                editorShown = false
            }
            .controlSize(.small)
        }
        .padding(12)
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .frame(width: 56)
        }
    }

    private func fmt(_ v: Double) -> String {
        if abs(v) < 5e-7 { return "0" }
        return String(format: "%.4g", v)
    }
}

// MARK: - 图形设置面板（GraphingSettings.xaml：范围/三角单位/线宽/重置）

private struct GraphingSettingsPanel: View {
    @ObservedObject var graph: GraphingViewModel

    @State private var xMinText = ""
    @State private var xMaxText = ""
    @State private var yMinText = ""
    @State private var yMaxText = ""
    @State private var rangeError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("图形选项")
                .font(.system(size: 13, weight: .semibold))

            Text("网格范围")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Grid(horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    rangeField("X 最小值", $xMinText)
                    rangeField("X 最大值", $xMaxText)
                }
                GridRow {
                    rangeField("Y 最小值", $yMinText)
                    rangeField("Y 最大值", $yMaxText)
                }
            }
            if rangeError {
                Text("最小值必须小于最大值")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }

            Button("重置视图") {
                graph.resetView()
                loadRange()
            }
            .controlSize(.small)

            Divider()

            Text("单位")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Picker("三角单位", selection: $graph.trigMode) {
                Text("弧度").tag(GraphTrigMode.radians)
                Text("角度").tag(GraphTrigMode.degrees)
                Text("梯度").tag(GraphTrigMode.gradians)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider()

            Text("线条粗细")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Picker("线条粗细", selection: $graph.lineWidth) {
                ForEach([1.0, 2.0, 3.0, 4.0], id: \.self) { width in
                    LineWidthSample(width: width)
                        .frame(width: 120, height: 14)
                        .tag(width)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
        .padding(14)
        .frame(width: 240)
        .onAppear(perform: loadRange)
        .onSubmit(applyRange)
    }

    private func rangeField(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            TextField("", text: text, onEditingChanged: { began in
                if !began { applyRange() }
            })
            .textFieldStyle(.roundedBorder)
            .controlSize(.small)
        }
    }

    private func loadRange() {
        xMinText = fmt(graph.xMin)
        xMaxText = fmt(graph.xMax)
        yMinText = fmt(graph.yMin)
        yMaxText = fmt(graph.yMax)
        rangeError = false
    }

    private func applyRange() {
        guard let x0 = Double(xMinText), let x1 = Double(xMaxText),
              let y0 = Double(yMinText), let y1 = Double(yMaxText) else {
            rangeError = true
            return
        }
        rangeError = !graph.applyRange(xMin: x0, xMax: x1, yMin: y0, yMax: y1)
    }

    private func fmt(_ v: Double) -> String {
        if v == v.rounded(), abs(v) < 1e15 { return String(Int64(v)) }
        return String(format: "%.6g", v)
    }
}

/// 线宽示意小样（对应原版 ComboBox 内的 Line 预览）。
private struct LineWidthSample: View {
    let width: Double

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.stroke(path, with: .color(.primary), lineWidth: width)
        }
    }
}

/// 单条方程的 Giac 符号分析行：后台求解，方程或滑块参数变化时自动刷新。
private struct GiacAnalysisRow: View {
    let eq: GraphingViewModel.Equation
    let expr: GraphExpression
    let params: [String: Double]
    let trig: GraphTrigMode
    @Environment(\.colorScheme) private var colorScheme

    @State private var analysis: GiacFunctionAnalysis?

    private var taskKey: String {
        eq.text + "|" + trig.rawValue + "|"
            + params.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
    }

    private var color: Color {
        GraphingViewModel.equationColor(index: eq.colorIndex, darkMode: colorScheme == .dark)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(eq.text)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }
            if let a = analysis {
                if a.isEmpty {
                    Text("无可报告特征")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    if let d = a.domain { line("定义域", d) }
                    if let r = a.range { line("值域", r) }
                    if a.parity == .even { line("奇偶性", "偶函数") }
                    if a.parity == .odd { line("奇偶性", "奇函数") }
                    if let p = a.periodicity { line("周期性", p) }
                    if let y0 = a.yIntercept { line("y 截距", "(0, \(y0))") }
                    if !a.zeros.isEmpty { line("零点", a.zeros.prefix(6).joined(separator: ", ")) }
                    if !a.maxima.isEmpty { line("极大值", a.maxima.prefix(4).map { "(\($0.x), \($0.y))" }.joined(separator: " ")) }
                    if !a.minima.isEmpty { line("极小值", a.minima.prefix(4).map { "(\($0.x), \($0.y))" }.joined(separator: " ")) }
                    if !a.inflectionPoints.isEmpty { line("拐点", a.inflectionPoints.prefix(4).map { "(\($0.x), \($0.y))" }.joined(separator: " ")) }
                    if !a.monotonicity.isEmpty {
                        line("单调性", a.monotonicity.prefix(5).map { "\($0.interval) \($0.direction)" }.joined(separator: "; "))
                    }
                    if !a.verticalAsymptotes.isEmpty { line("垂直渐近线", a.verticalAsymptotes.prefix(4).joined(separator: ", ")) }
                    if !a.horizontalAsymptotes.isEmpty { line("水平渐近线", a.horizontalAsymptotes.prefix(2).joined(separator: ", ")) }
                    if !a.obliqueAsymptotes.isEmpty { line("斜渐近线", a.obliqueAsymptotes.prefix(2).joined(separator: ", ")) }
                    if !a.tooComplexFeatures.isEmpty {
                        Text("因太复杂而无法计算：\(a.tooComplexFeatures.joined(separator: "、"))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("分析中…")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: taskKey) {
            let expr = expr
            let params = params
            let trig = trig
            analysis = await Task.detached(priority: .utility) {
                GiacMathSolver.analyze(expr, params: params, trig: trig)
            }.value
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 自研图形渲染器：网格 + 坐标轴 + 逐像素列自适应采样曲线 + 间断检测 +
/// 跟踪光标（ActiveTracing）与右上角命令面板（对照 GraphControlCommandPanel）。
private struct GraphCanvas: View {
    @ObservedObject var graph: GraphingViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var dragAccum: CGSize = .zero
    @GestureState private var magnify: CGFloat = 1

    /// 跟踪光标（屏幕坐标）；nil = 尚未定位。
    @State private var traceCursor: CGPoint?
    @FocusState private var canvasFocused: Bool
    @State private var settingsShown = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topTrailing) {
                Canvas { context, canvasSize in
                    drawGrid(context: context, size: canvasSize)
                    drawAxes(context: context, size: canvasSize)
                    for eq in graph.equations where eq.isVisible {
                        let color = GraphingViewModel.equationColor(index: eq.colorIndex, darkMode: colorScheme == .dark)
                        let stroke = StrokeStyle(
                            lineWidth: graph.lineWidth,
                            dash: eq.lineStyle.dashPattern(lineWidth: graph.lineWidth))
                        switch eq.compiled {
                        case .explicitFn(let expr):
                            drawCurve(expr, color: color, stroke: stroke, context: context, size: canvasSize)
                        case .implicitEq(let expr):
                            drawImplicit(expr, color: color, stroke: stroke, context: context, size: canvasSize)
                        case .inequality(let expr, let relation):
                            drawInequality(expr, relation: relation, color: color, stroke: stroke, context: context, size: canvasSize)
                        case nil:
                            break
                        }
                    }
                    if graph.isTracing, let cursor = traceCursor {
                        drawTrace(cursor: cursor, context: context, size: canvasSize)
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
                .contentShape(Rectangle())
                .gesture(dragGesture(size: size))
                .gesture(magnifyGesture)
                .onContinuousHover { phase in
                    guard graph.isTracing else { return }
                    if case .active(let location) = phase {
                        traceCursor = location
                    }
                }
                .focusable(graph.isTracing)
                .focused($canvasFocused)
                .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow], phases: [.down, .repeat]) { press in
                    moveTraceCursor(press, size: size)
                }
                .contextMenu {
                    Button("复制图形") { copyGraphImage(size: size) }
                }

                commandPanel(size: size)
            }
        }
    }

    // MARK: - 命令面板（跟踪/放大/缩小/图形视图）

    private func commandPanel(size: CGSize) -> some View {
        HStack(spacing: 2) {
            Button {
                graph.isTracing.toggle()
                if graph.isTracing {
                    // 原版：跟踪光标初始在画布中心偏移 (＋40, −40)。
                    traceCursor = CGPoint(x: size.width / 2 + 40, y: size.height / 2 - 40)
                    canvasFocused = true
                } else {
                    traceCursor = nil
                }
            } label: {
                Image(systemName: "scope")
                    .foregroundStyle(graph.isTracing ? Color.accentColor : Color.primary)
            }
            .help(graph.isTracing ? "停止跟踪" : "开始跟踪")
            .accessibilityLabel(graph.isTracing ? "停止跟踪" : "开始跟踪")

            Button {
                share(size: size)
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .help("分享")
            .accessibilityLabel("分享")

            Button { settingsShown.toggle() } label: { Image(systemName: "gearshape") }
                .help("图形选项")
                .accessibilityLabel("图形选项")
                .popover(isPresented: $settingsShown, arrowEdge: .bottom) {
                    GraphingSettingsPanel(graph: graph)
                }

            Button { graph.zoom(factor: 0.8) } label: { Image(systemName: "plus.magnifyingglass") }
                .help("放大 (⌃+)").accessibilityLabel("放大")
                .keyboardShortcut("=", modifiers: .control)
            Button { graph.zoom(factor: 1.25) } label: { Image(systemName: "minus.magnifyingglass") }
                .help("缩小 (⌃-)").accessibilityLabel("缩小")
                .keyboardShortcut("-", modifiers: .control)

            Button {
                graph.autoFitView()
            } label: {
                Image(systemName: graph.isManualAdjustment ? "arrow.up.left.and.arrow.down.right" : "sparkle.magnifyingglass")
            }
            .help("自动刷新视图 (⌃0)")
            .accessibilityLabel("图形视图")
            .keyboardShortcut("0", modifiers: .control)
            .background(
                // 原版 Ctrl+Home 和弦同样触发 graphViewButton。
                Button("") { graph.autoFitView() }
                    .keyboardShortcut(.home, modifiers: .control)
                    .opacity(0)
                    .frame(width: 0, height: 0)
            )
        }
        .buttonStyle(.borderless)
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(8)
    }

    /// 方向键移动跟踪光标：5pt / 按住 ⇧ 1pt（原版 delta 5 / accelerator 1）。
    private func moveTraceCursor(_ press: KeyPress, size: CGSize) -> KeyPress.Result {
        guard graph.isTracing, var cursor = traceCursor else { return .ignored }
        let delta: CGFloat = press.modifiers.contains(.shift) ? 1 : 5
        switch press.key {
        case .leftArrow: cursor.x = max(0, cursor.x - delta)
        case .rightArrow: cursor.x = min(size.width, cursor.x + delta)
        case .upArrow: cursor.y = max(0, cursor.y - delta)
        case .downArrow: cursor.y = min(size.height, cursor.y + delta)
        default: return .ignored
        }
        traceCursor = cursor
        return .handled
    }

    // MARK: - 分享/导出（原版 Share contract：图 + 方程列表）

    /// 把当前画布渲染为位图（2x 缩放）。
    @MainActor
    private func renderImage(size: CGSize) -> NSImage? {
        guard size.width > 1, size.height > 1 else { return nil }
        let content = Canvas { context, canvasSize in
            drawGrid(context: context, size: canvasSize)
            drawAxes(context: context, size: canvasSize)
            for eq in graph.equations where eq.isVisible {
                let color = GraphingViewModel.equationColor(index: eq.colorIndex, darkMode: colorScheme == .dark)
                let stroke = StrokeStyle(
                    lineWidth: graph.lineWidth,
                    dash: eq.lineStyle.dashPattern(lineWidth: graph.lineWidth))
                switch eq.compiled {
                case .explicitFn(let expr):
                    drawCurve(expr, color: color, stroke: stroke, context: context, size: canvasSize)
                case .implicitEq(let expr):
                    drawImplicit(expr, color: color, stroke: stroke, context: context, size: canvasSize)
                case .inequality(let expr, let relation):
                    drawInequality(expr, relation: relation, color: color, stroke: stroke, context: context, size: canvasSize)
                case nil:
                    break
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color(nsColor: .textBackgroundColor))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        return renderer.nsImage
    }

    /// 方程列表文本（分享附带，对应原版 Share 的方程清单）。
    private var equationListText: String {
        graph.equations
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { eq in
                eq.text.contains(where: { "=<>≤≥".contains($0) }) ? eq.text : "y=\(eq.text)"
            }
            .joined(separator: "\n")
    }

    @MainActor
    private func share(size: CGSize) {
        var items: [Any] = []
        if let image = renderImage(size: size) {
            items.append(image)
        }
        if !equationListText.isEmpty {
            items.append(equationListText)
        }
        guard !items.isEmpty, let view = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: items)
        let anchor = NSRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        picker.show(relativeTo: anchor, of: view, preferredEdge: .minY)
    }

    /// 右键菜单：复制图形位图到剪贴板（原版 ContextFlyout）。
    @MainActor
    private func copyGraphImage(size: CGSize) {
        guard let image = renderImage(size: size) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    // MARK: - 跟踪绘制（光标十字 + 吸附点 + 坐标浮层）

    private func drawTrace(cursor: CGPoint, context: GraphicsContext, size: CGSize) {
        // 十字光标。
        var cross = Path()
        cross.move(to: CGPoint(x: cursor.x - 7, y: cursor.y))
        cross.addLine(to: CGPoint(x: cursor.x + 7, y: cursor.y))
        cross.move(to: CGPoint(x: cursor.x, y: cursor.y - 7))
        cross.addLine(to: CGPoint(x: cursor.x, y: cursor.y + 7))
        context.stroke(cross, with: .color(.secondary), lineWidth: 1)

        // 吸附最近曲线点。
        let mathX = graph.xMin + Double(cursor.x) / Double(size.width) * graph.xSpan
        let mathY = graph.yMin + Double(size.height - cursor.y) / Double(size.height) * graph.ySpan
        guard let snap = graph.nearestCurvePoint(mathX: mathX, mathY: mathY) else { return }

        let sx = toScreenX(snap.x, size)
        let sy = toScreenY(snap.y, size)
        guard sy >= -20, sy <= size.height + 20 else { return }

        let color = GraphingViewModel.equationColor(
            index: graph.equations[snap.equationIndex].colorIndex, darkMode: colorScheme == .dark)
        context.fill(
            Path(ellipseIn: CGRect(x: sx - 4, y: sy - 4, width: 8, height: 8)),
            with: .color(color))

        // 坐标浮层（TraceValuePopup：右侧越界则翻到左侧）。
        let label = Text("(\(traceFmt(snap.x)), \(traceFmt(snap.y)))")
            .font(.system(size: 11, design: .monospaced))
        let resolved = context.resolve(label)
        let textSize = resolved.measure(in: CGSize(width: 300, height: 40))
        var px = sx + 15
        if px + textSize.width + 8 > size.width { px = sx - 15 - textSize.width - 8 }
        var py = sy - 30
        if py < 0 { py = sy + 10 }
        let rect = CGRect(x: px, y: py, width: textSize.width + 8, height: textSize.height + 4)
        context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(Color(nsColor: .windowBackgroundColor).opacity(0.92)))
        context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(.secondary.opacity(0.4)), lineWidth: 0.5)
        context.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY))
    }

    private func traceFmt(_ v: Double) -> String {
        if abs(v) < 5e-10 { return "0" }
        return String(format: "%.6g", v)
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

    private func drawCurve(_ expr: GraphExpression, color: Color, stroke: StrokeStyle, context: GraphicsContext, size: CGSize) {
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
            guard let mathY = expr.evaluate(x: mathX, params: graph.parameters, trig: graph.trigMode) else {
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

        context.stroke(path, with: .color(color), style: stroke)
    }

    /// 隐式方程 F(x,y)=0：marching squares 等值线（约 3px 网格）。
    private func drawImplicit(_ expr: GraphExpression, color: Color, stroke: StrokeStyle, context: GraphicsContext, size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let cellPx = 3.0
        let cols = max(8, Int(size.width / cellPx))
        let rows = max(8, Int(size.height / cellPx))

        let segments = MarchingSquares.trace(
            f: { expr.evaluate(x: $0, y: $1, params: graph.parameters, trig: graph.trigMode) },
            xMin: graph.xMin, xMax: graph.xMax, yMin: graph.yMin, yMax: graph.yMax,
            cols: cols, rows: rows)

        var path = Path()
        for seg in segments {
            path.move(to: CGPoint(x: toScreenX(seg.x1, size), y: toScreenY(seg.y1, size)))
            path.addLine(to: CGPoint(x: toScreenX(seg.x2, size), y: toScreenY(seg.y2, size)))
        }
        context.stroke(path, with: .color(color), style: stroke)
    }

    /// 不等式 F(x,y) rel 0：满足区域半透明着色 + F=0 边界线
    /// （严格不等式虚线、非严格实线，对应原版图形引擎行为）。
    private func drawInequality(_ expr: GraphExpression, relation: InequalityRelation, color: Color, stroke: StrokeStyle, context: GraphicsContext, size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let cellPx = 4.0
        let cols = max(8, Int(size.width / cellPx))
        let rows = max(8, Int(size.height / cellPx))
        let cellW = size.width / CGFloat(cols)
        let cellH = size.height / CGFloat(rows)

        var fill = Path()
        for row in 0..<rows {
            let sy = (CGFloat(row) + 0.5) * cellH
            let mathY = graph.yMax - Double(sy) / Double(size.height) * graph.ySpan
            var runStart: Int?
            for col in 0...cols {
                var inside = false
                if col < cols {
                    let sx = (CGFloat(col) + 0.5) * cellW
                    let mathX = graph.xMin + Double(sx) / Double(size.width) * graph.xSpan
                    if let f = expr.evaluate(x: mathX, y: mathY, params: graph.parameters, trig: graph.trigMode) {
                        inside = relation.satisfied(f)
                    }
                }
                if inside {
                    if runStart == nil { runStart = col }
                } else if let start = runStart {
                    // 合并同行连续单元为一个矩形，减少路径元素。
                    fill.addRect(CGRect(
                        x: CGFloat(start) * cellW, y: CGFloat(row) * cellH,
                        width: CGFloat(col - start) * cellW, height: cellH))
                    runStart = nil
                }
            }
        }
        context.fill(fill, with: .color(color.opacity(0.2)))

        // 边界 F=0：严格不等式强制虚线。
        let boundaryStroke = relation.isStrict
            ? StrokeStyle(lineWidth: stroke.lineWidth, dash: [2 * stroke.lineWidth, stroke.lineWidth])
            : stroke
        drawImplicit(expr, color: color, stroke: boundaryStroke, context: context, size: size)
    }
}
