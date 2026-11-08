#!/usr/bin/env python3
"""Print a release's bullets from kReleaseNotes as GitHub markdown.

    tools/release_notes_markdown.py 5.1.23

kReleaseNotes (lib/domain/release_notes.dart) holds the GitHub bullets
verbatim (docs/release-notes.md step 5), so the GitHub Release body is read
from it rather than kept as a second copy: appimage.yml's preflight runs this
and the publish job hands the result to `gh release create --notes-file`.
Every item is printed, `hiddenOn` included: the dialog filters per surface,
while the Release page names every build.

Standard library only (the preflight runner has no Dart SDK). It reads the
Dart source, so test/tools/release_notes_markdown_test.dart compares its
output with the compiled catalog for every release.

Exits 1, printing nothing, when the version has no entry or no items.
"""

import pathlib
import re
import sys

SOURCE = pathlib.Path(__file__).resolve().parent.parent / "lib/domain/release_notes.dart"
ESCAPES = {"n": "\n", "t": "\t", "\\": "\\", "'": "'", '"': '"', "$": "$"}


def fail(message):
    print(f"release_notes_markdown: {message}", file=sys.stderr)
    sys.exit(1)


def skip_space(src, i):
    while i < len(src):
        if src[i].isspace():
            i += 1
        elif src.startswith("//", i):
            i = src.find("\n", i)
            i = len(src) if i < 0 else i
        else:
            break
    return i


def read_literal(src, i):
    """One Dart string literal at src[i] (a quote); returns (text, end)."""
    quote = src[i]
    if src.startswith(quote * 3, i):
        fail("triple-quoted strings are not supported in kReleaseNotes items")
    out = []
    i += 1
    while i < len(src):
        c = src[i]
        if c == "\\":
            nxt = src[i + 1]
            if nxt not in ESCAPES:
                fail(f"unsupported escape \\{nxt}")
            out.append(ESCAPES[nxt])
            i += 2
        elif c == "$":
            fail("string interpolation is not supported in kReleaseNotes items")
        elif c == quote:
            return "".join(out), i + 1
        elif c == "\n":
            fail("unterminated string literal")
        else:
            out.append(c)
            i += 1
    fail("unterminated string literal")


def items_for(src, version):
    start = re.search(r"ReleaseNotes\(\s*version:\s*'" + re.escape(version) + r"'", src)
    if not start:
        return []
    following = src.find("ReleaseNotes(", start.end())
    block = src[start.end() : following if following >= 0 else len(src)]
    items_at = block.find("items:")
    if items_at < 0:
        return []
    items = []
    for match in re.finditer(r"ReleaseNoteItem\(", block[items_at:]):
        i = skip_space(block, items_at + match.end())
        parts = []
        while i < len(block) and block[i] in "'\"":
            text, i = read_literal(block, i)
            parts.append(text)
            i = skip_space(block, i)
        if not parts:
            fail("a ReleaseNoteItem does not start with a string literal")
        items.append("".join(parts))
    return items


def main():
    if len(sys.argv) != 2:
        fail("usage: release_notes_markdown.py <MAJOR.MINOR.PATCH>")
    items = items_for(SOURCE.read_text(encoding="utf-8"), sys.argv[1])
    if not items:
        fail(f"kReleaseNotes has no items for {sys.argv[1]}")
    sys.stdout.write("".join(f"- {item}\n" for item in items))


if __name__ == "__main__":
    main()
