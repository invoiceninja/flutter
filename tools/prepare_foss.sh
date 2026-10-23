#!/usr/bin/env bash
# Turns this checkout into the F-Droid (FOSS) build. Everything that differs
# from the store build happens here and only here — see docs/fdroid.md.
#
#   tools/prepare_foss.sh            prepare, then `flutter build apk --release`
#   tools/prepare_foss.sh --restore  put the store build back, byte-for-byte
#                                    (local use; F-Droid never needs it).
#                                    Refuses if pubspec.yaml was edited while
#                                    prepared; `--restore --force` discards it.
#   tools/prepare_foss.sh --update-lock
#                                    regenerate tools/foss/pubspec.lock after
#                                    pubspec.lock changes; touches nothing else.
#
# Three steps:
#   1. `store_services` → its FOSS twin, via a root pubspec_overrides.yaml
#      (no Google Sign-In / Play Billing / Sentry in the dependency graph).
#   2. SQLite compiled from source instead of the hook's prebuilt download:
#      fetch the pinned sqlite3mc amalgamation, check its sha256, and point
#      the sqlite3 hook at it (`source: source`). Hook user-defines can only
#      live in pubspec.yaml, so this one edits it.
#   3. `flutter pub get --enforce-lockfile` against tools/foss/pubspec.lock,
#      the committed lock of the FOSS graph, then fail if a non-free package is
#      in it, or if any package is pinned differently from the store build's lock.
#
# Needs network for the sqlite3mc download and pub get — run it where F-Droid
# runs `prebuild`. Set FLUTTER to the SDK's flutter binary if it isn't on PATH.
set -euo pipefail

cd "$(dirname "$0")/.."
FLUTTER="${FLUTTER:-flutter}"

# Anything else would fall through to a full prepare, which rewrites the
# checkout — the wrong outcome for a mistyped --update-lock.
case "${1:-}" in
  "" | --restore | --update-lock) ;;
  *)
    echo "usage: tools/prepare_foss.sh [--restore [--force] | --update-lock]" >&2
    exit 2
    ;;
esac

# Keep in lockstep with the SQLite3MultipleCiphers release that the resolved
# `sqlite3` package ships prebuilt (its tool/download_sqlite.dart at the
# matching tag) — so the FOSS build compiles the same source the store build
# downloads. Bump both when `sqlite3` moves (docs/fdroid.md § Bumping sqlite3mc).
SQLITE3MC_URL="https://github.com/utelle/SQLite3MultipleCiphers/releases/download/v2.6.1/sqlite3mc-2.6.1-sqlite-3.54.0-amalgamation.zip"
SQLITE3MC_ZIP_SHA256="3f25af603566a23c821d8e581778b5ece2a541d2435776de57b8d845c176815a"
SQLITE3MC_C_SHA256="9b129d1ceb2c7d5dbf374b833eb29a640ecfa8e4a5af6d48508b429019c707b0"
SQLITE3MC_H_SHA256="99b3e6997aa5fc604d9ea2352e6ae89dfd4d0af8d5bd7cbfe7293d959779e6eb"
SQLITE3MC_DIR="native/sqlite3mc"
SQLITE3MC_C="$SQLITE3MC_DIR/sqlite3mc_amalgamation.c"
SQLITE3MC_H="$SQLITE3MC_DIR/sqlite3mc_amalgamation.h"

NONFREE_PACKAGES='google_sign_in|in_app_purchase|sentry'

# The FOSS graph's own lock: pubspec.lock minus the store SDKs. F-Droid wants
# `pub get --enforce-lockfile`, which a lock rewritten by the swap can't pass
# (docs/fdroid.md § F-Droid resolves a committed FOSS lock).
FOSS_LOCK="tools/foss/pubspec.lock"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Everything `prepare` changes that is tracked: the pubspec pair, plus the
# per-platform plugin registrants and SwiftPM pins that `pub get` regenerates.
# `--restore` puts these back byte-for-byte. Re-resolving is not enough: once
# the store SDKs have left pubspec.lock, a fresh `pub get` picks newer
# versions of them than the ones committed.
BACKUP=".dart_tool/foss_store_backup.tar"

# True once `prepare` has run: either of its two edits is in place.
is_prepared() {
  [[ -f pubspec_overrides.yaml ]] ||
    grep -q "^      path: $SQLITE3MC_C\$" pubspec.yaml
}

