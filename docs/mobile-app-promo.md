# Mobile-app promo — telling desktop and web users about the phone app

Companion to CLAUDE.md § Strict rules, which carries the one rule. This doc carries the store-policy evidence, who sees the promo and when, and what to change at launch.

A one-screen dialog that pitches the phone app to someone using the desktop app (macOS, Windows, Linux) or the web, modelled on admin-portal's beta promo (`admin-portal/lib/ui/app/beta_promo/`, which told v1 users about this app). It opens on its own a few times, and stays reachable from the sidebar, About and Device Settings. Native iOS and Android never show it.

| Piece | File |
|---|---|
| The rules: targets per surface, presentation, eligibility, links | `lib/domain/mobile_app_promo.dart` |
| The schedule, a device preference | `lib/app/mobile_app_promo_controller.dart` (`DevicePrefKeys.mobileAppPromo`) |
| The dialog | `lib/ui/features/mobile_promo/mobile_app_promo_dialog.dart` |
| The automatic opener | `lib/ui/features/mobile_promo/mobile_app_promo_host.dart` (built by `SyncEventListener`) |
| Sidebar card | `lib/ui/features/shell/widgets/mobile_app_promo_footer.dart` |
| Device Settings card | `lib/ui/features/settings/widgets/mobile_app_section.dart` |
| About entry | `lib/ui/features/shell/widgets/about_dialog.dart` |

## The mobile-app promo never shows Android or Google Play on native macOS, never gates anything, and never carries purchase copy

Three store rules, each enforced in one place:

- **No other platform on native macOS.** `mobilePromoTargets(isWeb: false, platform: macOS)` is `[ios]`, and the dialog only ever names a phone it was handed — no toggle, text, icon, QR code, link, tooltip or semantics label for Android. `test/ui/features/mobile_promo/mobile_app_promo_dialog_test.dart` pumps the macOS surface and asserts that neither step — the QR step nor the sign-in step — shows or speaks "Android", "Google Play" or the Play URL, including the value Copy Link puts on the clipboard. ("Google" as the *sign-in provider* — "You sign in here with Google" — is fine: it names how this user signs in, not a platform, and the Mac sign-in screen offers Google too.) The "Beta" chip is also hidden there, so the Mac app can't read as calling itself a beta (guideline 2.2). A Mac *browser* is not the App Store build and offers both phones.
- **Never a gate.** The dialog always has the ✕, Esc, and a dismiss button, and nothing in the app waits on it. Esc needs the dialog's own `DismissIntent` action: the route's handler is off whenever the barrier isn't dismissible (`_DismissModalAction.isEnabled` returns `route.barrierDismissible`), and the barrier isn't, so a stray click beside the card doesn't count as an answer.
- **No purchase copy.** Both links go to a free download. Adding a plan, a price or an upgrade link to this dialog turns it into an external purchase call to action, which both stores forbid.

## Store-policy review

