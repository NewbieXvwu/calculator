// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 绘图模式的表达式求值器（生产路径）：纯 Swift 递归下降解析器 + S4 区间算术内核
// （隐式方程、Tupper 区间求值）。符号分析（零点/极值/渐近线等）由 GiacMathSolver（giac）
// 承担；几何采样/等值线/刻度下沉共享 C 层 graph_geometry。
//
// 支持语法：
//   - 数字、变量 x、常数 pi / π / e
//   - 运算符 + - * / ^（^ 右结合），一元 ±
//   - 隐式乘法：2x、3sin(x)、(x+1)(x-1)
//   - 函数：sin cos tan asin acos atan sinh cosh tanh ln log log2 sqrt abs exp

import Foundation

/// 三角单位（对应原版 GraphingSettings 的 Radians/Degrees/Gradians 单选）。
enum GraphTrigMode: String, CaseIterable, Codable {
    case radians, degrees, gradians

    /// 输入角 → 弧度的换算系数（sin(x) 按 sin(x·scale) 求值）。
    var scale: Double {
        switch self {
        case .radians: return 1
        case .degrees: return .pi / 180
        case .gradians: return .pi / 200
        }
    }
}

/// 区间求值的定义域三值（S4 Tupper，镜像 graph_box_domain_t）。
enum GraphBoxDomain {
    /// 盒内处处未定义。
    case nowhereDefined
    /// 盒内处处已定义。
    case defined
    /// 可能部分未定义（保守：无法证明处处定义时取此值）。
    case maybeDefined
}

/// 区间求值结果：F 在盒上（已定义部分）的保守围栏 + 定义域三值。
struct GraphIntervalResult {
    var lo: Double
    var hi: Double
    var domain: GraphBoxDomain
}

/// 把一元函数表达式 y=f(x) 解析为可反复求值的树。
struct GraphExpression {
    private let root: Node

    /// 表达式引用的参数名（除 x/y 外的单字母，如 a、b、k），供变量滑块用。
    let parameters: Set<String>

    /// 解析失败返回 nil。会剥离前缀 "y=" / "f(x)="。
    /// 输入长度上限（DoS 护栏）：超长平铺表达式（"1+1+1+…"）会构造左深 AST，
    /// Node.eval 递归深度 ≈ 项数，实测 15 万字符即主线程栈溢出 SIGSEGV
    /// （攻击审查 4.1）。2000 字符 ≈ 2000 层递归，实测安全（1500 层 OK）。
    static let maxInputLength = 2000

    /// 解析嵌套深度上限（DoS 护栏）：深括号 "((((…1…))))" 的 parsePrimary 递归，
    /// 实测 2500 层即在 512KB 分析线程 SIGBUS（攻击审查 4.1）。
    static let maxParseDepth = 200

    init?(_ source: String) {
        let cleaned = GraphExpression.stripPrefix(source)
        guard !cleaned.isEmpty else { return nil }
        guard cleaned.count <= GraphExpression.maxInputLength else { return nil }
        var parser = Parser(cleaned)
        guard let node = parser.parseExpression(), parser.isAtEnd else { return nil }
        root = node
        var names = Set<String>()
        node.collectParameters(into: &names)
        parameters = names
    }

    /// 在给定 x 处求值；非有限（NaN/Inf，如定义域外）返回 nil。
    func evaluate(x: Double, params: [String: Double] = [:], trig: GraphTrigMode = .radians) -> Double? {
        let value = root.eval(x: x, y: 0, params: params, trig: trig)
        return value.isFinite ? value : nil
    }

    /// 双变量求值（隐式方程 F(x,y) 用）；非有限返回 nil。
    func evaluate(x: Double, y: Double, params: [String: Double] = [:], trig: GraphTrigMode = .radians) -> Double? {
        let value = root.eval(x: x, y: y, params: params, trig: trig)
        return value.isFinite ? value : nil
    }

