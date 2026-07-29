import CalcManagerBridge
import Foundation

// Raw command IDs from CalculationManager::Command (Command.h).
let kAdd = 93
let kMultiply = 92
let kEquals = 121

let bridge = CalcManagerBridge()

var failures = 0

func check(_ label: String, expected: String) {
    let actual = bridge.primaryDisplay
    let ok = actual == expected
    print("\(ok ? "PASS" : "FAIL"): \(label) -> \"\(actual)\" (expected \"\(expected)\")")
    if !ok { failures += 1 }
}

bridge.sendDigit(1)
bridge.sendCommand(kAdd)
bridge.sendDigit(2)
bridge.sendCommand(kEquals)
check("1 + 2 =", expected: "3")

bridge.reset()
bridge.sendDigit(7)
bridge.sendCommand(kMultiply)
bridge.sendDigit(6)
bridge.sendCommand(kEquals)
check("7 * 6 =", expected: "42")

// New bridge surface: memory + history round-trip.
bridge.memorizeNumber()
bridge.memoryAdd(0)
let history = bridge.historyEntries()
let historyOK = history.count == 2 && history[1].result == "42"
print("\(historyOK ? "PASS" : "FAIL"): history entries -> \(history.count) items, last result \(history.last?.result ?? "nil")")
if !historyOK { failures += 1 }

exit(failures == 0 ? 0 : 1)
