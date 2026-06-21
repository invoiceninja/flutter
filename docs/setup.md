# Setup

Companion to CLAUDE.md (no longer carries a § Setup section — this doc is the canonical source).

## Git hooks

Enable the repo's pre-commit hook once per clone:

```sh
git config core.hooksPath .githooks
```

`.githooks/pre-commit` runs `dart format --set-exit-if-changed` on the staged Dart files and blocks the commit if any are unformatted — mirroring CI's "Verify formatting" step so a formatting failure can't reach CI. It's a no-op when `dart` isn't on `PATH`.

## Platform targets

All six targets are supported and shipped: iOS, **Android** (runner in `android/`, applicationId `com.invoiceninja.admin`, release signing via the gitignored `android/key.properties` + `android/app/key.jks`; Android Keystore for secure storage), macOS, **web**, **Linux** (desktop, distributed as a Snap — see § Linux desktop / Snap), **Windows** (desktop runner in `windows/`, binary `InvoiceNinja.exe`, app id `com.invoiceninja.admin`; DPAPI per-user for secure storage).

Each platform ships via its own per-store workflow — see § Shipping to the stores.

The Windows app icon is generated from the 1024px macOS source (`macos/AppIcon.icon/Assets/Image.png`) into a multi-size `windows/runner/resources/app_icon.ico` — regenerate after a logo change with `dart run tools/gen_windows_icon.dart`. The user-facing name lives in `windows/runner/main.cpp` (window title), `windows/CMakeLists.txt` (`BINARY_NAME`), and `windows/runner/Runner.rc` (version-info strings).

## Shipping to the stores

Five manually-triggered workflows publish the app, one per store — all `workflow_dispatch` only (a release is a deliberate act, never a per-push gate). **To run one:** GitHub → **Actions** → pick the workflow → **Run workflow** (on the default branch). Each builds the platform artifact, bakes in `IN_SENTRY_DSN`, and uploads to a non-production / testing channel — except Windows, which auto-commits to Store certification (see that section).

| Store | Workflow | Channel (non-prod) | Details |
|---|---|---|---|
| Linux Snap | `snapcraft.yml` | `edge` | § Linux desktop / Snap |
| Android | `playstore.yml` | Play `internal` | § Android / Google Play |
| iOS | `appstore-ios.yml` | TestFlight | § iOS / macOS — App Store & TestFlight |
| macOS | `appstore-macos.yml` | TestFlight | § iOS / macOS — App Store & TestFlight |
| Windows | `microsoft-store.yml` | restricted listing (auto-certifies) | § Windows / Microsoft Store |

**Finishing setup (one-time, per workflow).** The store accounts and listings already exist, but these workflows are new, so **their GitHub secrets are not configured yet** — before a workflow's first dispatch, add the secrets listed in its section (Settings → Secrets and variables → Actions) and do its one-time external setup. `IN_SENTRY_DSN` already exists and is reused by all of them. The two Apple `ExportOptions.plist` files (+ the macOS `PROVISIONING_PROFILE_SPECIFIER`) are pre-filled with the expected profile names (`Invoice Ninja Admin App Store`, `Invoice Ninja macOS App Store`) — edit them only if the real portal profile names differ.

**Per release.** Run `tools/bump_client_version.sh`, commit, then dispatch. The build number must **strictly increase** for Play / iOS / macOS / Windows (each rejects a re-used version). **Snap is the exception** — it's revision-ordered, so no bump is needed to publish; its display version is maintained separately in `snap/snapcraft.yaml` (`version:`, currently `5.1.1`).

## Linux desktop / Snap

The Linux desktop runner lives in `linux/` (binary `admin`, application id `com.invoiceninja.admin`) and resolves to the same native (`_io`) code path as iOS/macOS — SQLCipher DB + `flutter_secure_storage` key. It's distributed as a Snap on the `edge` channel of the `invoiceninja` snap, published by the manually-triggered `.github/workflows/snapcraft.yml`; a `build-linux` gate in `ci.yaml` compile-checks Linux on every CI run. `snap/snapcraft.yaml` + `snap/gui/` hold the snap metadata, desktop entry, and 512px icon.

