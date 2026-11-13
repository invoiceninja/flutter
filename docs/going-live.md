# Going live

Companion to CLAUDE.md § Release Notes. The checklist for taking the app out of beta on every store: the app changes that ship in the one launch release, the console step each store needs, and the decisions that sit outside the code. Tick items off here as they land. The deploy mechanics are in `docs/store-deployment-setup.md`, and its § 7 (Beta → GA flips) lists the beta-posture settings this checklist changes.

## Where each store stands

Updated 2026-11-12, after 5.1.25. Update this table whenever a store moves; the sections below hold the steps. The other goal running alongside is the Flutter 3.50 upgrade (`docs/upgrading-to-flutter-3-50.md` § Upgrade day, in order).

| Store | Production? | Ships to today | Next step |
|---|---|---|---|
| Flathub | ✅ since 5.1.23 (2026-11-10) | stable, as an update to v1's listing | the follow-ups in § Flathub |
| F-Droid | ✅ | f-droid.org | nothing until the app rename |
| Snap | ✅ since 5.1.25 (2026-11-13, revision 80) | `stable` and `edge`, replacing v1 | nothing until the app rename |
| Android (Play) | ❌ | Open testing | § Google Play |
| iOS | ❌ | TestFlight, external beta | § App Store (iOS and macOS) |
| macOS | ❌ | TestFlight | § App Store (iOS and macOS) |
| Windows | ❌ | Microsoft Store, Private audience | § Microsoft Store |
| Web | ❌ | built and checked by Deploy to Web; Pages and the release tarball wait on the Cloudflare project and the backend PR | `docs/web-deploy.md` § Going live |

Going live is one app release with the beta flag off, plus a store-console step on each store. Today every pipeline ships to testers: Play Open testing, TestFlight (iOS and macOS), and a restricted Microsoft Store listing. F-Droid, Flathub, the Snap and the GitHub Releases are already public.

On Play, the App Store and Microsoft the new app (`com.invoiceninja.admin`) has its own listing, so going live there leaves the v1 app (`com.invoiceninja.app`) untouched. **The Snap is the exception:** both apps are the `invoiceninja` snap, so releasing to `stable` replaces v1 for every snap user.

## App changes in the launch release

These ship together in one version to every store, so each store's first public build is already out of beta.

- [ ] Set `kAppIsBeta` to `false` in `lib/app/version.dart`. This switches on the store review prompt, which stays silent during the beta (`docs/review-prompt.md` § GA launch checklist).
- [ ] Set `kAppStoreId` in `lib/domain/review_prompt.dart`: the Apple ID in App Store Connect → App Information. iOS and macOS share one record.
- [ ] Swap the phone-app promo links from TestFlight and Play testing to the store listings (`docs/mobile-app-promo.md` § Swap the links at launch):
    - `kMobileAppIosUrl` → `https://apps.apple.com/app/id<number>`;
    - `kMobileAppAndroidUrl` → `https://play.google.com/store/apps/details?id=com.invoiceninja.admin`;
    - reword the `mobile_app_promo_testflight_step` and `mobile_app_promo_play_step` captions, and drop the "Beta" label.
- [ ] Rename the app from "Ninja Beta" to "Invoice Ninja":
    - `CFBundleDisplayName` in `ios/Runner/Info.plist` and `android:label` in `android/app/src/main/AndroidManifest.xml`;
    - drop " - Beta" from `msix_config` `display_name` in `pubspec.yaml` and from the `README.md` title;
    - update the v1 app's beta invitation (`kBetaAppNameMobile` in admin-portal) at the same time, since it names "Ninja Beta".
- [x] Snap: change `grade: devel` to `grade: stable` in `snap/snapcraft.yaml` (done 2026-11-12, ahead of the launch release, § Snap).
- [ ] Write the release notes, bump the version and run **Deploy to all** (`docs/release-notes.md`).

## Per-store steps

Each store needs its console step after the launch release is uploaded. Only the Snap and GitHub Releases need a workflow change.

### Google Play

`playstore.yml` releases to Open testing (`beta`) and can't reach production: the service account holds only "Release apps to testing tracks".

- [ ] Check that the store listing, Data safety, content rating and target audience are complete for `com.invoiceninja.admin`.
- [ ] Promote the launch release from Open testing to Production in the Play Console. Google reviews it.
- [ ] Optional: to release to production from CI, add `production` to the `track` options in `playstore.yml` and grant the service account "Release to production".

