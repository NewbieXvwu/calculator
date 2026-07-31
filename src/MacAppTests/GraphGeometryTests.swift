// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// S7 图形几何下沉的平价测试：graph_geometry.h（C ABI 共享层）与 macOS 首发
// 实现（GraphingView / GraphingViewModel / MarchingSquares）语义逐项锁定。
// 任何一侧改动而另一侧未同步即红。

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

@MainActor
final class GraphGeometryTests: XCTestCase {
    private func makeViewport(
        xMin: Double = -10, xMax: Double = 10, yMin: Double = -10, yMax: Double = 10,
        width: Double = 400, height: Double = 300
    ) -> graph_viewport_t {
        graph_viewport_t(x_min: xMin, x_max: xMax, y_min: yMin, y_max: yMax, width: width, height: height)
    }

    // MARK: - 坐标变换

    func testTransformsMatchViewFormulasAndRoundTrip() {
        var vp = makeViewport(xMin: -3, xMax: 7, yMin: -2, yMax: 4, width: 500, height: 320)
        // GraphCanvas.toScreenX/Y 的公式镜像。
        XCTAssertEqual(graph_to_screen_x(&vp, -3), 0, accuracy: 1e-12)
        XCTAssertEqual(graph_to_screen_x(&vp, 7), 500, accuracy: 1e-12)
        XCTAssertEqual(graph_to_screen_x(&vp, 2), 250, accuracy: 1e-12)
        XCTAssertEqual(graph_to_screen_y(&vp, -2), 320, accuracy: 1e-12)  // 数学 y 向上翻转
        XCTAssertEqual(graph_to_screen_y(&vp, 4), 0, accuracy: 1e-12)
        XCTAssertEqual(graph_to_screen_y(&vp, 1), 160, accuracy: 1e-12)

        for v in stride(from: 0.0, through: 500, by: 47) {
            XCTAssertEqual(graph_to_screen_x(&vp, graph_to_math_x(&vp, v)), v, accuracy: 1e-9)
        }
        for v in stride(from: 0.0, through: 320, by: 37) {
            XCTAssertEqual(graph_to_screen_y(&vp, graph_to_math_y(&vp, v)), v, accuracy: 1e-9)
        }
    }

    // MARK: - 刻度（1-2-5）

