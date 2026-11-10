# Companion apps — the WordPress plugin and the Chrome extension

Companion to CLAUDE.md § Strict rules, which carries the one rule. This doc carries who is offered each app on which build, the store-policy reasoning, and where each link lives.

Invoice Ninja ships two apps beside this one, and the app points at them quietly — a card in Settings, a card on the screen each one connects to, and one What's New release. Nothing opens on its own, nothing is a gate, and there is no new preference.

- **The WordPress plugin** (<https://wordpress.org/plugins/invoiceninja/>) adds a store (Products, Cart and Checkout blocks), a customer account area, a Quote Request Form, subscriptions, WooCommerce invoicing and product sync to a WordPress site. Its setup asks for an **admin API token** and the Invoice Ninja address; the address defaults to `https://invoicing.co` and the plugin strips a trailing `/api/v1`. A token needs Pro or Enterprise on hosted (any plan self-hosted).
- **The "Invoice Ninja: Tasks" Chrome extension** (<https://chromewebstore.google.com/detail/invoice-ninja-tasks/dlfcbfdpemfnjbjlladogijcchfmmaaf>) creates tasks and runs timers from the browser. It signs in with email and password (and a one-time code) through `/api/v1/login`, with a URL field for self-hosted — **no API token, so no plan gate**. It runs only in desktop Chrome.

| Piece | File |
|---|---|
| The rules: platforms, gates, links, the server address | `lib/domain/companion_apps.dart` |
| Integrations card ("More from Invoice Ninja") | `lib/ui/features/settings/views/basic/account_management/integrations_screen.dart` |
| API Tokens WordPress setup card | `lib/ui/features/tokens/views/token_list_screen.dart` (`WordPressSetupCard`, through `SettingsEntityListScaffold.footer`) |
| Task Settings Chrome card | `lib/ui/features/settings/views/basic/task_settings_screen.dart` (`_ChromeExtensionSection`) |
| What's New highlights | `lib/domain/release_notes.dart` (`ReleaseHighlightCompanionApp`, 5.1.24), `lib/ui/features/whats_new/whats_new_dialog.dart` (`whatsNewTargetReachable`) |
| Settings search gates | `lib/ui/features/settings/settings_search_catalog.dart` (`showsWordPressPlugin`, `showsChromeExtension`) |
| Tests | `test/domain/companion_apps_test.dart`, `test/ui/features/settings/views/basic/account_management/integrations_screen_test.dart`, `test/ui/features/tokens/token_list_wordpress_card_test.dart`, `test/ui/features/settings/views/basic/task_settings_screen_test.dart` |

## The WordPress plugin and Chrome extension links never open on their own, never show Chrome on native Apple builds, and appear only where usable

Three rules, each decided in `lib/domain/companion_apps.dart` and pinned by `test/domain/companion_apps_test.dart`:

- **Never on their own.** Every link is a row or a button the user taps. No dialog, no toast, no sidebar card, no schedule, no "don't show again" preference. The one unprompted appearance is the 5.1.24 What's New highlight, and it opens Integrations inside the app, never the store page (the dialog never links out: `docs/whats-new-dialog.md`).
- **No Chrome on native Apple builds.** `chromeExtensionPlatform` is false on native macOS and iOS whatever else is true. See the store-policy section below.
- **Only where usable.** WordPress needs an admin token the account can mint; Chrome needs a desktop Chrome and the Tasks module. A user who can't use an app is never shown it — not as an upsell, not as "needs Pro".

## Per platform

| Build | WordPress plugin | Chrome extension |
|---|---|---|
| Web on a desktop OS (macOS, Windows, Linux, ChromeOS) | ✅ | ✅ |
| Web on a phone or tablet (iOS, iPadOS, Android) | ✅ | — (`touchPrimary`) |
| Native Windows (Microsoft Store, MSIX) | ✅ | ✅ |
| Native Linux (Flatpak, Snap, AppImage) | ✅ | ✅ |
| Native macOS (Mac App Store) | ✅ | **never** (2.3.10) |
| Native iOS (App Store) | ✅ | never (2.3.10, and no extensions) |
| Native Android (Play, F-Droid) | ✅ | never (no extensions) |

WordPress is the same everywhere because its gate is the account, not the platform. On the web, `defaultTargetPlatform` is the browser's operating system, and Flutter's engine reports an iPad asking for the desktop site as iOS (it checks `navigator.maxTouchPoints`), so `Env.isTouchPrimary` — derived from that platform — is the right "no extensions here" signal. ChromeOS reports Linux, which is correct: Chrome there takes extensions.

## Store-policy reasoning

- **Apple guideline 2.3.10.** An App Store build may not show "names, icons, or imagery of other mobile platforms or alternative app marketplaces". The Chrome Web Store is a marketplace and Chrome carries Google's brand, the same reason the mobile-app promo never names Android or Google Play on native macOS (`docs/mobile-app-promo.md` § Store-policy review). So no Chrome row, card, highlight, bullet or search hit on native macOS or iOS. `test/domain/release_notes_test.dart` includes `chrome` in the App Store group's forbidden pattern, so a Chrome bullet or highlight without `hiddenOn: {appleStore, …}` fails the build.
- **WordPress is allowed on Apple builds.** It is neither a mobile platform nor an app marketplace, the plugin is a free download, and it is a way to use the same account, not a payment path.
- **No purchase copy.** A free hosted account is never shown the WordPress plugin, precisely so no surface says "upgrade to use this". Adding a plan, a price or an upgrade link next to either app would make it an external purchase call to action, which the App Store and Microsoft Store forbid.
- **No icons or logos.** The rows use Material icons (`storefront_outlined`, `extension_outlined`, `smartphone_outlined`); no WordPress, Chrome or Google artwork.
- **No auto-open, no new preferences.** See the rule above.

## The gates

| Function | True when |
|---|---|
| `wordPressPluginOffered(session)` | `kCompanionAppsEnabled`, the active company's user is an admin or owner, and the account is self-hosted or `hasProAccess` (Pro, Enterprise or a trial — the gate `TokenListScreen` uses), and it is not a demo (`Env.isDemoBuild`, `Env.demoMode`, `session.isDemo`) |
| `chromeExtensionOffered(session)` | `kCompanionAppsEnabled`, `currentChromeExtensionPlatform()`, the company has the Tasks module on, and not a demo. No role or plan gate: the extension signs in as the user |
| `companionAppOffered(app, session)` | the one of the two for `app` — what the What's New highlight checks |

Flip `kCompanionAppsEnabled` to switch every surface off at once.

## Where each link lives

- **Settings → Account Management → Integrations — the permanent home.** A "More from Invoice Ninja" `FormSection` after the API Docs button with up to three rows drawn as the Integrations card's own tiles (`_IntegrationTile` with a subtitle, so the two cards share one icon column and one trailing column and the new card reads as settings, not a promotion): WordPress plugin and Chrome extension (each with `Icons.open_in_new`, opening the listing through `openExternalUrl`), and Mobile app (a chevron, opening `showMobileAppPromoDialog(isManual: true)`, gated by `mobileAppSectionShown` like the Device Settings card). The card is left out of `sections` when no row is offered — a hidden card still costs a gap (`docs/comments-and-activity.md`).
- **Settings → API Tokens — how to connect WordPress.** A card under the token list (or its empty state), through `SettingsEntityListScaffold.footer`. Hosted: one line, because the plugin already defaults to `https://invoicing.co`. Self-hosted: the line names the server address too, and a `CopyValueRow` holds it — `session.baseUrl` with any `/api/v1` and trailing slash removed (`wordPressServerAddress`). Then "Get the plugin". Shown where `wordPressPluginOffered` holds; the page itself already requires self-hosted or Pro.
- **Settings → Task Settings — the Chrome extension.** The last card, at company scope only (a link has nothing to say for one client or group), where `chromeExtensionOffered` holds.
- **What's New, 5.1.24.** Two highlights with `ReleaseHighlightCompanionApp` targets: shown only where `companionAppOffered` holds, and both open Integrations. The Chrome highlight and bullet also carry `hiddenOn: {appleStore, nativePhone}`.

`CopyValueRow` (`lib/ui/core/widgets/copy_value_row.dart`) is the mobile-app promo's former private `_CopyRow`, promoted so the API Tokens card shares it: a bordered value with an always-visible Copy button, copying through `copyToClipboard`. The value reads left to right in every locale (it is a value, `docs/right-to-left-layout.md`) and wraps rather than clipping when large text leaves it no room on one line.

## Settings search

`kAccountManagementIntegrationsSearchKeys` (`api_docs`, `companion_apps_section`, `wordpress_plugin`, `chrome_extension`) is spread into the Integrations tab, and `chrome_extension` is on `kTaskSettingsSearchKeys`. Each companion key has a `keyGates` entry on the same predicate as the card — `SettingsSearchScope.showsWordPressPlugin` / `showsChromeExtension`, filled from the two functions above in `.from()`; the card title passes when any of its three rows would show; Task Settings' Chrome key also needs `!isCascade`. No ungated keyword map names "wordpress" or "chrome", so a search never opens a page without the row it promised (`test/ui/features/settings/settings_search_catalog_test.dart`).
