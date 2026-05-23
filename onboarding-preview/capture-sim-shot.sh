#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <slug> <title> [note]" >&2
  echo "Example: $0 entry-map 'Entry Map' 'After copy pass'" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$ROOT_DIR/swiftui-screenshots"
SLUG="$1"
TITLE="$2"
NOTE="${3:-Captured from booted simulator}"
FILE="${SLUG}.png"
PATH_OUT="$OUT_DIR/$FILE"

mkdir -p "$OUT_DIR"
xcrun simctl io booted screenshot "$PATH_OUT" >/dev/null

node "$ROOT_DIR/update-manifest.mjs" "$FILE" "$TITLE" "$NOTE"
echo "Saved $PATH_OUT"
