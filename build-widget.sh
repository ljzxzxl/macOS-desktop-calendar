#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SDK_PATH="$(xcrun --show-sdk-path)"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/DesktopCalendar.app"
APP_CONTENTS="$APP_DIR/Contents"
APP_EXECUTABLE="$APP_CONTENTS/MacOS/DesktopCalendar"
EXTENSION_DIR="$APP_CONTENTS/PlugIns/DesktopCalendarWidget.appex"
EXTENSION_EXECUTABLE="$EXTENSION_DIR/Contents/MacOS/DesktopCalendarWidget"

rm -rf "$APP_DIR"
mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources" "$EXTENSION_DIR/Contents/MacOS" "$EXTENSION_DIR/Contents/Resources"

swiftc \
    -parse-as-library \
    -target arm64-apple-macosx14.0 \
    -sdk "$SDK_PATH" \
    -framework AppKit \
    -framework WidgetKit \
    "$PROJECT_DIR/Sources/WidgetHostMain.swift" \
    -o "$APP_EXECUTABLE"

swiftc \
    -parse-as-library \
    -target arm64-apple-macosx14.0 \
    -sdk "$SDK_PATH" \
    -framework SwiftUI \
    -framework WidgetKit \
    "$PROJECT_DIR/Sources/CalendarWidget.swift" \
    "$PROJECT_DIR/Sources/CalendarData.swift" \
    -o "$EXTENSION_EXECUTABLE"

cp "$PROJECT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
cp "$PROJECT_DIR/Resources/WidgetInfo.plist" "$EXTENSION_DIR/Contents/Info.plist"

codesign \
    --force \
    --sign - \
    --entitlements "$PROJECT_DIR/Resources/Widget.entitlements" \
    "$EXTENSION_DIR"

codesign \
    --force \
    --sign - \
    --entitlements "$PROJECT_DIR/Resources/Host.entitlements" \
    "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
