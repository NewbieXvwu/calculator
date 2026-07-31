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
        // 清除记忆的模式，保证每个用例都从默认标准模式起步（隔离宿主 UserDefaults）。
        UserDefaults.standard.removeObject(forKey: "LastCalculatorMode")
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

    // MARK: 表达式 token 编辑（对应原版 UpdateOperand + Recalculate，P3-2）

    func testExpressionTokenOperandEditingMidExpression() async {
        // 标准模式无优先级:1 + 2 + 会折叠为 "3 +"(原版行为),编辑该操作数。
        model.digitPressed(1)
        model.buttonPressed(.add)
        model.digitPressed(2)
        model.buttonPressed(.add)
        await drain()
        XCTAssertTrue(model.isOperandTokenEditable(0))
        XCTAssertFalse(model.isOperandTokenEditable(2))
        XCTAssertTrue(model.updateOperand(tokenIndex: 0, newText: "5"))
        await drain()
        XCTAssertEqual(model.expressionTokens.map(\.text).joined().filter { !$0.isWhitespace }, "5+")
        model.digitPressed(3)
        model.buttonPressed(.equals)
        await drain()
        XCTAssertEqual(model.displayValue, "8")
    }

    func testExpressionTokenOperandEditingScientificKeepsFullExpression() async {
        // 科学模式有优先级,表达式完整保留:编辑中间操作数 2 → 5,1 + 5 × 4 = 21。
        model.setCalculatorType(.scientific)
        model.digitPressed(1)
        model.buttonPressed(.add)
        model.digitPressed(2)
        model.buttonPressed(.multiply)
        await drain()
        guard let index = model.expressionTokens.firstIndex(where: { $0.text.trimmingCharacters(in: .whitespaces) == "2" }) else {
            return XCTFail("找不到操作数 token 2：\(model.expressionTokens.map(\.text))")
        }
        XCTAssertTrue(model.isOperandTokenEditable(index))
        XCTAssertTrue(model.updateOperand(tokenIndex: index, newText: "5"))
        await drain()
        model.digitPressed(4)
        model.buttonPressed(.equals)
        await drain()
        XCTAssertEqual(model.displayValue, "21")
    }

    func testExpressionTokenEditingAfterEquals() async {
        model.digitPressed(1)
        model.buttonPressed(.add)
        model.digitPressed(2)
        model.buttonPressed(.equals)
        await drain()
        guard let index = model.expressionTokens.lastIndex(where: { $0.text.trimmingCharacters(in: .whitespaces) == "2" }) else {
            return XCTFail("找不到操作数 token 2：\(model.expressionTokens.map(\.text))")
        }
        XCTAssertTrue(model.updateOperand(tokenIndex: index, newText: "-7.5"))
        model.buttonPressed(.equals)
        await drain()
        XCTAssertEqual(model.displayValue, "-6.5")
    }

    func testExpressionTokenEditRejectsInvalidInput() async {
        model.digitPressed(1)
        model.buttonPressed(.add)
        model.digitPressed(2)
        await drain()
        XCTAssertFalse(model.updateOperand(tokenIndex: 0, newText: "abc"))
        XCTAssertFalse(model.updateOperand(tokenIndex: 99, newText: "3"))
        XCTAssertFalse(model.isOperandTokenEditable(99))
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

    func testBitShiftModeKeypadKeys() {
        XCTAssertEqual(BitShiftMode.arithmetic.leftKey.command, .lshf)
        XCTAssertEqual(BitShiftMode.arithmetic.rightKey.command, .rshf)
        XCTAssertEqual(BitShiftMode.logical.leftKey.command, .lshf)
        XCTAssertEqual(BitShiftMode.logical.rightKey.command, .rshfl)
        XCTAssertEqual(BitShiftMode.rotate.leftKey.command, .rol)
        XCTAssertEqual(BitShiftMode.rotate.rightKey.command, .ror)
        XCTAssertEqual(BitShiftMode.rotateCarry.leftKey.command, .rolc)
        XCTAssertEqual(BitShiftMode.rotateCarry.rightKey.command, .rorc)
    }

    func testProgrammerArithmeticShift() async {
        model.setCalculatorType(.programmer)
        model.digitPressed(1)
        model.buttonPressed(.lshf)
        model.digitPressed(4)
        model.buttonPressed(.equals)
        await drain()
        XCTAssertEqual(model.displayValue.replacingOccurrences(of: " ", with: ""), "16")
    }

    /// 模式持久化往返（对应原版记忆当前模式）：切模式写入 UserDefaults，新实例启动恢复。
    func testModePersistenceRoundTrip() {
        for m in [CalculatorMode.standard, .scientific, .programmer, .date, .converter, .graphing] {
            XCTAssertEqual(CalculatorMode(persistenceKey: m.persistenceKey), m)
        }
        model.setCalculatorType(.scientific)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "LastCalculatorMode"), "scientific")
        let restored = StandardCalculatorViewModel()
        XCTAssertEqual(restored.mode, .scientific)
        // 复位，避免污染其它用例的宿主默认值。
        model.setCalculatorType(.standard)
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

    // MARK: - 键盘快捷键（对照 Resources.resw KeyboardShortcutManager 词条）

    private func key(_ chars: String, keyCode: UInt16 = 0,
                     shift: Bool = false, control: Bool = false, command: Bool = false) -> Bool {
        model.handleKey(chars: chars, keyCode: keyCode,
                        modifiers: .init(command: command, shift: shift, control: control))
    }

    func testKeyboardBasicArithmetic() async {
        XCTAssertTrue(key("5"))
        XCTAssertTrue(key("+"))
        XCTAssertTrue(key("3"))
        XCTAssertTrue(key("=", keyCode: 36))
        await drain()
        XCTAssertEqual(model.displayValue, "8")
    }

    func testKeyboardCommandPassthrough() {
        XCTAssertFalse(key("c", command: true), "⌘ 组合应放行给菜单栏")
    }

    func testKeyboardScientificLetterChords() async {
        model.setCalculatorType(.scientific)
        model.digitPressed(9)
        XCTAssertTrue(key("q")) // Q → x²
        await drain()
        XCTAssertEqual(model.displayValue, "81")

        model.buttonPressed(.clear)
        XCTAssertTrue(key("p")) // P → π
        await drain()
        XCTAssertTrue(model.displayValue.hasPrefix("3.14"))

        // Shift+E → euler
        model.buttonPressed(.clear)
        XCTAssertTrue(key("E", shift: true))
        await drain()
        XCTAssertTrue(model.displayValue.hasPrefix("2.71"))
    }

    func testKeyboardScientificHyperbolicChords() async {
        model.setCalculatorType(.scientific)
        model.buttonPressed(.clear)
        XCTAssertTrue(key("s", control: true)) // Ctrl+S → sinh(0)=0
        await drain()
        XCTAssertEqual(model.displayValue, "0")
        XCTAssertTrue(key("o", shift: false, control: true)) // Ctrl+O → cosh(0)=1
        await drain()
        XCTAssertEqual(model.displayValue, "1")
    }

    func testKeyboardScientificPunctuation() async {
        model.setCalculatorType(.scientific)
        model.digitPressed(5)
        XCTAssertTrue(key("!")) // 阶乘
        await drain()
        XCTAssertEqual(model.displayValue, "120")
        model.buttonPressed(.clear)
        model.digitPressed(2)
        XCTAssertTrue(key("#")) // x³
        await drain()
        XCTAssertEqual(model.displayValue, "8")
        XCTAssertFalse(key("&"), "& 仅程序员模式有效")
    }

    func testKeyboardProgrammerChords() async {
        model.setCalculatorType(.programmer)
        // ^ → XOR：5 ^ 3 = 6
        model.digitPressed(5)
        XCTAssertTrue(key("^"))
        model.digitPressed(3)
        XCTAssertTrue(key("=", keyCode: 36))
        await drain()
        XCTAssertEqual(model.displayValue, "6")

        // A–F 仅 HEX 进制可用。
        model.buttonPressed(.clear)
        XCTAssertTrue(key("a"))
        await drain()
        XCTAssertEqual(model.displayValue, "0", "DEC 进制下 A 应被吞掉不生效")
        model.switchRadix(.hex)
        XCTAssertTrue(key("f"))
        await drain()
        XCTAssertEqual(model.displayValue, "F")

        // BIN 进制过滤数字 2-9。
        model.buttonPressed(.clear)
        model.switchRadix(.bin)
        XCTAssertTrue(key("2"))
        await drain()
        XCTAssertEqual(model.displayValue, "0")
        XCTAssertTrue(key("1"))
        await drain()
        XCTAssertEqual(model.displayValue, "1")
        model.switchRadix(.dec)
    }

    func testKeyboardProgrammerFunctionKeys() async {
        model.setCalculatorType(.programmer)
        XCTAssertTrue(key("", keyCode: 99)) // F3 → DWORD
        XCTAssertEqual(model.wordSize, .dword)
        XCTAssertTrue(key("", keyCode: 96)) // F5 → HEX
        XCTAssertEqual(model.currentRadix, .hex)
        XCTAssertTrue(key("", keyCode: 97)) // F6 → DEC
        XCTAssertEqual(model.currentRadix, .dec)
        XCTAssertTrue(key("", keyCode: 120)) // F2 → QWORD
        XCTAssertEqual(model.wordSize, .qword)
    }

    func testKeyboardScientificFunctionKeys() {
        model.setCalculatorType(.scientific)
        XCTAssertTrue(key("", keyCode: 96)) // F5 → RAD
        XCTAssertEqual(model.currentAngleType, .rad)
        XCTAssertTrue(key("", keyCode: 99)) // F3 → GRAD
        XCTAssertEqual(model.currentAngleType, .grad)
        XCTAssertTrue(key("", keyCode: 118)) // F4 → DEG
        XCTAssertEqual(model.currentAngleType, .deg)
    }

    func testKeyboardMemoryChords() async {
        model.digitPressed(4)
        model.digitPressed(2)
        XCTAssertTrue(key("m", control: true)) // Ctrl+M → MS
        await drain()
        XCTAssertFalse(model.isMemoryEmpty)
        model.buttonPressed(.clear)
        XCTAssertTrue(key("r", control: true)) // Ctrl+R → MR
        await drain()
        XCTAssertEqual(model.displayValue, "42")
        XCTAssertTrue(key("l", control: true)) // Ctrl+L → MC
        await drain()
        XCTAssertTrue(model.isMemoryEmpty)
    }

    func testKeyboardClearHistoryChord() async {
        model.digitPressed(1)
        model.buttonPressed(.add)
        model.digitPressed(1)
        model.buttonPressed(.equals)
        await drain()
        XCTAssertFalse(model.historyItems.isEmpty)
        XCTAssertTrue(key("d", shift: true, control: true)) // Ctrl+Shift+D
        await drain()
        XCTAssertTrue(model.historyItems.isEmpty)
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

    func testKeyGraphFeaturesFullFields() throws {
        let expr = try XCTUnwrap(GraphExpression("x^2-4"))
        let a = GiacMathSolver.analyze(expr)
        XCTAssertEqual(a.range, "[-4, +∞)")
        XCTAssertEqual(a.periodicity, L10n.string("Mac_Aperiodic"))
        XCTAssertEqual(a.monotonicity.count, 2)
        XCTAssertEqual(a.monotonicity[0].interval, "(-∞, 0)")
        XCTAssertEqual(a.monotonicity[0].direction, L10n.string("KGFMonotonicityDecreasing"))
        XCTAssertEqual(a.monotonicity[1].interval, "(0, +∞)")
        XCTAssertEqual(a.monotonicity[1].direction, L10n.string("KGFMonotonicityIncreasing"))
        XCTAssertTrue(a.obliqueAsymptotes.isEmpty)
    }

    func testPeriodicGeneralZeros() throws {
        let expr = try XCTUnwrap(GraphExpression("sin(x)"))
        let a = GiacMathSolver.analyze(expr)
        // all_trig_solutions 通解：n_0*pi → 展示为 n·π。
        XCTAssertTrue(a.zeros.contains { $0.contains("n·π") }, "zeros: \(a.zeros)")
        XCTAssertEqual(a.periodicity, "2·π")
    }

    func testObliqueAsymptote() throws {
        let expr = try XCTUnwrap(GraphExpression("(x^2+1)/x"))
        let a = GiacMathSolver.analyze(expr)
        XCTAssertEqual(a.obliqueAsymptotes, ["y = x"])
        XCTAssertEqual(a.verticalAsymptotes, ["x = 0"])
    }
}

