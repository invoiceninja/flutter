# Passkeys

Companion to CLAUDE.md § Strict rules. Signing in with a passkey and managing passkeys (Settings → User Details → Two-Factor), against the server's WebAuthn routes (`PasskeyService`, lbuchs/webauthn v2.2.0): what each platform needs, why the app offers passkeys only where they are proven to work, and what the server and the hosted domain must ship for each platform to light up.

## A passkey is offered only where `PasskeyReadiness` has proven it works on this device against this server, and no OS sheet opens on options `allowsCeremony` refuses

A ceremony that cannot succeed is worse than no button. A rejected Android sign-in is a 400 `invalid_credentials` that counts toward the server's per-email login lockout (`LoginController::handleFailedLogin`). A rejected registration fails *after* the OS has created the credential, leaving it orphaned in the user's password manager. So:

- `PasskeyReadiness.isReady` (`lib/data/services/passkey_readiness.dart`) decides whether the login button and the Add button show. It fails closed.
- `PasskeyReadiness.allowsCeremony` runs on the options the server actually sent, before the OS sheet opens. `LoginViewModel.submitPasskey` and `PasskeyRepository.add` (through `beforeCeremony`) both call it.
- Nothing retries a passkey sign-in.

## Safe until the PRs merge and deploy

The app ships independently of two outside changes, and may do so long before them:

- **The server PR** (invoiceninja/invoiceninja, branch `feature/native-passkeys`): it accepts the Android app's origin, lists it in the options as `android_origins`, grants `get_login_creds` in `assetlinks.json` where the server is the relying party, and excludes existing credentials at registration.
- **The hosted association files** on `app.invoicing.co` (a PR to invoiceninja/ui): `/.well-known/apple-app-site-association` with `webcredentials` and `/.well-known/assetlinks.json` with `get_login_creds`, both served as `application/json`. Today both return React's `index.html`.

Until each lands, the platforms that depend on it stay hidden, and each one appears once its pieces are deployed:

