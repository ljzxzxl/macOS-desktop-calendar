#!/bin/zsh
# 构建通用架构（Apple 芯片 + Intel）的 Release 版本，并打包成可发布到 GitHub Releases 的 DMG。
# 用法：DEVELOPMENT_TEAM=<Team ID> scripts/package-release.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
TEAM="${DEVELOPMENT_TEAM:-9BJB6S9V28}"
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
DERIVED="build/release/DerivedData"
APP="$DERIVED/Build/Products/Release/DesktopCalendar.app"
APPEX="$APP/Contents/PlugIns/DesktopCalendarWidget.appex"
STAGING="build/release/dmg"
DMG="build/release/DesktopCalendar-$VERSION.dmg"

echo "==> 构建 DesktopCalendar $VERSION"
rm -rf "$DERIVED"
xcodebuild -project DesktopCalendar.xcodeproj -scheme DesktopCalendar -configuration Release \
    -derivedDataPath "$DERIVED" DEVELOPMENT_TEAM="$TEAM" ONLY_ACTIVE_ARCH=NO \
    -allowProvisioningUpdates build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" || true
[ -d "$APPEX" ] || { echo "构建失败"; exit 1; }

# 构建产物会被自动注册到 LaunchServices，残留注册会干扰本机已安装的组件。
pluginkit -r "$APPEX" 2>/dev/null || true
"$LSR" -u "$APP" 2>/dev/null || true

echo "==> 校验签名与架构"
codesign --verify --deep --strict "$APP"
for binary in "$APP/Contents/MacOS/DesktopCalendar" "$APPEX/Contents/MacOS/DesktopCalendarWidget"; do
    archs=$(lipo -archs "$binary")
    [[ "$archs" == *arm64* && "$archs" == *x86_64* ]] || { echo "$binary 不是通用架构：$archs"; exit 1; }
done

echo "==> 打包 DMG"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/DesktopCalendar.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "DesktopCalendar $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGING"
# 构建产物即使注销过也可能被系统重新登记为组件来源，打包后直接删除。
rm -rf "$APP"

echo "==> 完成"
echo "$DMG"
shasum -a 256 "$DMG"