### App Store (iOS and macOS)

`appstore-ios.yml` and `appstore-macos.yml` upload to TestFlight and never submit for review. iOS and macOS are one App Store record.

- [ ] Fill in the iOS version page in App Store Connect: screenshots, description, keywords, privacy details, and a demo login for the reviewer.
- [ ] Pick the launch build from TestFlight and Submit for Review.
- [ ] Do the same for the macOS version.
- [ ] Release each version once approved, or set it to release automatically.

### Microsoft Store

`microsoft-store.yml` already publishes each build once Microsoft certifies it, to the restricted `InvoiceNinja.AdminPortal` listing (v1 is `InvoiceNinja.InvoiceNinja`). What restricts it is the **Audience**: Pricing and availability → Visibility → **Private audience**, the "Beta Testers" group. The submission API can't see the audience (its `visibility` is the Discoverability option and reads `Public` under a Private audience), so `tools/msstore_release_notes.py` can't check it; each CI submission copies the last, so the audience carries forward until someone changes it here.

- [ ] Partner Center → the app → Pricing and availability → Visibility → Audience: switch **Private audience** to **Public audience**. This is the Microsoft Store's go-live switch; nothing in CI makes it.
- [ ] Remove "Beta" from the Store listing name.

### Snap

Both apps are the `invoiceninja` snap, so this replaces v1 for every snap user.

v1's snap (admin-portal's `snap/snapcraft.yaml`, 5.0.204 on `stable`) plugs only `network`, `home` and `desktop`; it never used the keyring. A refresh to this app adds `password-manager-service`, which snapd doesn't auto-connect, so a build that needed that plug would have put every v1 user on the "Secure storage unavailable" screen. The database key now goes through the desktop's Secret portal instead, through the launcher `snap/local/keyring-backend` (`docs/setup.md` § Linux desktop / Snap). Docker has no AppArmor, so that was tested on the plugin's own code with a faked snap identity; the real snap is checked by the smoke test below.

- [x] Route the key through the Secret portal while the plug is unconnected (2026-11-12, in Docker on Ubuntu 22.04). An auto-connect request to the store is no longer needed.
- [x] Set `grade: stable`, so a tested `edge` revision can be promoted as it is.
- [x] Release it to `edge`: revision 80 (5.1.25), 2026-11-13.
- [x] Run **Snap smoke test** (`snap-smoke.yml`) on `edge`: on GitHub's Ubuntu 22.04 and 24.04 runners (real snapd and AppArmor) it checks a fresh install and a refresh from v1's `stable`, with no plug connected by hand. Run 43390912853 passed all four jobs: the plug unconnected, `default.keyring` written, the portal holding a secret for `snap.invoiceninja`, AppArmor denying only the Dart VM's harmless `/proc/sys/vm/max_map_count` read, and the sign-in screen on both launches.
- [x] Promote that revision: `snapcraft release invoiceninja 80 stable` (2026-11-13). To roll back, release revision 76 (v1, 5.0.204) to `stable`.
- [x] Make Deploy to all publish to `stable`: `snapcraft.yml` releases to `stable,edge`. A change to confinement, plugs or `snap/local/keyring-backend` is dispatched with `channels: edge` and passes `snap-smoke.yml` before it reaches `stable`.

### Flathub

**Flathub goes first** (decided 2026-11-08): the new app goes to Flathub straight into production, ahead of the other stores. Flathub's stable repo takes only stable software. It ships as an **update to v1's listing**, `com.invoiceninja.InvoiceNinja`, the way the Snap does (decided 2026-11-09, after the submission's reviewer asked for an ID named after the app: `docs/flatpak.md` § The Linux app ID is v1's Flathub ID). v1's Flatpak users are moved over by the update itself, and sign in again. **Hillel does every step here by hand.** Flathub's AI policy bars agents from its manifests and PRs, so an agent can explain a step but never take it. The background is in `docs/flatpak.md`.

