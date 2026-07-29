import CalcManagerBridge
import Foundation

let bridge = CalcManagerBridge()

var failures = 0

func check(_ label: String, expected: String) {
    let actual = bridge.primaryDisplay
    let ok = actual == expected
    print("\(ok ? "PASS" : "FAIL"): \(label) -> \"\(actual)\" (expected \"\(expected)\")")
    if !ok { failures += 1 }
}

bridge.sendDigit(1)
bridge.sendCommand(CalcBridgeCommand.add.rawValue)
bridge.sendDigit(2)
bridge.sendCommand(CalcBridgeCommand.equals.rawValue)
check("1 + 2 =", expected: "3")

bridge.reset()
bridge.sendDigit(7)
bridge.sendCommand(CalcBridgeCommand.multiply.rawValue)
bridge.sendDigit(6)
bridge.sendCommand(CalcBridgeCommand.equals.rawValue)
check("7 * 6 =", expected: "42")

exit(failures == 0 ? 0 : 1)
