# What's New — telling users what an update changed

Companion to CLAUDE.md § Release Notes. That section carries the rule; this doc carries who sees the dialog and when, how an update is told apart from an install, the store filter, and how the dialog keeps the mobile-app promo at a day's distance.

After an update, the app opens a dialog of that release's notes: a few highlights, each leading to its feature, then "See all N changes" folding out the full list grouped New / Improved / Fixed. It stays reachable from About ("See what's new in vX.Y.Z") and the command palette ("what's new", "changelog", "release notes", "version", "update").

| Piece | File |
|---|---|
| The notes, the store filter, which releases an update shows | `lib/domain/release_notes.dart` (`kReleaseNotes`, `releasesToShow`) |
| The schedule, a device preference | `lib/app/whats_new_controller.dart` (`DevicePrefKeys.whatsNew`) |
| The dialog, and the About / palette opener | `lib/ui/features/whats_new/whats_new_dialog.dart` |
| The automatic opener | `lib/ui/features/whats_new/whats_new_host.dart` (built by `SyncEventListener`) |
| The quiet-moment check it shares with the promo | `lib/ui/core/dialogs/automatic_dialogs.dart` (`QuietMomentCheck`) |
| The highlight row it shares with the promo | `lib/ui/core/widgets/feature_row.dart` |

## The release notes the app shows are bundled in kReleaseNotes, a bullet naming another platform or store is hidden on the App Store builds, and the dialog never links out

**Bundled, not fetched.** The notes are a `const` list in the app, written in the same pass as the GitHub release (`docs/release-notes.md` step 5). They read offline, they describe exactly the build that is running, and they add no call to a third-party server — which F-Droid flags as an anti-feature.

**One copy of the text.** Each `ReleaseNoteItem` is the house-style bullet pasted verbatim. `displayText` does the rest: it drops the `Added:` / `Updated:` / `Fixed:` prefix (the heading carries it), drops ` [#n](url)` issue links entirely, reduces any other link to its text, and strips backticks. A bare "#176" means nothing to most readers, and an inline link inside a sentence is too small for a finger.

**The store filter.** The Mac and iPhone builds ship through the App Store, which forbids naming "other mobile platforms or alternative app marketplaces" (guideline 2.3.10; the evidence is in `docs/mobile-app-promo.md` § Store-policy review). The GitHub notes name F-Droid, Android and Google Play freely, so:

- `releaseNoteSurfaces` puts native iOS and macOS in `ReleaseNoteSurface.appleStore`, and native iOS and Android in `nativePhone`. The web is neither, even on a Mac or an iPhone.
- A bullet or highlight that names Android, Google Play, F-Droid or another store carries `hiddenOn: {ReleaseNoteSurface.appleStore}`. One about the phone-app promo, or about keyboard shortcuts, carries `{nativePhone}`.
- `test/domain/release_notes_test.dart` scans the whole catalog as the Mac and iPhone builds see it for those names, so a future bullet that forgets the tag fails the build.

**Never a link out.** The GitHub release page lists the F-Droid build and the Android APKs, so linking to it from a Mac App Store build is the exposure the filter exists to prevent. Highlights lead only into the app.

## The bump script refuses a version with no kReleaseNotes entry, so the notes are written before the bump

`tools/bump_client_version.sh` looks for the new version's `version: 'X.Y.Z'` line in `lib/domain/release_notes.dart` before it touches a file, and exits 1 without one — for the automatic patch bump and an explicit version alike (a minor bump to 5.2.0 needs a `5.2.0` entry). A commented-out entry doesn't count; `--current` and a bump to the version already set need no notes.

Without it, a version could ship whose users the dialog has nothing to tell: `releasesToShow` would fall back to the previous release's notes, titled with that older version, for an install that predates the record, and show nothing at all to everyone else. The check sits in the bump rather than in CI because the bump is the step that makes a version real; a `kReleaseNotes` entry newer than `kClientVersion` is normal — the notes are written first — and `releasesToShow` ignores it until the build catches up.

## An update is told apart from an install by the store, not the session

The builds before this feature recorded no version, so the first launch of 5.1.16 can't compare one. `main()` calls `WhatsNewController.noteLaunch(existingInstall: …)` once, after the boot restore and before the demo-token bootstrap:

- `existingInstall` is `!db.createdThisOpen || opened.wasReset || auth.isAuthenticated`. `AppDatabase.createdThisOpen` is set by drift's `onCreate`, so it is true only for a store this launch made.
- "A session was restored" alone was rejected: a restore that timed out, an idle-locked web session, a 401 and a user signed out on the old build all look like a fresh install, and the baseline written for one would hide the notes for good.

