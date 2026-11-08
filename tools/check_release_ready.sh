#!/usr/bin/env bash
set -euo pipefail

# Is the version in pubspec.yaml ready to release? deploy-all.yml runs this
# before anything is built; run it yourself before dispatching.
#
# Checks the two steps a release depends on that nothing else enforces at
# release time (docs/store-deployment-setup.md § 5 Per release):
#
#  1. The new release notes are written (docs/release-notes.md):
#     - lib/domain/release_notes.dart has an entry for the version — the What's
#       New dialog shows it after the update;
#     - the F-Droid changelogs exist, one per ABI versionCode (build x 10 +
#       1..3), non-empty and identical — the bump script doesn't write these.
#  2. tools/bump_client_version.sh has run:
#     - every file it writes names the same version (kClientVersion, the snap's
#       display version, the F-Droid recipe's CurrentVersion / Code, the Linux
#       metainfo's <release> entry — Flathub builds from the tag);
#     - no v<version> tag exists yet — re-releasing a version re-runs every
#       store into a duplicate-build rejection;
#     - the version and the build number are both above the newest tag's.
#
# Usage:
#   tools/check_release_ready.sh             # every check (reads origin's tags)
#   tools/check_release_ready.sh --offline   # skip the two tag checks
#
# Prints every failure, not just the first, and exits 1 if there was one.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

offline=false
case "${1:-}" in
  '') ;;
  --offline) offline=true ;;
  *) echo "usage: $0 [--offline]" >&2; exit 2 ;;
esac

failures=0
fail() {
  failures=$((failures + 1))
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::error::$1"
  else
    echo "!! $1" >&2
  fi
}

# --- The version being released: pubspec.yaml's MAJOR.MINOR.PATCH+BUILD ---
pubspec_line="$(sed -n 's/^version:[[:space:]]*\([^[:space:]]*\).*$/\1/p' pubspec.yaml)"
if [[ ! "$pubspec_line" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
  fail "pubspec.yaml's version '$pubspec_line' is not MAJOR.MINOR.PATCH+BUILD."
  exit 1
fi
version="${BASH_REMATCH[1]}"
build="${BASH_REMATCH[2]}"
echo "==> checking $version+$build"

# --- 1. The release notes ---
# The bump script's own match: an uncommented `version: 'X.Y.Z'` line.
notes="lib/domain/release_notes.dart"
if ! grep -qE "^[[:space:]]*(ReleaseNotes\()?version: '${version//./\\.}'" "$notes"; then
  fail "No release notes for $version: add its ReleaseNotes entry to the top of kReleaseNotes in $notes (docs/release-notes.md step 5)."
fi

changelogs="fastlane/metadata/android/en-US/changelogs"
first=""
missing=""
for abi in 1 2 3; do
  f="$changelogs/$((build * 10 + abi)).txt"
  if [[ ! -s "$f" ]]; then
    missing="$missing $((build * 10 + abi)).txt"
  elif [[ -z "$first" ]]; then
    first="$f"
  elif ! cmp -s "$first" "$f"; then
    fail "F-Droid changelogs $first and $f differ: the three per release are identical."
  fi
done
if [[ -n "$missing" ]]; then
  fail "Missing or empty F-Droid changelog(s) in $changelogs:$missing — write the release's digest to all three (docs/release-notes.md step 5)."
fi

# --- 2. The bump: every file it writes agrees with pubspec.yaml ---
bump_hint="run tools/bump_client_version.sh rather than editing versions by hand"

client="$(sed -n "s/.*kClientVersion = '\([^']*\)'.*/\1/p" lib/app/version.dart)"
if [[ "$client" != "$version" ]]; then
  fail "kClientVersion in lib/app/version.dart is '$client', not $version: $bump_hint."
fi

snap="$(sed -n "s/^version:[[:space:]]*'\([^']*\)'.*/\1/p" snap/snapcraft.yaml)"
if [[ "$snap" != "$version" ]]; then
  fail "snap/snapcraft.yaml's version is '$snap', not $version: $bump_hint."
fi

recipe="tools/foss/com.invoiceninja.admin.yml"
recipe_version="$(sed -n 's/^CurrentVersion:[[:space:]]*\(.*\)$/\1/p' "$recipe")"
recipe_code="$(sed -n 's/^CurrentVersionCode:[[:space:]]*\(.*\)$/\1/p' "$recipe")"
if [[ "$recipe_version" != "$version" || "$recipe_code" != "$((build * 10 + 3))" ]]; then
  fail "$recipe names $recipe_version ($recipe_code), not $version ($((build * 10 + 3))): $bump_hint."
fi

if ! python3 tools/metainfo_release.py --check "$version" 2>/dev/null; then
  fail "appimage/com.invoiceninja.admin.metainfo.xml has no <release> for $version: $bump_hint."
fi

# --- 2. The bump: the version is new, and above the newest release ---
if [[ "$offline" == true ]]; then
  echo "==> --offline: skipped the tag checks"
else
  # origin's tags, not the local ones — a clone's tags can lag GitHub's.
  tags="$(git ls-remote --tags --refs origin 'v*' | sed 's|.*refs/tags/||')"
  if grep -qxF "v$version" <<<"$tags"; then
    fail "v$version is already released: bump the version (tools/bump_client_version.sh) to cut a new release; to retry a failed store, re-run its failed job instead."
  fi

  latest="$(grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' <<<"$tags" | sort -V | tail -n1 || true)"
  if [[ -n "$latest" && "$latest" != "v$version" ]]; then
    if [[ "$(printf '%s\n%s\n' "${latest#v}" "$version" | sort -V | tail -n1)" != "$version" ]]; then
      fail "$version is below the newest release, $latest."
    fi
    # The tag's commit may not be in this clone; fetch it without making a ref.
    if ! git cat-file -e "$latest^{commit}" 2>/dev/null; then
      git fetch --quiet --no-tags origin "refs/tags/$latest" 2>/dev/null || true
      latest_ref=FETCH_HEAD
    else
      latest_ref="$latest"
    fi
    latest_line="$(git show "$latest_ref:pubspec.yaml" 2>/dev/null | sed -n 's/^version:[[:space:]]*\([^[:space:]]*\).*$/\1/p' || true)"
    latest_build="${latest_line#*+}"
    if [[ ! "$latest_build" =~ ^[0-9]+$ ]]; then
      fail "Could not read the build number from $latest's pubspec.yaml ('$latest_line')."
    elif (( build <= latest_build )); then
      fail "Build number $build is not above $latest's ($latest_build): the stores reject a reused one; $bump_hint."
    fi
    echo "==> newest release: $latest (build $latest_build)"
  fi
fi

if (( failures > 0 )); then
  echo "!! $failures check(s) failed — $version+$build is not ready to release" >&2
  exit 1
fi
echo "==> $version+$build is ready to release"