- [x] Before launch: prove the offline build on a fork, for both arches, with `flatpak-builder-lint` clean (`docs/flatpak.md` § Submitting). Commit screenshots of the Flatpak and name them in the metainfo by URLs pinned to a commit SHA. Record the video.
- [x] Close the new-app submission (`flathub/flathub#11087`), since the app now ships under v1's ID. Closed 2026-11-09.
- [x] Cut a hand tag carrying the rename (`docs/flatpak.md` § Submitting), and open a PR on `flathub/com.invoiceninja.InvoiceNinja` that replaces v1's manifest with the from-source build of that tag. Drop `only-arches` from its `flathub.json` (this build has aarch64) and add `disable-external-data-checker`. The changed `finish-args` need a Flathub admin's approval on that PR, so justify each one there. Done 2026-11-09: tag `v5.1.23-flathub.2`, [com.invoiceninja.InvoiceNinja#31](https://github.com/flathub/com.invoiceninja.InvoiceNinja/pull/31).
- [x] Merge #31. Merged 2026-11-10.
- [ ] On a real x86_64 machine, install v1 from Flathub, update it to this app (the published build, or any test build's `.flatpakref` from flathubbot), and check that it launches to sign-in with its own dock icon and reopens without asking for the keyring again. Only an arm64 Docker run with v1-shaped leftovers has taken that path so far (2026-11-09).
- [ ] Add the update workflow to `flathub/com.invoiceninja.InvoiceNinja`: [#32](https://github.com/flathub/com.invoiceninja.InvoiceNinja/pull/32), open, then dispatch it once by hand and check it finds no update.
- [ ] Ask Flathub to enable auto-merge there: [flathub/flathub#11108](https://github.com/flathub/flathub/issues/11108), open. v1's verification already covers the ID, so `invoiceninja.com/.well-known/org.flathub.VerifiedApps.txt` needs no new token.
- [x] Set the repo variable `FLATHUB_ENABLED` to `true`, so Deploy to all follows each release onto Flathub (set 2026-11-10).
- [ ] Add the Flathub install link to `README.md`, and flip the Flatpak row in `FEATURES.md`.

### GitHub Releases

- [x] Releases are full releases: `--prerelease` is gone from `appimage.yml`, and every earlier release was flipped, v5.1.25 marked Latest (2026-11-13).

### F-Droid

Already public on f-droid.org: each tagged release reaches users once F-Droid's rebuild matches ours.

- [ ] Nothing beyond the app-name change. The listing title (`fastlane/metadata/android/en-US/title.txt`) already reads "Invoice Ninja".

## One-click production releases

Today one **Deploy to all** dispatch ships every store to its testing channel with no manual step: Play Open testing (track and rollout chosen in the dispatch form), TestFlight (built, What to Test set, added to "Beta - External" and submitted for beta review by `tools/testflight_release.py`), the restricted Microsoft Store listing (release notes set and committed by `tools/msstore_release_notes.py`), and to production on F-Droid, Flathub, the Snap (`stable`) and a GitHub Release marked Latest. The decision (2026-11-08) is to keep it that way until launch, then make the same single dispatch publish to production. That needs:

- [ ] **Play:** grant the service account "Release to production" (Play Console → Users and permissions), add `production` to `playstore.yml`'s `track` options and to Deploy to all's `play_track`, and make it the default. The `play_rollout` input already stages it.
- [ ] **App Store (iOS and macOS):** after the first version has been submitted and approved by hand (Apple needs its screenshots, description, privacy answers and age rating once), extend `tools/testflight_release.py` or add a sibling to: create the App Store version for the release, attach the build, set "What's New in This Version" from the same digest, and submit it for review with release-after-approval — plus a dispatch input choosing phased release (iOS, 7 days) or everyone at once.
- [x] **GitHub Release:** `--prerelease` dropped from `appimage.yml`, so the Release is marked Latest (2026-11-13).
- [ ] **Microsoft Store:** switch the listing's Audience to Public in Partner Center (§ Microsoft Store); CI needs no change, since `tools/msstore_release_notes.py` already commits a `Public` submission (`ALLOWED_VISIBILITY`). Drop " - Beta" from the listing name with the app rename above.
- [x] **Snap:** `snapcraft.yml` releases to `stable,edge` (2026-11-13, § Snap).
- [ ] Flip each workflow's header comment and `docs/store-deployment-setup.md` from "testers" to "production".

## Decisions outside the code

- [ ] **Moving v1 users over.** The v1 listings on Play, the App Store and Microsoft stay live after launch. Decide when to point v1 users at the new app and when to retire those listings.
- [ ] **Beta links.** Keep the TestFlight and Play testing links working for a while after launch: installed builds still point at them, and Snap, Microsoft Store and AppImage users can run an old build for months.
- [ ] **People who saw the beta promo.** Decide whether those who engaged with or dismissed it should see the public one; that needs a new preference key (`docs/mobile-app-promo.md` § Swap the links at launch).
