// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 数值函数分析器：在 Mock 引擎（GraphExpression）之上，用纯数值方法给出
// 原版 IGraphAnalyzer 的核心结果——零点、y 截距、极大/极小值。
// 后续接入 Giac 后，可换成 CAS 的符号分析；本接口（GraphAnalysis）保持稳定。

import Foundation

/// 单条方程在给定 x 区间上的分析结果。
struct GraphAnalysis {
    struct Point {
        var x: Double
        var y: Double
    }

    var yIntercept: Double?
    var zeros: [Double] = []
    var minima: [Point] = []
    var maxima: [Point] = []

    var isEmpty: Bool {
        yIntercept == nil && zeros.isEmpty && minima.isEmpty && maxima.isEmpty
    }
}

enum GraphAnalyzer {
    /// 采样列数：区间越宽采样越密，兼顾精度与耗时。
    private static let sampleCount = 2000

    /// 在 [xMin, xMax] 上分析表达式。
    static func analyze(_ expr: GraphExpression, xMin: Double, xMax: Double) -> GraphAnalysis {
        var result = GraphAnalysis()
        guard xMax > xMin else { return result }

        // y 截距：x=0 在区间内才有意义。
        if xMin <= 0, 0 <= xMax {
            result.yIntercept = expr.evaluate(x: 0)
        }

        let step = (xMax - xMin) / Double(sampleCount)

        // 逐点采样，记录 (x, y)；定义域外为 nil。
        var xs = [Double](repeating: 0, count: sampleCount + 1)
        var ys = [Double?](repeating: nil, count: sampleCount + 1)
        for i in 0...sampleCount {
            let x = xMin + Double(i) * step
            xs[i] = x
            ys[i] = expr.evaluate(x: x)
        }

        // 零点：相邻采样点异号 → 二分细化。
        var zeros: [Double] = []
        for i in 0..<sampleCount {
            guard let y0 = ys[i], let y1 = ys[i + 1] else { continue }
            if y0 == 0 { appendUnique(&zeros, xs[i]) }
            if y0 * y1 < 0 {
                let root = bisectRoot(expr, xs[i], xs[i + 1])
                appendUnique(&zeros, root)
            }
        }
        result.zeros = zeros

        // 极值：一阶差分符号翻转 → 内部采样点为局部极大/极小。
        for i in 1..<sampleCount {
            guard let yPrev = ys[i - 1], let yCur = ys[i], let yNext = ys[i + 1] else { continue }
            let slopeL = yCur - yPrev
            let slopeR = yNext - yCur
            if slopeL > 0, slopeR < 0 {
                result.maxima.append(.init(x: xs[i], y: yCur))
            } else if slopeL < 0, slopeR > 0 {
                result.minima.append(.init(x: xs[i], y: yCur))
            }
        }

        return result
    }

    /// 二分法在 [a, b]（已知异号）细化零点。
    private static func bisectRoot(_ expr: GraphExpression, _ a: Double, _ b: Double) -> Double {
        var lo = a, hi = b
        guard var fLo = expr.evaluate(x: lo) else { return (a + b) / 2 }
        for _ in 0..<60 {
            let mid = (lo + hi) / 2
            guard let fMid = expr.evaluate(x: mid) else { return mid }
            if fMid == 0 || (hi - lo) < 1e-12 { return mid }
            if fLo * fMid < 0 {
                hi = mid
            } else {
                lo = mid
                fLo = fMid
            }
        }
        return (lo + hi) / 2
    }

    /// 去重追加（合并极近的根，避免采样抖动产生重复）。
    private static func appendUnique(_ arr: inout [Double], _ value: Double) {
        if let last = arr.last, abs(last - value) < 1e-6 { return }
        arr.append(value)
    }
}
