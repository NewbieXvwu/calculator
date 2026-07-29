// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Giac(CAS) 符号数学求解器：对应原版 GraphingInterfaces 的 IMathSolver +
// IGraphAnalyzer 职责（解析/求值/格式化 + 零点/极值/拐点/渐近线/奇偶性/定义域）。
// GraphExpression 负责把计算器输入语法序列化为 Giac 语法（giacForm），
// 本类型把 Giac 的输出（"list[...]"、"x>=1"、"+infinity" 等）解析回结构化结果。

import Foundation
import GiacBridge

/// 符号函数分析结果（对应原版 KeyGraphFeaturesInfo 全字段）。
struct GiacFunctionAnalysis {
    enum Parity { case even, odd, none }

    var domain: String?
    var range: String?
    var parity: Parity = .none
    var zeros: [String] = []
    var yIntercept: String?
    var minima: [(x: String, y: String)] = []
    var maxima: [(x: String, y: String)] = []
    var inflectionPoints: [(x: String, y: String)] = []
    var verticalAsymptotes: [String] = []
    var horizontalAsymptotes: [String] = []
    var obliqueAsymptotes: [String] = []
    /// 周期表达式；"非周期" 表示确认非周期，nil 表示未知/不适用。
    var periodicity: String?
    /// 单调区间 →（递增/递减/恒定）。
    var monotonicity: [(interval: String, direction: String)] = []
    /// 太复杂无法计算的特征名（对应 TooComplexFeatures 降级提示）。
    var tooComplexFeatures: [String] = []

    var isEmpty: Bool {
        domain == nil && range == nil && parity == .none && zeros.isEmpty && yIntercept == nil
            && minima.isEmpty && maxima.isEmpty && inflectionPoints.isEmpty
            && verticalAsymptotes.isEmpty && horizontalAsymptotes.isEmpty
            && obliqueAsymptotes.isEmpty && periodicity == nil && monotonicity.isEmpty
            && tooComplexFeatures.isEmpty
    }
}

enum GiacMathSolver {
    /// 串行化分析：all_trig_solutions 是 giac 全局标志，避免并发分析互相污染。
    private static let analysisLock = NSLock()

