#!/usr/bin/env bash
set -euo pipefail

# Xcode IDE pre-action: bake the Sentry DSN (and, on iOS, the Google Sign-In
# iOS client ID — IN_GOOGLE_IOS_CLIENT_ID, Env.googleIosClientId) into a
# Product > Archive build. Both are lost the same way, described below for the
# DSN; the name stays for the scheme files that invoke it.
#
# It also syncs the app version (FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER) from
# pubspec.yaml into the same file, which goes stale the opposite way — nothing
# regenerates it when it should. See `sync_version` below.
#
# WHY: the Sentry DSN is a compile-time --dart-define (IN_SENTRY_DSN, read by
# Env.sentryDsn in lib/app/env.dart). Flutter forwards dart-defines to the
# native build as a base64 DART_DEFINES entry in the *gitignored, generated*
# xcconfig (macos/Flutter/ephemeral/Flutter-Generated.xcconfig,
# ios/Flutter/Generated.xcconfig). A bare `flutter run` / `flutter build`
# regenerates that file WITHOUT the DSN (`flutter pub get` does too, but only
# when the file is missing or older than the SDK's tools stamp), so a manual
# Xcode archive would ship with Sentry disabled.
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
# NOT IDE-only: command-line `xcodebuild -scheme Runner` runs scheme actions
# too, so this also fires under `flutter build ios|ipa|macos` and under the CI
# archives (appstore-ios.yml / appstore-macos.yml), which put the values in
# their job env for it. That is why it never drops an entry it has no
# replacement for: when a key resolves empty here, whatever `flutter build
# --config-only --dart-define=…` already wrote is kept. (It used to be dropped,
# which shipped every CI archive with Sentry disabled.) See docs/setup.md
# § "Release builds with Sentry".
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
  echo "==> [pre-action] CONFIGURATION=${CONFIGURATION:-<unset>} (not Release) — skipping."
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

# --- resolve each managed define (env > dev.json > empty) ---
# Kept identical to tools/build_release.sh's `resolve_define` so IDE archives
# and CLI builds behave the same. Keep the two in sync if either changes.
resolve_define() {
  local key="$1" value=""
  value="$(printenv "$key" || true)"
  if [[ -z "$value" && -f "$dev_json" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      value="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2],""))' "$dev_json" "$key" 2>/dev/null || true)"
    fi
    if [[ -z "$value" ]]; then
      value="$(grep -oE "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$dev_json" 2>/dev/null \
                 | head -n1 \
                 | sed -E "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/" || true)"
    fi
  fi
  printf '%s' "$value"
}

dsn_source=""
if [[ -n "${IN_SENTRY_DSN:-}" ]]; then
  dsn_source="environment (IN_SENTRY_DSN)"
elif [[ -f "$dev_json" ]]; then
  dsn_source="dev.json"
fi
dsn="$(resolve_define IN_SENTRY_DSN)"
# Google Sign-In's iOS client ID (Env.googleIosClientId) is lost the same way
# the DSN is. macOS has no Google sign-in, so it is only managed on iOS.
google_ios_client_id=""
if [[ "$platform" == "ios" ]]; then
  google_ios_client_id="$(resolve_define IN_GOOGLE_IOS_CLIENT_ID)"
fi

# --- locate the platform's generated xcconfig ---
case "$platform" in
  ios)   xcconfig="$repo_root/ios/Flutter/Generated.xcconfig" ;;
  macos) xcconfig="$repo_root/macos/Flutter/ephemeral/Flutter-Generated.xcconfig" ;;
esac

# First value of KEY in the generated xcconfig; empty when the key is absent.
xcconfig_get() {
  /usr/bin/grep -E "^$1=" "$xcconfig" | head -n1 | sed "s/^$1=//" || true
}

# --- sync the app version from pubspec.yaml ---
# Info.plist takes CFBundleShortVersionString / CFBundleVersion from
# FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER in this same generated xcconfig, and
# only a `flutter build` / `flutter run` for the platform rewrites them — a
# `flutter pub get` does not once the file exists (flutter_tools regenerates it
# there only after an SDK upgrade), and an Xcode archive never does. So after a
# version bump a hand-built archive carried whatever the last flutter build had
# seen: a macOS archive came out as 5.1.10 (13) with pubspec at 5.1.14+17. (iOS
# only escaped because tools/prepare_ios_archive.sh runs --config-only before
# each archive.)
#
# pubspec.yaml is the one source, on EVERY Release build through the scheme —
# `flutter build ipa|ios|macos` included, since flutter's own xcodebuild runs
# this pre-action after it wrote the file. So `--build-name` / `--build-number`
# cannot take effect on an Apple build; tools/build_release.sh and
# tools/prepare_ios_archive.sh refuse them rather than let them vanish. (Syncing
# only when pubspec is newer than the xcconfig would honour the flags, but the
# file's mtime proves nothing — the DART_DEFINES rewrite below bumps it — and a
# wrong guess recreates the stale archive.)
# Never fatal — an archive with a stale version is still better than none.
sync_version() {
  local spec name number old_name old_number tmp
  local re='^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)[[:space:]]*$'
  [[ -f "$xcconfig" ]] || return 0
  # Same expression tools/bump_client_version.sh reads the line with.
  spec="$(sed -n 's/^version:[[:space:]]*\(.*\)$/\1/p' "$repo_root/pubspec.yaml" 2>/dev/null | head -n1 || true)"
  if [[ ! "$spec" =~ $re ]]; then
    echo "warning: [version] pubspec.yaml version '${spec:-<none>}' is not MAJOR.MINOR.PATCH+BUILD — leaving the $platform build's version as generated." >&2
    return 0
  fi
  name="${BASH_REMATCH[1]}"
  number="${BASH_REMATCH[2]}"
  old_name="$(xcconfig_get FLUTTER_BUILD_NAME)"
  old_number="$(xcconfig_get FLUTTER_BUILD_NUMBER)"
  if [[ -z "$old_name" || -z "$old_number" ]]; then
    echo "warning: [version] no FLUTTER_BUILD_NAME / FLUTTER_BUILD_NUMBER in ${xcconfig#"$repo_root"/} — run a build once first; skipping the version sync." >&2
    return 0
  fi
  [[ "$old_name" == "$name" && "$old_number" == "$number" ]] && return 0
  tmp="$(/usr/bin/mktemp)"
  /usr/bin/awk -v name="FLUTTER_BUILD_NAME=$name" -v number="FLUTTER_BUILD_NUMBER=$number" \
    '/^FLUTTER_BUILD_NAME=/ { print name; next } /^FLUTTER_BUILD_NUMBER=/ { print number; next } { print }' \
    "$xcconfig" > "$tmp"
  mv "$tmp" "$xcconfig"
  echo "==> [version] $old_name ($old_number) -> $name ($number) (from pubspec.yaml)."
}
sync_version

