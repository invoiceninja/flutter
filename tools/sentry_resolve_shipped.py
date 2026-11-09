#!/usr/bin/env python3
"""Resolve the Sentry issues whose fixes have shipped, in the release that shipped them.

A fix commit names its issue in the message (`Sentry FLUTTER-ADMIN-K`, or a
list such as `FLUTTER-ADMIN-H, J, S, Z`). For every unresolved issue named
that way, this finds the first release tag (`vX.Y.Z`) holding the newest commit
that names it, and resolves the issue `inRelease` that version. It leaves an
issue alone when:

  * no release tag holds the fix yet;
  * that release has not reported to Sentry yet. Sentry creates a release on
    its first event and the token cannot create one, so the fixes in the
    release being shipped right now are resolved by the NEXT run;
  * the issue has events from that release or a later one (the fix did not
    hold; look at it again);
  * it is an "App Hanging" issue (one bucket for every hang, never fixed by
    one commit), or it was passed to --skip.

Never `inNextRelease`: this server takes it relative to the issue's last-seen
release, not the newest one.

Dry run by default; --apply resolves. The token is the `token=` line of
~/.sentryclirc (or $SENTRY_AUTH_TOKEN) and is never printed.

  tools/sentry_resolve_shipped.py            # what would be resolved, and why not
  tools/sentry_resolve_shipped.py --apply
  tools/sentry_resolve_shipped.py --apply --skip FLUTTER-ADMIN-X
"""

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.parse

BASE = "https://sentry2.invoicing.co/api/0"
ORG = "invoiceninja"
PROJECT = "flutter-admin"
PREFIX = "FLUTTER-ADMIN-"

# FLUTTER-ADMIN-H, then any ", J" / " and S" that continues the list.
ID_LIST = re.compile(
    r"FLUTTER-ADMIN-([0-9A-Z]{1,4})\b((?:\s*(?:,|and|&)\s*(?:FLUTTER-ADMIN-)?[0-9A-Z]{1,4}\b)*)"
)
FOLLOW_ON = re.compile(r"(?:,|and|&)\s*(?:FLUTTER-ADMIN-)?([0-9A-Z]{1,4})\b")
RELEASE_TAG = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")


def token():
    env = os.environ.get("SENTRY_AUTH_TOKEN")
    if env:
        return env.strip()
    path = os.path.expanduser("~/.sentryclirc")
    try:
        with open(path) as f:
            for line in f:
                m = re.match(r"\s*token\s*=\s*(\S+)", line)
                if m:
                    return m.group(1)
    except OSError:
        pass
    sys.exit("No Sentry token: set SENTRY_AUTH_TOKEN or a token= line in ~/.sentryclirc")


def api(method, path, body=None, ok404=False):
    # curl, not urllib: the server's Cloudflare front answers urllib with 403.
    cmd = ["curl", "-s", "-w", "\n%{http_code}", "-X", method,
           "-H", "Authorization: Bearer " + TOKEN]
    if body is not None:
        cmd += ["-H", "Content-Type: application/json", "-d", json.dumps(body)]
    out = subprocess.run(cmd + [BASE + path], capture_output=True, text=True,
                         check=True).stdout
    text, _, code = out.rpartition("\n")
    if code == "404" and ok404:
        return None
    if not code.startswith("2"):
        sys.exit(f"Sentry {method} {path} -> HTTP {code}: {text[:200]}")
    return json.loads(text) if text else None


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True,
                          check=True).stdout


def version_key(v):
    return tuple(int(p) for p in v.split("."))


def fix_commits():
    """{short id: [commit sha, ...]} from every commit message naming one."""
    log = git("log", "--format=%H%x00%B%x01", "-E", "--grep=FLUTTER-ADMIN-")
    found = {}
    for entry in log.split("\x01"):
        sha, _, body = entry.strip().partition("\x00")
        if not sha:
            continue
        body = " ".join(body.split())  # a list may wrap across lines
        for m in ID_LIST.finditer(body):
            ids = [m.group(1)] + FOLLOW_ON.findall(m.group(2))
            for i in ids:
                found.setdefault(PREFIX + i, []).append(sha)
    return found


def first_release(sha):
    tags = [t for t in git("tag", "--contains", sha).split() if RELEASE_TAG.match(t)]
    return min((t[1:] for t in tags), key=version_key, default=None)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--apply", action="store_true", help="resolve (default: dry run)")
    ap.add_argument("--skip", action="append", default=[], metavar="SHORT_ID")
    args = ap.parse_args()

    resolve, waiting = [], []
    reported = {}

    def has_reported(version):
        if version not in reported:
            reported[version] = api(
                "GET", f"/projects/{ORG}/{PROJECT}/releases/{urllib.parse.quote(version)}/",
                ok404=True) is not None
        return reported[version]

    for short_id, shas in sorted(fix_commits().items()):
        issue = api("GET", f"/organizations/{ORG}/shortids/{short_id}/", ok404=True)
        if issue is None:
            continue
        group = issue["group"]
        if group["status"] != "unresolved":
            continue
        title = group["title"][:70]
        label = f"{short_id}  {title}"
        if short_id in args.skip:
            waiting.append((label, "skipped (--skip)"))
            continue
        if group["title"].startswith("App Hanging"):
            waiting.append((label, "a hang bucket, never closed by one fix"))
            continue
        releases = [first_release(s) for s in shas]
        if None in releases:
            waiting.append((label, "a fix is not in a release tag yet"))
            continue
        version = max(releases, key=version_key)
        if not has_reported(version):
            waiting.append((label, f"fixed in {version}, which has not reported to Sentry yet"))
            continue
        # Every release the issue was seen in (topValues on the tag itself is
        # capped at the top few).
        seen = api("GET", f"/organizations/{ORG}/issues/{group['id']}"
                          "/tags/release/values/?per_page=100")
        seen_after = sorted(
            (v["value"] for v in seen
             if re.fullmatch(r"\d+\.\d+\.\d+", v["value"])
             and version_key(v["value"]) >= version_key(version)),
            key=version_key)
        if seen_after:
            waiting.append((label, f"fixed in {version} but seen in {', '.join(seen_after)}: recheck"))
            continue
        resolve.append((label, group["id"], version))

    verb = "Resolved" if args.apply else "Would resolve"
    print(f"{verb} ({len(resolve)}):")
    for label, _, version in resolve:
        print(f"  {label}  -> in {version}")
    if waiting:
        print(f"\nLeft open ({len(waiting)}):")
        for label, why in waiting:
            print(f"  {label}  [{why}]")

    if args.apply:
        for _, group_id, version in resolve:
            api("PUT", f"/organizations/{ORG}/issues/?id={group_id}",
                {"status": "resolved", "statusDetails": {"inRelease": version}})
    elif resolve:
        print("\nDry run. Re-run with --apply to resolve.")


if __name__ == "__main__":
    TOKEN = token()
    main()
