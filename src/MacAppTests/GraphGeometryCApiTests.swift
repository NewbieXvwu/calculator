// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// S7 图形几何下沉后的 C 层直接行为测试（平价测试退役，D6 纪律）：
// macOS 首发实现（GraphingView / GraphingViewModel 内 Swift 公式、
// MarchingSquares.swift 对拍 oracle）已全部退役或改为委托共享层，
// 本文件不再与任何 Swift 实现逐项对拍——全部为 graph_geometry.h
// （C ABI）的独立期望断言，构成 C 层行为回归网。

import CalcManagerBridge
import XCTest
@testable import MacCalculator

/// 把 Swift 闭包穿过 C void* 上下文的载体。
private final class EvalBox {
    let f1: ((Double) -> Double?)?
    let f2: ((Double, Double) -> Double?)?
    init(f1: ((Double) -> Double?)? = nil, f2: ((Double, Double) -> Double?)? = nil) {
        self.f1 = f1
        self.f2 = f2
    }
}

private let evalThunk1: @convention(c) (UnsafeMutableRawPointer?, Double, UnsafeMutablePointer<Double>?) -> Bool = { ctx, x, out in
    let box = Unmanaged<EvalBox>.fromOpaque(ctx!).takeUnretainedValue()
    guard let y = box.f1!(x) else { return false }
    out!.pointee = y
    return true
}

private let evalThunk2: @convention(c) (UnsafeMutableRawPointer?, Double, Double, UnsafeMutablePointer<Double>?) -> Bool = { ctx, x, y, out in
    let box = Unmanaged<EvalBox>.fromOpaque(ctx!).takeUnretainedValue()
    guard let f = box.f2!(x, y) else { return false }
    out!.pointee = f
    return true
}

/// S4：区间求值闭包穿过 C void* 的载体。
private final class IntervalBox {
    let f: (Double, Double, Double, Double) -> GraphIntervalResult
    init(_ f: @escaping (Double, Double, Double, Double) -> GraphIntervalResult) { self.f = f }
}

private let intervalThunk: @convention(c) (
    UnsafeMutableRawPointer?, Double, Double, Double, Double,
    UnsafeMutablePointer<Double>?, UnsafeMutablePointer<Double>?
) -> graph_box_domain_t = { ctx, xLo, xHi, yLo, yHi, outLo, outHi in
    let box = Unmanaged<IntervalBox>.fromOpaque(ctx!).takeUnretainedValue()
    let r = box.f(xLo, xHi, yLo, yHi)
    outLo!.pointee = r.lo
    outHi!.pointee = r.hi
    switch r.domain {
    case .nowhereDefined: return GRAPH_BOX_NOWHERE_DEFINED
    case .defined: return GRAPH_BOX_DEFINED
    case .maybeDefined: return GRAPH_BOX_MAYBE_DEFINED
    }
}

@MainActor
final class GraphGeometryCApiTests: XCTestCase {
    private func makeViewport(
        xMin: Double = -10, xMax: Double = 10, yMin: Double = -10, yMax: Double = 10,
        width: Double = 400, height: Double = 300
    ) -> graph_viewport_t {
        graph_viewport_t(x_min: xMin, x_max: xMax, y_min: yMin, y_max: yMax, width: width, height: height)
    }

    // MARK: - 坐标变换

    func testCoordinateTransformsAndRoundTrip() {
        var vp = makeViewport(xMin: -3, xMax: 7, yMin: -2, yMax: 4, width: 500, height: 320)
        // 屏幕坐标定义：x 线性映射，y 向上翻转（数学 y 最大 → 屏幕 0）。
        XCTAssertEqual(graph_to_screen_x(&vp, -3), 0, accuracy: 1e-12)
        XCTAssertEqual(graph_to_screen_x(&vp, 7), 500, accuracy: 1e-12)
        XCTAssertEqual(graph_to_screen_x(&vp, 2), 250, accuracy: 1e-12)
        XCTAssertEqual(graph_to_screen_y(&vp, -2), 320, accuracy: 1e-12)  // 数学 y 向上翻转
        XCTAssertEqual(graph_to_screen_y(&vp, 4), 0, accuracy: 1e-12)
        XCTAssertEqual(graph_to_screen_y(&vp, 1), 160, accuracy: 1e-12)

        // 双向互逆（往返保持精度）。
        for v in stride(from: 0.0, through: 500, by: 47) {
            XCTAssertEqual(graph_to_screen_x(&vp, graph_to_math_x(&vp, v)), v, accuracy: 1e-9)
        }
        for v in stride(from: 0.0, through: 320, by: 37) {
            XCTAssertEqual(graph_to_screen_y(&vp, graph_to_math_y(&vp, v)), v, accuracy: 1e-9)
        }
    }

    // MARK: - 刻度（1-2-5）

