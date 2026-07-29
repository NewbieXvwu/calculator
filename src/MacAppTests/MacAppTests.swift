// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 行为级测试：对齐原 CalculatorUITests 的验证点（按键序列 → 显示结果），
// 外加 macOS 移植新增纯逻辑模块（表达式解析、图形分析、隐式追踪、单位换算）。
// 原版为 XAML UI 驱动，这里直接驱动 ViewModel/纯函数层（SPM 无 XCUITest 宿主）。

import XCTest
@testable import MacCalculator
import GiacBridge

// MARK: - 标准/科学/程序员计算（对应 CalculatorUITests 基础用例）

@MainActor
final class CalculatorViewModelTests: XCTestCase {
    private var model: StandardCalculatorViewModel!

    override func setUp() async throws {
        model = StandardCalculatorViewModel()
        await drain()
    }

    /// 桥接回调用 Task { @MainActor } 异步刷新 @Published 状态，
    /// 断言前需让出主执行器排空这些任务。
    private func drain() async {
        for _ in 0..<50 { await Task.yield() }
    }

    func testAddition() async {
        model.digitPressed(1)
        model.buttonPressed(.add)
        model.digitPressed(2)
        model.buttonPressed(.equals)
        await drain()
        XCTAssertEqual(model.displayValue, "3")
    }

    func testMultiplication() async {
        model.digitPressed(7)
        model.buttonPressed(.multiply)
        model.digitPressed(6)
        model.buttonPressed(.equals)
        await drain()
        XCTAssertEqual(model.displayValue, "42")
    }

    func testClearResetsDisplay() async {
        model.digitPressed(9)
        model.digitPressed(9)
        model.buttonPressed(.clear)
        await drain()
        XCTAssertEqual(model.displayValue, "0")
        XCTAssertTrue(model.isInputEmpty)
    }

    func testMemoryStoreAndRecall() async {
        model.digitPressed(4)
        model.digitPressed(2)
        model.memorizeNumber()
        await drain()
        XCTAssertFalse(model.isMemoryEmpty)
        model.buttonPressed(.clear)
        model.memoryItemPressed(0)
        await drain()
        XCTAssertEqual(model.displayValue, "42")
        model.clearMemory()
        await drain()
        XCTAssertTrue(model.isMemoryEmpty)
    }

    func testHistoryRecordsCalculations() async {
        model.digitPressed(1)
        model.buttonPressed(.add)
        model.digitPressed(2)
        model.buttonPressed(.equals)
        await drain()
        XCTAssertEqual(model.historyItems.first?.result, "3")
    }

    func testScientificSquare() async {
        model.setCalculatorType(.scientific)
        model.digitPressed(9)
        model.buttonPressed(.sqrt)
        await drain()
        XCTAssertEqual(model.displayValue, "3")
    }

    func testProgrammerRadixDisplays() {
        model.setCalculatorType(.programmer)
        model.digitPressed(2)
        model.digitPressed(5)
        model.digitPressed(5)
        model.updateProgrammerDisplay()
        XCTAssertEqual(model.hexDisplay, "FF")
        XCTAssertEqual(model.octDisplay, "377")
        XCTAssertEqual(model.binDisplay.replacingOccurrences(of: " ", with: ""), "11111111")
    }

    func testModeSwitchKeepsNonEngineModesOffEngine() {
        model.setCalculatorType(.date)
        XCTAssertFalse(model.mode.usesEngine)
        model.setCalculatorType(.converter)
        XCTAssertFalse(model.mode.usesEngine)
        model.setCalculatorType(.graphing)
        XCTAssertFalse(model.mode.usesEngine)
        model.setCalculatorType(.standard)
        XCTAssertTrue(model.mode.usesEngine)
    }

    func testDivideByZeroShowsError() async {
        model.digitPressed(1)
        model.buttonPressed(.divide)
        model.digitPressed(0)
        model.buttonPressed(.equals)
        await drain()
        XCTAssertTrue(model.isInError)
        model.buttonPressed(.clear)
        await drain()
        XCTAssertFalse(model.isInError)
    }
}

// MARK: - 绘图表达式解析/求值

final class GraphExpressionTests: XCTestCase {
    private func value(_ src: String, x: Double, params: [String: Double] = [:]) -> Double? {
        GraphExpression(src)?.evaluate(x: x, params: params)
    }

    func testBasicSyntax() {
        XCTAssertEqual(value("x^2", x: 3), 9)
        XCTAssertEqual(value("y=2x+1", x: 4), 9)
        XCTAssertEqual(value("(x+1)(x-1)", x: 3), 8)
        XCTAssertEqual(value("3sin(x)", x: .pi / 2)!, 3, accuracy: 1e-12)
        XCTAssertEqual(value("2 x", x: 3), 6)
        XCTAssertEqual(value("1e3 + x", x: 1), 1001)
        XCTAssertEqual(value("e^x", x: 1)!, M_E, accuracy: 1e-12)
    }

