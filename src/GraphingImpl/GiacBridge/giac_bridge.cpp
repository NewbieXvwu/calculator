// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "giac_bridge.h"

#include <cstdio>
#include <cstring>
#include <mutex>
#include <string>

// Windows CRT 的 stderr 重定向原语（_pipe / _dup2 / _dup / _close / _read）。
#include <fcntl.h>
#include <io.h>
#include <process.h>

// libgiac_mingw.a 导出的 C 链接入口（src/giac/caseval.cc，nm 确认符号未修饰）。
extern "C" const char* caseval(const char*);

namespace {

// 串行锁：giac 使用全局 context，非线程安全（与 macOS GiacBridge 同策略）。
std::mutex& bridgeMutex() {
    static std::mutex m;
    return m;
}

// 捕获「在调用 capture 与 release 之间执行 fn() 时写往 stderr 的文本」。
// fd 2 临时指到管道（64KB）；giac 单条分析警告为 KB 量级，不会写满
// （见头文件「已知限制」）。求值完成后恢复 fd 2 并读回。
template <typename Fn>
std::string captureStderr(Fn&& fn) {
    int fds[2] = { -1, -1 };
    int savedErr = -1;
    bool redirected = false;
    if (_pipe(fds, 64 * 1024, _O_BINARY) == 0) {
        savedErr = _dup(_fileno(stderr));
        if (savedErr >= 0) {
            _dup2(fds[1], _fileno(stderr));
            redirected = true;
        } else {
            _close(fds[0]);
            _close(fds[1]);
            fds[0] = fds[1] = -1;
        }
    }

    fn();

    std::string captured;
    if (redirected) {
        fflush(stderr);
        _dup2(savedErr, _fileno(stderr));
        _close(savedErr);
        _close(fds[1]);
        char buf[4096];
        int n;
        while ((n = static_cast<int>(_read(fds[0], buf, sizeof(buf)))) > 0) {
            captured.append(buf, static_cast<size_t>(n));
        }
        _close(fds[0]);
    }
    return captured;
}

void copyOut(char* dst, unsigned int cap, const char* src) {
    if (!dst || cap == 0) return;
    const size_t len = std::strlen(src);
    const size_t n = (len < static_cast<size_t>(cap) - 1) ? len : static_cast<size_t>(cap) - 1;
    std::memcpy(dst, src, n);
    dst[n] = '\0';
}

}  // namespace

void giac_bridge_init() {
    static std::once_flag once;
    std::call_once(once, [] {
        // 目前无全局配置需要；保留入口供将来扩展（见头文件）。
    });
}

int giac_bridge_evaluate(
    const char* expr, char* out, unsigned int cap,
    char* warnings_out, unsigned int warnings_cap) {
    if (!expr) return -2;
    if (cap > 0 && !out) return -2;
    if (warnings_cap > 0 && !warnings_out) return -2;

    std::lock_guard<std::mutex> lock(bridgeMutex());
    try {
        const bool capture = warnings_out != nullptr && warnings_cap > 0;
        std::string warnings;
        const char* result = nullptr;
        if (capture) {
            warnings = captureStderr([&] { result = caseval(expr); });
        } else {
            result = caseval(expr);
        }

        const char* text = result ? result : "GIAC_ERROR: null result";
        copyOut(out, cap, text);
        copyOut(warnings_out, warnings_cap, warnings.c_str());
        return 0;
    } catch (...) {
        // 异常绝不穿过 C 边界（M4）：折叠为错误文本。
        copyOut(out, cap, "GIAC_ERROR: internal exception");
        if (warnings_out && warnings_cap > 0) warnings_out[0] = '\0';
        return -1;
    }
}
