#!/bin/bash
# 编译 Giac 为 macOS arm64 静态库并安装到 third_party/giac/。
# 用法：Tools/build_giac.sh [版本号，默认 2.1.0] [--disable-giac-XXX ...]
#   版本号之后的参数原样透传给 ./configure（如 --disable-giac-ti89 --disable-giac-maple）。
# 依赖：Homebrew 的 gmp、mpfr、gettext（libintl）+ autoconf/automake（应用补丁后重新生成 configure）。
# 前缀：默认取 $HOMEBREW_PREFIX，其次 `brew --prefix`，再退回 /opt/homebrew（Intel 用 /usr/local）。
# 补丁：解包后自动应用 Tools/giac-patches/（configure.ac / src/Makefile.am / src/giac_stubs.cc），
#   提供 --disable-giac-* 模块裁剪体系（15 个模块组，默认全部启用 = 官方等价行为）。
# 产物：third_party/giac/lib/libgiac.a + third_party/giac/COPYING（GPLv3）。
# 注意：链接了 libgiac.a 的产物整体受 GPLv3 约束。
set -euo pipefail

VERSION="${1:-2.1.0}"
shift 2>/dev/null || true
MODULE_ARGS=("$@")
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build-giac"
PATCHES="$ROOT/Tools/giac-patches"
PREFIX="$ROOT/third_party/giac"
BREW="${HOMEBREW_PREFIX:-$(brew --prefix 2>/dev/null || echo /opt/homebrew)}"
TARBALL="giac-$VERSION.tar.gz"
URL="https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac/$TARBALL"

for dep in gmp mpfr gettext; do
    brew list --versions "$dep" >/dev/null 2>&1 || brew install -q "$dep"
done
if ! command -v autoreconf >/dev/null; then
    brew install -q autoconf automake
fi

mkdir -p "$BUILD"
cd "$BUILD"
if ! tar tzf "$TARBALL" >/dev/null 2>&1; then
    # 官方服务器常中断连接，循环续传直到完整。
    for _ in $(seq 1 20); do
        curl -sL -C - --max-time 540 -o "$TARBALL" "$URL" && break || true
    done
    tar tzf "$TARBALL" >/dev/null
fi
[ -d "giac-$VERSION" ] || tar xzf "$TARBALL"

cd "giac-$VERSION"

# ── 应用 calculator fork 补丁：模块裁剪体系（configure.ac / src/Makefile.am / giac_stubs.cc）──
# configure.ac 被修改后必须 autoreconf 重新生成 configure/Makefile.in。
NEED_RECONF=0
for f in configure.ac src/Makefile.am src/giac_stubs.cc; do
    if ! cmp -s "$PATCHES/$f" "$f"; then
        cp "$PATCHES/$f" "$f"
        NEED_RECONF=1
    fi
done
if [ "$NEED_RECONF" = 1 ] || [ ! -x configure ] || ! grep -q "disable-giac" configure; then
    autoreconf -fi >/dev/null
fi

# ── 应用核心源码修复补丁（core-fixes.patch：usual/gausspol/sym2poly/gen 的
#    崩溃与超时缺陷修复，见 Tools/giac-patches/DIFF_REPORT 与 docs/giac-attack-review.md）──
if [ -f "$PATCHES/core-fixes.patch" ] && ! grep -q "attack review" src/gen.cc; then
    patch -p1 --forward < "$PATCHES/core-fixes.patch" >/dev/null 2>&1 || \
        { echo "!! core-fixes.patch 应用失败" >&2; exit 1; }
fi

if [ ! -f config.h ] || [ "${#MODULE_ARGS[@]}" -gt 0 ] || [ ! -f .config-args ] || ! grep -qxF "${MODULE_ARGS[*]}" .config-args; then
    # -O3 依官方 API 文档 1.4「full speed binaries」建议（原文另有 -fexpensive-optimizations
    # 与 -malign-*，均为古老 GCC/x86 专属标志，clang/arm64 不适用，予以省略）。
    # -DGIAC_GENERIC_CONSTANTS 必须：否则 cst_i 等 alias 常量在 arm64 上损坏（实测
    # arg(1+i) 输出 atan(65536) 并卡死），见 Tools/giac-patches/DIFF_REPORT.md。
    # 模块裁剪选项（--disable-giac-*）透传：默认全部启用 = 官方等价行为。
    # .config-args 记录本次模块参数：参数变化（含去掉参数恢复全模块）时强制重新 configure。
    CPPFLAGS="-I$BREW/include" \
    LDFLAGS="-L$BREW/lib" \
    CXXFLAGS="-O3 -std=gnu++17 -DGIAC_GENERIC_CONSTANTS -DTIMEOUT -DUSE_OBJET_BIDON -U_GLIBCXX_ASSERTIONS" \
    ./configure --disable-shared --enable-static \
        --disable-fltk --disable-gui --disable-ntl --disable-pari \
        --disable-gsl --disable-lapack --disable-ecm --disable-bernmm \
        --disable-glpk --disable-ao --disable-samplerate --disable-curl \
        --disable-micropy --disable-quickjs --disable-nls --disable-png \
        --disable-cocoa --disable-dl \
        "${MODULE_ARGS[@]}"
    printf '%s\n' "${MODULE_ARGS[*]}" > .config-args
fi
make -C src -j"$(sysctl -n hw.ncpu)" libgiac.la

mkdir -p "$PREFIX/lib"
cp src/.libs/libgiac.a "$PREFIX/lib/"
cp COPYING "$PREFIX/COPYING"
lipo -info "$PREFIX/lib/libgiac.a"
echo "Installed: $PREFIX/lib/libgiac.a"
echo "模块状态: $(grep -c '^#define GIAC_NO_' config.h 2>/dev/null || echo 0) 个模块被裁剪（0 = 全部启用）"
