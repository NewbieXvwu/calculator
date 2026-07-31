// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// S5 · C ABI 门面冒烟测试：Swift 直接绑定 calc_c_api.h（与 Kotlin/JNI、
// TS/Emscripten、ArkTS/NAPI 走同一条 extern "C" 通道）。
// 命令码镜像 CalculationManager::Command（Command.h）。

import XCTest
import CalcManagerBridge
@testable import MacCalculator

private final class CApiBox {
    var display = ""
    var isError = false
    var historyAdded: [UInt32] = []
    var memory: [String] = []
    var tokens: [(String, Int32)] = []
}

final class CalcCApiTests: XCTestCase {
    private let cmdAdd: Int32 = 93      // CommandADD
    private let cmdEquals: Int32 = 121  // CommandEQU

    private func makeSession(_ box: CApiBox, locale: calc_locale_t? = nil) -> OpaquePointer {
        let session: OpaquePointer?
        if var locale {
            session = withUnsafePointer(to: &locale) { calc_session_create($0) }
        } else {
            session = calc_session_create(nil)
        }
        guard let session else {
            XCTFail("calc_session_create 返回 NULL")
            fatalError()
        }

        var cbs = calc_callbacks_t()
        cbs.user_data = Unmanaged.passUnretained(box).toOpaque()
        cbs.on_primary_display = { ud, text, isError in
            let box = Unmanaged<CApiBox>.fromOpaque(ud!).takeUnretainedValue()
            box.display = text.map { String(cString: $0) } ?? ""
            box.isError = isError
        }
        cbs.on_history_item_added = { ud, index in
            Unmanaged<CApiBox>.fromOpaque(ud!).takeUnretainedValue().historyAdded.append(index)
        }
        cbs.on_memorized_numbers = { ud, values, count in
            let box = Unmanaged<CApiBox>.fromOpaque(ud!).takeUnretainedValue()
            box.memory = (0..<count).compactMap { values?[$0].map { String(cString: $0) } }
        }
        cbs.on_expression_tokens = { ud, tokens, count in
            let box = Unmanaged<CApiBox>.fromOpaque(ud!).takeUnretainedValue()
            box.tokens = (0..<count).compactMap { i in
                guard let t = tokens?[i] else { return nil }
                return (t.text.map { String(cString: $0) } ?? "", t.command_index)
            }
        }
        XCTAssertEqual(calc_session_set_callbacks(session, &cbs), CALC_OK)
        return session
    }

    func testArithmeticAndHistory() {
        let box = CApiBox()
        let session = makeSession(box)
        defer { calc_session_destroy(session) }

        XCTAssertEqual(calc_send_digit(session, 2), CALC_OK)
        XCTAssertEqual(calc_send_command(session, cmdAdd), CALC_OK)
        XCTAssertEqual(calc_send_digit(session, 3), CALC_OK)
        XCTAssertEqual(calc_send_command(session, cmdEquals), CALC_OK)

        XCTAssertEqual(box.display, "5")
        XCTAssertFalse(box.isError)
        XCTAssertEqual(box.historyAdded, [0])
        XCTAssertEqual(calc_history_count(session), 1)

        var expr: UnsafeMutablePointer<CChar>?
        var result: UnsafeMutablePointer<CChar>?
        XCTAssertEqual(calc_history_entry(session, 0, &expr, &result), CALC_OK)
        XCTAssertEqual(result.map { String(cString: $0) }, "5")
        XCTAssertTrue((expr.map { String(cString: $0) } ?? "").contains("2"))
        calc_string_free(expr)
        calc_string_free(result)

        XCTAssertEqual(calc_history_clear(session), CALC_OK)
        XCTAssertEqual(calc_history_count(session), 0)
    }

    func testMemoryCallbacks() {
        let box = CApiBox()
        let session = makeSession(box)
        defer { calc_session_destroy(session) }

        _ = calc_send_digit(session, 7)
        XCTAssertEqual(calc_memory_store(session), CALC_OK)
        XCTAssertEqual(box.memory, ["7"])
        XCTAssertEqual(calc_memory_add(session, 0), CALC_OK)
        XCTAssertEqual(box.memory, ["14"])
        XCTAssertEqual(calc_memory_clear_all(session), CALC_OK)
        XCTAssertTrue(box.memory.isEmpty)
    }

    func testLocaleInjection() {
        let box = CApiBox()
        let locale = calc_locale_t(
            decimal_separator: strdup(","),
            thousand_separator: strdup("."),
            grouping: strdup("3;0"))
        defer {
            free(UnsafeMutablePointer(mutating: locale.decimal_separator))
            free(UnsafeMutablePointer(mutating: locale.thousand_separator))
            free(UnsafeMutablePointer(mutating: locale.grouping))
        }
        let session = makeSession(box, locale: locale)
        defer { calc_session_destroy(session) }

        XCTAssertEqual(calc_decimal_separator(session), UInt32(UnicodeScalar(",").value))
        _ = calc_send_digit(session, 1)
        _ = calc_send_command(session, 84) // CommandPNT
        _ = calc_send_digit(session, 5)
        XCTAssertEqual(box.display, "1,5")
    }

    func testProgrammerRadix() {
        let box = CApiBox()
        let session = makeSession(box)
        defer { calc_session_destroy(session) }

        XCTAssertEqual(calc_set_mode(session, CALC_MODE_PROGRAMMER), CALC_OK)
        _ = calc_send_digit(session, 2)
        _ = calc_send_digit(session, 5)
        _ = calc_send_digit(session, 5)
        _ = calc_send_command(session, cmdEquals)

        let hex = calc_result_for_radix(session, 16, 64, false)
        XCTAssertEqual(hex.map { String(cString: $0) }, "FF")
        calc_string_free(hex)
    }

    func testBoundarySafety() {
        // NULL 会话不崩溃、返回错误码/安全默认值。
        XCTAssertEqual(calc_send_command(nil, cmdAdd), CALC_E_UNKNOWN)
        XCTAssertEqual(calc_history_count(nil), 0)
        XCTAssertTrue(calc_is_input_empty(nil))
        XCTAssertNil(calc_result_for_radix(nil, 16, 64, false))
        calc_string_free(nil)

        // 越界参数经边界护栏折叠为错误码，不抛异常。
        let box = CApiBox()
        let session = makeSession(box)
        defer { calc_session_destroy(session) }
        XCTAssertEqual(calc_send_digit(session, 99), CALC_E_UNKNOWN)
        var e: UnsafeMutablePointer<CChar>?
        var r: UnsafeMutablePointer<CChar>?
        XCTAssertEqual(calc_history_entry(session, 5, &e, &r), CALC_E_UNKNOWN)
    }
}
