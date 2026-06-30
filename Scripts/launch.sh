#!/bin/bash
set -euo pipefail

APP_NAME="ObsidianTodoBar"
CONFIG="${1:-debug}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source .env for the app process
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# Kill existing instance by bundle path
BUNDLE_DIR="/tmp/${APP_NAME}.app"
if [ -d "$BUNDLE_DIR" ]; then
    BUNDLE_PID=$(pgrep -f "$BUNDLE_DIR/Contents/MacOS/$APP_NAME" 2>/dev/null || true)
    if [ -n "$BUNDLE_PID" ]; then
        kill "$BUNDLE_PID" 2>/dev/null || true
        sleep 0.5
    fi
fi

if [ "$CONFIG" = "release" ]; then
    swift build -c release
    BUILD_DIR="$PROJECT_DIR/.build/release"
else
    swift build
    BUILD_DIR="$PROJECT_DIR/.build/debug"
fi

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"

cp "$BUILD_DIR/$APP_NAME" "$BUNDLE_DIR/Contents/MacOS/$APP_NAME"

cat > "$BUNDLE_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.evgenykon.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Launching $APP_NAME..."

# Register bundle with Launch Services (needed for Notification Center)
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$BUNDLE_DIR" 2>/dev/null || true

"$BUNDLE_DIR/Contents/MacOS/$APP_NAME" &
disown
