#!/bin/sh
# P-CLI/TUI 白送项：命令行计算器构建脚本（共享层 C ABI 的最小跨平台验证载体）。
# 不经 SPM，纯 clang++/g++ 编译：CalcManager 引擎 + CalcSession + calc_c_api
# （C ABI 门面）+ calc_cli.cpp。任何有 C++20 编译器的平台（macOS/Linux/WASM/
# Windows-MinGW）都可复现，验证 C ABI 契约的可移植性。
#
# 用法：Tools/build_calc_cli.sh [输出目录，默认 .build-portable]
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/.build-portable}"
CXX="${CXX:-clang++}"

mkdir -p "$OUT"

set --
for f in "$ROOT/src/CalcManager"/*.cpp \
         "$ROOT/src/CalcManager/CEngine"/*.cpp \
         "$ROOT/src/CalcManager/Ratpack"/*.cpp \
         "$ROOT/src/MacBridge/CalcSession.cpp" \
         "$ROOT/src/MacBridge/calc_c_api.cpp" \
         "$ROOT/src/CalcManager/smoketest/calc_cli.cpp"; do
    case "$f" in
        */pch.cpp) continue ;;
    esac
    set -- "$@" "$f"
done

"$CXX" -std=c++20 -O1 \
    -I "$ROOT/src" \
    -I "$ROOT/src/CalcManager" \
    -I "$ROOT/src/CalcManager/Ratpack" \
    -I "$ROOT/src/MacBridge" \
    -I "$ROOT/src/MacBridge/include" \
    -o "$OUT/calc-cli" \
    "$@"

echo "built: $OUT/calc-cli"
