#!/usr/bin/env python3
"""Hand an uploaded build to TestFlight's testers: What to Test, groups, review.

    APP_STORE_CONNECT_KEY_ID=… APP_STORE_CONNECT_ISSUER_ID=… \\
    APP_STORE_CONNECT_PRIVATE_KEY="$(cat AuthKey_….p8)" \\
    tools/testflight_release.py --platform IOS [--dry-run]
    tools/testflight_release.py --print-notes [--build N]   # no network

Run by appstore-ios.yml / appstore-macos.yml after the upload, it does what
used to be done by hand in App Store Connect for every build:

1. waits for App Store Connect to list the build — found by pubspec.yaml's
   `version: X.Y.Z+N` (CFBundleShortVersionString / CFBundleVersion) — and for
   Apple to finish processing it (`VALID`);
2. sets its en-US "What to Test";
3. adds it to every *external* beta group ("Beta - External", the public
   TestFlight link the mobile-app promo opens); internal groups get every
   build on their own;
4. submits it for beta app review, unless it already is, or has no What to
   Test to review. External testers are notified once Apple approves it.

What to Test is the release's short digest — the F-Droid changelog that Google
Play also takes as "What's new" (`fastlane/metadata/android/en-US/changelogs/
<build × 10 + 1>.txt`, docs/release-notes.md step 5), the list that used to be
pasted in by hand. A line naming Android, Google Play, F-Droid or another store
is dropped (Apple guideline 2.3.10, docs/mobile-app-promo.md); when nothing is
left, What to Test is not touched. `--print-notes` prints that text and exits,
which is what test/tools/testflight_release_test.dart checks for every digest.

Standard library only, plus the `openssl` CLI to sign the ES256 token (the
macOS runners have both). The key is written to a private temp file only for
that signature, then deleted. Exits non-zero on any failure; the workflows run
it with continue-on-error, because by then the build is already uploaded.
"""

import argparse
import base64
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.invoiceninja.admin"
LOCALE = "en-US"
MAX_WHATS_NEW = 4000  # App Store Connect's limit for whatsNew
ROOT = pathlib.Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "pubspec.yaml"
CHANGELOGS = ROOT / "fastlane/metadata/android/en-US/changelogs"
# What an App Store build may not name (guideline 2.3.10): the list
# test/domain/release_notes_test.dart bans from kReleaseNotes on Apple builds,
# minus its bare "google", which would drop "Sign in with Google" — plus the
# other stores a digest could mention.
OTHER_PLATFORM = re.compile(
    r"android|google play|play store|f-?droid|microsoft store|\bsnap\b|appimage|\bapks?\b|"
    r"galaxy store|huawei|amazon appstore",
    re.I,
)
RETRIES = 4  # a read, or any 5xx / network error, is tried this many times


def fail(message):
    print(f"::error::testflight_release: {message}", file=sys.stderr)
    sys.exit(1)


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der):
    """An ECDSA DER signature as JWS wants it: r || s, 32 bytes each."""
    if der[0] != 0x30:
        fail("unexpected signature encoding from openssl")
    i = 2 if der[1] < 0x80 else 3

    def read_int(i):
        if der[i] != 0x02:
            fail("unexpected signature encoding from openssl")
        n = der[i + 1]
        return der[i + 2 : i + 2 + n].lstrip(b"\0").rjust(32, b"\0"), i + 2 + n

    r, i = read_int(i)
    s, _ = read_int(i)
    return r + s


def token(key_id, issuer_id, private_key):
    now = int(time.time())
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    claims = b64url(
        json.dumps(
            {"iss": issuer_id, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
        ).encode()
    )
    signing_input = f"{header}.{claims}".encode()
    fd, path = tempfile.mkstemp(suffix=".p8")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(private_key)
        der = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", path],
            input=signing_input,
            capture_output=True,
            check=True,
        ).stdout
    except subprocess.CalledProcessError as e:
        fail(f"openssl could not sign with the key: {e.stderr.decode().strip()}")
    finally:
        os.unlink(path)
    return f"{header}.{claims}.{b64url(der_to_raw(der))}"