# pubspec.yaml with the hook edit undone — what the snapshot should hold.
unprepared_pubspec() {
  perl -0pe \
    "s|\n      source: source\n      path: \Q$SQLITE3MC_C\E\n|\n      source: sqlite3mc\n|" \
    pubspec.yaml
}

# One line per locked package, `name source version pin`: the sha256 of a
# hosted package, the resolved-ref of a git one. Path packages are skipped —
# swapping store_services for its twin is the point — and `dependency:` is
# left out because dropping the store SDKs legitimately changes it.
lock_pins() {
  awk '
    function flush() {
      if (name != "" && source != "path") print name, source, version, pin
      name = ""; source = ""; version = ""; pin = ""
    }
    /^packages:/ { in_packages = 1; next }
    /^[^ ]/ { flush(); in_packages = 0 }
    !in_packages { next }
    /^  [^ ]/ { flush(); name = $1; sub(/:$/, "", name) }
    /^      sha256: / || /^      resolved-ref: / { pin = $2 }
    /^    source: / { source = $2 }
    /^    version: / { version = $2 }
    END { flush() }
  ' | tr -d '"' | sort
}

# Fails unless FOSS lock $1 is free of the store SDKs and pins every package
# exactly as store lock $2 does, so F-Droid builds exactly what the store build
# tested (docs/fdroid.md § F-Droid resolves a committed FOSS lock).
check_foss_lock() {
  if grep -nE "^  ($NONFREE_PACKAGES)[a-z_]*:" "$1"; then
    echo "Non-free packages are still resolved (above) — the FOSS build would" >&2
    echo "ship them. Something outside packages/store_services depends on them." >&2
    exit 1
  fi
  local drifted
  drifted="$(comm -23 <(lock_pins <"$1") <(lock_pins <"$2"))"
  if [[ -n "$drifted" ]]; then
    echo "The FOSS lock pins packages the store lock does not:" >&2
    echo "$drifted" >&2
    echo "Run \`flutter pub get\` on the store build and commit its pubspec.lock, then" >&2
    echo "tools/prepare_foss.sh --update-lock." >&2
    exit 1
  fi
}

sqlite3mc_present() {
  [[ -f "$SQLITE3MC_C" && -f "$SQLITE3MC_H" &&
    "$(sha256 "$SQLITE3MC_C")" == "$SQLITE3MC_C_SHA256" &&
    "$(sha256 "$SQLITE3MC_H")" == "$SQLITE3MC_H_SHA256" ]]
}

store_files() {
  local f
  for f in pubspec.yaml pubspec.lock \
    macos/Flutter/GeneratedPluginRegistrant.swift \
    {linux,windows}/flutter/generated_plugin_registrant.{cc,h} \
    {linux,windows}/flutter/generated_plugins.cmake \
    {ios,macos}/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved \
    {ios,macos}/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved; do
    [[ -f "$f" ]] && echo "$f"
  done
  return 0
}

if [[ "${1:-}" == "--restore" ]]; then
  if [[ ! -f "$BACKUP" ]]; then
    echo "No $BACKUP — nothing to restore (was .dart_tool cleaned?)." >&2
    echo "Recover with: rm -f pubspec_overrides.yaml && git checkout -- \\" >&2
    echo "  pubspec.yaml pubspec.lock && $FLUTTER pub get" >&2
    exit 1
  fi
  # The snapshot is byte-exact, so it would silently drop anything added to
  # pubspec.yaml since `prepare`. Refuse unless told to discard it.
  if [[ "${2:-}" != "--force" ]] &&
    ! cmp -s <(unprepared_pubspec) <(tar -xOf "$BACKUP" pubspec.yaml); then
    echo "pubspec.yaml changed since prepare; --restore would discard that:" >&2
    diff <(tar -xOf "$BACKUP" pubspec.yaml) <(unprepared_pubspec) >&2 || true
    echo "To discard it, run: tools/prepare_foss.sh --restore --force" >&2
    echo "(then re-apply the change above if the store build needs it)." >&2
    exit 1
  fi
  rm -f pubspec_overrides.yaml
  tar -xf "$BACKUP"
  # One retry: on macOS, Flutter 3.44's SwiftPM step can crash with "Cannot
  # create link … File exists" when the plugin set has just changed; the
  # second run finds the link in place and succeeds.
  "$FLUTTER" pub get || "$FLUTTER" pub get
  # `pub get` deletes a SwiftPM pin when the plugin set changes, which it just
  # did — so lay the snapshot down again on top of what it regenerated.
  tar -xf "$BACKUP"
  rm -f "$BACKUP"
  echo "Restored the store build."
  exit 0