    /// S4 Tupper 区间求值：返回 F 在盒 [xLo,xHi]×[yLo,yHi] 上的保守围栏。
    /// 契约（graph_eval2_interval_fn）：盒内任一已定义点的值必落在 [lo,hi] 内。
    /// 每步不精确运算后端点外向舍入 1 ulp；libm 超越函数按 ≤1 ulp 误差假设，
    /// 舍入方向只会把围栏放大——放大是保守的（多画"不确定"，绝不漏解）。
    func evaluateInterval(
        xLo: Double, xHi: Double, yLo: Double, yHi: Double,
        params: [String: Double] = [:], trig: GraphTrigMode = .radians
    ) -> GraphIntervalResult {
        let result = root.evalInterval(
            x: IntervalValue(xLo, xHi), y: IntervalValue(yLo, yHi), params: params, trig: trig)
        return GraphIntervalResult(lo: result.v.lo, hi: result.v.hi, domain: result.domain)
    }

    /// 解析双变量表达式（不剥离 y= 前缀），供隐式方程 F(x,y)=LHS-RHS 使用。
    init?(rawTwoVariable raw: String) {
        let cleaned = raw.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        var parser = Parser(cleaned)
        guard let node = parser.parseExpression(), parser.isAtEnd else { return nil }
        root = node
        var names = Set<String>()
        node.collectParameters(into: &names)
        parameters = names
    }

