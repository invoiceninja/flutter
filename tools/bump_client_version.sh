#!/usr/bin/env bash
set -euo pipefail

# Bump the client version constant (AppVersion.kClientVersion) in
# lib/app/version.dart.
#
# kClientVersion is the version this client claims to the server: sent as the
# X-CLIENT-VERSION header on every request, drives the server's
# x-minimum-client-version handshake, tags Sentry releases, and supplies the
# trailing build digit in the About dialog's combined version string
# (v<server>-<platform><build>). Bump it on every release.
#
# Also bumps pubspec.yaml's version: keeps MAJOR.MINOR.PATCH in sync with
# kClientVersion and increments the build number (+N) by one, so the native
# build version (CFBundleVersion / versionCode, derived from pubspec) advances
# on every release. snap/snapcraft.yaml's display version is rewritten to the
# same MAJOR.MINOR.PATCH — it was a documented manual step that demonstrably
# never happened (drifted 4 releases behind).
#
# Does NOT touch kMinServerVersion (bumped only when depending on a server change).
#
# Usage:
#   tools/bump_client_version.sh             # auto-bump: patch +1 and build +1 (5.1.2+5 -> 5.1.3+6)
#   tools/bump_client_version.sh <version>   # set an explicit version, e.g. 5.2.0 (build still +1)
#   tools/bump_client_version.sh --current   # print the current version, no changes

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

file="lib/app/version.dart"

current="$(sed -n "s/.*kClientVersion = '\([^']*\)'.*/\1/p" "$file")"
if [[ -z "$current" ]]; then
  echo "!! could not find kClientVersion in $file" >&2
  exit 1
fi

arg="${1:-}"

# --current / -c: just print the current version (the old no-arg behavior).
if [[ "$arg" == "--current" || "$arg" == "-c" ]]; then
  echo "current kClientVersion: $current"
  exit 0
fi

if [[ -z "$arg" ]]; then
  # No version given: auto-bump the patch (MAJOR.MINOR.PATCH -> MAJOR.MINOR.PATCH+1).
  # The pubspec build number (+N) is bumped separately further below.
  if [[ ! "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "!! current kClientVersion '$current' is not MAJOR.MINOR.PATCH — pass an explicit version" >&2
    exit 1
  fi
  new_version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$(( BASH_REMATCH[3] + 1 ))"
else
  new_version="$arg"
fi

if [[ ! "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "!! '$new_version' is not MAJOR.MINOR.PATCH (e.g. 5.1.1)" >&2
  exit 1
fi

if [[ "$new_version" == "$current" ]]; then
  echo "==> kClientVersion already $current — nothing to do"
  exit 0
fi

perl -i -pe "s/(kClientVersion = ')[^']*(')/\${1}${new_version}\${2}/" "$file"

updated="$(sed -n "s/.*kClientVersion = '\([^']*\)'.*/\1/p" "$file")"
if [[ "$updated" != "$new_version" ]]; then
  echo "!! update failed — $file still reads '$updated'" >&2
  exit 1
fi

# --- pubspec.yaml: keep MAJOR.MINOR.PATCH in sync, increment the build (+N) ---
pubspec="pubspec.yaml"

pubspec_line="$(sed -n 's/^version:[[:space:]]*\(.*\)$/\1/p' "$pubspec")"
if [[ -z "$pubspec_line" ]]; then
  echo "!! could not find a top-level 'version:' in $pubspec" >&2
  exit 1
fi

pubspec_build="${pubspec_line#*+}"           # 4   (or whole string if no +BUILD)
if [[ "$pubspec_build" == "$pubspec_line" ]]; then
  pubspec_build=0                            # no +BUILD present -> start from 0
fi
if [[ ! "$pubspec_build" =~ ^[0-9]+$ ]]; then
  echo "!! unexpected build '$pubspec_build' in $pubspec (want MAJOR.MINOR.PATCH+BUILD)" >&2
  exit 1
fi

new_build=$(( pubspec_build + 1 ))
new_pubspec="${new_version}+${new_build}"

perl -i -pe "s/^version:.*/version: ${new_pubspec}/" "$pubspec"

pubspec_updated="$(sed -n 's/^version:[[:space:]]*\(.*\)$/\1/p' "$pubspec")"
if [[ "$pubspec_updated" != "$new_pubspec" ]]; then
  echo "!! pubspec update failed — $pubspec still reads '$pubspec_updated'" >&2
  exit 1
fi

# --- snap/snapcraft.yaml: keep the store-display version in sync ---
snapcraft="snap/snapcraft.yaml"

snap_current="$(sed -n "s/^version:[[:space:]]*'\([^']*\)'.*/\1/p" "$snapcraft")"
if [[ -z "$snap_current" ]]; then
  echo "!! could not find a top-level version: in $snapcraft" >&2
  exit 1
fi

perl -i -pe "s/^version:\s*'[^']*'/version: '${new_version}'/" "$snapcraft"

snap_updated="$(sed -n "s/^version:[[:space:]]*'\([^']*\)'.*/\1/p" "$snapcraft")"
if [[ "$snap_updated" != "$new_version" ]]; then
  echo "!! snapcraft update failed — $snapcraft still reads '$snap_updated'" >&2
  exit 1
fi

echo "==> kClientVersion: $current -> $new_version"
echo "==> pubspec version: $pubspec_line -> $new_pubspec"
echo "==> snapcraft version: $snap_current -> $new_version"
echo "    next: flutter analyze $file && flutter test test/app/version_test.dart"
