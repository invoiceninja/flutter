#!/usr/bin/env bash
set -euo pipefail

# Follow one release onto Flathub, and say how far it got.
#
# Flathub builds the app itself, from flathub/com.invoiceninja.admin. That
# repo's own update workflow (hand-written there, never by an agent: Flathub's
# generative-AI policy, docs/flatpak.md) sees the new release within the hour,
# regenerates the offline sources and opens branch update-v<version> with
# auto-merge on. Flathub's bot test-builds the PR for x86_64 and aarch64, the
# merge publishes, and the listing shows the version a few hours later.
#
# This script only reads (public GitHub and Flathub APIs), so it needs no
# secret beyond the workflow's own GITHUB_TOKEN, for the API rate limit:
#
#   1. wait for the update PR to appear;
#   2. follow its checks: a failed test build fails this, with the PR link;
#   3. wait for the merge — or, if the checks pass and nobody has merged it,
#      finish with a warning naming the PR to merge;
#   4. wait a while for flathub.org to list the version; a merge it doesn't
#      list yet is still a success (publishing takes hours).
#
# Usage:
#   tools/follow_flathub_release.sh [version]     # default: pubspec's
#
# Run by .github/workflows/flathub.yml (Deploy to all's `flathub` leg). The
# waits come from the environment so a test can shorten them.

APP_ID="com.invoiceninja.admin"
REPO="${FLATHUB_REPO:-flathub/$APP_ID}"
APPSTREAM_URL="${FLATHUB_APPSTREAM_URL:-https://flathub.org/api/v2/appstream/$APP_ID}"
POLL_SECONDS="${FLATHUB_POLL_SECONDS:-120}"
PR_WAIT_MINUTES="${FLATHUB_PR_WAIT_MINUTES:-90}"     # the Flathub repo's cron is hourly
MERGE_WAIT_MINUTES="${FLATHUB_MERGE_WAIT_MINUTES:-210}" # two arches build, then auto-merge
PUBLISH_WAIT_MINUTES="${FLATHUB_PUBLISH_WAIT_MINUTES:-45}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

version="${1:-}"
if [[ -z "$version" ]]; then
  version="$(sed -n 's/^version:[[:space:]]*\([0-9]*\.[0-9]*\.[0-9]*\)+.*$/\1/p' "$repo_root/pubspec.yaml")"
fi
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: $0 [MAJOR.MINOR.PATCH] (pubspec gave '$version')" >&2
  exit 2
fi
branch="${FLATHUB_BRANCH:-update-v$version}"

summary() {
  echo "$1"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$1" >>"$GITHUB_STEP_SUMMARY"
  fi
}
annotate() { # level message
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::$1::$2"; else echo "$1: $2" >&2; fi
}

deadline() { echo $(($(date +%s) + $1 * 60)); }

if ! gh api "repos/$REPO" --silent 2>/dev/null; then
  annotate error "$REPO does not exist: the app is not on Flathub yet (docs/flatpak.md § Submitting)."
  exit 1
fi

# --- 1. The update PR ---
pr_json=""
until_pr="$(deadline "$PR_WAIT_MINUTES")"
while :; do
  pr_json="$(gh pr list -R "$REPO" --head "$branch" --state all --limit 1 \
    --json number,url,state 2>/dev/null || echo '[]')"
  [[ "$(jq length <<<"$pr_json")" -gt 0 ]] && break
  if (($(date +%s) >= until_pr)); then
    annotate error "No $branch PR on $REPO after $PR_WAIT_MINUTES min: run that repo's update workflow (Actions → Update), or check its last run."
    summary "Flathub: no update PR for $version yet. Check https://github.com/$REPO/actions"
    exit 1
  fi
  echo "Waiting for the $branch PR on $REPO..."
  sleep "$POLL_SECONDS"
done
number="$(jq -r '.[0].number' <<<"$pr_json")"
url="$(jq -r '.[0].url' <<<"$pr_json")"
echo "Update PR: $url"

# --- 2 + 3. Its test build, then the merge ---
until_merge="$(deadline "$MERGE_WAIT_MINUTES")"
checks_passed=false
while :; do
  state="$(gh pr view "$number" -R "$REPO" --json state --jq .state)"
  case "$state" in
    MERGED) break ;;
    CLOSED)
      annotate error "The Flathub update PR was closed without merging: $url"
      summary "Flathub: $version was not published; its update PR was closed. $url"
      exit 1
      ;;
  esac
  # `gh pr checks` exits non-zero while checks are pending or failed, so read
  # the buckets rather than the exit code.
  buckets="$(gh pr checks "$number" -R "$REPO" --json bucket --jq '.[].bucket' 2>/dev/null || true)"
  if grep -qx fail <<<"$buckets"; then
    annotate error "Flathub's test build failed: $url (fix it in $REPO, never by re-tagging; docs/flatpak.md)."
    summary "Flathub: the test build for $version failed. $url"
    exit 1
  fi
  if [[ -n "$buckets" ]] && ! grep -qvx -e pass -e skipping <<<"$buckets"; then
    checks_passed=true
  fi
  if (($(date +%s) >= until_merge)); then
    if $checks_passed; then
      annotate warning "Flathub's test build passed but the PR is not merged yet: merge $url to publish $version."
      summary "Flathub: $version built on both architectures; merge $url to publish it."
      exit 0
    fi
    annotate error "Flathub's test build for $version had not finished after $MERGE_WAIT_MINUTES min: $url"
    summary "Flathub: the test build for $version is still running. $url"
    exit 1
  fi
  echo "PR #$number: $(tr "[:upper:]" "[:lower:]" <<<"$state"), checks: $(tr '\n' ' ' <<<"${buckets:-none yet}")"
  sleep "$POLL_SECONDS"
done
echo "Merged: $url"

# --- 4. The listing ---
until_publish="$(deadline "$PUBLISH_WAIT_MINUTES")"
while :; do
  listed="$(curl -fsSL "$APPSTREAM_URL" 2>/dev/null | jq -r '.releases[0].version // empty' 2>/dev/null || true)"
  if [[ "$listed" == "$version" ]]; then
    summary "Flathub: $version is published. https://flathub.org/apps/$APP_ID"
    exit 0
  fi
  if (($(date +%s) >= until_publish)); then
    summary "Flathub: $version is merged ($url) and publishing; flathub.org still lists ${listed:-nothing}. Publishing usually takes a few hours."
    exit 0
  fi
  echo "Waiting for flathub.org to list $version (lists ${listed:-nothing})..."
  sleep "$POLL_SECONDS"
done
