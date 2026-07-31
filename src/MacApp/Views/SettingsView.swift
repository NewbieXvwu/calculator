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
        case .light: return L10n.string("LightThemeRadioButton.Content")
        case .dark: return L10n.string("DarkThemeRadioButton.Content")
        case .system: return L10n.string("SystemThemeRadioButton.Content")
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
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L10n.string("Mac_DevBuild")
    }

    var body: some View {
        Form {
            Section(L10n.string("SettingsAppearance.Text")) {
                Picker(L10n.string("Mac_AppTheme"), selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: appearance) { _, newValue in
                    newValue.apply()
                }
            }

            Section(L10n.string("AboutGroupTitle.Text")) {
                LabeledContent(L10n.string("AppName"), value: L10n.format("Mac_Version", version))
                Text(L10n.string("Mac_LicenseCopyright"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(L10n.string("Mac_ThirdParty"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                // AboutContribute：贡献链接。
                Link(L10n.string("Mac_ContributeOnGitHub"), destination: URL(string: "https://github.com/NewbieXvwu/calculator")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        // 对应原版 SettingsPageOpened 播报。
        .onAppear { AccessibilityAnnouncer.announce(L10n.string("SettingsPageOpenedAnnouncement"), highPriority: false) }
    }
}
