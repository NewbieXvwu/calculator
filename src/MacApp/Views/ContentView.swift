// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 对应 Views/Calculator.xaml：计算器主体在左，右侧 History/Memory 侧栏
// 由工具栏常驻按钮 / ⌃H 以动画开合（macOS 惯例侧栏，替代原版 DockPanel 宽度阈值双态）。
// 工具栏：历史侧栏开关在 leading（紧贴红绿灯）、模式菜单在 trailing（Apple 计算器同款布局）。
// 整窗使用 macOS 原生毛玻璃材质。

import CalcManagerBridge
import SwiftUI

struct ContentView: View {
    let model: StandardCalculatorViewModel

    @AppStorage("HistorySidebarShown") private var sidebarShown = false

    private var sidebarActive: Bool { sidebarShown && model.mode.usesEngine }

    var body: some View {
        HStack(spacing: 0) {
            mainBody
                .frame(minWidth: minBodyWidth, maxWidth: .infinity, maxHeight: .infinity)

            if sidebarActive {
                Divider()
                HistoryMemoryPanel(model: model)
                    .frame(width: 280)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: AppIcon.sidebarHistory.sfSymbol)
                }
                .help(L10n.string("Mac_HistoryAndMemory"))
                .accessibilityLabel(L10n.string("Mac_HistoryAndMemory"))
                .disabled(!model.mode.usesEngine)
            }
            ToolbarItem(placement: .primaryAction) {
                ModeMenuButton(model: model)
            }
        }
        .background(VisualEffectBackground().ignoresSafeArea())
        .background(WindowConfigurator())
        .frame(
            minWidth: minWindowWidth + (sidebarActive ? 281 : 0),
            minHeight: minWindowHeight)
        // ⌃H / 菜单栏「历史记录」与工具栏按钮共用同一开合入口。
        .onChange(of: model.historyTogglePulse) { _, _ in
            toggleSidebar()
        }
    }

    @ViewBuilder
    private var mainBody: some View {
        switch model.mode {
        case .scientific:
            ScientificCalculatorView(model: model)
        case .programmer:
            ProgrammerCalculatorView(model: model)
        case .date:
            DateCalculatorView(model: model)
        case .converter:
            UnitConverterView(model: model)
        case .graphing:
            GraphingView(model: model)
        default:
            StandardCalculatorView(model: model)
        }
    }

    private func toggleSidebar() {
        guard model.mode.usesEngine else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            sidebarShown.toggle()
        }
        AccessibilityAnnouncer.announce(
            sidebarShown ? L10n.string("Mac_Ann_SidebarOpen") : L10n.string("Mac_Ann_SidebarClosed"), highPriority: false)
    }

    // 尺寸元数据统一查 ModeDescriptor 表（S6 规格表下沉）。
    private var minBodyWidth: CGFloat { model.mode.descriptor.minBodyWidth }

    private var minWindowWidth: CGFloat { model.mode.descriptor.minWindowWidth }

    // 标准模式允许收缩到触发紧凑档（HideStandardFunctions）；默认 500 仍是常规档。
    private var minWindowHeight: CGFloat { model.mode.descriptor.minWindowHeight }
}

#Preview {
    ContentView(model: StandardCalculatorViewModel())
}
