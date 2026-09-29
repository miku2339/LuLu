#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LuLuInterfacePreview"
APP_BUNDLE="$ROOT_DIR/outputs/LuLu Interface Preview.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

case "$MODE" in
    run|--verify|--build|--debug|--english) ;;
    *) echo "Usage: $0 [--build|--verify|--debug|--english]" >&2; exit 2 ;;
esac

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
xcrun clang -fobjc-arc -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=11.0 \
    -framework Cocoa "$ROOT_DIR/Preview/main.m" "$ROOT_DIR/Preview/PreviewController.m" \
    "$ROOT_DIR/Preview/PreviewModel.m" -o "$APP_BINARY"
cp "$ROOT_DIR/LICENSE.md" "$APP_BUNDLE/Contents/Resources/LICENSE.md"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LuLuInterfacePreview</string>
<key>CFBundleIdentifier</key><string>org.local.lulu.interface-preview</string>
<key>CFBundleName</key><string>LuLu Interface Preview</string>
<key>CFBundleDisplayName</key><string>LuLu Interface Preview</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>11.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Unofficial interface preview. GPL-3.0. LuLu by Objective-See.</string>
</dict></plist>
PLIST

case "$MODE" in
    --build) printf '%s\n' "$APP_BUNDLE" ;;
    --debug) lldb -- "$APP_BINARY" ;;
    --english) /usr/bin/open -n "$APP_BUNDLE" --args --english ;;
    --verify)
        /usr/bin/open -n "$APP_BUNDLE"
        sleep 1
        pgrep -x "$APP_NAME" >/dev/null
        printf 'Built and running: %s\n' "$APP_BUNDLE"
        ;;
    *) /usr/bin/open -n "$APP_BUNDLE" ;;
esac
