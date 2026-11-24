#!/bin/bash
set -euo pipefail
export UTODO_DB="$(mktemp -t utodo-smoke).sqlite3"
export UTODO_CONFIG="$(mktemp -t utodo-smoke).json"
export HOME="$(mktemp -d -t utodo-home)"
BIN="${1:-.build/debug/utodo}"
py() { /usr/bin/python3 -c "$1"; }

$BIN add "回 Alice 邮件"
$BIN add "" || true
[ "$($BIN list | wc -l | tr -d ' ')" = "1" ]

printf '甲\n乙\n' | $BIN add -
[ "$($BIN list --json | py 'import json,sys; print(json.load(sys.stdin)[0]["title"])')" = "甲" ]

JSON_ONE=$($BIN add --json "带 json 的一条")
[ "$(printf '%s' "$JSON_ONE" | py 'import json,sys; print(json.load(sys.stdin)["title"])')" = "带 json 的一条" ]
set +e; $BIN add --bogus 标题 >/dev/null 2>&1; [ $? -eq 2 ] || exit 1; set -e

ID=$($BIN list --json | py 'import json,sys; print(json.load(sys.stdin)[0]["id"][:8])')
$BIN done "$ID"
$BIN done "$ID"
[ "$($BIN list --json | py 'import json,sys; print(len(json.load(sys.stdin)))')" = "3" ]

set +e
$BIN done ffffffff >/dev/null 2>&1; [ $? -eq 1 ] || exit 1
$BIN --help >/dev/null 2>&1; [ $? -eq 0 ] || exit 1
$BIN >/dev/null 2>&1; [ $? -eq 0 ] || exit 1
$BIN config set glass 1.5 >/dev/null 2>&1; [ $? -eq 2 ] || exit 1
$BIN config set foo 1 >/dev/null 2>&1; [ $? -eq 2 ] || exit 1
set -e

# 透明度：默认值 → 改 → 读回；越界不落盘
[ "$($BIN config --json)" = '{"glassOpacity":0.3,"dimAlpha":0.55}' ]
$BIN config set glass 0.5 | grep -q "0.3 → 0.5"
[ "$($BIN config get glass)" = "0.5" ]
[ "$($BIN config --json)" = '{"glassOpacity":0.5,"dimAlpha":0.55}' ]
$BIN config set dim 0.35 >/dev/null
set +e; $BIN config set dim 0 >/dev/null 2>&1; [ $? -eq 2 ] || exit 1; set -e
[ "$($BIN config get dim)" = "0.35" ]

# agent：装、幂等、可卸载；不碰真实的 HOME
$BIN agent install | grep -q "AGENTS.md"
[ -f "$HOME/AGENTS.md" ]
[ -f "$HOME/.local/share/utodo/SKILL.md" ]
$BIN agent install | grep -q "已是新内容"
[ "$(grep -c 'utodo:begin' "$HOME/AGENTS.md")" = "1" ]
$BIN agent uninstall >/dev/null
[ ! -s "$HOME/AGENTS.md" ]
[ ! -e "$HOME/.local/share/utodo/SKILL.md" ]

$BIN clear | grep -q "已清除 1"
echo "cli-smoke OK"
