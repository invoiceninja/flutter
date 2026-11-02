#!/usr/bin/env bash
# Builds and runs tools/widget_snapshot_contract.swift — the Swift half of the
# home-screen widgets' contract test (docs/home-screen-widgets.md). macOS only.
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# Top-level code compiles only from a file named main.swift.
cp tools/widget_snapshot_contract.swift "$work/main.swift"
swiftc -O -o "$work/contract" \
  ios/HomeWidgets/WidgetSnapshot.swift \
  ios/HomeWidgets/WidgetFiles.swift \
  "$work/main.swift"
"$work/contract" test/fixtures/home_widgets
