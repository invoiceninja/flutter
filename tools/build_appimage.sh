#!/usr/bin/env bash
set -euo pipefail

# Build a Linux AppImage with the Sentry DSN baked in.
#
# Companion to tools/build_release.sh: that script compiles the per-platform
# release artifacts (incl. a compile-only `linux`); this one compiles Linux AND
# packages the result into a distributable AppImage via linuxdeploy + the gtk
# plugin. Sentry error reporting is wired in the app (lib/main.dart +
# lib/app/env.dart `Env.sentryDsn`); it activates only in release/profile builds
# when a non-empty IN_SENTRY_DSN is passed at compile time, so this script
# resolves the DSN and injects it via a single `--dart-define`, exactly like
# .github/workflows/snapcraft.yml and tools/build_release.sh.
#
# DSN resolution order (mirrors build_release.sh):
#   1. the IN_SENTRY_DSN environment variable (CI / explicit override), else
#   2. the IN_SENTRY_DSN key in dev.json (gitignored local config), else
#   3. empty -> Sentry stays disabled (safe no-op; Env.sentryDsn defaults to '').
#
# Linux-only: Flutter can't cross-compile Linux from macOS. CI runs this on
# ubuntu-22.04 (.github/workflows/appimage.yml) so the AppImage links glibc 2.35,
# matching the snap's core22 floor for broad distro compatibility.
#
# Usage:
#   tools/build_appimage.sh [--codegen]
#
#   --codegen   Run `dart run build_runner build --delete-conflicting-outputs`
#               first (off by default; assumes generated files are current).
#               `flutter pub get` is a prerequisite either way — CI runs both as
#               separate steps before calling this script.
#
# Env overrides:
#   IN_SENTRY_DSN     baked into the binary (see resolution order above)
#   APPIMAGE_VERSION  output/version override (else parsed from pubspec.yaml);
#                     CI sets this so the asset filename and the git tag agree
#   GTK_PLUGIN_REF    git ref of linuxdeploy-plugin-gtk to fetch (default: master;
#                     pin to a commit SHA for reproducibility)
#
# Reproducibility: tool downloads are verified against appimage/tool-checksums.sha256
# when that file has entries; otherwise the computed hashes are printed and
# verification is skipped (pin them by copying the printed lines into that file).

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dev_json="$repo_root/dev.json"

print_usage() {
  sed -n '4,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# --- parse args ---
run_codegen=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    -g|--codegen) run_codegen=1; shift ;;
    *) echo "ERROR: unknown argument '$1'" >&2; print_usage; exit 1 ;;
  esac
done

# --- Linux-only guard (Flutter can't cross-compile Linux from macOS) ---
if [[ "$(uname)" != "Linux" ]]; then
  echo "ERROR: build_appimage.sh only runs on Linux (CI builds it on ubuntu-22.04)." >&2
  echo "       On macOS, dispatch .github/workflows/appimage.yml instead." >&2
  exit 1
fi

# --- resolve the Sentry DSN (env > dev.json > empty) ---
dsn=""
dsn_source=""
if [[ -n "${IN_SENTRY_DSN:-}" ]]; then
  dsn="$IN_SENTRY_DSN"
  dsn_source="environment (IN_SENTRY_DSN)"