    func testNiceStepCoversAll125Branches() {
        // 1-2-5 序列：rough=span/target 归一到 {1,2,5,10}×10^n。
        XCTAssertEqual(graph_nice_step(20, 10), 2, accuracy: 1e-12)     // norm=2
        XCTAssertEqual(graph_nice_step(10, 10), 1, accuracy: 1e-12)     // norm=1
        XCTAssertEqual(graph_nice_step(1, 10), 0.1, accuracy: 1e-12)    // 缩小量级
        XCTAssertEqual(graph_nice_step(40, 10), 5, accuracy: 1e-12)     // norm=4
        XCTAssertEqual(graph_nice_step(80, 10), 10, accuracy: 1e-12)    // norm=8 → 10
        XCTAssertEqual(graph_nice_step(1.4, 10), 0.1, accuracy: 1e-12)  // norm=1.4 < 1.5
        XCTAssertEqual(graph_nice_step(15, 10), 2, accuracy: 1e-12)     // 边界 norm=1.5 → 2
        XCTAssertEqual(graph_nice_step(0, 10), 0)
        XCTAssertEqual(graph_nice_step(10, 0), 0)
    }

    func testTicksMatchGridEnumeration() {
        // 刻度枚举：x = (min/step).rounded(.up)*step; while x <= max。
        let step = graph_nice_step(20, 10)
        var expected: [Double] = []
        var x = (-10.0 / step).rounded(.up) * step
        while x <= 10 { expected.append(x); x += step }

        var out = [Double](repeating: .nan, count: 64)
        let count = graph_ticks(-10, 10, step, &out, out.count)
        XCTAssertEqual(Int(count), expected.count)
        for (i, e) in expected.enumerated() {
            XCTAssertEqual(out[i], e, accuracy: 1e-12)
        }
        // 非法步长安全。
        XCTAssertEqual(graph_ticks(-10, 10, 0, nil, 0), 0)
    }

    // MARK: - 视窗操作（GraphingViewModel 委托锁）

    func testViewportOpsMatchViewModel() {
        // VM 的 pan/zoom/applyRange 已委托共享层；本测试锁定委托语义：
        // VM 写回结果必须与直接调用 C ABI 一致（防回退到本地公式实现）。
        let vm = GraphingViewModel()
        var vp = makeViewport()

        vm.pan(dxMath: 1.5, dyMath: -0.75)
        graph_pan(&vp, 1.5, -0.75)
        assertViewportMatches(vp, vm)

        vm.zoom(factor: 0.8)
        graph_zoom(&vp, 0.8)
        assertViewportMatches(vp, vm)

        vm.zoom(factor: 1.25, anchorX: 2, anchorY: -3)
        graph_zoom_at(&vp, 1.25, 2, -3)
        assertViewportMatches(vp, vm)

        XCTAssertTrue(vm.applyRange(xMin: -5, xMax: 5, yMin: -4, yMax: 4))
        XCTAssertTrue(graph_apply_range(&vp, -5, 5, -4, 4))
        assertViewportMatches(vp, vm)

        // 拒绝条件：min ≥ max 或非有限值。
        XCTAssertFalse(vm.applyRange(xMin: 5, xMax: 5, yMin: -4, yMax: 4))
        XCTAssertFalse(graph_apply_range(&vp, 5, 5, -4, 4))
        XCTAssertFalse(graph_apply_range(&vp, -5, .infinity, -4, 4))
        assertViewportMatches(vp, vm)
    }

    private func assertViewportMatches(_ vp: graph_viewport_t, _ vm: GraphingViewModel) {
        XCTAssertEqual(vp.x_min, vm.xMin, accuracy: 1e-12)
        XCTAssertEqual(vp.x_max, vm.xMax, accuracy: 1e-12)
        XCTAssertEqual(vp.y_min, vm.yMin, accuracy: 1e-12)
        XCTAssertEqual(vp.y_max, vm.yMax, accuracy: 1e-12)
    }

    func testAutoFitPercentileDegenerateAndDelegation() {
        // C 直接：退化值域（全常数）→ ±1 再加 10% 边距。
        var lo = 0.0, hi = 0.0
        XCTAssertTrue(graph_auto_fit_y([3.0, 3.0, 3.0], 3, &lo, &hi))
        XCTAssertEqual(lo, 1.8, accuracy: 1e-12)
        XCTAssertEqual(hi, 4.2, accuracy: 1e-12)
        // 空输入 → false。
        XCTAssertFalse(graph_auto_fit_y(nil, 0, &lo, &hi))

        // VM 委托锁：autoFitView 采样后走同一 C 路径，结果写回视窗。
        let vm = GraphingViewModel()  // 自带 x^2 与 sin(x)
        var ys: [Double] = []
        let samples = 512
        for eq in vm.equations where eq.isVisible {
            guard let expr = eq.explicitExpression else { continue }
            for i in 0...samples {
                let x = vm.xMin + Double(i) / Double(samples) * vm.xSpan
                if let y = expr.evaluate(x: x, params: vm.parameters, trig: vm.trigMode) {
                    ys.append(y)
                }
            }
        }
        XCTAssertFalse(ys.isEmpty)
        var cLo = 0.0, cHi = 0.0
        XCTAssertTrue(graph_auto_fit_y(ys, ys.count, &cLo, &cHi))
        vm.autoFitView()
        XCTAssertEqual(cLo, vm.yMin, accuracy: 1e-9)
        XCTAssertEqual(cHi, vm.yMax, accuracy: 1e-9)
    }

    // MARK: - 显式曲线逐列采样