// MARK: - 绘图 ViewModel（不等式/跟踪吸附/三角单位）

@MainActor
final class GraphingViewModelTests: XCTestCase {
    func testInequalityCompile() throws {
        let vm = GraphingViewModel()
        vm.addEquation(text: "y<x^2")
        guard case .inequality(let f, let rel)? = vm.equations.last?.compiled else {
            return XCTFail("y<x^2 应编译为不等式")
        }
        XCTAssertEqual(rel, .lessThan)
        XCTAssertTrue(rel.isStrict)
        // F = y - x^2：(0, -1) 在区域内，(0, 1) 不在。
        XCTAssertTrue(rel.satisfied(try XCTUnwrap(f.evaluate(x: 0, y: -1))))
        XCTAssertFalse(rel.satisfied(try XCTUnwrap(f.evaluate(x: 0, y: 1))))

        vm.addEquation(text: "x^2+y^2<=25")
        guard case .inequality(let g, let rel2)? = vm.equations.last?.compiled else {
            return XCTFail("圆不等式应编译为不等式")
        }
        XCTAssertEqual(rel2, .lessOrEqual)
        XCTAssertFalse(rel2.isStrict)
        XCTAssertTrue(rel2.satisfied(try XCTUnwrap(g.evaluate(x: 0, y: 0))))
        XCTAssertTrue(rel2.satisfied(try XCTUnwrap(g.evaluate(x: 5, y: 0)))) // 边界含于 ≤
        XCTAssertFalse(rel2.satisfied(try XCTUnwrap(g.evaluate(x: 6, y: 0))))

        // Unicode ≥ 归一化。
        vm.addEquation(text: "y≥x")
        guard case .inequality(_, let rel3)? = vm.equations.last?.compiled else {
            return XCTFail("y≥x 应编译为不等式")
        }
        XCTAssertEqual(rel3, .greaterOrEqual)
    }

    func testInequalityErrors() {
        let vm = GraphingViewModel()
        vm.addEquation(text: "y<")
        XCTAssertTrue(vm.equations.last?.hasError ?? false)
        vm.addEquation(text: "1<x<2")
        XCTAssertTrue(vm.equations.last?.hasError ?? false)
    }

    func testNearestCurvePointSnapping() {
        let vm = GraphingViewModel() // 默认含 y=x^2 与 y=sin(x)
        let hit = vm.nearestCurvePoint(mathX: 2, mathY: 4.2)
        XCTAssertEqual(hit?.equationIndex, 0)
        XCTAssertEqual(hit?.y ?? .nan, 4, accuracy: 1e-12)

        let hit2 = vm.nearestCurvePoint(mathX: 2, mathY: 0.8)
        XCTAssertEqual(hit2?.equationIndex, 1)
        XCTAssertEqual(hit2?.y ?? .nan, sin(2), accuracy: 1e-12)
    }

