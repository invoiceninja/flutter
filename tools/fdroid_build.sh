#!/usr/bin/env bash
# Builds, signs and checks the F-Droid APKs the way F-Droid itself will: the
# real `fdroid build`, running tools/foss/com.invoiceninja.admin.yml inside
# F-Droid's own buildserver image. F-Droid publishes our signed APK only when
# its rebuild matches it byte-for-byte, so the recipe is the only build
# definition — see docs/fdroid.md § The F-Droid APK is built by F-Droid's own
# tooling.
#
#   tools/fdroid_build.sh lint
#   tools/fdroid_build.sh build <abi> [--vary] [--commit <sha>]
#   tools/fdroid_build.sh sign <abi> <unsigned.apk> <out-dir>
#   tools/fdroid_build.sh compare <signed.apk> <unsigned.apk>
#
# <abi> is armeabi-v7a, arm64-v8a or x86_64.
#
#   lint     `fdroid lint` + `fdroid rewritemeta` on the recipe, as fdroiddata's
#            CI runs them on a merge request.
#   build    the unsigned APK for one ABI, from <sha> (default: HEAD, which must
#            be pushed — fdroid clones the recipe's Repo), into
#            build/fdroid/<abi>[-vary]/, plus toolchain.txt. --vary changes the
#            CPU count, timezone, umask and hostname, so a second build proves
#            the first did not depend on them.
#   sign     signs on the host, never in the image. FDROID_KEYSTORE_BASE64,
#            FDROID_KEYSTORE_PASSWORD, FDROID_KEY_ALIAS and FDROID_KEY_PASSWORD
#            give the real key, which must match the recipe's
#            AllowedAPKSigningKeys; without them an ephemeral key is used and
#            the output is marked unpublishable.
#   compare  fdroidserver's own verify_apks: copy the signature onto the
#            unsigned APK and verify it — exactly F-Droid's publish check.
#
# lint, build and compare need Docker on a Linux x86_64 host (an arm64 Mac
# emulates, which is far too slow for build). sign needs the Android SDK.
set -euo pipefail

cd "$(dirname "$0")/.."

# Pins — bumped together (docs/fdroid.md § Bumping the F-Droid toolchain).
IMAGE="registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie@sha256:9cb68105642ca4e7b295f0ceab10f069f5b3247dc18fa7c36046e9d81aa469a8"
FDROIDSERVER_COMMIT=5806784d0d43bed7b938fd4b327162da68927060
FDROIDDATA_COMMIT=971da25ed6f9d099eb9b07124916e57cbafc1675
# apksigner < 35 has no --alignment-preserved; >= 35 without it re-pads every
# entry, and the signature no longer copies onto F-Droid's unsigned build.
BUILD_TOOLS=35.0.0

APPID=com.invoiceninja.admin
RECIPE="tools/foss/$APPID.yml"
OUT=build/fdroid

die() {
  echo "fdroid_build.sh: $*" >&2
  exit 1
}

# The ABI digit in the split APKs' versionCode, build * 10 + digit: abiCodes in
# android/app/build.gradle.kts.
abi_code() {
  case "$1" in
    armeabi-v7a) echo 1 ;;
    arm64-v8a) echo 2 ;;
    x86_64) echo 3 ;;
    *) die "unknown ABI '$1' (armeabi-v7a, arm64-v8a or x86_64)" ;;
  esac
}

# pubspec.yaml's `version: 5.1.15+18` -> "5.1.15" / "18".
pubspec_version() {
  local raw
  raw="$(grep -m1 '^version:' pubspec.yaml)"
  raw="${raw#version:}"
  raw="${raw//[\"\' ]/}"
  raw="${raw%$'\r'}"
  case "$1" in
    name) echo "${raw%%+*}" ;;
    code) echo "${raw#*+}" ;;
  esac
}

# The `binary:` URL of the recipe block that outputs <abi>'s APK. fdroid
# rewritemeta puts a long value on the line after its key, so read either.
recipe_binary() {
  awk -v abi="$1" '
    /^  - versionName:/ { if (out ~ "/app-" abi "-release\\.apk$") print bin; out = ""; bin = "" }
    /^    output: / { out = $2 }
    wrapped { bin = $1; wrapped = 0 }
    /^    binary:/ { if (NF > 1) bin = $2; else wrapped = 1 }
    END { if (out ~ "/app-" abi "-release\\.apk$") print bin }
  ' "$RECIPE"
}

recipe_signing_key() {
  sed -n -E 's/^AllowedAPKSigningKeys: (.+)$/\1/p' "$RECIPE"
}

