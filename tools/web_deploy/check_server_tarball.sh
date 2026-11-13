#!/usr/bin/env bash
set -euo pipefail

# The listing checks the backend's react_release.yml runs before it unpacks
# the self-hosted tarball (docs/web-deploy.md § Going live), run here first so
# a build the server would refuse fails this workflow instead of shipping a
# server release without the new app. Keep the patterns identical to the
# backend's; a new kind of asset (say .riv) needs its extension there first.
#
# Usage: tools/web_deploy/check_server_tarball.sh <invoiceninja-web-x.y.z.tar.gz>

archive="${1:?usage: check_server_tarball.sh <archive>}"
fail() { echo "!! $1" >&2; exit 1; }

tar -tvzf "$archive" | awk '$1 !~ /^[-d]/ { bad = 1 } END { exit bad }' \
  || fail "a link or a special file"
if tar -tzf "$archive" | grep -E '(^|/)\.\.?(/|$)'; then
  fail "a relative path"
fi
if tar -tzf "$archive" | grep -Ev '^(public/|resources/|resources/views/|resources/views/(flutter|landing)/|resources/views/(flutter|landing)/index\.html|public/(flutter|landing)/.*)$'; then
  fail "files outside the four paths"
fi
if tar -tzf "$archive" | grep -E '^public/' | grep -Ev '/$' | grep -Eiv '(/[^/.]+|/\.gitkeep|\.(js|mjs|wasm|json|css|png|jpg|jpeg|gif|webp|svg|ico|ttf|otf|woff|woff2|frag|bin|txt|map))$'; then
  fail "a file type the server doesn't accept under public/"
fi
if tar -tzf "$archive" | grep -Ei '\.(php[0-9]?|pht|phtml|phar|phps|cgi|pl|shtml)(\.|/|$)'; then
  fail "a file the web server could execute"
fi
if tar -tzf "$archive" | grep -E '/\.' | grep -Ev '/\.gitkeep$'; then
  fail "a dotfile"
fi
for part in public/flutter/flutter_bootstrap.js resources/views/flutter/index.html resources/views/landing/index.html; do
  tar -tzf "$archive" | grep -qx "$part" || fail "no $part"
done
echo "The server will accept $archive."
