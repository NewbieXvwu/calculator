// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// S13 语义树测试：结构/状态/跟踪定位锁定 + spec/graph-accessibility.json 防漂移
// （词表逐项一致、labelKey 与 announcements 键真实存在于 String Catalog）。

import XCTest
@testable import MacCalculator

@MainActor
final class GraphSemanticsTests: XCTestCase {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // MacAppTests
        .deletingLastPathComponent()   // src
        .deletingLastPathComponent()   // repo root

    // MARK: - spec 防漂移

    private struct A11ySpec: Decodable {
        struct Role: Decodable {
            let labelKey: String?
        }
        struct Exposure: Decodable {
            let via: [String]
            let announcement: String?
        }
        let roles: [String: Role]
        let actions: [String]
        let states: [String]
        let requiredExposures: [String: Exposure]
        let announcements: [String: String]
        let platformMechanisms: [String: String]
    }

    private func loadSpec() throws -> A11ySpec {
        let url = Self.repoRoot.appendingPathComponent("spec/graph-accessibility.json")
        return try JSONDecoder().decode(A11ySpec.self, from: Data(contentsOf: url))
    }

    /// String Catalog 的全部键（防漂移：spec 引用的键必须真实存在）。
    private func catalogKeys() throws -> Set<String> {
        let url = Self.repoRoot.appendingPathComponent("src/MacApp/Resources/Localizable.xcstrings")
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        return Set(strings.keys)
    }

    func testSpecVocabulariesMatchSwiftEnums() throws {
        let spec = try loadSpec()

        XCTAssertEqual(Set(spec.roles.keys), Set(GraphSemanticRole.allCases.map(\.rawValue)))
        XCTAssertEqual(Set(spec.actions), Set(GraphSemanticAction.allCases.map(\.rawValue)))
        XCTAssertEqual(spec.actions.count, GraphSemanticAction.allCases.count)
        XCTAssertEqual(Set(spec.states), Set(GraphSemanticState.allCases.map(\.rawValue)))
        XCTAssertEqual(Set(spec.platformMechanisms.keys), ["web", "android", "ohos", "apple"])

        // TODO S13 要求的五项暴露齐备，且引用的角色/播报名合法。
        XCTAssertEqual(
            Set(spec.requiredExposures.keys),
            ["viewportRange", "cursorCoordinates", "extremaAndZeros", "selectedCurve", "zoomResult"])
        for (name, exposure) in spec.requiredExposures {
            for role in exposure.via {
                XCTAssertNotNil(GraphSemanticRole(rawValue: role), "\(name): 未知角色 \(role)")
            }
            if let announcement = exposure.announcement {
                XCTAssertNotNil(spec.announcements[announcement], "\(name): 未知播报 \(announcement)")
            }
        }
    }

    func testSpecL10nKeysExistInStringCatalog() throws {
        let spec = try loadSpec()
        let keys = try catalogKeys()

        for l10nKey in spec.announcements.values {
            XCTAssertTrue(keys.contains(l10nKey), "播报键 \(l10nKey) 不在 String Catalog")
        }
        // 角色 labelKey（featureGroup 是 " | " 分隔的候选列表）。
        for (role, entry) in spec.roles {
            guard let labelKey = entry.labelKey else {
                XCTFail("\(role): 缺 labelKey")
                continue
            }
            for key in labelKey.components(separatedBy: " | ") {
                XCTAssertTrue(keys.contains(key), "\(role): labelKey \(key) 不在 String Catalog")
            }
        }
    }

    // MARK: - 树结构

