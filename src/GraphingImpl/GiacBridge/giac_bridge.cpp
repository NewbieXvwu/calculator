// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "giac_bridge.h"

#include <cstdio>
#include <cstring>
#include <iostream>
#include <mutex>
#include <sstream>
#include <string>

// libgiac_mingw.a 导出的 C 链接入口（src/giac/caseval.cc，nm 确认符号未修饰）。
extern "C" const char* caseval(const char*);

namespace {

// 串行锁：giac 使用全局 context，非线程安全（与 macOS GiacBridge 同策略）。
std::mutex& bridgeMutex() {
    static std::mutex m;
    return m;
}

// 捕获「在调用 capture 与 release 之间执行 fn() 时写往 std::cerr 的文本」。
// 实现：在 iostream 层临时替换 std::cerr.rdbuf() 为 ostringstream，而非劫持
// 进程级 fd 2。相比旧的 CRT _pipe 方案：
//   - 无 64KB 管道容量限制：写满会阻塞求值线程 → 永久死锁（旧 H3）；现在
//     缓冲无限增长（警告量级为 KB，实际无碍），无写端阻塞。
//   - 不触碰 fd 2：其他线程/库经 stdio（printf/fputs）写的 stderr 不受影响
//     （旧 H4 会混入 warnings 或丢失）；本线程 cerr 之外的输出天然隔离。
//   - UWP 无控制台（_fileno(stderr) == -1，旧方案捕获静默失效）依然有效。
// 异常安全：fn() 抛异常时先恢复 rdbuf 再重抛，调用方（giac_bridge_evaluate）
// 的 catch(...) 折叠为 GIAC_ERROR 文本。
template <typename Fn>
std::string captureStderr(Fn&& fn) {
    std::ostringstream oss;
    std::streambuf* saved = std::cerr.rdbuf(oss.rdbuf());
    try {
        fn();
    } catch (...) {
        std::cerr.rdbuf(saved);
        throw;
    }
    std::cerr.rdbuf(saved);
    return oss.str();
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
        if (capture) {
            // W-2/W-4：rdbuf 捕获是进程级全局，其他线程写 cerr 会混入；
            // 只保留 giac 警告特征行（诚实性判定依赖的文本），并限制缓冲
            // 大小（防恶意/故障查询产生 GB 级警告的慢速 OOM），保留尾部
            // （最新警告对诚实性判定最相关）。
            std::string filtered;
            size_t pos = 0;
            while (pos <= warnings.size()) {
                size_t nl = warnings.find('\n', pos);
                std::string line = warnings.substr(pos, nl == std::string::npos ? std::string::npos : nl - pos);
                std::string low;
                low.reserve(line.size());
                for (char c : line) low += static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
                if (low.find("periodic") != std::string::npos ||
                    low.find("assume") != std::string::npos ||
                    low.find("approx") != std::string::npos ||
                    low.find("bisection") != std::string::npos ||
                    low.find("warning") != std::string::npos ||
                    low.find("error") != std::string::npos) {
                    filtered += line;
                    filtered += '\n';
                }
                if (nl == std::string::npos) break;
                pos = nl + 1;
            }
            const size_t kTailLimit = 64 * 1024;
            if (filtered.size() > kTailLimit)
                filtered = filtered.substr(filtered.size() - kTailLimit);
            copyOut(warnings_out, warnings_cap, filtered.c_str());
        } else if (warnings_out && warnings_cap > 0) {
            warnings_out[0] = '\0';
        }
        return 0;
    } catch (...) {
        // 异常绝不穿过 C 边界（M4）：折叠为错误文本。
        copyOut(out, cap, "GIAC_ERROR: internal exception");
        if (warnings_out && warnings_cap > 0) warnings_out[0] = '\0';
        return -1;
    }
}