    func testPrecedence() {
        XCTAssertEqual(value("-x^2", x: 2), -4) // 一元负优先级低于 ^
        XCTAssertEqual(value("2^3^2", x: 0), 512) // 右结合
        XCTAssertEqual(value("2^-3", x: 0), 0.125)
    }

    func testDomainReturnsNil() {
        XCTAssertNil(value("sqrt(x)", x: -1))
        XCTAssertNil(value("ln(x)", x: 0))
        XCTAssertNil(value("1/x", x: 0))
    }

    func testParameters() {
        XCTAssertEqual(value("a*x^2", x: 3, params: ["a": 2]), 18)
        XCTAssertEqual(value("a x + b", x: 2, params: ["a": 3, "b": 1]), 7)
        XCTAssertEqual(value("a(x+1)", x: 4, params: ["a": 2]), 10)
        XCTAssertEqual(GraphExpression("a x + b")?.parameters, ["a", "b"])
        XCTAssertNil(value("a*x", x: 1)) // 缺参数 → nil
    }

    func testTwoVariable() {
        let f = GraphExpression(rawTwoVariable: "(x^2+y^2)-(25)")
        XCTAssertEqual(f?.evaluate(x: 3, y: 4), 0)
        XCTAssertEqual(f?.evaluate(x: 0, y: 0), -25)
    }

    func testInvalidSyntaxFails() {
        XCTAssertNil(GraphExpression("2+"))
        XCTAssertNil(GraphExpression("sin()"))
        XCTAssertNil(GraphExpression("unknown(x)"))
        XCTAssertNil(GraphExpression(""))
    }
}

// MARK: - 数值函数分析

final class GraphAnalyzerTests: XCTestCase {
    func testParabola() throws {
        let expr = try XCTUnwrap(GraphExpression("x^2-4"))
        let a = GraphAnalyzer.analyze(expr, xMin: -10, xMax: 10)
        XCTAssertEqual(a.zeros.count, 2)
        XCTAssertEqual(a.zeros[0], -2, accuracy: 1e-3)
        XCTAssertEqual(a.zeros[1], 2, accuracy: 1e-3)
        XCTAssertEqual(try XCTUnwrap(a.yIntercept), -4)
        XCTAssertEqual(a.minima.count, 1)
        XCTAssertEqual(a.minima[0].x, 0, accuracy: 1e-2)
        XCTAssertEqual(a.minima[0].y, -4, accuracy: 1e-2)
    }

    func testSine() throws {
        let expr = try XCTUnwrap(GraphExpression("sin(x)"))
        let a = GraphAnalyzer.analyze(expr, xMin: -3.14159, xMax: 3.14159)
        XCTAssertTrue(a.maxima.contains { abs($0.x - .pi / 2) < 1e-2 && abs($0.y - 1) < 1e-2 })
        XCTAssertTrue(a.minima.contains { abs($0.x + .pi / 2) < 1e-2 && abs($0.y + 1) < 1e-2 })
    }
}

// MARK: - 隐式方程 marching squares

final class MarchingSquaresTests: XCTestCase {
    func testCircle() throws {
        let f = try XCTUnwrap(GraphExpression(rawTwoVariable: "(x^2+y^2)-(25)"))
        let segs = MarchingSquares.trace(
            f: { f.evaluate(x: $0, y: $1) },
            xMin: -10, xMax: 10, yMin: -10, yMax: 10, cols: 200, rows: 200)
        XCTAssertGreaterThan(segs.count, 100)
        for s in segs {
            XCTAssertEqual((s.x1 * s.x1 + s.y1 * s.y1).squareRoot(), 5, accuracy: 0.05)
            XCTAssertEqual((s.x2 * s.x2 + s.y2 * s.y2).squareRoot(), 5, accuracy: 0.05)
        }
    }

    func testVerticalLineOnGridNodes() throws {
        let f = try XCTUnwrap(GraphExpression(rawTwoVariable: "(x)-(5)"))
        let segs = MarchingSquares.trace(
            f: { f.evaluate(x: $0, y: $1) },
            xMin: -10, xMax: 10, yMin: -10, yMax: 10, cols: 100, rows: 100)
        XCTAssertGreaterThanOrEqual(segs.count, 100)
        XCTAssertTrue(segs.allSatisfy { abs($0.x1 - 5) < 0.01 && abs($0.x2 - 5) < 0.01 })
    }

    func testHyperbola() throws {
        let f = try XCTUnwrap(GraphExpression(rawTwoVariable: "(x*y)-(4)"))
        let segs = MarchingSquares.trace(
            f: { f.evaluate(x: $0, y: $1) },
            xMin: -10, xMax: 10, yMin: -10, yMax: 10, cols: 200, rows: 200)
        XCTAssertGreaterThan(segs.count, 50)
        for s in segs {
            XCTAssertEqual(s.x1 * s.y1, 4, accuracy: 0.2)
            XCTAssertEqual(s.x2 * s.y2, 4, accuracy: 0.2)
        }
    }
}

// MARK: - Giac CAS 符号运算桥接

