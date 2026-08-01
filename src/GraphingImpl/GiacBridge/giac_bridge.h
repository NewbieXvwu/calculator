// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

// Windows giac 桥（P-Windows-1/2 求值器 A 方案）：
// 以纯 C ABI 把 giac 的 caseval 包成 DLL（libgiac_bridge.dll），供 UWP 主程序
// LoadLibrary + GetProcAddress 接入（MinGW ABI 与 MSVC 不兼容，DLL 是唯一通道）。
// 语义对齐 macOS GiacBridge（src/MacGiacBridge/GiacBridge.mm）：
//   - 求值 + stderr 警告捕获（诚实性加固依赖警告文本，见 TODO S3·R3/R4）
//   - 串行锁（giac 全局 context 非线程安全）
//   - 异常绝不穿过 C 边界（M4）
//
// 警告捕获实现：iostream 层替换 std::cerr.rdbuf()（giac 警告走 std::cerr），
// 不劫持进程级 fd 2——无管道容量死锁、不影响其他线程 stderr、UWP 无控制台
// 时依然有效（旧 CRT _pipe 方案的限制已随实现移除）。
//
// 已知限制（诚实记录）：
//   - caseval 返回全局静态缓冲，本桥立即复制到调用方缓冲后才释放锁。
//   - 捕获窗口内（仅本线程、锁内）其他线程经 std::cerr 的输出会一并进入
//     警告缓冲；经 stdio（printf/fputs）的输出不受影响。

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32) && defined(GIAC_BRIDGE_EXPORTS)
#define GIAC_BRIDGE_API __declspec(dllexport)
#else
#define GIAC_BRIDGE_API
#endif

// 一次性初始化（幂等，内部 once 保护）。纯计算无需初始化也可求值，保留此入口
// 供将来 giac 全局配置（如精度）扩展。
GIAC_BRIDGE_API void giac_bridge_init(void);

// 求值一条 Giac 表达式。
//   expr           UTF-8 表达式
//   out           结果缓冲（UTF-8，含结尾 NUL）；解析失败时以 "GIAC_ERROR:" 开头
//   cap           out 容量；0 表示只做探测（结果将被丢弃，仍返回 0）
//   warnings_out  可选：giac 写往 stderr 的警告文本（UTF-8，含结尾 NUL）
//   warnings_cap  warnings_out 容量；0 或 NULL 时不捕获
// 返回 0 成功；-1 内部异常（引擎抛错穿过 caseval）；-2 参数非法。
GIAC_BRIDGE_API int giac_bridge_evaluate(
    const char* expr, char* out, unsigned int cap,
    char* warnings_out, unsigned int warnings_cap);

#ifdef __cplusplus
}  // extern "C"
#endif
