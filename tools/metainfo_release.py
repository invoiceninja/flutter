#!/usr/bin/env python3
"""Write a release's notes into the Linux metainfo's <releases> block.

    tools/metainfo_release.py <version> <build> [--date YYYY-MM-DD]
    tools/metainfo_release.py --check <version>

Flathub's listing and GNOME Software / KDE Discover show the metainfo's
<releases> as the app's changelog, and AppStream requires one entry per
release, dated on or before the day it ships. The text is the release's short
store digest: the F-Droid changelog that Google Play, TestFlight and the
Microsoft Store already take (docs/release-notes.md step 5), read from
fastlane/metadata/android/en-US/changelogs/<build x 10 + 1>.txt. It is plain
text, so nothing in it needs the GitHub bullets' links, which AppStream's
description markup does not allow. A line about another platform or store (an
APK, an Intel Mac, a home-screen widget) is left out, as testflight_release.py
does for Apple; a release with nothing left reads "Fixes and improvements".

tools/bump_client_version.sh runs the first form, so the entry is committed
with the bump and lands in the tag Flathub builds from — never stamped at build
time, where it would carry the build's date (docs/flatpak.md). Writing an
entry that is already there replaces it, so a re-run is harmless. The second
form exits 1 unless the version has an entry; tools/check_release_ready.sh
runs it.

Standard library only (the release runners have no Dart SDK); the file is
edited as text so its comments and layout survive.
"""

import argparse
import datetime
import pathlib
import re
import sys
from xml.sax.saxutils import escape

ROOT = pathlib.Path(__file__).resolve().parent.parent
METAINFO = ROOT / "appimage/com.invoiceninja.admin.metainfo.xml"
CHANGELOGS = ROOT / "fastlane/metadata/android/en-US/changelogs"

# A digest line naming another platform or store, or a phone-only surface:
# these notes are only ever read on Linux.
OTHER_PLATFORM = re.compile(
    r"android|google play|play store|f-?droid|\bapks?\b|app store|testflight|"
    r"\bios\b|iphone|ipad|\bmacs?\b|macos|windows|microsoft store|\bsnap\b|"
    r"appimage|galaxy store|huawei|amazon appstore|home-screen",
    re.I,
)

# The <releases> opening tag and the indentation of the line it sits on.
RELEASES_OPEN = re.compile(r"^([ \t]*)<releases>[ \t]*\n", re.MULTILINE)


def fail(message):
    print(f"metainfo_release: {message}", file=sys.stderr)
    sys.exit(1)


def entry_pattern(version):
    """One existing entry for [version], self-closed or with a body."""
    v = re.escape(version)
    return re.compile(
        rf'^[ \t]*<release\b[^>]*\bversion="{v}"[^>]*?(/>|>.*?</release>)[ \t]*\n',
        re.MULTILINE | re.DOTALL,
    )


def digest_items(build):
    path = CHANGELOGS / f"{build * 10 + 1}.txt"
    if not path.is_file():
        fail(f"no changelog {path.relative_to(ROOT)} (docs/release-notes.md step 5)")
    items = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("- "):
            line = line[2:].strip()
        items.append(line)
    if not items:
        fail(f"{path.relative_to(ROOT)} is empty")
    return [item for item in items if not OTHER_PLATFORM.search(item)]


def render(version, date, items, indent):
    inner = indent + "  "
    if items:
        body = [
            f"{inner}    <ul>",
            *(f"{inner}      <li>{escape(item)}</li>" for item in items),
            f"{inner}    </ul>",
        ]
    else:
        body = [f"{inner}    <p>Fixes and improvements</p>"]
    lines = [
        f'{inner}<release version="{escape(version)}" date="{date}">',
        f"{inner}  <description>",
        *body,
        f"{inner}  </description>",
        f"{inner}</release>",
    ]
    return "\n".join(lines) + "\n"


def write(version, build, date):
    text = METAINFO.read_text(encoding="utf-8")
    match = RELEASES_OPEN.search(text)
    if not match:
        fail(f"no <releases> line in {METAINFO.relative_to(ROOT)}")
    text = entry_pattern(version).sub("", text, count=1)
    match = RELEASES_OPEN.search(text)
    entry = render(version, date, digest_items(build), match.group(1))
    text = text[: match.end()] + entry + text[match.end() :]
    METAINFO.write_text(text, encoding="utf-8")
    print(f"==> metainfo: <release {version} {date}> from changelog {build * 10 + 1}.txt")


def check(version):
    text = METAINFO.read_text(encoding="utf-8")
    if not entry_pattern(version).search(text):
        fail(
            f"{METAINFO.relative_to(ROOT)} has no <release> for {version}: "
            "run tools/bump_client_version.sh rather than editing versions by hand"
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--check", metavar="VERSION")
    parser.add_argument("version", nargs="?")
    parser.add_argument("build", nargs="?", type=int)
    parser.add_argument("--date", help="YYYY-MM-DD (default: today, UTC)")
    args = parser.parse_args()

    if args.check:
        check(args.check)
        return
    if not args.version or args.build is None:
        parser.error("give <version> <build>, or --check <version>")
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        parser.error(f"'{args.version}' is not MAJOR.MINOR.PATCH")
    date = args.date or datetime.datetime.now(datetime.timezone.utc).date().isoformat()
    try:
        datetime.date.fromisoformat(date)
    except ValueError:
        parser.error(f"'{date}' is not YYYY-MM-DD")
    write(args.version, args.build, date)


if __name__ == "__main__":
    main()
