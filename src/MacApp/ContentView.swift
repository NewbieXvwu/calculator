// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// 对应 Views/Calculator.xaml：计算器主体在左，窗口足够宽时右侧显示
// History/Memory 停靠面板（原版 DockPanel 行为）；窄窗时顶栏出现历史按钮。
// 整窗使用 macOS 原生毛玻璃材质。

import CalcManagerBridge
import SwiftUI

struct ContentView: View {
    @StateObject private var model = StandardCalculatorViewModel()

    private let dockVisibleThreshold: CGFloat = 560

    var body: some View {
        GeometryReader { proxy in
            let dockVisible = proxy.size.width >= dockVisibleThreshold
            HStack(spacing: 0) {
                StandardCalculatorView(model: model, showsHistoryButton: !dockVisible)
                    .frame(minWidth: 280)

                if dockVisible {
                    Divider()
                    HistoryMemoryPanel(model: model)
                        .frame(width: min(300, proxy.size.width - 320))
                }
            }
        }
        .background(VisualEffectBackground().ignoresSafeArea())
        .background(WindowConfigurator())
        .frame(minWidth: 322, minHeight: 480)
    }
}

#Preview {
    ContentView()
}
