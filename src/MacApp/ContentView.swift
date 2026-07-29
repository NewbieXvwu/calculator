// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Mirrors Views/Calculator.xaml: calculator on the left, History/Memory
// dock on the right when the window is wide enough (原版 DockPanel 行为).

import CalcManagerBridge
import SwiftUI

struct ContentView: View {
    @StateObject private var model = StandardCalculatorViewModel()

    private let dockVisibleThreshold: CGFloat = 560

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                StandardCalculatorView(model: model)
                    .frame(minWidth: 280)

                if proxy.size.width >= dockVisibleThreshold {
                    Divider()
                    HistoryMemoryPanel(model: model)
                        .frame(width: min(320, proxy.size.width - 320))
                }
            }
        }
        .frame(minWidth: 320, minHeight: 460)
    }
}

#Preview {
    ContentView()
}
