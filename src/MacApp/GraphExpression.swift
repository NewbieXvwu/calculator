// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 绘图模式的表达式求值器（Mock 数学引擎），对应原版 GraphingImpl/Mocks 的角色：
// 先用纯 Swift 递归下降解析器跑通绘图 UI 架构；后续再用 Giac(CAS) 替换以支持
// 隐式方程、符号分析（零点/极值/渐近线等）。
//
// 支持语法：
//   - 数字、变量 x、常数 pi / π / e
//   - 运算符 + - * / ^（^ 右结合），一元 ±
//   - 隐式乘法：2x、3sin(x)、(x+1)(x-1)
//   - 函数：sin cos tan asin acos atan sinh cosh tanh ln log log2 sqrt abs exp

import Foundation

/// 把一元函数表达式 y=f(x) 解析为可反复求值的树。
struct GraphExpression {
    private let root: Node

    /// 表达式引用的参数名（除 x/y 外的单字母，如 a、b、k），供变量滑块用。
    let parameters: Set<String>

    /// 解析失败返回 nil。会剥离前缀 "y=" / "f(x)="。
    init?(_ source: String) {
        let cleaned = GraphExpression.stripPrefix(source)
        guard !cleaned.isEmpty else { return nil }
        var parser = Parser(cleaned)
        guard let node = parser.parseExpression(), parser.isAtEnd else { return nil }
        root = node
        var names = Set<String>()
        node.collectParameters(into: &names)
        parameters = names
    }

    /// 在给定 x 处求值；非有限（NaN/Inf，如定义域外）返回 nil。
    func evaluate(x: Double, params: [String: Double] = [:]) -> Double? {
        let value = root.eval(x: x, y: 0, params: params)
        return value.isFinite ? value : nil
    }

    /// 双变量求值（隐式方程 F(x,y) 用）；非有限返回 nil。
    func evaluate(x: Double, y: Double, params: [String: Double] = [:]) -> Double? {
        let value = root.eval(x: x, y: y, params: params)
        return value.isFinite ? value : nil
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

        func eval(x: Double, y: Double, params: [String: Double]) -> Double {
            switch self {
            case .number(let v): return v
            case .variable: return x
            case .variableY: return y
            case .parameter(let name): return params[name] ?? .nan
            case .negate(let n): return -n.eval(x: x, y: y, params: params)
            case .binary(let op, let l, let r):
                let a = l.eval(x: x, y: y, params: params), b = r.eval(x: x, y: y, params: params)
                switch op {
                case "+": return a + b
                case "-": return a - b
                case "*": return a * b
                case "/": return a / b
                case "^": return pow(a, b)
                default: return .nan
                }
            case .call(let name, let arg):
                let v = arg.eval(x: x, y: y, params: params)
                switch name {
                case "sin": return sin(v)
                case "cos": return cos(v)
                case "tan": return tan(v)
                case "asin": return asin(v)
                case "acos": return acos(v)
                case "atan": return atan(v)
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
        func giacString(params: [String: Double]) -> String {
            switch self {
            case .number(let v):
                if v == .pi { return "pi" }
                if v == M_E { return "exp(1)" }
                return v == v.rounded() && abs(v) < 1e15
                    ? String(Int64(v)) : String(v)
            case .variable: return "x"
            case .variableY: return "y"
            case .parameter(let name):
                // 参数按滑块当前值代入，让 Giac 得到纯 x 表达式。
                let v = params[name] ?? 1
                return "(\(v == v.rounded() ? String(Int64(v)) : String(v)))"
            case .negate(let n):
                return "(-(\(n.giacString(params: params))))"
            case .binary(let op, let l, let r):
                return "((\(l.giacString(params: params)))\(op)(\(r.giacString(params: params))))"
            case .call(let name, let arg):
                let a = arg.giacString(params: params)
                switch name {
                case "log": return "log10(\(a))"
                case "log2": return "(ln(\(a))/ln(2))"
                default: return "\(name)(\(a))"
                }
            }
        }
    }

    /// 以 Giac/Xcas 语法输出该表达式（参数用给定滑块值代入）。
    func giacForm(params: [String: Double] = [:]) -> String {
        root.giacString(params: params)
    }

    // MARK: - 递归下降解析器

    private struct Parser {
        private let chars: [Character]
        private var pos = 0

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
