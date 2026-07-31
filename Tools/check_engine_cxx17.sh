#!/bin/sh
# 引擎可移植性闸门：CalcManager 必须能在 -std=c++17 下编译（防止引入 C++20 依赖，
# 也顺带暴露"靠 Apple SDK 间接包含侥幸编过"的隐式 include，见 TODO §S1）。
# 只做语法/语义检查（-fsyntax-only），不产出目标文件。
# 另含 S10 标量一致性检查：src/ 内禁止 long double（平台位宽不一：MSVC 64 位、
# x86-64 80 位、aarch64 128 位），唯一豁免是 CalcScalar.h 逃生通道本身。
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="$ROOT/src/CalcManager"
CXX="${CXX:-clang++}"

# S10：long double 禁令（grep 有命中即失败）。
if grep -rn "long double" "$ROOT/src/" | grep -v CalcScalar.h; then
    echo "FAIL: 'long double' found in src/ (only CalcScalar.h may mention it)" >&2
    exit 1
fi

status=0
for f in "$ENGINE"/*.cpp "$ENGINE"/CEngine/*.cpp "$ENGINE"/Ratpack/*.cpp; do
    case "$f" in
        */pch.cpp) continue ;;
    esac
    if ! "$CXX" -std=c++17 -fsyntax-only \
        -I "$ENGINE" -I "$ENGINE/Ratpack" \
        "$f"; then
        echo "FAIL (c++17): $f" >&2
        status=1
    fi
done

if [ "$status" -eq 0 ]; then
    echo "engine c++17 syntax check: OK"
fi
exit "$status"
