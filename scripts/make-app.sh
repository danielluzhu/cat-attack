#!/bin/bash
# Builds CatAttack.app into ./build. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/CatAttack.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/CatAttack "$APP/Contents/MacOS/CatAttack"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so macOS remembers the Accessibility grant across rebuilds.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with: open $APP"
