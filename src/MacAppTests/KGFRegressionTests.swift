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

    func testAllFourteenCases() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.casesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertEqual(files.count, 14, "期望 14 个回归 case")

        for file in files {
            let name = file.lastPathComponent
            let exp = try JSONDecoder().decode(KGFExpectation.self, from: Data(contentsOf: file))
            let expr = try XCTUnwrap(GraphExpression(exp.input), "\(name): 解析失败")

            let start = Date()
            let a = GiacMathSolver.analyze(expr)
            let elapsed = Date().timeIntervalSince(start)
            // S3 性能验收：任何单函数分析 ≤ 2 秒。
            XCTAssertLessThanOrEqual(elapsed, 2.0, "\(name): 分析耗时 \(elapsed)s 超过 2s 预算")

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
