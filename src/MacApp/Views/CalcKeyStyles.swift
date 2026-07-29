// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// macOS 26 Liquid Glass 风格的计算器按键与窗口材质组件。
// 遵循 Apple 官方指导：
//   - 玻璃只用于控件层（按键），内容层（显示区/列表）不加玻璃；
//   - 多个玻璃元素包进 GlassEffectContainer 共享采样区域；
//   - 自定义控件用 glassEffect(.regular … .interactive())，按压/悬停由系统处理；
//   - 强调色 tint 只用于主操作（等号键）。
// 排版职责在各 View 中严格对照原版 XAML；本文件只负责视觉皮肤。

import SwiftUI

/// NSVisualEffectView 包装：标准 macOS 窗口底材（非 Liquid Glass，
/// 玻璃控件需要背后有内容可折射，这层提供环境）。
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// 设置 NSWindow 属性：允许拖拽背景移动窗口（隐藏标题栏后必需）。
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

enum CalcKeyStyle {
    case digit    // 数字键：亮一层的玻璃（对应原版 NumericButtonStyle）
    case function // 运算/功能键：素玻璃（对应原版 OperatorButtonStyle）
    case accent   // 等号键：强调色玻璃（对应原版 AccentEmphasizedCalcButtonStyle）
    case emphasized // INV 第二功能键（对应原版 EmphasizedCalcButtonStyle）
}

enum CalcKeyLabel {
    case text(String)
    case symbol(String)
}

private let keyShape = RoundedRectangle(cornerRadius: 8, style: .continuous)

/// Liquid Glass 计算器按键。布局尺寸交由外层 Grid 决定，与原版 XAML 网格一致。
struct CalcKey: View {
    let label: CalcKeyLabel
    let style: CalcKeyStyle
    let fontSize: CGFloat
    let disabled: Bool
    let action: () -> Void

    init(_ text: String, style: CalcKeyStyle, fontSize: CGFloat = 16, disabled: Bool = false, action: @escaping () -> Void) {
        self.label = .text(text)
        self.style = style
        self.fontSize = fontSize
        self.disabled = disabled
        self.action = action
    }

    init(symbol: String, style: CalcKeyStyle, fontSize: CGFloat = 15, disabled: Bool = false, action: @escaping () -> Void) {
        self.label = .symbol(symbol)
        self.style = style
        self.fontSize = fontSize
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            labelView
                .frame(maxWidth: .infinity, minHeight: 34, maxHeight: .infinity)
                .contentShape(keyShape)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .glassEffect(glass, in: keyShape)
        .disabled(disabled)
    }

    @ViewBuilder
    private var labelView: some View {
        switch label {
        case .text(let text):
            Text(text)
                .font(.system(size: fontSize, weight: style == .digit ? .medium : .regular))
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: fontSize, weight: .medium))
        }
    }

    private var glass: Glass {
        var glass: Glass
        switch style {
        case .digit:
            glass = .regular.tint(Color.primary.opacity(0.08))
        case .function:
            glass = .regular
        case .accent:
            glass = .regular.tint(disabled ? Color.accentColor.opacity(0.4) : Color.accentColor)
        case .emphasized:
            glass = .regular.tint(Color.accentColor.opacity(0.18))
        }
        if !disabled {
            glass = glass.interactive()
        }
        return glass
    }

    private var foreground: Color {
        if disabled {
            return Color.primary.opacity(0.25)
        }
        return style == .accent ? .white : .primary
    }
}
