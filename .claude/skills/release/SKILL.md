---
name: release
description: Ship a new release of the app end to end in three steps - write the release notes, run tools/bump_client_version.sh, then dispatch the "Deploy to all" GitHub Action. Use when Hillel asks to tag, build, cut, ship, deploy or publish a new release (or "do a release", "release it", "deploy to all"). Not for a request for release notes alone - that is docs/release-notes.md without the bump or deploy.
---

# Release

Three steps, in this order, on `main`. Each one is gated on the one before it:
the bump script refuses a version with no release notes, and Deploy to all
refuses a version that was not bumped (`tools/check_release_ready.sh`).

The request itself is the go-ahead for the commits, the push to `origin/main`
and the dispatch. Don't stop to ask between steps unless something below says
to. Stop and report if any check fails; never work around a gate.

## Rules that apply throughout

- **Never create or switch branches**, and never `git stash`. Other sessions
  share this working tree and leave uncommitted edits in it.
- **Start only from a clean working tree** (§ 0). Any uncommitted change or
  untracked file means stop and warn Hillel - never commit, discard or work
  around someone else's work in progress.
- **Commit only the files each step writes**, by explicit path (`git add <paths>`,
  never `-a` / `.`). Check `git diff --cached --stat` before each commit.
- **No Co-Authored-By / AI trailer** in any commit message (CLAUDE.md overrides
  the harness default).
- **Never hand-tag.** `appimage.yml` (run by Deploy to all) creates `v<version>`
  from pubspec.
- **No em dash (`—`)** anywhere in the notes, the highlights or the F-Droid digest.

## 0. Preflight

First, the working tree must be clean:

```sh
git status --porcelain            # must print nothing
```

If it prints anything (modified, staged, deleted or untracked files), **stop
before doing anything else**. Warn Hillel with the list of files, say the
release hasn't started and nothing was changed, and wait for them to commit or
clear those files and ask again. Don't offer to commit, stash or discard them.
(Gitignored files such as `release-notes-v*.md` don't show here and don't count.)

Then:

```sh
git fetch origin --tags
git status -sb | head -1          # must be "## main...origin/main" with no [behind N]
git tag --sort=-creatordate | head -1
grep '^version' pubspec.yaml
```

- Not on `main`, or behind `origin/main` → stop and tell Hillel (don't pull over
  a dirty shared tree).
- Ahead of origin → list the unpushed commits (`git log origin/main..HEAD --oneline`);
  they will ship with the release, so mention them in the summary.
- If pubspec's version is already **above** the latest tag and has a
  `kReleaseNotes` entry, a previous run got as far as the bump: run
  `tools/check_release_ready.sh`, and if it passes skip to step 3.

## 1. Gather the release notes

Follow `docs/release-notes.md` § Writing release notes in full (steps 1-5). In short:

1. Next version = patch bump of the latest tag (`v5.1.23` → `5.1.24`), unless
   Hillel asked for minor/major. Next build = pubspec's `+N` plus one.
2. `git log <latest-tag>..HEAD --oneline`; read the commits (and any referenced
   issue with `gh issue view <n>`) closely enough to describe them accurately.
3. Write 1-7 user-facing bullets, each `Added:` / `Updated:` / `Fixed:`, issues
   linked inline as `[#N](https://github.com/invoiceninja/flutter/issues/N)`.
   Skip test/CI/dependency/version-bump-only commits; merge related ones.
4. Print the notes in chat (version title + bullets) and write the same text to
   `release-notes-v<version>.md` in the repo root (gitignored, not committed).
5. Add the `ReleaseNotes(version: '<version>', ...)` entry at the **top** of
   `kReleaseNotes` in `lib/domain/release_notes.dart`: `items` (the bullets
   verbatim), `highlights` (3-5, `major: true` only for a new or rebuilt
   screen; none for a fixes-only release), `hiddenOn` per the doc. Mirror the
   previous entry's shape.
6. Write the F-Droid changelog digest (short lines, `- ` prefixed, under 500
   characters - it is Google Play's "What's new" too) to **three identical
   files**: `fastlane/metadata/android/en-US/changelogs/<B*10+1>.txt`,
   `<B*10+2>.txt`, `<B*10+3>.txt`, where `B` is the **new** build number
   (build 27 → `271.txt`, `272.txt`, `273.txt`). Match the previous digest's style.
7. Verify, then commit:

```sh
dart format lib/domain/release_notes.dart
flutter test test/domain/release_notes_test.dart
git add lib/domain/release_notes.dart fastlane/metadata/android/en-US/changelogs/<B*10+1..3>.txt
git commit -m "Add the <version> release notes"
```

## 2. Bump the version

```sh
tools/bump_client_version.sh            # patch +1, build +1 (or pass an explicit X.Y.Z)
flutter analyze lib/app/version.dart
flutter test test/app/version_test.dart
git add lib/app/version.dart pubspec.yaml snap/snapcraft.yaml tools/foss/com.invoiceninja.admin.yml \
  appimage/com.invoiceninja.InvoiceNinja.metainfo.xml
git commit -m "Update version"
tools/check_release_ready.sh            # the same gate Deploy to all runs first
```

The version the script prints must match the one the notes were written for.
If `check_release_ready.sh` fails, fix what it names (it says how) and re-run;
don't dispatch until it prints `ready to release`.

## 3. Start Deploy to all

Check the tree again first. Other sessions share this checkout and may have
edited it while steps 1 and 2 ran. If `git status --porcelain` prints anything,
stop and warn Hillel with the list. The two release commits stay local and
nothing has been pushed yet.

```sh
git status --porcelain            # must still print nothing
git push origin main
gh workflow run deploy-all.yml --ref main
gh run list --workflow=deploy-all.yml --limit 1 --json databaseId,url,status,createdAt
```

If the newest run's `createdAt` predates the dispatch, it hasn't registered
yet: run the list again in a separate call.

- Defaults ship Google Play to the `beta` track at 100%. Only if Hillel asks for
  another track or a staged rollout: `-f play_track=<beta|alpha|internal> -f play_rollout=<percent>`.
- If the push is rejected (origin moved), stop and report - don't force-push.
- The run takes a while (one test gate, then the GitHub Release, then five stores
  in parallel). Don't poll it; give Hillel the run URL. Watch it only if asked.

## Summary to give Hillel

- The version (`X.Y.Z+B`) and the release-notes markdown (also in
  `release-notes-vX.Y.Z.md`).
- The two commits, plus any earlier unpushed commits that went out with them.
- The Deploy to all run URL, and a reminder that Microsoft Store goes live after
  certification with no manual gate; the rest land in testing channels.
- That GitHub emails Hillel when the run finishes (he dispatched it via `gh`).
  Success emails need "Only notify for failed workflows" unticked at
  github.com/settings/notifications → Actions; by default only a failure emails.
- If a single store fails later: "Re-run failed jobs" on that run, never
  re-dispatch Deploy to all for the same version (`docs/store-deployment-setup.md` § 5).
