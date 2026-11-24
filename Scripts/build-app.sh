#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

APP="build/UTodo.app"

swift build -c release --product UTodo

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/UTodo "$APP/Contents/MacOS/UTodo"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --identifier com.azerostart.utodo "$APP" 2>/dev/null

echo "built $APP"
