#!/usr/bin/env bash
set -euo pipefail

# Cache-bust a `flutter build web` output: stamp a content-hash `?v=` onto the
# app entrypoints (main.dart.{wasm,mjs,js}) that flutter_bootstrap.js loads, so
# a new build gets brand-new URLs no browser cache can satisfy. The engine files
# under canvaskit/ are versioned by the SDK and left alone.
#
# Usage: tools/stamp_web_cache_bust.sh <build/web dir>
# Prints the token on stdout (callers stamp their own page with it), progress
# on stderr. Idempotent: the pattern needs the closing quote right after the
# file name, which a stamped path no longer has. Portable (perl, not BSD or GNU
# `sed -i`), because it runs on macOS (tools/build_demo_web.sh) and on the
# Linux runner (.github/workflows/web.yml). docs/web-deploy.md.

dir="${1:?usage: tools/stamp_web_cache_bust.sh <build/web dir>}"
bootstrap="$dir/flutter_bootstrap.js"
[[ -f "$bootstrap" ]] || { echo "!! no $bootstrap" >&2; exit 1; }

entries=()
for f in main.dart.wasm main.dart.mjs main.dart.js; do
  [[ -f "$dir/$f" ]] && entries+=("$dir/$f")
done
[[ ${#entries[@]} -gt 0 ]] || { echo "!! no main.dart.* entrypoint in $dir" >&2; exit 1; }

sha256() { if command -v sha256sum >/dev/null; then sha256sum; else shasum -a 256; fi; }
token="$(cat "${entries[@]}" | sha256 | cut -c1-12)"

V="$token" perl -pi -e 's#"main\.dart\.(wasm|mjs|js)"#"main.dart.$1?v=$ENV{V}"#g' "$bootstrap"

# Fail loudly if a Flutter output change broke the rewrite, rather than ship an
# un-busted (cache-stale) build. Only check the entrypoints that were built.
for f in "${entries[@]}"; do
  name="$(basename "$f")"
  grep -q "\"$name?v=$token\"" "$bootstrap" \
    || { echo "!! cache-bust failed: $name not stamped in $bootstrap" >&2; exit 1; }
done

echo "==> cache-bust token: $token" >&2
echo "$token"
