#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

APP_DIR="$HOME/Applications"
BIN_DIR="$HOME/.local/bin"

./Scripts/build-app.sh
swift build -c release --product utodo --scratch-path .build-app

mkdir -p "$APP_DIR" "$BIN_DIR"
pkill -f "$APP_DIR/UTodo.app/Contents/MacOS/UTodo" 2>/dev/null || true
rm -rf "$APP_DIR/UTodo.app"
cp -R build/UTodo.app "$APP_DIR/UTodo.app"
cp .build-app/release/utodo "$BIN_DIR/utodo"
chmod +x "$BIN_DIR/utodo"

echo "App:  $APP_DIR/UTodo.app"
echo "CLI:  $BIN_DIR/utodo"
echo
echo "如果 $BIN_DIR 还不在 PATH 里，把这行加进 ~/.zshrc："
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo
echo "想让你的 AI 记住怎么用 utodo："
echo "  utodo agent install     # 往 ~/AGENTS.md 追加一段说明，幂等，可 uninstall"
echo

open "$APP_DIR/UTodo.app"
