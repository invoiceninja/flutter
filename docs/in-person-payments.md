# In-person card payments (Stripe Terminal)

Companion to CLAUDE.md § Strict rules (the store-SDK bullet, whose general evidence is in
`docs/fdroid.md`; this doc is Stripe Terminal's part of it). Taking a card in person — Tap to Pay on
the phone or a Stripe M2 Bluetooth reader — and paying an invoice with it. The server half is
invoiceninja/invoiceninja#13435 (gateway type 32, `card_present`): it creates every PaymentIntent
and records every payment, and the device only reads the card.

This doc covers the packaging that is in place today. The data, recovery and UI layers land in
later changes and extend it.

## The SDK is reached only through `StripeTerminal`

`packages/store_services/lib/src/stripe_terminal.dart` wraps `mek_stripe_terminal` in plain value
types; the FOSS twin declares the same API with `isAvailable == false`. Connection-level calls are
static on `StripeTerminal`; each payment is a `TerminalPayment` from `beginPayment(clientSecret)`.

- **No mek object crosses the boundary.** A mek `PaymentIntent` and a mek `TerminalException` both
  print the PaymentIntent's client secret in `toString()`, so every result is copied and every
  error becomes a `TerminalError(code, message)`. A `PlatformException` keeps only its code and
  message — its details can carry the PaymentIntent.
- **A payment is one object, and its steps are guarded.** `collect()` reads the card without
  charging; after the server changes the PaymentIntent, `collect()` again (Stripe needs a fresh
  read). `confirm(paymentIntentId:, amount:)` charges only the card `collect()` read, for that
  PaymentIntent at that amount, so a stale read or a read made before the server raised the amount
  can never be charged. One payment at a time; a second `beginPayment` while one is unfinished
  throws `readerBusy`, and a step while another runs throws `invalidState`.
- **A cancel is never lost.** `cancel()` works until `confirm()` starts. Between steps it marks the
  payment cancelled, so every later step throws `canceled`; during a read it also cancels the SDK
  operation, which is started at once — mek's `CancelableFuture` starts lazily on its first
  `await`, and a cancel before that does nothing. The SDK's cancel can hang forever, so it is fire
  and forget, bounded at 5 seconds; the server's cancel is what closes the PaymentIntent.
- **A confirm is never cancelled, and an unclear failure says so.** A declined card (or a
  PaymentIntent back in `requires_payment_method`) leaves the payment open for another card; any
  other confirm failure is `outcomeUnknown` — the card may have been charged, and only the server
  can say.
- **A token source belongs to one account.** `initialize(account:, fetchToken:)` keeps the SDK's
  cached token and reader session for the same account and `reset()`s for another. `reset()`
  abandons the payment in progress, drops the source (a token still being fetched for the old
  account is thrown away: `_generation`), bounds every step, never throws, and if Stripe couldn't
  clear its credentials the next `initialize` tries again. Every token failure reaches the SDK as
  a `TerminalError` — the plugin relays it to native code, which can't take a null message.
- **`connect` always passes `tosAcceptancePermitted`** — the SDK defaults it to true, which would
  let a non-admin accept Apple's Tap to Pay terms.
- **A reader's kind is the kind `discover` looked for**, not its `deviceType`, which the SDK leaves
  null for a type it doesn't know.
- **Reader prompts go to `StripeTerminal.events`**, read when each event arrives, so the screen
  that is collecting sets them.
- **Error codes are matched on mek's enum**, so a renamed code fails to compile instead of
  becoming `unknown`. Brands and statuses come back in Stripe's own spelling (`mastercard`,
  `requires_capture`).

## Who sees "Collect card payment", and what the app asks the server

- **The server decides.** `TerminalController.ensureConfig` asks `GET /terminal/config` only after
  the cheap gates pass (`kCardPresentEnabled`, the mobile app with Stripe's SDK, not the demo,
  `create_payment`) — a user without that permission would get a 401. An answer stands for five
  minutes (an admin who turns Card present on sees it without a restart); a failed fetch keeps the
  last answer and is tried again after a minute; an older server's 404 is remembered as "not here"
  for the session. None of it toasts or reports.
