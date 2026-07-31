// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// S13 自绘绘图区无障碍语义树（spec/graph-accessibility.json 的 macOS 首实现）。
// 语义树驱动绘制：节点由 GraphingViewModel 状态构建，平台把树映射进各自的
// 无障碍机制（macOS overlay / Android 虚拟节点 / Web 语义 DOM / 鸿蒙虚拟节点）。

import Foundation

/// 节点角色（spec roles 词表）。
enum GraphSemanticRole: String, CaseIterable {
    case graphArea, viewport, equationList, equation, featureGroup, tracePoint
}

/// 无障碍自定义动作（spec actions 词表）。
enum GraphSemanticAction: String, CaseIterable {
    case zoomIn, zoomOut, resetView, autoFit, toggleVisibility
}

/// 节点状态（spec states 词表）。
enum GraphSemanticState: String, CaseIterable {
    case visible, hidden, error, selected, tracing
}

/// 语义树节点。label 按 labelKey + labelArgs（%1/%2… 占位）经各平台 l10n 解析。
struct GraphSemanticNode {
    let stableId: String
    let role: GraphSemanticRole
    let labelKey: String
    var labelArgs: [String] = []
    var value: String?
    var states: [GraphSemanticState] = []
    /// 屏幕像素坐标；nil = 占满绘图区（无定位语义）。
    var bounds: CGRect?
    var actions: [GraphSemanticAction] = []
    var children: [GraphSemanticNode] = []

    /// macOS 侧标签解析（L10n.format 的数组参数版）。
    var resolvedLabel: String {
        var result = L10n.string(labelKey)
        for (index, arg) in labelArgs.enumerated() {
            result = result.replacingOccurrences(of: "%\(index + 1)", with: arg)
        }
        return result
    }

    /// 先序遍历（spec traversalOrder：children 数组序即朗读序）。
    func flattened() -> [GraphSemanticNode] {
        [self] + children.flatMap { $0.flattened() }
    }
}

@MainActor
enum GraphSemanticTree {
    /// 由视图模型状态构建语义树。
    /// - trace: 当前跟踪吸附点（nil = 未跟踪或无吸附）。
    /// - analyses: 方程索引 → KGF 分析结果（注入时生成 featureGroup 子节点）。
    static func build(
        graph: GraphingViewModel,
        width: Double,
        height: Double,
        trace: GraphingViewModel.TraceResult? = nil,
        analyses: [Int: GiacFunctionAnalysis] = [:]
    ) -> GraphSemanticNode {
        let g = { (v: Double) in String(format: "%g", v) }

        var viewport = GraphSemanticNode(
            stableId: "viewport",
            role: .viewport,
            labelKey: "Mac_GridRange",
            value: "x ∈ [\(g(graph.xMin)), \(g(graph.xMax))], y ∈ [\(g(graph.yMin)), \(g(graph.yMax))]",
            actions: [.zoomIn, .zoomOut, .resetView, .autoFit])
        viewport.bounds = nil

        var equationNodes: [GraphSemanticNode] = []
        for (index, eq) in graph.equations.enumerated() {
            var states: [GraphSemanticState] = [eq.isVisible ? .visible : .hidden]
            if eq.hasError { states.append(.error) }
            if trace?.equationIndex == index { states.append(.selected) }

            var node = GraphSemanticNode(
                stableId: "eq:\(index)",
                role: .equation,
                labelKey: "Mac_A11y_Equation",
                labelArgs: ["\(index + 1)"],
                value: eq.text,
                states: states,
                actions: [.toggleVisibility])

            if let a = analyses[index] {
                if !a.zeros.isEmpty {
                    node.children.append(GraphSemanticNode(
                        stableId: "eq:\(index)/zeros", role: .featureGroup, labelKey: "Mac_Zeros",
                        value: a.zeros.joined(separator: ", ")))
                }
                if !a.maxima.isEmpty {
                    node.children.append(GraphSemanticNode(
                        stableId: "eq:\(index)/maxima", role: .featureGroup, labelKey: "Maxima",
                        value: a.maxima.map { "(\($0.x), \($0.y))" }.joined(separator: " ")))
                }
                if !a.minima.isEmpty {
                    node.children.append(GraphSemanticNode(
                        stableId: "eq:\(index)/minima", role: .featureGroup, labelKey: "Minima",
                        value: a.minima.map { "(\($0.x), \($0.y))" }.joined(separator: " ")))
                }
            }
            equationNodes.append(node)
        }

        let equationList = GraphSemanticNode(
            stableId: "equations",
            role: .equationList,
            labelKey: "EquationInputList.[using:Windows.UI.Xaml.Automation]AutomationProperties.Name",
            children: equationNodes)

        let visibleCompiled = graph.equations.filter { $0.isVisible && $0.compiled != nil }.count
        var root = GraphSemanticNode(
            stableId: "graph",
            role: .graphArea,
            labelKey: "graphAutomationName",
            labelArgs: [g(graph.xMin), g(graph.xMax), g(graph.yMin), g(graph.yMax), "\(visibleCompiled)"],
            children: [viewport, equationList])

        if graph.isTracing {
            root.states.append(.tracing)
            if let trace {
                let sx = (trace.x - graph.xMin) / graph.xSpan * width
                let sy = height - (trace.y - graph.yMin) / graph.ySpan * height
                root.children.append(GraphSemanticNode(
                    stableId: "trace",
                    role: .tracePoint,
                    labelKey: "Mac_TracePoint",
                    labelArgs: [g(trace.x), g(trace.y)],
                    states: [.tracing],
                    bounds: CGRect(x: sx - 6, y: sy - 6, width: 12, height: 12)))
            }
        }
        return root
    }
}