    func testTrigModeEvaluation() throws {
        let sinExpr = try XCTUnwrap(GraphExpression("sin(x)"))
        XCTAssertEqual(try XCTUnwrap(sinExpr.evaluate(x: 90, trig: .degrees)), 1, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(sinExpr.evaluate(x: 100, trig: .gradians)), 1, accuracy: 1e-12)
        let asinExpr = try XCTUnwrap(GraphExpression("asin(x)"))
        XCTAssertEqual(try XCTUnwrap(asinExpr.evaluate(x: 1, trig: .degrees)), 90, accuracy: 1e-12)
        // 双曲函数不受角度单位影响。
        let sinhExpr = try XCTUnwrap(GraphExpression("sinh(x)"))
        XCTAssertEqual(try XCTUnwrap(sinhExpr.evaluate(x: 1, trig: .degrees)), sinh(1), accuracy: 1e-12)
    }
}

// MARK: - MathLive 公式编辑器

final class MathInputFieldTests: XCTestCase {
    func testBundledAssetsPresent() {
        let html = Bundle.module.url(forResource: "mathfield", withExtension: "html", subdirectory: "MathLiveAssets")
        XCTAssertNotNil(html)
        let js = Bundle.module.url(forResource: "mathlive.min", withExtension: "js", subdirectory: "MathLiveAssets")
        XCTAssertNotNil(js)
        let font = Bundle.module.url(
            forResource: "KaTeX_Main-Regular", withExtension: "woff2", subdirectory: "MathLiveAssets/fonts")
        XCTAssertNotNil(font)
    }

    func testAsciiMathNormalization() {
        XCTAssertEqual(MathInputField.normalizeAsciiMath("2⋅x"), "2*x")
        XCTAssertEqual(MathInputField.normalizeAsciiMath("x×y÷2"), "x*y/2")
        XCTAssertEqual(MathInputField.normalizeAsciiMath("−x^2"), "-x^2")
        XCTAssertEqual(MathInputField.normalizeAsciiMath("√(x)"), "sqrt(x)")
        XCTAssertEqual(MathInputField.normalizeAsciiMath(" sin(π) "), "sin(pi)")
        // 归一化结果应能被计算器语法解析。
        XCTAssertNotNil(GraphExpression(MathInputField.normalizeAsciiMath("(x+1)⋅(x−1)")))
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
        XCTAssertEqual(convert(1, from: L10n.string("UnitName_Meter"), to: L10n.string("UnitName_Centimeter"), category: L10n.string("CategoryName_LengthText"))!, 100, accuracy: 1e-9)
        XCTAssertEqual(convert(1, from: L10n.string("UnitName_Mile"), to: L10n.string("UnitName_Kilometer"), category: L10n.string("CategoryName_LengthText"))!, 1.609344, accuracy: 1e-9)
    }

    func testWeight() {
        XCTAssertEqual(convert(1, from: L10n.string("UnitName_Kilogram"), to: L10n.string("UnitName_Pound"), category: L10n.string("CategoryName_WeightText"))!, 2.2046226218, accuracy: 1e-6)
    }

    func testTemperature() {
        XCTAssertEqual(convert(100, from: L10n.string("UnitName_DegreesCelsius"), to: L10n.string("UnitName_DegreesFahrenheit"), category: L10n.string("CategoryName_TemperatureText"))!, 212, accuracy: 1e-9)
        XCTAssertEqual(convert(32, from: L10n.string("UnitName_DegreesFahrenheit"), to: L10n.string("UnitName_DegreesCelsius"), category: L10n.string("CategoryName_TemperatureText"))!, 0, accuracy: 1e-9)
        XCTAssertEqual(convert(0, from: L10n.string("UnitName_DegreesCelsius"), to: L10n.string("UnitName_Kelvin"), category: L10n.string("CategoryName_TemperatureText"))!, 273.15, accuracy: 1e-9)
    }

    func testData() {
        XCTAssertEqual(convert(1, from: L10n.string("UnitName_Gigabyte"), to: L10n.string("UnitName_Megabyte"), category: L10n.string("CategoryName_DataText"))!, 1000, accuracy: 1e-9)
    }

    func testWhimsicalFactors() {
        // 原版 UnitConverterDataLoader.cpp 因子表抽查。
        XCTAssertEqual(convert(1, from: L10n.string("UnitName_Elephant"), to: L10n.string("UnitName_Kilogram"), category: L10n.string("CategoryName_WeightText"))!, 4000, accuracy: 1e-9)
        XCTAssertEqual(convert(1, from: L10n.string("UnitName_SoccerField"), to: L10n.string("UnitName_SquareMeter"), category: L10n.string("CategoryName_AreaText"))!, 10869.66, accuracy: 1e-9)
        XCTAssertEqual(convert(1, from: L10n.string("UnitName_DVD"), to: L10n.string("UnitName_Megabyte"), category: L10n.string("CategoryName_DataText"))!, 4700, accuracy: 1e-9)
        XCTAssertEqual(convert(1, from: L10n.string("UnitName_Banana"), to: L10n.string("UnitName_Joule"), category: L10n.string("CategoryName_EnergyText"))!, 439614, accuracy: 1e-9)
        XCTAssertEqual(convert(1, from: L10n.string("UnitName_JumboJet"), to: L10n.string("UnitName_Meter"), category: L10n.string("CategoryName_LengthText"))!, 76, accuracy: 1e-9)
    }

    func testWhimsicalNotSelectable() {
        for cat in UnitConverterData.categories {
            XCTAssertFalse(cat.selectableUnits.contains { $0.isWhimsical },
                           "\(cat.name) 下拉框不应包含趣味单位")
        }
        let weight = UnitConverterData.categories.first { $0.name == L10n.string("CategoryName_WeightText") }!
        XCTAssertTrue(weight.units.contains { $0.isWhimsical })
    }

    @MainActor
    func testSupplementaryResultsAppendSingleWhimsical() {
        let vm = UnitConverterViewModel()
        let weight = UnitConverterData.categories.first { $0.name == L10n.string("CategoryName_WeightText") }!
        vm.selectCategory(weight)
        vm.selectFromUnit(weight.units.first { $0.name == L10n.string("UnitName_Kilogram") }!)
        vm.inputDigit(4)
        for _ in 0..<3 { vm.inputDigit(0) } // 4000 kg = 1 大象
        let whimsicalIDs = Set(weight.units.filter { $0.isWhimsical }.map { $0.id })
        let whimsicalResults = vm.supplementaryResults.filter { whimsicalIDs.contains($0.id) }
        XCTAssertEqual(whimsicalResults.count, 1, "补充结果应恰好含一个趣味条目")
        XCTAssertTrue(whimsicalIDs.contains(vm.supplementaryResults.last!.id), "趣味条目应在末位")
        // 4000 kg 恰为 1 大象（量级 |log10(1)|=0 最小，应被选为最佳趣味结果）。
        XCTAssertEqual(vm.supplementaryResults.last!.abbreviation, L10n.string("UnitAbbreviation_Elephant"))
        XCTAssertEqual(vm.supplementaryResults.last!.value, "1")
    }

    /// 换算显示走 Locale：千分位分组 + 本地化小数点（不依赖宿主语言）。
    @MainActor
    func testConverterDisplayUsesLocaleSeparators() {
        let g = UnitConverterViewModel.localeGrouping
        let d = UnitConverterViewModel.localeDecimal
        XCTAssertEqual(UnitConverterViewModel.localizedDisplay("1234567"), "1\(g)234\(g)567")
        XCTAssertEqual(UnitConverterViewModel.localizedDisplay("1234.5"), "1\(g)234\(d)5")
        XCTAssertEqual(UnitConverterViewModel.localizedDisplay("-1000"), "-1\(g)000")
        XCTAssertEqual(UnitConverterViewModel.localizedDisplay("42"), "42")
        // 科学计数法只替换小数点，不分组。
        XCTAssertEqual(UnitConverterViewModel.localizedDisplay("1.5e+20"), "1\(d)5e+20")
    }
}

// MARK: - CopyPasteManager（迁移自 CalculatorUnitTests/CopyPasteManagerTest.cpp）

final class CopyPasteManagerTests: XCTestCase {
    private typealias CPM = CopyPasteManager

