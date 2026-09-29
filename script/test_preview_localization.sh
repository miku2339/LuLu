#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/work"
mkdir -p "$WORK_DIR"
TEST_ROOT="$(mktemp -d "$WORK_DIR/preview-localization-tests.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM

APP_BUNDLE="$TEST_ROOT/PreviewLocalizationTests.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
TEST_BINARY="$MACOS_DIR/PreviewLocalizationTests"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

xcrun clang -fobjc-arc -Wall -Wextra -Werror -mmacosx-version-min=11.0 \
    -framework Cocoa -I "$ROOT_DIR/Preview" \
    "$ROOT_DIR/Preview/PreviewLocalizationTests.m" "$ROOT_DIR/Preview/PreviewLocalization.m" \
    -o "$TEST_BINARY"

cp -R "$ROOT_DIR"/Preview/Resources/*.lproj "$RESOURCES_DIR/"
cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PreviewLocalizationTests</string>
<key>CFBundleIdentifier</key><string>org.local.lulu.preview-localization-tests</string>
<key>CFBundleName</key><string>PreviewLocalizationTests</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
</dict></plist>
PLIST

PREVIEW_SOURCE_ROOT="$ROOT_DIR/Preview" "$TEST_BINARY"
