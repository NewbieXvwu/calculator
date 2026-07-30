// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 跨版本兼容层（部署目标 macOS 13）。
//
// 设计原则（据 Apple「系统组件自动、显式玻璃必须手动」）：
//   - 标准系统控件（工具栏/菜单/sheet 等）的液态玻璃由框架按链接 SDK 自动套用，无需处理；
//   - 显式 Liquid Glass API（.glassEffect / GlassEffectContainer / .buttonStyle(.glass) /
//     .scrollEdgeEffectStyle）是 macOS 26.0+ 新符号，旧系统运行时不存在，**不会**静默降级，
//     编译器强制用 #available 包裹。这里把每个 26-only 调用收进一个封装，
//     调用点保持干净：26 上走真玻璃，13–15 回退到等价材质/旧样式。
//   - 少数 macOS 14 API（onKeyPress / onChange 新闭包 / ContentUnavailableView）同样在此收口。

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

// MARK: - macOS 14 API 收口

extension View {
    /// `onChange` 版本兼容：14+ 用双参新闭包，13 退回单参旧闭包（避免弃用告警且可编译到 13）。
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, _ action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14, *) {
            self.onChange(of: value) { _, newValue in action(newValue) }
        } else {
            self.onChange(of: value) { newValue in action(newValue) }
        }
    }

    /// `defaultScrollAnchor(.trailing)`（macOS 14）：让横向表达式滚动初始锚定到尾部（显示最新 token）。
    /// 13 上无此 API，直接透传（表达式从头部显示，属可接受降级）。
    @ViewBuilder
    func defaultTrailingScrollAnchor() -> some View {
        if #available(macOS 14, *) {
            self.defaultScrollAnchor(.trailing)
        } else {
            self
        }
    }
}

/// 方向键导航封装：`onKeyPress` 是 macOS 14 API（`KeyPress` 类型亦然），
/// 故公开签名只用版本无关的 `ArrowKey`/`Bool`，把 14-only 符号锁进 #available 分支。
/// 13 上无键盘方向键跟踪（鼠标跟踪不受影响），属可接受的优雅降级。
enum ArrowKey { case left, right, up, down }

extension View {
    @ViewBuilder
    func arrowKeyNavigation(_ handler: @escaping (_ key: ArrowKey, _ fine: Bool) -> Bool) -> some View {
        if #available(macOS 14, *) {
            self.onKeyPress(
                keys: [.leftArrow, .rightArrow, .upArrow, .downArrow],
                phases: [.down, .repeat]
            ) { press in
                let key: ArrowKey
                switch press.key {
                case .leftArrow: key = .left
                case .rightArrow: key = .right
                case .upArrow: key = .up
                case .downArrow: key = .down
                default: return .ignored
                }
                return handler(key, press.modifiers.contains(.shift)) ? .handled : .ignored
            }
        } else {
            self
        }
    }
}

/// 空态视图：14+ 用系统 `ContentUnavailableView`，13 手绘等价布局。
struct CalcEmptyState: View {
    let title: String
    let systemImage: String
    let description: Text

    var body: some View {
        if #available(macOS 14, *) {
            ContentUnavailableView(title, systemImage: systemImage, description: description)
        } else {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                description
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
            .padding()
        }
    }
}
