# Real-time updates

Companion to CLAUDE.md § Sync — non-obvious rules (the real-time bullet). What the hosted server broadcasts, how the app listens for it, and why a pushed event only ever schedules the ordinary `/refresh` delta. Code: `lib/data/services/realtime/` (`pusher_connection.dart`, `realtime_service.dart`), `RefreshScheduler.requestSoon`, and the dashboard's `realtimeRefreshes` seam.

## A pushed server event never writes an entity

**The rule.** When the hosted server announces a change, `RealtimeService` calls `RefreshScheduler.requestSoon()` and nothing else. The delta that follows is the same `auth.refresh()` the 5-minute poll and app-resume run, applied by the same `applyRefreshDeltaTemplate` path (`docs/sync.md` § The refresh delta tops up the browsable tables).

**Why not apply the payload.** Most events carry the full transformed record (`DefaultResourceBroadcast::broadcastWith` runs the entity's `Transformer`). Applying it directly would be a second write path into Drift, and every guard the delta path already has would have to be rebuilt on it: upsert-only, never over a newer or dirty local row, bound to the company whose token fetched it, dropped when a logout lands mid-flight (`_sessionGeneration`). The delta costs one request per burst of events. Re-deriving those guards would cost a correctness bug nobody would see until it overwrote an unsynced edit. The payload is a doorbell.

**Why it exists at all.** invoiceninja/flutter#170: a colleague chased invoices that had already been paid, because the app showed days-old data. The 5-minute foreground poll narrowed that window but didn't close it. With the channel open, a payment made in the portal reaches the invoice list, the detail screen and the dashboard in about the debounce plus one request.

**What still relies on the poll.** Anything the server doesn't broadcast (most edits made in another client), and every self-hosted install. The poll is unchanged and stays the fallback.

**Own writes echo back.** The server skips the sender only when the request carried `X-Socket-ID` (`dontBroadcastToCurrentUser()`). The app doesn't send it yet, so saving an invoice here can come back as an event and cost one extra delta. That is harmless: the delta never overwrites a newer local row. Sending the header is a listed follow-up.

## What the server broadcasts, and where

Probed against production on 2026-09-28 with a throwaway `dart:io` script (scratchpad, not committed):

- **Socket.** `wss://socket.invoicing.co/app/ninja-key?protocol=7&client=dart&version=<app>&flash=false` on the default port 443 answers `pusher:connection_established` with `activity_timeout: 30`. The key is literally `ninja-key`: the hosted React bundle builds `new Pusher('ninja-key', {cluster:'eu', wsHost:'socket.invoicing.co', wsPort:6002, forceTLS:false, authEndpoint: <api>/broadcasting/auth})`. On an https page pusher-js uses wss on `wssPort` (443), so 6002 is the plain-ws port no hosted client reaches. The key isn't a secret, since every browser receives it. It lives in `Env.pusherAppKey` / `Env.pusherHost`; overriding the key to `''` switches the feature off.
- **Channel auth.** `POST {baseUrl}/broadcasting/auth` returns `{"auth":"ninja-key:<hmac>"}`. The route is at the server root, **not** under `/api/v1`. It sits behind `token_auth` (`X-API-TOKEN`; failures are 403, so never the 401 logout path) and takes a JSON body `{socket_id, channel_name}`.
  - The route is **registered twice**: once by `BroadcastServiceProvider::boot` (token_auth only) and once in `routes/web.php:69`, *inside the `web` group, which runs `VerifyCsrfToken`*. The probe got a 200 from a non-browser client, so today the provider's registration is the one answering. If a server change ever flips that, the symptom is a 419 and a `realtime channel auth failed` warning in the diagnostics log, and the app quietly falls back to the poll.
- **Channels** (`routes/channels.php`):
  - `private-company-{company_key}`: the token's company must own the key. **This is the one the app joins.**
  - `private-user-{account_key}-{user_id}` (`user_id` is the hashed id): carries `RefetchEntity {entity, entity_id}` from the recurring-invoice update job, and **`App\Events\Socket\DownloadAvailable {message, url}`** when a bulk PDF / ZIP download or a company export the user requested is ready (React #3340). **Joined** since the download notice landed: `PusherConnection` now carries one channel per named *slot* (`subscribe(…, slot:)` replaces only its own slot), the company channel in the default slot and this one in `kUserChannelSlot`, signed in the active company's scope. `account.key` arrives on the account envelope (`AccountEnvelopeApi.key` → `AuthSession.accountKey`); until it does, only the company channel is carried.
- **Events on the company channel:**
  - `InvoiceWasPaid`, `InvoiceWasViewed`, `InvoiceWasCreated`
  - `PaymentWasUpdated`
  - `CreditWasCreated`, `CreditWasUpdated`
  - `ClientWasArchived`

  Each arrives under its class name (`App\Events\Invoice\InvoiceWasPaid`). The app switches on the name for one event only: **`DownloadAvailable` refreshes nothing** — it changes no entity — and is surfaced on `RealtimeService.downloads`, which the shell's `SyncEventListener` turns into a long-lived success toast with a Download action (the URL is checked by `openExternalUrl` / `isSafeWebUrl`). Every other non-protocol event, on either channel, is a reason to refresh.
- **Hosted only**, like React (`isHosted()` gates its private subscription). A self-hosted server may run no socket at all, and the app has no way to know where one would be.

## Who opens the socket

- **`Services.build(realtimeUpdates:)` defaults to `false`; only `lib/main.dart` passes `true`.** Every test, the integration harnesses and the screenshot runner build the full graph. A live socket there would reach the real host and leave reconnect timers pending, which fails `testWidgets`. With the flag off the service still exists (the dashboard reads `services.realtime.lastRefresh`) but never connects. `test/lint/realtime_opt_in_test.dart` fails the build if anything but `lib/main.dart` passes `true` — or if `main.dart` stops passing it.
- **The gate** is `credentials.isHosted && !Env.demoMode && !session.isDemo && Env.pusherAppKey.isNotEmpty`.
- **Driven by `auth.credentials`**, not by chaining `onActiveCompanyChanged` / `onBeforeLogout`. Credentials change on login, company switch, a switch's 401 rollback and logout, so one listener covers all four; the rollback is the case the callbacks never see. `ApiCredentials` has identity equality and is reassigned on every refresh, so the service compares the company id and ignores a no-op reassign.
- **The channel name** needs `companyKey`, which is on the Drift `companies` row, not on `AuthCompany`. On a first login the credentials can flip before that row lands (`companyKey` defaults to `''`), so the service watches `CompanyRepository.watchCompany` and takes the first non-empty key. A key that arrives after the user has switched away is ignored.
- **The auth POST runs in `RequestScope(companyId)`**, so a company switch mid-request throws `CompanySwitchedException` instead of signing one workspace's channel with another's token.
- **Foreground only.** `SyncLifecycleObserver` calls `pause()` on `paused` / `detached` and `resume()` on `resumed`. The resume path already runs a delta, so nothing announced while away is lost. `connectivity.onOnline` calls `onOnline()`, which reconnects now, skipping any backoff wait, but only if the app is in front.

## The protocol client

`PusherConnection` is a hand-rolled Pusher protocol v7 client over `web_socket_channel`, which is pure Dart, so web, native and the F-Droid build are identical. It holds *desired* state: whether a socket should exist, and which one channel it should carry.

- **Handshake.** Reads `socket_id` and `activity_timeout`, then signs and sends `pusher:subscribe` for the current channel.
- **A subscribe that doesn't take is retried, boundedly.** A failed auth POST (a 5xx during a deploy, a network blip, a 403) or the server's `pusher:subscription_error` retries on the reconnect backoff, `maxAuthRetries` (5) times — about half a minute — then gives up with a warning until the next socket. `connect()` on a live socket that gave up starts a fresh round, so `resume()` and `onOnline()` are real retries. Without this a single failed POST left the socket connected but carrying nothing, which on desktop and web is the rest of the session: nothing else drops a healthy socket. A subscribe already in flight or awaiting confirmation is never sent twice.
- **Liveness.** Any inbound frame re-arms an idle timer for `activity_timeout`. When it fires, the client sends `pusher:ping` and waits `pongTimeout` (30 s). If nothing answers, the socket is dead even though nothing closed it, so it is replaced. `WebSocketChannel.connect` has no timeout of its own, so a socket silent for `connectTimeout` (20 s) after opening is replaced too.
- **Close codes.**
  - 4000–4099 (bad key, app disabled): stop until the next `connect()`.
  - 4100–4199: back off.
  - 4200–4299: reconnect at once.
  - Anything else, including a plain drop: back off 1 s, 2 s, 4 s … capped at 60 s. Each delay is drawn from the upper half of its step, so clients dropped together don't return in lockstep.
- **`_ChannelSocket` calls `ready.ignore()`.** A failed connect completes `ready` with an error *and* surfaces it on the stream. Nothing awaits `ready`, and an unobserved failed future is an uncaught error in the diagnostics log.

## How a push becomes a refresh

- **`RefreshScheduler.requestSoon()`:**
  - Debounces by `kPushRefreshDebounce` (2 s), so a bulk action's burst costs one request.
  - Never starts within `kMinPushRefreshGap` (30 s) of the last refresh finishing. It waits the gap out rather than being dropped. Each run is a full `/refresh` — company envelope, reference bundles and roster rewritten in one transaction — so the gap caps an open client at two a minute however busy the account's portal is; the first change after a quiet spell still lands in about the debounce.
  - **Re-runs after a refresh that was already on the wire.** That refresh may have read the server before the change it was told about. This is the one place the scheduler's single-flight *queues* rather than drops.
  - Returns `true` once a refresh that started after the call landed cleanly, and `false` when `stop()` dropped it, the session ended, or that refresh failed.
- **`RealtimeService.lastRefresh`** is set only after a clean refresh, and only if the company hasn't changed meanwhile. A burst of events shares one pending future, so it produces one announcement.
- **The dashboard** refetches its server-aggregated sections (KPIs, chart, computed cards) on `realtimeRefreshes`, at most once per `DashboardViewModel.kRealtimeRefetchGap` (30 s). The refetch trails, so the last change in a burst still lands. It reuses `_onResyncCompleted`'s company check and boot deferral. The lists and the two Drift-backed panels follow on their own. `test/lint/dashboard_panel_wiring_test.dart` pins the argument in `_buildVm`, because it's optional and dropping it compiles.

## Tests

- `test/data/services/realtime/pusher_connection_test.dart` (fake socket): handshake and signed subscribe, event filtering, ping/pong, the stall watchdog, each close-code range, resubscribe after a drop, channel switch, and the bounded subscribe retry (transient failure, persistent refusal, `connect()` after giving up, `subscription_error`, no double subscribe).
- `test/data/services/realtime/realtime_service_test.dart`: the hosted / enabled gate, the key wait, `/broadcasting/auth` scoped to the company, switch and rollback, sign-out, one announcement per refresh, and pause / online / resume.
- `test/data/services/refresh_scheduler_test.dart` (group `requestSoon`), `test/data/services/sync_lifecycle_observer_test.dart`, and `test/ui/features/dashboard/dashboard_view_model_test.dart` (group `a pushed server change`).

Two fake-time traps these tests step around:
- A bare `tester.pump()` flushes microtasks but elapses no time, so a zero-delay timer never fires. Pump `Duration.zero`.
- `await subscription.cancel()` inside `testWidgets` can hang forever on a root-zone future. Don't await it.
