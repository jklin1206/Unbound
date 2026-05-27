#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-UNBOUND/UNBOUND}"

run_section() {
  local title="$1"
  shift

  printf '\n## %s\n' "$title"
  "$@" || true
}

run_section "SwiftUI literal entry points" \
  rg -n 'Text\("[^"]*[A-Za-z][^"]*"\)|Button\("[^"]*[A-Za-z][^"]*"|Label\("[^"]*[A-Za-z][^"]*"|navigationTitle\("[^"]*[A-Za-z][^"]*"\)|Picker\("[^"]*[A-Za-z][^"]*"' \
    "$ROOT/Views" --glob '*.swift'

run_section "Model and service display copy" \
  rg -n 'return "[^"]*[A-Za-z][^"]*"|title: "[^"]*[A-Za-z][^"]*"|body: "[^"]*[A-Za-z][^"]*"|description: "[^"]*[A-Za-z][^"]*"' \
    "$ROOT/Models" "$ROOT/Services" --glob '*.swift'

run_section "Manual date and number formatting" \
  rg -n 'String\(format:|DateFormatter\(|NumberFormatter\(|MeasurementFormatter\(|dateFormat' \
    "$ROOT" --glob '*.swift'
