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
# with Sentry disabled.
#
# HOW: this rewrites *only* the IN_SENTRY_DSN entry inside the already-generated
# xcconfig's DART_DEFINES list, in place, using only base64 + awk. It does NOT
# invoke `flutter` / `pod` / `xcodebuild`, and that is the whole point:
#
#   An earlier version ran `flutter build <platform> --release --config-only`
#   here. Run synchronously inside an *iOS* archive's pre-action it HUNG — the
#   nested Flutter/CocoaPods work deadlocked under a GUI-launched Xcode that has
#   no shell PATH and no TTY — so the archive stalled in the pre-action and never
#   produced a .xcarchive (macOS happened to complete, so only iOS broke).
#
# Editing one line can't hang, needs nothing on PATH, and is instant. Xcode reads
# DART_DEFINES from the xcconfig as a build setting and xcode_backend.sh /
# macos_assemble.sh forward it to `flutter assemble`, so the compile consumes
# exactly what we write here — the same seam the old --config-only write relied on.
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
# Pre-actions also fire on Clean; don't touch the config there.
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

# --- locate the platform's generated xcconfig ---
case "$platform" in
  ios)   xcconfig="$repo_root/ios/Flutter/Generated.xcconfig" ;;
  macos) xcconfig="$repo_root/macos/Flutter/ephemeral/Flutter-Generated.xcconfig" ;;
esac

if [[ ! -f "$xcconfig" ]] || ! /usr/bin/grep -q '^DART_DEFINES=' "$xcconfig"; then
  # Non-fatal: any `flutter pub get` / build / run writes DART_DEFINES, so this
  # only trips on a never-built tree (which can't archive anyway). Don't block.
  echo "warning: [sentry-dsn] no DART_DEFINES in ${xcconfig#"$repo_root"/} — run a build once first; skipping Sentry injection." >&2
  exit 0
fi

# DART_DEFINES is a comma-separated list of base64("KEY=VALUE") entries. Rebuild
# it: keep every entry except a prior IN_SENTRY_DSN, then append a fresh one when
# we have a DSN (an empty DSN drops it -> Sentry disabled, no blank entry baked).
current="$(/usr/bin/grep -E '^DART_DEFINES=' "$xcconfig" | head -n1 | sed 's/^DART_DEFINES=//')"
rebuilt=""
saved_ifs="$IFS"
IFS=','
for entry in $current; do
  IFS="$saved_ifs"
  if [[ -n "$entry" ]]; then
    decoded="$(printf '%s' "$entry" | /usr/bin/base64 -D 2>/dev/null || true)"
    if [[ "$decoded" != IN_SENTRY_DSN=* ]]; then
      rebuilt="${rebuilt:+$rebuilt,}$entry"
    fi
  fi
  IFS=','
done
IFS="$saved_ifs"
if [[ -n "$dsn" ]]; then
  enc="$(printf '%s' "IN_SENTRY_DSN=$dsn" | /usr/bin/base64 | tr -d '\n')"
  rebuilt="${rebuilt:+$rebuilt,}$enc"
fi

# Write the DART_DEFINES line back. `awk -v` treats the value literally, so the
# / + = in base64 can't be mangled the way a `sed s/.../.../` replacement would.
tmp="$(/usr/bin/mktemp)"
/usr/bin/awk -v val="DART_DEFINES=$rebuilt" \
  '/^DART_DEFINES=/ { print val; next } { print }' "$xcconfig" > "$tmp"
mv "$tmp" "$xcconfig"

if [[ -n "$dsn" ]]; then
  echo "==> [sentry-dsn] Baked Sentry DSN into the $platform build (source: $dsn_source)."
else
  # Loud but non-fatal: an archive with Sentry disabled is a safe no-op, and we
  # must not block a developer who simply hasn't configured a DSN. `warning:`
  # makes Xcode surface it in the Issue navigator.
  echo "warning: [sentry-dsn] IN_SENTRY_DSN is empty (not in environment or dev.json)." >&2
  echo "warning: [sentry-dsn] This $platform build will ship with Sentry DISABLED." >&2
fi
