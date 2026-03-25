#!/bin/zsh
set -euo pipefail

APP_NAME="Prompt Timer"
BUNDLE_ID="com.joon.prompttimer"
BUILD_DIR=".deriveddata/Build/Products/Release"
INSTALL_DIR="/Applications"
CLI_LINK="/usr/local/bin/timer"

# Build
echo "Building ${APP_NAME}..."
xcodebuild -project PromptTimer.xcodeproj \
    -target PromptTimerApp \
    -configuration Release \
    BUILD_DIR="$BUILD_DIR" \
    build -quiet

# Quit running instance
if pgrep -x "$APP_NAME" > /dev/null 2>&1; then
    echo "Stopping running instance..."
    pkill -x "$APP_NAME"
    sleep 1
fi

# Install app
echo "Installing to ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
cp -R "${BUILD_DIR}/${APP_NAME}.app" "${INSTALL_DIR}/${APP_NAME}.app"
codesign --force --deep --sign - "${INSTALL_DIR}/${APP_NAME}.app"

# Symlink CLI
echo "Linking CLI to ${CLI_LINK}..."
if [[ ! -d "$(dirname "$CLI_LINK")" ]]; then
    sudo mkdir -p "$(dirname "$CLI_LINK")"
fi
sudo ln -sf "${INSTALL_DIR}/${APP_NAME}.app/Contents/Resources/timer" "$CLI_LINK"

# Launch
echo "Launching ${APP_NAME}..."
open "${INSTALL_DIR}/${APP_NAME}.app"

echo ""
echo "Done! CLI available at: ${CLI_LINK}"
echo "Try: timer 5 tea"
