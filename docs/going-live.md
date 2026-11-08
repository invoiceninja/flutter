# Going live

Companion to CLAUDE.md § Release Notes. The checklist for taking the app out of beta on every store: the app changes that ship in the one launch release, the console step each store needs, and the decisions that sit outside the code. Tick items off here as they land. The deploy mechanics are in `docs/store-deployment-setup.md`, and its § 7 (Beta → GA flips) lists the beta-posture settings this checklist changes.

Going live is one app release with the beta flag off, plus a store-console step on each store. Today every pipeline ships to testers: Play Open testing, TestFlight (iOS and macOS), Snap `edge`, a restricted Microsoft Store listing and a GitHub pre-release. F-Droid is already public.

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
- [ ] Snap: change `grade: devel` to `grade: stable` in `snap/snapcraft.yaml` (see § Snap for what blocks it).
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

`microsoft-store.yml` already publishes each build once Microsoft certifies it, to the restricted `InvoiceNinja.AdminPortal` listing (v1 is `InvoiceNinja.InvoiceNinja`).

- [ ] Partner Center → the app → Pricing and availability → Visibility: make the listing public.
- [ ] Remove "Beta" from the Store listing name.

### Snap

Both apps are the `invoiceninja` snap, so this replaces v1 for every snap user.

- [ ] Get the Snap Store to auto-connect `password-manager-service`. Without it the app can't save or open its database until the user connects it by hand.
- [ ] Ship the launch release with `grade: stable` (§ App changes in the launch release).
- [ ] Change `release: edge` to `release: stable` in `snapcraft.yml`, or promote the revision with `snapcraft release invoiceninja <rev> stable`.

### GitHub Releases

- [ ] Decide whether releases stay marked pre-release. If not, remove `--prerelease` from `appimage.yml`.

### F-Droid

Already public on f-droid.org: each tagged release reaches users once F-Droid's rebuild matches ours.

- [ ] Nothing beyond the app-name change. The listing title (`fastlane/metadata/android/en-US/title.txt`) already reads "Invoice Ninja".

## Decisions outside the code

- [ ] **Moving v1 users over.** The v1 listings on Play, the App Store and Microsoft stay live after launch. Decide when to point v1 users at the new app and when to retire those listings.
- [ ] **Beta links.** Keep the TestFlight and Play testing links working for a while after launch: installed builds still point at them, and Snap, Microsoft Store and AppImage users can run an old build for months.
- [ ] **People who saw the beta promo.** Decide whether those who engaged with or dismissed it should see the public one; that needs a new preference key (`docs/mobile-app-promo.md` § Swap the links at launch).