if [[ ! -f "$xcconfig" ]] || ! /usr/bin/grep -q '^DART_DEFINES=' "$xcconfig"; then
  # Non-fatal: any `flutter pub get` / build / run writes DART_DEFINES, so this
  # only trips on a never-built tree (which can't archive anyway). Don't block.
  echo "warning: [sentry-dsn] no DART_DEFINES in ${xcconfig#"$repo_root"/} — run a build once first; skipping Sentry injection." >&2
  exit 0
fi

# DART_DEFINES is a comma-separated list of base64("KEY=VALUE") entries. Rebuild
# it: a managed key that resolved to a value replaces its prior entry; one that
# resolved EMPTY leaves any prior entry alone (it was written by a `flutter
# build --config-only` that knew the value — the CI case, and
# `tools/prepare_ios_archive.sh` with a DSN in the env). Only a key with no
# value anywhere stays off, with no blank entry baked.
replace_keys=()
[[ -n "$dsn" ]] && replace_keys+=(IN_SENTRY_DSN)
[[ -n "$google_ios_client_id" ]] && replace_keys+=(IN_GOOGLE_IOS_CLIENT_ID)
kept_dsn=0
kept_google=0
current="$(xcconfig_get DART_DEFINES)"
rebuilt=""
saved_ifs="$IFS"
IFS=','
for entry in $current; do
  IFS="$saved_ifs"
  if [[ -n "$entry" ]]; then
    decoded="$(printf '%s' "$entry" | /usr/bin/base64 -D 2>/dev/null || true)"
    keep=1
    # `${arr[@]+…}`: an empty array under `set -u` is an unbound-variable error
    # in the bash 3.2 Xcode runs this with.
    for key in ${replace_keys[@]+"${replace_keys[@]}"}; do
      [[ "$decoded" == "$key="* ]] && keep=0
    done
    if [[ "$keep" -eq 1 ]]; then
      rebuilt="${rebuilt:+$rebuilt,}$entry"
      [[ "$decoded" == "IN_SENTRY_DSN="?* ]] && kept_dsn=1
      [[ "$decoded" == "IN_GOOGLE_IOS_CLIENT_ID="?* ]] && kept_google=1
    fi
  fi
  IFS=','
done
IFS="$saved_ifs"
if [[ -n "$dsn" ]]; then
  enc="$(printf '%s' "IN_SENTRY_DSN=$dsn" | /usr/bin/base64 | tr -d '\n')"
  rebuilt="${rebuilt:+$rebuilt,}$enc"
fi
if [[ -n "$google_ios_client_id" ]]; then
  enc="$(printf '%s' "IN_GOOGLE_IOS_CLIENT_ID=$google_ios_client_id" | /usr/bin/base64 | tr -d '\n')"
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
elif [[ "$kept_dsn" -eq 1 ]]; then
  echo "==> [sentry-dsn] IN_SENTRY_DSN is not in the environment or dev.json — kept the one already in DART_DEFINES (from flutter build --config-only)."
else
  # Loud but non-fatal: an archive with Sentry disabled is a safe no-op, and we
  # must not block a developer who simply hasn't configured a DSN. `warning:`
  # makes Xcode surface it in the Issue navigator.
  echo "warning: [sentry-dsn] IN_SENTRY_DSN is empty (not in environment, dev.json or DART_DEFINES)." >&2
  echo "warning: [sentry-dsn] This $platform build will ship with Sentry DISABLED." >&2
fi
if [[ "$platform" == "ios" ]]; then
  if [[ -n "$google_ios_client_id" ]]; then
    echo "==> [google] Baked the Google Sign-In iOS client ID into the build."
  elif [[ "$kept_google" -eq 1 ]]; then
    echo "==> [google] IN_GOOGLE_IOS_CLIENT_ID is not in the environment or dev.json — kept the one already in DART_DEFINES."
  else
    echo "warning: [google] IN_GOOGLE_IOS_CLIENT_ID is empty — Sign in with Google is hidden in this build." >&2
  fi
fi
