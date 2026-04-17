#!/bin/zsh
set -euo pipefail

APP_NAME="Prompt Timer"
BUNDLE_ID="com.joon.prompttimer"
BUILD_DIR="build/Release"
DIST_DIR="dist"

# Signing config — set these or export them in your environment
SIGN_IDENTITY="${SIGN_IDENTITY:-}"        # e.g. "Developer ID Application: ACA (TEAMID)"
NOTARIZE_APPLE_ID="${NOTARIZE_APPLE_ID:-}"  # e.g. you@email.com
NOTARIZE_TEAM_ID="${NOTARIZE_TEAM_ID:-}"    # e.g. ABC123DEF4
NOTARIZE_PASSWORD="${NOTARIZE_PASSWORD:-}"  # app-specific password, or use NOTARIZE_KEYCHAIN_PROFILE
NOTARIZE_KEYCHAIN_PROFILE="${NOTARIZE_KEYCHAIN_PROFILE:-}"  # set via: xcrun notarytool store-credentials

# Build first so we can read the version from the built app
echo "Building ${APP_NAME}..."
rm -rf "$BUILD_DIR" build/XCBuildData
xcodebuild -project PromptTimer.xcodeproj \
    -target PromptTimerApp \
    -configuration Release \
    CONFIGURATION_BUILD_DIR="$(pwd)/$BUILD_DIR" \
    clean build -quiet

VERSION=$(defaults read "$(pwd)/${BUILD_DIR}/${APP_NAME}.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0")
DMG_NAME="PromptTimer-${VERSION}.dmg"
STAGING_DIR="$(mktemp -d)/dmg-staging"

echo "Version: ${VERSION}"

# Sign
if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "Signing with Developer ID..."
    # Sign frameworks first
    find "${BUILD_DIR}/${APP_NAME}.app/Contents/Frameworks" -name "*.framework" | while read fw; do
        codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$fw"
    done
    # Sign the CLI binary explicitly with its own entitlements
    codesign --force --sign "$SIGN_IDENTITY" \
        --options runtime \
        --timestamp \
        --entitlements Config/timer.entitlements \
        "${BUILD_DIR}/${APP_NAME}.app/Contents/Resources/timer"
    # Sign the app bundle
    codesign --force --sign "$SIGN_IDENTITY" \
        --options runtime \
        --timestamp \
        --entitlements Config/PromptTimerApp.entitlements \
        "${BUILD_DIR}/${APP_NAME}.app"
else
    echo "No SIGN_IDENTITY set — using ad-hoc signing (not suitable for distribution)"
    codesign --force --deep --sign - "${BUILD_DIR}/${APP_NAME}.app"
fi

# Stage
echo "Staging DMG..."
mkdir -p "$STAGING_DIR"
cp -R "${BUILD_DIR}/${APP_NAME}.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
mkdir -p "$DIST_DIR"
echo "Creating DMG..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "${DIST_DIR}/${DMG_NAME}"

rm -rf "$(dirname "$STAGING_DIR")"

# Notarize
if [[ -n "$SIGN_IDENTITY" && ( -n "$NOTARIZE_KEYCHAIN_PROFILE" || -n "$NOTARIZE_APPLE_ID" ) ]]; then
    echo "Submitting for notarization..."
    if [[ -n "$NOTARIZE_KEYCHAIN_PROFILE" ]]; then
        xcrun notarytool submit "${DIST_DIR}/${DMG_NAME}" \
            --keychain-profile "$NOTARIZE_KEYCHAIN_PROFILE" \
            --wait
    else
        xcrun notarytool submit "${DIST_DIR}/${DMG_NAME}" \
            --apple-id "$NOTARIZE_APPLE_ID" \
            --team-id "$NOTARIZE_TEAM_ID" \
            --password "$NOTARIZE_PASSWORD" \
            --wait
    fi

    echo "Stapling notarization ticket..."
    xcrun stapler staple "${DIST_DIR}/${DMG_NAME}"
else
    echo "Skipping notarization (NOTARIZE_APPLE_ID not set)"
fi

SHA=$(shasum -a 256 "${DIST_DIR}/${DMG_NAME}" | awk '{print $1}')
echo ""
echo "Done: ${DIST_DIR}/${DMG_NAME}"
echo "SHA256: ${SHA}"
echo ""
echo "Update your Homebrew cask with:"
echo "  version \"${VERSION}\""
echo "  sha256 \"${SHA}\""