fi

if [[ "${1:-}" == "--update-lock" ]]; then
  if is_prepared; then
    echo "This tree is prepared; run tools/prepare_foss.sh --restore first." >&2
    exit 1
  fi
  # Resolve the FOSS graph from the store lock, so pub keeps every version the
  # store build locked and only drops what nothing uses any more. In a copy,
  # so the checkout's plugin registrants and SwiftPM pins are left alone.
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  cp pubspec.yaml pubspec.lock "$tmp/"
  cp tools/foss/pubspec_overrides.yaml "$tmp/pubspec_overrides.yaml"
  cp -R packages "$tmp/"
  "$FLUTTER" pub get --directory "$tmp"
  check_foss_lock "$tmp/pubspec.lock" pubspec.lock
  cp "$tmp/pubspec.lock" "$FOSS_LOCK"
  echo "Wrote $FOSS_LOCK — commit it."
  exit 0
fi

# Snapshot the store state whenever the tree is in it — replacing any older
# snapshot, which may predate a pull or a hand-restore and would otherwise
# revert those on --restore. A re-run on a prepared tree keeps the one it has.
if ! is_prepared; then
  mkdir -p .dart_tool
  # shellcheck disable=SC2046
  tar -cf "$BACKUP" $(store_files)
fi

# 1. The FOSS twin of store_services.
cp tools/foss/pubspec_overrides.yaml pubspec_overrides.yaml
echo "Wrote pubspec_overrides.yaml (store_services -> packages/store_services_foss)."

# 2. sqlite3mc from source.
if sqlite3mc_present; then
  echo "sqlite3mc amalgamation already present."
else
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL --retry 3 -o "$tmp/sqlite3mc.zip" "$SQLITE3MC_URL"
  actual="$(sha256 "$tmp/sqlite3mc.zip")"
  if [[ "$actual" != "$SQLITE3MC_ZIP_SHA256" ]]; then
    echo "sqlite3mc zip sha256 mismatch: got $actual" >&2
    exit 1
  fi
  mkdir -p "$SQLITE3MC_DIR"
  unzip -o -q "$tmp/sqlite3mc.zip" \
    sqlite3mc_amalgamation.c sqlite3mc_amalgamation.h -d "$SQLITE3MC_DIR"
  if ! sqlite3mc_present; then
    echo "sqlite3mc_amalgamation.{c,h} sha256 mismatch after extraction" >&2
    exit 1
  fi
  echo "Fetched sqlite3mc amalgamation into $SQLITE3MC_DIR."
fi

if grep -q "^      path: $SQLITE3MC_C\$" pubspec.yaml; then
  echo "pubspec.yaml already builds sqlite3mc from source."
else
  if [[ "$(grep -c '^      source: sqlite3mc$' pubspec.yaml)" != "1" ]]; then
    echo "pubspec.yaml: expected exactly one 'source: sqlite3mc' hook line" >&2
    echo "under hooks.user_defines.sqlite3 — update this script." >&2
    exit 1
  fi
  perl -pi -e \
    "s|^      source: sqlite3mc\$|      source: source\n      path: $SQLITE3MC_C|" \
    pubspec.yaml
  echo "pubspec.yaml: sqlite3 hook -> source: source ($SQLITE3MC_C)."
fi

# 3. Resolve exactly the committed FOSS lock, then prove it is free and pinned
# as the store build is. The snapshot still holds the store lock.
cp "$FOSS_LOCK" pubspec.lock
if ! "$FLUTTER" pub get --enforce-lockfile; then
  echo "$FOSS_LOCK no longer satisfies pubspec.yaml. Run" >&2
  echo "tools/prepare_foss.sh --update-lock on the store build and commit it." >&2
  exit 1
fi
# A file, not <(…): the check's own process substitutions would shadow its fd.
tar -xOf "$BACKUP" pubspec.lock >.dart_tool/foss_store_pubspec.lock
check_foss_lock pubspec.lock .dart_tool/foss_store_pubspec.lock
rm -f .dart_tool/foss_store_pubspec.lock

echo "FOSS build prepared. Next: $FLUTTER build apk --release"