    private static func stripPrefix(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        for prefix in ["y=", "Y=", "f(x)=", "F(x)="] where t.hasPrefix(prefix) {
            t.removeFirst(prefix.count)
            break
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - AST

    private indirect enum Node {
        case number(Double)
        case variable
        case variableY
        case parameter(String)
        case negate(Node)
        case binary(Character, Node, Node)
        case call(String, Node)

        func eval(x: Double, y: Double, params: [String: Double], trig: GraphTrigMode = .radians) -> Double {
            switch self {
            case .number(let v): return v
            case .variable: return x
            case .variableY: return y
            case .parameter(let name): return params[name] ?? .nan
            case .negate(let n): return -n.eval(x: x, y: y, params: params, trig: trig)
            case .binary(let op, let l, let r):
                let a = l.eval(x: x, y: y, params: params, trig: trig), b = r.eval(x: x, y: y, params: params, trig: trig)
                switch op {
                case "+": return a + b
                case "-": return a - b
                case "*": return a * b
                case "/": return a / b
                case "^": return pow(a, b)
                default: return .nan
                }
            case .call(let name, let arg):
                let v = arg.eval(x: x, y: y, params: params, trig: trig)
                switch name {
                case "sin": return sin(v * trig.scale)
                case "cos": return cos(v * trig.scale)
                case "tan": return tan(v * trig.scale)
                case "asin": return asin(v) / trig.scale
                case "acos": return acos(v) / trig.scale
                case "atan": return atan(v) / trig.scale
                case "sinh": return sinh(v)
                case "cosh": return cosh(v)
                case "tanh": return tanh(v)
                case "ln": return log(v)
                case "log": return log10(v)
                case "log2": return log2(v)
                case "sqrt": return sqrt(v)
                case "abs": return abs(v)
                case "exp": return exp(v)
                default: return .nan
                }
        }
        }

        // MARK: - 区间求值（S4 Tupper）
        // 语义：围栏包住"双精度逐点求值"在盒内的一切取值（含 libm ≤1 ulp 误差
        // 余量）。number 常量（π、e 亦然）按 double 点值处理——渲染的对象就是
        // double 组合函数本身，与 eval(x:y:) 严格同源。
        func evalInterval(
            x: IntervalValue, y: IntervalValue, params: [String: Double], trig: GraphTrigMode
        ) -> (v: IntervalValue, domain: GraphBoxDomain) {
            switch self {
            case .number(let value):
                return (IntervalValue(value, value), .defined)
            case .variable:
                return (x, .defined)
            case .variableY:
                return (y, .defined)
            case .parameter(let name):
                guard let p = params[name] else { return (.whole, .nowhereDefined) }
                return (IntervalValue(p, p), .defined)
            case .negate(let n):
                let r = n.evalInterval(x: x, y: y, params: params, trig: trig)
                return (IntervalValue(-r.v.hi, -r.v.lo), r.domain)
            case .binary(let op, let l, let rNode):
                let a = l.evalInterval(x: x, y: y, params: params, trig: trig)
                let b = rNode.evalInterval(x: x, y: y, params: params, trig: trig)
                let dom = worseDomain(a.domain, b.domain)
                if dom == .nowhereDefined { return (.whole, .nowhereDefined) }
                switch op {
                case "+": return (iadd(a.v, b.v), dom)
                case "-": return (isub(a.v, b.v), dom)
                case "*": return (imul(a.v, b.v), dom)
                case "/": return idiv(a.v, b.v, dom)
                case "^": return ipow(a.v, b.v, dom)
                default: return (.whole, .maybeDefined)
                }
            case .call(let name, let arg):
                let r = arg.evalInterval(x: x, y: y, params: params, trig: trig)
                if r.domain == .nowhereDefined { return (.whole, .nowhereDefined) }
                return icall(name, r.v, r.domain, trig: trig)
            }
        }

        func collectParameters(into names: inout Set<String>) {
            switch self {
            case .number, .variable, .variableY:
                break
            case .parameter(let name):
                names.insert(name)
            case .negate(let n):
                n.collectParameters(into: &names)
            case .binary(_, let l, let r):
                l.collectParameters(into: &names)
                r.collectParameters(into: &names)
            case .call(_, let arg):
                arg.collectParameters(into: &names)
            }
        }

        /// 序列化为 Giac/Xcas 输入语法（全部显式加括号，规避优先级差异）。
        func giacString(params: [String: Double], trig: GraphTrigMode = .radians) -> String {
            switch self {
            case .number(let v):
                if v == .pi { return "pi" }
                if v == M_E { return "exp(1)" }
                // 非有限值（1e999 等溢出 → ±inf）：显式输出 inf/-inf，由展示层
                // 白名单拒绝（攻击审查 1.3：String(inf) 曾产生常函数捷径错误答案）。
                if v.isInfinite { return v > 0 ? "inf" : "-inf" }
                if v.isNaN { return "undef" }
                // 精确整数值用整数形式序列化（阈值 Int64 上限 9.2e18）：giac 对
                // "1e16" 这类科学计数法走 double 路径（1 ULP=2），1e16+1 会被
                // 舍入丢 1（攻击审查 D1.4）；整数形式走精确整数路径。
                return v == v.rounded() && abs(v) < 9.2e18
                    ? String(Int64(v)) : String(v)
            case .variable: return "x"
            case .variableY: return "y"
            case .parameter(let name):
                // 参数按滑块当前值代入，让 Giac 得到纯 x 表达式。
                let v = params[name] ?? 1
                return "(\(v == v.rounded() ? String(Int64(v)) : String(v)))"
            case .negate(let n):
                return "(-(\(n.giacString(params: params, trig: trig))))"
            case .binary(let op, let l, let r):
                return "((\(l.giacString(params: params, trig: trig)))\(op)(\(r.giacString(params: params, trig: trig))))"
            case .call(let name, let arg):
                let a = arg.giacString(params: params, trig: trig)
                // 非弧度模式：正三角入参乘换算系数，反三角结果除以系数。
                let factor: String? = {
                    switch trig {
                    case .radians: return nil
                    case .degrees: return "pi/180"
                    case .gradians: return "pi/200"
                    }
                }()
                switch name {
                case "log": return "log10(\(a))"
                case "log2": return "(ln(\(a))/ln(2))"
                case "sin", "cos", "tan":
                    if let factor { return "\(name)((\(factor))*(\(a)))" }
                    return "\(name)(\(a))"
                case "asin", "acos", "atan":
                    if let factor { return "((\(name)(\(a)))/(\(factor)))" }
                    return "\(name)(\(a))"
                default: return "\(name)(\(a))"
                }
            }
        }
    }

    /// 以 Giac/Xcas 语法输出该表达式（参数用给定滑块值代入）。
    func giacForm(params: [String: Double] = [:], trig: GraphTrigMode = .radians) -> String {
        root.giacString(params: params, trig: trig)
    }

    /// 顶层是否为 sin/cos 调用（整个表达式形如 sin(g(x)) / cos(g(x))）。
    /// 值域构造（S3·R2）用它走"有界振荡"路径：|f| ≤ 1 由 sin/cos 值域保证，
    /// 端点可达性再经 solve(f=±1) 验证。
    var isTopLevelSinOrCos: Bool {
        if case .call(let name, _) = root, name == "sin" || name == "cos" {
            return true
        }
        return false
    }

    // MARK: - 递归下降解析器

    private struct Parser {
        private let chars: [Character]
        private var pos = 0
        private var depth = 0

        init(_ s: String) { chars = Array(s.lowercased()) }

        var isAtEnd: Bool {
            var i = pos
            while i < chars.count && chars[i] == " " { i += 1 }
            return i >= chars.count
        }

        private mutating func skipToNonSpace() {
            while pos < chars.count && chars[pos] == " " { pos += 1 }
        }

        private func peek() -> Character? {
            var i = pos
            while i < chars.count && chars[i] == " " { i += 1 }
            return i < chars.count ? chars[i] : nil
        }

        private mutating func advance() -> Character? {
            skipToNonSpace()
            guard pos < chars.count else { return nil }
            let c = chars[pos]
            pos += 1
            return c
        }

        private mutating func match(_ c: Character) -> Bool {
            if peek() == c { _ = advance(); return true }
            return false
        }

        // expr := term (('+'|'-') term)*
        mutating func parseExpression() -> Node? {
            guard var left = parseTerm() else { return nil }
            while let op = peek(), op == "+" || op == "-" {
                _ = advance()
                guard let right = parseTerm() else { return nil }
                left = .binary(op, left, right)
            }
            return left
        }

        // term := unary (('*'|'/'| implicit) unary)*
        private mutating func parseTerm() -> Node? {
            guard var left = parseUnary() else { return nil }
            while true {
                if let op = peek(), op == "*" || op == "/" {
                    _ = advance()
                    guard let right = parseUnary() else { return nil }
                    left = .binary(op, left, right)
                } else if let next = peek(), isImplicitMultiplyStart(next) {
                    // 隐式乘法：2x、3sin(x)、(x+1)(x-1)
                    guard let right = parseUnary() else { return nil }
                    left = .binary("*", left, right)
                } else {
                    break
                }
            }
            return left
        }

        private func isImplicitMultiplyStart(_ c: Character) -> Bool {
            c == "(" || c == "x" || c.isLetter || c.isNumber || c == "."
        }

        // unary := ('-'|'+')? unary | power  （一元号优先级低于 ^，故 -x^2 = -(x^2)）
        private mutating func parseUnary() -> Node? {
            if match("-") {
                guard let operand = parseUnary() else { return nil }
                return .negate(operand)
            }
            if match("+") {
                return parseUnary()
            }
            return parsePower()
        }

        // power := primary ('^' unary)?  （右结合，允许 2^-3）
        private mutating func parsePower() -> Node? {
            guard let base = parsePrimary() else { return nil }
            if match("^") {
                guard let exp = parseUnary() else { return nil }
                return .binary("^", base, exp)
            }
            return base
        }

        private mutating func parsePrimary() -> Node? {
            guard let c = peek() else { return nil }

            if c == "(" {
                _ = advance()
                depth += 1
                defer { depth -= 1 }
                guard depth <= GraphExpression.maxParseDepth else { return nil }
                guard let inner = parseExpression(), match(")") else { return nil }
                return inner
            }

            if c.isNumber || c == "." {
                return parseNumber()
            }

            if c.isLetter {
                return parseIdentifier()
            }

            return nil
        }

        private mutating func parseNumber() -> Node? {
            skipToNonSpace()
            var s = ""
            while let c = peekRaw(), c.isNumber || c == "." {
                s.append(c)
                pos += 1
            }
            // 科学计数 1e3 / 1e-3
            if let c = peekRaw(), c == "e",
               s.range(of: "[0-9]", options: .regularExpression) != nil {
                let save = pos
                pos += 1
                var expPart = "e"
                if let sign = peekRaw(), sign == "+" || sign == "-" { expPart.append(sign); pos += 1 }
                if let d = peekRaw(), d.isNumber {
                    while let dd = peekRaw(), dd.isNumber { expPart.append(dd); pos += 1 }
                    s += expPart
                } else {
                    pos = save // 不是指数，回退（e 作为常数处理）
                }
            }
            guard let value = Double(s) else { return nil }
            return .number(value)
        }

        /// 不跳空格的原地窥视：token 内部不允许跨空格（"a x" 是隐式乘法而非标识符 "ax"）。
        private func peekRaw() -> Character? {
            pos < chars.count ? chars[pos] : nil
        }

        private mutating func parseIdentifier() -> Node? {
            skipToNonSpace()
            var name = ""
            while let c = peekRaw(), c.isLetter || c.isNumber {
                name.append(c)
                pos += 1
            }

            switch name {
            case "x": return .variable
            case "y": return .variableY
            case "pi", "π": return .number(Double.pi)
            case "e": return .number(M_E)
            default:
                break
            }

            // 单字母未知标识符 → 可调参数（变量滑块），如 a、b、k。
            // 已知函数名均 ≥2 字符，后随 "(" 时按隐式乘法处理（a(x+1)=a*(x+1)）。
            if name.count == 1, let c = name.first, c.isLetter {
                return .parameter(name)
            }

            // 函数调用：name(expr)
            guard match("(") else { return nil }
            guard let arg = parseExpression(), match(")") else { return nil }
            let known: Set<String> = ["sin", "cos", "tan", "asin", "acos", "atan",
                                      "sinh", "cosh", "tanh", "ln", "log", "log2",
                                      "sqrt", "abs", "exp"]
            guard known.contains(name) else { return nil }
            return .call(name, arg)
        }
    }
}

// MARK: - 区间算术内核（S4 Tupper）

/// 闭区间 [lo, hi]，端点可为 ±inf。构造时对 NaN 兜底为全线、自动排序端点
/// （单调函数映射可以直接喂两个端点，方向无关）。
struct IntervalValue {
    let lo: Double
    let hi: Double

    init(_ a: Double, _ b: Double) {
        if a.isNaN || b.isNaN {
            lo = -.infinity
            hi = .infinity
        } else {
            lo = Swift.min(a, b)
            hi = Swift.max(a, b)
        }
    }

    static let whole = IntervalValue(-.infinity, .infinity)

    func contains(_ v: Double) -> Bool { v >= lo && v <= hi }

    /// 外向舍入：把可能带 1 ulp 舍入误差的端点各放宽一档（∞ 保持）。
    func widened() -> IntervalValue {
        IntervalValue(lo.isFinite ? lo.nextDown : lo, hi.isFinite ? hi.nextUp : hi)
    }
}

/// 定义域三值的悲观合并：任一侧全盒未定义 → 全盒未定义；任一侧可能未定义 → 可能。
func worseDomain(_ a: GraphBoxDomain, _ b: GraphBoxDomain) -> GraphBoxDomain {
    if a == .nowhereDefined || b == .nowhereDefined { return .nowhereDefined }
    if a == .maybeDefined || b == .maybeDefined { return .maybeDefined }
    return .defined
}

private func iadd(_ a: IntervalValue, _ b: IntervalValue) -> IntervalValue {
    IntervalValue(a.lo + b.lo, a.hi + b.hi).widened()
}

private func isub(_ a: IntervalValue, _ b: IntervalValue) -> IntervalValue {
    IntervalValue(a.lo - b.hi, a.hi - b.lo).widened()
}

/// 0×∞ 按区间算术约定取 0（避免 NaN 把整个围栏炸成全线）。
private func prod(_ x: Double, _ y: Double) -> Double {
    let p = x * y
    return p.isNaN ? 0 : p
}

private func imul(_ a: IntervalValue, _ b: IntervalValue) -> IntervalValue {
    let c = [prod(a.lo, b.lo), prod(a.lo, b.hi), prod(a.hi, b.lo), prod(a.hi, b.hi)]
    return IntervalValue(c.min()!, c.max()!).widened()
}

private func idiv(
    _ a: IntervalValue, _ b: IntervalValue, _ dom: GraphBoxDomain
) -> (v: IntervalValue, domain: GraphBoxDomain) {
    if b.contains(0) {
        // 分母恒为 0 → 处处未定义；否则可能碰到除零点 → 无界 + 可能未定义。
        if b.lo == 0 && b.hi == 0 { return (.whole, .nowhereDefined) }
        return (.whole, .maybeDefined)
    }
    var qLo = Double.infinity
    var qHi = -Double.infinity
    for n in [a.lo, a.hi] {
        for d in [b.lo, b.hi] {
            let q = n / d
            if q.isNaN { return (.whole, dom) }  // ∞/∞：无信息，保守全线
            qLo = Swift.min(qLo, q)
            qHi = Swift.max(qHi, q)
        }
    }
    return (IntervalValue(qLo, qHi).widened(), dom)
}

/// 整数常量幂：负底数也精确（x^2、x^3 是隐式方程最常见形态）。
private func ipowInt(
    _ v: IntervalValue, _ n: Int, _ dom: GraphBoxDomain
) -> (v: IntervalValue, domain: GraphBoxDomain) {
    if n == 0 { return (IntervalValue(1, 1), dom) }  // pow(x,0)=1，含 0^0——与逐点求值一致
    if n < 0 {
        let p = ipowInt(v, -n, dom)
        return idiv(IntervalValue(1, 1), p.v, p.domain)
    }
    let d = Double(n)
    if n % 2 == 1 {
        return (IntervalValue(pow(v.lo, d), pow(v.hi, d)).widened(), dom)
    }
    let aLo = abs(v.lo)
    let aHi = abs(v.hi)
    let mLo = v.contains(0) ? 0 : pow(Swift.min(aLo, aHi), d)
    let mHi = pow(Swift.max(aLo, aHi), d)
    return (IntervalValue(mLo, mHi).widened(), dom)
}

private func ipow(
    _ a: IntervalValue, _ b: IntervalValue, _ dom: GraphBoxDomain
) -> (v: IntervalValue, domain: GraphBoxDomain) {
    if b.lo == b.hi, b.lo.rounded() == b.lo, abs(b.lo) <= 1e9 {
        return ipowInt(a, Int(b.lo), dom)
    }
    if a.lo > 0 {
        // x^y 在 x>0 的盒上：内部驻值仅出现在 x=1 或 y=0（值均为 1），
        // 其余极值都在四角。
        var c = [pow(a.lo, b.lo), pow(a.lo, b.hi), pow(a.hi, b.lo), pow(a.hi, b.hi)]
        if a.contains(1) || b.contains(0) { c.append(1) }
        if c.contains(where: { $0.isNaN }) { return (.whole, dom) }
        return (IntervalValue(c.min()!, c.max()!).widened(), dom)
    }
    // 底数可能 ≤0 且指数非整数常量：实数域可能无定义（负底非整数幂），
    // 保守：全线 + 可能未定义。
    return (.whole, dom == .defined ? .maybeDefined : dom)
}

/// 周期格点 base + k·period 是否落在区间内。容差方向朝"包含"——对 sin/cos
/// 极值多收进来只会把范围扩到 ±1（安全）；对 tan 渐近线多算只会更保守。
/// 容差随端点量级放大：大参数下 (lo-base)/period 的除法舍入可达多个格点比例。
private func gridPointIn(_ base: Double, _ period: Double, _ v: IntervalValue) -> Bool {
    guard v.lo.isFinite, v.hi.isFinite else { return true }
    let tol = Swift.max(period * 1e-9, Swift.max(abs(v.lo), abs(v.hi)) * 1e-12)
    let k = ((v.lo - tol - base) / period).rounded(.up)
    return base + k * period <= v.hi + tol
}

/// 单调函数映射（方向无关：IntervalValue 构造会排序端点）。复合了缩放的
/// 映射额外 widened 一次，覆盖两步舍入。
private func imono(_ v: IntervalValue, _ f: (Double) -> Double) -> IntervalValue {
    IntervalValue(f(v.lo), f(v.hi)).widened().widened()
}

// swiftlint:disable:next cyclomatic_complexity function_body_length
func icall(
    _ name: String, _ v: IntervalValue, _ domain: GraphBoxDomain, trig: GraphTrigMode
) -> (v: IntervalValue, domain: GraphBoxDomain) {
    switch name {
    case "sin", "cos":
        let s = imul(v, IntervalValue(trig.scale, trig.scale))
        guard s.lo.isFinite, s.hi.isFinite, s.hi - s.lo < 2 * .pi else {
            return (IntervalValue(-1, 1), domain)
        }
        let f: (Double) -> Double = name == "sin" ? sin : cos
        var lo = Swift.min(f(s.lo), f(s.hi)).nextDown
        var hi = Swift.max(f(s.lo), f(s.hi)).nextUp
        let maxBase = name == "sin" ? Double.pi / 2 : 0
        let minBase = name == "sin" ? -Double.pi / 2 : Double.pi
        if gridPointIn(maxBase, 2 * .pi, s) { hi = 1 }
        if gridPointIn(minBase, 2 * .pi, s) { lo = -1 }
        return (IntervalValue(Swift.max(lo, -1), Swift.min(hi, 1)), domain)
    case "tan":
        let s = imul(v, IntervalValue(trig.scale, trig.scale))
        guard s.lo.isFinite, s.hi.isFinite, s.hi - s.lo < .pi,
              !gridPointIn(.pi / 2, .pi, s) else {
            // 区间跨过渐近线：值无界，且渐近线点本身未定义。
            return (.whole, domain == .defined ? .maybeDefined : domain)
        }
        return (imono(s) { tan($0) }, domain)
    case "asin", "acos":
        if v.lo > 1 || v.hi < -1 { return (.whole, .nowhereDefined) }
        let clipped = IntervalValue(Swift.max(v.lo, -1), Swift.min(v.hi, 1))
        let partial = v.lo < -1 || v.hi > 1
        let f: (Double) -> Double = name == "asin" ? asin : acos
        let scale = trig.scale
        return (imono(clipped) { f($0) / scale },
                partial ? .maybeDefined : domain)
    case "atan":
        let scale = trig.scale
        return (imono(v) { atan($0) / scale }, domain)
    case "sinh":
        return (imono(v, sinh), domain)
    case "cosh":
        let hi = Swift.max(cosh(v.lo), cosh(v.hi))
        let lo = v.contains(0) ? 1 : cosh(Swift.min(abs(v.lo), abs(v.hi)))
        return (IntervalValue(lo, hi).widened(), domain)
    case "tanh":
        return (imono(v, tanh), domain)
    case "ln", "log", "log2":
        let f: (Double) -> Double = name == "ln" ? log : (name == "log" ? log10 : log2)
        if v.hi <= 0 { return (.whole, .nowhereDefined) }
        if v.lo > 0 { return (imono(v, f), domain) }
        return (IntervalValue(-.infinity, f(v.hi).nextUp), .maybeDefined)
    case "sqrt":
        if v.hi < 0 { return (.whole, .nowhereDefined) }
        if v.lo >= 0 { return (imono(v, sqrt), domain) }
        return (IntervalValue(0, sqrt(v.hi).nextUp), .maybeDefined)
    case "abs":
        if v.lo >= 0 { return (v, domain) }
        if v.hi <= 0 { return (IntervalValue(-v.hi, -v.lo), domain) }
        return (IntervalValue(0, Swift.max(-v.lo, v.hi)), domain)
    case "exp":
        return (imono(v, exp), domain)
    default:
        return (.whole, .maybeDefined)
    }
}
