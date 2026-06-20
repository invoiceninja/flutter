# Setup

Companion to CLAUDE.md (no longer carries a § Setup section — this doc is the canonical source).

## Git hooks

Enable the repo's pre-commit hook once per clone:

```sh
git config core.hooksPath .githooks
```

`.githooks/pre-commit` runs `dart format --set-exit-if-changed` on the staged Dart files and blocks the commit if any are unformatted — mirroring CI's "Verify formatting" step so a formatting failure can't reach CI. It's a no-op when `dart` isn't on `PATH`.

## Platform targets

- **Now**: iOS, macOS, **web**, **Linux** (desktop, distributed as a Snap — see § Linux desktop / Snap), **Windows** (desktop runner in `windows/`, binary `InvoiceNinja.exe`, app id `com.invoiceninja.admin`; DPAPI per-user for secure storage).
- **Later**: Android.

When adding back Android, regenerate with `flutter create --platforms=android`. Note: Android needs `<uses-permission android:name="android.permission.INTERNET" />`.

The Windows app icon is generated from the 1024px macOS source (`macos/AppIcon.icon/Assets/Image.png`) into a multi-size `windows/runner/resources/app_icon.ico` — regenerate after a logo change with `dart run tools/gen_windows_icon.dart`. The user-facing name lives in `windows/runner/main.cpp` (window title), `windows/CMakeLists.txt` (`BINARY_NAME`), and `windows/runner/Runner.rc` (version-info strings).

## Linux desktop / Snap

The Linux desktop runner lives in `linux/` (binary `admin`, application id `com.invoiceninja.admin`) and resolves to the same native (`_io`) code path as iOS/macOS — SQLCipher DB + `flutter_secure_storage` key. It's distributed as a Snap on the `edge` channel of the `invoiceninja` snap, published by the manually-triggered `.github/workflows/snapcraft.yml`; a `build-linux` gate in `ci.yaml` compile-checks Linux on every CI run. `snap/snapcraft.yaml` + `snap/gui/` hold the snap metadata, desktop entry, and 512px icon.

