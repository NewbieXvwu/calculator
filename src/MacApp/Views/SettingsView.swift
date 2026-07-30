// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 对应原版 src/Calculator/Views/Settings.xaml：
//   - 外观主题三选（LightThemeRadioButton/DarkThemeRadioButton/SystemThemeRadioButton）
//   - 关于区（AboutExpander：应用名 + AboutBuildVersion 版本、版权、许可、AboutContribute 贡献链接）
// 豁免（见 TODO.md）：EULA/服务协议/隐私声明/反馈 Hub 为微软法务文书，以本移植的许可声明替代。

import SwiftUI

/// 外观主题（对应 ThemeRadioButtons），UserDefaults 持久化。
enum AppAppearance: String, CaseIterable, Identifiable {
    case light, dark, system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .system: return "使用系统设置"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        case .system: return nil
        }
    }

    static let defaultsKey = "AppAppearance"

    static var current: AppAppearance {
        AppAppearance(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .system
    }

    /// 应用到全局并持久化。
    func apply() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
        NSApp.appearance = nsAppearance
    }
}

struct SettingsView: View {
    @State private var appearance = AppAppearance.current

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发构建"
    }

    var body: some View {
        Form {
            Section("外观") {
                Picker("应用主题", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChangeCompat(of: appearance) { newValue in
                    newValue.apply()
                }
            }

            Section("关于") {
                LabeledContent("计算器", value: "版本 \(version)")
                Text("© Microsoft Corporation。原版计算器以 MIT 许可开源；本 macOS 移植因静态链接 Giac（GPLv3）整体以 GPLv3 分发，源码保留 MIT 文件头。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("第三方组件：Giac/Xcas（GPLv3）、MathLive（MIT）、GMP 与 MPFR（LGPL）。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                // AboutContribute：贡献链接。
                Link("在 GitHub 上参与贡献", destination: URL(string: "https://github.com/NewbieXvwu/calculator")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        // 对应原版 SettingsPageOpened 播报。
        .onAppear { AccessibilityAnnouncer.announce("已打开设置", highPriority: false) }
    }
}
