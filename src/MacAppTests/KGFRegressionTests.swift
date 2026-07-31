// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// S9 · KGF 14 函数回归测试：期望文件在 tests/kgf-regression/（每 case 一个 JSON），
// 与 spec/kgf-reference.md 对照维护。验收标准：无 🔴（错误值）；
// 🟡（格式差）与 ⬜（缺失，too complex 降级）在期望文件中如实固化并单独跟踪。

import XCTest
@testable import MacCalculator

private struct KGFExpectation: Decodable {
    let input: String
    let domain: String?
    let range: String?
    let zeros: [String]
    let yIntercept: String?
    let minima: [[String]]
    let maxima: [[String]]
    let inflection: [[String]]
    let verticalAsymptotes: [String]
    let horizontalAsymptotes: [String]
    let obliqueAsymptotes: [String]
    let parity: String
    let period: String?
    let monotonicity: [[String]]
    let tooComplex: [String]
}

final class KGFRegressionTests: XCTestCase {
    private static let casesDir: URL = {
        // src/MacAppTests/KGFRegressionTests.swift → 仓库根 → tests/kgf-regression
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // MacAppTests
            .deletingLastPathComponent()  // src
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("tests/kgf-regression")
    }()

    private func direction(_ token: String) -> String {
        switch token {
        case "up": return L10n.string("KGFMonotonicityIncreasing")
        case "down": return L10n.string("KGFMonotonicityDecreasing")
        case "const": return L10n.string("KGFMonotonicityConstant")
        default: return token
        }
    }

    private func fieldName(_ token: String) -> String {
        switch token {
        case "domain": return L10n.string("Domain")
        case "range": return L10n.string("Range")
        case "xIntercept": return L10n.string("XIntercept")
        case "minima": return L10n.string("Minima")
        case "maxima": return L10n.string("Maxima")
        case "inflection": return L10n.string("InflectionPoints")
        case "verticalAsymptotes": return L10n.string("VerticalAsymptotes")
        case "horizontalAsymptotes": return L10n.string("HorizontalAsymptotes")
        case "obliqueAsymptotes": return L10n.string("ObliqueAsymptotes")
        case "monotonicity": return L10n.string("Monotonicity")
        default: return token
        }
    }

    /// 相对基准（相对残差原则，TODO D6）：绝对时间跨设备不可比、CI 负载抖动
    /// 会偶发红。改为与本机轻量基线（x^2-4 全字段分析）的中位数比值判退化——
    /// 机器快慢同比例缩放，比值稳定。单 case 3 次取中位数消抖动。
    private func medianSamples(_ measure: () -> Void, times: Int = 3) -> TimeInterval {
        var samples: [TimeInterval] = []
        for _ in 0..<times {
            let start = Date()
            measure()
            samples.append(Date().timeIntervalSince(start))
        }
        return samples.sorted()[times / 2]
    }

    func testAllFourteenCases() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.casesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertEqual(files.count, 14, "期望 14 个回归 case")

        // 本机基线：轻量表达式分析的中位数耗时 = "1 单位"。比值阈值 40× 留足
        // 量级余量（正常函数比基线慢 5-20×），专防算法退化成指数复杂度；
        // 下限 0.25s 防超快机器上基线噪声放大比值。
        let baselineExpr = try XCTUnwrap(GraphExpression("x^2-4"))
        let baseline = medianSamples { _ = GiacMathSolver.analyze(baselineExpr) }
        let budget = max(baseline * 40, 0.25)

        for file in files {
            let name = file.lastPathComponent
            let exp = try JSONDecoder().decode(KGFExpectation.self, from: Data(contentsOf: file))
            let expr = try XCTUnwrap(GraphExpression(exp.input), "\(name): 解析失败")

            let elapsed = medianSamples { _ = GiacMathSolver.analyze(expr) }
            // S3 性能验收（相对基准）：任何单函数分析 ≤ 40 × 本机基线。
            XCTAssertLessThanOrEqual(elapsed, budget, "\(name): 分析耗时 \(elapsed)s 超基线 \(baseline)s 的 40 倍（复杂度退化）")

            let a = GiacMathSolver.analyze(expr)
            XCTAssertEqual(a.domain, exp.domain, "\(name): 定义域")
            XCTAssertEqual(a.range, exp.range, "\(name): 值域")
            XCTAssertEqual(a.zeros, exp.zeros, "\(name): 零点")
            XCTAssertEqual(a.yIntercept, exp.yIntercept, "\(name): Y 截距")
            XCTAssertEqual(a.minima.map { [$0.x, $0.y] }, exp.minima, "\(name): 极小值")
            XCTAssertEqual(a.maxima.map { [$0.x, $0.y] }, exp.maxima, "\(name): 极大值")
            XCTAssertEqual(a.inflectionPoints.map { [$0.x, $0.y] }, exp.inflection, "\(name): 拐点")
            XCTAssertEqual(a.verticalAsymptotes, exp.verticalAsymptotes, "\(name): 垂直渐近线")
            XCTAssertEqual(a.horizontalAsymptotes, exp.horizontalAsymptotes, "\(name): 水平渐近线")
            XCTAssertEqual(a.obliqueAsymptotes, exp.obliqueAsymptotes, "\(name): 斜渐近线")
            XCTAssertEqual(String(describing: a.parity), exp.parity, "\(name): 奇偶性")

            let expectedPeriod = exp.period == "aperiodic" ? L10n.string("Mac_Aperiodic") : exp.period
            XCTAssertEqual(a.periodicity, expectedPeriod, "\(name): 周期")

            XCTAssertEqual(
                a.monotonicity.map { [$0.interval, $0.direction] },
                exp.monotonicity.map { [$0[0], direction($0[1])] },
                "\(name): 单调性")
            XCTAssertEqual(a.tooComplexFeatures, exp.tooComplex.map(fieldName), "\(name): too complex 字段")
        }
    }
}
