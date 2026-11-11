#!/usr/bin/env bash
set -euo pipefail

# Build (and optionally deploy) the pre-authenticated demo web app.
#
# Produces the Flutter WASM web build, based at /admin/ for GitHub Pages and
# pre-authenticated against demo.invoiceninja.com via the public system token
# `TOKEN` (see docs/probing-the-demo-api.md). On a fresh browser the build
# boots straight to the dashboard instead of /login — see `Env.demoApiToken`
# and the bootstrap hook in lib/main.dart.
#
# Usage:
#   tools/build_demo_web.sh [deploy_dir]
#
#   deploy_dir   Directory to rsync build/web/ into. Defaults to the sibling
#                checkout ../hillelcoren.github.io/admin. Pass "-" to build
#                only and skip the deploy.
#
# After deploying, commit & push the deploy repo to publish (GitHub Pages).

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

deploy_dir="${1:-$repo_root/../hillelcoren.github.io/admin}"

echo "==> flutter build web --wasm (demo, base-href /admin/)"
# --no-web-resources-cdn bundles the CanvasKit/skwasm engine into build/web/
# (served from /admin/) instead of fetching it from www.gstatic.com at runtime,
# so the demo loads entirely from our own origin.
flutter build web --wasm --release \
  --no-web-resources-cdn \
  --base-href /admin/ \
  --dart-define=IN_DEMO_API_TOKEN=TOKEN

# Cache-bust the app entrypoints so a single browser refresh picks up a new
# deploy. GitHub Pages serves every file with `Cache-Control: max-age=600` and
# can't set custom headers, and the Flutter entry files have fixed names — so a
# fresh deploy would otherwise stay hidden behind the browser cache for up to
# 10 minutes. Stamp a content-hash token onto `flutter_bootstrap.js` and the app
# entrypoints (main.dart.{wasm,mjs,js}) as a `?v=` query: a new build yields
# brand-new URLs no cache can satisfy, so one refresh — which revalidates
# index.html via the Pages ETag — loads the new bootstrap + app code. The engine
# files under canvaskit/ are immutable per Flutter SDK, so they're left as-is
# (busting them every deploy would force a needless multi-MB re-download).
# The bootstrap half is shared with Deploy to Web (tools/stamp_web_cache_bust.sh);
# index.html is the demo's own page, so its stamp stays here.
token="$("$repo_root/tools/stamp_web_cache_bust.sh" build/web)"
V="$token" perl -pi -e 's#src="flutter_bootstrap\.js"#src="flutter_bootstrap.js?v=$ENV{V}"#' \
  build/web/index.html
# Fail loudly if a future Flutter output change breaks the rewrite above,
# rather than silently shipping an un-busted (cache-stale) build.
grep -q "src=\"flutter_bootstrap.js?v=$token\"" build/web/index.html \
  || { echo "!! cache-bust failed: index.html not stamped" >&2; exit 1; }

if [[ "$deploy_dir" == "-" ]]; then
  echo "==> build complete — build/web/ (deploy skipped)"
  exit 0
fi

if [[ ! -d "$deploy_dir" ]]; then
  echo "!! deploy dir not found: $deploy_dir" >&2
  echo "   build is in build/web/ — copy it manually or pass a valid path." >&2
  exit 1
fi

echo "==> deploying to $deploy_dir"
rsync -a --delete "$repo_root/build/web/" "$deploy_dir/"

# GitHub Pages runs Jekyll, which drops files whose names start with "_" —
# including assets/i18n/_app_pending.json (app-local strings). A .nojekyll at
# the Pages repo root disables Jekyll. Warn if it is missing.
pages_root="$(cd "$deploy_dir/.." && pwd)"
if [[ ! -f "$pages_root/.nojekyll" ]]; then
  echo "!! WARNING: $pages_root/.nojekyll is missing." >&2
  echo "   GitHub Pages will strip _app_pending.json and untranslated keys" >&2
  echo "   will render raw. Create an empty .nojekyll at that repo root." >&2
fi

echo "==> done. To publish, commit & push the deploy repo:"
echo "     git -C \"$pages_root\" add ."
echo "     git -C \"$pages_root\" commit -m 'Update admin demo build'"
echo "     git -C \"$pages_root\" push"
