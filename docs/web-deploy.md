# Deploy to Web

Companion to CLAUDE.md § Web. How the new app replaces admin-portal's web build on the Invoice Ninja server: the **Deploy to Web** workflow (`.github/workflows/web.yml`), the boot page it stages, what is decided where, and what is left before it goes live. Platform differences of the web build itself are in `docs/web-platform-differences.md`.

## Deploy to Web stages the build in public/flutter/ and, for now, never commits

Today `build_client` (an alias in Hillel's shell) merges admin-portal `develop` into `master`, whose **Build Web** builds the old app and pushes it to `invoiceninja/invoiceninja@v5-develop:public/`. Deploy to Web (`.github/workflows/web.yml`) replaces that, and never commits to the backend: that repository is already heavy with years of admin-portal builds, and the backend team asked that no build be committed (2026-11-13). It builds this app once and ships it two ways (§ Going live):

- **`pages/`, the hosted app.** The build at the site root with a static boot page (`render_boot_page.py --static --hosted --base-href / --api-url https://invoicing.co`), `manifest.json` scoped to `./`, and `tools/web_deploy/pages/_headers` and `404.html`. Published to Cloudflare Pages by Direct Upload and served at `admin.invoicing.co`.
- **`server/`, the self-hosted tarball.** `public/flutter/` (the build, minus `index.html`, `flutter_service_worker.js`, `drift_worker.dart`, `.last_build_id` and `*.symbols`, with `manifest.json` scoped to `../`), `resources/views/flutter/index.blade.php` (the boot page, `--blade`), and the landing page (`resources/views/landing/apps.blade.php`, `public/landing/`, § The landing page). Packed as `invoiceninja-web-<x.y.z>.tar.gz` and attached to this repo's GitHub Release; the backend's `react_release.yml` unpacks it into the server tarball.

**Modes.** `test` builds both trees and runs every gate, publishing nothing. `preview` (a dispatch) also deploys `pages/` to the Pages preview branch. `production` comes only from Deploy to all's `web:` leg and refuses unless the release tag `v<x.y.z>` is this commit; it deploys to the preview branch, checks what Pages serves there, promotes to the production branch, and uploads the tarball. Until the Pages project exists (repo variable `CLOUDFLARE_PAGES_PROJECT`, secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`), the Pages deploy is skipped with a notice and the tarball still ships.

**Three jobs, so neither shipment can hold up the other.** `deploy-web` builds, assembles both trees, runs the self-hosted gates and hands the trees on as artifacts (`web-pages`, `web-tarball`). `pages` runs the hosted gates and publishes; `attach` uploads the tarball in production, and is the only job with write access. A Pages failure (the size gate, wrangler, the check on the deployment) never withholds the tarball, which would otherwise leave the backend's release shipping the previous build without saying so.

Steps, in order:

1. `tools/prepare_foss.sh --web` (§ One FOSS build serves hosted and self-hosted).
2. `flutter build web --wasm --release --no-web-resources-cdn --pwa-strategy=none`. `--pwa-strategy=none` makes the bootstrap call `_flutter.loader.load()` with no service-worker settings; the option is hidden and deprecated in 3.47, and when it goes, a custom `web/flutter_bootstrap.js` (`{{flutter_js}}`, `{{flutter_build_config}}`, `_flutter.loader.load();`) does the same.
3. `tools/stamp_web_cache_bust.sh`: a content hash as `?v=` on the `main.dart.{wasm,mjs,js}` entries in `flutter_bootstrap.js`. Shared with `tools/build_demo_web.sh`.
4. `build.json` (`version`, `sha`, `run_url`, `built_at`) identifies a build: `curl https://admin.invoicing.co/build.json`, or `https://<server>/flutter/build.json`.
5. The two trees above. The self-hosted manifest's `id` resolves to `/`, the old app's, so an existing install on a self-hosted server updates in place; `web/manifest.json` is not touched (the GitHub Pages demo uses it).
6. Gates, before anything is published:
    - **size:** no file in `pages/` over 25 MiB, Pages' per-file limit (`main.dart.js` was 23.6 MiB on 5.1.24; the fallback is that one file from R2);
    - **served files** (`tools/web_deploy/check_served_files.py`, `--build .` for the Pages layout): every built file and every URL the page, bootstrap, manifest and font manifest name answers 200 with a type the browser accepts, for both trees, and again on the Pages preview deployment, before production is touched;
    - **boot smoke:** the app paints its first frame in headless Chrome, self-hosted as WASM and forced to dart2js, and hosted as WASM.
7. Artifact `web-staged` (7 days): `site/` (the self-hosted page as served, a `standalone.html` without `data-served` so a local copy keeps the usual server field, and `serve.py`), `pages/` and the tarball. Use `python3 serve.py .`: plain `python3 -m http.server` on an older Python serves `.mjs` as octet-stream, and the WASM boot then fails with no fallback.

Sizes, measured on 5.1.24: about 92 MB built (canvaskit 36 MB less its symbols, assets 24 MB of which 19 MB is translations, `main.dart.js` 25 MB, `main.dart.wasm` 15 MB); the tarball is about 30 MB.

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

## The landing page

**Every link and minimum-OS line on the invoicing.co landing page lives in `tools/web_deploy/landing/apps.json`, and `test/lint/landing_apps_test.dart` pins each minimum to the build files.** Hosted `invoicing.co/` becomes a page for every app (designed 2026-11-13): the two web apps first (Invoice Ninja Web, React at `app.invoicing.co`, recommended; Invoice Ninja App, this app at `admin.invoicing.co`), the client portal, then the desktop and mobile apps with the visitor's own platform highlighted, the add-ons, and the team's other products.

- **To change a link or a requirement, edit the JSON.** `tools/web_deploy/render_landing.py` fills `landing/landing.html` from it (`--blade` wraps it in `@verbatim` for the backend; `--static` for a preview) and copies its assets: the screenshots and Event Schedule's icon from `landing/img/`, the logos and fonts from `assets/`. It refuses a non-https URL or a placeholder left unfilled.
- **The minimums come from the build:** iOS from `ios/Podfile`, macOS from `macos/Podfile`, Android from `minSdk` (API level to version, a table in the test), Windows from Flutter's floor (Windows 10). A deployment-target bump that forgets the JSON fails CI.
- **Store links name each store's live listing.** Until a store's v2 goes live they are v1's (`com.invoiceninja.app`, the v1 App Store and Microsoft IDs); switch each with that store's launch (`docs/going-live.md`).
- **What the visitor arrived with goes on to the app they pick:** a sign-up link's `?signup=true` and `?rc=` (React's `#/register?rc=`, this app's query), UTM tags, and an old bookmark's `#/route` (to this app only, whose router maps admin-portal's routes; React's differ). The backend renders the page ahead of its `?login` / `?signup` redirect so the query is still there.
- **Every link opens in a new tab.** "Last used" is remembered in `localStorage` (`invoiceninja.landing.last`) when either web app is opened from the page; the page never redirects on its own. A "has moved" banner shows when the old app's `flutter.*` keys are in this origin's `localStorage`, and an "out of date" note when it runs as an installed app.
- **The screenshots are hand-made.** The React one is the public demo (`react.invoicing.co/demo`); retake it with data in its chart (the dashboard's range set to Last 365 days) when the demo account is in English.

## Going live

None of this is built yet beyond this repo's side; each item needs Hillel's go-ahead. Decided with the backend on 2026-11-13: no build is ever committed to the backend, hosted is served from Cloudflare Pages like React, self-hosted gets the build in the server's release tarball, and `invoicing.co` becomes the landing page.

**This repo (done):** `data-api-url` (`lib/app/serving_server_parse.dart`) and the static hosted boot page; the hosted login screen's way to Invoice Ninja Web for an account it can't sign in (Google, Microsoft, Apple or a passkey); `web.yml`'s two trees and gates; the `web:` leg in Deploy to all; `legacyV1Redirect` for v1's bookmarks; the landing page.

**Cloudflare (the backend team):** a Pages project created for **Direct Upload** with production branch `main` (React's Git integration can't run this build, and a Git-integrated project can't take direct uploads); an API token with Pages edit rights and the account ID as secrets, and the project name as the `CLOUDFLARE_PAGES_PROJECT` variable, on `invoiceninja/app`. At launch only: check the logs for API traffic on `admin.invoicing.co`, delete its DNS record and redirect rule (it 302s to `invoicing.co` today), and attach it as the custom domain.

**The backend:**

- **`react_release.yml`:** after "Prepare React FrontEnd", with `GH_TOKEN: ${{ github.token }}`, download the newest `invoiceninja/app` Release that carries an `invoiceninja-web-` asset and unpack it at the repo root (it holds `public/` and `resources/`); add `public/flutter/`, `public/landing/`, `resources/views/flutter/` and `resources/views/landing/` to `.gitignore`. Merge only once a Release carries the asset.
- **`flutterRoute()`:** hosted, when `HOSTED_LANDING` is on (default off: the launch switch and the rollback), renders `landing.apps` before the `?login` / `?signup` redirects, so `?signup`, `?rc` and UTM tags survive. Self-hosted's Flutter branch renders `flutter.index` when `public/flutter/flutter_bootstrap.js` exists and `FLUTTER_WEB_DEFAULT` is `v2` (default `legacy` until launch), with `is_hosted` and `base_href` (`$canvas_path . '/flutter/'`). `setBuild()`: `?build=v2|legacy` sets a cookie; the `wasm` / `last` / `next` cases go.
- **The `/app/` bridge (hosted):** its head script reads the landing page's `invoiceninja.landing.last`; `app` goes to `admin.invoicing.co/#/<path>?company=`, anything else to React as today.
- **CORS (`Cors.php`):** `X-API-OAUTH-PASSWORD` in the allowed headers, `Retry-After` in the exposed ones.
- **OAuth returns:** `flutter_web` added to `OneTimeTokenRequest`'s `platform` rule, returning to an allow-listed `FLUTTER_WEB_URL` (`admin.invoicing.co` hosted, `app_url` self-hosted), never a client-supplied URL. Only then does the app send it (today the rule 422s anything else).
- **`public/.htaccess`** (self-hosted): `AddType` for `wasm` and `mjs` in `<IfModule mod_mime.c>`, `DEFLATE` for wasm, js and json, and no-cache under `/flutter/`; the nginx equivalents in `invoiceninja/dockerfiles` and the self-host docs.

**Gates before launch:**

- **Error reporting.** Sentry is off on web; at least send a GTM event when the 30-second card shows.
- **MIME and compression on self-hosted.** `curl -sI` a staging server for `main.dart.mjs`, `main.dart.wasm`, `pdfjs/pdf.worker.min.mjs` and `sqlite3.wasm`. A wrong type on `.mjs` is a blank page.
- **A deep link survives sign-in** on a fresh `admin.invoicing.co`.

**Launch:** attach `admin.invoicing.co`, turn on `HOSTED_LANDING`, and make `FLUTTER_WEB_DEFAULT`'s default `v2` in the next server release.

**Cleanup:** retire `build_client` and admin-portal's Build Web; delete the stale `main.{html,last,next,wasm,foss.wasm}.dart.js` and `main.foss.dart.js.map` from the backend (about 55 MB; self-update never deletes files). Keep `public/flutter_service_worker.js`. `?clear_local` stays out of this app's boot page: deleting every database generation also deletes unsent changes, and anyone can send the link.

**What users will notice:** hosted web users sign in once at `admin.invoicing.co`, a new origin (admin-portal's token, `flutter.checksum` in `localStorage`, isn't imported, on purpose, so the Welcome still shows); What's New stays silent on that first load; an installed copy of the old web app keeps opening `invoicing.co`, now the landing page, which says so; passkeys and Google, Microsoft and Apple sign-in aren't offered on this app's web build yet (passkeys belong to `app.invoicing.co`), and its login screen points those accounts to Invoice Ninja Web.