| Stored record | Install | Result |
|---|---|---|
| none | fresh | Write `seenVersion = current` silently. A new user has no update to hear about. |
| none | existing | `pending` = the newest release this build carries. |
| `current ≤ seen` | — | Nothing (a downgrade keeps the higher version). |
| `seen < current` | — | `pending` = every release in `(seen, current]`, newest first, at most five. |

Writes it can't stand behind are skipped:

- **Not on a failed load.** `DevicePrefsStore.load()` sets `isLoaded` even when the read throws, leaving an empty mirror; a baseline written then would overwrite the real row. `loadSucceeded` is the gate.
- **Not when there is nothing to show.** A version with no entry writes nothing, so the next build that carries notes still covers the gap.
- **Never on a demo build** (`Env.isDemoBuild`, `Env.demoMode`), and the host skips a demo session.

Only `main()` calls `noteLaunch`, so no test or harness ever arms the dialog.

## When it opens on its own

`WhatsNewHost` sits in the authenticated shell beside `MobileAppPromoHost`, so it never lands over `/login`, `/lock` or `/setup`:

- **About 2 s after the shell settles**, sooner than the promo's 4 s — it belongs to the update just installed.
- **Only at a quiet moment** (`QuietMomentCheck`, shared with the promo): no click, tap, scroll or key since the previous check, no dialog or sheet up, nothing being typed, no unsaved form, not on an `/edit`, `/new`, email, refund, statement or `/settings` screen, the window in front. It rechecks every 3 s and gives up for the launch after about a minute.
- **It waits behind other automatic dialogs instead of standing down.** The promo skips a launch that showed the missing-name prompt or the local-data notice; What's New can't, because a hosted user with no name gets that prompt on every launch and the notes would never come. An open dialog is not a quiet moment, so it opens once that one closes.
- **Three launches that give up stop the automatic open** (`maxAttempts`, counted per version so one release that never found a moment doesn't silence the next). The notes stay in About and the palette.
- **The first half-second ignores clicks, Enter and Esc**, as the promo's does: Got it has the focus, and a keystroke already in flight would close it unread.
- **`shownAt` is written as it opens; `seenVersion` as it closes.** A 401 or the idle timeout tears the dialog down and unmounts the host; the notes come back next launch, but the promo's hold has already started.

Opening the notes from About or the palette while an update is waiting counts as reading them: it marks them seen and starts the promo's hold. With nothing waiting, it shows this build's release and changes nothing.

## The mobile-app promo waits a day behind What's New

`MobileAppPromoController.isDue` asks `WhatsNewController.holdsBackPromptsAt(now)`, which holds:

- while the dialog may still open on its own (`autoOpens`), so the update always goes first, and
- for `promptHold` (24 h) after it opened.

A `shownAt` in the future — the clock moved back — holds nothing, or the promo could wait for months. The promo's sidebar card is not a modal and is not held. Tests: `test/app/whats_new_controller_test.dart` and `test/app/mobile_app_promo_controller_test.dart`.

## The dialog

- **Highlights first, key features before newer small ones.** At most five, merged across the releases shown (`whatsNewHighlights`): every `major` highlight first, then the rest, each group newest release first. Merged newest first alone, a catch-up filled its five with the latest release's small changes and dropped the key features of the releases the user skipped. Filtered by surface and by whether this user can open the target: a `ReleaseHighlightRoute` passes the rules the sidebar applies to the same row (the module enabled, and `view_reports` for Reports); `ReleaseHighlightMobileApp` passes where the promo itself may open. A highlight that fails is left out, not shown dead.
- **Tapping one closes the dialog with where it leads.** The caller then follows it (`followWhatsNewResult`): a route, behind the unsaved-changes prompt the sidebar gives; the promo as a manual open; or Contact Us for Feedback. Every close means seen.
- **A release with no highlights** (fixes only) opens on its full list, with nothing to fold.
- **A catch-up** across several releases titles the newest, says "Including the changes since vX", and folds every release but the newest to "vX · N changes".
- **The bullets stay in English**, as on GitHub; only the chrome is translated.
- **Layout:** a 560-px card, 16-px insets on a phone; the header and body scroll together under a pinned footer, with a divider only while the body overflows. The ✕ sits beside the title and scrolls away with it — pinned over the notes, it covered the first highlight's chevron on a phone — while Got it, in the footer, never leaves the screen. "See all" brings the list up only once it has finished growing (`AnimatedSize.onEnd`); before that the scroll view has nowhere to go. Got it keeps its width and Feedback gives way. Page Up / Page Down scroll the notes while Got it holds the focus (`PrimaryScrollController` around the whole card). `test/ui/features/whats_new/whats_new_dialog_test.dart` checks a 360-px phone, 1.4× text, a landscape phone and right-to-left.
