#!/bin/bash
set -euo pipefail
export UTODO_DB="$(mktemp -t utodo-smoke).sqlite3"
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
$BIN --help >/dev/null 2>&1; [ $? -eq 2 ] || exit 1
set -e

$BIN clear | grep -q "已清除 1"
echo "cli-smoke OK"
