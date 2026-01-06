#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="${1:-/tmp/CORTEX_SMOKE}"

rm -rf "$ROOT"
"$DIR/bin/cortex" init "$ROOT" --title "Smoke" >/dev/null

ID1="$("$DIR/bin/cortex" --root "$ROOT" node new --title "Alpha")"
ID2="$("$DIR/bin/cortex" --root "$ROOT" node new --title "Beta")"

"$DIR/bin/cortex" --root "$ROOT" index show nodes | grep -q "$ID1"
"$DIR/bin/cortex" --root "$ROOT" index show nodes | grep -q "$ID2"

printf "\nSee: (%s/README.md)\n" "$ID2" >> "$ROOT/$ID1/README.md"
"$DIR/bin/cortex" --root "$ROOT" node touch "$ID1" >/dev/null
"$DIR/bin/cortex" --root "$ROOT" index show links | grep -q "$ID1"$'\t'"$ID2"

echo "hello" > /tmp/cortex_asset.txt
"$DIR/bin/cortex" --root "$ROOT" asset attach "$ID1" /tmp/cortex_asset.txt >/dev/null
"$DIR/bin/cortex" --root "$ROOT" index show assets | grep -q "$ID1"$'\t'"assets/cortex_asset.txt"

"$DIR/bin/cortex" --root "$ROOT" validate
