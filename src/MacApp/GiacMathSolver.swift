// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Giac(CAS) 符号数学求解器：对应原版 GraphingInterfaces 的 IMathSolver +
// IGraphAnalyzer 职责（解析/求值/格式化 + 零点/极值/拐点/渐近线/奇偶性/定义域）。
// GraphExpression 负责把计算器输入语法序列化为 Giac 语法（giacForm），
// 本类型把 Giac 的输出（"list[...]"、"x>=1"、"+infinity" 等）解析回结构化结果。

import Foundation
import GiacBridge

/// 符号函数分析结果（对应原版 IGraphFunctionAnalysisData 的 macOS 精简版）。
struct GiacFunctionAnalysis {
    enum Parity { case even, odd, none }

    var domain: String?
    var parity: Parity = .none
    var zeros: [String] = []
    var yIntercept: String?
    var minima: [(x: String, y: String)] = []
    var maxima: [(x: String, y: String)] = []
    var inflectionPoints: [(x: String, y: String)] = []
    var verticalAsymptotes: [String] = []
    var horizontalAsymptotes: [String] = []

    var isEmpty: Bool {
        domain == nil && parity == .none && zeros.isEmpty && yIntercept == nil
            && minima.isEmpty && maxima.isEmpty && inflectionPoints.isEmpty
            && verticalAsymptotes.isEmpty && horizontalAsymptotes.isEmpty
    }
}

enum GiacMathSolver {
    /// 对显式函数 y=f(x) 做符号分析。Giac 求解失败的子项将被跳过（返回部分结果）。
    static func analyze(_ expr: GraphExpression, params: [String: Double] = [:]) -> GiacFunctionAnalysis {
        let f = expr.giacForm(params: params)
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

        a.zeros = list(ask("solve(\(f)=0,x)")).map(prettify)

        if let y0 = ask("subst(\(f),x=0)"), isFiniteResult(y0) {
            a.yIntercept = prettify(y0)
        }

        // 驻点 + 二阶导符号判别极大/极小。
        for r in list(ask("solve(diff(\(f),x)=0,x)")) {
            guard let second = ask("sign(subst(diff(\(f),x,2),x=\(r)))"),
                  let y = ask("normal(subst(\(f),x=\(r)))"), isFiniteResult(y)
            else { continue }
            let point = (x: prettify(r), y: prettify(y))
            if second == "1" {
                a.minima.append(point)
            } else if second == "-1" {
                a.maxima.append(point)
            }
        }

        for r in list(ask("solve(diff(\(f),x,2)=0,x)")) {
            // 二阶导为零且三阶导非零 → 拐点。
            guard ask("sign(subst(diff(\(f),x,3),x=\(r)))") != "0",
                  let y = ask("normal(subst(\(f),x=\(r)))"), isFiniteResult(y)
            else { continue }
            a.inflectionPoints.append((x: prettify(r), y: prettify(y)))
        }

        a.verticalAsymptotes = list(ask("solve(denom(normal(\(f)))=0,x)")).map { "x = \(prettify($0))" }

        var horizontals = Set<String>()
        for direction in ["inf", "-inf"] {
            if let lim = ask("limit(\(f),x,\(direction))"), isFiniteResult(lim) {
                horizontals.insert("y = \(prettify(lim))")
            }
        }
        a.horizontalAsymptotes = horizontals.sorted()

        return a
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
    }

    private static func isFiniteResult(_ s: String) -> Bool {
        if s.contains("infinity") || s.contains("undef") { return false }
        // 拒绝复数结果：匹配独立的虚数单位 i（避开 sin/pi 等标识符里的字母 i）。
        return s.range(of: #"(^|[^a-z])i([^a-z]|$)"#, options: .regularExpression) == nil
    }
}
