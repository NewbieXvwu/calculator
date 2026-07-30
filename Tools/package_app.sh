#!/bin/bash
# 把 SPM/xcodebuild 的 Release 产物包装为标准 MacCalculator.app 并产出 DMG。
# 用法：Tools/package_app.sh <Release产物目录> <输出dmg路径> [版本号，默认 0.1.0]
# DMG 而非直接上传 .app：actions/upload-artifact 会丢执行权限，DMG 完整保留。
set -euo pipefail

PRODUCTS="$1"
OUT_DMG="$2"
VERSION="${3:-0.1.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"

# 从 xcstrings 派生实际发行的语言列表，写入 CFBundleLocalizations，
# 让 AppKit 系统菜单与资源包都随系统语言切换（否则始终回落到开发区域 en）。
LOCALIZATIONS_XML="$(python3 - "$ROOT/src/MacApp/Resources/Localizable.xcstrings" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding="utf-8"))
langs=set()
for v in d["strings"].values():
    langs.update(v.get("localizations",{}).keys())
print("".join(f"        <string>{l}</string>\n" for l in sorted(langs)).rstrip("\n"))
PY
)"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

APP="$STAGING/MacCalculator.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$PRODUCTS/MacCalculator" "$APP/Contents/MacOS/"
cp -R "$PRODUCTS"/MacCalculator_*.bundle "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleAllowMixedLocalizations</key>
    <true/>
    <key>CFBundleLocalizations</key>
    <array>
$LOCALIZATIONS_XML
    </array>
    <key>CFBundleExecutable</key>
    <string>MacCalculator</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.newbiexvwu.calculator</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MacCalculator</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# ad-hoc 签名：无开发者证书也能在 Apple Silicon 上直接运行（仍会触发 Gatekeeper 未公证提示）。
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"

# 静态链 giac → 整体 GPLv3，许可证随 DMG 分发。
cp "$ROOT/third_party/giac/COPYING" "$STAGING/COPYING.GPLv3"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname MacCalculator -srcfolder "$STAGING" -ov -format UDZO "$OUT_DMG"
echo "Packaged: $OUT_DMG"
