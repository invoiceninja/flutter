#!/usr/bin/env bash
set -euo pipefail

# Xcode IDE pre-action: bake the Sentry DSN into a Product > Archive build.
#
# WHY: the Sentry DSN is a compile-time --dart-define (IN_SENTRY_DSN, read by
# Env.sentryDsn in lib/app/env.dart). Flutter forwards dart-defines to the
# native build as a base64 DART_DEFINES entry in the *gitignored, generated*
# xcconfig (macos/Flutter/ephemeral/Flutter-Generated.xcconfig,
# ios/Flutter/Generated.xcconfig). A bare `flutter pub get` / `flutter run`
# regenerates that file WITHOUT the DSN, so a manual Xcode archive would ship
# with Sentry disabled. This rewrites the generated xcconfig with the DSN via
# `flutter build <platform> --release --config-only` (the same seam CI uses in
# appstore-{ios,macos}.yml) BEFORE Xcode compiles, so IDE archives report
# crashes like the CLI/CI ones do.
#
# Wired in as the first BuildAction pre-action in BOTH shared schemes
# (macos|ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme).
# Command-line `xcodebuild` / `flutter build` do NOT run scheme actions, so CLI
# + CI are unaffected. See docs/setup.md § "Release builds with Sentry".
#
# Usage (invoked by Xcode; also runnable by hand to test):
#   tools/xcode_inject_sentry_dsn.sh <macos|ios>

platform="${1:-}"
case "$platform" in
  macos|ios) ;;
  *) echo "error: xcode_inject_sentry_dsn.sh needs a platform arg: macos | ios" >&2; exit 1 ;;
esac

# Only Release compiles (Archive + any Release build). Debug (⌘R) / Profile skip
# untouched -> the inner dev loop is unaffected. CONFIGURATION comes from Xcode.
if [[ "${CONFIGURATION:-}" != "Release" ]]; then
  echo "==> [sentry-dsn] CONFIGURATION=${CONFIGURATION:-<unset>} (not Release) — skipping."
  exit 0
fi
# Pre-actions also fire on Clean; don't build there (mirrors Flutter's prepare).
if [[ "${ACTION:-}" == "clean" ]]; then
  exit 0
fi

# Repo root = this script's dir (tools/) parent — independent of $SRCROOT so the
# script also runs by hand. Mirrors tools/build_release.sh.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dev_json="$repo_root/dev.json"

# --- resolve the Sentry DSN (env > dev.json > empty) ---
# Kept identical to tools/build_release.sh (lines 70-95) so IDE archives and CLI
# builds behave the same. Keep the two in sync if either changes.
dsn=""
dsn_source=""
if [[ -n "${IN_SENTRY_DSN:-}" ]]; then
  dsn="$IN_SENTRY_DSN"
  dsn_source="environment (IN_SENTRY_DSN)"
elif [[ -f "$dev_json" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    dsn="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("IN_SENTRY_DSN",""))' "$dev_json" 2>/dev/null || true)"
  fi
  if [[ -z "$dsn" ]]; then
    dsn="$(grep -oE '"IN_SENTRY_DSN"[[:space:]]*:[[:space:]]*"[^"]*"' "$dev_json" 2>/dev/null \
             | head -n1 \
             | sed -E 's/.*"IN_SENTRY_DSN"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' || true)"
  fi
  [[ -n "$dsn" ]] && dsn_source="dev.json"
fi

# Locate flutter: prefer Xcode's FLUTTER_ROOT (from the generated xcconfig),
# fall back to PATH so a manual run still works.
if [[ -n "${FLUTTER_ROOT:-}" && -x "$FLUTTER_ROOT/bin/flutter" ]]; then
  flutter_bin="$FLUTTER_ROOT/bin/flutter"
elif command -v flutter >/dev/null 2>&1; then
  flutter_bin="$(command -v flutter)"
else
  echo "error: [sentry-dsn] flutter not found (FLUTTER_ROOT unset and not on PATH)." >&2
  exit 1
fi

if [[ -z "$dsn" ]]; then
  # Loud but non-fatal: an archive with Sentry disabled is a safe no-op, and we
  # must not block a developer who simply hasn't configured a DSN. `warning:`
  # makes Xcode surface it in the Issue navigator.
  echo "warning: [sentry-dsn] IN_SENTRY_DSN is empty (not in environment or dev.json)." >&2
  echo "warning: [sentry-dsn] This $platform archive will ship with Sentry DISABLED." >&2
else
  echo "==> [sentry-dsn] Baking Sentry DSN into the $platform archive (source: $dsn_source)."
fi

# macOS desktop must be enabled for `flutter build macos` (idempotent no-op when
# already on). Mirrors tools/build_release.sh.
[[ "$platform" == "macos" ]] && "$flutter_bin" config --enable-macos-desktop >/dev/null

# Regenerate the platform's Generated.xcconfig with the DSN in DART_DEFINES.
# --config-only writes the config and STOPS (no compile) -> no xcodebuild
# re-entrancy / no pre-action recursion, and no codesigning needed. Runs from
# the Flutter project root.
cd "$repo_root"
"$flutter_bin" build "$platform" --release --config-only \
  --dart-define=IN_SENTRY_DSN="$dsn"

echo "==> [sentry-dsn] Done — $platform Generated.xcconfig updated (Sentry: $([[ -n "$dsn" ]] && echo enabled || echo disabled))."
