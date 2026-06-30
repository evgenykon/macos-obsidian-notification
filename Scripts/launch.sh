#!/bin/bash
set -euo pipefail

APP_NAME="ObsidianTodoBar"
CONFIG="${1:-debug}"
BUNDLE_ID="com.evgenykon.${APP_NAME}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source .env and write to UserDefaults for the app
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a

    # Populate UserDefaults so app works when launched via open (no env vars)
    defaults write "$BUNDLE_ID" vaultPath "${OBSIDIAN_VAULT_PATH:-}" 2>/dev/null || true
    defaults write "$BUNDLE_ID" tasksFolder "${TASKS_FOLDER:-Inbox/tasks}" 2>/dev/null || true
    defaults write "$BUNDLE_ID" promptFile "${PROMPT_FILE:-Inbox/tasks/_prompt_task.md}" 2>/dev/null || true
    defaults write "$BUNDLE_ID" historyFilePattern "${HISTORY_FILE_PATTERN:-Inbox/tasks/history-{date}.md}" 2>/dev/null || true
    defaults write "$BUNDLE_ID" apiKey "${OPENROUTER_API_KEY:-}" 2>/dev/null || true
    defaults write "$BUNDLE_ID" model "${AI_MODEL:-openai/gpt-4o-mini}" 2>/dev/null || true
    defaults write "$BUNDLE_ID" baseURL "${AI_BASE_URL:-https://openrouter.ai/api/v1}" 2>/dev/null || true
    defaults write "$BUNDLE_ID" checkInterval "${CHECK_INTERVAL:-30}" 2>/dev/null || true
    defaults write "$BUNDLE_ID" notificationsStartHour "${NOTIFICATIONS_START_HOUR:-9}" 2>/dev/null || true
    defaults write "$BUNDLE_ID" notificationsEndHour "${NOTIFICATIONS_END_HOUR:-18}" 2>/dev/null || true
fi

BUNDLE_DIR="/tmp/${APP_NAME}.app"

# Kill existing instance
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
    <string>${BUNDLE_ID}</string>
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

# open registers the bundle with Launch Services so it appears in System Settings → Notifications
open "$BUNDLE_DIR"
