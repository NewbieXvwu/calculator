// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 跨版本兼容层（部署目标 macOS 14）。
//
// 设计原则（据 Apple「系统组件自动、显式玻璃必须手动」）：
//   - 标准系统控件（工具栏/菜单/sheet 等）的液态玻璃由框架按链接 SDK 自动套用，无需处理；
//   - 显式 Liquid Glass API（.glassEffect / GlassEffectContainer / .buttonStyle(.glass) /
//     .scrollEdgeEffectStyle）是 macOS 26.0+ 新符号，旧系统运行时不存在，**不会**静默降级，
//     编译器强制用 #available 包裹。这里把每个 26-only 调用收进一个封装，
//     调用点保持干净：26 上走真玻璃，14–15 回退到等价材质/旧样式。

import SwiftUI

// MARK: - Liquid Glass（macOS 26）封装

extension View {
    /// 替代裸 `.buttonStyle(.glass)`：26 用玻璃按钮，旧系统回退 `.bordered`
    /// （`.glass` 不会自动退化成 `.bordered`，必须手写 else 分支）。
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// 替代裸 `.scrollEdgeEffectStyle(.soft, for: .top)`：旧系统无此效果，直接透传。
    @ViewBuilder
    func softTopScrollEdge() -> some View {
        if #available(macOS 26, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}

/// 替代 `GlassEffectContainer`：26 共享玻璃采样区域，旧系统透传内容（间距交给内部布局）。
struct GlassKeypadContainer<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// 方向键导航的键位抽象（`onKeyPress` 的 `KeyPress.Key` 与移动逻辑解耦，
/// 便于图形画布复用而不把平台键盘事件类型泄漏到绘制层）。
enum ArrowKey { case left, right, up, down }
