# Release notes

Companion to CLAUDE.md § Release Notes. The full procedure for "release notes" requests: finding the next version, reviewing the commits since the last tag, the house style, and where the output goes.

## Writing release notes

When the user asks for "release notes" (or "releasenotes"), generate the notes for the **next** version of the app and print the markdown in chat. Do not create a GitHub release/tag and do not bump version files unless explicitly asked separately. Follow the established style at <https://github.com/invoiceninja/flutter/releases>.

**Steps:**

1. **Find the last release and next version.** The authoritative last release is the latest git tag: `git tag --sort=-creatordate | head -1` (e.g. `v5.1.5`), cross-checked against `version:` in `pubspec.yaml` and `kClientVersion` in `lib/app/version.dart` (and `gh release view --json tagName,name` if GitHub Releases are in use). Versions are `vMAJOR.MINOR.PATCH`. The next version is a **patch bump** by default (`v5.1.5` → `v5.1.6`); only use a minor/major bump if the user asks.

2. **Review changes since the last release.** Run `git log <last-release-tag>..HEAD --oneline`. If the tag is missing locally (local tags can lag GitHub), run `git fetch --tags` first. Read the actual commits closely enough to describe each change accurately; for a referenced issue/PR you can read it with `gh issue view <n>` / `gh pr view <n>` for a clearer summary.

3. **Write short, user-facing bullets** matching the house style:
   - Bullet list only, each prefixed with `Added:`, `Updated:`, or `Fixed:`. No emoji.
   - No em dash (`—`). Use a period, a colon, a comma or parentheses instead; an ordinary hyphen (`-`) is fine (see § Release notes never use an em dash).
   - Keep it short and sweet (aim for ~1-7 bullets). Describe user-facing impact, not implementation details.
   - Skip internal-only commits (test-only changes, version bumps, CI, dependency bumps, no-op refactors).
   - Merge related commits into a single bullet.
   - When a commit references an issue/PR number (e.g. `#7`), link it inline: `[#7](https://github.com/invoiceninja/flutter/issues/7)`.

4. **Output.** Print the version as the title followed by the bullet body, as markdown in chat, ready to paste into GitHub's release form — **and** write the same text to `release-notes-vX.Y.Z.md` in the repo root (gitignored) so it can be copied.

5. **Bundle them for the What's New dialog** (`docs/whats-new-dialog.md`) — **before the version is bumped**: `tools/bump_client_version.sh` refuses a version with no entry and changes nothing. Add a `ReleaseNotes` entry for the version at the top of `kReleaseNotes` in `lib/domain/release_notes.dart`:
   - `items`: the same bullets, verbatim, one `ReleaseNoteItem` each — links and all; the dialog strips them.
   - `highlights`: the 3–5 changes worth leading with, each a short title, a one-line body, the destination's sidebar icon and, where there is a screen to open, a `ReleaseHighlightRoute` naming its module or permission. Write them in the same pass as the F-Droid changelog digest (`fastlane/metadata/android/en-US/changelogs/<build>.txt`), which is the same editorial job. A fixes-only release may have none; it opens on its full list.
   - `hiddenOn`: `{ReleaseNoteSurface.appleStore}` on anything that names Android, Google Play, F-Droid or another store; `{ReleaseNoteSurface.nativePhone}` on the phone-app promo and keyboard-only changes.
   - Then run `flutter test test/domain/release_notes_test.dart` — it fails on a missing prefix, an out-of-order version, a store name an App Store build would show, or an em dash.

**Example output:**

```
v5.1.6

- Added: Keyboard shortcuts across the app for faster navigation and saving.
- Updated: Login now supports a shared login secret.
- Fixed: Adding a payment to an invoice now marks the invoice as paid [#7](https://github.com/invoiceninja/flutter/issues/7)
```

## Release notes never use an em dash

The house style bans `—` in every copy of the notes: the GitHub release body, `release-notes-vX.Y.Z.md`, the `kReleaseNotes` items and highlights, and the F-Droid changelog digest. It reads as machine-written. Ordinary hyphens (`-`, as in `F-Droid` or `burn-up`) are fine. Rewrite the clause instead:

| Instead of | Write |
|---|---|
| `Added: Reports rebuilt — open a report to run it` | `Added: Reports are rebuilt. Open a report to run it` |
| `Added: Project analytics — a forecast finish date` | `Added: Project analytics, with a forecast finish date` |
| `Updated: Smarter list search — it finds clients` | `Updated: Smarter list search. It finds clients` |

The `Added:` / `Updated:` / `Fixed:` prefix already takes the line's colon, so a second colon right after it reads badly. Prefer a period or a comma there.

`test/domain/release_notes_test.dart` ("no bullet, highlight or F-Droid changelog uses an em dash") scans every `kReleaseNotes` entry and every `fastlane/metadata/android/en-US/changelogs/*.txt`. Nothing checks the GitHub body or the root file, but both are the same bullets, so a clean `kReleaseNotes` means they are clean too. When the rule arrived (2026-10-18), every earlier copy was reworded too: the bundled v5.1.16 items (they show again in a catch-up from an older version), the root `release-notes-v*.md` files, and the GitHub bodies of v5.1.7 to v5.1.14.