final class GiacEngineTests: XCTestCase {
    func testSymbolicOperations() {
        XCTAssertEqual(GiacEngine.evaluate("factor(x^2-4)"), "(x-2)*(x+2)")
        XCTAssertEqual(GiacEngine.evaluate("diff(sin(x),x)"), "cos(x)")
        XCTAssertEqual(GiacEngine.evaluate("solve(x^2=25,x)"), "list[-5,5]")
        XCTAssertEqual(GiacEngine.evaluate("limit((1+1/n)^n,n,inf)"), "exp(1)")
        XCTAssertTrue(GiacEngine.evaluate("integrate(2*x,x)").contains("x^2"))
    }

    func testNumericEvaluation() {
        XCTAssertEqual(GiacEngine.evaluate("1+2*3"), "7")
        XCTAssertEqual(GiacEngine.evaluate("evalf(pi,10)"), "3.141592654")
    }
}

// MARK: - Giac 符号函数分析（IMathSolver/IGraphAnalyzer 适配）

final class GiacMathSolverTests: XCTestCase {
    func testParabolaAnalysis() throws {
        let expr = try XCTUnwrap(GraphExpression("x^2-4"))
        let a = GiacMathSolver.analyze(expr)
        XCTAssertEqual(a.zeros, ["-2", "2"])
        XCTAssertEqual(a.yIntercept, "-4")
        XCTAssertEqual(a.parity, .even)
        XCTAssertEqual(a.minima.count, 1)
        XCTAssertEqual(a.minima[0].x, "0")
        XCTAssertEqual(a.minima[0].y, "-4")
        XCTAssertTrue(a.maxima.isEmpty)
    }

    func testCubicInflection() throws {
        let expr = try XCTUnwrap(GraphExpression("x^3-3x"))
        let a = GiacMathSolver.analyze(expr)
        XCTAssertEqual(a.parity, .odd)
        XCTAssertEqual(a.maxima.first?.x, "-1")
        XCTAssertEqual(a.maxima.first?.y, "2")
        XCTAssertEqual(a.minima.first?.x, "1")
        XCTAssertEqual(a.inflectionPoints.first?.x, "0")
    }

    func testRationalAsymptotes() throws {
        let expr = try XCTUnwrap(GraphExpression("(2x+1)/(x-3)"))
        let a = GiacMathSolver.analyze(expr)
        XCTAssertEqual(a.verticalAsymptotes, ["x = 3"])
        XCTAssertEqual(a.horizontalAsymptotes, ["y = 2"])
    }

    func testDomainAndParameters() throws {
        let sqrtExpr = try XCTUnwrap(GraphExpression("sqrt(x-1)"))
        XCTAssertEqual(GiacMathSolver.analyze(sqrtExpr).domain, "x>=1")

        let paramExpr = try XCTUnwrap(GraphExpression("a*x^2"))
        let a = GiacMathSolver.analyze(paramExpr, params: ["a": -1])
        XCTAssertEqual(a.maxima.first?.x, "0") // a<0 时顶点为极大值
    }

    func testGiacFormSerialization() throws {
        let expr = try XCTUnwrap(GraphExpression("log(x) + log2(x)"))
        let out = GiacMathSolver.ask("evalf(subst(\(expr.giacForm()),x=100))")
        XCTAssertNotNil(out)
        XCTAssertEqual(Double(out!)!, 2 + log2(100.0), accuracy: 1e-9)
    }
}

// MARK: - 单位换算

final class UnitConverterDataTests: XCTestCase {
    private func convert(_ value: Double, from: String, to: String, category: String) -> Double? {
        guard let cat = UnitConverterData.categories.first(where: { $0.name == category }),
              let f = cat.units.first(where: { $0.name == from }),
              let t = cat.units.first(where: { $0.name == to })
        else { return nil }
        return UnitConverterData.convert(value, from: f, to: t, category: cat)
    }

    func testLength() {
        XCTAssertEqual(convert(1, from: "米", to: "厘米", category: "长度")!, 100, accuracy: 1e-9)
        XCTAssertEqual(convert(1, from: "英里", to: "千米", category: "长度")!, 1.609344, accuracy: 1e-9)
    }

    func testWeight() {
        XCTAssertEqual(convert(1, from: "千克", to: "磅", category: "重量和质量")!, 2.2046226218, accuracy: 1e-6)
    }

    func testTemperature() {
        XCTAssertEqual(convert(100, from: "摄氏度", to: "华氏度", category: "温度")!, 212, accuracy: 1e-9)
        XCTAssertEqual(convert(32, from: "华氏度", to: "摄氏度", category: "温度")!, 0, accuracy: 1e-9)
        XCTAssertEqual(convert(0, from: "摄氏度", to: "开尔文", category: "温度")!, 273.15, accuracy: 1e-9)
    }

    func testData() {
        XCTAssertEqual(convert(1, from: "吉字节", to: "兆字节", category: "数据")!, 1000, accuracy: 1e-9)
    }
}