    func testSampleCurveContinuous() {
        var vp = makeViewport()
        let box = EvalBox(f1: { $0 })  // y = x：连续单折线
        let ctx = Unmanaged.passUnretained(box).toOpaque()
        var out = [graph_sample_t](repeating: graph_sample_t(), count: 401)
        let count = graph_sample_curve(&vp, evalThunk1, ctx, &out, out.count)

        XCTAssertEqual(count, 401)  // 0...columns，columns = Int(width)
        XCTAssertEqual(out.prefix(Int(count)).filter(\.move).count, 1)
        XCTAssertTrue(out[0].move)
        // 首尾点落在画布对角（y=x 在 [-10,10]² 视窗内）。
        XCTAssertEqual(out[0].sx, 0, accuracy: 1e-12)
        XCTAssertEqual(out[0].sy, 300, accuracy: 1e-9)
        XCTAssertEqual(out[400].sx, 400, accuracy: 1e-12)
        XCTAssertEqual(out[400].sy, 0, accuracy: 1e-9)
    }

    func testSampleCurveBreaksAtUndefinedAndAsymptote() {
        // 独立期望（价值点：y=1/x 断裂/抬笔）：x=0 恰在第 200 列（未定义 → 抬笔），
        // 渐近线两侧还有两次超过 1.5 倍画布高的跳变断裂。
        let vpValue = makeViewport(xMin: -5, xMax: 5, yMin: -5, yMax: 5)
        var vp = vpValue
        let f: (Double) -> Double? = { x in x == 0 ? nil : 1 / x }
        let box = EvalBox(f1: f)
        let ctx = Unmanaged.passUnretained(box).toOpaque()
        var out = [graph_sample_t](repeating: graph_sample_t(), count: 401)
        let count = graph_sample_curve(&vp, evalThunk1, ctx, &out, out.count)

        // 采样循环的独立镜像（drawCurve 语义，见 graph_geometry.cpp）：
        // 未定义列抬笔；相邻列屏幕 y 跳变 > 1.5×画布高 → 断裂抬笔。
        var expected: [(sx: Double, sy: Double, move: Bool)] = []
        var penDown = false
        var lastScreenY = 0.0
        let jumpThreshold = vpValue.height * 1.5
        let columns = Int(vpValue.width)
        for column in 0...columns {
            let sx = Double(column)
            let mathX = vpValue.x_min + sx / vpValue.width * (vpValue.x_max - vpValue.x_min)
            guard let mathY = f(mathX) else {
                penDown = false
                continue
            }
            let sy = vpValue.height - (mathY - vpValue.y_min) / (vpValue.y_max - vpValue.y_min) * vpValue.height
            if penDown && abs(sy - lastScreenY) > jumpThreshold { penDown = false }
            expected.append((sx, sy, !penDown))
            penDown = true
            lastScreenY = sy
        }

        XCTAssertEqual(Int(count), expected.count)
        XCTAssertEqual(count, 400)  // 401 列 − 1 个未定义列
        for (i, e) in expected.enumerated() {
            XCTAssertEqual(out[i].sx, e.sx, accuracy: 1e-12, "sample[\(i)].sx")
            XCTAssertEqual(out[i].sy, e.sy, accuracy: 1e-9, "sample[\(i)].sy")
            XCTAssertEqual(out[i].move, e.move, "sample[\(i)].move")
        }
        XCTAssertEqual(expected.filter(\.move).count, 4)
        // 宽度 ≤ 1 不采样。
        var tiny = makeViewport(width: 1)
        XCTAssertEqual(graph_sample_curve(&tiny, evalThunk1, ctx, nil, 0), 0)
    }

    // MARK: - Marching squares（独立期望；Swift 对拍 oracle 已退役）

    func testMarchingSquaresCircleRadius() {
        // 独立期望：半径 5 的圆，全部线段端点落在圆上。
        let f: (Double, Double) -> Double? = { x, y in (x * x + y * y) - 25 }
        let box = EvalBox(f2: f)
        let ctx = Unmanaged.passUnretained(box).toOpaque()
        var out = [graph_segment_t](repeating: graph_segment_t(), count: 2 * 200 * 200)
        let count = graph_marching_squares(-10, 10, -10, 10, 200, 200, evalThunk2, ctx, &out, out.count)
        XCTAssertGreaterThan(count, 100)
        for i in 0..<Int(count) {
            XCTAssertEqual((out[i].x1 * out[i].x1 + out[i].y1 * out[i].y1).squareRoot(), 5, accuracy: 0.05, "seg[\(i)].p1")
            XCTAssertEqual((out[i].x2 * out[i].x2 + out[i].y2 * out[i].y2).squareRoot(), 5, accuracy: 0.05, "seg[\(i)].p2")
        }
    }

    func testMarchingSquaresVerticalLineOnGridNodes() {
        // 独立期望：竖直线 x=5 恰落在网格节点上（节点值 0 → +ε 防退化），
        // 全部线段端点 x≈5。
        let f: (Double, Double) -> Double? = { x, _ in x - 5 }
        let box = EvalBox(f2: f)
        let ctx = Unmanaged.passUnretained(box).toOpaque()
        var out = [graph_segment_t](repeating: graph_segment_t(), count: 2 * 100 * 100)
        let count = graph_marching_squares(-10, 10, -10, 10, 100, 100, evalThunk2, ctx, &out, out.count)
        XCTAssertGreaterThanOrEqual(count, 100)
        for i in 0..<Int(count) {
            XCTAssertEqual(abs(out[i].x1 - 5), 0, accuracy: 0.01, "seg[\(i)].p1")
            XCTAssertEqual(abs(out[i].x2 - 5), 0, accuracy: 0.01, "seg[\(i)].p2")
        }
    }

