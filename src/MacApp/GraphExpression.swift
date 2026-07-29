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

    /// 解析失败返回 nil。会剥离前缀 "y=" / "f(x)="。
    init?(_ source: String) {
        let cleaned = GraphExpression.stripPrefix(source)
        guard !cleaned.isEmpty else { return nil }
        var parser = Parser(cleaned)
        guard let node = parser.parseExpression(), parser.isAtEnd else { return nil }
        root = node
    }

    /// 在给定 x 处求值；非有限（NaN/Inf，如定义域外）返回 nil。
    func evaluate(x: Double) -> Double? {
        let value = root.eval(x: x)
        return value.isFinite ? value : nil
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
        case negate(Node)
        case binary(Character, Node, Node)
        case call(String, Node)

        func eval(x: Double) -> Double {
            switch self {
            case .number(let v): return v
            case .variable: return x
            case .negate(let n): return -n.eval(x: x)
            case .binary(let op, let l, let r):
                let a = l.eval(x: x), b = r.eval(x: x)
                switch op {
                case "+": return a + b
                case "-": return a - b
                case "*": return a * b
                case "/": return a / b
                case "^": return pow(a, b)
                default: return .nan
                }
            case .call(let name, let arg):
                let v = arg.eval(x: x)
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
            var s = ""
            while let c = peek(), c.isNumber || c == "." {
                s.append(c)
                _ = advance()
            }
            // 科学计数 1e3 / 1e-3
            if let c = peek(), c == "e",
               s.range(of: "[0-9]", options: .regularExpression) != nil {
                let save = pos
                _ = advance()
                var expPart = "e"
                if let sign = peek(), sign == "+" || sign == "-" { expPart.append(sign); _ = advance() }
                if let d = peek(), d.isNumber {
                    while let dd = peek(), dd.isNumber { expPart.append(dd); _ = advance() }
                    s += expPart
                } else {
                    pos = save // 不是指数，回退（e 作为常数处理）
                }
            }
            guard let value = Double(s) else { return nil }
            return .number(value)
        }

        private mutating func parseIdentifier() -> Node? {
            var name = ""
            while let c = peek(), c.isLetter || c.isNumber {
                name.append(c)
                _ = advance()
            }

            switch name {
            case "x": return .variable
            case "pi", "π": return .number(Double.pi)
            case "e": return .number(M_E)
            default:
                break
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
