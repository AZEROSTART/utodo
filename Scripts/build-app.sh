#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

APP="build/UTodo.app"
SCRATCH=".build-app"

swift build -c release --product UTodoApp --scratch-path "$SCRATCH"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$SCRATCH/release/UTodoApp" "$APP/Contents/MacOS/UTodo"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --identifier com.azerostart.utodo "$APP" 2>/dev/null

echo "built $APP"