    /// 对显式函数 y=f(x) 做符号分析。Giac 求解失败的子项将被跳过（返回部分结果）。
    static func analyze(_ expr: GraphExpression, params: [String: Double] = [:], trig: GraphTrigMode = .radians) -> GiacFunctionAnalysis {
        analysisLock.lock()
        defer { analysisLock.unlock() }

        let f = expr.giacForm(params: params, trig: trig)
        var a = GiacFunctionAnalysis()

        if let d = ask("domain(\(f),x)"), d != "x" {
            // "x" 表示全体实数，不必展示。
            a.domain = prettify(d)
        }

        if ask("normal(subst(\(f),x=-x)-(\(f)))") == "0" {
            a.parity = .even
        } else if ask("normal(subst(\(f),x=-x)+(\(f)))") == "0" {
            a.parity = .odd
        }

        // 零点：开 all_trig_solutions 取周期通解（sin → n·π 形式）。
        _ = ask("all_trig_solutions:=1")
        a.zeros = list(ask("solve(\(f)=0,x)")).map(prettify)
        _ = ask("all_trig_solutions:=0")

        if let y0 = ask("subst(\(f),x=0)"), isFiniteResult(y0) {
            a.yIntercept = prettify(y0)
        }

        // 驻点 + 二阶导符号判别极大/极小（保留具体解，供单调性与值域用）。
        let stationary = list(ask("solve(diff(\(f),x)=0,x)"))
        var extremaY: [(exact: String, value: Double, isMax: Bool)] = []
        for r in stationary {
            guard let second = ask("sign(subst(diff(\(f),x,2),x=\(r)))"),
                  let y = ask("normal(subst(\(f),x=\(r)))"), isFiniteResult(y)
            else { continue }
            let point = (x: prettify(r), y: prettify(y))
            if second == "1" {
                a.minima.append(point)
                if let v = numeric(y) { extremaY.append((y, v, false)) }
            } else if second == "-1" {
                a.maxima.append(point)
                if let v = numeric(y) { extremaY.append((y, v, true)) }
            }
        }

        for r in list(ask("solve(diff(\(f),x,2)=0,x)")) {
            // 二阶导为零且三阶导非零 → 拐点。
            guard ask("sign(subst(diff(\(f),x,3),x=\(r)))") != "0",
                  let y = ask("normal(subst(\(f),x=\(r)))"), isFiniteResult(y)
            else { continue }
            a.inflectionPoints.append((x: prettify(r), y: prettify(y)))
        }

        let verticalRoots = list(ask("solve(denom(normal(\(f)))=0,x)"))
        a.verticalAsymptotes = verticalRoots.map { "x = \(prettify($0))" }

        var horizontals = Set<String>()
        var infLimits: [String] = []
        for direction in ["inf", "-inf"] {
            if let lim = ask("limit(\(f),x,\(direction))") {
                infLimits.append(lim)
                if isFiniteResult(lim) {
                    horizontals.insert("y = \(prettify(lim))")
                }
            }
        }
        a.horizontalAsymptotes = horizontals.sorted()

        // 斜渐近线：k=lim f/x（有限且非零），b=lim f-kx（有限）→ y = k·x + b。
        var obliques = Set<String>()
        for direction in ["inf", "-inf"] {
            guard let k = ask("limit((\(f))/x,x,\(direction))"), isFiniteResult(k), k != "0",
                  let b = ask("limit((\(f))-(\(k))*x,x,\(direction))"), isFiniteResult(b)
            else { continue }
            let kPart = k == "1" ? "x" : "\(prettify(k))·x"
            if b == "0" {
                obliques.insert("y = \(kPart)")
            } else if b.hasPrefix("-") {
                obliques.insert("y = \(kPart) - \(prettify(String(b.dropFirst())))")
            } else {
                obliques.insert("y = \(kPart) + \(prettify(b))")
            }
        }
        a.obliqueAsymptotes = obliques.sorted()

        // 周期性：period(f,x)="+infinity" 表示非周期。
        if let p = ask("period(\(f),x)") {
            a.periodicity = p == "+infinity" ? "非周期" : prettify(p)
        }

        // 单调区间：驻点 + 垂直渐近线切分实轴，区间中点看一阶导符号。
        a.monotonicity = monotonicIntervals(f: f, breakRoots: stationary + verticalRoots)

        // 值域：极值 + 无穷极限 + 垂直渐近线单侧极限的启发式组合。
        if let range = estimateRange(
            f: f, extremaY: extremaY, infLimits: infLimits, verticalRoots: verticalRoots) {
            a.range = range
        } else if !infLimits.isEmpty || !extremaY.isEmpty {
            // 有部分信息但拼不出可靠值域 → 按原版报"太复杂"。
            a.tooComplexFeatures.append("值域")
        }

        return a
    }

    /// 单调区间表：断点数值排序后逐段采样 f' 符号。
    private static func monotonicIntervals(f: String, breakRoots: [String]) -> [(interval: String, direction: String)] {
        var points: [(exact: String, value: Double)] = []
        for r in breakRoots {
            // 含参数通解（n_0 等）无法数值化，跳过。
            guard let v = numeric(r) else { continue }
            if !points.contains(where: { abs($0.value - v) < 1e-9 }) {
                points.append((prettify(r), v))
            }
        }
        points.sort { $0.value < $1.value }

        var result: [(String, String)] = []
        let count = points.count
        for i in 0...count {
            let loExact = i == 0 ? "-∞" : points[i - 1].exact
            let hiExact = i == count ? "+∞" : points[i].exact
            let mid: Double
            if count == 0 {
                mid = 0
            } else if i == 0 {
                mid = points[0].value - 1
            } else if i == count {
                mid = points[count - 1].value + 1
            } else {
                mid = (points[i - 1].value + points[i].value) / 2
            }
            guard let s = ask("sign(subst(diff(\(f),x),x=\(mid)))") else { continue }
            let direction: String
            switch s {
            case "1": direction = "递增"
            case "-1": direction = "递减"
            case "0": direction = "恒定"
            default: continue
            }
            result.append(("(\(loExact), \(hiExact))", direction))
        }

        // 全程恒定或单一区间且无断点时合并展示。
        return result
    }