    func testTreeStructureForDefaultModel() throws {
        let graph = GraphingViewModel()  // 默认 x^2 与 sin(x)
        let root = GraphSemanticTree.build(graph: graph, width: 400, height: 300)

        XCTAssertEqual(root.stableId, "graph")
        XCTAssertEqual(root.role, .graphArea)
        XCTAssertEqual(root.labelKey, "graphAutomationName")
        XCTAssertEqual(root.labelArgs, ["-10", "10", "-10", "10", "2"])
        XCTAssertTrue(root.states.isEmpty)
        XCTAssertEqual(root.children.map(\.stableId), ["viewport", "equations"])

        let viewport = root.children[0]
        XCTAssertEqual(viewport.role, .viewport)
        XCTAssertEqual(viewport.labelKey, "Mac_GridRange")
        XCTAssertEqual(viewport.value, "x ∈ [-10, 10], y ∈ [-10, 10]")
        XCTAssertEqual(viewport.actions, [.zoomIn, .zoomOut, .resetView, .autoFit])
        XCTAssertNil(viewport.bounds)

        let list = root.children[1]
        XCTAssertEqual(list.role, .equationList)
        XCTAssertEqual(list.children.count, 2)
        XCTAssertEqual(list.children.map(\.stableId), ["eq:0", "eq:1"])
        XCTAssertEqual(list.children.map(\.labelArgs), [["1"], ["2"]])
        XCTAssertEqual(list.children.map(\.value), ["x^2", "sin(x)"])
        for eq in list.children {
            XCTAssertEqual(eq.role, .equation)
            XCTAssertEqual(eq.labelKey, "Mac_A11y_Equation")
            XCTAssertEqual(eq.states, [.visible])
            XCTAssertEqual(eq.actions, [.toggleVisibility])
            XCTAssertNil(eq.bounds)
        }
    }

    func testStatesHiddenErrorSelectedAndTraceBounds() throws {
        let graph = GraphingViewModel()
        graph.toggleVisibility(id: graph.equations[0].id)
        graph.addEquation(text: "y=)", latex: "")  // 语法错误
        XCTAssertTrue(graph.equations[2].hasError)

        graph.isTracing = true
        let trace = GraphingViewModel.TraceResult(equationIndex: 1, x: 1, y: 1)
        let root = GraphSemanticTree.build(graph: graph, width: 400, height: 300, trace: trace)

        // 根：tracing 状态；可见已编译方程数 = sin(x) 一条（x^2 隐藏、错误方程未编译）。
        XCTAssertEqual(root.states, [.tracing])
        XCTAssertEqual(root.labelArgs.last, "1")

        let equations = root.children[1].children
        XCTAssertEqual(equations[0].states, [.hidden])
        XCTAssertEqual(equations[1].states, [.visible, .selected])
        XCTAssertEqual(equations[2].states, [.visible, .error])

        // 跟踪节点：数学 (1,1) → 屏幕 (220, 135)（400×300、视窗 ±10）。
        let traceNode = try XCTUnwrap(root.children.last)
        XCTAssertEqual(traceNode.stableId, "trace")
        XCTAssertEqual(traceNode.role, .tracePoint)
        XCTAssertEqual(traceNode.labelKey, "Mac_TracePoint")
        XCTAssertEqual(traceNode.labelArgs, ["1", "1"])
        XCTAssertEqual(traceNode.states, [.tracing])
        let bounds = try XCTUnwrap(traceNode.bounds)
        XCTAssertEqual(bounds.midX, 220, accuracy: 1e-9)
        XCTAssertEqual(bounds.midY, 135, accuracy: 1e-9)

        // 未跟踪时无 trace 节点、根无 tracing 状态。
        graph.isTracing = false
        let idle = GraphSemanticTree.build(graph: graph, width: 400, height: 300)
        XCTAssertTrue(idle.states.isEmpty)
        XCTAssertEqual(idle.children.count, 2)
    }

    func testFeatureGroupsAndPreorderTraversal() throws {
        let graph = GraphingViewModel()
        var analysis = GiacFunctionAnalysis()
        analysis.zeros = ["0", "2"]
        analysis.maxima = [(x: "1", y: "3")]
        let root = GraphSemanticTree.build(
            graph: graph, width: 400, height: 300, analyses: [0: analysis])

        let eq0 = root.children[1].children[0]
        XCTAssertEqual(eq0.children.map(\.stableId), ["eq:0/zeros", "eq:0/maxima"])
        XCTAssertEqual(eq0.children.map(\.role), [.featureGroup, .featureGroup])
        XCTAssertEqual(eq0.children.map(\.labelKey), ["Mac_Zeros", "Maxima"])
        XCTAssertEqual(eq0.children.map(\.value), ["0, 2", "(1, 3)"])

        // 先序遍历：children 数组序即朗读序；stableId 全树唯一。
        let flat = root.flattened().map(\.stableId)
        XCTAssertEqual(flat, ["graph", "viewport", "equations", "eq:0", "eq:0/zeros", "eq:0/maxima", "eq:1"])
        XCTAssertEqual(Set(flat).count, flat.count)
    }
}
