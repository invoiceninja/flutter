#!/usr/bin/env python3
"""Set the Microsoft Store listing's release notes, then commit the submission.

    PARTNER_CENTER_TENANT_ID=… PARTNER_CENTER_CLIENT_ID=… \\
    PARTNER_CENTER_CLIENT_SECRET=… MS_STORE_PRODUCT_ID=9NG93WNXN797 \\
    tools/msstore_release_notes.py [--dry-run]
    tools/msstore_release_notes.py --print-notes [--build N]   # no network

microsoft-store.yml runs `msstore publish --noCommit`, which uploads the MSIX
into the app's pending submission and stops there; this script then writes the
release's short digest — the F-Droid changelog Google Play also takes as
"What's new" (`fastlane/metadata/android/en-US/changelogs/<build × 10 + 1>.txt`,
docs/release-notes.md step 5) — into every listing's `releaseNotes`, and
commits. The commit is what sends the submission to certification and, once
certified, to the live listing: if anything here fails, the submission is
left a draft in Partner Center instead of going out without notes.

Uses the Store submission API (manage.devcenter.microsoft.com), the one
`msstore` itself drives for an MSIX app, with the same Entra app credentials.
`--dry-run` signs in and reads the pending (or last published) submission
without changing anything. Standard library only.
"""

import argparse
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://manage.devcenter.microsoft.com/v1.0/my"
ROOT = pathlib.Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "pubspec.yaml"
CHANGELOGS = ROOT / "fastlane/metadata/android/en-US/changelogs"
MAX_RELEASE_NOTES = 1500  # the Store's limit for releaseNotes
# The app is in beta (docs/going-live.md): its listing is restricted, and a
# commit publishes with the submission's own visibility. Only Private (no one
# outside the listing's audience can get it) is committed; Public, and Hidden
# (anyone with the link can install it), are refused rather than released.
# Going live is a deliberate change here.
ALLOWED_VISIBILITY = {"Private"}
RETRIES = 4  # a read, or any 5xx / network error, is tried this many times


def fail(message):
    print(f"::error::msstore_release_notes: {message}", file=sys.stderr)
    sys.exit(1)


def notes_for(build):
    path = CHANGELOGS / f"{int(build) * 10 + 1}.txt"
    if not path.is_file():
        fail(f"{path.relative_to(ROOT)} is missing: write the release's short notes first "
             "(docs/release-notes.md step 5)")
    notes = "\n".join(l for l in path.read_text(encoding="utf-8").splitlines() if l.strip())
    if not notes:
        fail(f"{path.relative_to(ROOT)} is empty")
    if len(notes) > MAX_RELEASE_NOTES:
        notes = notes[:MAX_RELEASE_NOTES].rsplit("\n", 1)[0]
    return notes


def pubspec_build():
    match = re.search(r"^version:\s*\d+\.\d+\.\d+\+(\d+)\s*$", PUBSPEC.read_text(), re.M)
    if not match:
        fail("pubspec.yaml has no MAJOR.MINOR.PATCH+BUILD version")
    return match.group(1)


def get_token(tenant, client_id, secret):
    body = urllib.parse.urlencode({
        "grant_type": "client_credentials",
        "client_id": client_id,
        "client_secret": secret,
        "scope": "https://manage.devcenter.microsoft.com/.default",
    }).encode()
    url = f"https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token"
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=body), timeout=60) as r:
            return json.loads(r.read())["access_token"]
    except urllib.error.HTTPError as e:
        detail = json.loads(e.read() or b"{}").get("error_description", "")[:300]
        fail(f"could not sign in to Entra (HTTP {e.code}): {detail}")


class CallFailed(Exception):
    pass


