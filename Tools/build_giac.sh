#!/bin/bash
# 编译 Giac 为 macOS arm64 静态库并安装到 third_party/giac/。
# 用法：Tools/build_giac.sh [版本号，默认 2.1.0]
# 依赖：Homebrew 的 gmp、mpfr、gettext（libintl）。
# 前缀：默认取 $HOMEBREW_PREFIX，其次 `brew --prefix`，再退回 /opt/homebrew（Intel 用 /usr/local）。
# 产物：third_party/giac/lib/libgiac.a + third_party/giac/COPYING（GPLv3）。
# 注意：链接了 libgiac.a 的产物整体受 GPLv3 约束。
set -euo pipefail

VERSION="${1:-2.1.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build-giac"
PREFIX="$ROOT/third_party/giac"
BREW="${HOMEBREW_PREFIX:-$(brew --prefix 2>/dev/null || echo /opt/homebrew)}"
TARBALL="giac-$VERSION.tar.gz"
URL="https://www-fourier.univ-grenoble-alpes.fr/~parisse/giac/$TARBALL"

for dep in gmp mpfr gettext; do
    brew list --versions "$dep" >/dev/null 2>&1 || brew install -q "$dep"
done

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
if [ ! -f config.h ]; then
    CPPFLAGS="-I$BREW/include" \
    LDFLAGS="-L$BREW/lib" \
    CXXFLAGS="-O2 -std=gnu++17" \
    ./configure --disable-shared --enable-static \
        --disable-fltk --disable-gui --disable-ntl --disable-pari \
        --disable-gsl --disable-lapack --disable-ecm --disable-bernmm \
        --disable-glpk --disable-ao --disable-samplerate --disable-curl \
        --disable-micropy --disable-quickjs --disable-nls --disable-png \
        --disable-cocoa --disable-dl
fi
make -C src -j"$(sysctl -n hw.ncpu)" libgiac.la

mkdir -p "$PREFIX/lib"
cp src/.libs/libgiac.a "$PREFIX/lib/"
cp COPYING "$PREFIX/COPYING"
lipo -info "$PREFIX/lib/libgiac.a"
echo "Installed: $PREFIX/lib/libgiac.a"
