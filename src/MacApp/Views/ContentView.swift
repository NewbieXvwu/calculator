// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 对应 Views/Calculator.xaml：计算器主体在左，右侧 History/Memory 侧栏
// 由工具栏常驻按钮 / ⌃H 以动画开合（macOS 惯例侧栏，替代原版 DockPanel 宽度阈值双态）。
// 工具栏：历史侧栏开关在 leading（紧贴红绿灯）、模式菜单在 trailing（Apple 计算器同款布局）。
// 整窗使用 macOS 原生毛玻璃材质。

import CalcManagerBridge
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: StandardCalculatorViewModel

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
                    Image(systemName: "sidebar.leading")
                }
                .help("历史记录与内存")
                .accessibilityLabel("历史记录与内存")
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
        .onChangeCompat(of: model.historyTogglePulse) { _ in
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
            sidebarShown ? "历史记录面板已打开" : "历史记录面板已关闭", highPriority: false)
    }

    private var minBodyWidth: CGFloat {
        switch model.mode {
        case .scientific: return 360
        case .programmer: return 340
        case .date: return 300
        case .converter: return 300
        case .graphing: return 480
        case .standard: return 280
        }
    }

    private var minWindowWidth: CGFloat {
        switch model.mode {
        case .scientific: return 400
        case .programmer: return 380
        case .date: return 340
        case .converter: return 340
        case .graphing: return 560
        case .standard: return 322
        }
    }

    private var minWindowHeight: CGFloat {
        switch model.mode {
        case .scientific: return 560
        case .programmer: return 600
        case .date: return 460
        case .converter: return 520
        case .graphing: return 520
        // 允许收缩到触发紧凑档（HideStandardFunctions）；默认 500 仍是常规档。
        case .standard: return 360
        }
    }
}

#Preview {
    ContentView(model: StandardCalculatorViewModel())
}
