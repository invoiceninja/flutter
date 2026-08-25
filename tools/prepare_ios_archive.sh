#!/usr/bin/env bash
set -euo pipefail

# Prepare the tree for a hand-built iOS "Product > Archive" in Xcode, then
# verify the thing that actually breaks it.
#
# WHY: an Xcode archive fails Swift Package Manager resolution with
#
#     The package product 'file-picker' requires minimum platform version 14.0
#     for the iOS platform, but this target supports 13.0
#
# even though ios/Podfile and all three IPHONEOS_DEPLOYMENT_TARGET entries in
# ios/Runner.xcodeproj/project.pbxproj already say 14.0. The 13.0 lives in the
# *generated, gitignored*
#
#     ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
#
# which is the top-level SwiftPM package the Runner target links. flutter_tools
# writes it at its hardcoded iOS default (darwin.dart -> Version(13, 0)) and
# raises it to the project's real target only in
# SwiftPackageManager.updateMinimumDeployment, called from a single site inside
# `flutter build ios`/`ipa`/`run` (ios/mac.dart). An Xcode archive never calls
# it, and EVERY `flutter pub get` — including an IDE auto-pub-get when you save
# pubspec.yaml — resets the file back down. Upstream: flutter/flutter#162196
# (open, P3); `--config-only` is the Flutter team's own stated workaround.
# Tracked in docs/upstream-workarounds.md § 8.
#
# WHY THIS ISN'T A SCHEME PRE-ACTION: Xcode resolves the Swift package graph
# BEFORE any pre-action or build-phase script runs, so an in-Xcode hook could
# only ever fix the *next* archive. Worse, running `flutter build … --config-only`
# from a pre-action is exactly what deadlocked iOS archives once before — see the
# header of tools/xcode_inject_sentry_dsn.sh. It has to be a terminal step.
#
# NOTE ON THE SENTRY DSN: this deliberately does NOT pass
# --dart-define=IN_SENTRY_DSN. The Runner scheme pre-action
# (tools/xcode_inject_sentry_dsn.sh) owns the DSN and patches it into the
# generated xcconfig at archive time — i.e. after this script has run. Don't
# "fix" that by duplicating build_release.sh's DSN resolution here; running
# --config-only first actually *helps*, because it guarantees the DART_DEFINES
# line that pre-action edits in place already exists.
#
# Usage:
#   tools/prepare_ios_archive.sh [-- <extra flutter build args>]
#
# Then archive in Xcode: Product > Archive.
#
# For a fully CLI release that needs none of this, use tools/build_release.sh ios
# (`flutter build ipa --release`) — that path self-heals the manifest itself.

# Keep this bash 3.2 compatible: /bin/bash on macOS is 3.2.57, so no `mapfile`,
# no associative arrays, no `${var,,}` (same constraint tools/git-hooks/pre-commit
# documents).

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

manifest="$repo_root/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
packages_dir="$repo_root/ios/Flutter/ephemeral/Packages/.packages"
pbxproj="$repo_root/ios/Runner.xcodeproj/project.pbxproj"
xcconfig="$repo_root/ios/Flutter/Generated.xcconfig"

print_usage() {
  sed -n '42,48p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

extra_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --) shift; extra_args+=("$@"); break ;;
    *) echo "ERROR: unexpected argument '$1' (pass flutter args after '--')" >&2
       print_usage >&2
       exit 1 ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: iOS archives are macOS-only; this is $(uname -s)." >&2
  exit 1
fi

# --- version helpers -------------------------------------------------------
# Swift manifests declare a platform two ways — .iOS("13.0") and .iOS(.v13) —
# and .vNN_M means NN.M. Normalise both to a plain dotted number.
ver_norm() {
  local v="$1"
  v="$(printf '%s' "$v" | tr -d '"')"
  v="${v#.v}"
  v="$(printf '%s' "$v" | tr '_' '.')"
  # `.v13` means 13.0 — spell the minor out so the report reads consistently
  # (ver_ge already pads missing fields, so this is presentation only).
  case "$v" in
    *.*) ;;
    *) v="$v.0" ;;
  esac
  printf '%s' "$v"
}

# ver_ge A B -> true when A >= B, comparing field by field (no `sort -V`, whose
# availability differs between BSD and GNU userlands).
ver_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, ".")
    k = (n > m ? n : m)
    for (i = 1; i <= k; i++) {
      ai = (i <= n ? x[i] + 0 : 0)
      bi = (i <= m ? y[i] + 0 : 0)
      if (ai > bi) exit 0
      if (ai < bi) exit 1
    }
    exit 0
  }'
}

ver_gt() { ver_ge "$1" "$2" && ! ver_ge "$2" "$1"; }

# ios_floor <Package.swift> -> normalised iOS floor, or empty when the manifest
# declares no `platforms:` block at all (FlutterFramework doesn't).
ios_floor() {
  local raw
  raw="$(grep -oE '\.iOS\((\.v[0-9_]+|"[0-9.]+")\)' "$1" 2>/dev/null | head -n1 || true)"
  [[ -z "$raw" ]] && return 0
  raw="$(printf '%s' "$raw" | sed -E 's/^\.iOS\(//; s/\)$//')"
  ver_norm "$raw"
}

