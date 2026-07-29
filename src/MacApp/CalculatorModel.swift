// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

import CalcManagerBridge
import Foundation

@MainActor
final class CalculatorModel: ObservableObject {
    @Published private(set) var display = "0"
    @Published private(set) var isInError = false

    private let bridge = CalcManagerBridge()

    init() {
        bridge.onDisplayChanged = { [weak self] text, isError in
            guard let self else { return }
            Task { @MainActor in
                self.display = text
                self.isInError = isError
            }
        }
        display = bridge.primaryDisplay
    }

    func sendDigit(_ digit: Int) {
        bridge.sendDigit(digit)
    }

    func send(_ command: CalcBridgeCommand) {
        bridge.sendCommand(command.rawValue)
    }
}