| Platform | Ready when (`isReady`) | Before the ceremony (`allowsCeremony`) |
|---|---|---|
| Android | The RP's `assetlinks.json` grants `com.invoiceninja.admin` `get_login_creds` | The options' `android_origins` include **this install's** origin. `MainActivity` reports its signing-certificate hashes on `invoice_ninja/app_identity`. A server without the fix lists none, and a debug or upload-key build is never listed; either would have its assertion rejected. |
| iOS / macOS | Hosted only. `app.invoicing.co`'s AASA lists `NPC44Y2C98.com.invoiceninja.admin` under `webcredentials` | The options name `app.invoicing.co` |
| Windows | Always: its WebAuthn API takes any RP ID | Not loopback |
| Web | The page host is the RP ID or below it (the browser's own rule) | Same |
| Linux, F-Droid, demo | Never | — |

The RP ID is inferred before options exist (hosted: `kHostedPasskeyRpId`; self-hosted: the API host) and re-checked against the options' own. Answers are cached for `PasskeyReadiness.cacheFor` (10 minutes), so a deploy shows up without an app update. A ceremony that still fails with `notAssociated`, for example while Apple's CDN catches up (it caches an AASA for up to a day), shows `passkey_unavailable`.

## The relying party is the server's, so a platform works only where its domain is associated

The RP ID is the host of the server's `REACT_URL`. On hosted that is `app.invoicing.co` (`kHostedPasskeyRpId`), which is where React registered every existing passkey. It is not `kHostedAppLinkHost` (`invoicing.co`), and moving it would orphan those passkeys.

| | Origin the platform reports | Association it needs |
|---|---|---|
| Android | `android:apk-key-hash:` + unpadded base64url SHA-256 of the signing certificate | `get_login_creds` in `https://<rpId>/.well-known/assetlinks.json` (fetched at runtime, so a self-hosted server can provide it); the server must list the hash (`addAndroidKeyHashes`, derived from `APP_LINKS_ANDROID_FINGERPRINTS`) |
| iOS / macOS | `https://<rpId>` | `webcredentials:<rpId>` in the app's entitlements (compile-time, so hosted only; macOS Release only, as with `applinks:`) and `webcredentials` in the RP's AASA |
| Windows | `https://<rpId>` | none |
| Web | the page origin | the page host must be the RP ID or a subdomain of it |

The Play app-signing certificate is `BB:BC:8B:FB:…:7D:E8:88` (Play Console → App signing, Play App Signing enrolled), the first default of `APP_LINKS_ANDROID_FINGERPRINTS` and what hosted's `invoicing.co/.well-known/assetlinks.json` lists. Debug and upload-key builds report other hashes, so test Android passkeys on a Play internal-testing install.

A self-hosted server still on `.env.example`'s `REACT_URL=http://localhost:3001` has RP ID `localhost`, which no app can use. The fix is the admin's: set `REACT_URL` to APP_URL (or unset it). Until then `isReady` refuses a loopback RP ID on every platform but web, where the browser enforces the rule.

## The passkey sheet is our own native code on one channel, never a pub plugin, and only Android's half is non-free

`NativePasskeys` (`lib/data/services/native_passkeys.dart`) talks to `invoice_ninja/passkeys`, which three native halves answer:

| Platform | Where | API | What crosses the channel |
|---|---|---|---|
| Android | `packages/store_services/android`, `PasskeysPlugin.kt` (hosted by `StoreServicesPlugin`, the package's one `pluginClass`) | Credential Manager 1.6.0 (the version `google_sign_in` already pulls) | the server's WebAuthn JSON as `requestJson`, minus lbuchs' placeholder `extensions: {exts: true}`; Credential Manager's `responseJson` back, already WebAuthn JSON |
| iOS / macOS | `packages/passkeys_native/darwin` (SwiftPM + podspec, `sharedDarwinSource`) | AuthenticationServices' platform provider. It builds at iOS 15 / macOS 12, so the deployment targets don't move, but `isAvailable` is true only from iOS 16 / macOS 13: before that passkeys were a developer-toggle preview and every ceremony fails | rpId, the challenge and credential ids as bytes; the OS builds `clientDataJSON` and returns it with the rest as bytes; Dart builds the JSON |
| Windows | `packages/passkeys_native/windows` | webauthn.dll, loaded with `LoadLibraryExW` (never linked: a Windows release without it must still launch), WebAuthn API v1 struct versions only (make-credential options 3, get-assertion options 4) | as Apple, except that Windows takes `clientDataJSON` from the caller, so Dart builds it (`origin: https://<rpId>`, what the server accepts from a page on that host); the call blocks, so it runs on a worker thread (a COM single-threaded apartment) and answers through a registered message to the top-level window; each ceremony carries a cancellation id, so closing the app with the sheet open ends it instead of hanging the exit |

Every native half replies with one of six error codes (`cancelled`, `not-associated`, `no-credentials`, `already-registered`, `unsupported`, `failed`), which `NativePasskeys.failureForCode` folds into a `PasskeyFailure`. Android's mapping matches a few Play Services outcomes by message text, the same strings `passkeys_android` 2.15.0 matched; everything else is matched by class, which R8 keeps working.

Below Android 14 the passkey provider is Play Services, so the Android half lives in the non-free `store_services` and the F-Droid build has none: the channel throws `MissingPluginException`, `isAvailable` is false, and there is no passkey UI. `passkeys_native` is OS APIs only, so it is free and the F-Droid build carries it (unused there).

**Why not Corbado's `passkeys_*` plugins.** `passkeys_darwin` requires macOS 13.5 at compile time (the app's macOS floor is lower), `passkeys_windows` links webauthn.dll so the app fails to load where it is missing, and the umbrella `passkeys` package's web plugin calls `window.close()` before `runApp` unless Corbado's `bundle.js` is vendored. What they added over the OS APIs was the error-code switch.

Web uses the browser's `navigator.credentials` directly (`lib/data/services/web_passkeys_web.dart`, behind the `web_passkeys.dart` seam). It does the same base64url ↔ `ArrayBuffer` conversion React's `src/common/helpers/passkeys.ts` does, and maps a rejection's `DOMException.name` inside the promise chain, where the error is still typed as a JS value.

`PasskeyAuthenticator` (`lib/data/services/passkey_authenticator.dart`) picks between web and native.

## Signing in

- **Placement.** "Login with a Passkey" sits on the credentials step, under Log in, behind an "or" divider. The options route is behind `api_secret_check`, and the self-hosted secret field lives on that step. Enter never triggers it.
- **The requests.**
  - `POST /api/v1/passkeys/login/options {email}` returns `{data: {publicKey, challenge_token, android_origins}}`.
  - Then `POST /api/v1/login {email, passkey_challenge_token, passkey_authentication: {id, rawId, type, clientDataJSON, authenticatorData, signature, userHandle?}}` (flattened as React sends it).
  - No password is sent: with one, the server treats the request as a password login.
  - The server skips TOTP for a passkey, so a required code field does not hold it back.
  - The session tail is `login`'s: `_wipeIfIdentityChanged`, then `_persistAndActivate`.
- **Errors.** Each is a toast:

| Error | What the user sees |
|---|---|
| options 400 (no passkeys, or no account: the server answers both alike) | `no_passkeys_registered`, and focus moves to the password |
| options 404 / 405: a server from before passkeys, reachable only from Windows and web, where nothing proves server support before the options | `passkeys_not_supported_by_server`, and the button goes for the session |
| `notAssociated`, `noCredentials`, `unsupported`, or options `allowsCeremony` refuses | `passkey_unavailable` |
| cancelled | nothing |
| `/login` 400 | the server's message |

## Managing passkeys

The Passkeys card (`passkeys_section.dart`, `PasskeysViewModel`) is a section of the Two-Factor tab, not a tab of its own: the tab is short, and React puts passkeys in the same place.

- **Rows.** Each row shows the name (one line, ellipsised), `created` and `last_used`. `created_at` arrives as an ISO string and `last_used_at` as epoch seconds. Each row has a Remove button whose semantics label names the passkey.
- **Add.**
  - A name dialog comes first, prefilled with the platform's name and selected.
  - The name goes only to `POST /settings/passkeys`, never to `/options`, where the server would make it the WebAuthn `user.displayName` the password manager shows.
  - Then the options are fetched, `allowsCeremony` checks them, the OS sheet runs, and the credential is stored.
  - At 10 (`PasskeyService::MAX_CREDENTIALS_PER_USER`), Add is disabled and `max_limit` shows.
  - `alreadyRegistered` (excludeCredentials matched) shows `passkey_already_registered`.
- **When the card shows.**
  - Not ready, but passkeys exist: the rows show with `passkeys_cannot_add_here`, worded neutrally because during the rollout it often means "not yet".
  - Hidden when not ready with no passkeys, when the list returns 404 / 405, and in demo mode.
- **No outbox.** `PasskeyRepository` calls the server directly, an accepted exception to the outbox rule like `TwoFactorRepository`: the challenge expires in five minutes, with the OS sheet in the middle of it. Removal is a plain `DELETE` through `ApiClient.mutate`.
- **No password prompt.** The management routes need only the session token, so the card asks for no password; React behaves the same way.

## Tests

- `test/data/services/native_passkeys_test.dart` covers the channel protocol per platform against lbuchs's real JSON: what each native half is sent, the WebAuthn JSON built from its reply, Windows' `clientDataJSON`, and every error code.
- `test/data/services/passkey_readiness_test.dart` covers the platform rules, the association-file parsers, caching, `allowsCeremony` and the codec.
- `test/data/services/auth_service_passkey_test.dart` covers the request bodies (no password, the secret, the flattened assertion) and the list's date shapes.
- `test/ui/features/auth/login_view_model_passkey_test.dart` and `test/ui/features/settings/passkeys_view_model_test.dart` cover the view models.
- `test/ui/features/settings/widgets/passkeys_section_test.dart` covers the card.
- `test/lint/universal_links_test.dart` pins the `webcredentials:` entitlements to `kHostedPasskeyRpId`.
