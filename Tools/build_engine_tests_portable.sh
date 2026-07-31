#!/bin/sh
# S10 · 可移植引擎测试构建：不经 SPM，直接用 clang++/g++ 编 CalcManager + 引擎
# 测试（含黄金向量跑器），供跨架构 CI 腿（x86-64 Linux 等）验证黄金测试逐位一致。
# macOS 上 SPM 路径仍是日常入口（swift run engine-tests）；本脚本保证同一套
# 源码和向量在任何有 C++20 编译器的平台上可独立复现。
#
# 用法：Tools/build_engine_tests_portable.sh [输出目录，默认 .build-portable]
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/.build-portable}"
CXX="${CXX:-clang++}"

mkdir -p "$OUT"

# 与 Package.swift 的 engine-tests target 完全同源：
#   CalcManagerCore 全部源文件（排除 pch.cpp/smoketest）+ MacEngineTests 全部源文件。
set --
for f in "$ROOT/src/CalcManager"/*.cpp \
         "$ROOT/src/CalcManager/CEngine"/*.cpp \
         "$ROOT/src/CalcManager/Ratpack"/*.cpp \
         "$ROOT/src/MacEngineTests"/*.cpp; do
    case "$f" in
        */pch.cpp) continue ;;
    esac
    set -- "$@" "$f"
done

"$CXX" -std=c++20 -O1 \
    -I "$ROOT/src" \
    -I "$ROOT/src/CalcManager" \
    -I "$ROOT/src/CalcManager/Ratpack" \
    -I "$ROOT/src/MacEngineTests" \
    -I "$ROOT/src/MacEngineTests/shim" \
    -I "$ROOT/src/MacBridge" \
    -o "$OUT/engine-tests" \
    "$@"

echo "built: $OUT/engine-tests"
"$OUT/engine-tests"
