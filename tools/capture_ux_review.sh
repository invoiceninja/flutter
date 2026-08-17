#!/usr/bin/env bash
set -euo pipefail

# Capture a UX-review sweep of the real app across viewports / platforms /
# themes / text scales / locales.
#
# Boots the app on web against demo.invoiceninja.com (the same baked-token
# bootstrap the public web demo uses) and writes one PNG per stop into
# $UX_OUT_DIR, driven by integration_test/ux_review_test.dart +
# test_driver/ux_review_driver.dart.
#
# WHY WEB: the integration_test plugin only implements takeScreenshot for
# Android/iOS/web — there is no macOS plugin. Web is the only desktop-class,
# permission-free target, and it runs headless so it never takes over the
# foreground app.
#
# WRITE SAFETY: passes IN_DEMO_MODE=true, so ApiClient throws
# DemoModeException on every non-GET. The tour opens editors and menus; without
# this it could write to the shared live demo account.
#
# PREREQUISITE: a chromedriver matching your Chrome major version on :4444.
# Not a package-manager install — fetch the standalone binary:
#   https://googlechromelabs.github.io/chrome-for-testing/
#   chromedriver --port=4444
#
# Usage:
#   tools/capture_ux_review.sh [pass ...]
#
# With no arguments runs the default matrix. A pass is
# "VIEWPORT:PLATFORM:THEME:SCALEx100:LOCALE", e.g. "390x844:android:dark:140:de".

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

demo_token="${IN_DEMO_API_TOKEN:-TOKEN}"
demo_url="${IN_DEMO_API_URL:-https://demo.invoiceninja.com}"
export UX_OUT_DIR="${UX_OUT_DIR:-build/ux-review}"

if ! curl -s -m 3 -o /dev/null "http://localhost:4444/status"; then
  echo "!! chromedriver is not reachable on :4444." >&2
  echo "   Start it in another terminal first:  chromedriver --port=4444" >&2
  exit 1
fi

# Default matrix. Note 360 and 390 are NOT both here — both sit below
# Breakpoints.wide (600), so they exercise the identical layout branch. The
# widths that earn a slot are the ones straddling a real breakpoint:
#   600  Breakpoints.wide            (sidebar appears; InSpacing md/lg step up)
#   880  Breakpoints.settingsTwoPane (settings sidebar vs redirect — these two
#                                     sites must agree or the band strands the
#                                     user on a page with no menu)
#   1000 entityFormMultiColumn
#   1024 slideOver
default_passes=(
  "390x844:android:light:100:en"      # phone, touch sizing
  "390x844:android:dark:100:en"       # phone, dark
  "390x844:android:light:140:en"      # phone, app-max text scale
  "390x844:android:light:100:de"      # phone, longest-string locale
  "844x390:android:light:100:en"      # landscape phone — crosses `wide` (600)
  "820x1180:ios:light:100:en"         # iPad portrait — past 600, under 1000
  "879x800:ios:light:100:en"          # just under settingsTwoPane
  "881x800:ios:light:100:en"          # just over settingsTwoPane
  "1440x900::light:100:en"            # laptop, real pointer metrics
  "1440x900::dark:100:en"             # laptop, dark
  "1440x900::light:140:de"            # laptop, worst-case text + strings
)

passes=("$@")
if [ ${#passes[@]} -eq 0 ]; then
  passes=("${default_passes[@]}")
fi

mkdir -p "$UX_OUT_DIR"
echo "==> writing to $UX_OUT_DIR"

for pass in "${passes[@]}"; do
  IFS=':' read -r viewport platform theme scale locale <<< "$pass"
  echo ""
  echo "=============================================================="
  echo "==> $viewport  platform='${platform:-pointer}'  $theme  ${scale}%  $locale"
  echo "=============================================================="

  # --browser-dimension must match UX_VIEWPORT: the test sets the same logical
  # surface, and any mismatch makes the binding scale + letterbox the capture.
  flutter drive \
    --driver=test_driver/ux_review_driver.dart \
    --target=integration_test/ux_review_test.dart \
    -d web-server \
    --browser-name=chrome \
    --browser-dimension="$viewport" \
    --dart-define=IN_DEMO_API_TOKEN="$demo_token" \
    --dart-define=IN_DEMO_API_URL="$demo_url" \
    --dart-define=IN_DEMO_MODE=true \
    --dart-define=UX_VIEWPORT="$viewport" \
    --dart-define=UX_PLATFORM="$platform" \
    --dart-define=UX_THEME="$theme" \
    --dart-define=UX_TEXT_SCALE_X100="$scale" \
    --dart-define=UX_LOCALE="$locale" \
    || echo "!! pass failed: $pass (continuing)"
done

echo ""
echo "==> done. Captured:"
ls -1 "$UX_OUT_DIR" | head -50
echo "    ($(ls -1 "$UX_OUT_DIR" | wc -l | tr -d ' ') files)"