# Shared by every container: fdroidserver at the pinned commit, and a scratch
# fdroiddata tree at /home/vagrant — the production buildserver's layout, with
# fdroiddata's own config/ (lint validates Categories against it) and its
# flutter srclib, both at the pinned commit.
CONTAINER_PREAMBLE='
set -euo pipefail
source /etc/profile.d/bsenv.sh
# Checkouts below end up owned by vagrant while root reads them.
git config --global --add safe.directory "*"
rm -rf "$fdroidserver"
git clone -q --filter=blob:none https://gitlab.com/fdroid/fdroidserver.git "$fdroidserver"
git -C "$fdroidserver" -c advice.detachedHead=false checkout -q "$FDROIDSERVER_COMMIT"
export PATH="$fdroidserver:$PATH" PYTHONPATH="$fdroidserver:$fdroidserver/examples"
export PYTHONUNBUFFERED=true
data="$home_vagrant"
git init -q /tmp/fdroiddata
git -C /tmp/fdroiddata remote add origin https://gitlab.com/fdroid/fdroiddata.git
git -C /tmp/fdroiddata fetch -q --depth 1 --filter=blob:none origin "$FDROIDDATA_COMMIT"
git -C /tmp/fdroiddata checkout -q FETCH_HEAD -- config srclibs/flutter.yml
mkdir -p "$data"/{metadata,srclibs,tmp,unsigned,logs,.android,.gradle}
cp -R /tmp/fdroiddata/config "$data/"
cp /tmp/fdroiddata/srclibs/flutter.yml "$data/srclibs/"
: > "$data/config.yml"
cp /work/recipe.yml "$data/metadata/$APPID.yml"
cd "$data"
'

# The checks a fdroiddata merge request runs, so a recipe that would fail
# review fails here first.
CONTAINER_LINT='
fdroid lint "$APPID"
cp "metadata/$APPID.yml" /tmp/before.yml
fdroid rewritemeta "$APPID"
if ! diff -u /tmp/before.yml "metadata/$APPID.yml"; then
  echo "fdroid rewritemeta reformats the recipe (diff above) — apply it to $RECIPE" >&2
  exit 1
fi
cp /work/recipe.yml "metadata/$APPID.yml"
'

run_image() {
  local work="$1"
  shift
  docker run --rm -i --platform linux/amd64 \
    -v "$PWD/$work:/work" \
    -e APPID="$APPID" -e RECIPE="$RECIPE" \
    -e FDROIDSERVER_COMMIT="$FDROIDSERVER_COMMIT" \
    -e FDROIDDATA_COMMIT="$FDROIDDATA_COMMIT" \
    -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
    "$@"
}

cmd_lint() {
  local work="$OUT/lint"
  rm -rf "$work"
  mkdir -p "$work"
  cp "$RECIPE" "$work/recipe.yml"
  run_image "$work" "$IMAGE" bash -s <<<"$CONTAINER_PREAMBLE$CONTAINER_LINT"
  echo "Recipe lints clean."
}

cmd_build() {
  local abi="" vary="" commit=""
  while (($#)); do
    case "$1" in
      --vary) vary=1 ;;
      --commit)
        commit="${2:?--commit needs a sha}"
        shift
        ;;
      -*) die "unknown option $1" ;;
      *) abi="$1" ;;
    esac
    shift
  done
  [[ -n "$abi" ]] || die "build needs an ABI"
  local name number vercode
  name="$(pubspec_version name)"
  number="$(pubspec_version code)"
  vercode=$((number * 10 + $(abi_code "$abi")))
  commit="${commit:-$(git rev-parse HEAD)}"

  local work="$OUT/$abi${vary:+-vary}"
  rm -rf "$work"
  mkdir -p "$work/out"
  cp "$RECIPE" "$work/recipe.yml"

  local docker_args=()
  if [[ -n "$vary" ]]; then
    # bsenv.sh pins LC_ALL=C.UTF-8 on every F-Droid buildserver and the image
    # ships no other locale, so the locale is not a variable worth varying.
    docker_args+=(--cpuset-cpus 0,1 --hostname fdroid-rebuild -e TZ=Etc/GMT-14)
  fi

  echo "fdroid build $APPID:$vercode ($abi, $name, $commit)${vary:+ — varied environment}"
  run_image "$work" ${docker_args[@]+"${docker_args[@]}"} \
    -e ABI="$abi" -e VERNAME="$name" -e VERCODE="$vercode" -e COMMIT="$commit" \
    -e VARY="$vary" \
    "$IMAGE" bash -s <<<"$CONTAINER_PREAMBLE$CONTAINER_LINT"'
