// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 排版对照 Views/GraphingCalculator/GraphingCalculator.xaml：
//   左侧图形画布（layoutPriority 2，弹性）＋ 右侧方程输入区（固定 220pt）。
//   顶栏由 ContentView 共享工具栏提供（历史侧栏开关 + 模式菜单）。
// 渲染：SwiftUI Canvas(CoreGraphics) 绘制，几何采样/间断点检测/刻度/坐标变换
// 走共享 C 层 graph_geometry（S7）；平移用拖拽、缩放用捏合与按钮。
// 图形设置（GraphingSettings.xaml）：范围四框 / 三角单位 / 线宽 / 重置。
// 方程样式（EquationStylePanelControl.xaml)：14 色 + 实线/虚线/点线。

import AppKit
import CalcManagerBridge
import SwiftUI

struct GraphingView: View {
    let model: StandardCalculatorViewModel
    @State private var graph = GraphingViewModel()

    @State private var showAnalysis = false

    var body: some View {
        HStack(spacing: 0) {
            GraphCanvas(graph: graph)
                .frame(minWidth: 260)
                .layoutPriority(2)

            Divider()

            equationPanel
                .frame(width: 220)
        }
    }

    // MARK: - 方程输入区

    private var equationPanel: some View {
        @Bindable var graph = graph
        return VStack(spacing: 0) {
            HStack {
                Text(L10n.string("funcButton.Text"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    showAnalysis.toggle()
                } label: {
                    Image(systemName: showAnalysis ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                }
                .buttonStyle(.borderless)
                .help(L10n.string("KeyGraphFeaturesLabel.Text"))
                .accessibilityLabel(L10n.string("KeyGraphFeaturesLabel.Text"))
                Button {
                    graph.addEquation()
                } label: {
                    Image(systemName: AppIcon.graphEquationAdd.sfSymbol)
                }
                .buttonStyle(.borderless)
                .help(L10n.string("Mac_AddFunction"))
                .accessibilityLabel(L10n.string("Mac_AddFunction"))
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
    let graph: GraphingViewModel
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
            .help(L10n.string("Mac_LineStyle"))
            .accessibilityLabel(L10n.string("Mac_LineStyle"))
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
                    Image(systemName: AppIcon.graphEquationError.sfSymbol)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .help(L10n.string("Mac_ExprParseError"))
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
            .help(eq.isVisible ? L10n.string("Mac_Hide") : L10n.string("Mac_Show"))
            .accessibilityLabel(eq.isVisible ? L10n.string("Mac_HideFunction") : L10n.string("Mac_ShowFunction"))

            Button {
                graph.removeEquation(id: eq.id)
            } label: {
                Image(systemName: AppIcon.graphEquationRemove.sfSymbol)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.string("DeleteHistoryMenuItem.Text"))
            .accessibilityLabel(L10n.string("Mac_DeleteFunction"))
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
    let graph: GraphingViewModel
    let eq: GraphingViewModel.Equation
    @Environment(\.colorScheme) private var colorScheme

    private var palette: [Color] {
        colorScheme == .dark ? GraphingViewModel.darkPalette : GraphingViewModel.lightPalette
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("Mac_LineColor"))
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
                    .accessibilityLabel(L10n.format("Mac_ColorN", "\(index + 1)"))
                }
            }

            Text(L10n.string("Mac_LineStyle"))
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
        case .solid: return L10n.string("Mac_LineSolid")
        case .dash: return L10n.string("Mac_LineDash")
        case .dot: return L10n.string("Mac_LineDot")
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
    let graph: GraphingViewModel
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
                Image(systemName: AppIcon.graphParamStepMinus.sfSymbol).font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .help(L10n.string("Mac_StepMinus"))
            .accessibilityLabel(L10n.format("Mac_ParamStepMinus", name))
            Slider(value: Binding(
                get: { variable.value },
                set: { graph.setVariableValue(name, $0) }), in: variable.min...variable.max)
                .controlSize(.mini)
                .accessibilityLabel(L10n.format("Mac_Param", name))
            Button { graph.stepVariable(name, direction: 1) } label: {
                Image(systemName: AppIcon.graphParamStepPlus.sfSymbol).font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .help(L10n.string("Mac_StepPlus"))
            .accessibilityLabel(L10n.format("Mac_ParamStepPlus", name))
            Button {
                minText = fmt(variable.min)
                maxText = fmt(variable.max)
                stepText = fmt(variable.step)
                editorShown.toggle()
            } label: {
                Image(systemName: AppIcon.graphParamRange.sfSymbol).font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .help(L10n.string("Mac_RangeAndStep"))
            .accessibilityLabel(L10n.format("Mac_ParamRangeAndStep", name))
            .popover(isPresented: $editorShown, arrowEdge: .bottom) {
                editor
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.format("Mac_Param", name))
                .font(.system(size: 11, weight: .semibold))
            HStack(spacing: 6) {
                field(L10n.string("Mac_Min"), $minText)
                field(L10n.string("Mac_Max"), $maxText)
                field(L10n.string("Mac_Step"), $stepText)
            }
            Button(L10n.string("Mac_Apply")) {
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
    @Bindable var graph: GraphingViewModel

    @State private var xMinText = ""
    @State private var xMaxText = ""
    @State private var yMinText = ""
    @State private var yMaxText = ""
    @State private var rangeError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("GraphOptionsHeading.Text"))
                .font(.system(size: 13, weight: .semibold))

            Text(L10n.string("Mac_GridRange"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Grid(horizontalSpacing: 8, verticalSpacing: 6) {
                GridRow {
                    rangeField(L10n.string("Mac_XMin"), $xMinText)
                    rangeField(L10n.string("Mac_XMax"), $xMaxText)
                }
                GridRow {
                    rangeField(L10n.string("Mac_YMin"), $yMinText)
                    rangeField(L10n.string("Mac_YMax"), $yMaxText)
                }
            }
            if rangeError {
                Text(L10n.string("Mac_MinLessThanMax"))
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }

            Button(L10n.string("ResetViewButton.Content")) {
                graph.resetView()
                loadRange()
            }
            .controlSize(.small)

            Divider()

            Text(L10n.string("UnitsHeading.Text"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Picker(L10n.string("Mac_TrigUnit"), selection: $graph.trigMode) {
                Text(L10n.string("Mac_Radians")).tag(GraphTrigMode.radians)
                Text(L10n.string("Mac_Degrees")).tag(GraphTrigMode.degrees)
                Text(L10n.string("Mac_Gradians")).tag(GraphTrigMode.gradians)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Divider()

            Text(L10n.string("LineThicknessBoxHeading.Text"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Picker(L10n.string("LineThicknessBoxHeading.Text"), selection: $graph.lineWidth) {
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
                    Text(L10n.string("Mac_NoFeatures"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    if let d = a.domain { line(L10n.string("Domain"), d) }
                    if let r = a.range { line(L10n.string("Range"), r) }
                    if a.parity == .even { line(L10n.string("Parity"), L10n.string("Mac_Even")) }
                    if a.parity == .odd { line(L10n.string("Parity"), L10n.string("Mac_Odd")) }
                    if let p = a.periodicity { line(L10n.string("Periodicity"), p) }
                    if let y0 = a.yIntercept { line(L10n.string("YIntercept"), "(0, \(y0))") }
                    if !a.zeros.isEmpty { line(L10n.string("Mac_Zeros"), a.zeros.prefix(6).joined(separator: ", ")) }
                    if !a.maxima.isEmpty { line(L10n.string("Maxima"), a.maxima.prefix(4).map { "(\($0.x), \($0.y))" }.joined(separator: " ")) }
                    if !a.minima.isEmpty { line(L10n.string("Minima"), a.minima.prefix(4).map { "(\($0.x), \($0.y))" }.joined(separator: " ")) }
                    if !a.inflectionPoints.isEmpty { line(L10n.string("InflectionPoints"), a.inflectionPoints.prefix(4).map { "(\($0.x), \($0.y))" }.joined(separator: " ")) }
                    if !a.monotonicity.isEmpty {
                        line(L10n.string("Monotonicity"), a.monotonicity.prefix(5).map { "\($0.interval) \($0.direction)" }.joined(separator: "; "))
                    }
                    if !a.verticalAsymptotes.isEmpty { line(L10n.string("VerticalAsymptotes"), a.verticalAsymptotes.prefix(4).joined(separator: ", ")) }
                    if !a.horizontalAsymptotes.isEmpty { line(L10n.string("HorizontalAsymptotes"), a.horizontalAsymptotes.prefix(2).joined(separator: ", ")) }
                    if !a.obliqueAsymptotes.isEmpty { line(L10n.string("ObliqueAsymptotes"), a.obliqueAsymptotes.prefix(2).joined(separator: ", ")) }
                    if !a.tooComplexFeatures.isEmpty {
                        Text(L10n.format("Mac_TooComplex", a.tooComplexFeatures.joined(separator: "、")))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(L10n.string("Mac_Analyzing"))
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

/// 图形画布渲染：网格/坐标轴/曲线采样/间断检测走共享 C 层 graph_geometry（S7），
/// Swift 侧负责 Canvas 绘制与交互；跟踪光标（ActiveTracing）与右上角命令面板（对照 GraphControlCommandPanel）。
private struct GraphCanvas: View {
    let graph: GraphingViewModel
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
                // 画布平移手势优先于窗口背景拖拽（P0-2：拖窗曾抢走 DragGesture）；
                // 同层接收滚轮事件做缩放（对齐"像地图一样"的浏览交互）。
                .background(WindowBackgroundDragDisabler(onScroll: { deltaY in
                    graph.zoom(factor: pow(1.0015, -deltaY))
                }))
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
                    let key: ArrowKey
                    switch press.key {
                    case .leftArrow: key = .left
                    case .rightArrow: key = .right
                    case .upArrow: key = .up
                    case .downArrow: key = .down
                    default: return .ignored
                    }
                    return moveTraceCursor(key, fine: press.modifiers.contains(.shift), size: size) ? .handled : .ignored
                }
                .contextMenu {
                    Button(L10n.string("GraphCopyMenuItem.Text")) { copyGraphImage(size: size) }
                }
                .onChange(of: traceCursor) { _, _ in
                    announceTrace(size: size)
                }
                // S13：语义树 → 隐形无障碍元素 overlay（spec/graph-accessibility.json apple 机制）。
                .overlay(alignment: .topLeading) {
                    accessibilityOverlay(size: size)
                }

                commandPanel(size: size)
            }
        }
    }

    /// 对应原版绘图跟踪值播报（GraphTrace）：吸附点坐标随光标移动播报。
    private func announceTrace(size: CGSize) {
        guard graph.isTracing, let cursor = traceCursor else { return }
        let mathX = graph.xMin + Double(cursor.x) / Double(size.width) * graph.xSpan
        let mathY = graph.yMin + Double(size.height - cursor.y) / Double(size.height) * graph.ySpan
        guard let snap = graph.nearestCurvePoint(mathX: mathX, mathY: mathY) else { return }
        AccessibilityAnnouncer.announce(L10n.format("Mac_TracePoint", traceFmt(snap.x), traceFmt(snap.y)), highPriority: false)
    }

    // MARK: - 无障碍语义树（S13）

    private func accessibilityOverlay(size: CGSize) -> some View {
        let root = GraphSemanticTree.build(
            graph: graph, width: size.width, height: size.height, trace: currentTraceSnap(size: size))
        return GraphAccessibilityOverlay(root: root, size: size) { action, stableId in
            switch action {
            case .zoomIn: graph.zoom(factor: 0.8)
            case .zoomOut: graph.zoom(factor: 1.25)
            case .resetView: graph.resetView()
            case .autoFit: graph.autoFitView()
            case .toggleVisibility:
                if let index = Int(stableId.dropFirst("eq:".count)), graph.equations.indices.contains(index) {
                    graph.toggleVisibility(id: graph.equations[index].id)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func currentTraceSnap(size: CGSize) -> GraphingViewModel.TraceResult? {
        guard graph.isTracing, let cursor = traceCursor, size.width > 0, size.height > 0 else { return nil }
        let mathX = graph.xMin + Double(cursor.x) / Double(size.width) * graph.xSpan
        let mathY = graph.yMin + Double(size.height - cursor.y) / Double(size.height) * graph.ySpan
        return graph.nearestCurvePoint(mathX: mathX, mathY: mathY)
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
                Image(systemName: AppIcon.graphTrace.sfSymbol)
                    .foregroundStyle(graph.isTracing ? Color.accentColor : Color.primary)
            }
            .help(graph.isTracing ? L10n.string("disableTracingButtonToolTip") : L10n.string("enableTracingButtonToolTip"))
            .accessibilityLabel(graph.isTracing ? L10n.string("disableTracingButtonToolTip") : L10n.string("enableTracingButtonToolTip"))

            Button {
                share(size: size)
            } label: {
                Image(systemName: AppIcon.graphExport.sfSymbol)
            }
            .help(L10n.button("shareButton"))
            .accessibilityLabel(L10n.button("shareButton"))

            Button { settingsShown.toggle() } label: { Image(systemName: AppIcon.graphSettings.sfSymbol) }
                .help(L10n.string("GraphOptionsHeading.Text"))
                .accessibilityLabel(L10n.string("GraphOptionsHeading.Text"))
                .popover(isPresented: $settingsShown, arrowEdge: .bottom) {
                    GraphingSettingsPanel(graph: graph)
                }

            Button { graph.zoom(factor: 0.8) } label: { Image(systemName: AppIcon.graphZoomIn.sfSymbol) }
                .help(L10n.string("Mac_ZoomIn")).accessibilityLabel(L10n.button("zoomInButton"))
                .keyboardShortcut("=", modifiers: .control)
            Button { graph.zoom(factor: 1.25) } label: { Image(systemName: AppIcon.graphZoomOut.sfSymbol) }
                .help(L10n.string("Mac_ZoomOut")).accessibilityLabel(L10n.button("zoomOutButton"))
                .keyboardShortcut("-", modifiers: .control)

            Button {
                graph.autoFitView()
            } label: {
                Image(systemName: AppIcon.graphZoomReset.sfSymbol)
                    .foregroundStyle(graph.isManualAdjustment ? Color.accentColor : Color.primary)
            }
            .help(graph.isManualAdjustment ? L10n.string("Mac_RestoreAutoFit") : L10n.string("Mac_AutoFitView"))
            .accessibilityLabel(L10n.string("Mac_AutoFitViewLabel"))
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
    @discardableResult
    private func moveTraceCursor(_ key: ArrowKey, fine: Bool, size: CGSize) -> Bool {
        guard graph.isTracing, var cursor = traceCursor else { return false }
        let delta: CGFloat = fine ? 1 : 5
        switch key {
        case .left: cursor.x = max(0, cursor.x - delta)
        case .right: cursor.x = min(size.width, cursor.x + delta)
        case .up: cursor.y = max(0, cursor.y - delta)
        case .down: cursor.y = min(size.height, cursor.y + delta)
        }
        traceCursor = cursor
        return true
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

    /// 由当前视窗与画布尺寸构造共享层视窗结构（C ABI 几何的输入）。
    private func makeViewport(_ size: CGSize) -> graph_viewport_t {
        graph_viewport_t(
            x_min: graph.xMin, x_max: graph.xMax, y_min: graph.yMin, y_max: graph.yMax,
            width: Double(size.width), height: Double(size.height))
    }

    private func toScreenX(_ x: Double, _ size: CGSize) -> CGFloat {
        var vp = makeViewport(size)
        return CGFloat(graph_to_screen_x(&vp, x))
    }

    private func toScreenY(_ y: Double, _ size: CGSize) -> CGFloat {
        var vp = makeViewport(size)
        return CGFloat(graph_to_screen_y(&vp, y))
    }

    // MARK: - 绘制

    private func niceStep(_ span: Double, target: Int) -> Double {
        graph_nice_step(span, Int32(target))
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let stepX = niceStep(graph.xSpan, target: 10)
        let stepY = niceStep(graph.ySpan, target: 10)
        let gridColor = Color.secondary.opacity(0.15)

        var xs = [Double](repeating: 0, count: 512)
        let nx = xs.withUnsafeMutableBufferPointer {
            graph_ticks(graph.xMin, graph.xMax, stepX, $0.baseAddress, $0.count)
        }
        for i in 0..<min(Int(nx), xs.count) {
            let sx = toScreenX(xs[i], size)
            var path = Path()
            path.move(to: CGPoint(x: sx, y: 0))
            path.addLine(to: CGPoint(x: sx, y: size.height))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }

        var ys = [Double](repeating: 0, count: 512)
        let ny = ys.withUnsafeMutableBufferPointer {
            graph_ticks(graph.yMin, graph.yMax, stepY, $0.baseAddress, $0.count)
        }
        for i in 0..<min(Int(ny), ys.count) {
            let sy = toScreenY(ys[i], size)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: sy))
            path.addLine(to: CGPoint(x: size.width, y: sy))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
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
        var vp = makeViewport(size)
        let params = graph.parameters
        let trig = graph.trigMode
        let box = GraphIntervalBox(
            interval: { _, _, _, _ in GraphIntervalResult(lo: 0, hi: 0, domain: .defined) },
            point: nil,
            explicit: { expr.evaluate(x: $0, params: params, trig: trig) })

        let cap = Int(size.width) + 1
        var samples = [graph_sample_t](repeating: graph_sample_t(), count: cap)
        var count = 0
        withExtendedLifetime(box) {
            let ctx = Unmanaged.passUnretained(box).toOpaque()
            count = samples.withUnsafeMutableBufferPointer { buf in
                graph_sample_curve(&vp, graphExplicitThunk, ctx, buf.baseAddress, buf.count)
            }
        }

        var path = Path()
        for i in 0..<min(count, cap) {
            let s = samples[i]
            let pt = CGPoint(x: s.sx, y: s.sy)
            if s.move { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        context.stroke(path, with: .color(color), style: stroke)
    }

    /// 隐式方程 F(x,y)=0：marching squares 等值线 + Tupper 区间补格（S4）。
    /// MS 段保持平滑并沿用线宽/虚线；区间补格只补 MS 因四角同号或角未定义
    /// 而漏画的格（自交点、亚格特征），保证不丢解。
    private func drawImplicit(_ expr: GraphExpression, color: Color, stroke: StrokeStyle, context: GraphicsContext, size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        var vp = graph_viewport_t(
            x_min: graph.xMin, x_max: graph.xMax, y_min: graph.yMin, y_max: graph.yMax,
            width: Double(size.width), height: Double(size.height))
        let params = graph.parameters
        let trig = graph.trigMode
        let box = GraphIntervalBox(
            interval: { expr.evaluateInterval(xLo: $0, xHi: $1, yLo: $2, yHi: $3, params: params, trig: trig) },
            point: { expr.evaluate(x: $0, y: $1, params: params, trig: trig) })

        var pixelPx = 3.0
        var rects = [graph_rect_t](repeating: graph_rect_t(), count: graphCellBudget)
        var count = 0
        withExtendedLifetime(box) {
            let ctx = Unmanaged.passUnretained(box).toOpaque()
            while true {
                count = rects.withUnsafeMutableBufferPointer { buf in
                    graph_implicit_cells(&vp, pixelPx, graphIntervalThunk, ctx,
                                         graphCornerThunk, ctx, buf.baseAddress, graphCellBudget)
                }
                // 超预算：加粗格子重算（保守，只会多涂不会漏画），而非丢矩形。
                if count <= graphCellBudget || pixelPx > Double(max(size.width, size.height)) { break }
                pixelPx *= 2
            }
        }

        // MS 网格与四叉树叶节点逐点对齐（2^k 格），补格抑制判定才成立。
        let cols = Int(graph_pow2_cell_count(Double(size.width), pixelPx))
        let rows = Int(graph_pow2_cell_count(Double(size.height), pixelPx))
        let segCap = max(1, 2 * cols * rows)  // graph_marching_squares 最坏情形
        var segments = [graph_segment_t](repeating: graph_segment_t(), count: segCap)
        var segCount = 0
        withExtendedLifetime(box) {
            let ctx = Unmanaged.passUnretained(box).toOpaque()
            segCount = segments.withUnsafeMutableBufferPointer { buf -> Int in
                Int(graph_marching_squares(
                    graph.xMin, graph.xMax, graph.yMin, graph.yMax,
                    Int32(cols), Int32(rows), graphCornerThunk, ctx,
                    buf.baseAddress, buf.count))
            }
        }

        var path = Path()
        for i in 0..<min(segCount, segCap) {
            let seg = segments[i]
            path.move(to: CGPoint(x: toScreenX(seg.x1, size), y: toScreenY(seg.y1, size)))
            path.addLine(to: CGPoint(x: toScreenX(seg.x2, size), y: toScreenY(seg.y2, size)))
        }
        context.stroke(path, with: .color(color), style: stroke)

        if count > 0 {
            var cells = Path()
            for i in 0..<min(count, graphCellBudget) {
                let r = rects[i]
                cells.addRect(CGRect(x: r.x, y: r.y, width: r.w, height: r.h))
            }
            context.fill(cells, with: .color(color))
        }
    }

    /// 不等式 F(x,y) rel 0：Tupper 三值区域（S4）——「确定成立」按原版 0.2
    /// 透明度着色，「不确定」用更浅的着色显式呈现（M4：近似不冒充精确）；
    /// F=0 边界线严格不等式虚线、非严格实线（原版行为）。
    private func drawInequality(_ expr: GraphExpression, relation: InequalityRelation, color: Color, stroke: StrokeStyle, context: GraphicsContext, size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        var vp = graph_viewport_t(
            x_min: graph.xMin, x_max: graph.xMax, y_min: graph.yMin, y_max: graph.yMax,
            width: Double(size.width), height: Double(size.height))
        let params = graph.parameters
        let trig = graph.trigMode
        let box = GraphIntervalBox(
            interval: { expr.evaluateInterval(xLo: $0, xHi: $1, yLo: $2, yHi: $3, params: params, trig: trig) },
            point: nil)

        let relationC: graph_relation_t
        switch relation {
        case .lessThan: relationC = GRAPH_REL_LESS
        case .lessOrEqual: relationC = GRAPH_REL_LESS_EQUAL
        case .greaterThan: relationC = GRAPH_REL_GREATER
        case .greaterOrEqual: relationC = GRAPH_REL_GREATER_EQUAL
        }

        var pixelPx = 4.0
        var certain = [graph_rect_t](repeating: graph_rect_t(), count: graphCellBudget)
        var uncertain = [graph_rect_t](repeating: graph_rect_t(), count: graphCellBudget)
        var certainCount = 0
        var uncertainCount = 0
        withExtendedLifetime(box) {
            let ctx = Unmanaged.passUnretained(box).toOpaque()
            while true {
                var uncertainTotal = 0
                certainCount = certain.withUnsafeMutableBufferPointer { cBuf in
                    uncertain.withUnsafeMutableBufferPointer { uBuf in
                        graph_inequality_regions(
                            &vp, pixelPx, relationC, graphIntervalThunk, ctx,
                            cBuf.baseAddress, graphCellBudget,
                            uBuf.baseAddress, graphCellBudget, &uncertainTotal)
                    }
                }
                uncertainCount = uncertainTotal
                if (certainCount <= graphCellBudget && uncertainCount <= graphCellBudget)
                    || pixelPx > Double(max(size.width, size.height)) { break }
                pixelPx *= 2
            }
        }

        var certainPath = Path()
        for i in 0..<min(certainCount, graphCellBudget) {
            let r = certain[i]
            certainPath.addRect(CGRect(x: r.x, y: r.y, width: r.w, height: r.h))
        }
        context.fill(certainPath, with: .color(color.opacity(0.2)))

        if uncertainCount > 0 {
            var uncertainPath = Path()
            for i in 0..<min(uncertainCount, graphCellBudget) {
                let r = uncertain[i]
                uncertainPath.addRect(CGRect(x: r.x, y: r.y, width: r.w, height: r.h))
            }
            context.fill(uncertainPath, with: .color(color.opacity(0.08)))
        }

        // 边界 F=0：严格不等式强制虚线。
        let boundaryStroke = relation.isStrict
            ? StrokeStyle(lineWidth: stroke.lineWidth, dash: [2 * stroke.lineWidth, stroke.lineWidth])
            : stroke
        drawImplicit(expr, color: color, stroke: boundaryStroke, context: context, size: size)
    }
}

// MARK: - S4 区间求值 ↔ C 回调桥接

/// 把 Swift 闭包穿过 C void* 上下文的载体（与 GraphGeometryCApiTests 同模式）。
private final class GraphIntervalBox {
    let interval: (Double, Double, Double, Double) -> GraphIntervalResult
    let point: ((Double, Double) -> Double?)?
    let explicit: ((Double) -> Double?)?

    init(interval: @escaping (Double, Double, Double, Double) -> GraphIntervalResult,
         point: ((Double, Double) -> Double?)?,
         explicit: ((Double) -> Double?)? = nil) {
        self.interval = interval
        self.point = point
        self.explicit = explicit
    }
}

/// 显式曲线 y=f(x) 的 C 回调（graph_eval_fn）：穿过 void* 上下文求值，
/// 未定义返回 false（out_y 被忽略）。供 graph_sample_curve 逐列采样使用。
private let graphExplicitThunk: @convention(c) (
    UnsafeMutableRawPointer?, Double, UnsafeMutablePointer<Double>?
) -> Bool = { ctx, x, out in
    let box = Unmanaged<GraphIntervalBox>.fromOpaque(ctx!).takeUnretainedValue()
    guard let y = box.explicit?(x) else { return false }
    out!.pointee = y
    return true
}

/// 单帧最多接收的矩形数；超出则加粗 pixel_px 重算（保守方向）。
private let graphCellBudget = 1 << 16

private let graphIntervalThunk: @convention(c) (
    UnsafeMutableRawPointer?, Double, Double, Double, Double,
    UnsafeMutablePointer<Double>?, UnsafeMutablePointer<Double>?
) -> graph_box_domain_t = { ctx, xLo, xHi, yLo, yHi, outLo, outHi in
    let box = Unmanaged<GraphIntervalBox>.fromOpaque(ctx!).takeUnretainedValue()
    let r = box.interval(xLo, xHi, yLo, yHi)
    outLo!.pointee = r.lo
    outHi!.pointee = r.hi
    switch r.domain {
    case .nowhereDefined: return GRAPH_BOX_NOWHERE_DEFINED
    case .defined: return GRAPH_BOX_DEFINED
    case .maybeDefined: return GRAPH_BOX_MAYBE_DEFINED
    }
}

private let graphCornerThunk: @convention(c) (
    UnsafeMutableRawPointer?, Double, Double, UnsafeMutablePointer<Double>?
) -> Bool = { ctx, x, y, out in
    let box = Unmanaged<GraphIntervalBox>.fromOpaque(ctx!).takeUnretainedValue()
    guard let f = box.point?(x, y) else { return false }
    out!.pointee = f
    return true
}

/// S13 无障碍 overlay：语义树先序展开为定位的隐形元素（spec traversalOrder），
/// 不拦截指针事件；actions 映射为 VoiceOver 自定义动作。
private struct GraphAccessibilityOverlay: View {
    let root: GraphSemanticNode
    let size: CGSize
    let onAction: (GraphSemanticAction, String) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(root.flattened(), id: \.stableId) { node in
                element(node)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func element(_ node: GraphSemanticNode) -> some View {
        let rect = node.bounds ?? CGRect(origin: .zero, size: size)
        var view = AnyView(
            Color.clear
                .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                .offset(x: rect.minX, y: rect.minY)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(node.resolvedLabel)
                .accessibilityValue(node.value ?? ""))
        if node.states.contains(.selected) {
            view = AnyView(view.accessibilityAddTraits(.isSelected))
        }
        for action in node.actions {
            view = AnyView(view.accessibilityAction(named: actionName(action, node: node)) {
                onAction(action, node.stableId)
            })
        }
        return view
    }

    private func actionName(_ action: GraphSemanticAction, node: GraphSemanticNode) -> String {
        switch action {
        case .zoomIn: return L10n.button("zoomInButton")
        case .zoomOut: return L10n.button("zoomOutButton")
        case .resetView: return L10n.string("Mac_A11y_ResetView")
        case .autoFit: return L10n.string("Mac_AutoFitViewLabel")
        case .toggleVisibility:
            return L10n.string(node.states.contains(.hidden) ? "Mac_ShowFunction" : "Mac_HideFunction")
        }
    }
}