- **Build deps** (on a 22.04 host — the snap base is core22): `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev` (plus `execstack` in the deploy). No OpenSSL/jsoncpp — `sqlite3mc` ships a prebuilt self-contained binary and `flutter_secure_storage_linux` needs only libsecret.
- **Keyring under strict confinement (load-bearing).** `flutter_secure_storage` holds the SQLCipher DB key and reaches gnome-keyring via the `password-manager-service` plug, which is **not auto-connected**. After `snap install invoiceninja --edge` users must run `snap connect invoiceninja:password-manager-service` once, or the app can't open its encrypted DB. Must be resolved (a store auto-connect request — Canonical generally declines these — or a libsecret-portal/per-snap-storage backend) before any `stable` release. `grade: devel` in `snapcraft.yaml` blocks accidental stable pushes until then.
- **Build mechanism.** The workflow compiles `flutter build linux --release` on the 22.04 host (matching core22's glibc), clears the executable stack on `libsentry.so`/`crashpad_handler`, then packs + publishes via `snapcore/action-build` + `snapcore/action-publish`. Keep `runs-on: ubuntu-22.04` pinned — a binary built on a newer host links glibc symbols missing from core22 and crashes at launch. When 22.04 is retired, move the Flutter build inside the snap (a core22 build container).
- **Store credentials.** Repo secret `SNAPCRAFT_STORE_CREDENTIALS`: on a machine logged into the Snap Store (`snapcraft login`), run `snapcraft export-login --snaps invoiceninja --acls package_access,package_push,package_update,package_release --expires <date> exported.txt`, then paste the **full contents** of `exported.txt` into the secret. Expired credentials silently break publishing — track the date.

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

## iOS / macOS — App Store & TestFlight

Both Apple targets are published to **TestFlight** by two manually-triggered workflows — `.github/workflows/appstore-ios.yml` and `appstore-macos.yml` (`workflow_dispatch` only; publishing is a deliberate release action, not a per-push gate). TestFlight is the Apple analogue of the snap's `edge` / Play's `internal`: builds reach internal/external testers (the shared join link `testflight.apple.com/join/YY1BZ7uR`, used for both iOS and macOS), never straight to the store. **Uploading to TestFlight does not submit the build for App Store review** — promotion to the store is a separate, manual App Store Connect action. Both jobs run on `macos-26` + Xcode 26.4.1 (matching the CI `apple` gate), pin Flutter 3.44.1, and bake `IN_SENTRY_DSN` in at compile time like every other publish pipeline.

**macOS is a Mac App Store build, not Developer ID.** The app is sandboxed (`macos/Runner/Release.entitlements`: app-sandbox, network.client, files, print, keychain-access-groups, applesignin), so its channel is the Mac App Store / TestFlight, not a notarized direct download. `flutter build macos` only produces a `.app` — there is no `flutter build` MAS equivalent to `flutter build ipa` — so the macOS workflow drives `xcodebuild` directly: `flutter build macos --release --config-only --dart-define=IN_SENTRY_DSN=…` (writes the dart-define into the generated xcconfig the build reads) → `xcodebuild archive` (signed) → `xcodebuild -exportArchive -exportOptionsPlist macos/ExportOptions.plist` with `method: app-store` (emits a signed `.pkg`) → `xcrun altool --upload-app --type macos`. This is the same `--config-only` then explicit-`xcodebuild` seam the unsigned `apple` gate in `ci.yaml` uses, but with real distribution signing instead of the `CODE_SIGN_IDENTITY="-"` overrides.

- **The Mac App Store needs TWO certificates.** A MAS `.pkg` is signed twice: the **app-signing** distribution cert ("Apple Distribution" / "3rd Party Mac Developer Application") signs the `.app` inside; the **installer-signing** cert ("Mac Installer Distribution" / "3rd Party Mac Developer Installer") signs the `.pkg` wrapper. Both identities are imported from **one combined `.p12`** in a single `apple-actions/import-codesign-certs@v7` step and are named in `macos/ExportOptions.plist` (`signingCertificate` + `installerSigningCertificate`). One combined import is deliberate: two separate import steps into the default `signing_temp` keychain break, because each auto-generates its own random keychain password and the second's `set-key-partition-list` then fails against the first's keychain (`apple-actions/import-codesign-certs#14`). Omitting the installer cert produces a package App Store Connect rejects. iOS needs only the one "Apple Distribution" app cert — an `.ipa` isn't an installer package.
- **Signing is injected, the Xcode projects are untouched.** Both tracked projects use **Automatic** signing with an "Apple Development" identity (right for local dev). CI injects the distribution certs (`.p12`), the App Store provisioning profiles (`.mobileprovision` / `.provisionprofile`), and the App Store Connect API key (`.p8`) from base64 secrets, decoded at job start and wiped with `if: always()`. **Both** jobs do `flutter build {ios,macos} --release --config-only` (writes the `IN_SENTRY_DSN` dart-define only) then drive an explicit `xcodebuild archive` with manual signing forced on the command line (`CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Distribution" PROVISIONING_PROFILE_SPECIFIER="<profile name>" DEVELOPMENT_TEAM=NPC44Y2C98`), then `xcodebuild -exportArchive` re-signs via a committed secret-free `ExportOptions.plist` (`signingStyle: manual`, `method: app-store`). `flutter build ipa` is **not** used: it archives under the project's Automatic signing, which fails on a headless runner with no Apple-account session. Neither `project.pbxproj` is edited, so local dev keeps working. The `ExportOptions.plist` files reference profiles **by name** — set the two placeholders (`Invoice Ninja Admin App Store`, `Invoice Ninja macOS App Store`) to the real portal names when the profiles are created.
- **CFBundleVersion must always increase.** App Store Connect rejects any upload whose build number (`CFBundleVersion`, from the pubspec `+N`) is ≤ a build already on the app record — for **both** iOS and macOS, which share the version string `5.1.3+6`. It's advanced only by `tools/bump_client_version.sh`. **Run the bump, commit it, then trigger the workflow** — re-dispatching without a bump fails at the upload step ("the bundle version must be higher than the previously uploaded version").
- **Export compliance is already declared.** `ios/Runner/Info.plist` and `macos/Runner/Info.plist` both set `ITSAppUsesNonExemptEncryption=false`, so neither target hits the TestFlight encryption-compliance prompt. No app-side change is needed; the app uses only exempt OS-provided TLS.
- **Why `altool` for the macOS `.pkg`.** iOS uploads via `apple-actions/upload-testflight-build@v5` (which retries on transient ASC failures); the macOS `.pkg` uploads via first-party `xcrun altool --upload-app -f X.pkg --type macos --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>` (altool reads the key from `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`), because the action's macOS `.pkg` path is unreliable across versions.
- **Repo secrets** (Settings → Secrets and variables → Actions):
  - `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_PRIVATE_KEY` — the App Store Connect API key (issuer UUID, key ID, and the **raw** `.p8` text — `cat AuthKey_<id>.p8 | pbcopy`, **not** base64). Shared by both jobs.
  - `APPLE_DISTRIBUTION_CERT_P12_BASE64` + `APPLE_DISTRIBUTION_CERT_PASSWORD` — the iOS app-signing cert (`base64 -i dist.p12 | pbcopy`).
  - `IOS_APPSTORE_PROVISIONING_PROFILE_BASE64` — the iOS App Store profile for `com.invoiceninja.admin` (must include Sign in with Apple).
  - `MAC_DISTRIBUTION_CERTS_P12_BASE64` + `MAC_DISTRIBUTION_CERTS_PASSWORD` — **one combined `.p12`** holding **both** macOS distribution identities (app-signing "Apple Distribution" + installer-signing "Mac Installer Distribution"). In Keychain Access select both, Export 2 items → one `.p12`, then `base64 -i certs.p12 | pbcopy`.
  - `MACOS_APPSTORE_PROVISIONING_PROFILE_BASE64` — the Mac App Store profile (`base64 -i x.provisionprofile | pbcopy`), distinct from the iOS one.
  - Reuses the existing `IN_SENTRY_DSN` secret for symbolicated crash reports.
- **One-time Apple setup** (redo only for a new bundle id / account): (1) **ASC API key** — Users and Access → Integrations → App Store Connect API → generate a key (App Manager role), download the `.p8` once (non-recoverable), record the Key ID + Issuer ID. (2) **Certificates** — create an **Apple Distribution** cert (app signing; used by iOS and the macOS app) and a **Mac Installer Distribution** cert (macOS `.pkg` signing). Export the iOS one as its own password-protected `.p12` (→ `APPLE_DISTRIBUTION_CERT_*`); for macOS, select **both** identities in Keychain Access and export them into **one combined** `.p12` (→ `MAC_DISTRIBUTION_CERTS_*`). (3) **Provisioning profiles** — create an **iOS App Store** and a **Mac App Store** profile for `com.invoiceninja.admin`. The App ID must have **Sign in with Apple** enabled for **both** (the macOS App ID also needs **App Sandbox** + **Keychain Sharing**), matching `Runner.entitlements` / `Release.entitlements` — a profile missing a declared capability fails the archive. Put each profile's **name** into the `ExportOptions.plist` files + the macOS `PROVISIONING_PROFILE_SPECIFIER`. (4) **App records** — confirm the iOS and macOS apps exist on App Store Connect; unlike Google Play, ASC accepts the **first** build via API/altool with no prior manual upload, as long as the record exists.

## Windows / Microsoft Store

The unsigned `.msix` is submitted to the existing `InvoiceNinja.AdminPortal` Microsoft Store listing by the manually-triggered `.github/workflows/microsoft-store.yml` (`workflow_dispatch` only — publishing is a deliberate release action, not a per-push gate). It mirrors `playstore.yml`: one job on `windows-latest`, store credentials as repo secrets, `IN_SENTRY_DSN` baked in at compile time. The Microsoft Store has **no instant testers-only channel** like the snap's `edge`, Play's `internal`, or TestFlight, so the workflow **auto-submits (commits)** the submission: a dispatch uploads the package and commits it, so it enters Store **certification** automatically and goes live on the (restricted/beta) listing once certified — there is no manual gate. To add a safety gate later, append `--noCommit` to the publish step (keeps the submission a draft you click Publish on in Partner Center) or target a closed-beta **package flight** with `-f <flightId>`.

**Build then package — no second rebuild.** `dart run msix:create` defaults to running `flutter build windows` itself, *without* dart-defines, which would overwrite the DSN-baked binary. The workflow therefore builds explicitly — `flutter build windows --release --dart-define=IN_SENTRY_DSN=…` (bakes the DSN into `InvoiceNinja.exe` at compile time; a safe no-op when the secret is empty) — then packages with `dart run msix:create --build-windows false --store`, where `--build-windows false` tells the `msix` tool to package the *existing* `build/windows/x64/runner/Release` output rather than rebuild. `--store` emits an **unsigned** package the Store re-signs on ingestion (matching `store: true` in the pubspec `msix_config` block — no `.pfx` in CI).

- **Publish mechanism.** `microsoft/microsoft-store-apppublisher@v1.3` installs the **Microsoft Store Developer CLI** (`msstore`) onto the runner; `msstore reconfigure` authenticates with a Partner-Center-linked Microsoft Entra app registration; `msstore publish -i <msix> --appId <ProductId>` uploads and commits the submission. This is Microsoft's current, documented CI path — the legacy `microsoft/store-submission` action and Dev Center submission API are superseded, and `dart run msix:publish` makes a sideload `.appinstaller`, not a Store submission. (Microsoft's docs note GitHub-Actions app updates are supported for **free products only** — Invoice Ninja is free, so this is satisfied.)
- **`--appId` is the Product ID, not the Store ID.** The CLI wants the ~12-character **Product ID** from the app's Partner Center overview page (secret `MS_STORE_PRODUCT_ID`), **not** the `9NG93WNXN797` Store ID in the `apps.microsoft.com/detail/...` URL — they are different identifiers and the Store ID fails. `msstore apps list` prints the correct Product IDs.
- **Identity must match Partner Center.** `identity_name` (`InvoiceNinja.AdminPortal`), `publisher` (`CN=2B7AA393-06A0-46F5-AF85-1917142440C3`), and `publisher_display_name` in the pubspec `msix_config` block must exactly match Partner Center → Product identity, or upload validation rejects the package.
- **MSIX version must always increase.** The package version auto-derives from the pubspec `version:` (`5.1.3+6` → `5.1.3.0`, format `x.y.z.0`), and each Store submission must use a strictly higher version. It's advanced only by `tools/bump_client_version.sh`. **Run the bump, commit it, then trigger the workflow** — re-dispatching without a bump produces a duplicate version the Store rejects. Certification then runs (typically hours) before the build is live; there is no instant promotion.
- **Repo secrets** (Settings → Secrets and variables → Actions):
  - `PARTNER_CENTER_TENANT_ID`, `PARTNER_CENTER_SELLER_ID`, `PARTNER_CENTER_CLIENT_ID`, `PARTNER_CENTER_CLIENT_SECRET` — the Microsoft Entra app registration (Manager role in Partner Center) used by `msstore reconfigure`. The Seller ID is **not** the `9N…` Store ID.
  - `MS_STORE_PRODUCT_ID` — the Partner Center Product ID (not the `9N…` Store ID).
  - Reuses the existing `IN_SENTRY_DSN` secret for symbolicated crash reports.
- **One-time Microsoft setup** (the already-live listing satisfies the "app must exist" rule, like Google Play): associate a Microsoft Entra tenant with Partner Center → register an Entra app → create a client secret → add the app under Partner Center → User management → Microsoft Entra applications with the **Manager** role → record Tenant/Client/Seller IDs + the app's Product ID → add the secrets. Optionally create a customer group + package flight and switch the publish step to `-f <flightId>`.

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
