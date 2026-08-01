// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 本地化查表：键名沿用原版 Resources.resw（如 clearButton 的 AutomationProperties.Name）。
// 唯一真相源是 Resources/Localizable.xcstrings（60 语言，从原版 resw 转换而来）。
// xcodebuild 构建时经 xcstringstool 原生编译为各语言 .lproj/Localizable.strings 进 bundle,
// 由 Bundle.module 解析。没有手写回退——键查不到时原样返回键名（暴露缺失,不静默吞掉）。
// 纯 `swift build` 也会编译 xcstrings（实测产物含 en/zh-hans 真实翻译，非键名退化）；
// 完整 60 语言产物仍以 xcodebuild 为准，UI 文案验证走 xcodebuild。

import Foundation

enum L10n {
    /// 按 resw 键取当前语言字符串;查不到时返回键名本身（便于定位缺失,不掩盖 bug）。
    static func string(_ key: String) -> String {
        let value = Bundle.module.localizedString(forKey: key, value: sentinel, table: nil)
        return value == sentinel ? key : value
    }

    /// 带位置参数的本地化(对应原版 Format_* 键,占位符 %1/%2…)。
    static func format(_ key: String, _ args: String...) -> String {
        var result = string(key)
        for (index, arg) in args.enumerated() {
            result = result.replacingOccurrences(of: "%\(index + 1)", with: arg)
        }
        return result
    }

    /// 按钮无障碍名:沿用原版 resw 的 `<id>.AutomationProperties.Name` 键;
    /// 查不到时返回可读的 id 叶子（如 "plusButton"）而非整条 WinRT 键。
    static func button(_ id: String) -> String {
        let key = "\(id).\(automationNameSuffix)"
        let value = Bundle.module.localizedString(forKey: key, value: sentinel, table: nil)
        return value == sentinel ? id : value
    }

    private static let automationNameSuffix =
        "[using:Windows.UI.Xaml.Automation]AutomationProperties.Name"

    private static let sentinel = "\u{0}__L10N_MISSING__\u{0}"
}