    func testMarchingSquaresHyperbolaOnCurve() {
        // 独立期望：双曲线 xy=4，全部端点落在曲线上。
        let f: (Double, Double) -> Double? = { x, y in x * y - 4 }
        let box = EvalBox(f2: f)
        let ctx = Unmanaged.passUnretained(box).toOpaque()
        var out = [graph_segment_t](repeating: graph_segment_t(), count: 2 * 200 * 200)
        let count = graph_marching_squares(-10, 10, -10, 10, 200, 200, evalThunk2, ctx, &out, out.count)
        XCTAssertGreaterThan(count, 50)
        for i in 0..<Int(count) {
            XCTAssertEqual(out[i].x1 * out[i].y1, 4, accuracy: 0.2, "seg[\(i)].p1")
            XCTAssertEqual(out[i].x2 * out[i].y2, 4, accuracy: 0.2, "seg[\(i)].p2")
        }
    }

    func testMarchingSquaresCircleWithNilHoleDropsCells() {
        // 独立期望（nil 传播）：x < -3 的区域未定义 → 含未定义角的格子整体跳过，
        // 圆左帽（x∈[−5,−3]）消失：线段数严格减少，且无任何端点落入洞区。
        let full: (Double, Double) -> Double? = { x, y in x * x + y * y - 25 }
        let holed: (Double, Double) -> Double? = { x, y in x < -3 ? nil : x * x + y * y - 25 }

        let fBox = EvalBox(f2: full)
        let fCtx = Unmanaged.passUnretained(fBox).toOpaque()
        let hBox = EvalBox(f2: holed)
        let hCtx = Unmanaged.passUnretained(hBox).toOpaque()
        var fullOut = [graph_segment_t](repeating: graph_segment_t(), count: 2 * 64 * 48)
        var holedOut = [graph_segment_t](repeating: graph_segment_t(), count: 2 * 64 * 48)
        let fullCount = graph_marching_squares(-10, 10, -8, 8, 64, 48, evalThunk2, fCtx, &fullOut, fullOut.count)
        let holedCount = graph_marching_squares(-10, 10, -8, 8, 64, 48, evalThunk2, hCtx, &holedOut, holedOut.count)

        XCTAssertGreaterThan(fullCount, 100)
        for i in 0..<Int(fullCount) {
            XCTAssertEqual((fullOut[i].x1 * fullOut[i].x1 + fullOut[i].y1 * fullOut[i].y1).squareRoot(), 5, accuracy: 0.05)
        }
        XCTAssertLessThan(holedCount, fullCount, "洞区未生效：含未定义角的格子应被跳过")
        XCTAssertGreaterThan(holedCount, 0)
        for i in 0..<Int(holedCount) {
            XCTAssertGreaterThanOrEqual(holedOut[i].x1, -3 - 1e-9, "seg[\(i)].p1 落入未定义洞区")
            XCTAssertGreaterThanOrEqual(holedOut[i].x2, -3 - 1e-9, "seg[\(i)].p2 落入未定义洞区")
        }
    }

    func testMarchingSquaresSaddleDisambiguationQuadrants() {
        // 独立期望（价值点：鞍点消歧）：双曲线 xy=1 在单格网格 [−1.5,1.5]² 上
        // 四角符号 +,−,+,−（bl=(−1.5,−1.5): xy=2.25>1；br<1；tr>1；tl<1）→ 4 交点
        // 鞍点格。中心 (0,0) 处 f=−1<0 与 bl 异侧 → 配对「下-左、上-右」：
        // 两条线段必须分别完全落在第三象限与第一象限，端点落在曲线上。
        // 错误配对（下-上、左-右）会让线段横穿原点区域。
        let f: (Double, Double) -> Double? = { x, y in x * y - 1 }
        let box = EvalBox(f2: f)
        let ctx = Unmanaged.passUnretained(box).toOpaque()
        var out = [graph_segment_t](repeating: graph_segment_t(), count: 4)
        let count = graph_marching_squares(-1.5, 1.5, -1.5, 1.5, 1, 1, evalThunk2, ctx, &out, out.count)

        XCTAssertEqual(count, 2, "鞍点格应产出 2 条线段")
        for i in 0..<Int(count) {
            // 端点落在曲线 xy=1 上（线性插值精度内）。
            XCTAssertEqual(abs(out[i].x1 * out[i].y1 - 1), 0, accuracy: 1e-9, "seg[\(i)].p1 不在曲线上")
            XCTAssertEqual(abs(out[i].x2 * out[i].y2 - 1), 0, accuracy: 1e-9, "seg[\(i)].p2 不在曲线上")
            // 端点按象限聚合：整条线段在 Q1 或 Q3，不得跨象限。
            let q1 = out[i].x1 > 0 && out[i].y1 > 0 && out[i].x2 > 0 && out[i].y2 > 0
            let q3 = out[i].x1 < 0 && out[i].y1 < 0 && out[i].x2 < 0 && out[i].y2 < 0
            XCTAssertTrue(q1 || q3, "seg[\(i)] 端点跨象限 = 鞍点配对错误")
            // 正确配对的分支端点离原点足够远（错误配对会贴近原点）。
            XCTAssertGreaterThan((out[i].x1 * out[i].x1 + out[i].y1 * out[i].y1).squareRoot(), 1.0)
            XCTAssertGreaterThan((out[i].x2 * out[i].x2 + out[i].y2 * out[i].y2).squareRoot(), 1.0)
        }
        // 非法网格安全。
        XCTAssertEqual(graph_marching_squares(0, 1, 0, 1, 0, 4, evalThunk2, ctx, nil, 0), 0)
    }