    private func assertPositive(
        _ inputs: [String], mode: CPM.PasteMode,
        radix: RadixKind = .dec, wordSize: WordSize = .qword,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        for input in inputs {
            XCTAssertEqual(
                CPM.validate(input, mode: mode, radix: radix, wordSize: wordSize), input,
                "应接受: \(input.debugDescription)", file: file, line: line)
        }
    }

    private func assertNegative(
        _ inputs: [String], mode: CPM.PasteMode,
        radix: RadixKind = .dec, wordSize: WordSize = .qword,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        for input in inputs {
            XCTAssertNil(
                CPM.validate(input, mode: mode, radix: radix, wordSize: wordSize),
                "应拒绝: \(input.debugDescription)", file: file, line: line)
        }
    }

    func testValidatePasteExpressionErrorStates() {
        var expTooLong = ""
        for _ in 0..<(CPM.maxPasteableLength / 8) {
            expTooLong += "-1234567"
        }
        XCTAssertEqual(CPM.validate(expTooLong, mode: .standard), expTooLong, "最大长度以内应接受")
        expTooLong += "1"
        XCTAssertNil(CPM.validate(expTooLong, mode: .standard), "超出最大长度应拒绝")

        XCTAssertNil(CPM.validate("", mode: .standard), "空串应拒绝")
        XCTAssertNil(CPM.validate("1a23f456", mode: .standard), "当前模式不支持的字符应拒绝")
    }

    func testValidateExtractOperands() {
        XCTAssertEqual(CPM.extractOperands("123456", mode: .standard), ["123456"])
        XCTAssertEqual(CPM.extractOperands("123^456", mode: .standard), ["123^456"])
        XCTAssertEqual(CPM.extractOperands("123+456", mode: .standard), ["123", "456"])
        XCTAssertEqual(CPM.extractOperands("123-456", mode: .standard), ["123", "456"])
        XCTAssertEqual(CPM.extractOperands("123*456", mode: .standard), ["123", "456"])
        XCTAssertEqual(CPM.extractOperands("123/456", mode: .standard), ["123", "456"])
        XCTAssertEqual(CPM.extractOperands("123e456", mode: .standard), ["123e456"])
        XCTAssertEqual(CPM.extractOperands("123e4567", mode: .standard), ["123e4567"])
        XCTAssertEqual(CPM.extractOperands("((45)+(-30))", mode: .scientific), ["((45)", "(-30))"])
    }

    func testValidateExtractOperandsErrors() {
        var expOperandLimit = ""
        for _ in 0..<CPM.maxOperandCount {
            expOperandLimit += "+1"
        }
        XCTAssertEqual(CPM.extractOperands(expOperandLimit, mode: .standard).count, 100, "最多允许 100 个操作数")
        expOperandLimit += "+1"
        XCTAssertEqual(CPM.extractOperands(expOperandLimit, mode: .standard).count, 0, "操作数过多返回空")

        XCTAssertEqual(CPM.extractOperands("12e9999", mode: .standard).count, 1, "指数最多 4 位")
        XCTAssertEqual(CPM.extractOperands("12e10000", mode: .standard).count, 0, "指数过长返回空")
    }

    func testValidateExpressionRegExMatch() {
        XCTAssertFalse(CPM.expressionRegExMatch([], mode: .standard), "空操作数列表返回 false")

        // 超长操作数
        XCTAssertFalse(CPM.expressionRegExMatch(["12345678901234567"], mode: .standard))
        XCTAssertFalse(CPM.expressionRegExMatch(["123456789012345678901234567890123"], mode: .scientific))
        XCTAssertFalse(CPM.expressionRegExMatch(["12345678901234567"], mode: .converter))
        XCTAssertFalse(CPM.expressionRegExMatch(["11111111111111111"], mode: .programmer, radix: .hex, wordSize: .qword))
        XCTAssertFalse(CPM.expressionRegExMatch(["12345678901234567890"], mode: .programmer, radix: .dec, wordSize: .qword))
        XCTAssertFalse(CPM.expressionRegExMatch(["11111111111111111111111"], mode: .programmer, radix: .oct, wordSize: .qword))
        XCTAssertFalse(CPM.expressionRegExMatch(
            ["10000000000000000000000000000000000000000000000000000000000000000"],
            mode: .programmer, radix: .bin, wordSize: .qword))

        // 超最大值
        XCTAssertFalse(
            CPM.expressionRegExMatch(["9223372036854775808"], mode: .programmer, radix: .dec, wordSize: .qword),
            "超最大值应返回 false")

        XCTAssertTrue(
            CPM.expressionRegExMatch(["((((((((((((((((((((123))))))))))))))))))))"], mode: .scientific),
            "清洗后的操作数应视为长度以内")
        XCTAssertTrue(
            CPM.expressionRegExMatch(["9223372036854775807"], mode: .programmer, radix: .dec, wordSize: .qword),
            "等于最大值应返回 true")
        XCTAssertTrue(
            CPM.expressionRegExMatch(["-9223372036854775808"], mode: .programmer, radix: .dec, wordSize: .qword),
            "等于最小负值应返回 true")

        // 所有操作数都必须匹配
        XCTAssertTrue(CPM.expressionRegExMatch(["123", "456"], mode: .standard))
        XCTAssertTrue(CPM.expressionRegExMatch(["123", "1e23"], mode: .standard))
        XCTAssertFalse(CPM.expressionRegExMatch(["123", "fab10"], mode: .standard))

        XCTAssertTrue(
            CPM.expressionRegExMatch(
                ["1.23e+456", "1.23e456", ".23e+456", "123e-456", "12e2", "12e+2", "12e-2", "-12e2", "-12e+2", "-12e-2"],
                mode: .scientific),
            "科学模式接受指数")

        XCTAssertFalse(
            CPM.expressionRegExMatch(["123", "12345678901234567"], mode: .standard),
            "所有操作数都要在最大长度内")
        XCTAssertFalse(
            CPM.expressionRegExMatch(["123", "9223372036854775808"], mode: .programmer, radix: .dec, wordSize: .qword),
            "所有操作数都要在最大值内")
    }

