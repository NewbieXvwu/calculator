// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// S8 · Locale 注入加固的 CI 禁用清单：引擎与共享层严禁依赖 C/C++ locale
// 设施（musl 平台 localeconv/setlocale 静默返回错误值，见 TODO S8 实测）。
// 分隔符与分组只能经 IResourceProvider / calc_locale_t 注入。
// 本测试随 swift test 运行，等价于 CI 检查。

import XCTest

final class LocaleBanTests: XCTestCase {
    /// 仓库根（相对本测试文件定位，与 SpecTableTests 同法）。
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // MacAppTests
        .deletingLastPathComponent()   // src
        .deletingLastPathComponent()   // repo root

    /// 禁用符号（TODO S8 代码规范）。
    private static let bannedTokens = [
        "localeconv",
        "setlocale",
        "std::locale(\"\")",
        "wcstod_l",
        "strtod_l",
        "std::wcout",
        "std::wcerr",
        "wstring_convert",
        "codecvt_utf8",
    ]

    /// 受检目录：src/ 下**全部**目录自动发现、默认纳入扫描——新增共享层目录
    /// （如将来的 src/Shared）零维护自动入检；仅豁免明确不参与跨平台构建的
    /// macOS 专属目录（豁免是罕见操作，须显式登记）。
    private static let exemptDirs: Set<String> = ["MacApp", "MacAppTests", "MacEngineTests", "MacGiacBridge"]
    private static let scannedDirs: [String] = {
        let fm = FileManager.default
        let srcRoot = repoRoot.appendingPathComponent("src")
        guard let entries = try? fm.contentsOfDirectory(atPath: srcRoot.path) else { return [] }
        return entries.filter { !exemptDirs.contains($0) }
    }()
    private static let sourceExtensions: Set<String> = ["h", "hpp", "cpp", "cc", "mm", "m"]

    func testEngineAndSharedLayerAvoidLocaleFacilities() throws {
        let fm = FileManager.default
        var scannedCount = 0
        var violations: [String] = []

        for dir in Self.scannedDirs {
            let root = Self.repoRoot.appendingPathComponent("src").appendingPathComponent(dir)
            guard fm.fileExists(atPath: root.path) else { continue }
            let enumerator = try XCTUnwrap(fm.enumerator(at: root, includingPropertiesForKeys: nil), dir)
            for case let url as URL in enumerator {
                guard Self.sourceExtensions.contains(url.pathExtension.lowercased()) else { continue }
                // smoketest 是开发 harness（不入库、不参与任何平台构建），豁免其日志输出。
                if url.pathComponents.contains("smoketest") { continue }
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
                scannedCount += 1
                for token in Self.bannedTokens where content.contains(token) {
                    violations.append("\(url.path): \(token)")
                }
            }
        }

        XCTAssertGreaterThan(scannedCount, 50, "扫描文件数异常少，目录定位可能失效")
        XCTAssertTrue(violations.isEmpty, "引擎/共享层出现 locale 依赖：\n" + violations.joined(separator: "\n"))
    }
}
