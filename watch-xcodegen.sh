#!/usr/bin/env bash
#
# Watches UNBOUND source tree for file add/remove/rename and regenerates the
# xcodeproj via xcodegen. Ignores content-only edits (those don't need regen —
# Xcode's incremental build handles them).
#
# Usage:
#   ./watch-xcodegen.sh                      # foreground, logs to stdout
#   nohup ./watch-xcodegen.sh &>/tmp/xcodegen-watch.log &   # background

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/UNBOUND"
SPEC="$ROOT/project.yml"

echo "[watch-xcodegen] watching $SRC and $SPEC"

# --event filter: only structural changes require regen.
# --latency 0.5: debounce multi-file operations (e.g. git checkout, xcodegen itself).
# Exclude the xcodeproj itself so regen doesn't re-trigger.
fswatch \
  --event=Created --event=Removed --event=Renamed --event=MovedFrom --event=MovedTo \
  --latency 0.5 \
  --exclude='\.xcodeproj' \
  --exclude='\.xcworkspace' \
  --exclude='DerivedData' \
  --exclude='\.DS_Store' \
  -r \
  "$SRC" "$SPEC" \
| while read -r path; do
    ts="$(date +%H:%M:%S)"
    echo "[$ts] change: $path"
    if (cd "$ROOT" && xcodegen generate) >/tmp/xcodegen-watch-last.log 2>&1; then
      echo "[$ts] ✅ xcodeproj regenerated"
    else
      echo "[$ts] ❌ xcodegen failed — see /tmp/xcodegen-watch-last.log"
      tail -5 /tmp/xcodegen-watch-last.log
    fi
  done