# --- 1. regenerate the SwiftPM manifest ------------------------------------
cd "$repo_root"
echo "==> flutter build ios --release --config-only"
flutter build ios --release --config-only ${extra_args[@]+"${extra_args[@]}"}
echo

# --- 2. read back what it produced -----------------------------------------
if [[ ! -f "$manifest" ]]; then
  echo "ERROR: no generated SwiftPM manifest at" >&2
  echo "       $manifest" >&2
  echo "       The build above should have created it — check its output." >&2
  exit 1
fi

manifest_floor="$(ios_floor "$manifest")"
if [[ -z "$manifest_floor" ]]; then
  echo "ERROR: could not read an .iOS(...) platform from the generated manifest:" >&2
  echo "       $manifest" >&2
  exit 1
fi

# The Runner and RunnerTests targets declare no IPHONEOS_DEPLOYMENT_TARGET of
# their own and inherit the project-level value, so the lowest value present is
# the binding one.
project_target=""
while IFS= read -r v; do
  [[ -z "$v" ]] && continue
  if [[ -z "$project_target" ]] || ver_gt "$project_target" "$v"; then
    project_target="$v"
  fi
done < <(grep -oE 'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+' "$pbxproj" | sed -E 's/.*= //' | sort -u)

# Highest floor any linked plugin demands — this is what the archive must clear.
max_floor=""
max_pkg=""
for pkg_manifest in "$packages_dir"/*/Package.swift; do
  [[ -f "$pkg_manifest" ]] || continue
  floor="$(ios_floor "$pkg_manifest")"
  [[ -z "$floor" ]] && continue
  if [[ -z "$max_floor" ]] || ver_gt "$floor" "$max_floor"; then
    max_floor="$floor"
    max_pkg="$(basename "$(dirname "$pkg_manifest")")"
  fi
done

# --- 3. report -------------------------------------------------------------
echo "==> iOS deployment floors"
printf '    %-34s %s\n' "Xcode project target" "${project_target:-<none found>}"
printf '    %-34s %s\n' "generated SwiftPM package" "$manifest_floor"
if [[ -n "$max_floor" ]]; then
  printf '    %-34s %s  (%s)\n' "highest plugin requirement" "$max_floor" "$max_pkg"
else
  printf '    %-34s %s\n' "highest plugin requirement" "<none declared>"
fi
echo

status=0

if [[ -n "$max_floor" ]] && ! ver_ge "$manifest_floor" "$max_floor"; then
  echo "FAIL: the generated package allows iOS $manifest_floor but '$max_pkg' needs $max_floor." >&2
  echo "      Xcode will refuse to resolve the package graph:" >&2
  echo "        \"requires minimum platform version $max_floor for the iOS platform," >&2
  echo "         but this target supports $manifest_floor\"" >&2
  echo >&2
  echo "      Raise the project's deployment target to $max_floor, then re-run this script:" >&2
  echo "        ios/Runner.xcodeproj/project.pbxproj  — all IPHONEOS_DEPLOYMENT_TARGET entries" >&2
  echo "        ios/Podfile                           — platform :ios, '$max_floor'" >&2
  status=1
fi

if [[ -n "$project_target" ]] && [[ "$manifest_floor" != "$project_target" ]]; then
  echo "WARNING: the generated package ($manifest_floor) doesn't match the project target ($project_target)." >&2
  echo "         After --config-only these must agree; a mismatch means Flutter's" >&2
  echo "         updateMinimumDeployment didn't apply (usually xcodebuild -showBuildSettings" >&2
  echo "         returning nothing). Re-run, or check the build output above." >&2
  echo >&2
fi

if [[ "$status" -ne 0 ]]; then
  exit "$status"
fi

# Informational: the Sentry pre-action patches IN_SENTRY_DSN into this line in
# place, so it has to exist before the archive starts. --config-only writes it.
if grep -q '^DART_DEFINES=' "$xcconfig" 2>/dev/null; then
  echo "==> DART_DEFINES present in ios/Flutter/Generated.xcconfig"
  echo "    (the Sentry DSN pre-action can patch it during the archive)"
else
  echo "WARNING: no DART_DEFINES line in ios/Flutter/Generated.xcconfig — the Sentry"
  echo "         DSN pre-action will no-op and the archive will ship with Sentry off."
fi
echo

if command -v pgrep >/dev/null 2>&1 && pgrep -x Xcode >/dev/null 2>&1; then
  echo "!!  Xcode is already running. It caches the resolved package graph, so"
  echo "    close and reopen ios/Runner.xcworkspace (or File > Packages > Reset"
  echo "    Package Caches) before archiving, or it will re-use the stale one."
  echo
fi

echo "Ready to archive.  In Xcode:  Product > Archive"
echo "(Re-run this after any 'flutter pub get' — it resets the manifest.)"