    func testValidateGetMaxOperandLengthAndValue() {
        typealias LV = CopyPasteManager.MaxOperandLengthAndValue

        XCTAssertEqual(
            CPM.maxOperandLengthAndValue(mode: .standard, radix: .dec, wordSize: .qword),
            LV(maxLength: CPM.maxStandardOperandLength, maxValue: 0))
        XCTAssertEqual(
            CPM.maxOperandLengthAndValue(mode: .scientific, radix: .dec, wordSize: .qword),
            LV(maxLength: CPM.maxScientificOperandLength, maxValue: 0))
        XCTAssertEqual(
            CPM.maxOperandLengthAndValue(mode: .converter, radix: .dec, wordSize: .qword),
            LV(maxLength: CPM.maxConverterInputLength, maxValue: 0))

        let qwordMax = UInt64.max
        let dwordMax = UInt64(UInt32.max)
        let wordMax = UInt64(UInt16.max)
        let byteMax = UInt64(UInt8.max)

        // Hex
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .hex, wordSize: .qword), LV(maxLength: 16, maxValue: qwordMax))
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .hex, wordSize: .dword), LV(maxLength: 8, maxValue: dwordMax))
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .hex, wordSize: .word), LV(maxLength: 4, maxValue: wordMax))
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .hex, wordSize: .byte), LV(maxLength: 2, maxValue: byteMax))
        // Dec
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .dec, wordSize: .qword), LV(maxLength: 19, maxValue: qwordMax >> 1))
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .dec, wordSize: .dword), LV(maxLength: 10, maxValue: dwordMax >> 1))
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .dec, wordSize: .word), LV(maxLength: 5, maxValue: wordMax >> 1))
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .dec, wordSize: .byte), LV(maxLength: 3, maxValue: byteMax >> 1))
        // Oct
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .oct, wordSize: .qword), LV(maxLength: 22, maxValue: qwordMax))
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .oct, wordSize: .dword), LV(maxLength: 11, maxValue: dwordMax))
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .oct, wordSize: .word), LV(maxLength: 6, maxValue: wordMax))
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .oct, wordSize: .byte), LV(maxLength: 3, maxValue: byteMax))
        // Bin
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .bin, wordSize: .qword), LV(maxLength: 64, maxValue: qwordMax))
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .bin, wordSize: .dword), LV(maxLength: 32, maxValue: dwordMax))
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .bin, wordSize: .word), LV(maxLength: 16, maxValue: wordMax))
        XCTAssertEqual(CPM.maxOperandLengthAndValue(mode: .programmer, radix: .bin, wordSize: .byte), LV(maxLength: 8, maxValue: byteMax))
    }

    func testValidateSanitizeOperand() {
        XCTAssertEqual(CPM.sanitizeOperand("((1234"), "1234")
        XCTAssertEqual(CPM.sanitizeOperand("1234))"), "1234")
        XCTAssertEqual(CPM.sanitizeOperand("-1234"), "1234")
        XCTAssertEqual(CPM.sanitizeOperand("+1234"), "1234")
        XCTAssertEqual(CPM.sanitizeOperand("-(1234)"), "1234")
        XCTAssertEqual(CPM.sanitizeOperand("+(1234)"), "1234")
        XCTAssertEqual(CPM.sanitizeOperand("12-34"), "1234")
        XCTAssertEqual(CPM.sanitizeOperand("((((1234))))"), "1234")
        XCTAssertEqual(CPM.sanitizeOperand("1'2'3'4"), "1234")
        XCTAssertEqual(CPM.sanitizeOperand("'''''1234''''"), "1234")
        XCTAssertEqual(CPM.sanitizeOperand("1_2_3_4"), "1234")
        XCTAssertEqual(CPM.sanitizeOperand("______1234___"), "1234")
    }

    func testValidatePrefixCurrencySymbols() {
        XCTAssertEqual(CPM.removeUnwantedChars("\u{00A5}5"), "5") // ¥
        XCTAssertEqual(CPM.removeUnwantedChars("\u{00A4}5"), "5") // ¤
        XCTAssertEqual(CPM.removeUnwantedChars("\u{20B5}5"), "5") // ₵
        XCTAssertEqual(CPM.removeUnwantedChars("$5"), "5")
        XCTAssertEqual(CPM.removeUnwantedChars("\u{20A1}5"), "5") // ₡
        XCTAssertEqual(CPM.removeUnwantedChars("\u{20A9}5"), "5") // ₩
        XCTAssertEqual(CPM.removeUnwantedChars("\u{20AA}5"), "5") // ₪
        XCTAssertEqual(CPM.removeUnwantedChars("\u{20A6}5"), "5") // ₦
        XCTAssertEqual(CPM.removeUnwantedChars("\u{20B9}5"), "5") // ₹
        XCTAssertEqual(CPM.removeUnwantedChars("\u{00A3}5"), "5") // £
        XCTAssertEqual(CPM.removeUnwantedChars("\u{20AC}5"), "5") // €
    }

    func testValidateTryOperandToULL() {
        // Hex
        XCTAssertEqual(CPM.tryOperandToULL("1234", radix: .hex), 0x1234)
        XCTAssertEqual(CPM.tryOperandToULL("FF", radix: .hex), 0xFF)
        XCTAssertEqual(CPM.tryOperandToULL("FFFFFFFFFFFFFFFF", radix: .hex), UInt64.max)
        XCTAssertEqual(CPM.tryOperandToULL("0xFFFFFFFFFFFFFFFF", radix: .hex), UInt64.max)
        XCTAssertEqual(CPM.tryOperandToULL("0XFFFFFFFFFFFFFFFF", radix: .hex), UInt64.max)
        XCTAssertEqual(CPM.tryOperandToULL("0X0FFFFFFFFFFFFFFFF", radix: .hex), UInt64.max)
        // Dec
        XCTAssertEqual(CPM.tryOperandToULL("1234", radix: .dec), 1234)
        XCTAssertEqual(CPM.tryOperandToULL("18446744073709551615", radix: .dec), UInt64.max)
        XCTAssertEqual(CPM.tryOperandToULL("018446744073709551615", radix: .dec), UInt64.max)
        // Oct
        XCTAssertEqual(CPM.tryOperandToULL("777", radix: .oct), 0o777)
        XCTAssertEqual(CPM.tryOperandToULL("0777", radix: .oct), 0o777)
        XCTAssertEqual(CPM.tryOperandToULL("1777777777777777777777", radix: .oct), UInt64.max)
        XCTAssertEqual(CPM.tryOperandToULL("01777777777777777777777", radix: .oct), UInt64.max)
        // Bin
        XCTAssertEqual(CPM.tryOperandToULL("1111", radix: .bin), 0b1111)
        XCTAssertEqual(CPM.tryOperandToULL("0010", radix: .bin), 0b10)
        XCTAssertEqual(
            CPM.tryOperandToULL("1111111111111111111111111111111111111111111111111111111111111111", radix: .bin),
            UInt64.max)
        XCTAssertEqual(
            CPM.tryOperandToULL("01111111111111111111111111111111111111111111111111111111111111111", radix: .bin),
            UInt64.max)

        // 溢出 / 非法输入返回 nil
        XCTAssertNil(CPM.tryOperandToULL("0xFFFFFFFFFFFFFFFFF1", radix: .hex))
        XCTAssertNil(CPM.tryOperandToULL("18446744073709551616", radix: .dec))
        XCTAssertNil(CPM.tryOperandToULL("2000000000000000000000", radix: .oct))
        XCTAssertNil(CPM.tryOperandToULL(
            "11111111111111111111111111111111111111111111111111111111111111111", radix: .bin))
        XCTAssertNil(CPM.tryOperandToULL("-1", radix: .dec))
        XCTAssertNil(CPM.tryOperandToULL("5555", radix: .bin))
        XCTAssertNil(CPM.tryOperandToULL("xyz", radix: .bin))
    }

    func testValidateStandardScientificOperandLength() {
        XCTAssertEqual(CPM.standardScientificOperandLength(""), 0)
        XCTAssertEqual(CPM.standardScientificOperandLength("0.2"), 1)
        XCTAssertEqual(CPM.standardScientificOperandLength("1.2"), 2)
        XCTAssertEqual(CPM.standardScientificOperandLength("0."), 0)
        XCTAssertEqual(CPM.standardScientificOperandLength("12345"), 5)
        XCTAssertEqual(CPM.standardScientificOperandLength("-12345"), 6)
    }

    func testValidateProgrammerOperandLength() {
        XCTAssertEqual(CPM.programmerOperandLength("1001", radix: .bin), 4)
        XCTAssertEqual(CPM.programmerOperandLength("1001b", radix: .bin), 4)
        XCTAssertEqual(CPM.programmerOperandLength("1001B", radix: .bin), 4)
        XCTAssertEqual(CPM.programmerOperandLength("0b1001", radix: .bin), 4)
        XCTAssertEqual(CPM.programmerOperandLength("0B1001", radix: .bin), 4)
        XCTAssertEqual(CPM.programmerOperandLength("0y1001", radix: .bin), 4)
        XCTAssertEqual(CPM.programmerOperandLength("0Y1001", radix: .bin), 4)
        XCTAssertEqual(CPM.programmerOperandLength("0b", radix: .bin), 1)

        XCTAssertEqual(CPM.programmerOperandLength("123456", radix: .oct), 6)
        XCTAssertEqual(CPM.programmerOperandLength("0t123456", radix: .oct), 6)
        XCTAssertEqual(CPM.programmerOperandLength("0T123456", radix: .oct), 6)
        XCTAssertEqual(CPM.programmerOperandLength("0o123456", radix: .oct), 6)
        XCTAssertEqual(CPM.programmerOperandLength("0O123456", radix: .oct), 6)

        XCTAssertEqual(CPM.programmerOperandLength("", radix: .dec), 0)
        XCTAssertEqual(CPM.programmerOperandLength("-", radix: .dec), 0)
        XCTAssertEqual(CPM.programmerOperandLength("12345", radix: .dec), 5)
        XCTAssertEqual(CPM.programmerOperandLength("-12345", radix: .dec), 5)
        XCTAssertEqual(CPM.programmerOperandLength("0n12345", radix: .dec), 5)
        XCTAssertEqual(CPM.programmerOperandLength("0N12345", radix: .dec), 5)

        XCTAssertEqual(CPM.programmerOperandLength("123ABC", radix: .hex), 6)
        XCTAssertEqual(CPM.programmerOperandLength("0x123ABC", radix: .hex), 6)
        XCTAssertEqual(CPM.programmerOperandLength("0X123ABC", radix: .hex), 6)
        XCTAssertEqual(CPM.programmerOperandLength("123ABCh", radix: .hex), 6)
        XCTAssertEqual(CPM.programmerOperandLength("123ABCH", radix: .hex), 6)
    }

    func testValidateStandardPasteExpression() {
        assertPositive([
            "123", "+123", "-133", "12345.", "+12.34", "12.345", "012.034", "-23.032",
            "-.123", ".1234", "012.012", "123+456", "123+-234", "123*-345", "123*4*-3",
            "123*+4*-3", "1,234", "1 2 3", "\n\r1,234\n", "\u{0C}\n1+2\t\r\u{0B}\u{85}",
            "\n 1+\n2 ", "1\"2", "1234567891234567", "2+2=", "2+2=   ", "1.2e23", "12345e-23",
        ], mode: .standard)
        assertNegative([
            "(123)+(456)", "abcdef", "xyz", "ABab", "e+234", "12345678912345678",
            "SIN(2)", "2+2==", "2=+2", "2%2", "10^2",
        ], mode: .standard)
    }

    func testValidateScientificPasteExpression() {
        assertPositive([
            "123", "+123", "-133", "123+456", "12345e+023", "1,234", "1.23", "-.123",
            ".1234", "012.012", "123+-234", "123*-345", "123*4*-3", "123*+4*-3", "1 2 3",
            "\n\r1,234\n", "\u{0C}\n1+2\t\r\u{0B}\u{85}", "\n 1+\n2 ", "1\"2", "1.2e+023",
            "12345e-23", "(123)+(456)", "12345678912345678123456789012345", "(123)+(456)=",
            "2+2=   ", "-(43)", "+(41213)", "-(432+3232)", "-(+(-3213)+(-2312))",
            "-(-(432+3232))", "1.2e23", "12^2", "-12.12^-2", "61%99-6.1%99",
            "1.1111111111111111111111111111111e+1142",
        ], mode: .scientific)
        assertNegative([
            "abcdef", "xyz", "ABab", "e+234", "123456789123456781234567890123456",
            "11.1111111111111111111111111111111e+1142", "1.1e+10001",
            "0.11111111111111111111111111111111111e+111111SIN(2)", "2+2==", "2=+2",
        ], mode: .scientific)
    }

    func testValidateProgrammerHexPasteExpression() {
        assertPositive([
            "123", "123+456", "1,234", "1 2 3", "1'2'3'4", "1_2_3_4", "12345e-23",
            "\n\r1,234\n", "\u{0C}\n1+2\t\r\u{0B}\u{85}", "\n 1+\n2 ", "e+234", "1\"2",
            "(123)+(456)", "abcdef", "ABab", "ABCDF21abc41a", "0x1234", "0xab12", "0X1234",
            "AB12h", "BC34H", "1234u", "1234ul", "1234ULL", "2+2=", "2+2=   ",
            "A4C3%12", "1233%AB", "FFC1%F2",
        ], mode: .programmer, radix: .hex, wordSize: .qword)
        assertNegative([
            "+123", "1.23", "1''2", "'123", "123'", "1__2", "_123", "123_", "-133",
            "1.2e+023", "1.2e23", "xyz", "ABCDEF21abc41abc7", "SIN(2)", "123+-234",
            "1234x", "A0x1234", "0xx1234", "1234uu", "1234ulll", "2+2==", "2=+2",
        ], mode: .programmer, radix: .hex, wordSize: .qword)

        assertPositive([
            "123", "123+456", "1,234", "1 2 3", "1'2'3'4", "1_2_3_4", "12345e-23",
            "\n\r1,234\n", "\u{0C}\n1+2\t\r\u{0B}\u{85}", "\n 1+\n2 ", "e+234", "1\"2",
            "(123)+(456)", "abcdef", "ABab", "ABCD123a", "0x1234", "0xab12", "0X1234",
            "AB12h", "BC34H", "1234u", "1234ul", "1234ULL",
        ], mode: .programmer, radix: .hex, wordSize: .dword)
        assertNegative([
            "+123", "1.23", "1''2", "'123", "123'", "1__2", "_123", "123_", "-133",
            "1.2e+023", "1.2e23", "xyz", "ABCD123ab", "SIN(2)", "123+-234", "1234x",
            "A0x1234", "0xx1234", "1234uu", "1234ulll",
        ], mode: .programmer, radix: .hex, wordSize: .dword)

        assertPositive([
            "123", "13+456", "1,34", "12 3", "1'2'3'4", "1_2_3_4", "15e-23", "\r1",
            "\n\r1,4", "\n1,4\n", "\u{0C}\n1+2\t\r\u{0B}", "\n 1+\n2 ", "e+24", "1\"2",
            "(23)+(4)", "aef", "ABab", "A1a3", "FFFF", "0x1234", "0xab12", "0X1234",
            "AB12h", "BC34H", "1234u", "1234ul", "1234ULL",
        ], mode: .programmer, radix: .hex, wordSize: .word)
        assertNegative([
            "+123", "1.23", "1''2", "'123", "123'", "1__2", "_123", "123_", "-133",
            "1.2e+023", "1.2e23", "xyz", "A1a3b", "SIN(2)", "123+-234", "1234x",
            "A0x1234", "0xx1234", "1234uu", "1234ulll",
        ], mode: .programmer, radix: .hex, wordSize: .word)

        assertPositive([
            "13", "13+6", "1,4", "2 3", "1'2", "1_2", "5e-3", "\r1", "a", "ab", "A1",
            "0x12", "0xab", "0X12", "A9h", "B8H", "12u", "12ul", "12ULL",
        ], mode: .programmer, radix: .hex, wordSize: .byte)
        assertNegative([
            "+3", "1.2", "1''2", "'12", "12'", "1__2", "_12", "12_", "-3", "1.1e+02",
            "1.2e3", "xz", "A3a", "SIN(2)", "13+-23", "12x", "A0x1", "0xx12", "12uu", "12ulll",
        ], mode: .programmer, radix: .hex, wordSize: .byte)
    }

    func testValidateProgrammerDecPasteExpression() {
        assertPositive([
            "123", "+123", "-133", "123+456", "1,234", "1 2 3", "1'2'3'4", "1_2_3_4",
            "\n\r1,234\n", "\u{0C}\n1+2\t\r\u{0B}\u{85}", "\n 1+\n2 ", "1\"2", "(123)+(456)",
            "123+-234", "123*-345", "123*4*-3", "123*+4*-3", "9223372036854775807",
            "-9223372036854775808", "0n1234", "0N1234", "1234u", "1234ul", "1234ULL",
            "2+2=", "2+2=   ", "823%21",
        ], mode: .programmer, radix: .dec, wordSize: .qword)
        assertNegative([
            "1.23", "1''2", "'123", "123'", "1__2", "_123", "123_", "1.2e23", "1.2e+023",
            "12345e-23", "abcdef", "xyz", "ABab", "e+234", "9223372036854775808",
            "9223372036854775809", "SIN(2)", "-0n123", "0nn1234", "1234uu", "1234ulll",
            "2+2==", "2=+2",
        ], mode: .programmer, radix: .dec, wordSize: .qword)

        assertPositive([
            "123", "+123", "-133", "123+456", "1,234", "1 2 3", "1'2'3'4", "1_2_3_4",
            "\n\r1,234\n", "\u{0C}\n1+2\t\r\u{0B}\u{85}", "\n 1+\n2 ", "1\"2", "(123)+(456)",
            "123+-234", "123*-345", "123*4*-3", "123*+4*-3", "2147483647", "-2147483647",
            "0n1234", "0N1234", "1234u", "1234ul", "1234ULL",
        ], mode: .programmer, radix: .dec, wordSize: .dword)
        assertNegative([
            "1.23", "1''2", "'123", "123'", "1__2", "_123", "123_", "1.2e23", "1.2e+023",
            "12345e-23", "abcdef", "xyz", "ABab", "e+234", "2147483649", "SIN(2)",
            "-0n123", "0nn1234", "1234uu", "1234ulll",
        ], mode: .programmer, radix: .dec, wordSize: .dword)

        assertPositive([
            "123", "+123", "-133", "123+456", "1,234", "1 2 3", "1'2'3'4", "1_2_3_4",
            "\u{0C}\n1+2\t\r\u{0B}\u{85}", "1\"2", "(123)+(456)", "123+-234", "123*-345",
            "123*4*-3", "123*+4*-3", "32767", "-32767", "-32768", "0n1234", "0N1234",
            "1234u", "1234ul", "1234ULL",
        ], mode: .programmer, radix: .dec, wordSize: .word)
        assertNegative([
            "1.23", "1''2", "'123", "123'", "1__2", "_123", "123_", "1.2e23", "1.2e+023",
            "12345e-23", "abcdef", "xyz", "ABab", "e+234", "32769", "SIN(2)", "-0n123",
            "0nn1234", "1234uu", "1234ulll",
        ], mode: .programmer, radix: .dec, wordSize: .word)

        assertPositive([
            "13", "+13", "-13", "13+46", "13+-34", "13*-3", "3*4*-3", "3*+4*-3", "1,3",
            "1 3", "1'2'3", "1_2_3", "1\"2", "127", "-127", "0n123", "0N123", "123u",
            "123ul", "123ULL",
        ], mode: .programmer, radix: .dec, wordSize: .byte)
        assertNegative([
            "1.23", "1''2", "'123", "123'", "1__2", "_123", "123_", "1.2e23", "1.2e+023",
            "15e-23", "abcdef", "xyz", "ABab", "e+24", "129", "SIN(2)", "-0n123",
            "0nn1234", "123uu", "123ulll",
        ], mode: .programmer, radix: .dec, wordSize: .byte)
    }

    func testValidateProgrammerOctPasteExpression() {
        assertPositive([
            "123", "123+456", "1,234", "1 2 3", "1'2'3'4", "1_2_3_4", "\n\r1,234\n",
            "\u{0C}\n1+2\t\r\u{0B}\u{85}", "\n 1+\n2 ", "1\"2", "(123)+(456)", "0t1234",
            "0T1234", "0o1234", "0O1234", "1234u", "1234ul", "1234ULL", "2+2=", "2+2=   ",
            "127%71", "1777777777777777777777",
        ], mode: .programmer, radix: .oct, wordSize: .qword)
        assertNegative([
            "+123", "1.23", "1''2", "'123", "123'", "1__2", "_123", "123_", "-133",
            "1.2e23", "1.2e+023", "12345e-23", "abcdef", "xyz", "ABab", "e+234",
            "12345678901234567890123", "2000000000000000000000", "SIN(2)", "123+-234",
            "0ot1234", "1234uu", "1234ulll", "2+2==", "2=+2", "89%12",
        ], mode: .programmer, radix: .oct, wordSize: .qword)

        assertPositive([
            "123", "123+456", "1,234", "1 2 3", "1'2'3'4", "1_2_3_4", "\n\r1,234\n",
            "\u{0C}\n1+2\t\r\u{0B}\u{85}", "\n 1+\n2 ", "1\"2", "(123)+(456)",
            "37777777777", "0t1234", "0T1234", "0o1234", "0O1234", "1234u", "1234ul", "1234ULL",
        ], mode: .programmer, radix: .oct, wordSize: .dword)
        assertNegative([
            "+123", "1.23", "1''2", "'123", "123'", "1__2", "_123", "123_", "-133",
            "1.2e23", "1.2e+023", "12345e-23", "abcdef", "xyz", "ABab", "e+234",
            "377777777771", "40000000000", "SIN(2)", "123+-234", "0ot1234", "1234uu", "1234ulll",
        ], mode: .programmer, radix: .oct, wordSize: .dword)

        assertPositive([
            "123", "123+456", "1,234", "1 2 3", "1'2'3'4", "1_2_3_4",
            "\u{0C}\n1+2\t\r\u{0B}\u{85}", "1\"2", "(123)+(456)", "177777", "0t1234",
            "0T1234", "0o1234", "0O1234", "1234u", "1234ul", "1234ULL",
        ], mode: .programmer, radix: .oct, wordSize: .word)
        assertNegative([
            "+123", "1.23", "1''2", "'123", "123'", "1__2", "_123", "123_", "-133",
            "1.2e23", "1.2e+023", "12345e-23", "abcdef", "xyz", "ABab", "e+234",
            "1777771", "200000", "SIN(2)", "123+-234", "0ot1234", "1234uu", "1234ulll",
        ], mode: .programmer, radix: .oct, wordSize: .word)

        assertPositive([
            "13", "13+46", "1,3", "1 3", "1'2'3", "1_2_3", "1\"2", "377", "0t123",
            "0T123", "0o123", "0O123", "123u", "123ul", "123ULL",
        ], mode: .programmer, radix: .oct, wordSize: .byte)
        assertNegative([
            "+123", "1.23", "1''2", "'123", "123'", "1__2", "_123", "123_", "-13",
            "1.2e23", "1.2e+023", "15e-23", "abcdef", "xyz", "ABab", "e+24", "477",
            "400", "SIN(2)", "123+-34", "0ot123", "123uu", "123ulll",
        ], mode: .programmer, radix: .oct, wordSize: .byte)
    }

    func testValidateProgrammerBinPasteExpression() {
        assertPositive([
            "100", "100+101", "1,001", "1 0 1", "1'0'0'1", "1_0_0_1", "\n\r1,010\n",
            "\u{0C}\n1+11\t\r\u{0B}\u{85}", "\n 1+\n1 ", "1\"1", "(101)+(10)", "0b1001",
            "0B1111", "0y1001", "0Y1001", "1100b", "1101B", "1111u", "1111ul", "1111ULL",
            "1010101010101010101010101011110110100100101010101001010101001010",
            "1+10=", "1+10=   ", "1001%10",
        ], mode: .programmer, radix: .bin, wordSize: .qword)
        assertNegative([
            "+10101", "1.01", "1''0", "'101", "101'", "1__0", "_101", "101_",
            "-10101001", "123", "1.2e23", "1.2e+023", "101010e-1010", "abcdef", "xyz",
            "ABab", "e+10101", "b1001", "10b01", "0x10", "1001x", "1001h", "0bb1111",
            "1111uu", "1111ulll",
            "10101010101010101010101010111101101001001010101010010101010010100",
            "SIN(01010)", "10+-10101010101", "1+10==", "1=+10",
        ], mode: .programmer, radix: .bin, wordSize: .qword)

        assertPositive([
            "100", "100+101", "1,001", "1 0 1", "1'0'0'1", "1_0_0_1", "\n\r1,010\n",
            "\u{0C}\n1+11\t\r\u{0B}\u{85}", "\n 1+\n1 ", "1\"1", "(101)+(10)", "0b1001",
            "0B1111", "0y1001", "0Y1001", "1100b", "1101B", "1111u", "1111ul", "1111ULL",
            "10101001001010101101010111111100",
        ], mode: .programmer, radix: .bin, wordSize: .dword)
        assertNegative([
            "+10101", "1.01", "1''0", "'101", "101'", "1__0", "_101", "101_",
            "-10101001", "123", "1.2e23", "1.2e+023", "101010e-1010", "abcdef", "xyz",
            "ABab", "e+10101", "b1001", "10b01", "0x10", "1001x", "1001h", "0bb1111",
            "1111uu", "1111ulll", "101010010010101011010101111111001", "SIN(01010)",
            "10+-10101010101",
        ], mode: .programmer, radix: .bin, wordSize: .dword)

        assertPositive([
            "100", "100+101", "1,001", "1 0 1", "1'0'0'1", "1_0_0_1", "\n\r1,010\n",
            "\u{0C}\n1+11\t\r\u{0B}\u{85}", "\n 1+\n1 ", "1\"1", "(101)+(10)", "0b1001",
            "0B1111", "0y1001", "0Y1001", "1100b", "1101B", "1111u", "1111ul", "1111ULL",
            "1010101010010010",
        ], mode: .programmer, radix: .bin, wordSize: .word)
        assertNegative([
            "+10101", "1.01", "1''0", "'101", "101'", "1__0", "_101", "101_",
            "-10101001", "123", "1.2e23", "1.2e+023", "101010e-1010", "abcdef", "xyz",
            "ABab", "e+10101", "b1001", "10b01", "0x10", "1001x", "1001h", "0bb1111",
            "1111uu", "1111ulll", "10101010100100101", "SIN(01010)", "10+-10101010101",
        ], mode: .programmer, radix: .bin, wordSize: .word)

        assertPositive([
            "100", "100+101", "1,001", "1 0 1", "1'0'0'1", "1_0_0_1", "\n\r1,010\n",
            "\n 1+\n1 ", "1\"1", "(101)+(10)", "0b1001", "0B1111", "0y1001", "0Y1001",
            "1100b", "1101B", "1111u", "1111ul", "1111ULL", "10100010", "11111111",
        ], mode: .programmer, radix: .bin, wordSize: .byte)
        assertNegative([
            "+10101", "1.01", "1''0", "'101", "101'", "1__0", "_101", "101_",
            "-10101001", "123", "1.2e23", "1.2e+023", "101010e-1010", "abcdef", "xyz",
            "ABab", "e+10101", "b1001", "10b01", "0x10", "1001x", "1001h", "0bb1111",
            "1111uu", "1111ulll", "101000101", "100000000", "SIN(01010)", "10+-1010101",
        ], mode: .programmer, radix: .bin, wordSize: .byte)
    }

    func testValidateConverterPasteExpression() {
        assertPositive([
            "123", "+123", "-133", "12345.", "012.012", "1,234", "1 2 3", "\n\r1,234\n",
            "\u{0C}\n12\t\r\u{0B}\u{85}", "1\"2", "100=", "100=   ",
        ], mode: .converter)
        assertNegative([
            "(123)+(456)", "1.2e23", "12345e-23", "\n 1+\n2 ", "123+456", "abcdef",
            "xyz", "ABab", "e+234", "12345678912345678", "SIN(2)", "123+-234",
            "100==", "=100",
        ], mode: .converter)
    }
}

