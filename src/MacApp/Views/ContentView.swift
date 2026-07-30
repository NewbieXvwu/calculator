// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 对应 Views/Calculator.xaml：计算器主体在左，窗口足够宽时右侧显示
// History/Memory 停靠面板（原版 DockPanel 行为）；窄窗时顶栏出现历史按钮。
// 整窗使用 macOS 原生毛玻璃材质。

import CalcManagerBridge
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: StandardCalculatorViewModel

    private let dockVisibleThreshold: CGFloat = 560

    var body: some View {
        GeometryReader { proxy in
            let dockVisible = proxy.size.width >= dockVisibleThreshold
            HStack(spacing: 0) {
                Group {
                    switch model.mode {
                    case .scientific:
                        ScientificCalculatorView(model: model, showsHistoryButton: !dockVisible)
                    case .programmer:
                        ProgrammerCalculatorView(model: model, showsHistoryButton: !dockVisible)
                    case .date:
                        DateCalculatorView(model: model, showsHistoryButton: !dockVisible)
                    case .converter:
                        UnitConverterView(model: model, showsHistoryButton: !dockVisible)
                    case .graphing:
                        GraphingView(model: model, showsHistoryButton: !dockVisible)
                    default:
                        StandardCalculatorView(model: model, showsHistoryButton: !dockVisible)
                    }
                }
                .frame(minWidth: minBodyWidth)

                if dockVisible && model.mode.usesEngine {
                    Divider()
                    HistoryMemoryPanel(model: model)
                        .frame(width: min(300, proxy.size.width - 320))
                }
            }
        }
        .background(VisualEffectBackground().ignoresSafeArea())
        .background(WindowConfigurator())
        .frame(minWidth: minWindowWidth, minHeight: minWindowHeight)
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