- **`terminalAvailability`** (`lib/domain/terminal/terminal_eligibility.dart`, pure) adds the
  invoice (not deleted, paid, cancelled, reversed or unsaved; drafts are fine — the server marks
  them sent) and how this phone can read a card: Tap to Pay when the phone can and the gateway's
  Stripe account is in `kTapToPayAndroidCountries`, else a Bluetooth reader only once one has been
  connected in this app (`DevicePrefKeys.cardReaderUsed`, account scope) — not on every phone that
  merely has Bluetooth. A hosted plan below Pro shows it as an upgrade.
- **Build switches**: `IN_CARD_PRESENT`, `IN_CARD_PRESENT_BLUETOOTH`, `IN_CARD_PRESENT_SURCHARGE`
  (all default true) pull the feature or one part of it without a code change.
- **The SDK session is one Stripe account and Location** (`account: company/gateway/location`): a
  connection token belongs to exactly one.
- **A session end or a company switch resets it** (`onBeforeLogout`, `onActiveCompanyChanged`):
  the session's own state goes at once, then the SDK is reset once no charge is in flight
  (`guardCharge`, from a card's finalize to the server's answer), waiting up to a minute — unless a
  newer session was prepared meanwhile.
- **`TerminalRepository` is online-only** (the CLAUDE.md outbox exception): every call in the
  company's `RequestScope`; a refusal the screen branches on comes back as a
  `TerminalServerError(code, message, data)` read from the body's `error_code` — 409 and 403 bodies
  are kept on `ConflictException.body` / `ServerException.body` for this — and a plain 422 is
  `field_errors` with its first message. `apply_fee` goes in the quote's query as `1` / `0`
  (Laravel's `boolean` refuses `true`). `finalize` times out at 12 s, inside Stripe's 30 s
  between reading a card and charging it. The invoice is re-read after a create (a draft was marked
  sent) and after every `complete` / `cancel`; a recorded payment also re-reads its client and the
  payment.

## A collection, step by step

"Collect card payment" is on the invoice's record screen only (`InvoiceActions.itemsFor` /
`quickItemsFor` take a `TerminalAvailability`; lists, the dashboard and the editor pass none), as a
`Card` tile that leads on a draft too. It opens `showCollectCardPaymentScreen`, a full-screen route on
the root navigator that is never saved as a route; `CollectCardPaymentViewModel` drives it.

1. **Configure.** The first usable gateway and Location; the amount (a deposit if one is due, a
   draft's amount, else the balance); the surcharge switch only when the gateway allows it (an admin
   acknowledges the rules first, `surcharge_acknowledgement`). Every figure is the server's `quote`.
   Permissions, the SDK and the reader start in parallel, so nothing waits after "Collect".
2. **Create.** A new `collection_id` per attempt; the same one only to retry a create whose outcome
   is unknown (the server answers the same PaymentIntent). `collection_closed` gets a new id once;
   `collection_open` offers **Cancel it and start again** (the server's cancel records the payment
   instead if it was charged after all).
3. **Read, then finalize — after every read.** `finalize` may raise the PaymentIntent for a credit
   card's surcharge, or lower it again for a debit card on the next read: then the card is read
   again (at most three reads). A read more than 25 s old by the time finalize answers is read again
   too (Stripe allows 30 s), and a finalize that fails cancels — a charge is never made on a guess.
4. **Confirm** at the latest `amount_minor`. From finalize to the server's answer everything runs
   inside `TerminalController.guardCharge`: nothing — not Cancel, Back, a company switch or a
   sign-out — interrupts it. A screen that closes before the charge gives the payment up (after
   finalize answers, if it was deciding); a charge already under way finishes, and the server
   records it.
5. **Result.** One table maps `complete` (and `cancel`):