    // MARK: - 不等式关系表

    func testRelationTableDirect() {
        // C 层 graph_relation_satisfied 为单一真相源
        // （原 Swift InequalityRelation.satisfied 已随平价测试退役删除）。
        for f in [-1.0, 0.0, 1.0, -1e-300, 1e-300] {
            XCTAssertEqual(graph_relation_satisfied(GRAPH_REL_LESS, f), f < 0, "LESS f=\(f)")
            XCTAssertEqual(graph_relation_satisfied(GRAPH_REL_LESS_EQUAL, f), f <= 0, "LESS_EQUAL f=\(f)")
            XCTAssertEqual(graph_relation_satisfied(GRAPH_REL_GREATER, f), f > 0, "GREATER f=\(f)")
            XCTAssertEqual(graph_relation_satisfied(GRAPH_REL_GREATER_EQUAL, f), f >= 0, "GREATER_EQUAL f=\(f)")
        }
        // isStrict：< 与 > 严格（UI 边界虚线），≤ ≥ 非严格（实线）。
        XCTAssertTrue(graph_relation_is_strict(GRAPH_REL_LESS))
        XCTAssertTrue(graph_relation_is_strict(GRAPH_REL_GREATER))
        XCTAssertFalse(graph_relation_is_strict(GRAPH_REL_LESS_EQUAL))
        XCTAssertFalse(graph_relation_is_strict(GRAPH_REL_GREATER_EQUAL))
    }

    func testInequalityRunsHalfPlane() {
        // y < 0：满足区域应为屏幕下半（屏幕 y 向下），每行合并为整行单矩形。
        var vp = makeViewport(width: 400, height: 400)
        let box = EvalBox(f2: { _, y in y })
        let ctx = Unmanaged.passUnretained(box).toOpaque()
        var out = [graph_rect_t](repeating: graph_rect_t(), count: 100 * 51)
        let count = graph_inequality_runs(&vp, 4, GRAPH_REL_LESS, evalThunk2, ctx, &out, out.count)

        // drawInequality：cols=rows=max(8, 400/4)=100；下半 50 行各一条整行 run。
        XCTAssertEqual(count, 50)
        for rect in out.prefix(Int(count)) {
            XCTAssertEqual(rect.x, 0, accuracy: 1e-12)
            XCTAssertEqual(rect.w, 400, accuracy: 1e-12)
            XCTAssertEqual(rect.h, 4, accuracy: 1e-12)
            XCTAssertGreaterThanOrEqual(rect.y, 200)
        }

        XCTAssertEqual(graph_cell_count(400, 4), 100)
        XCTAssertEqual(graph_cell_count(10, 3), 8)  // max(8, …) 下限
    }

    // MARK: - 跟踪吸附（GraphingViewModel 委托锁）

    func testTraceSnapDirectAndDelegation() throws {
        // C 直接：按 |y−mathY|/ySpan 归一距离取最近；NaN 候选跳过。
        let ys: [Double] = [1, 4, .nan, 9]
        XCTAssertEqual(ys.withUnsafeBufferPointer { graph_trace_snap($0.baseAddress, $0.count, 4.1, 20) }, 1)
        XCTAssertEqual(ys.withUnsafeBufferPointer { graph_trace_snap($0.baseAddress, $0.count, 8.9, 20) }, 3)
        XCTAssertEqual(ys.withUnsafeBufferPointer { graph_trace_snap($0.baseAddress, $0.count, 20, 20) }, 3)
        // 全 NaN → -1。
        XCTAssertEqual(graph_trace_snap([Double.nan, .nan], 2, 0, 20), -1)

        // VM 委托锁：候选采集 + 下标映射后走同一 C 路径。
        let vm = GraphingViewModel()  // x^2、sin(x)
        let mathX = 1.3, mathY = 1.1
        let snap = try XCTUnwrap(vm.nearestCurvePoint(mathX: mathX, mathY: mathY))
        var cand: [Double] = []
        var indexMap: [Int] = []
        for (index, eq) in vm.equations.enumerated() where eq.isVisible {
            guard let expr = eq.explicitExpression,
                  let y = expr.evaluate(x: mathX, params: vm.parameters, trig: vm.trigMode) else { continue }
            cand.append(y)
            indexMap.append(index)
        }
        let picked = cand.withUnsafeBufferPointer { graph_trace_snap($0.baseAddress, $0.count, mathY, vm.ySpan) }
        XCTAssertGreaterThanOrEqual(picked, 0)
        XCTAssertEqual(indexMap[Int(picked)], snap.equationIndex)
        XCTAssertEqual(cand[Int(picked)], snap.y, accuracy: 1e-12)
    }

    // MARK: - S4 区间算术（Tupper）

    func testPow2CellCountAlignsWithQuadtreeLeaves() {
        // 400px / 3px：最小 2^k 使 400/2^k ≤ 3 → 256；4px → 128。
        XCTAssertEqual(graph_pow2_cell_count(400, 3), 256)
        XCTAssertEqual(graph_pow2_cell_count(400, 4), 128)
        XCTAssertEqual(graph_pow2_cell_count(2, 4), 1)   // 不足一格 → 不再细分
        XCTAssertEqual(graph_pow2_cell_count(0, 3), 1)
    }

