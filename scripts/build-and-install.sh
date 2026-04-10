#!/usr/bin/env bash
set -euo pipefail

# Required environment variables (set in shell or pass on command line):
#   APPLE_ID            — Apple ID email
#   APPLE_TEAM_ID       — 10-character team ID from developer.apple.com
#   APPLE_APP_PASSWORD  — app-specific password for notarytool
# Optional:
#   SKIP_NOTARIZE=1     — build and sign only, skip notarization and staple

APPLE_ID="${APPLE_ID:?set APPLE_ID}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:?set APPLE_TEAM_ID}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/Leo.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_NAME="Leo.app"
APP_PATH="$EXPORT_PATH/$APP_NAME"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Regenerating Xcode project"
cd "$ROOT"
xcodegen generate

echo "==> Archiving"
xcodebuild archive \
    -scheme Leo \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
    -quiet

echo "==> Exporting signed .app"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$ROOT/scripts/ExportOptions.plist" \
    -quiet

if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
    APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:?set APPLE_APP_PASSWORD}"

    echo "==> Zipping for notarization"
    ZIP_PATH="$BUILD_DIR/Leo.zip"
    /usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

    echo "==> Submitting to notarytool (this takes a few minutes)"
    xcrun notarytool submit "$ZIP_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --wait

    echo "==> Stapling ticket"
    xcrun stapler staple "$APP_PATH"
fi

echo "==> Installing to /Applications"
if [[ -d "/Applications/$APP_NAME" ]]; then
    rm -rf "/Applications/$APP_NAME"
fi
cp -R "$APP_PATH" "/Applications/$APP_NAME"

echo "==> Done. Launch with: open /Applications/$APP_NAME"
