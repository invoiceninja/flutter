# Deep links

Companion to CLAUDE.md § Deep links. The main file carries the link shapes and the rule for each behaviour; this doc carries the evidence — why the https form replaced the custom scheme, why Flutter's own deep linking must stay off, the arrival choreography, and the registry obligations a new entity inherits.

## The link is https because a custom scheme is not a link

**The link is https because a custom scheme is not a link.** No messenger
linkifies one — WhatsApp, Element, Slack and every mail client match `http(s)`
and a few well-known schemes — so a shared `invoiceninja://` URL arrived as inert
text the recipient had to select, copy and paste into ⌘K, which is
invoiceninja/flutter#144. Nothing the app declares changes what a third-party
linkifier matches, so the shape had to change. `buildEntityDeepLink` emits the
https form whenever the session has a usable base URL (`appLinkBaseFrom`, which
keeps a sub-path install's own path and drops `userInfo` — a credentialed base
URL must never reach the clipboard) and falls back to the custom scheme
otherwise, which is also what every link already in the wild looks like.

## Only the hosted host can be OS-verified

**Only `kHostedAppLinkHost` can ever be OS-verified, and the `/app/` prefix is
what keeps that claim narrow.** Android's `<intent-filter>` and Apple's
`applinks:` entitlement both need a build-time literal, so a self-hosted origin
cannot be verified no matter what either side ships — those links open the
browser and land on that instance's own `/app/` bridge page, which offers the
`invoiceninja://` launch to Android and iOS before continuing to the web client.
A desktop browser is sent straight on instead, from a script in the page's
`<head>`: the server emits `/app/` links in its own notification emails now, and
the offer would otherwise be an interstitial in front of every one of them.
Since the prefix is a real path (unlike the hash-routed web client, where every
URL's path is `/`),
the claim covers shared links and not the client portal or payment pages that
share the host. The manual console steps behind all of this — the Apple
capability, the Play fingerprints, the deploy order — are in `APP_LINKS.md`.

## Flutter's own deep linking must stay off

**Flutter's own deep linking must stay off, and turning it off costs iOS its
cold start unless the shim stays too.** Both flags default to **on** when absent
(`FlutterActivityLaunchConfigs.deepLinkEnabled`,
`FlutterSharedApplication.isFlutterDeepLinkingEnabled`), and the engine then
pushes the raw URI at go_router *as well as* `DeepLinkRouter` — bypassing
validation, the company switch and the biometric hold, and for an https link
landing on the route-error screen, which sticks, because `NavStatePersister` has
no filter for error locations and `stripTransientQuery` strips only `module_off`
and `view=full`. go_router also discards `initialLocation` whenever the platform
default is set, so a cold-start link overrides the restored route. Hence
`flutter_deeplinking_enabled=false` (on the **activity** — `shouldHandleDeeplinking()`
reads `ActivityInfo.metaData`, so an `<application>` entry is silently ignored)
and `FlutterDeepLinkingEnabled` `<false/>` in the iOS plist only, since the macOS
embedder has no built-in deep linking for the key to disable. With it off,
`ios/Runner/SceneDelegate.swift` is what keeps cold starts alive: under the scene
lifecycle UIKit delivers the launch URL only in `connectionOptions`, the engine
converts that to `application:didFinishLaunchingWithOptions:`, and `app_links`
implements only `openURL` and `continueUserActivity`. macOS needs its own shim
for a different reason — `app_links` ships its macOS universal-link handler
commented out. Both are logged in `docs/upstream-workarounds.md`, and
`test/lint/universal_links_test.dart` fails the build if either goes missing,
along with the claim, the prefix and the flags.

## A link naming another instance is refused

**A link that names another instance is refused, not followed.** Company hashids
are per-instance and derived from sequential ids, so with default salts a link
from one install can resolve to a *different* company's record on another — the
`?company=` guard cannot see it, because the id genuinely resolves. `DeepLinkRouter`
compares the link's host against the session's; the bridge page forwards
`server=<its own origin>` on the custom-scheme URL so that path, which carries no
origin of its own, can be checked too. It is compared, never navigated to.

## The route lives in the URI path, behind a constant host

**The whole route lives in the URI path, behind a constant `app` host.** That
is not cosmetic: `Uri.parse` lower-cases a reg-name host (`_normalizeRegName`
in the SDK's `uri.dart`) and never the path, and entity ids are case-sensitive
hashids — so encoding the route *as* the host would work only for as long as
every `routePath` happens to be lowercase snake_case, and would fail silently
the day one isn't. The constant host also keeps record links in a different
namespace from server-owned OAuth-return hosts (`calendar_connection`), which
is what lets Android keep **host-pinned** intent filters instead of claiming
the whole scheme.

## The four pieces, deliberately split

Four pieces, deliberately split:

- `lib/app/entity_links.dart` — a **leaf** (only the registry and the `EntityType` enum it
  already pulls in) holding
  `buildEntityDeepLink` / `parseAppDeepLink` / `parseCalendarCompleteLink`, plus
  `entityRecordPath`, which lives here and is re-exported from `router.dart` so
  link building doesn't drag in the router's whole UI graph. Build uses
  `entityRecordPath`, so a shared link opens exactly what tapping the row opens
   — **never `entityDestination`**, whose `user`/`company`/`design` cases point
  at the reader's own settings screens rather than a record.
- `lib/app/deep_link_router.dart` — `Services.deepLinks`, the arrival
  choreography. Takes only the auth slice it needs (session + lock listenables
  + an `isAuthenticated` predicate) so it is testable with plain fakes, and
  `attach(go:, contextOf:)` wires navigation once `MaterialApp.router` exists.
- `lib/app/app_deep_links.dart` — the platform bridge (`app_links`), which only
  transports URIs into `deepLinks.open`, plus the web branch that reads the page
  URL (§ On web the link is the page URL). The **command palette is the second
  source**: paste a link into ⌘K and it routes through the same `open`. That is
  the only way to follow one on Linux, the only way to follow a *pasted* one on
  web (neither receives a link from the OS), and the fallback wherever a
  messenger renders the scheme as inert text.
- `lib/ui/features/shell/widgets/switch_company_guarded.dart` — the company
  switch, shared with `CompanyPicker` so a link can't fork it (trap 4).

## Five things that fail silently

Five things fail silently if you change this:

1. **Every platform delivers a cold-start link twice — except iOS, which used to
   deliver it not at all.** Android, macOS and Windows all replay the cached
   `initialLink` into the stream on `onListen` *and* return it from
   `getInitialLink()`, and the bridge subscribes to both. iOS under the scene
   lifecycle delivered **zero** times until `SceneDelegate` started handing the
   launch URL over by hand (see above), which is also why cold-start links there
   were being handled by Flutter's built-in deep linking rather than by this
   class — with no validation, no company switch and no biometric hold.
   Harmless for the calendar return; for a record link it means two
   unsaved-changes prompts and two pending-outbox prompts. `_pending` de-dups
   and `_inFlight` serialises two *different* links arriving mid-dialog. Scope
   `_pending` to what is **in flight**, never to history: the palette feeds the
   same `open`, where re-following a link is an ordinary user action, and a
   history guard silently killed it for the rest of the session. `reset()`
   cannot cancel a link already chained onto `_inFlight`, so it bumps
   `_generation` and `open` captures it — otherwise a queued link runs after
   logout, finds the gate shut, re-defers itself and replays into the **next**
   account's session, which is the one thing `reset()` exists to prevent.
2. **`parseAppDeepLink` drops the entire query string**, not just `company`.
   `stripTransientQuery` only knows `module_off` and `view=full`, so anything
   else would be written into `nav_state.current_route` and replayed on every
   cold start.
3. **Nothing modal runs before the auth + biometric gate.** The lock screen is
   an ordinary `Scaffold` — a `showDialog` lands right on top of it — so a link
   arriving while signed out or locked is *held* and replayed once both clear.
   This is also why there is no `/login?from=` round-trip: a route can't carry
   the company, and holding the parsed link can. **The gate must listen to
   `auth.credentials`, not just `auth.session`**: `AuthRepository` assigns
   `_session` before `_credentials` on both login and `restore()`, so a gate
   that reads `isAuthenticated` (credentials) while waking on the session edge
   sees `false`, drops the link, and then replays it minutes later off an
   unrelated background refresh. `main.dart` merges `credentials` first into the
   router's own `refreshListenable` for the same reason. And a held link is
   dropped on logout (`deepLinks.reset()` from `onBeforeLogout`) — it belongs to
   the account that was signed in when it arrived. **The replay waits for the
   frame after the gate opens.** On that frame the router swaps out the page the
   gate kept up (`/lock`, `/login`). A company switch's prompt pushed before the
   swap landed on that page and went with it. The switch then read as cancelled,
   and the link did nothing. `deep_link_router_test.dart` pins this with a real
   router.
4. **A company switch goes through `switchCompanyGuarded`**
   (`lib/ui/features/shell/widgets/switch_company_guarded.dart`, shared with
   `CompanyPicker`), never `auth.switchCompany` directly — the unsaved-changes
   and pending-outbox prompts are non-negotiable. Navigation afterwards is the
   record path, **never `companySafeLocation`**, which strips `/clients/<id>`
   back to `/clients`.
5. **An unvalidated path must never reach `go()`** — go_router's top-level
   `errorBuilder` replaces the whole app with the route-error screen, outside
   the shell with the sidebar gone. `!disabled && routePath.isNotEmpty` is
   **not** that validation: `user` (`/settings/account`, which is not a route
   at all) and `company` (`/settings/company_details`, whose only children are
   tab slugs) are registered directly in `Services.build`, so they carry
   neither flag. `kNonRecordRouteEntityTypes` is the guard, applied by BOTH
   `parseAppDeepLink` and `buildEntityDeepLink` — asymmetry there means Copy
   Link hands out a URL the app itself refuses. Note the test fixture is what
   let this ship: it built its registry from the module specs alone, so the
   two registry-only entries were invisible to it.

## On web the link is the page URL

**On web nothing delivers the link — it *is* the page URL, so `?company=` is
honoured once at boot and stripped before it can persist.** The `app_links`
plugin has nothing to intercept there and is skipped outright, so `AppDeepLinks`
reads `Uri.base` once instead: the browser simply loads the URL. Only the **fragment** of it
reaches the app — with the hash strategy the engine builds `defaultRouteName`
from `window.location.hash` alone (`url_strategy.dart`'s `getPath`), so the real
path and `?search` are invisible, and go_router's `_effectiveInitialLocation`
lets that platform value beat the restored `nav_state` route. So a record link
arrives as `…/#/clients/<id>?company=<id>` and go_router routes it *without* the
company: nothing on the route side reads one, and the record would open against
whatever workspace happened to be active — "not found" whenever it belongs to
another. Worse, the stray param survived into `nav_state.current_route`
(`stripTransientQuery` knew only `module_off` and `view=full`) and replayed a
workspace switch on every cold start.

`DeepLinkRouter.openWebInitialLocation` is the fix, and it is deliberately thin:
it reads the company out of the fragment (or from ahead of the `#`, which is a
legal way to write the same link and equally invisible to go_router),
synthesises a link and hands it to the same `open()` as every other source. That
buys the signed-out/locked hold, the `_pending`/`_inFlight` de-dup, the guarded
switch and its toast — and the closing `go(target.path)` is what drops the query
from the live location. Two guards matter: a `company` on a route that isn't a
record (`/#/dashboard?company=…`) is ignored **in silence**, because `open`
would otherwise toast `invalid_url` at boot for a URL nobody typed; and a
fragment with no `company` is left entirely alone, since go_router is already
routing it and a second `go()` would be a duplicate.

The synthesised link uses the **custom-scheme** form, which carries no instance
claim, so the cross-instance check (§ A link naming another instance is refused)
is skipped rather than failed. That is the honest reading — this is the address
of the app the user is already in, not a link someone sent them — and it is also
required: the web build is not always served from the instance it talks to (the
GitHub Pages demo is not), so comparing the page host against the session host
would refuse every link there. A forged company id stays bounded, because
`_open` only switches to a company the session actually lists.

## Landing on a record the recipient never opened

Landing on a record the recipient has never opened is the normal case, so every
detail screen passes `hydrate:` to `EntityDetailScaffold` (`repo.ensureLoaded`)
and the scaffold holds its spinner until that resolves — without it the screen
flashes "not found" for the length of the fetch. `emptyAction:` gives a genuinely
missing record a way onward instead of a dead end.

## Two registry notes this depends on

Two registry notes this depends on. `EntityHandlers.detailBuilder` is read as
"does this entity have a detail screen?" by `entityRecordPath`, so a
settings-hosted entity whose detail screen is registered by the *settings*
router still has to declare it (bank accounts do — the builder there registers
no route, since the entity has no branch); leave it null and the shared link
points at the editor while the list's own row tap goes to the viewer. And a
settings `:id` route needs its own id-keyed subtree (`_settingsRoute` adds one):
go_router derives `state.pageKey` from the route *pattern*, so every id under a
root shares one page, and these screens bind their VM from `widget.id` in
`initState` — without the key, going straight from record A to record B keeps
showing A. The entity branches already do this in `buildEntityRouteBlock`.
