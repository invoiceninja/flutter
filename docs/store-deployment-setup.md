# Store deployment — setup runbook

**How to get the six publish workflows working from zero.** This is the *how*; `docs/setup.md` §§ Shipping to the stores → Windows / Microsoft Store is the *why* (rationale, design decisions, per-platform background). Read a section here to act; follow the cross-reference when you want to know why it's built that way.

Nothing in this guide requires editing a workflow. They are complete as written — what's missing is credentials.

---

## 0. Start here

Six workflows publish the app. Every one of them:

- is **manual only** — GitHub → **Actions** → pick the workflow → **Run workflow** (on the default branch). There is no push, tag, or schedule trigger anywhere in this repo.
- **runs the full test suite first** (`_test.yaml`, always on `ubuntu-latest`, ~8–12 min). A red suite stops the release before anything is built or uploaded. Under **Deploy to all** (below) it runs once, inside the release, and the stores skip their copy.
- ships to a **testing channel**, not straight to users — with **two exceptions**. **Microsoft Store** auto-commits to certification and goes live on the listing with no manual gate (§3D). **AppImage** attaches its build to a **public GitHub Release** — this is a public repo, so it is downloadable by anyone the moment it is created; `prerelease: true` only keeps it off the "Latest" badge, it restricts nothing (§3A). The same Release carries the **F-Droid APKs**, which F-Droid picks up from it on its own schedule once the app is listed (§3A).

| Target | Workflow | Lands in | Store credentials |
|---|---|---|---|
| Linux AppImage + F-Droid APKs | `appimage.yml` | GitHub Release (prerelease) → F-Droid | a repo setting, plus the F-Droid signing key (4, in an Environment) |
| Linux Snap | `snapcraft.yml` | Snap Store `edge` | 1 |
| Android | `playstore.yml` | Play **Open testing** (or another testing track) | 5 |
| Windows | `microsoft-store.yml` | Store certification → live listing | 5 |
| iOS | `appstore-ios.yml` | TestFlight | 8 |
| macOS | `appstore-macos.yml` | TestFlight | 7 (3 shared with iOS) |
| **All of the above** | `deploy-all.yml` | Every row above, release first | the union |

