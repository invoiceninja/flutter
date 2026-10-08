#!/usr/bin/env bash
# Builds the two release variants the web benchmark compares — the same
# entrypoint (benchmark/web_bench_main.dart), the same flags, and only the
# compiler differing:
#
#   <out>/js    dart2js   + CanvasKit   (flutter build web)
#   <out>/wasm  dart2wasm + skwasm      (flutter build web --wasm)
#
# Usage: tools/web_bench/build.sh [js|wasm|all]
#
#   BENCH_DIR   output directory            (default: build/bench)
#   BENCH_SRC   project to build            (default: this checkout)
#   BENCH_PORT  port the harness serves on  (default: 8791)
#
# The port is baked in: the app is pointed at the harness's own origin
# (IN_DEMO_API_URL), which replays recorded demo-server responses, so a
# measured run never touches the network. IN_DEMO_MODE=true blocks every
# write. Numbers meant for publication should come from a clean commit — point
# BENCH_SRC at an export (`git archive HEAD | tar -x -C <dir>`) when the
# working tree has edits in flight. Run `flutter pub get` there first.
#
# One build at a time, and nothing else running `flutter`: see
# docs/web-benchmarks.md.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
src="${BENCH_SRC:-$repo_root}"
out="${BENCH_DIR:-$repo_root/build/bench}"
port="${BENCH_PORT:-8791}"
which="${1:-all}"

sha="$(git -C "$repo_root" rev-parse --short HEAD)"
if [ -d "$src/.git" ] || [ -f "$src/.git" ]; then
  if [ -n "$(git -C "$src" status --porcelain -- lib packages pubspec.yaml pubspec.lock web)" ]; then
    tree="dirty"
  else
    tree="clean"
  fi
else
  tree="export"
fi

build() {
  local name="$1"
  shift
  echo "==> building $name ($sha, $tree) from $src"
  (
    cd "$src"
    flutter build web --release --no-pub \
      --no-web-resources-cdn \
      -t benchmark/web_bench_main.dart \
      --dart-define=IN_DEMO_API_TOKEN=TOKEN \
      --dart-define=IN_DEMO_API_URL="http://127.0.0.1:$port" \
      --dart-define=IN_DEMO_MODE=true \
      --dart-define=BENCH_GIT_SHA="$sha" \
      -o "$out/$name" \
      "$@"
  )
}

mkdir -p "$out"
case "$which" in
  js) build js --no-wasm-dry-run ;;
  wasm) build wasm --wasm ;;
  all)
    build js --no-wasm-dry-run
    build wasm --wasm
    ;;
  *)
    echo "usage: $0 [js|wasm|all]" >&2
    exit 2
    ;;
esac

cat > "$out/build.json" <<EOF
{
  "sha": "$sha",
  "tree": "$tree",
  "port": $port,
  "flutter": "$(flutter --version 2>/dev/null | sed -n 's/^Flutter \([0-9.]*\).*/\1/p')",
  "dart": "$(flutter --version 2>/dev/null | sed -n 's/.*Dart \([0-9.]*\).*/\1/p')",
  "builtAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
echo "==> done: $out"
