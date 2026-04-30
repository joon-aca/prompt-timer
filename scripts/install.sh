#!/bin/zsh
set -euo pipefail

APP_NAME="Prompt Timer"
BUNDLE_ID="com.joon.prompttimer"
BUILD_DIR="build/Release"
INSTALL_DIR="/Applications"
CLI_LINK="/usr/local/bin/timer"
APP_PATH="${INSTALL_DIR}/${APP_NAME}.app"
BUILT_APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
APP_CLI_PATH="${APP_PATH}/Contents/Resources/timer"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

# Build
echo "Building ${APP_NAME}..."
rm -rf "$BUILD_DIR" build/XCBuildData
xcodebuild -project PromptTimer.xcodeproj \
    -target PromptTimerPersonal \
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

if [[ ! -d "$APP_PATH" ]]; then
    echo "Install failed: ${APP_PATH} was not created." >&2
    exit 1
fi

if [[ ! -x "$APP_CLI_PATH" ]]; then
    echo "Install failed: embedded CLI missing or not executable at ${APP_CLI_PATH}" >&2
    exit 1
fi

echo "Signing installed app..."
if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "Using signing identity: ${SIGN_IDENTITY}"
    SIGN_TIMESTAMP_ARGS=(--timestamp)
    SIGNING_IDENTITY="$SIGN_IDENTITY"
else
    echo "No SIGN_IDENTITY set, using ad-hoc signing for a consistent local bundle"
    SIGN_TIMESTAMP_ARGS=()
    SIGNING_IDENTITY="-"
fi

find "${APP_PATH}/Contents/Frameworks" -name "*.framework" | while read -r fw; do
    codesign --force --sign "$SIGNING_IDENTITY" \
        --options runtime \
        "${SIGN_TIMESTAMP_ARGS[@]}" \
        "$fw"
done
codesign --force --sign "$SIGNING_IDENTITY" \
    --options runtime \
    "${SIGN_TIMESTAMP_ARGS[@]}" \
    --entitlements Config/timer.entitlements \
    "$APP_CLI_PATH"
codesign --force --sign "$SIGNING_IDENTITY" \
    --options runtime \
    "${SIGN_TIMESTAMP_ARGS[@]}" \
    --entitlements Config/PromptTimerPersonal.entitlements \
    "$APP_PATH"

echo "Verifying code signature..."
codesign --verify --deep --strict "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH" || true

# Symlink CLI
echo "Linking CLI to ${CLI_LINK}..."
if [[ "$(readlink "$CLI_LINK" 2>/dev/null || true)" == "$APP_CLI_PATH" ]]; then
    echo "CLI link already points to installed app."
elif [[ ! -d "$(dirname "$CLI_LINK")" ]]; then
    sudo mkdir -p "$(dirname "$CLI_LINK")"
    sudo ln -sf "$APP_CLI_PATH" "$CLI_LINK"
else
    sudo ln -sf "$APP_CLI_PATH" "$CLI_LINK"
fi

if [[ ! -x "$CLI_LINK" ]]; then
    echo "Install failed: ${CLI_LINK} does not resolve to an executable." >&2
    exit 1
fi

if ! command -v timer >/dev/null 2>&1; then
    echo "Warning: ${CLI_LINK} exists, but 'timer' is not on this shell's PATH." >&2
    echo "Add /usr/local/bin to PATH or invoke ${CLI_LINK} directly." >&2
fi

# Launch
echo "Launching ${APP_NAME}..."
open "$APP_PATH"

echo ""
echo "Done! CLI available at: ${CLI_LINK}"
echo "Try: timer 5 tea"
