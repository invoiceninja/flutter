# Deploy to Web

Companion to CLAUDE.md § Web. How the new app replaces admin-portal's web build on the Invoice Ninja server: the **Deploy to Web** workflow (`.github/workflows/web.yml`), the boot page it stages, what is decided where, and what is left before it goes live. Platform differences of the web build itself are in `docs/web-platform-differences.md`.

## Deploy to Web stages the build in public/flutter/ and, for now, never commits

Today `build_client` (an alias in Hillel's shell) merges admin-portal `develop` into `master`. The push runs admin-portal's **Build Web**, which builds the old app three times (hosted `main.dart.js`, `main.profile.dart.js`, FOSS `main.foss.dart.js`) and pushes three commits to `invoiceninja/invoiceninja@v5-develop:public/`. The server's `/` route (`BaseController::flutterRoute`) renders `index.index`, which loads one of those files with a plain `<script>` tag. On self-hosted installs with `set_react_as_default_ap` set, the default, `/` shows React instead, and that switch is untouched by any of this.

Deploy to Web replaces that. It builds this app once and stages it into a throwaway, anonymous, sparse clone of the backend:

- `public/flutter/`: the build, minus `index.html` (the server renders its own page), `flutter_service_worker.js`, `drift_worker.dart`, `.last_build_id` and the engine's `*.symbols`.
- `resources/views/flutter/index.blade.php`: the boot page, rendered from `tools/web_deploy/index.blade.php`.

**Test mode is the only mode.** The workflow has no token and no push step; it reports what a commit would change. The job summary leads with "TEST MODE: nothing committed or pushed". The commit arrives with § Going live.

Steps, in order:

1. `tools/prepare_foss.sh --web` (§ One FOSS build serves hosted and self-hosted).
2. `flutter build web --wasm --release --no-web-resources-cdn --pwa-strategy=none`. `--pwa-strategy=none` makes the bootstrap call `_flutter.loader.load()` with no service-worker settings; the option is hidden and deprecated in 3.47, and when it goes, a custom `web/flutter_bootstrap.js` (`{{flutter_js}}`, `{{flutter_build_config}}`, `_flutter.loader.load();`) does the same.
3. `tools/stamp_web_cache_bust.sh`: a content hash as `?v=` on the `main.dart.{wasm,mjs,js}` entries in `flutter_bootstrap.js`. Shared with `tools/build_demo_web.sh`.
4. The build's `manifest.json` gets `start_url` and `scope` of `"../"`, so an installed app opens the boot page at the site root, not the folder (which has no index and answers 403). Its `id` resolves to `/`, the old app's, so existing installs update in place. `web/manifest.json` is not touched: the GitHub Pages demo uses it.
5. `build.json` (`version`, `sha`, `run_url`, `built_at`) identifies the build a server serves: `curl https://<server>/flutter/build.json`.
6. Gates: only the two folders may change, the backend's `.gitignore` may drop nothing, every staged file must be tracked; every staged file and every URL the page, bootstrap, manifest and font manifest name must be served with 200 and the right type (`tools/web_deploy/check_served_files.py`); and the app must paint its first frame in headless Chrome, once as WASM and once forced to dart2js (`tools/web_deploy/smoke_webdriver.sh`).
7. Artifact `web-staged` (7 days): the served site, a `standalone.html` without `data-served` (so a local copy keeps the usual server field and can sign in to the demo server), and `serve.py`. Use `python3 serve.py .`: plain `python3 -m http.server` on an older Python serves `.mjs` as octet-stream, and the WASM boot then fails with no fallback.

Sizes, measured on 5.1.24: about 92 MB staged (canvaskit 36 MB less its symbols, assets 24 MB of which 19 MB is translations, `main.dart.js` 25 MB, `main.dart.wasm` 15 MB). Each deploy changes about 40 MB of git blobs in the backend; `build_client` changes about 80 MB today.

## One FOSS build serves hosted and self-hosted

admin-portal built a separate `main.foss.dart.js` so self-hosted servers shipped no store SDKs. Here nothing in `packages/store_services` runs on web: Sentry, Google and Apple sign-in, in-app purchase, the review prompt and Stripe Terminal are all `!kIsWeb`-gated, and the review prompt and release notes decide on `isWeb` before `isStoreBuild`. So one build on the FOSS graph behaves exactly like the store graph on web and keeps self-hosted free of store SDKs. `prepare_foss.sh --web` runs only the twin swap and the FOSS-lock check; the sqlite3mc source and the ML Kit plugin are native-only (docs/fdroid.md).

## The boot page is one template, and its glue matches web/index.html

`tools/web_deploy/index.blade.php` is the only copy. `tools/web_deploy/render_boot_page.py` renders it two ways: `--blade` fills in only the bootstrap hash (the view the backend serves) and `--static` substitutes everything (the smoke page and the artifact), failing if any Blade is left.

- **Every variable is optional** (`{{ $x ?? default }}`): `$base_href` (default `/flutter/`), `$is_hosted`, `$signup`, `$rc`, `$white_label`. A controller that passes fewer of them can never 500 `/`. GTM sits in `@if ($is_hosted ?? false)`.
- **`<base href>` comes first**, and everything else is relative to it: the manifest, icons, `flutter_bootstrap.js`, and through `document.baseURI` the engine, `canvaskit/`, `assets/`, `sqlite3.wasm`, `drift_worker.js` and `pdfjs/`. Hash routing reads `location.pathname`, so a page at `/` with a base of `/flutter/` routes correctly.
- **`data-served="1"` and `data-hosted`** tell the app it is served by an Invoice Ninja server. The old page's `data-signup`, `data-rc` and `data-white-label` are kept.
- **Left out of the old page on purpose:** `js/pdf.min.js` and `pdfjsLib.GlobalWorkerOptions` (printing would use that pdf.js instead of the pinned `pdfjs/`), `canvasKitBaseUrl` and the root `manifest.json` (the old engine and the old app), the MSAL and Apple scripts (this app has no web OAuth), and og/twitter tags.
- **The loader, `dartPdfJsBaseUrl` and the first-frame / 30-second Reload script** are marked `<!-- glue:start … -->` in both this template and `web/index.html`, and `test/lint/web_boot_page_glue_test.dart` keeps them identical. The first-frame handler sets `window.__flutterFirstFrame`, which the boot smoke waits for.

## The old app's service worker is dropped before the new app boots

The old page registered `flutter_service_worker.js?v=<server version>` at the site root. Today's copy is Flutter's self-unregistering stub, but on activation it navigates the page, and a reload mid-boot can wedge the web database (`lib/data/db/database_opener_web.dart`). So the boot page checks synchronously: if the page's controller is a worker whose script **path** ends in `/flutter_service_worker.js` (its URL carries `?v=`, so a plain suffix test misses it), it unregisters the registrations scoped to the site root (`new URL('../', document.baseURI)`, which is right on a sub-path too) and reloads once, guarded in `sessionStorage`; only otherwise does it inject the bootstrap. Keep `public/flutter_service_worker.js` in the backend: a visit to the legacy app re-registers it, and the stub is what makes that harmless.

## Going live

None of this is built yet; each item needs Hillel's go-ahead.

**Gates before the server boots it by default:**

- **OAuth-only accounts.** Web is email and password only; the old web app offered Google, Apple and Microsoft (Microsoft on self-hosted too). Count the affected users, then reach parity or add static login-card copy ("Signed up with Google, Microsoft or Apple? Use Forgot password."). Not a precheck hint: the precheck omits OAuth on purpose, against account enumeration.
- **Old bookmarks.** v1's routes are singular (`/invoice`, `/invoice/view`) and carry no id. Add a `legacyV1Redirect` beside `legacyIntegrationsRedirect` in `lib/app/router.dart`.
- **Error reporting.** Sentry is off on web; at least send a GTM event when the 30-second card shows.
- **MIME and compression.** `curl -sI` a staging server for `main.dart.mjs`, `main.dart.wasm`, `pdfjs/pdf.worker.min.mjs` and `sqlite3.wasm`. nginx (invoiceninja/dockerfiles) needs `mjs` and `wasm` types and gzip for them; say so in the self-hosted upgrade notes. A wrong type on `.mjs` is a blank page.
- **How a `v5-develop` commit reaches hosted.** Self-hosted installs get whatever `v5-develop` holds when the release tarball is built (`react_release.yml`); hosted's deploy path is to confirm.

**The backend PR** (only the `index.index` branch changes; the React switch stays):

- `flutterRoute` renders `flutter.index` with the template's variables, `$base_href` from the path of `config('ninja.app_url')` (as the old `$canvas_path`) plus `/flutter/`, and falls back to `index.index` when `public/flutter/flutter_bootstrap.js` is missing. A `FLUTTER_WEB_DEFAULT=v2|legacy` flag, read through `config()`, is the global rollback.
- `setBuild()`: explicit `legacy` (hosted `main.dart.js`, self-hosted `main.foss.dart.js`) and `v2`; `?build=` sets or clears a cookie **before** the `?login` / `?signup` redirects, which drop the query; the `wasm` / `last` / `next` cases go with their files.
- `?clear_local` moves into the template's JS, before boot: delete every generation's IndexedDB database, OPFS, and the app's `localStorage` keys. Clearing `localStorage` alone resets the database generation and can reopen an abandoned store.
- `public/.htaccess`: `AddType` for `wasm` and `mjs` (in `<IfModule mod_mime.c>`), `DEFLATE` for wasm, js and json, and no-cache for `/flutter/` (`<If "%{REQUEST_URI} =~ m#/flutter/#">` in `<IfModule mod_headers.c>`), because the engine files are not versioned.

**Commit mode:** a write deploy key on `invoiceninja/invoiceninja` (no expiry, unlike a fine-grained token); commits as hillelcoren@gmail.com titled `Admin Portal v2 - <version> [skip ci]` (each push otherwise runs the backend's 32 phpunit jobs); rebase and retry on a moved branch, tested on the shallow sparse clone first; `mode` gains `commit`.

**Wiring:** a `web:` leg in `deploy-all.yml` (`needs: release`, `secrets: inherit`, `with: skip_tests: true` and `mode: commit`), `web.yml` in `deploy_all_workflow_test.dart`'s store list, and the "five stores" wording in `deploy-all.yml`, that test, `docs/store-deployment-setup.md` and `.claude/skills/release/SKILL.md`.

**Cleanup:** retire `build_client` and admin-portal's Build Web; delete the stale `main.{html,last,next,wasm,foss.wasm}.dart.js` and `main.foss.dart.js.map` from the backend (about 55 MB; self-update never deletes files, so existing installs keep them).

**What users will notice:** old web users sign in once (admin-portal's token, `flutter.checksum` in `localStorage`, is not imported, on purpose, so the Welcome still shows); What's New stays silent on that first load; passkeys aren't offered at invoicing.co, because their relying party is `app.invoicing.co`.