**Deploy to all** (`deploy-all.yml`) is the one dispatch for a whole release. It runs `tools/check_release_ready.sh` (the release notes are written and the version bump has run, §5), then `appimage.yml` (its test gate is the run's only test run; the GitHub Release is created), then the five store workflows in parallel, each called with `skip_tests` so its nested `test` shows as skipped. A failed release skips every store; a failed store leaves the others alone. It includes **Microsoft**, which goes live with no manual gate. Its runs appear only under "Deploy to all" in the Actions sidebar, not in each store workflow's history.

All six additionally read `IN_SENTRY_DSN`, which is optional — 28 secret names in total (four of them the F-Droid signing key, kept in an Environment), plus two optional Google Sign-In client IDs (Android, and iOS + macOS, §2) that only switch "Sign in with Google" on. `ci.yaml` and `_test.yaml` use **no secrets at all**, so nothing in this guide affects them.

### First: find out what's already set

```sh
gh auth login          # once per machine
gh secret list         # tick off anything already present before you start
```

Twenty-one secret names exist across the six workflows. To regenerate that list at any time:

```sh
grep -rhoE 'secrets\.[A-Z0-9_]+' .github/workflows/ | sort -u
```

### How to add a secret

Web UI: **Settings → Secrets and variables → Actions → New repository secret**. Fine for short values, error-prone for the eight that are multi-line or base64 blobs — a trailing newline or a soft-wrapped paste breaks them silently. Prefer piping from a file:

```sh
gh secret set APP_STORE_CONNECT_PRIVATE_KEY < AuthKey_ABC123XYZ.p8
base64 -i android/app/key.jks | gh secret set ANDROID_KEYSTORE_BASE64
```

> On Linux, `base64` needs `-w0` to avoid line wrapping: `base64 -w0 android/app/key.jks`. On macOS, `base64 -i <file>` is already unwrapped.

> **You cannot read a secret back to check it.** `gh secret list` (and the web UI) show only the name and last-updated time — the value is write-only. A truncated paste or a stray newline surfaces as a confusing build failure on the next dispatch, which is exactly why the piped forms above are worth using over copy-paste.

---

## 1. Prerequisites

Accounts and **roles** that must exist before any credential can be minted. The role is usually what blocks people — it's often held by someone else on the team.

| Store | Account | The role that trips people up |
|---|---|---|
| **Apple** | Apple Developer Program membership, team `NPC44Y2C98` | Minting an App Store Connect API key needs **Admin** or **Account Holder**. A Developer-role account cannot do it. |
| **Google Play** | Play Console access to `com.invoiceninja.admin`, plus a Google Cloud project | The **Google Play Android Developer API** must be enabled on that GCP project, and you need rights to create a service account in it. |
| **Microsoft** | Partner Center account owning `InvoiceNinja.AdminPortal` | Registering the Entra app needs **Microsoft Entra tenant admin** — a different directory role from your Partner Center role. |
| **Snap** | Snap Store account with upload rights on the `invoiceninja` snap | — |
| **GitHub** | **Admin** on `invoiceninja/flutter` (required to add secrets) | AppImage additionally needs Settings → Actions → General → **Workflow permissions = Read and write** (§3A). |
| **Sentry** | A project DSN | Optional. An empty or unset `IN_SENTRY_DSN` is a safe no-op — `Env.sentryDsn` defaults to `''` and Sentry stays disabled. |

> **Shared record links need two console steps of their own**, and one of them
> blocks Apple builds entirely: Associated Domains must be enabled on the App ID
> before `ios/Runner/Runner.entitlements` will sign, and `assetlinks.json` needs
> the Play **app signing** SHA-256 from Play Console → Setup → App integrity.
> Both, plus the order they go in, are in **`APP_LINKS.md`**.

> **Sharing files into the app (invoiceninja/flutter#173) adds a second signed
> iOS target**, the Share Extension, and an **App Group** both targets use. The
> group must be registered and enabled on both App IDs before
> `ios/Runner/Runner.entitlements` will sign, and the extension needs its own
> App Store profile and secret — §3E steps 1 and 3. Until then every iOS App
> Store dispatch fails at the profile step.
>
> **The home-screen widgets (docs/home-screen-widgets.md) add a third signed
> iOS target**, `com.invoiceninja.admin.HomeWidgets`, in the same App Group. It
> needs its own App ID (App Groups enabled), App Store profile and secret
> (`IOS_HOME_WIDGETS_APPSTORE_PROVISIONING_PROFILE_BASE64`) — §3E steps 1 and
> 3. Until then every iOS App Store dispatch fails at the profile step.
>
> **The macOS widgets add the same on the Mac side:** the Mac app and its
> widgets share a team-prefixed App Group,
> `NPC44Y2C98.com.invoiceninja.admin.widgets`. A group that starts with the team
> ID is **never registered** in the portal (macOS accepts it as is), so there is
> nothing to create under Identifiers → App Groups — only the **App Groups
> capability** has to be on both App IDs. Then: the Mac App Store profile
> "Invoice Ninja Home Widgets macOS App Store" for
> `com.invoiceninja.admin.HomeWidgets`, its secret
> `MACOS_HOME_WIDGETS_APPSTORE_PROVISIONING_PROFILE_BASE64`, and a **fresh** Mac
> App Store profile for the app, since the Runner now claims the group. Until
> then every macOS App Store dispatch fails at the profile step.
>
> **None of this is needed for a release archived in Xcode** (Product →
> Archive). Automatic signing registers the widget App ID and its group and
> makes the profiles itself; open the HomeWidgets target's **Signing &
> Capabilities** once before the first archive, and click **Try Again** if it
> shows a profile error. Everything in §3E is for the GitHub workflows only.

The Play, Partner Center, and Snap Store **listings already exist** — you are wiring credentials to existing apps, not creating new ones. That matters for Google Play in particular: a brand-new package requires one manual bundle upload in the Console before the API will accept anything, and that is already satisfied here. **Confirm the Apple side yourself** — the iOS and macOS app records must exist on App Store Connect (§3E step 5); unlike Play, ASC then accepts the very first build over the API with no prior manual upload.

---

## 2. Master secret table

All 22, plus the two optional Google client IDs, grouped by what they unlock. `IN_SENTRY_DSN` is the only cross-cutting one.

### Shared

| Secret | Used by | What it is | How to produce it |
|---|---|---|---|
| `IN_SENTRY_DSN` | all 6 | Sentry DSN, baked in at compile time via `--dart-define` | Copy from the Sentry project settings. Safe to leave unset. |

### F-Droid — `appimage.yml`, Environment `fdroid-signing`

Environment secrets, not repository secrets: only the `fdroid-sign` job can read them, and only on `main` (§3A, F-Droid signing key).

| Secret | What it is | How to produce it |
|---|---|---|
| `FDROID_KEYSTORE_BASE64` | The F-Droid keystore, base64 — **a dedicated key, never the Play upload key** | `base64 -i fdroid.jks` |
| `FDROID_KEYSTORE_PASSWORD` | Its store password | Whatever you set in `keytool -genkeypair` |
| `FDROID_KEY_ALIAS` | Its key alias | `fdroid` if you followed §3A |
| `FDROID_KEY_PASSWORD` | Its key password | **The same value as `FDROID_KEYSTORE_PASSWORD`**: `keytool` makes a PKCS12 keystore, which has a single password |

### Snap — `snapcraft.yml`

| Secret | What it is | How to produce it |
|---|---|---|
| `SNAPCRAFT_STORE_CREDENTIALS` | Exported Snap Store login | `snapcraft export-login --snaps invoiceninja --acls package_access,package_push,package_update,package_release --expires <YYYY-MM-DD> exported.txt` then paste the **full contents** of `exported.txt` |

### Android — `playstore.yml`

| Secret | What it is | How to produce it |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | The upload keystore, base64 | `base64 -i android/app/key.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` | Read from local `android/key.properties` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` | Read from local `android/key.properties` |
| `ANDROID_KEY_ALIAS` | `keyAlias` | Read from local `android/key.properties` |
| `PLAY_SERVICE_ACCOUNT_JSON` | GCP service-account JSON key | Full JSON text, verbatim (passed inline — never written to disk on the runner) |
| `IN_GOOGLE_SERVER_CLIENT_ID` | *Optional.* Google OAuth **Web** client ID, passed as `serverClientId` | `docs/setup.md` § Google Sign-In client IDs. Unset hides "Sign in with Google" on Android. |

### Windows — `microsoft-store.yml`

| Secret | What it is | How to produce it |
|---|---|---|
| `PARTNER_CENTER_TENANT_ID` | Entra directory (tenant) ID | Entra admin center → app registration → Overview |
| `PARTNER_CENTER_CLIENT_ID` | Entra application (client) ID | Same page |
| `PARTNER_CENTER_CLIENT_SECRET` | Entra client secret **value** | Certificates & secrets → New client secret. The *value* is shown once. |
| `PARTNER_CENTER_SELLER_ID` | Partner Center Seller ID | Partner Center account settings. **Not** the `9N…` Store ID. |
| `MS_STORE_PRODUCT_ID` | The app's **Store ID** (`9NG93WNXN797` for Invoice Ninja - Beta) | Product management → Product identity → Store ID, or `msstore apps list`. For an MSIX app it *is* the `9N…` value. Not `9N3F2BBCFDR6`, which is the old app. |

### Apple — shared by `appstore-ios.yml` and `appstore-macos.yml`

| Secret | What it is | How to produce it |
|---|---|---|
| `APP_STORE_CONNECT_ISSUER_ID` | ASC API issuer UUID | App Store Connect → Users and Access → Integrations |
| `APP_STORE_CONNECT_KEY_ID` | ASC API key ID | Same page |
| `APP_STORE_CONNECT_PRIVATE_KEY` | The `.p8` private key, **raw text — NOT base64** | `gh secret set APP_STORE_CONNECT_PRIVATE_KEY < AuthKey_<KEYID>.p8` |
| `IN_GOOGLE_IOS_CLIENT_ID` | *Optional.* Google OAuth **iOS** client ID for `com.invoiceninja.admin` — the Mac app signs in with the same one | `docs/setup.md` § Google Sign-In client IDs — its reversed form must also be in `ios/Runner/Info.plist` and `macos/Runner/Info.plist`. Unset hides "Sign in with Google" on iOS and macOS. |

### Apple — iOS only

| Secret | What it is | How to produce it |
|---|---|---|
| `APPLE_DISTRIBUTION_CERT_P12_BASE64` | Apple Distribution cert + private key | `base64 -i dist.p12` |
| `APPLE_DISTRIBUTION_CERT_PASSWORD` | The `.p12` export password | Whatever you set on export |
| `IOS_APPSTORE_PROVISIONING_PROFILE_BASE64` | iOS App Store profile | `base64 -i profile.mobileprovision` |
| `IOS_SHARE_EXTENSION_APPSTORE_PROVISIONING_PROFILE_BASE64` | iOS App Store profile for the Share Extension (`com.invoiceninja.admin.ShareExtension`) | `base64 -i share-extension.mobileprovision` |
| `IOS_HOME_WIDGETS_APPSTORE_PROVISIONING_PROFILE_BASE64` | iOS App Store profile for the home-screen widgets (`com.invoiceninja.admin.HomeWidgets`) | `base64 -i home-widgets.mobileprovision` |

### Apple — macOS only

| Secret | What it is | How to produce it |
|---|---|---|
| `MAC_DISTRIBUTION_CERTS_P12_BASE64` | **One combined `.p12`** with **both** Mac distribution identities | `base64 -i certs.p12` — see §3E for why it must be combined |
| `MAC_DISTRIBUTION_CERTS_PASSWORD` | That `.p12`'s export password | Whatever you set on export |
| `MACOS_APPSTORE_PROVISIONING_PROFILE_BASE64` | Mac App Store profile (distinct from the iOS one) | `base64 -i profile.provisionprofile` |
| `MACOS_HOME_WIDGETS_APPSTORE_PROVISIONING_PROFILE_BASE64` | Mac App Store profile for the macOS home-screen widgets (`com.invoiceninja.admin.HomeWidgets`) | `base64 -i home-widgets.provisionprofile` |

---

## 3. Per-store setup

Ordered easiest → hardest. Working in this order means you validate the pipeline before spending time on certificates.

### A. AppImage — no store credentials *(do this first)*

The only workflow that needs no store credential — it still reads the optional `IN_SENTRY_DSN`, but authenticates with the built-in `GITHUB_TOKEN`. It's also the one workflow that writes back to the repo (it creates the `v<version>` tag and GitHub Release), so what it needs is a repo *setting* rather than a secret.

> **The release it creates is public.** `invoiceninja/flutter` is a public repo, so the attached AppImage is downloadable by anyone as soon as the release exists. `prerelease: true` only keeps it off the "Latest release" badge — it is not an access control. Use the dry run below for validation; a real dispatch is a real release.

**One-time setup**

1. Settings → Actions → General → **Workflow permissions** → **Read and write permissions**. Without it, `preflight` cannot see draft Releases and `publish` cannot create the Release — the latter fails at the very end, after a full build.
2. Nothing else. GitHub Releases need no enabling.

The Release body is the version's `kReleaseNotes` bullets (`tools/release_notes_markdown.py`, read in preflight, so a version with no notes fails before anything is built), followed by GitHub's generated Full Changelog link. A re-dispatch onto an existing Release leaves its body alone (docs/release-notes.md).

**Verify** — dispatch `Deploy to GitHub Releases` with the **`publish` checkbox unchecked**. That's a build-only dry run: it still runs the test gate, builds the AppImage, smoke-checks it, and uploads it as a run artifact — but creates no tag and no Release. Download the artifact from the run summary to confirm.

This single dry run exercises checkout → test gate → Flutter build → packaging → artifact upload. If it's green, the shared half of every other workflow is known good.

The same dry run builds the three F-Droid APKs twice each with F-Droid's own tooling, signs them (with a throwaway key until the secrets below exist), and checks them the way F-Droid will — `docs/fdroid.md` § The reproducibility gate. Those jobs take ~20–30 min and run in parallel with the test gate.

> A `v*` tag-protection rule or repository ruleset would block this workflow. If the release step fails on the tag rather than the upload, check Settings → Rules.

#### F-Droid signing key

F-Droid publishes the APK **we** sign, after checking it against its own rebuild, and pins the key's fingerprint for good — every later release must be signed with the same key, and **losing it ends the listing**. Do this once, before the recipe is submitted (`docs/fdroid.md` § Signing the F-Droid APK):

1. **Make the key** on a trusted machine — a dedicated one, never the Play upload key:
   ```sh
   keytool -genkeypair -v -keystore fdroid.jks -alias fdroid \
     -keyalg RSA -keysize 4096 -validity 36500 \
     -dname "CN=Invoice Ninja, O=Invoice Ninja"
   ```
2. **Back it up offline** — the `.jks` and both passwords, somewhere that outlives this laptop and this repo's secrets.
3. **Create the Environment**: Settings → Environments → **New environment** → `fdroid-signing` → Deployment branches and tags → **Selected branches** → add `main`. Add the four secrets of §2 *to the Environment* (not as repository secrets).
4. **Read its fingerprint** in both forms (each asks for the password):
   ```sh
   keytool -list -v -keystore fdroid.jks -alias fdroid | grep 'SHA256:'
   #   → colon pairs: goes in APP_LINKS_ANDROID_FINGERPRINTS on the server (APP_LINKS.md § 2)
   keytool -list -v -keystore fdroid.jks -alias fdroid \
     | sed -n 's/^[[:space:]]*SHA256: //p' | tr -d ':' | tr 'A-F' 'a-f'
   #   → lowercase hex: goes in AllowedAPKSigningKeys in tools/foss/com.invoiceninja.admin.yml
   ```
   Not `keytool -exportcert … | openssl dgst`: on a PKCS12 keystore without the password,
   `-exportcert` fails and writes its error to **stdout**, so that pipe prints the hash of an error
   message, which looks just like a fingerprint. The `-list` form prints nothing on a wrong password.
5. **Commit the lowercase one** as `AllowedAPKSigningKeys` in `tools/foss/com.invoiceninja.admin.yml`. Done for the current key on 2026-10-15 (`d17fac8d…c17d`); repeat only for a rotation. From then on the APKs are mandatory and must carry exactly this key — the `sign` step fails on any other, and `publish` fails on an APK signed with the ephemeral key (missing Environment secrets).

**Verify** — a dry run now reports `publishable=true` from the sign step instead of the ephemeral-key warning, and `apksigner verify --print-certs` on a downloaded `fdroid-signed` APK prints the same SHA-256.

### B. Snap — 1 secret

**One-time setup** — on a machine logged into the Snap Store (`snapcraft login`):

```sh
snapcraft export-login \
  --snaps invoiceninja \
  --acls package_access,package_push,package_update,package_release \
  --expires 2027-08-17 \
  exported.txt
```

Paste the **entire** contents of `exported.txt` into `SNAPCRAFT_STORE_CREDENTIALS`, then delete the local file.

> **Record the expiry date somewhere you'll see it.** Expired credentials break publishing, and the failure is not obviously about expiry.

**Verify** — dispatch `Deploy to Snapcraft`. Success puts a new revision on the `edge` channel; check with `snap info invoiceninja`. `grade: devel` in `snap/snapcraft.yaml` structurally prevents a push to `stable`/`candidate`.

> Testers installing from edge must run `snap connect invoiceninja:password-manager-service` once, or the app can't open its encrypted database. This is a known strict-confinement limitation, not a setup error — see `docs/setup.md` § Linux desktop / Snap.

### C. Android / Google Play — 5 secrets

**The signing material already exists — don't create a new keystore.** `android/app/key.jks` and `android/key.properties` are present in the checkout releases have been built from. Both are **gitignored and untracked**, so a fresh clone or a different machine will *not* have them — get them from whoever holds the release machine, or from the off-CI backup. Generating a replacement doesn't work: Play rejects an upload signed by an unregistered key.

**Produce the four signing secrets**

```sh
cat android/key.properties                                  # storePassword / keyPassword / keyAlias
base64 -i android/app/key.jks | gh secret set ANDROID_KEYSTORE_BASE64
```

Map the rest: `storePassword` → `ANDROID_KEYSTORE_PASSWORD`, `keyPassword` → `ANDROID_KEY_PASSWORD`, `keyAlias` → `ANDROID_KEY_ALIAS`.

> **Back up `key.jks` and its passwords off-CI.** If the app is enrolled in Play App Signing, this is the *upload* key — Google holds the real app signing key, and a lost upload key can be reset through Play Console support. If it is **not** enrolled, this keystore *is* the app signing key, and losing it means you can never ship an update to the listing again. Back it up either way.

**One-time Play API setup**

1. Google Cloud Console → create or select a project → enable the **Google Play Android Developer API**.
2. Create a **service account** in that project → add a **JSON key** → download it.
3. Play Console → **Users and permissions** → invite the service-account email → grant **app-level** permission on `com.invoiceninja.admin`: **"Release apps to testing tracks"**.

> Grant **only** the testing-track permission. That's what makes this workflow structurally incapable of touching production, which is the whole safety model here.

4. Paste the JSON file's full text into `PLAY_SERVICE_ACCOUNT_JSON`.

**Verify** — dispatch `Deploy to Google Play`. Success lands a release on the **Open testing** track (`beta`), with the version's short notes under "What's new", out to testers once Google's review passes; nothing is left to finish in the Console. Dispatch with `track: internal` or `alpha` to target another testing track, or `rollout` below 100 for a staged rollout. Promote to production by hand in the Console.

### D. Windows / Microsoft Store — 5 secrets

> **This is the only pipeline with no manual gate.** A dispatch uploads *and commits* the submission: it enters Store certification automatically and goes live on the listing once certified. There is no `edge` / `internal` / TestFlight equivalent. The upload runs with `--noCommit`; `tools/msstore_release_notes.py` then writes the version's digest (`changelogs/<build × 10 + 1>.txt`) into every listing's release notes and commits — so a failure there leaves a draft in Partner Center, never a submission without notes. If you want a gate, drop that script's commit (the draft then waits for you in Partner Center) or target a package flight with `-f <flightId>`. `tools/msstore_release_notes.py --dry-run` (with the four secrets in the environment) reads the submission without changing it.

**One-time setup**

1. Associate a **Microsoft Entra tenant** with your Partner Center account (Partner Center → Account settings → Tenants). **This needs an Entra *work* account with Global Administrator — a personal Microsoft account (the Partner Center login, `contact@invoiceninja.com`) is refused.** If the tenant is only that account's "Default Directory", create a user in it (`partner-admin@contactinvoiceninja.onmicrosoft.com` exists for this), give it Global Administrator, and sign in as it at the Associate prompt. **Error `530035`** there is security defaults blocking an admin with no MFA: register MFA for the user at `aka.ms/mfasetup` first.
2. Entra admin center → **App registrations** → New registration. Record the **Directory (tenant) ID** and **Application (client) ID**.
3. That app → **Certificates & secrets** → **New client secret**. Copy the **Value** immediately — it is shown once and cannot be retrieved later. **The current one (app "Invoice Ninja GitHub Actions") expires in November 2028**; mint its replacement before then and re-set `PARTNER_CENTER_CLIENT_SECRET`.
4. Partner Center → **User management** → **Sign in with Microsoft Entra ID** (as the work account above) → **Microsoft Entra applications** → add the app you registered with the **Manager** role (it shows as `Manager(Windows)`).
5. Record the **Seller ID** (Account settings → Legal info → Developer) and the app's **Store ID** (Product management → Product identity).

**Two ID traps** — both fail confusingly if you get them wrong:

- `PARTNER_CENTER_SELLER_ID` is the Partner Center **Seller ID** (a number), *not* the `9N…` Store ID.
- `MS_STORE_PRODUCT_ID` is the **Store ID of Invoice Ninja - Beta, `9NG93WNXN797`** — the same `9N…` value as the `apps.microsoft.com/detail/...` URL, because for an MSIX app the submission API's application id *is* the Store ID (measured 2026-11-08: `GET /v1.0/my/applications` lists `9NG93WNXN797` and `9N3F2BBCFDR6`, the old app). The account has both apps, so the trap is picking the old one.

**Check the credentials without publishing.** A dispatch here goes live, so prove the Entra app and its Manager role first: get a token with the client secret (`POST https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token`, `grant_type=client_credentials`, `scope=https://manage.devcenter.microsoft.com/.default`), then `GET https://manage.devcenter.microsoft.com/v1.0/my/applications` with it. A 200 listing `9NG93WNXN797` means the secrets are right; a 401 / 403 means the Manager role (step 4) is missing. The secret can be a temporary second one on the same app — access is granted per app, not per secret. `msstore publish` also fails when the app has a pending submission left in draft in Partner Center (`pendingApplicationSubmission` in that response).

**Check the package identity matches Partner Center.** The `msix_config` block in `pubspec.yaml` must exactly match Partner Center → Product identity, or upload validation rejects the package:

```yaml
identity_name: InvoiceNinja.AdminPortal
publisher: CN=2B7AA393-06A0-46F5-AF85-1917142440C3
publisher_display_name: Invoice Ninja
```

**Verify** — dispatch `Deploy to Microsoft Store`. Success means the submission is committed; certification typically takes hours. Watch it in Partner Center.

### E. Apple — iOS + macOS, 12 secrets

The hardest of the six, and the one where order matters: **App ID capabilities → certificates → provisioning profiles → API key**. A profile is minted against the capabilities and certificates that exist *at that moment*, so doing this out of order means re-issuing profiles.

#### Step 1 — App ID capabilities

The App IDs must have the capabilities the entitlements files declare, or `xcodebuild archive` fails on a mismatch:

| Target | App ID | Required capabilities | Declared in |
|---|---|---|---|
| iOS | `com.invoiceninja.admin` | **Sign in with Apple**, **Associated Domains** (`APP_LINKS.md`), **App Groups** → `group.com.invoiceninja.admin` | `ios/Runner/Runner.entitlements` |
| iOS Share Extension | `com.invoiceninja.admin.ShareExtension` | **App Groups** → `group.com.invoiceninja.admin` | `ios/ShareExtension/ShareExtension.entitlements` |
| iOS home-screen widgets | `com.invoiceninja.admin.HomeWidgets` | **App Groups** → `group.com.invoiceninja.admin` | `ios/HomeWidgets/HomeWidgets.entitlements` |
| macOS | `com.invoiceninja.admin` | **Sign in with Apple**, **App Sandbox**, **Keychain Sharing**, **App Groups** → `NPC44Y2C98.com.invoiceninja.admin.widgets` | `macos/Runner/Release.entitlements` |
| macOS home-screen widgets | `com.invoiceninja.admin.HomeWidgets` | **App Sandbox**, **App Groups** → `NPC44Y2C98.com.invoiceninja.admin.widgets` | `macos/HomeWidgets/HomeWidgets.entitlements` |

For the home-screen widgets: create **one** explicit App ID, `com.invoiceninja.admin.HomeWidgets`, for both platforms (tick iOS and macOS), with **App Groups** enabled, then **Configure** → `group.com.invoiceninja.admin` for iOS. The Mac group `NPC44Y2C98.com.invoiceninja.admin.widgets` is team-prefixed: it is not registered under Identifiers → App Groups and won't appear in the Configure list, and that is correct — the App Groups capability on the App ID is all macOS needs. `com.invoiceninja.admin` already has App Groups (from the Share Extension), so its capabilities don't change; mint its Mac App Store profile after this step anyway (step 3), because the Runner's entitlements now claim the group.

For the Share Extension (invoiceninja/flutter#173): first register the App Group `group.com.invoiceninja.admin` (Identifiers → App Groups), then create the extension's App ID, then enable App Groups on both iOS App IDs and assign that group. **Do this before merging the Share Extension**, and then regenerate and re-upload **both** existing App Store profiles: changing an App ID's capabilities marks every profile minted against it Invalid, and the macOS app shares the `com.invoiceninja.admin` App ID (`macos/Runner/Configs/AppInfo.xcconfig`). The iOS archive fails outright with the old profile (`Runner.entitlements` now claims App Groups); regenerate the macOS one (`MACOS_APPSTORE_PROVISIONING_PROFILE_BASE64`) too rather than find out at the next macOS release. A developer's first device build with Automatic signing registers the new App ID and group itself — which needs the Admin or App Manager role.

#### Step 2 — Certificates

> **"No Certificates are available" when generating a profile** means the team has no distribution certificate you can sign profiles with — the usual state when releases have been archived in Xcode. Xcode's Automatic signing uses an **Apple-managed** ("cloud") distribution certificate, which never appears in the portal's profile wizard and can't be exported. CI needs its own: on the Mac that will export it, Keychain Access → **Certificate Assistant → Request a Certificate From a Certificate Authority** → *Saved to disk*; then portal → Certificates → **+** → **Apple Distribution** → upload the `.certSigningRequest` → download and double-click the `.cer` to install it with its private key. Repeat with **Mac Installer Distribution** for macOS. Only then does the profile wizard list a certificate. Creating them doesn't affect Xcode archives, which keep using the managed one.

| Certificate | Signs | Goes into |
|---|---|---|
| **Apple Distribution** | the iOS app, and the macOS `.app` | `APPLE_DISTRIBUTION_CERT_P12_BASE64` (iOS) and the combined macOS `.p12` |
| **Mac Installer Distribution** | the macOS `.pkg` wrapper | the combined macOS `.p12` only |

**iOS** — export the Apple Distribution identity (cert + private key) from Keychain Access as its own password-protected `.p12`:

```sh
base64 -i dist.p12 | gh secret set APPLE_DISTRIBUTION_CERT_P12_BASE64
```

**macOS — export both identities into ONE `.p12`.** In Keychain Access select *both* the Apple Distribution and Mac Installer Distribution identities, then **Export 2 items…** into a single file:

```sh
base64 -i certs.p12 | gh secret set MAC_DISTRIBUTION_CERTS_P12_BASE64
```

> **Why combined, not two secrets.** A Mac App Store `.pkg` is signed twice — the app cert signs the `.app` inside, the installer cert signs the `.pkg` around it. But two separate `import-codesign-certs` steps break: each generates its own random password for the shared `signing_temp` keychain, so the second step's `security set-key-partition-list` fails against the first step's keychain ([`import-codesign-certs#14`](https://github.com/Apple-Actions/import-codesign-certs/issues/14)). One combined `.p12` is the action's own recommended workaround. Omitting the installer cert produces a package App Store Connect rejects.

#### Step 3 — Provisioning profiles

Profiles → **+** → Distribution → **App Store Connect**, then pick the platform. Create **five** App Store profiles, each embedding the certificate from step 2: **iOS App Store** and **Mac App Store** for `com.invoiceninja.admin`, **iOS App Store** for `com.invoiceninja.admin.ShareExtension`, and **iOS App Store** and **Mac App Store** for `com.invoiceninja.admin.HomeWidgets`. Mint them *after* step 1 — a profile carries the capabilities its App ID had at that moment.

```sh
base64 -i profile.mobileprovision         | gh secret set IOS_APPSTORE_PROVISIONING_PROFILE_BASE64
base64 -i share-extension.mobileprovision | gh secret set IOS_SHARE_EXTENSION_APPSTORE_PROVISIONING_PROFILE_BASE64
base64 -i home-widgets.mobileprovision    | gh secret set IOS_HOME_WIDGETS_APPSTORE_PROVISIONING_PROFILE_BASE64
base64 -i home-widgets.provisionprofile   | gh secret set MACOS_HOME_WIDGETS_APPSTORE_PROVISIONING_PROFILE_BASE64
base64 -i profile.provisionprofile        | gh secret set MACOS_APPSTORE_PROVISIONING_PROFILE_BASE64
```

**The profile names must match what's committed.** The workflows and export options reference profiles by name:

| File / setting | Expects |
|---|---|
| `ios/ExportOptions.plist` | `Invoice Ninja Admin App Store`, `Invoice Ninja Share Extension App Store`, `Invoice Ninja Home Widgets App Store` |
| `macos/ExportOptions.plist` | `Invoice Ninja macOS App Store`, `Invoice Ninja Home Widgets macOS App Store` |
| `tools/ci_macos_target_profiles.rb` (run by `appstore-macos.yml`) | `Invoice Ninja macOS App Store`, `Invoice Ninja Home Widgets macOS App Store` |
| `tools/ci_ios_target_profiles.rb` (run by `appstore-ios.yml`) | `Invoice Ninja Admin App Store`, `Invoice Ninja Share Extension App Store`, `Invoice Ninja Home Widgets App Store` |

Name the profiles exactly that in the portal, **or** edit those four places to match the names you used.

> **Why iOS pins profiles per target.** A `PROVISIONING_PROFILE_SPECIFIER` on the `xcodebuild` command line applies to *every* target, and a profile is bound to one bundle id — so with the Share Extension embedded, the global override signed the extension with the app's profile and the archive failed. `tools/ci_ios_target_profiles.rb` sets each target's Release profile in the runner's copy of the project instead (the `xcodeproj` gem ships with CocoaPods).

#### Step 4 — App Store Connect API key

App Store Connect → **Users and Access → Integrations → App Store Connect API** → generate a key with the **App Manager** role.

- Download the `.p8` — **it downloads once and is non-recoverable.**
- Record the **Key ID** and the **Issuer ID**.

```sh
gh secret set APP_STORE_CONNECT_KEY_ID     --body "ABC123XYZ"
gh secret set APP_STORE_CONNECT_ISSUER_ID  --body "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
gh secret set APP_STORE_CONNECT_PRIVATE_KEY < AuthKey_ABC123XYZ.p8
```

> `APP_STORE_CONNECT_PRIVATE_KEY` is the **raw `.p8` text**, not base64 — unlike every other Apple secret here. Base64-encoding it is a common and confusing failure.

#### Step 5 — App records

Confirm the iOS and macOS apps exist on App Store Connect. Unlike Google Play, ASC accepts the **first** build via API with no prior manual upload, as long as the record exists.

**Verify** — dispatch `Deploy to TestFlight (iOS)`, then `Deploy to TestFlight (macOS)`. Success puts a build on TestFlight for testers. **Uploading to TestFlight does not submit for App Store review** — that's a separate manual action in App Store Connect.

**Testers get the build with no clicks.** After the upload, `tools/testflight_release.py` does what used to be done by hand in App Store Connect: it waits for the build to be listed and sets its en-US "What to Test" to the version's digest (`changelogs/<build × 10 + 1>.txt`, the text Google Play gets) minus any line naming Android, Google Play or F-Droid; waits for Apple to process it (`VALID`); adds it to every external group ("Beta - External", the public TestFlight link); and submits it for beta app review. External testers are notified once Apple approves, usually within hours. Internal testers get every build on their own. The step is `continue-on-error`: the build is already up, so a failure there means finishing it by hand. `--dry-run` (with the three App Store Connect secrets in the environment) finds the build and prints what it would do. The App Store's own "What's New in This Version" is still set by hand at submission — the first version of an app can't carry one.

> Your local Xcode projects are untouched by any of this. All their targets — the app, the Share Extension and the home-screen widgets, on both platforms — still use Automatic signing with an Apple Development identity (which also registers the extensions' App IDs and the App Group on your first device build or archive); CI forces manual signing via `xcodebuild` command-line overrides — plus, on iOS, the per-target profiles pinned on the runner — so local development keeps working.

---

## 4. First dispatch

Run them in this order — cheapest failure first:

1. **AppImage** (dry run, `publish: false`) — validates checkout, the test gate, and the Flutter build with zero credentials, and publishes nothing.
2. **AppImage** (real) — validates the release-writing permission. **This publishes a public GitHub Release** (§3A), so treat it as a real release, not a rehearsal.
3. **Snap** — one secret, reversible (edge channel).
4. **Google Play** — five secrets, lands on a testing track.
5. **iOS**, then **macOS** — most credential surface; TestFlight is still testers-only.
6. **Microsoft Store** — last, because it is the only one that auto-publishes to the listing.

Once each target is green on its own, ship whole releases with **Deploy to all** (§5).

**Bump the version first** (§5) for **Play, iOS, macOS, and Microsoft** — each rejects a re-used build number. **Snap** doesn't require it. **AppImage** re-dispatched for a version already released replaces the AppImage on that Release only from the *same* commit; from any other commit its preflight fails (`v<version> already points at …`), because F-Droid builds the tag. **Deploy to all** refuses an already-released version outright.

**What success looks like**

| Target | Where the build lands | How to promote |
|---|---|---|
| AppImage | GitHub Release `v<version>`, marked prerelease | Uncheck "pre-release" on the Release |
| Snap | `edge` channel | `snapcraft release invoiceninja <rev> <channel>` — blocked for stable while `grade: devel` |
| Play | Open testing track (or the dispatched testing track) | Play Console: promote to production |
| iOS / macOS | TestFlight | App Store Connect: submit for review |
| Microsoft | Certification, then the live listing | Automatic — no promotion step |

**After a Flutter bump that changes desktop rendering, run the desktop builds on real machines before they ship.** CI only *builds* Windows and Linux; nothing runs them. Flutter 3.47 made Impeller the renderer on Windows (over ANGLE) and Linux (over OpenGL), with new text rendering. Launch a `flutter build windows` build on real Windows hardware before running `microsoft-store.yml` (or Deploy to all, which runs it), because Microsoft publishes straight to the listing after certification. Launch the AppImage or Snap on Linux before you promote it out of prerelease / `edge`. If either renders wrong, the per-platform opt-out is one line: `project.set_impeller_switch(flutter::ImpellerSwitch::Disabled)` in `windows/runner/main.cpp`, or `fl_dart_project_set_enable_impeller(project, FALSE)` in `linux/runner/my_application.cc`. Log it in `docs/upstream-workarounds.md` as MUST-REVERT, because Flutter says the Skia fallback will be removed. The same release made Impeller the default on macOS too. That one did ship broken: text was garbled on Intel Macs. macOS is opted out with `FLTEnableImpeller` = `false` in `macos/Runner/Info.plist` (`docs/upstream-workarounds.md` entry 16). Test the macOS build on an Intel Mac as well as Apple Silicon.

---

## 5. Per release

```sh
tools/bump_client_version.sh     # patch +1 and build +1, e.g. 5.1.6+9 → 5.1.7+10
git commit -am "Bump version"
tools/check_release_ready.sh     # the notes are written and the bump agrees everywhere
# then dispatch Deploy to all, or the individual workflows you want
```

`tools/check_release_ready.sh` is the gate **Deploy to all** runs first, so run it before dispatching. It fails, naming the fix, unless:

- `lib/domain/release_notes.dart` has a `kReleaseNotes` entry for the version, and the three F-Droid changelogs (`fastlane/metadata/android/en-US/changelogs/<build×10+1..3>.txt`) exist and match (`docs/release-notes.md` step 5);
- `kClientVersion`, `snap/snapcraft.yaml` and the F-Droid recipe all name pubspec's version (the bump script writes all of them);
- no `v<version>` tag exists on GitHub yet, and the version and build number are above the newest tag's.

`--offline` skips the two tag checks.

Don't dispatch the standalone **Deploy to GitHub Releases** while a Deploy to all is queued: both use the `appimage-release` concurrency group, which holds one running and one pending run, so a third run cancels the pending one, and with it every store.

The bump rewrites three files in lockstep — `lib/app/version.dart` (`kClientVersion`), `pubspec.yaml` (`version:`), and `snap/snapcraft.yaml` (display `version:`) — and `test/app/version_test.dart` asserts they stay in sync.

**The bump is mandatory** because Play, App Store Connect, and the Microsoft Store each reject a re-used build number:

| Store | Rejects on | Derived from |
|---|---|---|
| Play | `versionCode` already used | pubspec `+N` |
| App Store Connect | `CFBundleVersion` ≤ an existing build | pubspec `+N` |
| Microsoft Store | duplicate MSIX version | pubspec `version:` → `x.y.z.0` |

Two exceptions:

- **Snap** is revision-ordered — no bump needed to publish.
- **AppImage** keys off the display version. Re-dispatching the same version from the same commit replaces the AppImage on that Release; from any other commit preflight fails. Bump to cut a new one. **Deploy to all** needs the bump regardless.

---

## 6. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `ANDROID_KEYSTORE_BASE64 is empty — cannot produce a Play-signed bundle` | Secret not set. The workflow hard-fails deliberately: without it the build would silently fall back to **debug** signing, which Play rejects on upload. |
| `IOS_APPSTORE_PROVISIONING_PROFILE_BASE64 is empty` / same for macOS | Same deliberate guard. Set the secret. |
| `IOS_SHARE_EXTENSION_APPSTORE_PROVISIONING_PROFILE_BASE64 is empty` | The embedded Share Extension can't be signed without its own profile. §3E steps 1 and 3. |
| `IOS_HOME_WIDGETS_APPSTORE_PROVISIONING_PROFILE_BASE64 is empty` | The embedded home-screen widget extension can't be signed without its own profile. §3E steps 1 and 3. |
| `MACOS_HOME_WIDGETS_APPSTORE_PROVISIONING_PROFILE_BASE64 is empty` | The same, for the Mac widgets: a Mac App Store profile for `com.invoiceninja.admin.HomeWidgets`. §3E steps 1 and 3. |
| Portal: *"No Certificates are available"* while generating a profile | The team has only Xcode's Apple-managed distribution certificate, which the wizard can't use. Create an **Apple Distribution** (and, for macOS, **Mac Installer Distribution**) certificate from a CSR — §3E step 2. |
| macOS archive: *"…doesn't include the com.apple.security.application-groups entitlement"* | The Mac App Store profile for `com.invoiceninja.admin` (or the widgets') was minted before App Groups was on its App ID. Re-mint it after §3E step 1 and re-upload its secret. |
| Archive: *"…ShareExtension… requires a provisioning profile"* / *"doesn't match the bundle identifier"* / *"doesn't include the App Groups capability"* | The extension's profile is missing, named differently from `tools/ci_ios_target_profiles.rb`, or minted before App Groups was enabled on its App ID — re-issue it after §3E step 1. |
| Archive: *"Runner… doesn't include the com.apple.security.application-groups entitlement"* (iOS), or the macOS release failing after the Share Extension merged | The app's own profile predates App Groups on the shared `com.invoiceninja.admin` App ID, which invalidated it — regenerate the iOS **and** macOS App Store profiles and re-upload both secrets (§3E step 1). |
| Play: *"Version code N has already been used"* | You didn't bump. Run `tools/bump_client_version.sh`, commit, re-dispatch. |
| Play: *"Changes cannot be sent for review automatically. Please set … changesNotSentForReview to true"* | Account/app-state dependent. Add `changesNotSentForReview: true` under the publish step in `playstore.yml`. Leave it unset by default — some accounts get the inverse error when it *is* set. |
| ASC: *"the bundle version must be higher than the previously uploaded version"* | You didn't bump. iOS and macOS share the pubspec version. |
| Archive fails on an entitlement mismatch | The App ID is missing a capability the entitlements declare — Sign in with Apple (both), Associated Domains + App Groups (iOS), App Sandbox + Keychain Sharing (macOS). See §3E step 1. |
| macOS: package rejected by App Store Connect | The combined `.p12` is missing the **Mac Installer Distribution** identity. Re-export both identities together. |
| Apple upload auth fails | `APP_STORE_CONNECT_PRIVATE_KEY` was base64-encoded. It must be the **raw** `.p8` text. |
| Store: upload validation rejects the package | `msix_config` `identity_name` / `publisher` / `publisher_display_name` in `pubspec.yaml` don't exactly match Partner Center → Product identity. |
| `msstore publish` fails on `--appId` | You used the `9N…` Store ID. Use the ~12-char **Product ID** (`msstore apps list`). |
| Snap publish fails after months of working | `SNAPCRAFT_STORE_CREDENTIALS` expired. Re-run `snapcraft export-login`. |
| Snap installs but can't save / can't open its database | Not a CI problem — the user must run `snap connect invoiceninja:password-manager-service`. |
| Deploy to all: *"No release notes for X.Y.Z"* / *"Missing or empty F-Droid changelog(s)"* / *"changelogs … differ"* | The notes come before the bump: the `kReleaseNotes` entry and the three identical changelogs (`docs/release-notes.md` step 5). Commit them and re-dispatch. |
| Deploy to all: *"kClientVersion …"* / *"snap/snapcraft.yaml's version …"* / *"tools/foss/… names …"* / *"Build number N is not above …"* | A version was edited by hand. Reset it and run `tools/bump_client_version.sh`, which writes every one of them. |
| Deploy to all: *"vX.Y.Z is already released"* | That version shipped. To cut a new release, bump. To retry a store that failed in that release, open the original run and **Re-run failed jobs** (fix a secret or console setting first). A fix that needs a commit ships through that store's own workflow. |
| *"vX.Y.Z already points at <sha>, not <sha>"* (release preflight) | A tag for that version exists on another commit: you didn't bump. Under Deploy to all no store starts. |
| *"A draft Release for vX.Y.Z is left over from a failed run"* | Delete the draft on the Releases page and re-dispatch. |
| Deploy to all: the release is red and all five stores are skipped | Fix the release (an F-Droid verify mismatch: `docs/fdroid.md` § The reproducibility gate) and **Re-run failed jobs**, or dispatch the stores individually meanwhile (each then runs its own tests). |
| `fdroid-sign` refused by the `fdroid-signing` Environment | The run was dispatched on a branch other than `main`. Dispatch on `main`. |
| AppImage build is green but no Release appears | Either you dispatched with `publish` unchecked, or Settings → Actions → Workflow permissions is not **Read and write**. |

---

## 7. Beta → GA flips *(not required for setup)*

These are deliberate beta-posture settings, listed so they aren't mistaken for setup gaps. None of them blocks a dispatch. The full launch checklist, with each store's console step, is `docs/going-live.md`.

| Where | Current | At GA |
|---|---|---|
| `snap/snapcraft.yaml` | `grade: devel` | `grade: stable` — a `devel` snap *cannot* be released to stable/candidate. Blocked until the `password-manager-service` auto-connect issue is resolved. |
| `pubspec.yaml` `msix_config` | `display_name: Invoice Ninja - Beta` | Drop the ` - Beta` |
| `appimage.yml` | `prerelease: true` | Decide per release |
| `ios/Runner/Info.plist` | `CFBundleDisplayName = Ninja Beta`, `CFBundleName = admin` | `Invoice Ninja`. The beta installs beside the v1 app, whose home-screen label is "Invoice Ninja", and iOS truncates a label at about 12 characters — "Invoice Ninja Beta" would read "Invoice Ninj…" and look like the old app. The exported `.ipa` filename derives from this value, so `appstore-ios.yml` renames it before the upload. The v1 app's beta invitation names this label (`kBetaAppNameMobile` in admin-portal), so change the two together. |
| `android/app/src/main/AndroidManifest.xml` | `android:label="Ninja Beta"` | `Invoice Ninja` — same reason and same pairing as the iOS label. |

---

## See also

- `docs/setup.md` § Shipping to the stores — per-platform rationale, build mechanics, and the design decisions behind each pipeline.
- `tools/build_release.sh` — local release builds (not CI).
- `tools/build_appimage.sh` — the AppImage builder, also runnable locally on a Linux host.
