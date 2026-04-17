#!/bin/zsh
set -euo pipefail

APP_NAME="Prompt Timer"
BUNDLE_ID="com.joon.prompttimer"
BUILD_DIR="build/Release"
INSTALL_DIR="/Applications"
CLI_LINK="/usr/local/bin/timer"
APP_PATH="${INSTALL_DIR}/${APP_NAME}.app"
BUILT_APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

# Build
echo "Building ${APP_NAME}..."
rm -rf "$BUILD_DIR" build/XCBuildData
xcodebuild -project PromptTimer.xcodeproj \
    -target PromptTimerApp \
    -configuration Release \
    CONFIGURATION_BUILD_DIR="$(pwd)/$BUILD_DIR" \
    clean build -quiet

# Quit running instance
if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
    echo "Stopping running instance..."
    pkill -x "$APP_NAME"
    sleep 1
fi

# Install app
echo "Installing to ${INSTALL_DIR}..."
rm -rf "$APP_PATH"
ditto "$BUILT_APP_PATH" "$APP_PATH"

echo "Signing installed app..."
if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "Using signing identity: ${SIGN_IDENTITY}"
    find "${APP_PATH}/Contents/Frameworks" -name "*.framework" | while read -r fw; do
        codesign --force --sign "$SIGN_IDENTITY" --timestamp "$fw"
    done
    codesign --force --sign "$SIGN_IDENTITY" \
        --entitlements Config/timer.entitlements \
        "${APP_PATH}/Contents/Resources/timer"
    codesign --force --sign "$SIGN_IDENTITY" \
        --entitlements Config/PromptTimerApp.entitlements \
        "$APP_PATH"
else
    echo "No SIGN_IDENTITY set, using ad-hoc signing for a consistent local bundle"
    codesign --force --deep --sign - "$APP_PATH"
fi

echo "Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH" || true

# Symlink CLI
echo "Linking CLI to ${CLI_LINK}..."
if [[ ! -d "$(dirname "$CLI_LINK")" ]]; then
    sudo mkdir -p "$(dirname "$CLI_LINK")"
fi
sudo ln -sf "${APP_PATH}/Contents/Resources/timer" "$CLI_LINK"

# Launch
echo "Launching ${APP_NAME}..."
open "$APP_PATH"

echo ""
echo "Done! CLI available at: ${CLI_LINK}"
echo "Try: timer 5 tea"
