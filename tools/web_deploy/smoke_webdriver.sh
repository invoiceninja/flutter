#!/usr/bin/env bash
set -euo pipefail

# Deploy to Web's boot smoke: load <url> in headless Chrome and wait for the
# app's first frame (web/index.html and the boot page set
# window.__flutterFirstFrame on `flutter-first-frame`).
#
# Usage: tools/web_deploy/smoke_webdriver.sh <url> [timeout_seconds]
#
# Drives ChromeDriver over the W3C WebDriver API with curl + jq, so it needs no
# npm or pip: the GitHub ubuntu runner ships Chrome and ChromeDriver
# ($CHROMEWEBDRIVER). Prints the time to first frame, or the browser's console
# errors when it never comes, and exits non-zero then. docs/web-deploy.md.

url="${1:?usage: smoke_webdriver.sh <url> [timeout_seconds]}"
timeout="${2:-120}"
port="${CHROMEDRIVER_PORT:-9515}"

driver="${CHROMEDRIVER:-}"
if [[ -z "$driver" && -n "${CHROMEWEBDRIVER:-}" ]]; then driver="$CHROMEWEBDRIVER/chromedriver"; fi
if [[ -z "$driver" ]]; then driver="$(command -v chromedriver || true)"; fi
[[ -x "$driver" ]] || { echo "!! no chromedriver (set CHROMEDRIVER or CHROMEWEBDRIVER)" >&2; exit 2; }

"$driver" --port="$port" >/dev/null 2>&1 &
driver_pid=$!
session=""
cleanup() {
  if [[ -n "$session" ]]; then
    curl -s -X DELETE "http://127.0.0.1:$port/session/$session" >/dev/null || true
  fi
  kill "$driver_pid" 2>/dev/null || true
}
trap cleanup EXIT

wd() { # method path [json]
  curl -s -X "$1" "http://127.0.0.1:$port$2" -H 'Content-Type: application/json' ${3:+-d "$3"}
}

for _ in $(seq 1 50); do
  wd GET /status | jq -e '.value.ready' >/dev/null 2>&1 && break
  sleep 0.2
done

# SwiftShader stands in for the GPU the runner doesn't have; recent Chrome no
# longer falls back to it on its own, and both renderers draw through WebGL.
caps='{"capabilities":{"alwaysMatch":{"browserName":"chrome","goog:loggingPrefs":{"browser":"ALL"},
  "goog:chromeOptions":{"args":["--headless=new","--no-sandbox","--disable-dev-shm-usage",
  "--enable-unsafe-swiftshader","--use-angle=swiftshader","--window-size=1280,900"]}}}}'
session="$(wd POST /session "$caps" | jq -r '.value.sessionId // empty')"
[[ -n "$session" ]] || { echo "!! could not start a ChromeDriver session" >&2; exit 2; }

start=$(date +%s)
wd POST "/session/$session/url" "$(jq -n --arg u "$url" '{url:$u}')" >/dev/null

painted=false
while (($(date +%s) - start < timeout)); do
  if [[ "$(wd POST "/session/$session/execute/sync" \
      '{"script":"return !!window.__flutterFirstFrame","args":[]}' | jq -r '.value')" == "true" ]]; then
    painted=true
    break
  fi
  sleep 1
done
elapsed=$(($(date +%s) - start))

errors="$(wd POST "/session/$session/se/log" '{"type":"browser"}' \
  | jq -r '.value[]? | select(.level == "SEVERE") | .message' 2>/dev/null || true)"

if $painted; then
  echo "First frame after ${elapsed}s: $url"
  [[ -n "$errors" ]] && { echo "Console errors (not fatal):"; echo "$errors" | head -20; }
  exit 0
fi
echo "!! No first frame after ${timeout}s: $url" >&2
if [[ -n "$errors" ]]; then echo "Console errors:" >&2; echo "$errors" | head -40 >&2; fi
exit 1
