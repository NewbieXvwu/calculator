// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// S6 规格表下沉的防漂移测试：spec/*.json 是跨平台唯一事实源，
// macOS 侧的 Swift 镜像表必须与之逐字段一致。任何一侧改动而另一侧未同步即红。

import SwiftUI
import XCTest
@testable import MacCalculator

@MainActor
final class SpecTableTests: XCTestCase {
    /// 仓库根 spec/ 目录（相对本测试文件定位，与 KGFRegressionTests 同法）。
    private static let specDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // MacAppTests
        .deletingLastPathComponent()   // src
        .deletingLastPathComponent()   // repo root
        .appendingPathComponent("spec")

    private func loadJSON<T: Decodable>(_ file: String, as type: T.Type) throws -> T {
        let url = Self.specDir.appendingPathComponent(file)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - spec/modes.json ⇄ ModeDescriptor

    private struct ModesSpec: Decodable {
        struct Mode: Decodable {
            let id: String
            let l10nKey: String
            let usesEngine: Bool
            let precision: Int
            let engineModeCommand: String
            let menuShortcutDigit: Int
            let icon: String
            let minBodyWidth: Double
            let minWindowWidth: Double
            let minWindowHeight: Double
        }
        let modes: [Mode]
    }

    func testModesSpecMatchesModeDescriptorTable() throws {
        let spec = try loadJSON("modes.json", as: ModesSpec.self)
        XCTAssertEqual(spec.modes.count, ModeDescriptor.all.count)

        let commandByName: [String: EngineCommand] = [
            "modeBasic": .modeBasic, "modeScientific": .modeScientific, "modeProgrammer": .modeProgrammer,
        ]

        for (specMode, descriptor) in zip(spec.modes, ModeDescriptor.all) {
            XCTAssertEqual(specMode.id, descriptor.persistenceKey)
            XCTAssertEqual(specMode.l10nKey, descriptor.l10nKey)
            XCTAssertEqual(specMode.usesEngine, descriptor.usesEngine)
            XCTAssertEqual(specMode.precision, descriptor.precision)
            XCTAssertEqual(commandByName[specMode.engineModeCommand], descriptor.modeCommand, specMode.id)
            XCTAssertEqual(specMode.menuShortcutDigit, descriptor.menuShortcutDigit)
            XCTAssertEqual(specMode.icon, descriptor.iconSemantic)
            XCTAssertEqual(CGFloat(specMode.minBodyWidth), descriptor.minBodyWidth, specMode.id)
            XCTAssertEqual(CGFloat(specMode.minWindowWidth), descriptor.minWindowWidth, specMode.id)
            XCTAssertEqual(CGFloat(specMode.minWindowHeight), descriptor.minWindowHeight, specMode.id)
            // 往返：persistenceKey 反查回同一模式。
            XCTAssertEqual(CalculatorMode(persistenceKey: specMode.id), descriptor.mode)
        }

        // ⌘1-6 序号连续且与表序一致。
        XCTAssertEqual(spec.modes.map(\.menuShortcutDigit), Array(1...spec.modes.count))
    }

    // MARK: - spec/layout-tiers.json ⇄ LayoutTier

    private struct TiersSpec: Decodable {
        struct Tier: Decodable {
            let name: String
            let minHeight: Double
            let digitFont: Double
            let opFont: Double
            let funcFont: Double
            let clearFont: Double
            let hideStandardFunctions: Bool
        }
        let standardKeypadTiers: [Tier]
    }

    func testLayoutTiersSpecMatchesLayoutTierTable() throws {
        let spec = try loadJSON("layout-tiers.json", as: TiersSpec.self)
        XCTAssertEqual(spec.standardKeypadTiers.count, LayoutTier.all.count)

        for (specTier, tier) in zip(spec.standardKeypadTiers, LayoutTier.all) {
            XCTAssertEqual(specTier.name, tier.name)
            XCTAssertEqual(CGFloat(specTier.minHeight), tier.minHeight, specTier.name)
            XCTAssertEqual(CGFloat(specTier.digitFont), tier.digitFont, specTier.name)
            XCTAssertEqual(CGFloat(specTier.opFont), tier.opFont, specTier.name)
            XCTAssertEqual(CGFloat(specTier.funcFont), tier.funcFont, specTier.name)
            XCTAssertEqual(CGFloat(specTier.clearFont), tier.clearFont, specTier.name)
            XCTAssertEqual(specTier.hideStandardFunctions, tier.hideStandardFunctions, specTier.name)
        }

        // 降序匹配 + 0 兜底的结构约束。
        let heights = LayoutTier.all.map(\.minHeight)
        XCTAssertEqual(heights, heights.sorted(by: >))
        XCTAssertEqual(heights.last, 0)

        // 行为抽样：阈值边界各归各档。
        XCTAssertEqual(LayoutTier.forKeypadHeight(360).name, "large")
        XCTAssertEqual(LayoutTier.forKeypadHeight(359).name, "medium")
        XCTAssertEqual(LayoutTier.forKeypadHeight(260).name, "medium")
        XCTAssertEqual(LayoutTier.forKeypadHeight(259).name, "compact")
        XCTAssertTrue(LayoutTier.forKeypadHeight(100).hideStandardFunctions)
    }

    // MARK: - spec/graph-colors.json ⇄ GraphingViewModel 色板

    private struct ColorsSpec: Decodable {
        let light: [String]
        let dark: [String]
    }

    private func parseHex(_ text: String) throws -> UInt32 {
        let hex = String(text.dropFirst())  // 去掉 #
        XCTAssertEqual(text.first, "#")
        XCTAssertEqual(hex.count, 6)
        return try XCTUnwrap(UInt32(hex, radix: 16), text)
    }

    func testGraphColorsSpecMatchesPalettes() throws {
        let spec = try loadJSON("graph-colors.json", as: ColorsSpec.self)
        XCTAssertEqual(spec.light.count, 14)
        XCTAssertEqual(spec.dark.count, 14)
        XCTAssertEqual(GraphingViewModel.lightPalette.count, 14)
        XCTAssertEqual(GraphingViewModel.darkPalette.count, 14)

        for (index, hexText) in spec.light.enumerated() {
            XCTAssertEqual(Color(hex: try parseHex(hexText)), GraphingViewModel.lightPalette[index], "light[\(index)]")
        }
        for (index, hexText) in spec.dark.enumerated() {
            XCTAssertEqual(Color(hex: try parseHex(hexText)), GraphingViewModel.darkPalette[index], "dark[\(index)]")
        }

        // 色板取用行为：越界索引回卷。
        XCTAssertEqual(
            GraphingViewModel.equationColor(index: 14, darkMode: false),
            GraphingViewModel.equationColor(index: 0, darkMode: false))
    }
}