| Answer | Screen |
|---|---|
| `recorded`, `unapplied` | Approved (and the unapplied note), receipt by email or QR |
| `processing` | Recording — "Charged. The payment is being recorded." + Check again |
| `requires_payment_method` after a confirm | Declined — the charge failed; another card on a new payment session |
| other `requires_*` after a confirm started, a confirm with an unknown outcome, `complete` failing (asked 3 times) | Checking — "We couldn't confirm whether the card was charged. Don't take another card for this invoice yet." + Check again, or Cancel the payment (the server records it instead if it was charged) |
| `rejected`, `orphaned` | Charged, couldn't be recorded — contact support (the server alerted) |
| `canceled`, `failed` | Cancelled — the only screen that says the card wasn't charged, with a decline |

A decline leaves the PaymentIntent open: **Try another card** reads again and finalizes again. Every
SDK and server code has words (`terminal_error_text.dart`, tested exhaustively).

**Support runbook.** A payment the app shows as Checking: find the PaymentIntent in Stripe by its
`collection_id` metadata; the client's System Logs show what the server did; `php artisan
ninja:terminal-reconcile --pi=pi_…` records it by hand. Never Enter Payment for it — the server
records every charge itself, and a manual payment would count it twice.

## The device check and permissions are ours, not the SDK's

Stripe's Android SDK checks permissions but never asks; its iOS SDK may prompt for location at a
moment the app doesn't choose; and its own `supportsReadersOfType` asks for location and Bluetooth
just to answer. So `StripeTerminal.deviceSupport()`, `requestPermissions(kind)` and
`openSettings()` go over `invoice_ninja/stripe_terminal`. `requestPermissions` answers `granted`,
`denied` or `blocked` (the system won't ask again — offer Settings), and concurrent calls share one
request.

- **Android** — `StripeTerminalPlugin` in `packages/store_services/android`. Tap to Pay needs
  Android 13, an ARM processor (Stripe ships its kernels for ARM only), NFC and a hardware
  keystore — Stripe's own preflight, except the key it generates to check; `tapToPayBlocker` says
  what's missing. A Bluetooth reader asks for "Nearby devices" (Android 12+); Tap to Pay asks for
  location only. Precise location is always asked for together with approximate — Android 12+
  ignores a precise-only request — and only precise counts as granted (Stripe takes approximate on
  a device with no GPS; this is stricter). A dialog survives a config change.
- **iOS** — `StripeTerminalBridge` in `ios/Runner/AppDelegate.swift` asks for location while in
  use; for a Bluetooth reader a refused Bluetooth permission is `blocked` (iOS asks for it itself
  when a scan starts). A prompt iOS never shows is answered after 2 minutes. `deviceSupport`
  reports `entitlementMissing` for Tap to Pay on iPhone, hardcoded: it changes in code once Apple
  grants `com.apple.developer.proximity-reader.payment.acceptance`.

Stripe takes no payment with device location services off (`locationServicesEnabled`). Whether
Stripe accepts iOS's reduced ("approximate") accuracy is untested — check on a phone.

## What the SDK costs the packaging

It ships to every store user, whether or not they ever take a card.

- **minSdk 26 for every build**, F-Droid's included (`android/app/build.gradle.kts`, never below
  Flutter's own floor; `packages/store_services/android/build.gradle`).
- **Merged permissions would make hardware required.** The SDK's `BLUETOOTH*`,
  `ACCESS_*_LOCATION`, `ACCESS_WIFI_STATE` and Tap to Pay's `READ_PHONE_STATE` imply the bluetooth,
  location, wifi and telephony features as required, and Play then hides the app from devices
  without them (checked with `aapt2 dump badging` on a release APK).
  `packages/store_services/android/src/main/AndroidManifest.xml` marks all four `required="false"`.
  Telephony was already implied by the app's own `CALL_PHONE`, so this also makes the store build
  installable on Wi-Fi-only tablets for the first time.
- **Play's listing changes with this release**: new dangerous permissions (precise and approximate
  location, Nearby devices, `READ_PHONE_STATE`) and, once the SDK starts, what it sends Stripe
  (location, a device id, network details, its own crash diagnostics). Update Data safety, and the
  Financial features declaration, before a build with this reaches Play.
- **`gwpAsanMode`.** Tap to Pay's AAR sets `android:gwpAsanMode="always"` on `<application>`, which
  would apply to the whole app and turn any native heap bug anywhere into a crash. The app manifest
  puts it back to `default` (`tools:replace`). Whether Stripe's Tap to Pay checks need "always" is
  untested — check on a phone before the feature ships.
- **The `:stripetaptopay` process.** Tap to Pay's AAR runs an activity there. Content providers
  without a process (ML Kit's, Sentry's, androidx.startup) stay in the main process; only Stripe's
  `TtpContentProvider` runs there. In the main process Stripe's `PaymentMethodSpecsContentProvider`
  starts at every launch, and mek registers lifecycle observers when the activity attaches — both
  cheap.
- **Backup.** Stripe's device id (`stripe_terminal_shared_prefs.xml`), its offline database and
  the Tap to Pay kernel's prefs (`com.visa.vac.tc.sharedPref.xml`) belong to one phone and its
  keystore, so `backup_rules.xml` and `data_extraction_rules.xml` leave them out.
- **Size.** About 19 MB of native code and assets per universal APK (7–8 MB of it per ABI) and
  about 12 MB of dex, roughly +24 MB installed on an arm64 phone. On iOS `StripeTerminal.framework`
  is a 34 MB dynamic framework, loaded at every cold start.
- **R8.** Stripe's consumer rules keep everything under `kotlin.**`, `kotlinx.**`, `okhttp3.**`,
  `okio.**`, `com.google.gson.**`, `dagger.**`, `javax.**` and `com.squareup.**`, and rename every
  frame's source file to `SourceFile` — app-wide, not just for Stripe — so release stack traces need
  the mapping file. `packages/store_services/android/consumer-rules.pro` adds one `-dontwarn`:
  `play:review-ktx` (from `in_app_review`) references
  `com.google.android.gms.common.annotation.NoNullnessRewrite`, which nothing here defines, and
  Stripe's `-keepattributes *Annotation*` made R8 resolve it and fail the release build.
- **iOS** needs `NSBluetoothAlwaysUsageDescription` and `NSLocationWhenInUseUsageDescription`
  (`Info.plist`, `InfoPlist.xcstrings`) as soon as the SDK is linked. Stripe's privacy manifest
  declares coarse location and product interaction as collected, so the App Store privacy answers
  change too. The `bluetooth-central` background mode is left for the release that turns the
  feature on, with its App Review note.
- **USB.** Plugging a Stripe reader in over USB offers to open the app (Stripe's
  `UsbEventReceiverActivity`). Harmless.
- **F-Droid** drops the SDK with the rest of the store graph (`docs/fdroid.md`); the CI classpath
  check also greps for `com.stripe`.
- **The fork.** mek 5.7.3 has no `collectPaymentMethod` / `confirmPaymentIntent`, which the
  surcharge flow needs (read the card, let the server decide, then charge). The app pins
  `hillelcoren/mek-packages@3f2cf999` (BreX900/mek-packages#171, which also fixes an Android cancel
  that never answered) until a release ships it — `docs/upstream-workarounds.md` entry 19, which
  also records a known Android issue left in the fork.

## Secrets never reach a log

A PaymentIntent client secret (`pi_…_secret_…`) and a connection token (`pst_live_…` /
`pst_test_…`) are redacted by `redact()` (`lib/app/logging.dart`) by key and by value — quoted,
bare or percent-encoded. The console and the diagnostics log, the debug-capture ring and Sentry all
go through it. In Sentry (`runWithCrashReporting`'s `redact`) it runs over each breadcrumb as it is
recorded and, before an event leaves, over its message, exception values, breadcrumbs and contexts;
an event it can't scrub is dropped. The native SDKs' own network breadcrumbs and failed-request
events are off: they record other SDKs' traffic, Stripe's among them, and never pass those
callbacks. Native crash reports still carry the breadcrumbs synced to the native scope, which is
why scrubbing happens when a breadcrumb is recorded. `test/app/logging_redact_test.dart` pins the
shapes.
