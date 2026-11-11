# The Flatpak (Flathub)

Companion to CLAUDE.md § Strict rules. This doc covers how the Linux app reaches Flathub as
`com.invoiceninja.InvoiceNinja`, v1's ID: who builds it, which files belong to whom, how a release
gets there, and what to touch when a pinned dependency moves. The Flathub-side files themselves
live in `flathub/com.invoiceninja.InvoiceNinja`, not here.

Status: **Flathub is the first platform this app goes to production on** (decided 2026-11-08), ahead
of the other stores' GA. Flathub's stable repo takes only stable software, and a new app can't
start on its beta repo, so it goes straight to stable. `kAppIsBeta` stays `true` there. It only
holds back the review prompt (docs/review-prompt.md), and nothing in the app is labelled beta.
It ships as an update to v1's Flathub listing, so there is no second listing to retire
(§ Retiring v1's listing).

## The Flatpak is built by Flathub from the release tag

Flathub builds every app on its own builders, offline, from sources the manifest declares. Its
policy is *"All source available submissions must be built entirely from source code"*. v1's
manifest repackages a CI-built tarball, which is grandfathered, and this app replaces that
manifest rather than inheriting the exception. So this app takes the better route:
[flatpak-flutter](https://github.com/TheAppgineer/flatpak-flutter) turns a normal manifest into
an offline one. It pins the Flutter SDK as a module, every `pubspec.lock` entry as a pub-cache
source, and the binaries that plugins download at build time, using its "foreign deps" registry.
That gives a reproducible build with no tarball, and aarch64 alongside x86_64.

The build is the **FOSS graph**, the one F-Droid uses: `tools/prepare_foss.sh --offline` swaps
`store_services` for its twin, so there is no Sentry, Play SDK or Google Sign-In (already off on
Linux). It also compiles sqlite3mc from the pinned amalgamation (`docs/fdroid.md` § SQLite is
compiled from source). `--offline` is the same prepare with no network: the amalgamation must
already be in `native/sqlite3mc` (the manifest declares the zip), and `pub get` runs
`--offline --enforce-lockfile` against the pub cache that flatpak-flutter's `setup-flutter.sh`
filled.

What lives where:

| Here (`invoiceninja/flutter`) | There (`flathub/com.invoiceninja.InvoiceNinja`, hand-written) |
|---|---|
| `appimage/com.invoiceninja.InvoiceNinja.metainfo.xml` and `.desktop`, `snap/gui/invoiceninja.png` (512 px) | the flatpak-flutter input manifest, `foreign.json`, `flathub.json` |
| `tools/prepare_foss.sh --offline`, the pins it holds | the generated offline manifest and sources |
| `tools/follow_flathub_release.sh`, `.github/workflows/flathub.yml` (reads only) | the update workflow that opens each release's PR |

Facts the build rests on (checked 2026-11-08 against the sources, not assumed):

- **Runtime.** `org.freedesktop.Platform` **26.08**, the latest. Flathub requires the latest at
  submission, and 24.08 went end of life on 2026-09-08. It needs
  `org.freedesktop.Sdk.Extension.llvm22`: `flutter build linux` runs CMake with `CC=clang`
  (`flutter_tools/lib/src/linux/build_linux.dart`), and the SDK ships no clang. llvm22 is the
  only LLVM extension with a 26.08 branch, but flatpak-flutter's template still says llvm20.
- **App ID.** `linux/CMakeLists.txt` `APPLICATION_ID com.invoiceninja.InvoiceNinja`,
  `BINARY_NAME admin`, and `g_set_prgname(APPLICATION_ID)` in `my_application.cc`, so the Wayland
  `app_id` matches the desktop file and the dock icon resolves (§ The Linux app ID is v1's Flathub
  ID). flatpak-flutter takes the app module to be the one named after the ID's last part
  (`InvoiceNinja`); a module named anything else needs `--app-module`.
- **No Sentry needs no CMake change.** The `crashpad_handler` install in `linux/CMakeLists.txt` is
  a string compare that is simply false when sentry_flutter is absent.

## No agent writes Flathub packaging or a Flathub PR

Flathub's [generative-AI policy](https://docs.flathub.org/docs/for-app-authors/requirements#generative-ai-policy):
*"Flathub manifests must not contain AI-generated or AI-assisted content"*, which disclosure
does not exempt. AI tools or agents may not open or automate Flathub submission pull requests,
or write their commit messages, descriptions or review comments. Other AI-generated material,
such as app code or upstream packaging files, must be disclosed in the submission, with the
affected parts and approximate extent. Breaking the policy can get the submission rejected
without review, and repeat breaches can get a permanent ban.

So, in this repo and every session working on it:

- **Hillel writes, by hand,** everything in `flathub/com.invoiceninja.InvoiceNinja`: manifests, `foreign.json`, `flathub.json`, workflows,
  and patches. He also writes every Flathub PR's text, commit messages and review replies.
- **An agent may** research and explain the requirements, read a failing build log, and change
  this repo's upstream files (metainfo, `prepare_foss.sh`, app code). Those changes count as
  AI-assisted material that must be disclosed at submission time.
- **An agent never** edits a Flathub-side file, opens or comments on a Flathub PR, or pastes a
  ready-made manifest for copying. A dependency bump that would need a `foreign.json` change
  stops and hands that part to Hillel (§ Bumping a pinned dependency).

The update workflow in the Flathub repo opens PRs as `github-actions[bot]`. That is automation
Hillel wrote, not an AI agent, and Saber's Flathub repo does the same.

## Release notes are the metainfo releases entry

Flathub's listing, GNOME Software and KDE Discover show the metainfo's `<releases>` as the
changelog. AppStream wants one entry per release, never dated in the future, and its
description markup has no links. Flathub builds from the tag, so the entry must be **in the
tag**. It is never stamped at build time: that would carry the build's date, and the AppImage's
old `sed` stamp did exactly that.

So `tools/bump_client_version.sh` runs `tools/metainfo_release.py <version> <build>`. That
writes the release's short store digest (`fastlane/.../changelogs/<build × 10 + 1>.txt`, the
text Play, TestFlight and the Microsoft Store already show) as the newest `<release>`, dated the
day of the bump.

- A digest line naming another platform or store (an APK, an Intel Mac, a home-screen widget) is
  dropped, as `testflight_release.py` does for Apple. A release left with nothing reads "Fixes
  and improvements".
- The bump refuses, changing nothing, when the digest isn't written yet. That is the order
  `docs/release-notes.md` step 5 already has.
- `tools/check_release_ready.sh` (Deploy to all's first job) fails if the version has no entry.
- `test/tools/metainfo_release_test.dart` pins the order, the dates, the escaping and the
  filter.

The release skill's bump commit includes the metainfo.

## The offline build, what pins what

### sqlite3: the registry entry must be suppressed

flatpak-flutter's registry applies the highest entry ≤ the locked version. Its `sqlite3/3.3.0`
entry therefore lands on our 3.7.1, and it does two things wrong:

- It downloads simolus3's prebuilt **plain** `libsqlite3.<arch>.linux.so`, which has no
  SQLite3MultipleCiphers, so the encrypted database can't be opened.
- It patches `lib/src/hook/assets.dart` at a line that 3.7.1 no longer has, so the build fails.

A top-level `"sqlite3"` key in the Flathub repo's `foreign.json` replaces the registry entry.
That key holds the sqlite3mc amalgamation zip as an `archive` source with `dest: native/sqlite3mc`
and `strip-components: 0` (the files sit at the zip root). The URL and sha256 are
`SQLITE3MC_URL` / `SQLITE3MC_ZIP_SHA256` in `tools/prepare_foss.sh` at the release tag. Local
entries are not versioned, and `$PUB_DEV` expands to nothing in them.

### pdfium comes from the registry

`printing` downloads pdfium during CMake configure (`download_project`). Its
`linux/CMakeLists.txt` is byte-identical in 5.14.2 and 5.15.1, so the registry's
`printing/5.14.2` entry and patch apply to us as they are. They pin bblanchon's pdfium
**chromium/7520**, where the AppImage and Snap ship printing's default 5200. The prebuilt has
Flathub precedent (Saber, Passy, OpenBubbles): pdfium has no practical offline source build
outside Chromium's toolchain. *"Binary files must not be present in the submission"* means
committed files, not URL sources.

### The FOSS lock

flatpak-flutter generates pub sources from the store `pubspec.lock`, because it has no option to
read another lock. That still covers the FOSS build: `check_foss_lock` guarantees every package
in `tools/foss/pubspec.lock` is pinned identically in the store lock. The cost is that the Dart
sources of sentry, google_sign_in and in_app_purchase ship as unused sources, which should be
explained in the PR. The alternative is a `patch` source adding `pubspec_overrides.yaml` and the
FOSS lock before flatpak-flutter's own `pub get`, so that only FOSS sources are generated.

The rest needs nothing:

- `super_editor`'s git dependency gets a git source.
- Of the FOSS graph's hooks, `objective_c` returns early on Linux.
- The plugins' googletest FetchContent is test-only.
- The generated `.g.dart` / `.freezed.dart` files are committed, so no `build_runner` runs.

### Flutter

flatpak-flutter reads the Flutter version only from a flutter git source `tag:` in its input
manifest. The update workflow sets that tag from `flutter-version:` in `appimage.yml` at the
release tag, the same pin the F-Droid recipe reads. 3.47.7 is not among flatpak-flutter's
precomputed SDK modules (it has up to 3.44.1), so it generates one. Proving that this works is
part of the first build.

## finish-args

Each one is justified in the PR:

- `--share=ipc`, `--socket=wayland`, `--socket=fallback-x11`, `--device=dri`: the GTK window.
- `--share=network`: the app is a client of an Invoice Ninja server.
- `--filesystem=xdg-download`: PDFs and exports save to Downloads. `getDownloadsDirectory` runs
  `xdg-user-dir`, which Flatpak answers for a granted xdg dir. Pickers use the FileChooser portal
  (`file_picker_linux` talks D-Bus to it directly).

Three are deliberately absent:

- No `--system-talk-name=org.freedesktop.NetworkManager`. `connectivity_plus` can't see network
  state from the sandbox, and the app assumes it is online, as it does on the Snap. It doesn't
  even ask: the sandbox has no system bus socket, so `ConnectivityWatcher.live` skips the plugin
  (`systemBusMissing`, `lib/data/services/system_bus_probe.dart`). Asking anyway made the
  plugin's failed connect escape as an uncaught zone error on every probe, and left the probe to
  run into its 5-second timeout. The first run of the Flatpak in Docker found it (2026-11-09).
- No `pulseaudio`, `xdg-pictures` or `xdg-documents`, which v1 asked for and this app doesn't
  use.
- No `--talk-name=org.freedesktop.secrets`. Flathub's permission review rejected it on
  `flathub/com.invoiceninja.InvoiceNinja#31` (2026-11-09): app-owned secrets go through the
  Secret portal, and the host keyring is for apps that need *existing* entries, which this one
  doesn't (it stores only its own database key). Inside a sandbox, libsecret already prefers the
  portal's file backend (`~/.var/app/<id>/data/keyrings/`), and KWallet now implements the
  portal too (KDE bug 466197), so the name only ever covered a desktop with no Secret portal.
  There the app shows the keyring screen (`SecureStorageUnavailableApp`), and the user can grant
  the name themselves with
  `flatpak override --user --talk-name=org.freedesktop.secrets com.invoiceninja.InvoiceNinja`.

`lib/app/linux_package.dart` tells a Flatpak from a Snap (`FLATPAK_ID` or `/.flatpak-info`
versus `SNAP`), for copy like the keyring hint.

## Deploy to all follows the release

Flathub publishes from its own repo, which this one cannot write to: a fine-grained token can't
reach a repo where its owner is an outside collaborator, and Flathub maintainers are outside
collaborators. So each side does its half:

1. **The Flathub repo updates itself.** Its update workflow (`.github/workflows/update.yml`
   there, added in `flathub/com.invoiceninja.InvoiceNinja#32`), modelled on
   `flathub/com.adilhanney.saber/.github/workflows/update.yml`, runs hourly and on dispatch.
   - It finds the newest `invoiceninja/flutter` release tag. Every release is still a GitHub
     *pre-release* until the general launch (docs/going-live.md § GitHub Releases), so it must
     not filter those out, or it never fires.
   - It compares versions as numbers, after stripping `-flathub…` from the manifest's current
     tag, and acts only on a strictly greater one. A plain "is it different" check, Saber's,
     would have opened `update-v5.1.23` on its first run and shipped plain v5.1.23, which predates
     the app-ID move (§ The Linux app ID is v1's Flathub ID).
   - It skips a version whose `update-v<version>` branch already exists. Without that, every
     hourly run before the merge regenerates and may force-push the branch, restarting the
     two-arch test build. The cost: a version whose PR was closed unmerged is never retried on
     its own. Delete its branch and dispatch the workflow to retry it.
   - It reads the Flutter and sqlite3mc pins from that tag.
   - It regenerates the offline sources with a flatpak-flutter image pinned by version and
     digest, passing `--app-module admin` (the module is not named after the ID's last part).
     flatpak-flutter leaves a `.flatpak-builder/` directory behind, which the repo's `.gitignore`
     keeps out of the PR. A forced dry run against v5.1.23 (2026-11-10) regenerated `generated/`
     byte for byte, so an update PR carries only the pins.
   - It opens branch **`update-v<version>`** and asks for GitHub auto-merge. That step is
     non-fatal, since it fails until Flathub enables auto-merge on the repo.
   - `flathub.json` sets `"disable-external-data-checker": true`: Flathub's own checker would
     bump the tag without regenerating the pub sources.
2. **Flathub's bot test-builds the PR** for x86_64 and aarch64. Its checks are `flathub/build`,
   `flathub/permissions` and others. Auto-merge then merges the PR, which publishes. Flathub
   grants auto-merge on request to verified apps. Without it, the PR waits for a human merge.
   - **The permission review diffs against the *published* build, not `master`.** A PR opened
     before the previous build reaches users is flagged with that build's permission changes
     again and waits for a moderator: #32, which touched no manifest, was held on #31's three
     removals because flathub.org still served v1's 5.0.204.
3. **Deploy to all's `flathub` leg** (`.github/workflows/flathub.yml` running
   `tools/follow_flathub_release.sh`) reads only. Its steps:
   - Waits up to 90 minutes for the PR. If none appears, it ends green with a warning to run
     that repo's **Update app** workflow: the hourly cron there is throttled on a quiet repo
     (5.1.24's PR waited until the workflow was dispatched by hand, 5 hours after the last
     scheduled run).
   - Fails, with the PR link, on a failed test build or a PR closed unmerged. These are the
     only red outcomes besides a missing Flathub repo.
   - Waits for the merge. If the checks pass, or are still running, and nobody has merged it,
     it ends green with a warning naming the PR to merge.
   - Watches `flathub.org/api/v2/appstream/com.invoiceninja.InvoiceNinja` for the version for 45
     minutes. A merge that isn't listed yet is still a success, because publishing takes hours.

   It is skipped until the repo variable `FLATHUB_ENABLED` is `'true'`. It needs no secret, and
   `test/lint/deploy_all_workflow_test.dart` keeps it that way. Dispatch `flathub.yml` by hand to
   re-follow a release.

The branch name `update-v<version>` is the contract between the two halves.

## When the Flathub build fails

- **Never re-tag.** The tag also carries the F-Droid APKs and every store's build number.
- Fix it in the Flathub repo, with a patch source or a regenerated sources file, and merge.
  Then dispatch `flathub.yml` to report it. Or ship the fix in the next release.
- A newer release while an update PR is still open gets a new branch. Close the stale PR.

## Bumping a pinned dependency

These are the moves that break the Flatpak build. Each needs a hand-written Flathub-side change
or a check, and a successful bot build on the next update PR is the proof.

- **`sqlite3` / sqlite3mc.** Follow `docs/fdroid.md` § Bumping sqlite3mc. The update workflow
  reads the new pins from `prepare_foss.sh`, but if flatpak-flutter's registry gains an entry
  newer than ours, check that `foreign.json`'s override still covers it.
- **`printing`.** If its `linux/CMakeLists.txt` changes, the registry patch may no longer apply.
  Diff it against 5.15.1's before bumping.
- **Flutter.** The update workflow follows `appimage.yml`. Check that flatpak-flutter generates
  the new SDK module, and whether a newer LLVM extension is needed.
- **A new plugin with native code or a build hook.** Check its `linux/CMakeLists.txt` and
  `hook/` for downloads (`FetchContent`, `ExternalProject`, `file(DOWNLOAD)`, a fetch in
  `build.dart`). Each needs a registry entry or a local `foreign.json` one.
- **flatpak-flutter itself.** Bump the pinned image on purpose, because its registry ships
  inside the image.

## The Linux app ID is v1's Flathub ID

The app went to Flathub first as a new app, `com.invoiceninja.admin` (`flathub/flathub#11087`,
2026-11-09). Its reviewer asked for an ID named after the app, Invoice Ninja, not "admin". The
ID named after the app is v1's, so the app takes v1's listing over instead, as the Snap already
does (both apps are the `invoiceninja` snap). That means:

- **The Linux ID differs from every other platform's.** Android, iOS, macOS and Windows stay
  `com.invoiceninja.admin`. On Linux, `APPLICATION_ID` in `linux/CMakeLists.txt`, the
  `appimage/com.invoiceninja.InvoiceNinja.*` file names, the desktop file's `Icon=` and
  `StartupWMClass=`, and the metainfo's `<id>` and `<launchable>` must all agree on
  `com.invoiceninja.InvoiceNinja`. The metainfo no longer `<provides>` or `<replaces>` v1's ID,
  because it *is* that ID.
- **The keyring namespace did not move.** `flutter_secure_storage_linux` keys its entries by the
  `APPLICATION_ID` its own `CMakeLists.txt` sees at configure time, and the database key is one of
  them. So `linux/CMakeLists.txt` sets `APPLICATION_ID` to `KEYRING_APPLICATION_ID`
  (`com.invoiceninja.admin`) around `include(flutter/generated_plugins.cmake)` and restores it
  after. Without that, every AppImage and Snap install from before the rename loses its key, and
  with it the encrypted database and any unsynced outbox rows. Never change that value.
- **The data directory moves once.** `path_provider_linux` names the support directory after the
  runtime GApplication ID, so `my_application.cc` (`migrate_legacy_data_dir`) renames
  `$XDG_DATA_HOME/com.invoiceninja.admin` to the new ID before Flutter starts. It never renames
  over an existing directory, and a failure is logged and leaves the old one in place. The cache
  directory is not moved: it is only a cache. Inside a Flatpak the data home is per app ID, so
  nothing is ever there to move.
- **v1's Flatpak users get this app as an ordinary update.** There is no end-of-life rebase and
  no new verification token, because v1's verification already covers the ID. v1's files sit
  under their own names inside `~/.var/app/com.invoiceninja.InvoiceNinja`
  (`data/com.invoiceninja.app`), and v1 kept nothing in a keyring, so nothing collides. Users
  start clean and sign in again, as Snap users do when v2 reaches the snap's stable channel.

## Submitting

The new-app submission (`flathub/flathub#11087`) is superseded by § The Linux app ID is v1's
Flathub ID. The launch is now a PR on `flathub/com.invoiceninja.InvoiceNinja` that replaces v1's
manifest, done and written by Hillel. `docs/going-live.md` § Flathub has the checklist. Before it:

- the app's upstream files must be in a released tag, since Flathub builds from one;
- the offline build must be proven on a fork, with `flatpak-builder-lint` clean on both
  the manifest and the repo (`--mirror-screenshots-url=https://dl.flathub.org/media`, or the
  screenshot check fails);
- screenshots of the Flatpak must be committed and named in the metainfo by URLs pinned to a
  commit SHA, never a branch.

What the PR has to cover:

- `flathub.json` drops `only-arches`, since this build has aarch64, and adds
  `"disable-external-data-checker": true`;
- the `finish-args` differ from v1's (§ finish-args), and a permission change needs a Flathub
  admin's approval on the PR, so each one is justified there;
- the AI disclosure, listing the upstream files agents wrote: the metainfo,
  `prepare_foss.sh --offline`, the release-notes tooling, the follow workflow, the Linux app-ID
  move and much of the app;
- a demo login for whoever reviews it, because the app does nothing without a server.

The first submission built **`v5.1.23-flathub`**, a tag outside `main`: v5.1.23 plus the four
Flathub commits (packaging, the no-system-bus network check, the screenshots, the workflow
rename). `main` held 48 unreleased commits at the time, and Flathub's first production build
should ship exactly what every other store already had. It was tagged by hand in a detached
worktree. Its name doesn't match the plain `vX.Y.Z` pattern that F-Droid's update check and
`check_release_ready.sh` look for, so both ignore it. The PR on v1's repo
(`flathub/com.invoiceninja.InvoiceNinja#31`) builds **`v5.1.23-flathub.2`**, made the same way:
`v5.1.23-flathub` plus the app-ID commit, cherry-picked with `-x`. Every later release reaches Flathub through
the update workflow (§ Deploy to all follows the release).

#31 merged on 2026-11-10 (`2b03ae26`). After it:

- The update workflow went in through `flathub/com.invoiceninja.InvoiceNinja#32`. `master` there
  requires `flathub/build` and `flathub/permissions`, so even a workflow-only change goes through a
  PR.
- Auto-merge was requested in `flathub/flathub#11108`. The precedent, `flathub/flathub#10341`, was
  granted only once the maintainers gave a concrete reason (an already-built update waiting on
  someone offline); "we want it" drew a refusal first.
- `https://invoiceninja.com/.well-known/org.flathub.VerifiedApps.txt` stays as it is: it holds
  v1's token, which is this ID's.

## Retiring v1's listing

Nothing retires now: this app is v1's listing's next version (§ The Linux app ID is v1's Flathub
ID). The PR that switched the manifest merged on 2026-11-10, so v1 gets no more version bumps
there: its last was 5.0.204 (#30).