- **Build deps** (on a 22.04 host — the snap base is core22): `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev` (plus `execstack` in the deploy). No OpenSSL/jsoncpp — `sqlite3mc` ships a prebuilt self-contained binary and `flutter_secure_storage_linux` needs only libsecret.
- **Keyring under strict confinement (load-bearing).** `flutter_secure_storage` holds the SQLCipher DB key and reaches gnome-keyring via the `password-manager-service` plug, which is **not auto-connected**. After `snap install invoiceninja --edge` users must run `snap connect invoiceninja:password-manager-service` once, or the app can't open its encrypted DB. Must be resolved (a store auto-connect request — Canonical generally declines these — or a libsecret-portal/per-snap-storage backend) before any `stable` release. `grade: devel` in `snapcraft.yaml` blocks accidental stable pushes until then.
- **Build mechanism.** The workflow compiles `flutter build linux --release` on the 22.04 host (matching core22's glibc), clears the executable stack on `libsentry.so`/`crashpad_handler`, then packs + publishes via `snapcore/action-build` + `snapcore/action-publish`. Keep `runs-on: ubuntu-22.04` pinned — a binary built on a newer host links glibc symbols missing from core22 and crashes at launch. When 22.04 is retired, move the Flutter build inside the snap (a core22 build container).
- **Store credentials.** Repo secret `SNAPCRAFT_STORE_CREDENTIALS`, generated with `snapcraft export-login --snaps invoiceninja --acls package_access,package_push,package_update,package_release --expires <date> exported.txt`. Expired credentials silently break publishing — track the date.

## Android release build

The release `.aab` is large (~119 MB) mostly because the Dart AOT `libapp.so` ships **unstripped**: its debug symbols (~120 MB across the three ABIs) land in the bundle's `BUNDLE-METADATA/`. Before "fixing" that, two facts:

- **It doesn't change what users download.** Play strips `BUNDLE-METADATA/` before generating delivery APKs, and per-ABI splitting means a device pulls one ABI's `libapp.so` (~35 MB), not all three — the ~119 MB is the *upload artifact*, not the install size. R8 is not the lever: it's already on (both builds carry a `proguard.map`) and only shrinks the ~4 MB Java/Kotlin dex, never the native libs. The growth that *does* reach users vs. admin-portal is ~13 MB — the encrypted-SQLite native lib (`libsqlite3mc.so`), more compiled Dart, the `assets/i18n/*.json` (moved out of Dart code into assets), and the bundled Inter Tight / JetBrains Mono fonts. Partly offset by tree-shaking the Material Design Icons font, which v1 shipped in full (~1 MB).

- **To shrink the upload artifact**, build with `flutter build appbundle --split-debug-info=build/symbols` (optionally `--obfuscate`): `libapp.so` is stripped and the Dart debug info is written to `build/symbols/` instead of the bundle — roughly 35–45 MB off the `.aab`. **Caveat — this breaks Sentry's Dart symbolication.** Sentry Dart stack traces are currently readable *only because* those symbols are baked into the binary; there is no symbol-upload pipeline (`SentryFlutter.init` is wired in `lib/main.dart`, but no `sentry_dart_plugin` / `sentry.properties` / `sentry-cli`). After splitting you must upload `build/symbols/` to Sentry (`sentry_dart_plugin`, or `sentry-cli debug-files upload`) or Dart frames arrive as raw addresses; `flutter symbolize -d build/symbols/<file>` covers manual symbolication. Native-crash symbolication (libflutter / libsentry / libsqlite3mc) is unaffected.

Unless the upload-artifact size is an actual problem, leaving the build as-is is fine — the symbols cost users nothing and currently double as the de-facto Sentry symbol source.

## Android / Google Play

The signed `.aab` is published to the **Internal testing** track of the existing `com.invoiceninja.admin` Play listing by the manually-triggered `.github/workflows/playstore.yml` (`workflow_dispatch` only — publishing is a deliberate release action, not a per-push gate). It mirrors `snapcraft.yml`: one job, store credentials as a repo secret, `IN_SENTRY_DSN` baked in at compile time. Internal testing is the safe-by-default analogue of the snap's `edge`/`grade: devel` — the service account is granted only **"Release apps to testing tracks"**, so the workflow is structurally incapable of touching production. The build half is the same `flutter build appbundle --release` covered in § Android release build; promote internal → closed → production by hand in the Console.

- **Track & status.** `track: internal`, `status: completed` (released to internal testers automatically — the action default, the closest mirror of snap `edge`). `completed` is accepted because the app already has testing-track releases. (A *brand-new* package still in Play Console "draft" state accepts only `status: draft` and rejects `completed` with *"Only releases with status draft may be created on draft app"* — not our case.) The very first bundle for any new app must be uploaded **manually** in the Console before the API will accept uploads; already satisfied here.
- **Signing.** CI restores the release keystore + `key.properties` from secrets (the same files local release machines have), so the existing `signingConfigs` in `android/app/build.gradle.kts` signs the bundle unchanged. Both `android/key.properties` and `android/app/key.jks` are gitignored, so without this step the release build silently falls back to **debug** signing, which Play rejects on upload. If the app is enrolled in Play App Signing, `key.jks` is the **upload key** (recoverable via Play Console support if lost) and Google re-signs delivered APKs with the app signing key it holds; back up `key.jks` + its passwords off-CI regardless.
- **versionCode must always increase.** Play rejects any upload whose `versionCode` is ≤ the highest already on the track (*"Version code N has already been used"*). It comes from the pubspec build number (`+N`), advanced only by `tools/bump_client_version.sh`. **Run the bump, commit it, then trigger the workflow** — re-running without a bump fails at the upload step.
- **Release notes** are optional for a testing-track upload; omit `whatsNewDirectory` (add `distribution/whatsnew/whatsnew-en-US` later if you want changelog text in the tester UI).
- **Troubleshooting `changesNotSentForReview`.** If a run fails with *"Changes cannot be sent for review automatically. Please set the query parameter changesNotSentForReview to true."*, add `changesNotSentForReview: true` under the publish step. It's account/app-state-dependent — leave it unset by default, since some accounts get the inverse error (*"...must not be set"*) when it *is* set.
- **Repo secrets** (Settings → Secrets and variables → Actions):
  - `PLAY_SERVICE_ACCOUNT_JSON` — full text of the Play Developer API service-account JSON key.
  - `ANDROID_KEYSTORE_BASE64` — `base64 -i android/app/key.jks | pbcopy` (Linux: `base64 -w0`).
  - `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS` — the three values from local `android/key.properties` (alias is currently `key`).
  - Reuses the existing `IN_SENTRY_DSN` secret for symbolicated crash reports.
- **One-time Play setup** (already done for this listing; redo only for a new package): create/select a Google Cloud project → enable the **Google Play Android Developer API** → create a service account → add a JSON key → in Play Console → Users and permissions, invite the service-account email with **app-level** "Release apps to testing tracks" on `com.invoiceninja.admin` (do **not** grant the production permission).

## Dependency updates

Routine bump: raise the `^` floors in `pubspec.yaml`, run `flutter pub upgrade`, regenerate codegen (`dart run build_runner build --delete-conflicting-outputs`), and — only if `drift` or `sqlite3` moved — the vendored web assets (§ Web setup notes). Gate the result with `flutter analyze` + `flutter test` + `flutter build web --wasm`.

**Why `flutter pub outdated` still shows a stale tail.** ~22 transitive packages list a newer **"Latest"** that is *not resolvable*: `flutter pub upgrade --major-versions --dry-run` (the most aggressive solve — it even rewrites our own constraints) reports **"No dependencies would change."** Each is capped by an **already-latest upstream package** (not by our `pubspec.yaml`), so nothing here can move them; they clear only when the upstream widens its bound or Flutter ships a newer stable. Verified 2026-06-02 on Flutter 3.44.1 / Dart 3.12.1:

| Stuck package(s) | Capped by (already the latest version) |
|---|---|
| `analyzer`, `_fe_analyzer_shared`, `dart_style`, `mockito` | `freezed 3.2.5` → `analyzer <11.0.0` |
| `cli_util` | `drift_dev 2.33.0` → `cli_util ^0.4.0` |
| `xml`, `image` (image 4.9 needs xml 7) | `pdf 3.12.0` (via `printing`) → `xml <7.0.0` |
| `qr` | `qr_flutter 4.1.0` + `barcode` → `qr ^3` |
| `in_app_purchase_android` | `in_app_purchase 3.2.3` → `^0.4.0` (no Android target anyway) |
| `meta`, `vector_math`, `test`, `test_api`, `test_core`, `matcher` | Flutter SDK exact pins (`flutter` / `flutter_test`) — needs a Flutter bump |
| `flutter_secure_storage_darwin`, `jni`, `path_provider_android` | federated plugin parents (`flutter_secure_storage`; `sentry_flutter` pins `jni 0.14.2`; `path_provider`) |
| `dart_quill_delta`, `flutter_test_robots`, `flutter_test_runners` | the `super_editor` git pin in `pubspec.yaml` |

Don't force these with `dependency_overrides` — `analyzer ≥11` breaks `freezed`, `xml 7` breaks `pdf`, and the SDK pins break the framework. Re-run `flutter pub upgrade --major-versions --dry-run` after any future `freezed` / `pdf` / `qr_flutter` / Flutter bump to see what has since opened up.

## Web setup notes

See CLAUDE.md § Web for the runtime model (unencrypted IndexedDB via drift WASM, localStorage tokens, hash URLs, OAuth/biometric disabled, the `Idempotency-Key` CORS backend dependency in `BACKEND.md`). Operational notes for this repo:

- **Vendored assets** live in `web/` and are committed: `web/sqlite3.wasm` and `web/drift_worker.js`. They are **not** generated by `flutter build web` — regenerate them by hand whenever `drift` or `sqlite3` is bumped in `pubspec.lock`:
  - `web/sqlite3.wasm`: download the `sqlite3.wasm` asset for the **resolved `sqlite3` Dart package version** from <https://github.com/simolus3/sqlite3.dart/releases> (tag `sqlite3-<version>`). Use the plain build, not `sqlite3mc` — web is unencrypted. Current: matched to `sqlite3` 3.3.2.
  - `web/drift_worker.js`: `dart compile js -O4 -o web/drift_worker.js web/drift_worker.dart` (the `.dart` source is committed; the `.js` output is what's served). Delete the stray `.js.deps`/`.js.map` afterward.
- **Serving**: any static host. The host must serve `.wasm` as `Content-Type: application/wasm`. Hash routing means no rewrite-to-index config is required.
- **Run / build**: `flutter run -d chrome`, `flutter build web --release`. `flutter build web` is the authoritative web compile gate (catches platform-API regressions; `flutter analyze` runs against the VM target and won't). CI builds with `--wasm`, so it also gates WebAssembly compatibility (dart2wasm rejects `dart:html`).

### Demo web build

`tools/build_demo_web.sh` produces the public pre-authenticated demo hosted at <https://hillelcoren.github.io/admin/>:

- Builds `flutter build web --wasm --release --no-web-resources-cdn --base-href /admin/ --dart-define=IN_DEMO_API_TOKEN=TOKEN`. `--base-href /admin/` matches the GitHub Pages subdirectory; `--no-web-resources-cdn` bundles the CanvasKit/skwasm engine into `build/web/` (served from `/admin/`) instead of fetching it from `www.gstatic.com` at runtime, so the demo loads from our own origin; the `IN_DEMO_API_TOKEN` define makes the app boot straight to the dashboard, pre-authenticated against `demo.invoiceninja.com` with the public system token `TOKEN` (see `docs/probing-the-demo-api.md`). The bootstrap path is `Env.demoApiToken` → `AuthRepository.loginWithToken` in `lib/main.dart`; it is inert in any build without the define.
- **Cache-busts the app entrypoints** so a single browser refresh picks up a redeploy. GitHub Pages serves every file with `Cache-Control: max-age=600` and offers no way to set custom headers, and Flutter's entry files have fixed names — so without this a fresh deploy stays hidden behind the browser cache for up to ~10 min. The script appends a content-hash token (`?v=<sha256-12 of main.dart.{wasm,mjs,js}>`) to `flutter_bootstrap.js` (in `index.html`) and to `main.dart.{wasm,mjs,js}` (in `flutter_bootstrap.js`'s `buildConfig`). A new build → new token → brand-new URLs no cache can satisfy, so one refresh (which revalidates the fixed-URL `index.html` via the Pages ETag) loads the new bootstrap + app code. Two `grep` guards fail the build if a future Flutter output change breaks the rewrite. The `canvaskit/` engine files are intentionally **not** busted — they're immutable per Flutter SDK, so re-stamping them every deploy would force a needless multi-MB re-download (only a Flutter SDK bump changes them; a one-time hard refresh covers that rare case).
- Rsyncs `build/web/` into the deploy directory — defaults to the sibling checkout `../hillelcoren.github.io/admin`; pass a path as the first arg, or `-` to build only.
- The deploy repo **must** keep an empty `.nojekyll` at its root. GitHub Pages otherwise runs Jekyll, which strips `assets/i18n/_app_pending.json` (the leading `_`), and every not-yet-translated string renders as its raw key. The script warns if `.nojekyll` is missing.
- Publishing is manual: commit & push the deploy repo after running the script.

## macOS setup notes

The sandboxed macOS build needs four entitlements (see `macos/Runner/{DebugProfile,Release}.entitlements`):

- `com.apple.security.app-sandbox` — on by default.
- `com.apple.security.network.client` — outbound HTTP. Added in M1.1.
- `keychain-access-groups` — required by `flutter_secure_storage`. Value: `$(AppIdentifierPrefix)com.invoiceninja.admin`. Without it, the first `auth.login` throws `PlatformException -34018 (errSecMissingEntitlement)`.
- `com.apple.security.files.user-selected.read-write` — required by `image_picker` + `file_picker` (Company Details: Logo, Documents tabs). Without it the sandbox blocks the open panels and the plugins log `NSCocoaErrorDomain` errors.

Any new package that touches Keychain (OAuth, biometric login, etc.) is already covered by the keychain entitlement — don't add another. If we ever change the bundle id from `com.invoiceninja.admin`, update the `keychain-access-groups` entries to match.

## Dev-machine login pre-fill

To avoid retyping credentials on every fresh launch:

1. Copy `dev.json.example` → `dev.json` (gitignored) and fill in `IN_DEV_EMAIL` / `IN_DEV_PASSWORD`.
2. Run with `flutter run --dart-define-from-file=dev.json`.

The pre-fill happens in `LoginViewModel`'s constructor and is guarded by `!kReleaseMode`, so debug *and* profile builds prefill (handy for perf testing) while release builds tree-shake the branch — credentials cannot leak into a shipped binary even if you accidentally pass the file at build. Keys are `String.fromEnvironment` reads in `lib/app/env.dart` (`Env.devEmail`, `Env.devPassword`).

## Release builds with Sentry

Sentry crash/error reporting is already wired in the app — `sentry_flutter` in `pubspec.yaml`, `Env.sentryDsn` (`String.fromEnvironment('IN_SENTRY_DSN')` in `lib/app/env.dart`), and the init in `lib/main.dart`, which activates Sentry only when `!kIsWeb && !kDebugMode && Env.sentryDsn.isNotEmpty` (sends are further gated by the per-account `report_errors` opt-in via `sentryShouldSend`). The DSN is a **compile-time** value: it must be passed with `--dart-define=IN_SENTRY_DSN=…` at build time and cannot be injected into a prebuilt bundle.

To make local release builds easy, put your DSN in `dev.json` (gitignored — see `dev.json.example`):

```json
{ "IN_DEV_EMAIL": "…", "IN_DEV_PASSWORD": "…", "IN_SENTRY_DSN": "https://…@…ingest.sentry.io/…" }
```

Then build with `tools/build_release.sh`:

```sh
tools/build_release.sh                  # interactive platform picker
tools/build_release.sh macos
tools/build_release.sh appbundle --codegen
tools/build_release.sh ios -- --no-codesign
IN_SENTRY_DSN=https://…  tools/build_release.sh macos   # env var overrides dev.json
```

- Targets: `macos | ios | appbundle | linux | web` (Android is **appbundle only**). `ios` builds the `ipa` (distributable, needs signing); `web` builds with `--wasm` but Sentry is excluded on web by the `!kIsWeb` gate, so the DSN is ignored there; `linux` only compiles on a Linux host (no cross-compile from macOS — CI handles it, below).
- DSN resolution: `IN_SENTRY_DSN` env var → else the `IN_SENTRY_DSN` key in `dev.json` → else empty (Sentry stays disabled, with a warning — a safe no-op). The script reads **only** that key, never `IN_DEV_EMAIL`/`IN_DEV_PASSWORD`, so dev credentials never land in the release binary.
- `--codegen` runs `dart run build_runner build --delete-conflicting-outputs` first (off by default — assumes generated files are current).
- Adding the key to `dev.json` also means the **"Flutter (profile, dev creds)"** launch config (profile mode → `!kDebugMode`) exercises Sentry locally — a free way to test the wiring. The debug "Flutter (dev creds)" config still won't init Sentry (the `!kDebugMode` gate).

**CI / Linux snap.** The published artifact (the Linux snap, the only CI publish pipeline) is handled separately by `.github/workflows/snapcraft.yml`, which injects the DSN from the `IN_SENTRY_DSN` GitHub Actions secret (`--dart-define=IN_SENTRY_DSN=${{ secrets.IN_SENTRY_DSN }}`). `tools/build_release.sh` is for **local** macOS/iOS/Android/web release builds. (Note: there is no Dart-symbol upload pipeline — Sentry symbolication relies on symbols baked into the binary; see § Android release build before adding `--split-debug-info`.)
