// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 本地化查表：键名沿用原版 Resources.resw（如 clearButton 的 AutomationProperties.Name）。
// SPM `swift build` 不编译 .xcstrings,故 Resources/{en,zh-Hans}.lproj/Localizable.strings
// 由 xcstrings 导出(scripts/export_strings.py),经 Bundle.module 解析。

import Foundation

enum L10n {
    /// 按 resw 键取当前语言字符串;缺失时回退到 `fallback`(通常为原中文硬编码)。
    static func string(_ key: String, _ fallback: String) -> String {
        let value = Bundle.module.localizedString(forKey: key, value: sentinel, table: nil)
        return value == sentinel ? fallback : value
    }

    /// 带位置参数的本地化(对应原版 Format_* 键,占位符 %1/%2…)。
    static func format(_ key: String, _ fallback: String, _ args: String...) -> String {
        var result = string(key, fallback)
        for (index, arg) in args.enumerated() {
            result = result.replacingOccurrences(of: "%\(index + 1)", with: arg)
        }
        return result
    }

    /// 按钮无障碍名:沿用原版 resw 的 `<id>.AutomationProperties.Name` 键。
    static func button(_ id: String, _ fallback: String) -> String {
        string("\(id).\(automationNameSuffix)", fallback)
    }

    private static let automationNameSuffix =
        "[using:Windows.UI.Xaml.Automation]AutomationProperties.Name"

    private static let sentinel = "\u{0}__L10N_MISSING__\u{0}"
}
