#!/usr/bin/env bash
set -euo pipefail

# Build a release artifact with the Sentry DSN baked in.
#
# Sentry error reporting is already wired in the app (lib/main.dart +
# lib/app/env.dart `Env.sentryDsn`); it activates only in release/profile
# builds when a non-empty IN_SENTRY_DSN was passed at compile time. Release
# builds don't read dev.json, so this script resolves the DSN and injects it
# via a single `--dart-define`, mirroring .github/workflows/snapcraft.yml.
#
# DSN resolution order:
#   1. the IN_SENTRY_DSN environment variable (CI / explicit override), else
#   2. the IN_SENTRY_DSN key in dev.json (gitignored local config), else
#   3. empty -> Sentry stays disabled (safe no-op; Env.sentryDsn defaults to '').
#
# The Google Sign-In client IDs resolve the same way (env > dev.json > empty):
#   IN_GOOGLE_SERVER_CLIENT_ID (Android) and IN_GOOGLE_IOS_CLIENT_ID (iOS).
# Empty hides "Sign in with Google" on that platform — see docs/setup.md
# § Google Sign-In client IDs.
#
# Only those keys are read from dev.json — IN_DEV_EMAIL / IN_DEV_PASSWORD are
# deliberately NOT passed, so dev credentials never land in a shipped binary.
#
# Usage:
#   tools/build_release.sh [platform] [--codegen] [-- <extra flutter args>]
#
#   platform   macos | ios | appbundle | linux | web
#              Omit it for an interactive picker. (Android is appbundle only.)
#   --codegen  Run `dart run build_runner build --delete-conflicting-outputs`
#              first (off by default; assumes generated files are current).
#   --         Everything after is passed verbatim to `flutter build`.
#
# Examples:
#   tools/build_release.sh                              # interactive picker
#   tools/build_release.sh macos
#   tools/build_release.sh appbundle --codegen
#   tools/build_release.sh ios -- --no-codesign         # unsigned compile check
#   IN_SENTRY_DSN=https://…  tools/build_release.sh macos   # env override

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dev_json="$repo_root/dev.json"

print_usage() {
  sed -n '4,33p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# --- parse args ---
platform=""
run_codegen=0
extra_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    -g|--codegen) run_codegen=1; shift ;;
    --) shift; extra_args+=("$@"); break ;;
    *) if [[ -z "$platform" ]]; then platform="$1"; else extra_args+=("$1"); fi; shift ;;
  esac
done

# --- pick a platform if none was given ---
if [[ -z "$platform" ]]; then
  if [[ -t 0 ]]; then
    echo "Select a release platform:"
    select p in macos ios appbundle linux web; do
      [[ -n "${p:-}" ]] && { platform="$p"; break; }
    done
  else
    echo "ERROR: no platform argument and no TTY for the interactive picker." >&2
    print_usage
    exit 1
  fi
fi

# --- resolve the Sentry DSN (env > dev.json > empty) ---
dsn=""
dsn_source=""
if [[ -n "${IN_SENTRY_DSN:-}" ]]; then
  dsn="$IN_SENTRY_DSN"
  dsn_source="environment (IN_SENTRY_DSN)"
elif [[ -f "$dev_json" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    dsn="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("IN_SENTRY_DSN",""))' "$dev_json" 2>/dev/null || true)"
  fi
  # Fallback (python3 missing / failed): parse the flat "IN_SENTRY_DSN": "<value>" line.
  if [[ -z "$dsn" ]]; then
    dsn="$(grep -oE '"IN_SENTRY_DSN"[[:space:]]*:[[:space:]]*"[^"]*"' "$dev_json" 2>/dev/null \
             | head -n1 \
             | sed -E 's/.*"IN_SENTRY_DSN"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' || true)"
  fi
  [[ -n "$dsn" ]] && dsn_source="dev.json"
fi

if [[ -z "$dsn" ]]; then
  echo "WARNING: IN_SENTRY_DSN is empty (not in environment or dev.json)."
  echo "         Building with Sentry DISABLED — safe no-op (Env.sentryDsn defaults to '')."
else
  # Never print the DSN value itself — just where it came from.
  echo "==> Sentry DSN resolved from: $dsn_source"
fi

# --- resolve the Google Sign-In client IDs (env > dev.json > empty) ---
# Kept identical to tools/xcode_inject_sentry_dsn.sh's `resolve_define`.
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
google_server_client_id="$(resolve_define IN_GOOGLE_SERVER_CLIENT_ID)"
google_ios_client_id="$(resolve_define IN_GOOGLE_IOS_CLIENT_ID)"
if [[ "$platform" == "appbundle" && -z "$google_server_client_id" ]]; then
  echo "WARNING: IN_GOOGLE_SERVER_CLIENT_ID is empty — Sign in with Google is hidden on Android."
fi
if [[ "$platform" == "ios" && -z "$google_ios_client_id" ]]; then
  echo "WARNING: IN_GOOGLE_IOS_CLIENT_ID is empty — Sign in with Google is hidden on iOS."
fi

# --- map the platform to `flutter build` args ---
case "$platform" in
  macos)
    flutter config --enable-macos-desktop >/dev/null
    build_args=(macos --release) ;;
  ios)
    # `ipa` is the distributable archive (needs signing configured). For an
    # unsigned compile check use: tools/build_release.sh ios -- --no-codesign
    # which you'd pair with `flutter build ios`; pass it through after `--`.
    build_args=(ipa --release) ;;
  appbundle)
    build_args=(appbundle --release) ;;
  linux)
    # Linux only compiles on a Linux host (Flutter can't cross-compile it from
    # macOS) — on this machine CI's snapcraft.yml builds + injects the DSN.
    flutter config --enable-linux-desktop >/dev/null
    build_args=(linux --release) ;;
  web)
    echo "NOTE: Sentry is excluded on web (the !kIsWeb gate in main.dart) — the DSN is ignored there."
    build_args=(web --wasm --release) ;;
  *)
    echo "ERROR: unknown platform '$platform' (expected: macos | ios | appbundle | linux | web)" >&2
    exit 1 ;;
esac

cd "$repo_root"

if [[ "$run_codegen" -eq 1 ]]; then
  echo "==> dart run build_runner build --delete-conflicting-outputs"
  dart run build_runner build --delete-conflicting-outputs
fi

echo "==> flutter build ${build_args[*]} (Sentry: $([[ -n "$dsn" ]] && echo enabled || echo disabled))"
# `${arr[@]+"${arr[@]}"}` safely expands a possibly-empty array under `set -u`
# (needed on macOS's stock bash 3.2). `set -x` echoes the exact build command.
set -x
flutter build "${build_args[@]}" \
  --dart-define=IN_SENTRY_DSN="$dsn" \
  --dart-define=IN_GOOGLE_SERVER_CLIENT_ID="$google_server_client_id" \
  --dart-define=IN_GOOGLE_IOS_CLIENT_ID="$google_ios_client_id" \
  ${extra_args[@]+"${extra_args[@]}"}