    func testImplicitCellsCoverSelfIntersection() throws {
        // 验收判据①：x² = y²(x+1) 自交点(0,0)。区间法保证无假阴性：
        // 不做角抑制时，包含原点的叶格必然幸存（F 的包络含 0）。
        var vp = makeViewport(width: 400, height: 400)
        let expr = try XCTUnwrap(GraphExpression(rawTwoVariable: "x^2 - y^2(x+1)"))
        let box = IntervalBox { expr.evaluateInterval(xLo: $0, xHi: $1, yLo: $2, yHi: $3) }
        let ctx = Unmanaged.passUnretained(box).toOpaque()

        var out = [graph_rect_t](repeating: graph_rect_t(), count: 1 << 16)
        let count = out.withUnsafeMutableBufferPointer {
            graph_implicit_cells(&vp, 3, intervalThunk, ctx, nil, nil, $0.baseAddress, $0.count)
        }
        XCTAssertGreaterThan(count, 0)
        XCTAssertLessThanOrEqual(count, out.count, "预算内不应溢出")
        // 原点屏幕坐标 (200,200) 必须被某个幸存叶格覆盖。
        let coversOrigin = out.prefix(count).contains {
            $0.x <= 200 && 200 <= $0.x + $0.w && $0.y <= 200 && 200 <= $0.y + $0.h
        }
        XCTAssertTrue(coversOrigin, "自交点所在格被区间法丢弃 = 假阴性")
    }

    func testImplicitCellsFindSubCellCircleMarchingSquaresMisses() throws {
        // 半径 1e-3 的圆整体落在单个 MS 网格格内且不触及任何节点：
        // 四角同号 → MS 完全失明；角抑制开启时区间补格必须把它救回来。
        var vp = makeViewport(width: 400, height: 400)
        let expr = try XCTUnwrap(GraphExpression(rawTwoVariable: "(x-0.037)^2 + (y+0.021)^2 - 0.000001"))
        let iBox = IntervalBox { expr.evaluateInterval(xLo: $0, xHi: $1, yLo: $2, yHi: $3) }
        let iCtx = Unmanaged.passUnretained(iBox).toOpaque()
        let cBox = EvalBox(f2: { expr.evaluate(x: $0, y: $1) })
        let cCtx = Unmanaged.passUnretained(cBox).toOpaque()

        // 同网格的 MS 什么都画不出（对齐 2^k 网格）。
        let cols = Int(graph_pow2_cell_count(400, 3))
        var segs = [graph_segment_t](repeating: graph_segment_t(), count: 16)
        let segCount = segs.withUnsafeMutableBufferPointer {
            graph_marching_squares(-10, 10, -10, 10, Int32(cols), Int32(cols),
                                   evalThunk2, cCtx, $0.baseAddress, $0.count)
        }
        XCTAssertEqual(segCount, 0, "圆应小到 MS 网格完全看不见")

        var out = [graph_rect_t](repeating: graph_rect_t(), count: 1 << 16)
        let count = out.withUnsafeMutableBufferPointer {
            graph_implicit_cells(&vp, 3, intervalThunk, iCtx, evalThunk2, cCtx, $0.baseAddress, $0.count)
        }
        XCTAssertGreaterThan(count, 0, "亚格特征不得整体消失")
        // 圆心 (0.037, -0.021) 屏幕坐标 ≈ (200.74, 200.42)；所有补格应聚在附近。
        let sx = (0.037 + 10) / 20 * 400
        let sy = 400 - (-0.021 + 10) / 20 * 400
        for rect in out.prefix(min(count, out.count)) {
            XCTAssertLessThan(abs(rect.x + rect.w / 2 - sx), 6, "补格离圆心过远")
            XCTAssertLessThan(abs(rect.y + rect.h / 2 - sy), 6, "补格离圆心过远")
        }
    }

