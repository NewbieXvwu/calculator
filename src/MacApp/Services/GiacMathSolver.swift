// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Giac(CAS) 符号数学求解器：对应原版 GraphingInterfaces 的 IMathSolver +
// IGraphAnalyzer 职责（解析/求值/格式化 + 零点/极值/拐点/渐近线/奇偶性/定义域）。
//
// 诚实性契约（S3，元规则 M4）：任何字段在无法可靠计算时必须进
// tooComplexFeatures，绝不显示看似合理的错误答案。为此：
//   R1  giac 特殊记号（bounded_function/undef/infinity/…）走白名单过滤，
//       bounded_function 在水平渐近线语境里是"确定没有"的信号；
//   R2  值域从「驻点值 ∪ 端点极限 ∪ VA 单侧极限 ∪ 挖点极限」构造，
//       构造不出完整结构就报 too complex，不从上下界瞎推；
//   R3  捕获 giac stderr 的 "Auto assume" 警告（三角方程被截断到主区间），
//       检测到即把受影响字段标 too complex，不把主区间结论外推到 ℝ；
//   R4  捕获 "bisection"/"switching to approx" 警告与点数阈值，数值兜底解
//       不冒充完备列表；
//   R5  giac 的 sign() 对浮点返回 "-1.0"，一律数值解析，不做字符串精确比较；
//   R6  period()==0 表示"任意周期/不适用"（常函数），不显示周期字段。
// 性能治理：单次分析查询预算 100 条 + 总时限，超限剩余字段标 too complex。

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
    /// 串行化分析：all_trig_solutions 与 assume 是 giac 全局状态，避免并发分析互相污染。
    private static let analysisLock = NSLock()

    /// 单函数分析预算（查询条数 / 总时限秒）。超限即中止，剩余字段标 too complex。
    private static let queryBudget = 100
    private static let timeBudget: TimeInterval = 1.8

    /// 单个 solve 结果的点数上限：超过视为数值兜底解洪水（R4）。
    private static let maxSolutionCount = 20

    // MARK: - 会话（预算与警告聚合）

    private struct Session {
        var deadline = Date.distantFuture
        var queriesLeft = Int.max
        var exhausted = false
        /// 任一查询触发过 "Auto assume"（三角主区间截断）→ 结构性结论不可信。
        var sawAutoAssume = false
    }

    private static var session = Session()

    private struct QueryOutcome {
        var output: String?
        var warnings: String

        var autoAssumed: Bool { warnings.contains("Auto assume") }
        /// giac 从符号求解回退到数值 bisection 的信号（R4）。
        var approximate: Bool {
            warnings.contains("bisection") || warnings.contains("switching to approx")
                || warnings.contains("approx. solutions")
        }
    }

    private static func query(_ q: String) -> QueryOutcome {
        guard !session.exhausted, session.queriesLeft > 0, Date() < session.deadline else {
            session.exhausted = true
            return QueryOutcome(output: nil, warnings: "")
        }
        session.queriesLeft -= 1
        var warn: NSString?
        let out = GiacEngine.evaluate(q, warningsOut: &warn)
        let warnings = (warn as String?) ?? ""
        if warnings.contains("Auto assume") { session.sawAutoAssume = true }
        let output: String?
        if out.hasPrefix("GIAC_ERROR") || out.contains("Error") || out == "undef" || out.isEmpty {
            output = nil
        } else {
            output = out
        }
        return QueryOutcome(output: output, warnings: warnings)
    }

    // MARK: - 字段（too complex 记录用；顺序 = 原版 XAML 字段显示顺序）

    private enum Field: Int, CaseIterable {
        case domain, range, xIntercept, minima, maxima, inflection
        case verticalAsymptotes, horizontalAsymptotes, obliqueAsymptotes, monotonicity

        var localizedName: String {
            switch self {
            case .domain: return L10n.string("Domain")
            case .range: return L10n.string("Range")
            case .xIntercept: return L10n.string("XIntercept")
            case .minima: return L10n.string("Minima")
            case .maxima: return L10n.string("Maxima")
            case .inflection: return L10n.string("InflectionPoints")
            case .verticalAsymptotes: return L10n.string("VerticalAsymptotes")
            case .horizontalAsymptotes: return L10n.string("HorizontalAsymptotes")
            case .obliqueAsymptotes: return L10n.string("ObliqueAsymptotes")
            case .monotonicity: return L10n.string("Monotonicity")
            }
        }
    }

    // MARK: - 基础结构

    private struct Breakpoint {
        var exact: String
        var value: Double
    }

    private struct ValueCandidate {
        var exact: String
        var value: Double
        /// true = 该值被函数取到（驻点/不可导点/闭端点）；false = 仅极限趋近。
        var attained: Bool
    }

    /// 解析后的定义域：`[lower, upper]` 去掉 excluded 点。nil 界 = 无穷。
    private struct DomainInfo {
        var lower: Breakpoint?
        var lowerIncluded = false
        var upper: Breakpoint?
        var upperIncluded = false
        var excluded: [Breakpoint] = []

        var isFullLine: Bool { lower == nil && upper == nil && excluded.isEmpty }

        func containsPoint(_ x: Double) -> Bool {
            if let lo = lower {
                if x < lo.value - 1e-12 { return false }
                if abs(x - lo.value) <= 1e-12 && !lowerIncluded { return false }
            }
            if let hi = upper {
                if x > hi.value + 1e-12 { return false }
                if abs(x - hi.value) <= 1e-12 && !upperIncluded { return false }
            }
            return !excluded.contains { abs($0.value - x) <= 1e-12 }
        }

        /// 严格内点（不含端点）。
        func strictlyInside(_ x: Double) -> Bool {
            if let lo = lower, x <= lo.value + 1e-12 { return false }
            if let hi = upper, x >= hi.value - 1e-12 { return false }
            return !excluded.contains { abs($0.value - x) <= 1e-12 }
        }
    }

    // MARK: - 主入口

    /// 对显式函数 y=f(x) 做符号分析。无法可靠计算的字段进 tooComplexFeatures。
    static func analyze(_ expr: GraphExpression, params: [String: Double] = [:], trig: GraphTrigMode = .radians) -> GiacFunctionAnalysis {
        analysisLock.lock()
        defer {
            session = Session()
            _ = GiacEngine.evaluate("all_trig_solutions:=0")
            analysisLock.unlock()
        }
        session = Session(
            deadline: Date().addingTimeInterval(timeBudget),
            queriesLeft: queryBudget,
            exhausted: false,
            sawAutoAssume: false)

        let f = expr.giacForm(params: params, trig: trig)
        var a = GiacFunctionAnalysis()
        var tooComplex = Set<Field>()

        // ── 定义域查询提前（常函数捷径依赖它）──
        let domainQ = query("domain(\(f),x)")

        // ── 常函数捷径：f' ≡ 0 且定义域为全线 ──
        // 必须先看定义域：giac 对 abs(x)/x 类分段函数求导可能误报 0（实测
        // normal(diff(abs(x)/x,x)) == "0"），此时 domain 会给出 x<>0，
        // 绝不允许走捷径——否则 domain/range/parity/monotonicity 全部给出
        // 自信的错误答案（S1：诚实性契约第一条防线）。
        if let d1 = query("normal(diff(\(f),x))").output, d1 == "0",
           domainQ.output == "x", !domainQ.autoAssumed,
           let c = query("normal(\(f))").output, isDisplayableFinite(c) {
            // 白名单（攻击审查 1.3）：normal(f) 必须可展示（inf/nan/未知记号
            // 一律不走捷径——曾出现 range={+infinity} 的自信错误答案）。
            a.domain = "ℝ"
            a.range = "{\(prettify(c))}"
            a.parity = .even
            a.yIntercept = prettify(c)
            a.monotonicity = [("(-∞, +∞)", L10n.string("KGFMonotonicityConstant"))]
            // R6：period()==0（任意周期）→ 不显示周期字段。
            return a
        }

        // 全程开启三角通解（零点/驻点求解都受益；结束时 defer 复位）。
        _ = query("all_trig_solutions:=1")

        // ── 定义域（复用捷径前的 domainQ）──
        var domainInfo: DomainInfo?
        if domainQ.output == "x", !domainQ.autoAssumed || domainQ.warnings.contains("Periodic function") {
            // Auto assume 区间恰为一个完整周期（实测），周期内无排除点 ⇒ 全 ℝ 无排除点。
            domainInfo = parseDomain("x")
            a.domain = "ℝ"
        } else if domainQ.autoAssumed || domainQ.output == nil {
            // R3：giac 自动假设主区间 → 定义域被截断，不可信。
            tooComplex.insert(.domain)
        } else if let d = domainQ.output {
            domainInfo = parseDomain(d)
            a.domain = prettify(d)
        }

        // ── 奇偶性 ──
        if query("normal(subst(\(f),x=-x)-(\(f)))").output == "0" {
            a.parity = .even
        } else if query("normal(subst(\(f),x=-x)+(\(f)))").output == "0" {
            a.parity = .odd
        }

        // ── 周期性（R6）──
        var periodExact: String?
        if let p = query("period(\(f),x)").output {
            if p == "+infinity" {
                a.periodicity = L10n.string("Mac_Aperiodic")
            } else if p != "0" {
                a.periodicity = prettify(p)
                periodExact = p
            }
        }

        // ── 零点（保留三角通解族）──
        let zerosQ = query("solve(\(f)=0,x)")
        if zerosQ.output == nil || zerosQ.approximate {
            tooComplex.insert(.xIntercept)
        } else {
            let items = list(zerosQ.output)
            if items.count > maxSolutionCount || isApproxPeriodicSolution(f, items)
                || !items.allSatisfy(isDisplayableFinite) {
                // R4：数值点洪水不冒充完备列表。
                // M1：周期函数 + 全数值解 = giac 对小数输入不做通解族展开
                // （solve(sin(x)=0.5,x) 只给主区间 2 个数值根，真零点无穷多），
                // 静默展示会丢失族 → 降级，提示改用精确输入（如 1/2）。
                // 白名单（攻击审查 4.3）：任何不可展示 token 也降级。
                tooComplex.insert(.xIntercept)
            } else {
                a.zeros = items.map(prettify)
            }
        }

        // ── Y 截距 ──
        if domainInfo?.containsPoint(0) ?? true,
           let y0 = query("normal(subst(\(f),x=0))").output, isDisplayableFinite(y0) {
            a.yIntercept = prettify(y0)
        }

        // ── 驻点 ──
        let statQ = query("solve(diff(\(f),x)=0,x)")
        var stationaryTrusted = statQ.output != nil && !statQ.approximate
        var stationaryItems = stationaryTrusted ? list(statQ.output) : []
        if stationaryItems.count > maxSolutionCount || isApproxPeriodicSolution(f, stationaryItems) {
            stationaryTrusted = false
            stationaryItems = []
        }
        let stationaryParametric = stationaryItems.contains(where: isParametric)

        var numericStationary: [Breakpoint] = []
        if stationaryTrusted && !stationaryParametric {
            for r in stationaryItems {
                if let v = numericValue(r) {
                    numericStationary.append(Breakpoint(exact: r, value: v))
                } else {
                    stationaryTrusted = false
                    numericStationary = []
                    break
                }
            }
        }

        // ── 垂直渐近线（denom(normal(f)) 路径天然剔除可去奇点；tan 类分母为 1 的
        //    情况再对定义域排除点/开有限边界做单侧极限验证）──
        let vaQ = query("solve(denom(normal(\(f)))=0,x)")
        var vaTrusted = vaQ.output != nil && !vaQ.approximate && !vaQ.autoAssumed
        var vaRoots: [Breakpoint] = []
        if vaTrusted {
            for r in list(vaQ.output) {
                guard !isParametric(r), let v = numericValue(r) else {
                    vaTrusted = false
                    vaRoots = []
                    break
                }
                vaRoots.append(Breakpoint(exact: r, value: v))
            }
        }
        // true = 该侧极限为无穷；false = 确定有界；nil = 无法判定。
        func isInfiniteLimit(_ s: String?) -> Bool? {
            guard let s else { return nil }
            if s.contains("infinity") || s == "unsigned_inf" { return true }
            if s.contains("bounded_function") { return false }
            return isDisplayableFinite(s) ? false : nil
        }
        // denom 路径成功 ⇒ 极点列表可信（H2：不再整体依赖 domainInfo；
        // 探针仅用于补全 denom 路径遗漏的奇异点，如 tan 类分母为 1 的情况）。
        // 但 denom 空结果 + 定义域不可解析（tan 类参数化排除点）时 VA 状态
        // 未知 → 必须 too complex，绝不静默宣称"无 VA"（M4 诚实性）。
        if vaTrusted, vaRoots.isEmpty, domainInfo == nil {
            vaTrusted = false
        }
        if vaTrusted, let di = domainInfo {
            var probes: [Breakpoint] = di.excluded
            if let lo = di.lower, !di.lowerIncluded { probes.append(lo) }
            if let hi = di.upper, !di.upperIncluded { probes.append(hi) }
            for p in probes where !vaRoots.contains(where: { abs($0.value - p.value) <= 1e-12 }) {
                let right = isInfiniteLimit(query("limit(\(f),x,\(p.exact),1)").output)
                let left = isInfiniteLimit(query("limit(\(f),x,\(p.exact),-1)").output)
                if right == true || left == true {
                    vaRoots.append(p)
                } else if right == nil || left == nil {
                    vaTrusted = false
                    break
                }
            }
        }
        if vaTrusted {
            vaRoots.sort { $0.value < $1.value }
            a.verticalAsymptotes = vaRoots.map { "x = \(prettify($0.exact))" }
        } else {
            vaRoots = []
            tooComplex.insert(.verticalAsymptotes)
        }

        // ── 不可导点（f' 的分母零点，取定义域严格内点；abs 之类的尖点）──
        let nondiffQ = query("solve(denom(normal(diff(\(f),x)))=0,x)")
        var nondiffTrusted = nondiffQ.output != nil && !nondiffQ.approximate
        var nondiff: [Breakpoint] = []
        if nondiffTrusted {
            for r in list(nondiffQ.output) {
                guard !isParametric(r), let v = numericValue(r) else {
                    nondiffTrusted = false
                    nondiff = []
                    break
                }
                let isVA = vaRoots.contains { abs($0.value - v) <= 1e-12 }
                let isStationary = numericStationary.contains { abs($0.value - v) <= 1e-12 }
                if !isVA && !isStationary && (domainInfo?.strictlyInside(v) ?? false) {
                    nondiff.append(Breakpoint(exact: r, value: v))
                }
            }
        }

        /// 结构可信 = 驻点/不可导点均完备且无三角截断——单调性与一般值域构造的前提。
        let structureTrusted = stationaryTrusted && !stationaryParametric && nondiffTrusted
            && !session.sawAutoAssume && domainInfo != nil

        // ── 极值（二阶导判别，R5 数值解析；歧义时退一阶导变号判别）──
        var interiorWalls: [Double] = (numericStationary + nondiff + vaRoots).map(\.value)
        if let di = domainInfo {
            interiorWalls += di.excluded.map(\.value)
            if let lo = di.lower { interiorWalls.append(lo.value) }
            if let hi = di.upper { interiorWalls.append(hi.value) }
        }

        func probeDelta(around x: Double) -> Double {
            let nearest = interiorWalls.filter { abs($0 - x) > 1e-9 }.map { abs($0 - x) }.min() ?? 1
            return min(nearest / 2, 0.5)
        }

        func firstDerivativeSign(at x: Double) -> Int? {
            guard let s = query("sign(subst(diff(\(f),x),x=\(x)))").output, let v = Double(s) else { return nil }
            return v > 0 ? 1 : (v < 0 ? -1 : 0)
        }

        var extremaProblem = !structureTrusted
        var attainedValues: [ValueCandidate] = []
        /// M3：极值阶段已算好的 f(驻点/不可导点/端点) 值，按 x 数值建表，
        /// 值域构造 C-path 查表复用（避免每个驻点重复 subst+evalf 2 条查询，
        /// 驻点数接近上限时仅值域就 ~80 条查询会耗尽预算）。
        var attainedByX: [Double: ValueCandidate] = [:]

        func attainedY(at exact: String, xValue: Double? = nil) -> ValueCandidate? {
            guard let y = query("normal(subst(\(f),x=\(exact)))").output,
                  isDisplayableFinite(y), let v = numericValue(y) else { return nil }
            let c = ValueCandidate(exact: y, value: v, attained: true)
            if let xv = xValue { attainedByX[xv] = c }
            return c
        }

        if structureTrusted {
            for p in numericStationary {
                // 二阶导符号：数值解析（"-1.0" 也认，R5）。
                var kind: Int?
                if let s = query("sign(subst(diff(\(f),x,2),x=\(p.exact)))").output, let v = Double(s), v != 0 {
                    kind = v > 0 ? 1 : -1 // >0 → 极小
                }
                if kind == nil {
                    let d = probeDelta(around: p.value)
                    if let l = firstDerivativeSign(at: p.value - d),
                       let r = firstDerivativeSign(at: p.value + d), l != 0, r != 0 {
                        kind = (l < 0 && r > 0) ? 1 : ((l > 0 && r < 0) ? -1 : 0)
                    }
                }
                guard let kind else {
                    extremaProblem = true
                    continue
                }
                guard let y = attainedY(at: p.exact, xValue: p.value) else {
                    extremaProblem = true
                    continue
                }
                attainedValues.append(y)
                if kind == 1 {
                    a.minima.append((x: prettify(p.exact), y: prettify(y.exact)))
                } else if kind == -1 {
                    a.maxima.append((x: prettify(p.exact), y: prettify(y.exact)))
                }
            }

            // 不可导点（abs(x) 的 (0,0)）：一阶导变号判别。
            for p in nondiff {
                guard let y = attainedY(at: p.exact, xValue: p.value) else {
                    extremaProblem = true
                    continue
                }
                attainedValues.append(y)
                let d = probeDelta(around: p.value)
                guard let l = firstDerivativeSign(at: p.value - d),
                      let r = firstDerivativeSign(at: p.value + d), l != 0, r != 0 else {
                    extremaProblem = true
                    continue
                }
                if l < 0 && r > 0 {
                    a.minima.append((x: prettify(p.exact), y: prettify(y.exact)))
                } else if l > 0 && r < 0 {
                    a.maxima.append((x: prettify(p.exact), y: prettify(y.exact)))
                }
            }

            // 定义域闭端点（sqrt(x) 的 (0,0)）：端点单侧导数判别。
            if let di = domainInfo {
                let ends: [(Breakpoint, Bool)?] = [
                    di.lowerIncluded ? di.lower.map { ($0, true) } : nil,
                    di.upperIncluded ? di.upper.map { ($0, false) } : nil,
                ]
                for case let (bp, isLower)? in ends {
                    guard let y = attainedY(at: bp.exact, xValue: bp.value) else {
                        extremaProblem = true
                        continue
                    }
                    attainedValues.append(y)
                    let d = probeDelta(around: bp.value)
                    let inner = firstDerivativeSign(at: isLower ? bp.value + d : bp.value - d)
                    switch (inner, isLower) {
                    case (1, true), (-1, false):
                        a.minima.append((x: prettify(bp.exact), y: prettify(y.exact)))
                    case (-1, true), (1, false):
                        a.maxima.append((x: prettify(bp.exact), y: prettify(y.exact)))
                    default:
                        break // 端点侧导数为零/未知：不是可靠极值，但仍是值域候选
                    }
                }
            }
        }
        if extremaProblem {
            tooComplex.insert(.minima)
            tooComplex.insert(.maxima)
        }

        // ── 拐点 ──
        if query("normal(diff(\(f),x,2))").output == "0" {
            // 二阶导恒为 0（线性/带挖点线性/分段线性）→ 确定无拐点。
        } else {
            let inflQ = query("solve(diff(\(f),x,2)=0,x)")
            if inflQ.output == nil || inflQ.approximate || session.sawAutoAssume {
                tooComplex.insert(.inflection)
            } else {
                let items = list(inflQ.output)
                if items.count > maxSolutionCount || isApproxPeriodicSolution(f, items) {
                    tooComplex.insert(.inflection)
                } else {
                    for r in items {
                        guard !isParametric(r), let rv = numericValue(r) else {
                            tooComplex.insert(.inflection)
                            break
                        }
                        guard domainInfo?.strictlyInside(rv) ?? true else { continue }
                        // 三阶导非零 → 拐点；为零/无法判定 → 二阶导两侧变号判别。
                        var confirmed: Bool?
                        if let s = query("sign(subst(diff(\(f),x,3),x=\(r)))").output, let v = Double(s), v != 0 {
                            confirmed = true
                        }
                        if confirmed == nil {
                            let d = probeDelta(around: rv)
                            func secondSign(at x: Double) -> Int? {
                                guard let s = query("sign(subst(diff(\(f),x,2),x=\(x)))").output, let v = Double(s) else { return nil }
                                return v > 0 ? 1 : (v < 0 ? -1 : 0)
                            }
                            if let l = secondSign(at: rv - d), let rr = secondSign(at: rv + d), l != 0, rr != 0 {
                                confirmed = l != rr
                            }
                        }
                        guard let confirmed else {
                            tooComplex.insert(.inflection)
                            continue
                        }
                        guard confirmed else { continue }
                        guard let y = query("normal(subst(\(f),x=\(r)))").output, isDisplayableFinite(y) else { continue }
                        a.inflectionPoints.append((x: prettify(r), y: prettify(y)))
                    }
                }
            }
        }

        // ── 水平渐近线（R1：bounded_function = 确定无 HA）──
        var infLimitRaw: [String: String] = [:]
        var haProblem = false
        var horizontals = Set<String>()
        for direction in ["inf", "-inf"] {
            guard let lim = query("limit(\(f),x,\(direction))").output else {
                haProblem = true
                continue
            }
            infLimitRaw[direction] = lim
            if lim.contains("bounded_function") { continue } // 极限有界但不存在 → 无 HA，且确定
            if lim == "+infinity" || lim == "-infinity" || lim == "infinity" || lim == "unsigned_inf" { continue }
            if isDisplayableFinite(lim) {
                horizontals.insert("y = \(prettify(lim))")
            } else {
                haProblem = true // 白名单外的未知记号：不显示也不宣称"没有"
            }
        }
        a.horizontalAsymptotes = horizontals.sorted()
        if haProblem { tooComplex.insert(.horizontalAsymptotes) }

        // ── 斜渐近线：仅在该方向极限为无穷时才可能存在 ──
        var obliques = Set<String>()
        for direction in ["inf", "-inf"] {
            guard let lim = infLimitRaw[direction], lim == "+infinity" || lim == "-infinity" else { continue }
            guard let k = query("limit((\(f))/x,x,\(direction))").output else {
                tooComplex.insert(.obliqueAsymptotes)
                continue
            }
            guard isDisplayableFinite(k), k != "0" else { continue } // 极限非有限非零 → 无斜渐近线
            guard let b = query("limit((\(f))-(\(k))*x,x,\(direction))").output, isDisplayableFinite(b) else {
                tooComplex.insert(.obliqueAsymptotes)
                continue
            }
            let kPart: String
            switch k {
            case "1": kPart = "x"
            case "-1": kPart = "-x"
            default: kPart = "\(prettify(k))·x"
            }
            if b == "0" {
                obliques.insert("y = \(kPart)")
            } else if b.hasPrefix("-") {
                obliques.insert("y = \(kPart) - \(prettify(String(b.dropFirst())))")
            } else {
                obliques.insert("y = \(kPart) + \(prettify(b))")
            }
        }
        a.obliqueAsymptotes = obliques.sorted()

        // ── 单调性：结构可信才给（R3 修复：三角截断/通解族 → too complex）──
        if structureTrusted, let di = domainInfo {
            var walls: [Breakpoint] = numericStationary + nondiff + vaRoots + di.excluded
            walls = walls.filter { bp in
                if let lo = di.lower, bp.value <= lo.value + 1e-12 { return false }
                if let hi = di.upper, bp.value >= hi.value - 1e-12 { return false }
                return true
            }
            walls.sort { $0.value < $1.value }
            var dedup: [Breakpoint] = []
            for w in walls where !dedup.contains(where: { abs($0.value - w.value) <= 1e-9 }) {
                dedup.append(w)
            }

            let edges: [Breakpoint?] = [di.lower] + dedup.map { Optional($0) } + [di.upper]
            var rows: [(String, String)] = []
            var monoProblem = false
            for i in 0..<(edges.count - 1) {
                let lo = edges[i], hi = edges[i + 1]
                if let l = lo?.value, let h = hi?.value, h - l < 1e-9 { continue }
                let mid: Double
                switch (lo, hi) {
                case (nil, nil): mid = 0
                case (nil, let h?): mid = h.value - 1
                case (let l?, nil): mid = l.value + 1
                case (let l?, let h?): mid = (l.value + h.value) / 2
                }
                guard let s = firstDerivativeSign(at: mid) else {
                    monoProblem = true
                    break
                }
                let direction = s > 0
                    ? L10n.string("KGFMonotonicityIncreasing")
                    : (s < 0 ? L10n.string("KGFMonotonicityDecreasing") : L10n.string("KGFMonotonicityConstant"))
                let loStr = lo.map { prettify($0.exact) } ?? "-∞"
                let hiStr = hi.map { prettify($0.exact) } ?? "+∞"
                rows.append(("(\(loStr), \(hiStr))", direction))
            }
            if monoProblem {
                tooComplex.insert(.monotonicity)
            } else {
                a.monotonicity = rows
            }
        } else {
            tooComplex.insert(.monotonicity)
        }

        // ── 值域（R2：构造式）──
        if let range = computeRange(
            f: f, expr: expr, domainInfo: domainInfo, periodExact: periodExact,
            vaTrusted: vaTrusted, vaRoots: vaRoots, structureTrusted: structureTrusted,
            numericStationary: numericStationary, nondiff: nondiff,
            attainedValues: attainedValues, attainedByX: attainedByX, infLimitRaw: infLimitRaw) {
            a.range = range
        } else {
            tooComplex.insert(.range)
        }

        a.tooComplexFeatures = Field.allCases.filter(tooComplex.contains).map(\.localizedName)
        return a
    }

    // MARK: - 值域构造（R2）

    private static func computeRange(
        f: String,
        expr: GraphExpression,
        domainInfo: DomainInfo?,
        periodExact: String?,
        vaTrusted: Bool,
        vaRoots: [Breakpoint],
        structureTrusted: Bool,
        numericStationary: [Breakpoint],
        nondiff: [Breakpoint],
        attainedValues: [ValueCandidate],
        attainedByX: [Double: ValueCandidate],
        infLimitRaw: [String: String]) -> String?
    {
        // A · 周期路径：定义域全线且无 VA 的连续周期函数——限制到一个周期
        // [0, p]，闭区间上连续函数必取到最值，候选 = 端点值 ∪ 周期内驻点值。
        if let p = periodExact, let di = domainInfo, di.isFullLine, vaTrusted, vaRoots.isEmpty {
            // M2：purge 必须直接求值（绕过 query 的预算门控）——若 assume 成功后
            // 会话预算耗尽，query() 会静默跳过执行，assume 将泄漏到 giac 全局
            // context，污染后续分析的 domain/solve（且因"已有显式假设"不再触发
            // Auto assume 警告，R3 失效）。
            defer { _ = GiacEngine.evaluate("purge(x)", warningsOut: nil) }
            if query("assume(x>=0 and x<=\(p))").output != nil {
                let sq = query("solve(diff(\(f),x)=0,x)")
                if let so = sq.output, !sq.approximate {
                    var vals: [ValueCandidate] = []
                    var ok = true
                    let points = ["0"] + list(so)
                    if points.count <= maxSolutionCount + 1 {
                        for r in points {
                            guard !isParametric(r),
                                  let y = query("normal(subst(\(f),x=\(r)))").output,
                                  isDisplayableFinite(y), let v = numericValue(y) else {
                                ok = false
                                break
                            }
                            vals.append(ValueCandidate(exact: y, value: v, attained: true))
                        }
                        if ok, let lo = vals.min(by: { $0.value < $1.value }),
                           let hi = vals.max(by: { $0.value < $1.value }) {
                            return abs(lo.value - hi.value) <= 1e-12
                                ? "{\(prettify(lo.exact))}"
                                : "[\(prettify(lo.exact)), \(prettify(hi.exact))]"
                        }
                    }
                }
            }
            return nil
        }

        // B · 有界振荡路径：整个表达式是 sin(g)/cos(g) → |f| ≤ 1 由值域保证；
        // ±1 可达性经 solve(f=±1) 的非空解集验证（如 sin(1/x) 的两族通解）。
        // 注：可达 ±1 的解落在连通定义域段内时，介值定理给出 [-1,1] 全取到。
        if expr.isTopLevelSinOrCos {
            let s1 = query("solve(\(f)=1,x)")
            let s2 = query("solve(\(f)=(-1),x)")
            if let o1 = s1.output, !s1.approximate, !list(o1).isEmpty,
               let o2 = s2.output, !s2.approximate, !list(o2).isEmpty {
                return "[-1, 1]"
            }
            return nil
        }

        // C · 一般构造：按定义域挖点 + VA 切分实轴，每段（连续段）的值域 =
        // [段内候选最小, 最大]，候选 = 段端极限/端点值 ∪ 段内驻点值 ∪ 不可导点值。
        // 候选完备性依赖 structureTrusted；不完备 → nil（too complex）。
        guard structureTrusted, vaTrusted, let di = domainInfo else { return nil }

        func limitCandidate(at exact: String, fromRight: Bool) -> ValueCandidate? {
            guard let lim = query("limit(\(f),x,\(exact),\(fromRight ? "1" : "-1"))").output else { return nil }
            return limitToCandidate(lim)
        }
        func infinityCandidate(_ direction: String) -> ValueCandidate? {
            guard let lim = infLimitRaw[direction] ?? query("limit(\(f),x,\(direction))").output else { return nil }
            return limitToCandidate(lim)
        }
        func limitToCandidate(_ lim: String) -> ValueCandidate? {
            if lim == "+infinity" { return ValueCandidate(exact: "+∞", value: .infinity, attained: false) }
            if lim == "-infinity" { return ValueCandidate(exact: "-∞", value: -.infinity, attained: false) }
            guard isDisplayableFinite(lim), let v = numericValue(lim) else { return nil }
            return ValueCandidate(exact: lim, value: v, attained: false)
        }
        func attainedCandidate(at exact: String, xValue: Double) -> ValueCandidate? {
            // M3：优先复用极值阶段已算好的 f(x)（按 x 数值匹配：精确命中 + 容差兜底）。
            if let cached = attainedByX[xValue] { return cached }
            if let key = attainedByX.keys.min(by: { abs($0 - xValue) < abs($1 - xValue) }),
               abs(key - xValue) <= 1e-9 { return attainedByX[key] }
            guard let y = query("normal(subst(\(f),x=\(exact)))").output,
                  isDisplayableFinite(y), let v = numericValue(y) else { return nil }
            return ValueCandidate(exact: y, value: v, attained: true)
        }

        // 区间墙 = 定义域界 + 排除点 + VA 根（内点，去重排序）。
        var innerWalls: [Breakpoint] = (di.excluded + vaRoots).filter { bp in
            if let lo = di.lower, bp.value <= lo.value + 1e-12 { return false }
            if let hi = di.upper, bp.value >= hi.value - 1e-12 { return false }
            return true
        }
        innerWalls.sort { $0.value < $1.value }
        var walls: [Breakpoint] = []
        for w in innerWalls where !walls.contains(where: { abs($0.value - w.value) <= 1e-9 }) {
            walls.append(w)
        }

        struct Piece {
            var lo: ValueCandidate
            var loClosed: Bool
            var hi: ValueCandidate
            var hiClosed: Bool
        }
        struct Edge {
            var bp: Breakpoint?
            var included: Bool
        }
        let edges: [Edge] = [Edge(bp: di.lower, included: di.lowerIncluded)]
            + walls.map { Edge(bp: $0, included: false) }
            + [Edge(bp: di.upper, included: di.upperIncluded)]

        var pieces: [Piece] = []
        for i in 0..<(edges.count - 1) {
            let lo = edges[i], hi = edges[i + 1]
            if let l = lo.bp?.value, let h = hi.bp?.value, h - l < 1e-9 { continue }

            var cands: [ValueCandidate] = []
            if let bp = lo.bp {
                guard let c = lo.included ? attainedCandidate(at: bp.exact, xValue: bp.value) : limitCandidate(at: bp.exact, fromRight: true) else { return nil }
                cands.append(c)
            } else {
                guard let c = infinityCandidate("-inf") else { return nil }
                cands.append(c)
            }
            if let bp = hi.bp {
                guard let c = hi.included ? attainedCandidate(at: bp.exact, xValue: bp.value) : limitCandidate(at: bp.exact, fromRight: false) else { return nil }
                cands.append(c)
            } else {
                guard let c = infinityCandidate("inf") else { return nil }
                cands.append(c)
            }
            for p in numericStationary + nondiff {
                let insideLo = lo.bp.map { p.value > $0.value + 1e-12 } ?? true
                let insideHi = hi.bp.map { p.value < $0.value - 1e-12 } ?? true
                guard insideLo && insideHi else { continue }
                // 复用极值阶段已算好的值（按数值匹配）；找不到就现算。
                if let c = attainedCandidate(at: p.exact, xValue: p.value) {
                    cands.append(c)
                } else {
                    return nil
                }
            }

            let loVal = cands.map(\.value).min()!
            let hiVal = cands.map(\.value).max()!
            // 注意无穷端点：±inf 加容差会得 NaN，改用先判相等（-inf == -inf 成立）。
            func near(_ a: Double, _ b: Double) -> Bool {
                if a == b { return true }
                guard a.isFinite, b.isFinite else { return false }
                return abs(a - b) <= max(1e-9, max(abs(a), abs(b)) * 1e-12)
            }
            guard let loCand = cands.filter({ near($0.value, loVal) })
                .sorted(by: { ($0.attained ? 0 : 1) < ($1.attained ? 0 : 1) }).first,
                let hiCand = cands.filter({ near($0.value, hiVal) })
                .sorted(by: { ($0.attained ? 0 : 1) < ($1.attained ? 0 : 1) }).first else { return nil }
            pieces.append(Piece(lo: loCand, loClosed: loCand.attained, hi: hiCand, hiClosed: hiCand.attained))
        }
        guard !pieces.isEmpty else { return nil }

        // 合并重叠段；相邻同值端点若一侧闭则连通，两侧皆开则记为挖点。
        pieces.sort { $0.lo.value < $1.lo.value }
        var merged: [Piece] = []
        var gaps: [ValueCandidate] = []
        for p in pieces {
            guard var last = merged.last else {
                merged.append(p)
                continue
            }
            let touching = abs(last.hi.value - p.lo.value) <= 1e-9
            let overlapping = p.lo.value < last.hi.value - 1e-9
            if overlapping || (touching && (last.hiClosed || p.loClosed)) {
                if p.hi.value > last.hi.value || (abs(p.hi.value - last.hi.value) <= 1e-9 && p.hiClosed) {
                    last.hi = p.hi
                    last.hiClosed = p.hiClosed
                }
                merged[merged.count - 1] = last
            } else {
                if touching { gaps.append(last.hi) }
                merged.append(p)
            }
        }

        // 展示：全线 → ℝ；全线挖有限点 → ℝ \ {…}；否则区间并集。
        func fmt(_ c: ValueCandidate) -> String { prettify(c.exact) }
        if merged.count == 1, merged[0].lo.value == -.infinity, merged[0].hi.value == .infinity {
            return "ℝ"
        }
        if !gaps.isEmpty, merged.count == gaps.count + 1,
           merged.first!.lo.value == -.infinity, merged.last!.hi.value == .infinity {
            return "ℝ \\ {\(gaps.map(fmt).joined(separator: ", "))}"
        }
        return merged.map { p -> String in
            if p.loClosed && p.hiClosed && abs(p.lo.value - p.hi.value) <= 1e-12 {
                return "{\(fmt(p.lo))}"
            }
            let l = p.lo.value == -.infinity ? "-∞" : fmt(p.lo)
            let h = p.hi.value == .infinity ? "+∞" : fmt(p.hi)
            return "\(p.loClosed ? "[" : "(")\(l), \(h)\(p.hiClosed ? "]" : ")")"
        }.joined(separator: " ∪ ")
    }

    // MARK: - 定义域解析

    /// 剥掉整串首尾匹配的括号（giac 的 and 复合定义域总带括号包裹）。
    private static func stripParens(_ t: String) -> String {
        var u = t.trimmingCharacters(in: .whitespaces)
        while u.hasPrefix("("), u.hasSuffix(")"), isBalanced(String(u.dropFirst().dropLast())) {
            u = String(u.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return u
    }

    /// 解析形如 "x<op>v" 的原子条件（允许带括号），返回 (op, 数值, 原串)。
    private static func parseAtom(_ term: String) -> (op: String, value: Double, exact: String)? {
        let t = stripParens(term)
        guard t.hasPrefix("x") else { return nil }
        var rest = String(t.dropFirst())
        let op: String
        if rest.hasPrefix(">=") { op = ">=" } else if rest.hasPrefix("<=") { op = "<=" }
        else if rest.hasPrefix("<>") { op = "<>" } else if rest.hasPrefix(">") { op = ">" }
        else if rest.hasPrefix("<") { op = "<" } else { return nil }
        rest = stripParens(String(rest.dropFirst(op.count)))
        guard let v = numericValue(rest) else { return nil }
        return (op, v, rest)
    }

    /// 解析 giac 的 domain 输出："x"（全线）、"x>=a"、"x>a"、"x<=b"、"x<b"、
    /// "x<>c"、括号包裹的 and 复合（"((x>=-1) and (x<=1))"）、
    /// "全线挖一点"的列表形式（"[x<0,x>0]" → ℝ\{0}）。
    /// 一般并集列表（"[x<=-1,x>=1]"）无法用单区间模型表示 → 解析失败（安全降级）。
    /// 解析失败返回 nil（依赖它的字段降级 too complex）。
    private static func parseDomain(_ raw: String) -> DomainInfo? {
        var info = DomainInfo()
        var s = stripParens(raw)
        if s == "x" { return info }

        // 列表形式（并集）：仅支持"全线挖一点"（[x<a, x>b] 且 a==b）。
        if s.hasPrefix("[") && s.hasSuffix("]") {
            let inner = String(s.dropFirst().dropLast())
            let items = inner.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            if items.count == 2,
               let l = parseAtom(items[0]), let r = parseAtom(items[1]),
               l.value == r.value,
               (l.op == "<" || l.op == "<="), (r.op == ">" || r.op == ">=") {
                // [x<a, x>b] → 全线挖 a
                info.excluded.append(Breakpoint(exact: l.exact, value: l.value))
                return info
            }
            if items.count == 1 {
                s = items[0]
            } else {
                return nil
            }
        }

        // 顶层按 " and " 切分（括号深度 0 处）。
        var terms: [String] = []
        var depth = 0
        var current = ""
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "(" || c == "[" { depth += 1 }
            if c == ")" || c == "]" { depth -= 1 }
            if depth == 0, c == " ", s.dropFirst(i).hasPrefix(" and ") {
                terms.append(current)
                current = ""
                i += 5
                continue
            }
            current.append(c)
            i += 1
        }
        if !current.isEmpty { terms.append(current) }

        for term in terms {
            guard let (op, v, exact) = parseAtom(term) else { return nil }
            let bp = Breakpoint(exact: exact, value: v)
            switch op {
            case ">=", ">":
                if info.lower == nil || v > info.lower!.value {
                    info.lower = bp
                    info.lowerIncluded = op == ">="
                }
            case "<=", "<":
                if info.upper == nil || v < info.upper!.value {
                    info.upper = bp
                    info.upperIncluded = op == "<="
                }
            case "<>":
                info.excluded.append(bp)
            default:
                return nil
            }
        }
        return info
    }

    private static func isBalanced(_ s: String) -> Bool {
        var depth = 0
        for c in s {
            if c == "(" { depth += 1 }
            if c == ")" {
                depth -= 1
                if depth < 0 { return false }
            }
        }
        return depth == 0
    }

    // MARK: - 数值与记号工具

    /// 是否含通解参数（n_0/n_1…）或代表"任意值"的裸 x。
    private static func isParametric(_ s: String) -> Bool {
        s == "x" || s.range(of: #"n_\d+"#, options: .regularExpression) != nil
    }

    /// M1：周期函数 + 全数值解 → 通解族被静默丢弃的信号。
    /// giac 对小数输入（solve(sin(x)=0.5,x)）不做通解族展开，只给主区间数值根
    /// 且无任何警告（实测 stderr 干净）；而精确输入（1/2）返回 n_0 族。检测到
    /// 即降级 too complex（R4 精神），提示用户改用精确输入。
    /// 非周期函数不受影响：solve(x=0.5,x) → [0.5]（完备）不降级。
    private static func isApproxPeriodicSolution(_ f: String, _ items: [String]) -> Bool {
        guard !items.isEmpty, items.allSatisfy({ $0.contains(".") }) else { return false }
        return f.contains("sin(") || f.contains("cos(") || f.contains("tan(")
    }

    /// 数值化一个 giac 精确表达式（evalf）；失败返回 nil。
    private static func numericValue(_ exact: String) -> Double? {
        if let v = Double(exact) { return v }
        guard !isParametric(exact), let out = query("evalf(\(exact))").output else { return nil }
        return Double(out)
    }

    /// R1 白名单：仅由数字、运算符与已知数学记号组成的结果才可展示。
    /// bounded_function / undef / infinity / unsigned_inf / rootof / 虚数单位 i
    /// 等一律拒绝——任何未知 token 都不许变成用户可见的"答案"。
    static func isDisplayableFinite(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        let allowed: Set<String> = [
            "sqrt", "pi", "exp", "ln", "log", "log10", "abs",
            "sin", "cos", "tan", "asin", "acos", "atan", "e",
        ]
        var index = s.startIndex
        while let r = s.range(of: #"[A-Za-z_][A-Za-z_0-9]*"#, options: .regularExpression, range: index..<s.endIndex) {
            let token = String(s[r])
            // 通解族变量（n_0/n_1…，all_trig_solutions 输出）是合法的"任意整数"
            // 记号，不是未知 token——放行（sin(x) 的零点族 n_0*pi 必须可展示）。
            if !allowed.contains(token), !isParametric(token) { return false }
            index = r.upperBound
        }
        return true
    }

    /// 解析并求值一条 Giac 表达式；出错返回 nil（对应 IMathSolver::ParseInput+Serialize）。
    /// 攻击审查 1.2/2.1：ask 是全应用唯一能携带任意串到达 giac 的漏斗——
    /// ① 白名单拒绝任何可能改写 giac 全局状态（sto/assume/purge/赋值/多语句）的语法；
    /// ② 强制持 analysisLock，避免与进行中的 analyze 竞态互吞预算。
    static func ask(_ q: String) -> String? {
        let forbidden: [String] = [";", ":=", "sto(", "purge", "assume", ":=1"]
        guard !forbidden.contains(where: q.contains) else { return nil }
        analysisLock.lock()
        defer { analysisLock.unlock() }
        return query(q).output
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

    /// 展示层格式化（对应 IFormatOptions 的角色）：还原常量记号、去掉乘号噪音、
    /// 整值浮点去掉小数尾巴（"100.0" → "100"）。
    static func prettify(_ s: String) -> String {
        if s.contains("."), let v = Double(s), v == v.rounded(), abs(v) < 1e15 {
            return String(Int64(v))
        }
        return s.replacingOccurrences(of: "exp(1)", with: "e")
            .replacingOccurrences(of: "pi", with: "π")
            .replacingOccurrences(of: "*", with: "·")
            // all_trig_solutions 通解变量 n_0/n_1… → n（展示为 n·π 之类）。
            .replacingOccurrences(of: #"n_\d+"#, with: "n", options: .regularExpression)
    }
}
