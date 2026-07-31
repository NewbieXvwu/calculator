// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// calc_cli — 命令行计算器（P-CLI/TUI 白送项：共享层 C ABI 的最小验证载体）。
//
// 纯 C++17，仅依赖 calc_c_api.h（S5 C ABI 门面）+ 引擎静态库。这是除 macOS
// Swift 外的第一个 C ABI 真实消费方，验证：
//   - 会话生命周期 / 命令 / 数字输入 / 显示回调 / 历史 / 内存
//   - UTF-8 字符串约定（引擎内部 wchar_t，边界处转换）
//   - 异常不穿 C 边界（除零 → CALC_E_DIVIDEBYZERO 错误码）
//
// 用法：
//   calc_cli "1+2*3="         单次表达式（'=' 触发求值，输出结果）
//   calc_cli -h "2+2=" "3*3=" 带历史输出（-h 打印历史条目）
//   calc_cli                  交互 REPL（逐行表达式，Ctrl+D/Ctrl+Z 退出）
//
// 按键映射：0-9 数字、. 小数点、+ - * / 运算、= 求值、% 百分号、
//           C 清除、B 退格、N 取负、H 历史、M 内存列表、Q 退出。

#include "calc_c_api.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>

// LSP（macOS 侧）include 路径提示：编译时经 -I<repo>/src/MacBridge/include。
namespace {

// 引擎命令枚举（镜像 Command.h 的 Command，仅用到的子集）。
constexpr int32_t kCmdNull = 0;
constexpr int32_t kCmdSign = 80;
constexpr int32_t kCmdClear = 81;
constexpr int32_t kCmdBack = 83;
constexpr int32_t kCmdPnt = 84;
constexpr int32_t kCmdDiv = 91;
constexpr int32_t kCmdMul = 92;
constexpr int32_t kCmdAdd = 93;
constexpr int32_t kCmdSub = 94;
constexpr int32_t kCmdPercent = 118;
constexpr int32_t kCmdEqu = 121;
constexpr int32_t kCmdExp = 127;
constexpr int32_t kCmdPwr = 97;

std::string g_lastDisplay;
bool g_inError = false;

void OnPrimaryDisplay(void*, const char* utf8_text, bool is_error) {
    g_lastDisplay = utf8_text ? utf8_text : "";
    g_inError = is_error;
}

// 单个输入字符 → 命令。返回 false 表示不是引擎命令（数字/小数点走专用通道）。
bool CharToCommand(char c, int32_t& cmdOut) {
    switch (c) {
        case '+': cmdOut = kCmdAdd; return true;
        case '-': cmdOut = kCmdSub; return true;
        case '*': cmdOut = kCmdMul; return true;
        case '/': cmdOut = kCmdDiv; return true;
        case '=': cmdOut = kCmdEqu; return true;
        case '%': cmdOut = kCmdPercent; return true;
        case '.': cmdOut = kCmdPnt; return true;
        case 'C': case 'c': cmdOut = kCmdClear; return true;
        case 'B': case 'b': cmdOut = kCmdBack; return true;
        case 'N': case 'n': cmdOut = kCmdSign; return true;
        case 'E': case 'e': cmdOut = kCmdExp; return true;
        case '^': cmdOut = kCmdPwr; return true;
        default: return false;
    }
}

// 求值一行表达式（如 "1+2*3="；'=' 可省，自动补）。返回显示结果。
bool EvaluateLine(calc_session_t* session, const std::string& line, std::string& result) {
    // 每行从干净状态开始（清错误/显示，保留内存——CLI 行间独立）。
    calc_reset(session, /*clear_memory=*/false);
    for (char c : line) {
        if (c >= '0' && c <= '9') {
            calc_send_digit(session, c - '0');
            continue;
        }
        int32_t cmd = 0;
        if (CharToCommand(c, cmd)) {
            calc_send_command(session, cmd);
            continue;
        }
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n') continue;
        result = "unknown input: " + std::string(1, c);
        return false;
    }
    // 未以 '=' 结尾则补一次求值（幂等）。
    if (line.find('=') == std::string::npos) {
        calc_send_command(session, kCmdEqu);
    }
    result = g_inError ? ("ERROR: " + g_lastDisplay) : g_lastDisplay;
    return true;
}

void PrintHistory(calc_session_t* session) {
    const size_t count = calc_history_count(session);
    if (count == 0) {
        printf("(no history)\n");
        return;
    }
    printf("history (%zu):\n", count);
    for (size_t i = 0; i < count; ++i) {
        char* expr = nullptr;
        char* res = nullptr;
        if (calc_history_entry(session, i, &expr, &res) == CALC_OK && expr && res) {
            printf("  %s = %s\n", expr, res);
        }
        calc_string_free(expr);
        calc_string_free(res);
    }
}

void PrintMemory(calc_session_t* session) {
    // 内存回调走 calc_callbacks_t.on_memorized_numbers；CLI 直接输出占位提示，
    // 完整内存交互（MS/MR/M+/M-）留给 TUI 阶段（P-CLI 后续）。
    printf("(memory UI is a TUI-phase feature; engine memory APIs available)\n");
}

}  // namespace

int main(int argc, char** argv) {
    calc_session_t* session = calc_session_create(nullptr);
    if (!session) {
        fprintf(stderr, "calc_session_create failed\n");
        return 1;
    }
    calc_callbacks_t cb{};
    cb.on_primary_display = OnPrimaryDisplay;
    calc_session_set_callbacks(session, &cb);

    const bool showHistory = argc > 1 && std::strcmp(argv[1], "-h") == 0;
    const int firstArg = showHistory ? 2 : 1;

    if (argc > firstArg) {
        // 命令行模式：逐参数求值。
        for (int i = firstArg; i < argc; ++i) {
            std::string result;
            if (!EvaluateLine(session, argv[i], result)) {
                printf("%s\n", result.c_str());
                continue;
            }
            printf("%s = %s\n", argv[i], result.c_str());
        }
        if (showHistory) PrintHistory(session);
        calc_session_destroy(session);
        return 0;
    }

    // REPL 模式。
    printf("calc_cli — C ABI calculator (keys: 0-9 . + - * / = %% C B N E, H history, M memory, Q quit)\n");
    std::string line;
    while (true) {
        printf("> ");
        fflush(stdout);
        if (!std::getline(std::cin, line)) break;
        if (line == "Q" || line == "q") break;
        if (line == "H" || line == "h") { PrintHistory(session); continue; }
        if (line == "M" || line == "m") { PrintMemory(session); continue; }
        if (line.empty()) continue;
        std::string result;
        if (!EvaluateLine(session, line, result)) {
            printf("%s\n", result.c_str());
            continue;
        }
        printf("%s\n", result.c_str());
    }
    calc_session_destroy(session);
    return 0;
}