def call(token, method, path, body=None, fatal=True):
    """One API call. A GET, a 5xx or a dropped connection is retried with a
    backoff; a 4xx on a write is final. With fatal=False a failure raises
    CallFailed instead of exiting, for the polls after the commit."""
    for attempt in range(1, RETRIES + 1):
        request = urllib.request.Request(
            API + path,
            method=method,
            data=None if body is None else json.dumps(body).encode(),
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                raw = response.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            hint = " (is the Entra app a Manager in Partner Center?)" if e.code in (401, 403) else ""
            problem = f"HTTP {e.code}{hint}: {e.read().decode(errors='replace')[:500]}"
            final = (e.code < 500 and method != "GET") or attempt == RETRIES
        except (urllib.error.URLError, OSError) as e:
            problem, final = str(e), attempt == RETRIES
        if final:
            if fatal:
                fail(f"{method} {path} → {problem}")
            raise CallFailed(problem)
        print(f"{method} {path} failed ({problem}); retrying…")
        time.sleep(10 * attempt)


def main():
    # A Windows runner's Python writes stdout in cp1252; the notes and these
    # messages are UTF-8.
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", help="build number (default: pubspec.yaml's)")
    parser.add_argument("--print-notes", action="store_true", help="print the notes and exit")
    parser.add_argument("--dry-run", action="store_true", help="read the submission, change nothing")
    args = parser.parse_args()

    notes = notes_for(args.build or pubspec_build())
    if args.print_notes:
        print(notes)
        return

    env = {k: os.environ.get(k, "") for k in (
        "PARTNER_CENTER_TENANT_ID", "PARTNER_CENTER_CLIENT_ID",
        "PARTNER_CENTER_CLIENT_SECRET", "MS_STORE_PRODUCT_ID")}
    missing = [k for k, v in env.items() if not v]
    if missing:
        fail(f"missing {', '.join(missing)}")
    app_id = env["MS_STORE_PRODUCT_ID"]
    token = get_token(env["PARTNER_CENTER_TENANT_ID"], env["PARTNER_CENTER_CLIENT_ID"],
                      env["PARTNER_CENTER_CLIENT_SECRET"])

    app = call(token, "GET", f"/applications/{app_id}")
    pending = (app.get("pendingApplicationSubmission") or {}).get("id")
    if args.dry_run:
        sub_id = pending or (app.get("lastPublishedApplicationSubmission") or {}).get("id")
        which = "pending" if pending else "last published"
        if not sub_id:
            fail(f"{app_id} has no submission to read")
        sub = call(token, "GET", f"/applications/{app_id}/submissions/{sub_id}")
        print(f"{which} submission {sub_id}: visibility {sub.get('visibility')!r}, "
              f"targetPublishMode {sub.get('targetPublishMode')!r}"
              + ("" if sub.get("visibility") in ALLOWED_VISIBILITY
                 else " — a run would REFUSE to commit this (not a restricted listing)"))
        for lang, listing in sorted((sub.get("listings") or {}).items()):
            current = (listing.get("baseListing") or {}).get("releaseNotes")
            print(f"{which} submission {sub_id}, listing {lang}: releaseNotes now {current!r}")
        print(f"Dry run: would set {len(notes)} characters:\n{notes}")
        return
    if not pending:
        fail(f"{app_id} has no pending submission — did `msstore publish --noCommit` run?")

    path = f"/applications/{app_id}/submissions/{pending}"
    sub = call(token, "GET", path)
    if sub.get("visibility") not in ALLOWED_VISIBILITY:
        fail(f"submission {pending} has visibility {sub.get('visibility')!r}, not a restricted "
             "listing; refusing to commit while the app is in beta. The draft is left in Partner "
             "Center (docs/going-live.md § One-click production releases).")
    listings = sub.get("listings") or {}
    if not listings:
        fail(f"submission {pending} has no listings to put release notes on")
    for listing in listings.values():
        listing.setdefault("baseListing", {})["releaseNotes"] = notes
    call(token, "PUT", path, sub)
    print(f"Set releaseNotes on {', '.join(sorted(listings))} ({len(notes)} characters):\n{notes}")

    call(token, "POST", f"{path}/commit")
    # From here the submission is committed: a run that turns red now would
    # invite a re-run, and `msstore publish` against a submission already in
    # certification. So the polls only warn.
    for _ in range(20):  # up to ~10 minutes
        try:
            status = call(token, "GET", f"{path}/status", fatal=False)
        except CallFailed as e:
            print(f"::warning::committed submission {pending}, but its status can't be read ({e}); "
                  "watch it in Partner Center. Don't re-run this job.")
            return
        state = status.get("status")
        if state == "CommitFailed":
            errors = (status.get("statusDetails") or {}).get("errors")
            fail(f"the commit failed: {json.dumps(errors)[:800]}")
        if state != "CommitStarted":
            print(f"Committed: submission {pending} is {state}.")
            return
        time.sleep(30)
    print(f"::warning::submission {pending} is still CommitStarted; watch it in Partner Center.")


if __name__ == "__main__":
    main()