# The recipe as fdroiddata will hold it once checkupdates adds this version:
# the ABI block alone, at this version and commit. Binaries and the signing
# key are publish-time checks against an APK that does not exist yet.
python3 - "metadata/$APPID.yml" "$ABI" "$VERNAME" "$VERCODE" "$COMMIT" <<'"'PY'"'
import sys
from ruamel.yaml import YAML

path, abi, name, code, commit = sys.argv[1:]
yaml = YAML()
yaml.width = 4096
yaml.preserve_quotes = True
with open(path) as f:
    recipe = yaml.load(f)
blocks = [b for b in recipe["Builds"]
          if str(b["output"]).endswith(f"/app-{abi}-release.apk")]
if len(blocks) != 1:
    sys.exit(f"expected one build block for {abi}, found {len(blocks)}")
block = blocks[0]
block["versionName"] = name
block["versionCode"] = int(code)
block["commit"] = commit
block.pop("binary", None)
recipe["Builds"] = [block]
recipe.pop("Binaries", None)
recipe.pop("AllowedAPKSigningKeys", None)
recipe["CurrentVersion"] = name
recipe["CurrentVersionCode"] = int(code)
with open(path, "w") as f:
    yaml.dump(recipe, f)
PY

export GRADLE_USER_HOME="$home_vagrant/.gradle"
chown -R vagrant "$home_vagrant"
# Each `fdroid build --on-server` expects sudo, runs the recipe sudo: block,
# then uninstalls it — the same invocation as fdroiddata CI`s build job.
fdroid="sudo --preserve-env --user vagrant
  env PATH=$fdroidserver:$PATH
  env PYTHONPATH=$fdroidserver:$fdroidserver/examples
  env PYTHONUNBUFFERED=true
  env HOME=$home_vagrant
  fdroid"
$fdroid fetchsrclibs "$APPID:$VERCODE" --verbose
if [[ -n "$VARY" ]]; then umask 0077; fi
(unset CI; $fdroid build --verbose --test --refresh-scanner --on-server --no-tarball "$APPID:$VERCODE")
umask 0022

