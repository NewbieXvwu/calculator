# 与上游（microsoft/calculator）的已知差异

> 目的：将来 rebase 上游时，这里列出的本地修改**不得被覆盖**。
> 每项差异附理由与证据。上游 `src/CalcManager/pch.h` 的注释明确要求
> 引擎支持非 MSVC 工具链（"compiles both in Windows and other platforms"），
> 下列修复正是为满足该目标——这些文件原先违反了它。

## 1. `src/CalcManager/Ratpack/support.cpp` — 补 `#include <cmath>`

- **改动**：新增 `#include <cmath>`（`log2` / `ceil`）。
- **原因**：Apple SDK 的 libc++ 头相互间接包含，侥幸可编；换任何其它标准库即失败。
- **证据**（实测）：GCC 14 / Linux：
  `support.cpp:139: error: 'log2' was not declared in this scope`

## 2. `src/CalcManager/Header Files/IHistoryDisplay.h` — 补 `#include <string>` `<string_view>`

- **改动**：新增 `#include <string>` 与 `#include <string_view>`（`std::wstring_view`）。
- **原因**：同上，依赖间接包含。
- **证据**（实测）：OHOS clang 15.0.4 / aarch64：
  `IHistoryDisplay.h:16: error: no type named 'wstring_view' in namespace 'std'`

## 防回归

`Tools/check_engine_cxx17.sh` 在 CI（engine job）对全部引擎翻译单元做
`-std=c++17 -fsyntax-only` 检查：既锁定引擎不引入 C++20 依赖，
也能暴露新的隐式 include（该检查不经 Xcode 预编译头路径）。

## 上游关系

按 TODO v2 §D7：**不向上游提 PR**，以上作为 fork 内本地修复维护。
