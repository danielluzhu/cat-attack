#!/bin/bash
# Builds CatAttack.app into ./build. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/CatAttack.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/CatAttack "$APP/Contents/MacOS/CatAttack"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# App icon; regenerate with: swift scripts/generate-icon.swift build/AppIcon.iconset
#                            iconutil -c icns -o Resources/AppIcon.icns build/AppIcon.iconset
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signing gives the app a new code identity on every build, so macOS
# stops honouring the Accessibility grant and it has to be re-granted. Set a
# stable signing identity to avoid that:
#   CATATTACK_SIGN_IDENTITY="CatAttack Self Signed" ./scripts/make-app.sh
codesign --force --sign "${CATATTACK_SIGN_IDENTITY:--}" "$APP"

echo "Built $APP"
echo "Run it with: open $APP"