apk="tmp/${APPID}_${VERCODE}.apk"
test -f "$apk"
install -m 0644 "$apk" "/work/out/${APPID}_${VERCODE}.apk"
{
  echo "image digest: pinned by tools/fdroid_build.sh"
  echo "fdroidserver: $(git -C "$fdroidserver" rev-parse HEAD)"
  echo "cpus: $(nproc)  arch: $(uname -m)  TZ=${TZ:-unset}  LC_ALL=$LC_ALL"
  java -version 2>&1
  javac -version 2>&1
  for f in "$ANDROID_HOME"/ndk/*/source.properties "$ANDROID_HOME"/platforms/*/source.properties "$ANDROID_HOME"/build-tools/*/source.properties; do
    [[ -f "$f" ]] && { echo "== $f"; cat "$f"; }
  done
  git -C build/srclib/flutter describe --tags 2>/dev/null || true
  cat build/srclib/flutter/bin/cache/engine.stamp 2>/dev/null || true
} > /work/out/toolchain.txt
chown -R "$HOST_UID:$HOST_GID" /work/out
'
  echo "Unsigned APK: $work/out/${APPID}_${vercode}.apk"
}

cmd_sign() {
  local abi="${1:?sign needs an ABI}" unsigned="${2:?sign needs the unsigned APK}" outdir="${3:?sign needs an output directory}"
  abi_code "$abi" >/dev/null
  [[ -f "$unsigned" ]] || die "no such APK: $unsigned"

  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  [[ -n "$sdk" ]] || die "ANDROID_HOME is not set"
  local bt="$sdk/build-tools/$BUILD_TOOLS"
  if [[ ! -x "$bt/apksigner" ]]; then
    local sdkmanager="$sdk/cmdline-tools/latest/bin/sdkmanager"
    [[ -x "$sdkmanager" ]] || die "no build-tools $BUILD_TOOLS and no sdkmanager to install it"
    yes | "$sdkmanager" "build-tools;$BUILD_TOOLS" >/dev/null
  fi

  local pattern name
  pattern="$(recipe_binary "$abi")"
  [[ -n "$pattern" ]] || die "$RECIPE has no binary: for $abi"
  name="${pattern##*/}"
  name="${name//%v/$(pubspec_version name)}"
  mkdir -p "$outdir"
  local signed="$outdir/$name"

  local tmp
  tmp="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/fdroid-sign.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  local ks alias real
  if [[ -n "${FDROID_KEYSTORE_BASE64:-}" ]]; then
    real=1
    ks="$tmp/fdroid.jks"
    alias="${FDROID_KEY_ALIAS:?FDROID_KEY_ALIAS is not set}"
    : "${FDROID_KEYSTORE_PASSWORD:?FDROID_KEYSTORE_PASSWORD is not set}"
    : "${FDROID_KEY_PASSWORD:?FDROID_KEY_PASSWORD is not set}"
    printf '%s' "$FDROID_KEYSTORE_BASE64" | base64 --decode >"$ks"
  else
    real=""
    echo "No FDROID_KEYSTORE_BASE64: signing with an EPHEMERAL key. The APK proves" >&2
    echo "the signature copies across, and is not publishable." >&2
    ks="$tmp/ephemeral.jks"
    alias=ephemeral
    FDROID_KEYSTORE_PASSWORD="$(head -c 24 /dev/urandom | base64)"
    FDROID_KEY_PASSWORD="$FDROID_KEYSTORE_PASSWORD"
    export FDROID_KEYSTORE_PASSWORD FDROID_KEY_PASSWORD
    keytool -genkeypair -keystore "$ks" -alias "$alias" -keyalg RSA -keysize 2048 \
      -validity 2 -dname CN=ephemeral \
      -storepass:env FDROID_KEYSTORE_PASSWORD -keypass:env FDROID_KEY_PASSWORD >/dev/null 2>&1
  fi

  "$bt/apksigner" sign \
    --ks "$ks" --ks-key-alias "$alias" \
    --ks-pass env:FDROID_KEYSTORE_PASSWORD --key-pass env:FDROID_KEY_PASSWORD \
    --alignment-preserved \
    --v1-signing-enabled false --v2-signing-enabled true \
    --v3-signing-enabled true --v4-signing-enabled false \
    --out "$signed" "$unsigned"
  rm -f "$ks"

  # Native libraries are stored uncompressed and must stay 16 KB-aligned for
  # Android 15's 16 KB-page devices; --alignment-preserved keeps whatever AGP
  # produced, so this proves AGP produced it.
  "$bt/zipalign" -c -P 16 4 "$signed" || die "$signed is not 16 KB page-aligned"

  local cert pinned
  cert="$("$bt/apksigner" verify --print-certs "$signed" |
    sed -n -E 's/^Signer #1 certificate SHA-256 digest: ([0-9a-f]{64})$/\1/p')"
  [[ -n "$cert" ]] || die "could not read the signing certificate of $signed"
  pinned="$(recipe_signing_key)"
  local publishable=false
  if [[ -n "$real" ]]; then
    [[ "$pinned" =~ ^[0-9a-f]{64}$ ]] ||
      die "$RECIPE has no AllowedAPKSigningKeys fingerprint yet; put $cert there"
    [[ "$cert" == "$pinned" ]] ||
      die "signed with $cert, but $RECIPE pins $pinned — wrong FDROID_* secrets?"
    publishable=true
  fi
  printf 'publishable=%s\ncert=%s\n' "$publishable" "$cert" >"$signed.signing"
  echo "Signed: $signed (certificate $cert, publishable=$publishable)"
}

cmd_compare() {
  local signed="${1:?compare needs the signed APK}" unsigned="${2:?compare needs the unsigned APK}"
  [[ -f "$signed" && -f "$unsigned" ]] || die "compare needs two existing APKs"
  local work="$OUT/compare"
  rm -rf "$work"
  mkdir -p "$work/a" "$work/b"
  cp "$signed" "$work/a/signed.apk"
  cp "$unsigned" "$work/b/unsigned.apk"
  cp "$RECIPE" "$work/recipe.yml"
  run_image "$work" "$IMAGE" bash -s <<<"$CONTAINER_PREAMBLE"'
mkdir -p /tmp/compare
python3 - /work/a/signed.apk /work/b/unsigned.apk <<'"'PY'"'
import sys
from fdroidserver import common

common.read_config()
error = common.verify_apks(sys.argv[1], sys.argv[2], "/tmp/compare")
if error:
    print(error)
    sys.exit(1)
print("Verified: the signature copies onto the independent build.")
PY
'
}

case "${1:-}" in
  lint) shift && cmd_lint "$@" ;;
  build) shift && cmd_build "$@" ;;
  sign) shift && cmd_sign "$@" ;;
  compare) shift && cmd_compare "$@" ;;
  *) sed -n '2,32p' "$0" >&2 && exit 2 ;;
esac