    func testInequalityRegionsKeepNarrowBandOldSamplerMisses() throws {
        // 验收判据②的机制版：y² < 0.0001（|y|<0.01，屏幕上仅 0.2px 高的细带）。
        // 旧的中心点采样（graph_inequality_runs）整片丢失；区间三值版必须以
        // 「不确定」形式保住 y=0 一线（M4：不确定有显式表示）。
        var vp = makeViewport(width: 400, height: 400)
        let expr = try XCTUnwrap(GraphExpression(rawTwoVariable: "y^2 - 0.0001"))

        let cBox = EvalBox(f2: { expr.evaluate(x: $0, y: $1) })
        let cCtx = Unmanaged.passUnretained(cBox).toOpaque()
        var runs = [graph_rect_t](repeating: graph_rect_t(), count: 8)
        let oldCount = runs.withUnsafeMutableBufferPointer {
            graph_inequality_runs(&vp, 4, GRAPH_REL_LESS, evalThunk2, cCtx, $0.baseAddress, $0.count)
        }
        XCTAssertEqual(oldCount, 0, "旧采样若能看见细带，此测试前提不再成立")

        let iBox = IntervalBox { expr.evaluateInterval(xLo: $0, xHi: $1, yLo: $2, yHi: $3) }
        let iCtx = Unmanaged.passUnretained(iBox).toOpaque()
        var certain = [graph_rect_t](repeating: graph_rect_t(), count: 1 << 16)
        var uncertain = [graph_rect_t](repeating: graph_rect_t(), count: 1 << 16)
        var uncertainTotal = 0
        let certainCount = certain.withUnsafeMutableBufferPointer { cBuf in
            uncertain.withUnsafeMutableBufferPointer { uBuf in
                graph_inequality_regions(
                    &vp, 4, GRAPH_REL_LESS, intervalThunk, iCtx,
                    cBuf.baseAddress, cBuf.count, uBuf.baseAddress, uBuf.count, &uncertainTotal)
            }
        }
        XCTAssertGreaterThan(uncertainTotal, 0, "细带必须至少以不确定形式呈现")
        // y=0 的屏幕行 sy=200 必须被 certain ∪ uncertain 覆盖。
        let all = certain.prefix(certainCount) + uncertain.prefix(min(uncertainTotal, uncertain.count))
        let coversAxis = all.contains { $0.y <= 200 && 200 <= $0.y + $0.h }
        XCTAssertTrue(coversAxis, "y=0 一线整片消失")
        // 细带外的大片区域必须被判「确定不成立」而丢弃：不确定格总面积应远小于画布。
        let uncertainArea = uncertain.prefix(min(uncertainTotal, uncertain.count)).reduce(0.0) { $0 + $1.w * $1.h }
        XCTAssertLessThan(uncertainArea, 400.0 * 400.0 * 0.1, "不确定区域应收敛在细带附近")
    }

    func testInequalityRegionsSinOneOverXNoFalseNegatives() throws {
        // 验收判据②：0 < sin(1/x) < 0.1 类细窄区域。UI 语法为单关系，取其窄侧
        // sin(1/x) < 0.1 做无假阴性校验：所有真值采样点（含 x→0 无限振荡区）
        // 必须落在 certain ∪ uncertain 覆盖内——宁可标不确定，不得整片消失。
        var vp = graph_viewport_t(x_min: -1, x_max: 1, y_min: -1, y_max: 1, width: 400, height: 400)
        let expr = try XCTUnwrap(GraphExpression(rawTwoVariable: "sin(1/x) - 0.1"))
        let iBox = IntervalBox { expr.evaluateInterval(xLo: $0, xHi: $1, yLo: $2, yHi: $3) }
        let iCtx = Unmanaged.passUnretained(iBox).toOpaque()

        var certain = [graph_rect_t](repeating: graph_rect_t(), count: 1 << 16)
        var uncertain = [graph_rect_t](repeating: graph_rect_t(), count: 1 << 16)
        var uncertainTotal = 0
        let certainCount = certain.withUnsafeMutableBufferPointer { cBuf in
            uncertain.withUnsafeMutableBufferPointer { uBuf in
                graph_inequality_regions(
                    &vp, 4, GRAPH_REL_LESS, intervalThunk, iCtx,
                    cBuf.baseAddress, cBuf.count, uBuf.baseAddress, uBuf.count, &uncertainTotal)
            }
        }
        let rects = Array(certain.prefix(certainCount)) + Array(uncertain.prefix(min(uncertainTotal, uncertain.count)))
        func columnCovered(_ sx: Double) -> Bool {
            rects.contains { $0.x <= sx && sx <= $0.x + $0.w && $0.y <= 200 && 200 <= $0.y + $0.h }
        }
        // 真值采样点（留边距避免边界并列）：sin(1/x) < 0.05 的列必须被覆盖。
        var checked = 0
        for i in 1...400 {
            let x = -1.0 + 2.0 * Double(i) / 400
            guard abs(x) > 1e-9, sin(1 / x) < 0.05 else { continue }
            let sx = (x + 1) / 2 * 400
            XCTAssertTrue(columnCovered(sx), "真值列 x=\(x) 整片消失")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 50, "采样应覆盖足够多真值列")
        // x=0 振荡区：区间收敛到 [-1,1]-0.1 含 0 → 必须以不确定形式可见。
        XCTAssertGreaterThan(uncertainTotal, 0)
        XCTAssertTrue(columnCovered(200), "x→0 振荡区不得空白")
    }

    func testInequalityRegionsCertainHalfPlane() throws {
        // y < 0：下半平面应主要以「确定」大块矩形输出（未细分的四叉树节点），
        // 不确定格仅贴着 y=0 边界一条线。
        var vp = makeViewport(width: 400, height: 400)
        let expr = try XCTUnwrap(GraphExpression(rawTwoVariable: "y"))
        let iBox = IntervalBox { expr.evaluateInterval(xLo: $0, xHi: $1, yLo: $2, yHi: $3) }
        let iCtx = Unmanaged.passUnretained(iBox).toOpaque()

        var certain = [graph_rect_t](repeating: graph_rect_t(), count: 1 << 16)
        var uncertain = [graph_rect_t](repeating: graph_rect_t(), count: 1 << 16)
        var uncertainTotal = 0
        let certainCount = certain.withUnsafeMutableBufferPointer { cBuf in
            uncertain.withUnsafeMutableBufferPointer { uBuf in
                graph_inequality_regions(
                    &vp, 4, GRAPH_REL_LESS, intervalThunk, iCtx,
                    cBuf.baseAddress, cBuf.count, uBuf.baseAddress, uBuf.count, &uncertainTotal)
            }
        }
        XCTAssertGreaterThan(certainCount, 0)
        let certainArea = certain.prefix(certainCount).reduce(0.0) { $0 + $1.w * $1.h }
        XCTAssertGreaterThan(certainArea, 400.0 * 400.0 * 0.45, "下半平面绝大部分应为确定区域")
        for rect in certain.prefix(certainCount) {
            XCTAssertGreaterThanOrEqual(rect.y + 1e-9, 200, "确定区域不得越过 y=0")
        }
        for rect in uncertain.prefix(min(uncertainTotal, uncertain.count)) {
            XCTAssertLessThan(abs(rect.y + rect.h / 2 - 200), 8, "不确定格应贴着边界")
        }
    }

