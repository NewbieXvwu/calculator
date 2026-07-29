// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

import CalcManagerBridge
import SwiftUI

/// Phase 0 骨架：验证 SwiftUI ↔ 引擎全链路。
/// 完整的标准模式 1:1 排版在 Phase 1 实现。
struct ContentView: View {
    @StateObject private var model = CalculatorModel()

    var body: some View {
        VStack(spacing: 8) {
            Text(model.display)
                .font(.system(size: 40, weight: .semibold, design: .default))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .foregroundStyle(model.isInError ? .red : .primary)
                .accessibilityIdentifier("primaryDisplay")

            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    key("C") { model.send(.clear) }
                        .gridCellColumns(4)
                }
                GridRow {
                    digit(7); digit(8); digit(9)
                    key("÷") { model.send(.divide) }
                }
                GridRow {
                    digit(4); digit(5); digit(6)
                    key("×") { model.send(.multiply) }
                }
                GridRow {
                    digit(1); digit(2); digit(3)
                    key("−") { model.send(.subtract) }
                }
                GridRow {
                    digit(0)
                    key(".") { model.send(.point) }
                    key("=") { model.send(.equals) }
                    key("+") { model.send(.add) }
                }
            }
            .padding(8)
        }
        .frame(minWidth: 280, minHeight: 420)
    }

    private func digit(_ value: Int) -> some View {
        key("\(value)") { model.sendDigit(value) }
    }

    private func key(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.bordered)
        .frame(minHeight: 48, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