    func testNiceStepCoversAll125Branches() {
        // GraphCanvas.niceStep：rough=span/target → {1,2,5,10}×10^n。
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
        // drawGrid：x = (min/step).rounded(.up)*step; while x <= max。
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

    // MARK: - 视窗操作 ⇄ GraphingViewModel

    func testViewportOpsMatchViewModel() {
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

        // 拒绝条件同 GraphingViewModel.applyRange。
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

    func testAutoFitMatchesViewModel() throws {
        let vm = GraphingViewModel()  // 自带 x^2 与 sin(x)
        // 与 autoFitView 相同的采样（512 段，两条可见曲线依次追加）。
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

        var lo = 0.0, hi = 0.0
        XCTAssertTrue(graph_auto_fit_y(ys, ys.count, &lo, &hi))
        vm.autoFitView()
        XCTAssertEqual(lo, vm.yMin, accuracy: 1e-9)
        XCTAssertEqual(hi, vm.yMax, accuracy: 1e-9)

        // 退化值域：全常数 → ±1 再加 10% 边距。
        XCTAssertTrue(graph_auto_fit_y([3.0, 3.0, 3.0], 3, &lo, &hi))
        XCTAssertEqual(lo, 2 - 0.2, accuracy: 1e-12)
        XCTAssertEqual(hi, 4 + 0.2, accuracy: 1e-12)
        XCTAssertFalse(graph_auto_fit_y(nil, 0, &lo, &hi))
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
        // y = 1/x：x=0 恰在第 200 列（未定义），渐近线两侧还各有一次
        // 超过 1.5 倍画布高的跳变断裂 → 与 drawCurve 逐列循环全量平价。
        let vpValue = makeViewport(xMin: -5, xMax: 5, yMin: -5, yMax: 5)
        var vp = vpValue
        let f: (Double) -> Double? = { x in x == 0 ? nil : 1 / x }
        let box = EvalBox(f1: f)
        let ctx = Unmanaged.passUnretained(box).toOpaque()
        var out = [graph_sample_t](repeating: graph_sample_t(), count: 401)
        let count = graph_sample_curve(&vp, evalThunk1, ctx, &out, out.count)

        // drawCurve 的采样循环镜像（GraphingView.swift）。
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

    // MARK: - Marching squares ⇄ MarchingSquares.trace

    func testMarchingSquaresParityWithSwift() {
        let f: (Double, Double) -> Double? = { x, y in
            // 圆 + 左半平面未定义洞，覆盖 nil 传播与鞍点消歧路径。
            x < -9 ? nil : x * x + y * y - 25
        }
        let swiftSegments = MarchingSquares.trace(
            f: f, xMin: -10, xMax: 10, yMin: -8, yMax: 8, cols: 64, rows: 48)

        let box = EvalBox(f2: f)
        let ctx = Unmanaged.passUnretained(box).toOpaque()
        var out = [graph_segment_t](repeating: graph_segment_t(), count: 2 * 64 * 48)
        let count = graph_marching_squares(-10, 10, -8, 8, 64, 48, evalThunk2, ctx, &out, out.count)

        XCTAssertEqual(Int(count), swiftSegments.count)
        XCTAssertGreaterThan(count, 0)
        for (i, seg) in swiftSegments.enumerated() {
            XCTAssertEqual(out[i].x1, seg.x1, accuracy: 1e-12, "seg[\(i)].x1")
            XCTAssertEqual(out[i].y1, seg.y1, accuracy: 1e-12, "seg[\(i)].y1")
            XCTAssertEqual(out[i].x2, seg.x2, accuracy: 1e-12, "seg[\(i)].x2")
            XCTAssertEqual(out[i].y2, seg.y2, accuracy: 1e-12, "seg[\(i)].y2")
        }

        // 非法网格安全。
        XCTAssertEqual(graph_marching_squares(0, 1, 0, 1, 0, 4, evalThunk2, ctx, nil, 0), 0)
    }

    func testMarchingSquaresSaddleParity() {
        // 双曲线 xy=1 网格粗采样必然出现鞍点格。
        let f: (Double, Double) -> Double? = { x, y in x * y - 1 }
        let swiftSegments = MarchingSquares.trace(
            f: f, xMin: -4, xMax: 4, yMin: -4, yMax: 4, cols: 9, rows: 9)

        let box = EvalBox(f2: f)
        let ctx = Unmanaged.passUnretained(box).toOpaque()
        var out = [graph_segment_t](repeating: graph_segment_t(), count: 2 * 9 * 9)
        let count = graph_marching_squares(-4, 4, -4, 4, 9, 9, evalThunk2, ctx, &out, out.count)

        XCTAssertEqual(Int(count), swiftSegments.count)
        for (i, seg) in swiftSegments.enumerated() {
            XCTAssertEqual(out[i].x1, seg.x1, accuracy: 1e-12)
            XCTAssertEqual(out[i].y1, seg.y1, accuracy: 1e-12)
            XCTAssertEqual(out[i].x2, seg.x2, accuracy: 1e-12)
            XCTAssertEqual(out[i].y2, seg.y2, accuracy: 1e-12)
        }
    }

    // MARK: - 不等式

    func testRelationTableMatchesSwift() {
        let pairs: [(graph_relation_t, InequalityRelation)] = [
            (GRAPH_REL_LESS, .lessThan),
            (GRAPH_REL_LESS_EQUAL, .lessOrEqual),
            (GRAPH_REL_GREATER, .greaterThan),
            (GRAPH_REL_GREATER_EQUAL, .greaterOrEqual),
        ]
        for (cRel, swiftRel) in pairs {
            for f in [-1.0, 0.0, 1.0, -1e-300, 1e-300] {
                XCTAssertEqual(graph_relation_satisfied(cRel, f), swiftRel.satisfied(f), "\(swiftRel) f=\(f)")
            }
            XCTAssertEqual(graph_relation_is_strict(cRel), swiftRel.isStrict, "\(swiftRel)")
        }
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
        XCTAssertEqual(graph_cell_count(10, 3), 8)  // max(8, …) 下限同 Swift
    }

    // MARK: - 跟踪吸附 ⇄ nearestCurvePoint

    func testTraceSnapMatchesNearestCurvePoint() throws {
        let vm = GraphingViewModel()  // x^2、sin(x)
        let mathX = 1.3, mathY = 1.1
        let snap = try XCTUnwrap(vm.nearestCurvePoint(mathX: mathX, mathY: mathY))

        // 按可见方程序号构造候选 y 值（不可见/未定义 → NaN），与 VM 同一口径。
        var ys: [Double] = []
        var indexMap: [Int] = []
        for (index, eq) in vm.equations.enumerated() where eq.isVisible {
            guard let expr = eq.explicitExpression,
                  let y = expr.evaluate(x: mathX, params: vm.parameters, trig: vm.trigMode) else { continue }
            ys.append(y)
            indexMap.append(index)
        }
        let picked = graph_trace_snap(ys, ys.count, mathY, vm.ySpan)
        XCTAssertGreaterThanOrEqual(picked, 0)
        XCTAssertEqual(indexMap[Int(picked)], snap.equationIndex)
        XCTAssertEqual(ys[Int(picked)], snap.y, accuracy: 1e-12)

        // 全 NaN → -1。
        XCTAssertEqual(graph_trace_snap([Double.nan, .nan], 2, 0, 20), -1)
    }
}