// MARK: - 粘贴功能级测试（对应 FunctionalCopyPasteTest + OnPaste 行为）

@MainActor
final class PasteFunctionalTests: XCTestCase {
    private var model: StandardCalculatorViewModel!

    override func setUp() async throws {
        // 清除记忆的模式，保证每个用例都从默认标准模式起步（隔离宿主 UserDefaults）。
        UserDefaults.standard.removeObject(forKey: "LastCalculatorMode")
        model = StandardCalculatorViewModel()
        await drain()
    }

    private func drain() async {
        for _ in 0..<50 { await Task.yield() }
    }

    func testFunctionalCopyPaste() async {
        // 原版：标准模式粘贴后，显示值应能再次通过标准/科学/程序员Hex校验。
        let inputs = ["123", "12345", "123+456", "1,234", "1 2 3", "\n\r1,234\n", "\n 1+\n2 ", "1\"2"]
        for input in inputs {
            model.buttonPressed(.clear)
            model.onPaste(input)
            await drain()
            let display = model.displayValue.replacingOccurrences(of: " ", with: "")
            XCTAssertNotNil(CopyPasteManager.validate(display, mode: .standard), "标准应可再粘贴: \(input.debugDescription)")
            XCTAssertNotNil(CopyPasteManager.validate(display, mode: .scientific), "科学应可再粘贴: \(input.debugDescription)")
            XCTAssertNotNil(
                CopyPasteManager.validate(display, mode: .programmer, radix: .hex, wordSize: .qword),
                "程序员Hex应可再粘贴: \(input.debugDescription)")
        }
    }