The desktop app ships to the Mac App Store (TestFlight today), the Microsoft Store, the Snap Store and as an AppImage, and the same code runs on the web (`docs/store-deployment-setup.md`). Reviewed October 2026 against [Apple's App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) and the [Microsoft Store Policies](https://learn.microsoft.com/en-us/windows/apps/publish/store-policies) (v7.20).

| Rule | Source | How the promo complies |
|---|---|---|
| "don't include names, icons, or imagery of other mobile platforms or alternative app marketplaces in your app or metadata, unless there is specific, approved interactive functionality" | Apple 2.3.10 | iPhone/iPad only on native macOS (above). Reviewers apply it literally — reported rejections cite "Google Play is mentioned in the ads" and "Android references in the binary" ([Unity forum](https://discussions.unity.com/t/binary-rejected-by-apple-because-theres-a-google-play-banner-at-the-end-of-the-ads/672380), [Thunkable forum](https://community.thunkable.com/t/solved-app-rejection-ios-guideline-2-3-10-performance-accurate-metadata/1032461)). |
| "Displaying your own apps for purchase or promotion within your app" is acceptable | Apple 3.2.1(i) | It promotes our own app, in one dialog — not a catalog. |
| Apps must not "force users to … download other apps … in order to access functionality" | Apple 3.2.2(x) | Always dismissible; gates nothing. |
| Apps "shouldn't primarily be marketing materials" / advertising may not be the primary content | Apple 4.2.2, Microsoft 10.10.4 | At most three automatic opens ever, none before the third day of use. |
| Interstitials need "easily accessible and visible close/skip buttons large enough" | Apple 2.5.18 (written for ads; followed anyway) | A 44-px ✕ with a tooltip, plus a labelled button. |
| No buttons or links to purchasing outside in-app purchase | Apple 3.1.1(a) / 3.1.3, Microsoft 10.8.1 | The links are free downloads. |
| Notifications may promote only your own products | Microsoft 10.9.4 | Not a notification; and it is our own product. |
| Third-party names and logos only as their owners permit | Microsoft 11.2; Apple and Google badge and trademark guidelines | No official store badges (they require unmodified artwork and attribution) and no Apple logo glyph (not licensed to third parties): plain-text names and generic Material phone icons. |

Two things that look like problems and aren't:

- **The binary contains Android strings.** `kMobileAppAndroidUrl`, the `google_play` / `android_app` keys and `upgrade_launcher.dart`'s Play URL are compiled into every build; what a reviewer sees is what 2.3.10 is applied to. One of them *was* reachable: About → Debug Panel → screenshot-size menu headed a group "Google Play" on every desktop. `visibleScreenshotPresetGroups` now drops that group from a **release** macOS build (debug and profile runs, where the store screenshots are captured, keep it).
- **A TestFlight link inside a Mac App Store build.** Guideline 2.2 is about *submitting* betas to the store, not linking to one. It is still the first link to swap once the iOS app is public.

Rejected: a single QR code pointing at a redirect that sends Android phones to Google Play. It would avoid printing the word on macOS while doing exactly what 2.3.10 forbids — a Mac user with an Android phone can get the link from the web app instead.

## Who sees it, and when

`mobilePromoEligible`: a signed-in session that is not the demo (`isDemo`, `Env.isDemoBuild`, `Env.demoMode`) and whose server a phone could reach — `localhost` / `*.localhost`, `127.*`, `0.0.0.0` and `::1` are skipped (`isLoopbackHost`). A private-network server — anything `isLocalNetworkHost` (the self-hosted login's classifier) calls local apart from loopback: RFC 1918, link-local, CGNAT, `.local` / `.lan` / `.home.arpa` / `.internal` — is shown with "Your phone needs to be on the same network".

Where it can open:

| Surface | Targets | Presentation |
|---|---|---|
| Native macOS | iPhone | QR code |
| Native Windows, Linux | iPhone, Android (toggle) | QR code |
| Web, desktop browser | iPhone, Android (toggle) | QR code |
| Web, phone browser | that phone | Store button — a phone can't scan its own screen |
| Native iOS, Android | — | never |

The automatic open (`MobileAppPromoHost`) and the sidebar card, which `main()` switches on with `Services.build(mobileAppPromote: true)` — off in every test and harness, so the web CI smoke test never gets a barrier over its taps or a card shortening the nav list it taps:

- **Not before the third day** this device is used while signed in (`daysSeen`, one per calendar day).
- **At most three times**: a close without engaging snoozes +7 days, then +30, then stops. The last one offers Close only.
- **Never in a launch that already showed an automatic dialog** — the local-data recovery notice or the missing-name prompt (`AutomaticDialogs`).
- **Only at a quiet moment**: about 4 s after the shell settles, then rechecking every 3 s while a dialog or sheet is up (a root-navigator route, or a `PopupRoute` holding focus — most sheets push onto a branch navigator, where the shell's `isCurrent` can't see them), a text field has focus, a form is dirty (`UnsavedChangesGuard`), the path is a settings one or ends in `edit`, `new`, `email`, `refund` or `statement`, or the window isn't in front. It gives up for the launch after about a minute of checks. A `MenuAnchor` menu is not a route and is an accepted gap — the promo opens over it and closes back to it.
- **The first half-second ignores clicks and keys**, so a click aimed at what was under it doesn't spend a reminder.
- **A forced close is not a snooze.** A 401, the idle timeout or `/setup` replacing the shell pops the dialog with `null` and unmounts the host; only a `null` with the host still mounted (Esc) counts.

Taking the app — Copy Link, the store button, or "I've installed it" — ends the automatic opens and the sidebar card; "I've installed it" also shows the sign-in details (email; server URL when self-hosted; a password note when the user signs in here with a provider the phone app doesn't offer — Microsoft anywhere, Apple on Android, any provider self-hosted). "Don't show again" ends both too. About and Device Settings open it on request forever. Closing a requested open never snoozes the schedule, but what the user *does* in it still counts — Copy Link, the store button or "I've installed it" ends the automatic opens, and "Don't show again" (offered there while the sidebar card would remain) ends both.

The schedule is a `PrefScope.device` key: "this machine has been told", so a sign-out keeps it. It is per device — someone on both the web and the desktop app can see up to six automatic opens.

## The sidebar card yields to every other footer card

`MobileAppPromoFooter` renders only when no trial, expired-plan or white-label card does, never on the collapsed rail (an unlabelled phone glyph reads as "call"), and only where `sidebarShowsUpsell` says the viewport can afford optional chrome. It is mounted between `PlanExpiredFooter` and `WhiteLabelFooter` because nothing may follow the white-label card (`test/lint/sidebar_footer_wiring_test.dart`, `docs/sidebar-and-shell.md`).

## Swap the links at launch

When the phone apps leave beta:

1. `kMobileAppIosUrl` → the App Store listing (`https://apps.apple.com/app/id<number>`).
2. `kMobileAppAndroidUrl` → `https://play.google.com/store/apps/details?id=com.invoiceninja.admin`.
3. The beta-step captions: `mobile_app_promo_testflight_step` and `mobile_app_promo_play_step` describe TestFlight and "Become a tester"; replace them with store wording, and drop the "Beta" label and the `_qr_*` "…beta" semantics labels.
4. Builds already installed keep the old links. Snap, Microsoft Store and AppImage users can run an old build for months, so keep the TestFlight and testing links working for a while after launch.
5. Decide whether people who engaged with or dismissed the *beta* promo should see the public one: that needs a new preference key (`mobile_app_promo_json` already says "told").

Until then, watch two limits. A TestFlight public link caps at 10,000 testers, and a full beta shows "This beta is full" to everyone the promo sends there. And `kMobilePromoEnabled` is compile-time: it stops the promo in the *next* build, not in ones already installed.