def call(jwt, method, path, body=None):
    """One API call. A dropped connection or a 5xx is retried with a backoff —
    the waits make ~100 calls, and one blip must not strand the build — as is
    every GET; a 4xx on a write is final."""
    for attempt in range(1, RETRIES + 1):
        request = urllib.request.Request(
            path if path.startswith("http") else API + path,
            method=method,
            data=None if body is None else json.dumps(body).encode(),
            headers={"Authorization": f"Bearer {jwt}", "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                raw = response.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode(errors="replace")[:500]
            if e.code < 500 or attempt == RETRIES:
                fail(f"{method} {path} → HTTP {e.code}: {detail}")
            problem = f"HTTP {e.code}"
        except (urllib.error.URLError, OSError) as e:
            if attempt == RETRIES:
                fail(f"{method} {path} → {e}")
            problem = str(e)
        print(f"{method} {path} failed ({problem}); retrying…")
        time.sleep(10 * attempt)


def pubspec_version():
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", PUBSPEC.read_text(), re.M)
    if not match:
        fail("pubspec.yaml has no MAJOR.MINOR.PATCH+BUILD version")
    return match.group(1), match.group(2)


def apple_notes(build):
    """The build's digest, minus any line an App Store build may not show."""
    path = CHANGELOGS / f"{int(build) * 10 + 1}.txt"
    if not path.is_file():
        fail(f"{path.relative_to(ROOT)} is missing: write the release's short notes first "
             "(docs/release-notes.md step 5)")
    lines = [l for l in path.read_text(encoding="utf-8").splitlines()
             if l.strip() and not OTHER_PLATFORM.search(l)]
    notes = "\n".join(lines)
    if len(notes) > MAX_WHATS_NEW:
        # Cut at a bullet boundary rather than mid-sentence.
        notes = notes[:MAX_WHATS_NEW].rsplit("\n", 1)[0]
    return notes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=["IOS", "MAC_OS"])
    parser.add_argument("--build", help="build number (default: pubspec.yaml's)")
    parser.add_argument("--print-notes", action="store_true", help="print the notes and exit")
    parser.add_argument("--timeout", type=int, default=2700,
                        help="seconds to wait for the build to be listed and processed, in all")
    parser.add_argument("--dry-run", action="store_true", help="find the build, change nothing")
    args = parser.parse_args()

    version, build = pubspec_version()
    build = args.build or build
    notes = apple_notes(build)
    if args.print_notes:
        sys.stdout.write(notes + ("\n" if notes else ""))
        return
    if not args.platform:
        fail("--platform is required")
    if not notes:
        print("::warning::Every line of this release's digest names another platform, so there "
              "is no What to Test: the build goes to the external group but is NOT submitted for "
              "beta review. Write What to Test and submit it in App Store Connect.")

    env = {k: os.environ.get(k, "") for k in (
        "APP_STORE_CONNECT_KEY_ID", "APP_STORE_CONNECT_ISSUER_ID", "APP_STORE_CONNECT_PRIVATE_KEY")}
    missing = [k for k, v in env.items() if not v]
    if missing:
        fail(f"missing {', '.join(missing)}")
    jwt_args = (env["APP_STORE_CONNECT_KEY_ID"], env["APP_STORE_CONNECT_ISSUER_ID"],
                env["APP_STORE_CONNECT_PRIVATE_KEY"])

    apps = call(token(*jwt_args), "GET",
                "/apps?" + urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID, "fields[apps]": "bundleId"}))
    app_id = next((a["id"] for a in apps.get("data", []) if a["attributes"]["bundleId"] == BUNDLE_ID), None)
    if not app_id:
        fail(f"no App Store Connect app for {BUNDLE_ID}")

    query = urllib.parse.urlencode({
        "filter[app]": app_id,
        "filter[version]": build,
        "filter[preReleaseVersion.version]": version,
        "filter[preReleaseVersion.platform]": args.platform,
        "fields[builds]": "version,processingState",
        "limit": "1",
    })
    deadline = time.time() + args.timeout
    while True:
        # A fresh token each poll: the wait can outlast one token's 20 minutes.
        found = call(token(*jwt_args), "GET", f"/builds?{query}").get("data", [])
        if found:
            build_id = found[0]["id"]
            print(f"Found {args.platform} build {version} ({build}): {build_id}, "
                  f"{found[0]['attributes'].get('processingState')}")
            break
        if time.time() > deadline:
            fail(f"build {version} ({build}) for {args.platform} did not appear within {args.timeout}s")
        print(f"Waiting for App Store Connect to list build {version} ({build})…")
        time.sleep(30)

    while True:  # the same deadline: --timeout covers both waits
        state = call(token(*jwt_args), "GET",
                     f"/builds/{build_id}?fields[builds]=processingState")["data"]["attributes"]["processingState"]
        if state == "VALID":
            break
        if state in ("FAILED", "INVALID"):
            fail(f"Apple could not process build {version} ({build}): {state}")
        if time.time() > deadline:
            fail(f"build {version} ({build}) was still {state} after {args.timeout}s; "
                 "add it to the external group and submit it for review by hand")
        print(f"Waiting for Apple to process build {version} ({build}): {state}…")
        time.sleep(30)
    print(f"Build {version} ({build}) is processed.")

    # Only now: What to Test is the build's test information, which Apple may
    # not take while the build is still processing.
    jwt = token(*jwt_args)
    if notes:
        set_whats_new(jwt, build_id, notes, args.dry_run)

    groups = call(jwt, "GET", f"/apps/{app_id}/betaGroups?limit=50&fields[betaGroups]=name,isInternalGroup")
    external = [g for g in groups.get("data", []) if not g["attributes"].get("isInternalGroup")]
    if not external:
        print("::warning::the app has no external TestFlight group; only internal testers get this build.")
    for group in external:
        name = group["attributes"]["name"]
        if args.dry_run:
            print(f"Dry run: would add the build to external group {name!r}.")
            continue
        # Adding a build the group already has is a no-op (204), so a re-run is safe.
        call(jwt, "POST", f"/betaGroups/{group['id']}/relationships/builds",
             {"data": [{"type": "builds", "id": build_id}]})
        print(f"Added the build to external group {name!r}.")

    if external and notes:
        # A list query, so "none yet" is an empty list rather than a 404.
        reviews = call(jwt, "GET", "/betaAppReviewSubmissions?" + urllib.parse.urlencode(
            {"filter[build]": build_id, "fields[betaAppReviewSubmissions]": "betaReviewState"}
        )).get("data", [])
        if reviews:
            print(f"Already submitted for beta review: {reviews[0]['attributes'].get('betaReviewState')}.")
        elif args.dry_run:
            print("Dry run: would submit the build for beta app review.")
        else:
            call(jwt, "POST", "/betaAppReviewSubmissions", {"data": {
                "type": "betaAppReviewSubmissions",
                "relationships": {"build": {"data": {"type": "builds", "id": build_id}}},
            }})
            print("Submitted for beta app review; external testers are notified once Apple approves it.")


def set_whats_new(jwt, build_id, notes, dry_run):
    localizations = call(jwt, "GET", f"/builds/{build_id}/betaBuildLocalizations").get("data", [])
    existing = next((l for l in localizations if l["attributes"].get("locale") == LOCALE), None)
    if dry_run:
        current = (existing or {}).get("attributes", {}).get("whatsNew")
        print(f"Dry run: would {'update' if existing else 'create'} the {LOCALE} What to Test "
              f"(now: {current!r}) with {len(notes)} characters.")
        return
    if existing:
        call(jwt, "PATCH", f"/betaBuildLocalizations/{existing['id']}", {"data": {
            "type": "betaBuildLocalizations",
            "id": existing["id"],
            "attributes": {"whatsNew": notes},
        }})
    else:
        call(jwt, "POST", "/betaBuildLocalizations", {"data": {
            "type": "betaBuildLocalizations",
            "attributes": {"locale": LOCALE, "whatsNew": notes},
            "relationships": {"build": {"data": {"type": "builds", "id": build_id}}},
        }})
    print(f"Set What to Test ({LOCALE}, {len(notes)} characters):\n{notes}")

if __name__ == "__main__":
    main()
