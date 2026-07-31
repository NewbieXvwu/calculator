#!/bin/bash
# 构建 Windows giac 桥 DLL（libgiac_bridge.dll）。
# P-Windows-1/2 求值器 A 方案的交付物：把 giac caseval 包成纯 C ABI DLL，
# 供 UWP 主程序 LoadLibrary + GetProcAddress 接入（MinGW ABI ≠ MSVC ABI，
# DLL 是唯一通道）。
#
# 前置：
#   - 已按 Tools/build_giac_windows.sh 产出 third_party/giac-win/lib/libgiac_mingw.a
#   - MSYS2/mingw64 环境（PATH 含 /usr/bin、/mingw64/bin）
#
# 产物：
#   third_party/giac-win/bin/libgiac_bridge.dll     （主 DLL，C ABI）
#   third_party/giac-win/bin/libgiac_bridge.def      （导出符号表，MSVC 侧可选）
# 链接方式：-static 全静态（gmp/mpfr/intl/pthread 全部 .a），
# 运行时只依赖系统 DLL，AppX 打包无第三方 DLL 散装问题。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GIAC_PREFIX="$ROOT/third_party/giac-win"
SRC="$ROOT/src/GraphingImpl/GiacBridge"
OUT="$GIAC_PREFIX/bin"
mkdir -p "$OUT"

x86_64-w64-mingw32-g++ -O2 -std=gnu++17 -DGIAC_BRIDGE_EXPORTS \
    -I"$SRC" \
    "$SRC/giac_bridge.cpp" \
    "$GIAC_PREFIX/lib/libgiac_mingw.a" \
    -L/mingw64/lib -lmpfr -lgmp -lintl -lpthread -lm \
    -static -static-libgcc -static-libstdc++ \
    -shared \
    -Wl,--out-implib,"$OUT/libgiac_bridge_mingw.a" \
    -Wl,--output-def,"$OUT/libgiac_bridge.def" \
    -o "$OUT/libgiac_bridge.dll"

echo ">> done: $OUT/libgiac_bridge.dll"
ls -la "$OUT/"
