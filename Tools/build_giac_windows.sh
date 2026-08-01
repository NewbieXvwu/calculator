#!/bin/bash
# 在 Windows（MSYS2/mingw64）上构建 Giac 静态库。
# P-Windows-1/2 求值器（A 方案：完整移植 giac）的可复现构建脚本。
#
# 前置（实测 2026-08-01）：
#   - MSYS2（建议从清华/中科大镜像下载 msys2-base-x86_64-*.tar.xz，解压到用户目录免 UAC）
#   - pacman 包：base-devel mingw-w64-x86_64-gcc mingw-w64-x86_64-gmp mingw-w64-x86_64-mpfr
#     （MSYS2 自带 gettext/libintl、winpthreads，勿删）
#   - 必须从「MSYS2 环境」运行本脚本，或用 bash.exe 直接执行（PATH 需含 /usr/bin）
#
# 已知坑（实测）：
#   1. giac 自带 config.guess/sub 是 2017 版，不认识 MSYS2 的 uname（Windows_NT）→
#      必须替换为 autoconf-mirror 2025 版（config/ 子目录也要换），并显式
#      --build=x86_64-w64-mingw32 --host=x86_64-w64-mingw32 跳过 build type 猜测
#   2. 生成的 libtool 脚本在本环境静默失效（--mode=compile 直接跳过，无产物、
#      exit 0）→ 本脚本绕开 libtool，直接 g++ -c + ar 打包（见下方循环）
#   3. 机器 PATH 若有 w64devkit / Git 等其它工具链，make 可能解析到错误的 sh/gcc
#      → 本脚本固定 export PATH=/usr/bin:/mingw64/bin:$PATH
#
# 产物：<ROOT>/third_party/giac-win/lib/libgiac_mingw.a（GPLv3，链接产物受 GPL 约束）
#
# 用法：Tools/build_giac_windows.sh [版本号，默认 2.1.0]
set -euo pipefail

VERSION="${1:-2.1.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build-giac-win"
PREFIX="$ROOT/third_party/giac-win"
TARBALL="giac-$VERSION.tar.gz"
URL="https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac/$TARBALL"

mkdir -p "$BUILD"
cd "$BUILD"
if [ ! -f "$TARBALL" ]; then
    echo ">> downloading $TARBALL（官方源较慢，可手动放入 $BUILD/）"
    for _ in $(seq 1 30); do
        curl -sL -C - --max-time 540 -o "$TARBALL" "$URL" && break || true
    done
fi
[ -d "giac-$VERSION" ] || tar xzf "$TARBALL"

cd "giac-$VERSION"

# 1) config.guess/sub 换 2025 版（根目录 + config/ 子目录）
curl -sL --max-time 60 -o config.sub https://raw.githubusercontent.com/autotools-mirror/autoconf/master/build-aux/config.sub
curl -sL --max-time 60 -o config.guess https://raw.githubusercontent.com/autotools-mirror/autoconf/master/build-aux/config.guess
chmod +x config.sub config.guess
cp config.sub config/config.sub 2>/dev/null || true
cp config.guess config/config.guess 2>/dev/null || true
chmod +x config/config.sub config/config.guess 2>/dev/null || true

# 2) configure（跳过 build type 猜测 + 最小依赖）
if [ ! -f config.h ]; then
    CPPFLAGS="-I/mingw64/include" \
    LDFLAGS="-L/mingw64/lib" \
    CXXFLAGS="-O3 -std=gnu++17" \
    ./configure --build=x86_64-w64-mingw32 --host=x86_64-w64-mingw32 \
        --disable-shared --enable-static --disable-dependency-tracking \
        --disable-fltk --disable-gui --disable-ntl --disable-pari --disable-gsl \
        --disable-lapack --disable-ecm --disable-bernmm --disable-glpk --disable-ao \
        --disable-samplerate --disable-curl --disable-micropy --disable-quickjs \
        --disable-nls --disable-png --disable-dl
fi

# 3) 绕开 libtool，直接编译 + ar 打包（见文件头「已知坑 2」）
cd src
COMMON="-DHAVE_CONFIG_H -I. -I.. -DIN_GIAC -I. -I.. -I. -I.. -I/mingw64/include -O3 -std=gnu++17 -U_GLIBCXX_ASSERTIONS -DUSE_OBJET_BIDON -fno-strict-aliasing -DGIAC_GENERIC_CONSTANTS -DTIMEOUT"
mkdir -p build_objs
n=0
pids=()
for f in *.cc; do
    base=$(basename "$f" .cc)
    obj="build_objs/${base}.o"
    if [ ! -f "$obj" ]; then
        x86_64-w64-mingw32-g++ $COMMON -c "$f" -o "$obj" &
        pids+=("$!")
        n=$((n+1))
        if [ $((n % 20)) -eq 0 ]; then
            # 逐 PID 检查退出码：无参 wait 静默返回 0，编译失败会被吞掉
            for p in "${pids[@]}"; do wait "$p" || { echo "!! 编译失败 (PID $p)" >&2; exit 1; }; done
            pids=()
        fi
    fi
done
for p in "${pids[@]}"; do wait "$p" || { echo "!! 编译失败 (PID $p)" >&2; exit 1; }; done
pids=()
for f in *.c; do
    base=$(basename "$f" .c)
    obj="build_objs/${base}.o"
    if [ ! -f "$obj" ]; then
        x86_64-w64-mingw32-gcc $COMMON -c "$f" -o "$obj" &
        pids+=("$!")
    fi
done
for p in "${pids[@]}"; do wait "$p" || { echo "!! 编译失败 (PID $p)" >&2; exit 1; }; done
mkdir -p "$PREFIX/lib" "$PREFIX/include"
ar rcs "$PREFIX/lib/libgiac_mingw.a" build_objs/*.o
cp -r ../src/*.h "$PREFIX/include/" 2>/dev/null || true
cp giac.h "$PREFIX/include/" 2>/dev/null || true
cp ../COPYING "$PREFIX/" 2>/dev/null || true
echo ">> done: $PREFIX/lib/libgiac_mingw.a ($(du -h "$PREFIX/lib/libgiac_mingw.a" | cut -f1))"
