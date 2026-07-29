// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// macOS 26 Liquid Glass 风格的计算器按键与窗口材质组件。
// 遵循 Apple 官方指导：
//   - 玻璃只用于控件层（按键），内容层（显示区/列表）不加玻璃；
//   - 多个玻璃元素包进 GlassEffectContainer 共享采样区域；
//   - 自定义控件用 glassEffect(.regular … .interactive())，按压弹性交给系统；
//   - tint 只承载语义：运算符列 = 系统橙（主操作），其余为校准灰阶。
// 排版职责在各 View 中严格对照原版 XAML；本文件只负责视觉皮肤。

import AppKit
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

/// 设置 NSWindow 属性：隐藏标题栏后允许拖拽背景移动、记忆窗口位置、禁用全屏。
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.setFrameAutosaveName("MainCalculatorWindow")
            // 小工具窗全屏无意义，绿色按钮退回 zoom 语义。
            window.collectionBehavior.insert(.fullScreenNone)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

enum CalcKeyStyle {
    case digit       // 数字键：最亮一层灰阶（对应原版 NumericButtonStyle）
    case function    // 运算/函数键：深一层灰阶（对应原版 OperatorButtonStyle）
    case operatorKey // 右侧运算符列 ÷×−+= ：系统橙（Apple 计算器语义）
    case emphasized  // 科学模式 INV/2nd 态（对应原版 EmphasizedCalcButtonStyle）
}

enum CalcKeyLabel {
    case text(String)
    case symbol(String)
}

// Apple 计算器按键约 40pt 高，属 large 控件范畴——新设计收敛为胶囊形。
private let keyShape = Capsule(style: .continuous)

/// 语义灰阶色：走 NSColor 动态通道，深浅色各一份（等价于资产目录双通道，
/// 避免把单一 hex 硬编码进 Swift）。玻璃 tint 会再经系统 vibrancy 处理。
extension Color {
    static let calcDigitKey = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1.0, alpha: 0.14) : NSColor(white: 1.0, alpha: 0.85)
    })
    static let calcFunctionKey = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1.0, alpha: 0.06) : NSColor(white: 0.0, alpha: 0.05)
    })
}

private extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

/// Liquid Glass 计算器按键。布局尺寸交由外层 Grid 决定，与原版 XAML 网格一致。
struct CalcKey: View {
    let label: CalcKeyLabel
    let style: CalcKeyStyle
    let fontSize: CGFloat
    let disabled: Bool
    let flashing: Bool
    let a11yLabel: String?
    let action: () -> Void

    init(_ text: String, style: CalcKeyStyle, fontSize: CGFloat = 16, disabled: Bool = false, flashing: Bool = false, a11yLabel: String? = nil, action: @escaping () -> Void) {
        self.label = .text(text)
        self.style = style
        self.fontSize = fontSize
        self.disabled = disabled
        self.flashing = flashing
        self.a11yLabel = a11yLabel
        self.action = action
    }

    init(symbol: String, style: CalcKeyStyle, fontSize: CGFloat = 15, disabled: Bool = false, flashing: Bool = false, a11yLabel: String, action: @escaping () -> Void) {
        self.label = .symbol(symbol)
        self.style = style
        self.fontSize = fontSize
        self.disabled = disabled
        self.flashing = flashing
        self.a11yLabel = a11yLabel
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
        // 物理键盘命中时的瞬时闪动高亮。
        .overlay {
            if flashing {
                keyShape.fill(Color.white.opacity(0.35))
            }
        }
        .disabled(disabled)
        .accessibilityLabel(accessibilityText)
        // 键盘事件走全局 monitor，按键本身不参与 Tab 焦点环。
        .focusable(false)
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

    private var accessibilityText: String {
        if let a11yLabel { return a11yLabel }
        if case .text(let text) = label { return text }
        return ""
    }

    private var glass: Glass {
        var glass: Glass
        switch style {
        case .digit:
            glass = .regular.tint(.calcDigitKey)
        case .function:
            glass = .regular.tint(.calcFunctionKey)
        case .operatorKey:
            glass = .regular.tint(disabled ? Color.orange.opacity(0.4) : Color.orange)
        case .emphasized:
            glass = .regular.tint(Color.orange.opacity(0.25))
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
        return style == .operatorKey ? .white : .primary
    }
}