    // MARK: - S4 Swift 区间内核性质

    func testIntervalEnclosesPointSamplesAcrossCorpus() throws {
        // 包含性（区间算术的根本契约）：盒内任意可定义点的取值 ∈ [lo, hi]。
        let corpus = [
            "x^2 - y^2(x+1)", "sin(x)cos(y)", "1/(x-y)", "sqrt(x)+ln(y)",
            "tan(x/3)", "e^x/(1+x^2)", "abs(x)-abs(y)", "x^y", "log(x*y)",
        ]
        let boxes: [(Double, Double, Double, Double)] = [
            (-1, 1, -1, 1), (0.1, 2.3, 0.5, 4), (-5, -0.2, 1, 6),
            (-0.001, 0.001, -0.001, 0.001), (2, 100, -3, 3),
        ]
        for source in corpus {
            let expr = try XCTUnwrap(GraphExpression(rawTwoVariable: source), source)
            for (xLo, xHi, yLo, yHi) in boxes {
                let r = expr.evaluateInterval(xLo: xLo, xHi: xHi, yLo: yLo, yHi: yHi)
                if case .nowhereDefined = r.domain {
                    // 声称处处未定义 → 任何采样点都不得有定义值。
                    for i in 0...8 {
                        for j in 0...8 {
                            let x = xLo + (xHi - xLo) * Double(i) / 8
                            let y = yLo + (yHi - yLo) * Double(j) / 8
                            XCTAssertNil(expr.evaluate(x: x, y: y), "\(source) 在 (\(x),\(y)) 有定义却报 nowhereDefined")
                        }
                    }
                    continue
                }
                for i in 0...8 {
                    for j in 0...8 {
                        let x = xLo + (xHi - xLo) * Double(i) / 8
                        let y = yLo + (yHi - yLo) * Double(j) / 8
                        guard let v = expr.evaluate(x: x, y: y) else {
                            if case .defined = r.domain {
                                XCTFail("\(source) 报 defined 但在 (\(x),\(y)) 未定义")
                            }
                            continue
                        }
                        XCTAssertGreaterThanOrEqual(v, r.lo, "\(source) @(\(x),\(y)) 低于下界")
                        XCTAssertLessThanOrEqual(v, r.hi, "\(source) @(\(x),\(y)) 高于上界")
                    }
                }
            }
        }
    }

    func testIntervalSpecialShapes() throws {
        // sin 跨整周期 → 恰为 [-1,1]（含端点极值）。
        let sinE = try XCTUnwrap(GraphExpression(rawTwoVariable: "sin(x)"))
        let wide = sinE.evaluateInterval(xLo: -10, xHi: 10, yLo: 0, yHi: 0)
        XCTAssertLessThanOrEqual(wide.lo, -1)
        XCTAssertGreaterThanOrEqual(wide.hi, 1)
        // 窄区间含极大值 π/2 → hi 必须达到 1（gridPointIn 极值检测）。
        let peak = sinE.evaluateInterval(xLo: 1.5, xHi: 1.6, yLo: 0, yHi: 0)
        XCTAssertGreaterThanOrEqual(peak.hi, 1)
        XCTAssertLessThan(peak.lo, sin(1.5) + 1e-9)

        // 除以含 0 区间 → 可能未定义，包络为全线。
        let inv = try XCTUnwrap(GraphExpression(rawTwoVariable: "1/x"))
        let r = inv.evaluateInterval(xLo: -1, xHi: 1, yLo: 0, yHi: 0)
        XCTAssertEqual(r.domain, .maybeDefined)
        XCTAssertEqual(r.lo, -.infinity)
        XCTAssertEqual(r.hi, .infinity)

        // sqrt 部分定义域：[-1,4] → maybeDefined，值域 ⊇ [0,2]。
        let sq = try XCTUnwrap(GraphExpression(rawTwoVariable: "sqrt(x)"))
        let s = sq.evaluateInterval(xLo: -1, xHi: 4, yLo: 0, yHi: 0)
        XCTAssertEqual(s.domain, .maybeDefined)
        XCTAssertLessThanOrEqual(s.lo, 0)
        XCTAssertGreaterThanOrEqual(s.hi, 2)
        // 全负 → nowhereDefined。
        XCTAssertEqual(sq.evaluateInterval(xLo: -4, xHi: -1, yLo: 0, yHi: 0).domain, .nowhereDefined)

        // ln 全非正 → nowhereDefined。
        let ln = try XCTUnwrap(GraphExpression(rawTwoVariable: "ln(x)"))
        XCTAssertEqual(ln.evaluateInterval(xLo: -3, xHi: -1, yLo: 0, yHi: 0).domain, .nowhereDefined)
    }
}