    /// 值域启发式：无穷极限给无界性，极值给达界值；拼不出可靠区间返回 nil。
    private static func estimateRange(
        f: String,
        extremaY: [(exact: String, value: Double, isMax: Bool)],
        infLimits: [String],
        verticalRoots: [String]) -> String?
    {
        var upperUnbounded = false
        var lowerUnbounded = false
        var finiteLimits: [(exact: String, value: Double)] = []

        for lim in infLimits {
            if lim == "+infinity" { upperUnbounded = true }
            if lim == "-infinity" { lowerUnbounded = true }
            if isFiniteResult(lim), let v = numeric(lim) { finiteLimits.append((prettify(lim), v)) }
        }

        // 垂直渐近线单侧极限贡献无界性。
        for r in verticalRoots {
            guard numeric(r) != nil else { continue }
            for side in ["1", "-1"] {
                guard let lim = ask("limit(\(f),x,\(r),\(side))") else { continue }
                if lim == "+infinity" { upperUnbounded = true }
                if lim == "-infinity" { lowerUnbounded = true }
            }
        }

        if upperUnbounded && lowerUnbounded { return "(-∞, +∞)" }

        // 有界候选：极值（达到）与有限极限（趋近）。
        let achievedMin = extremaY.filter { !$0.isMax }.min { $0.value < $1.value }
        let achievedMax = extremaY.filter { $0.isMax }.max { $0.value < $1.value }
        let limitMin = finiteLimits.min { $0.value < $1.value }
        let limitMax = finiteLimits.max { $0.value < $1.value }

        if upperUnbounded {
            if let m = achievedMin, limitMin == nil || m.value <= limitMin!.value {
                return "[\(m.exact), +∞)"
            }
            if let l = limitMin, achievedMin == nil {
                return "(\(l.exact), +∞)"
            }
            return nil
        }
        if lowerUnbounded {
            if let m = achievedMax, limitMax == nil || m.value >= limitMax!.value {
                return "(-∞, \(m.exact)]"
            }
            if let l = limitMax, achievedMax == nil {
                return "(-∞, \(l.exact))"
            }
            return nil
        }

        // 双侧有界：需要极大与极小同时可达（如 sin：[-1, 1]）。
        if let lo = achievedMin, let hi = achievedMax, lo.value <= hi.value {
            return "[\(lo.exact), \(hi.exact)]"
        }
        return nil
    }

    /// 数值化一个 giac 精确表达式（evalf）；失败返回 nil。
    private static func numeric(_ exact: String) -> Double? {
        // 已是纯数字直接解析。
        if let v = Double(exact) { return v }
        guard exact.range(of: #"n_\d+"#, options: .regularExpression) == nil,
              let out = ask("evalf(\(exact))") else { return nil }
        return Double(out)
    }

    /// 解析并求值一条 Giac 表达式；出错返回 nil（对应 IMathSolver::ParseInput+Serialize）。
    static func ask(_ query: String) -> String? {
        let out = GiacEngine.evaluate(query)
        if out.hasPrefix("GIAC_ERROR") || out.contains("Error") || out == "undef" || out.isEmpty {
            return nil
        }
        return out
    }

    /// 把 "list[-2,2]" / "[-2,2]" 拆成顶层元素；"[]"、nil → 空数组。
    static func list(_ raw: String?) -> [String] {
        guard var s = raw else { return [] }
        if s.hasPrefix("list") { s.removeFirst(4) }
        guard s.hasPrefix("["), s.hasSuffix("]") else { return s.isEmpty ? [] : [s] }
        s = String(s.dropFirst().dropLast())
        guard !s.isEmpty else { return [] }
        var items: [String] = []
        var depth = 0
        var current = ""
        for c in s {
            switch c {
            case "[", "(": depth += 1; current.append(c)
            case "]", ")": depth -= 1; current.append(c)
            case "," where depth == 0:
                items.append(current)
                current = ""
            default: current.append(c)
            }
        }
        if !current.isEmpty { items.append(current) }
        return items
    }

    /// 展示层格式化（对应 IFormatOptions 的角色）：还原常量记号、去掉乘号噪音。
    static func prettify(_ s: String) -> String {
        s.replacingOccurrences(of: "exp(1)", with: "e")
            .replacingOccurrences(of: "pi", with: "π")
            .replacingOccurrences(of: "*", with: "·")
            // all_trig_solutions 通解变量 n_0/n_1… → n（展示为 n·π 之类）。
            .replacingOccurrences(of: #"n_\d+"#, with: "n", options: .regularExpression)
    }

    private static func isFiniteResult(_ s: String) -> Bool {
        if s.contains("infinity") || s.contains("undef") { return false }
        // 拒绝复数结果：匹配独立的虚数单位 i（避开 sin/pi 等标识符里的字母 i）。
        return s.range(of: #"(^|[^a-z])i([^a-z]|$)"#, options: .regularExpression) == nil
    }
}