elif [[ -f "$dev_json" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    dsn="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("IN_SENTRY_DSN",""))' "$dev_json" 2>/dev/null || true)"
  fi
  # Fallback (python3 missing / failed): parse the flat "IN_SENTRY_DSN": "<value>" line.
  if [[ -z "$dsn" ]]; then
    dsn="$(grep -oE '"IN_SENTRY_DSN"[[:space:]]*:[[:space:]]*"[^"]*"' "$dev_json" 2>/dev/null \
             | head -n1 \
             | sed -E 's/.*"IN_SENTRY_DSN"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' || true)"
  fi
  [[ -n "$dsn" ]] && dsn_source="dev.json"
fi

if [[ -z "$dsn" ]]; then
  echo "WARNING: IN_SENTRY_DSN is empty (not in environment or dev.json)."
  echo "         Building with Sentry DISABLED — safe no-op (Env.sentryDsn defaults to '')."
else
  # Never print the DSN value itself — just where it came from.
  echo "==> Sentry DSN resolved from: $dsn_source"
fi

# --- derive the version (APPIMAGE_VERSION override > pubspec) ---
# pubspec `version: 5.1.4+7` -> 5.1.4 (strip label, quotes, +build, CR).
if [[ -n "${APPIMAGE_VERSION:-}" ]]; then
  version="$APPIMAGE_VERSION"
else
  version="$(grep -m1 '^version:' "$repo_root/pubspec.yaml")"
  version="${version#*version:}"        # after "version:"
  version="${version//[\"\' ]/}"        # drop quotes + spaces
  version="${version%%+*}"              # drop +build
  version="${version%$'\r'}"            # drop trailing CR
fi
if [[ -z "$version" ]]; then
  echo "ERROR: could not determine version (set APPIMAGE_VERSION or check pubspec.yaml)." >&2
  exit 1
fi
echo "==> AppImage version: $version"

# --- paths ---
work="$repo_root/build/appimage"
appdir="$work/AppDir"
tools_dir="$work/tools"
bundle="$repo_root/build/linux/x64/release/bundle"
output="$work/InvoiceNinja-${version}-x86_64.AppImage"

cd "$repo_root"

# --- optional codegen + the Flutter Linux build (this script owns the build) ---
if [[ "$run_codegen" -eq 1 ]]; then
  echo "==> dart run build_runner build --delete-conflicting-outputs"
  dart run build_runner build --delete-conflicting-outputs
fi

echo "==> flutter build linux --release (Sentry: $([[ -n "$dsn" ]] && echo enabled || echo disabled))"
flutter config --enable-linux-desktop >/dev/null
set -x
flutter build linux --release --dart-define=IN_SENTRY_DSN="$dsn"
set +x

# --- clean slate (a stale AppDir must not merge into a re-run) ---
rm -rf "$appdir" "$work"/InvoiceNinja-*-x86_64.AppImage "$work/squashfs-root"
mkdir -p "$appdir/usr/bin" "$appdir/usr/share/metainfo" "$tools_dir"

# --- assemble the AppDir ---
# Flutter resolves lib/libapp.so + data/ relative to /proc/self/exe, and the
# runner sets RPATH=$ORIGIN/lib, so admin + lib/ + data/ must live together in
# usr/bin/. Pre-place only lib/ + data/; linuxdeploy places `admin` itself.
cp -r "$bundle/lib"  "$appdir/usr/bin/"
cp -r "$bundle/data" "$appdir/usr/bin/"

# linuxdeploy has no metainfo flag — install it ourselves, then stamp the real
# version/date into the AppDir COPY ONLY (never the tracked source -> no drift).
install -Dm644 "$repo_root/appimage/com.invoiceninja.admin.metainfo.xml" \
  "$appdir/usr/share/metainfo/com.invoiceninja.admin.metainfo.xml"
sed -i -E "s|<release[^/]*/>|<release version=\"$version\" date=\"$(date +%F)\"/>|" \
  "$appdir/usr/share/metainfo/com.invoiceninja.admin.metainfo.xml"

# crashpad_handler (sentry_flutter) is installed mode 0644 by Flutter's
# linux/CMakeLists.txt; without +x, posix_spawn of the handler fails with EACCES
# at runtime and the app crashes on startup when Sentry is enabled. The
# install(PROGRAMS) fix in linux/CMakeLists.txt handles the source bundle; this is
# belt-and-suspenders so the AppImage is correct even if that ever regresses.
find "$appdir" -name crashpad_handler -exec chmod 0755 {} +

# Keep GIO from dlopen-ing the HOST's gvfs/gio modules (built against a newer glib
# than the bundled 2.72) — that prints "undefined symbol: g_task_set_static_name"
# on newer hosts. Point GIO at a bundled (empty) module dir via an AppRun hook;
# linuxdeploy's AppRun sources apprun-hooks/* with $APPDIR set at launch.
mkdir -p "$appdir/usr/lib/gio/modules" "$appdir/apprun-hooks"
cat > "$appdir/apprun-hooks/99-gio-modules.sh" <<'HOOK'
export GIO_MODULE_DIR="$APPDIR/usr/lib/gio/modules"
export GIO_USE_VFS=local
HOOK

# --- fetch the packaging tools + the AppImage runtime ---
# linuxdeploy + the appimage output plugin ship only a rolling `continuous` tag;
# the gtk plugin is a raw script (pin GTK_PLUGIN_REF to a commit for repro);
# appimagetool would otherwise download the runtime at build time, so we pin it.
gtk_ref="${GTK_PLUGIN_REF:-master}"
fetch() {  # fetch <url> <dest>
  echo "==> downloading $(basename "$2")"
  curl -fSL --retry 3 -o "$2" "$1"
}
fetch "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" \
      "$tools_dir/linuxdeploy-x86_64.AppImage"
fetch "https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-x86_64.AppImage" \
      "$tools_dir/linuxdeploy-plugin-appimage-x86_64.AppImage"
fetch "https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/${gtk_ref}/linuxdeploy-plugin-gtk.sh" \
      "$tools_dir/linuxdeploy-plugin-gtk.sh"
fetch "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64" \
      "$tools_dir/runtime-x86_64"
chmod +x "$tools_dir/linuxdeploy-x86_64.AppImage" \
         "$tools_dir/linuxdeploy-plugin-appimage-x86_64.AppImage" \
         "$tools_dir/linuxdeploy-plugin-gtk.sh"

# --- verify tool integrity (pin via appimage/tool-checksums.sha256) ---
checksums="$repo_root/appimage/tool-checksums.sha256"
echo "==> tool checksums:"
( cd "$tools_dir" && sha256sum -- * )
if [[ -f "$checksums" ]] && grep -qvE '^[[:space:]]*(#|$)' "$checksums"; then
  echo "==> verifying tools against appimage/tool-checksums.sha256"
  ( cd "$tools_dir" && grep -vE '^[[:space:]]*(#|$)' "$checksums" | sha256sum -c - )
else
  echo "WARNING: appimage/tool-checksums.sha256 has no entries — skipping verification."
  echo "         Pin the build by copying the hashes above into that file."
fi

# --- package ---
cd "$work"
export PATH="$tools_dir:$PATH"
export APPIMAGE_EXTRACT_AND_RUN=1   # ubuntu-22.04 has no libfuse2; also covers --appimage-extract
export ARCH=x86_64                  # appimagetool can't auto-detect under extract-and-run
export DEPLOY_GTK_VERSION=3
export NO_STRIP=1                   # don't strip the bundled engine libs
export LINUXDEPLOY_OUTPUT_VERSION="$version"
export LDAI_OUTPUT="InvoiceNinja-${version}-x86_64.AppImage"
export LDAI_NO_APPSTREAM=1          # don't let a metainfo warning abort packaging
export LDAI_RUNTIME_FILE="$tools_dir/runtime-x86_64"

set -x
linuxdeploy-x86_64.AppImage --appdir "$appdir" \
  --executable "$bundle/admin" \
  --desktop-file "$repo_root/appimage/com.invoiceninja.admin.desktop" \
  --icon-file "$repo_root/snap/gui/invoiceninja.png" --icon-filename com.invoiceninja.admin \
  --plugin gtk --output appimage
set +x

# --- verify the output exists ---
if [[ ! -f "$output" ]]; then
  echo "ERROR: expected $output but it was not produced." >&2
  exit 1
fi
chmod +x "$output"
echo "==> built $output"