    func testPasteExpressionEvaluatesOnTrailingEquals() async {
        model.onPaste("2+2=")
        await drain()
        XCTAssertEqual(model.displayValue, "4")
    }

    func testPasteNegativeNumber() async {
        model.onPaste("-133")
        await drain()
        XCTAssertEqual(model.displayValue, "-133")
    }

    func testPasteScientificExponent() async {
        model.setCalculatorType(.scientific)
        model.onPaste("1.2e2=")
        await drain()
        XCTAssertEqual(model.displayValue, "120")
    }

    func testPasteParenthesizedNegation() async {
        model.setCalculatorType(.scientific)
        model.onPaste("(45)+(-30)=")
        await drain()
        XCTAssertEqual(model.displayValue, "15")
    }

    func testConverterPasteFeedsActiveValue() {
        let vm = UnitConverterViewModel()
        vm.onPaste("123.5")
        XCTAssertEqual(vm.fromDisplay, "123.5")
        vm.onPaste("42")
        XCTAssertEqual(vm.fromDisplay, "42")
    }
}

// MARK: - 本地化管线（P3-4）

final class LocalizationTests: XCTestCase {
    /// 从指定 .lproj 直接取值,验证 en/zh-Hans 两语解析(不依赖宿主语言)。
    /// SPM 会把 lproj 目录名小写化(zh-Hans → zh-hans),故大小写不敏感查找。
    private func lookup(_ lang: String, _ key: String) -> String? {
        for name in [lang, lang.lowercased()] {
            if let url = Bundle.module.url(forResource: name, withExtension: "lproj"),
               let bundle = Bundle(url: url) {
                let sentinel = "__MISSING__"
                let v = bundle.localizedString(forKey: key, value: sentinel, table: nil)
                return v == sentinel ? nil : v
            }
        }
        return nil
    }

    func testStringsCatalogResolvesBothLanguages() throws {
        let clearKey = "clearButton.[using:Windows.UI.Xaml.Automation]AutomationProperties.Name"
        // 纯 swift build 不跑 xcstringstool,catalog 未编译成 .lproj;该断言需 xcodebuild。
        try XCTSkipIf(lookup("en", clearKey) == nil, "String Catalog 未编译（纯 swift build）")
        XCTAssertEqual(lookup("en", clearKey), "Clear")
        XCTAssertEqual(lookup("zh-Hans", clearKey), "清除")
    }

    func testL10nReturnsKeyWhenMissing() {
        // 无手写回退:查不到的键原样返回键名,暴露缺失而非静默吞掉。
        XCTAssertEqual(L10n.string("__definitely_absent_key__"), "__definitely_absent_key__")
    }

    func testL10nFormatSubstitutesPositionalArgs() {
        // 不依赖 catalog 是否已编译:验证 %1 替换与模板解析一致这一不变式。
        let template = L10n.string("Format_DecButtonValue")
        let out = L10n.format("Format_DecButtonValue", "255")
        XCTAssertEqual(out, template.replacingOccurrences(of: "%1", with: "255"))
    }
}
