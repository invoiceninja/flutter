# Store deployment — setup runbook

**How to get the six publish workflows working from zero.** This is the *how*; `docs/setup.md` §§ Shipping to the stores → Windows / Microsoft Store is the *why* (rationale, design decisions, per-platform background). Read a section here to act; follow the cross-reference when you want to know why it's built that way.

Nothing in this guide requires editing a workflow. They are complete as written — what's missing is credentials.

---

## 0. Start here

Six workflows publish the app. Every one of them:

- is **manual only** — GitHub → **Actions** → pick the workflow → **Run workflow** (on the default branch). There is no push, tag, or schedule trigger anywhere in this repo.
- **runs the full test suite first** (`_test.yaml`, always on `ubuntu-latest`, ~8–12 min). A red suite stops the release before anything is built or uploaded.
- ships to a **testing channel**, not straight to users — with **two exceptions**. **Microsoft Store** auto-commits to certification and goes live on the listing with no manual gate (§3D). **AppImage** attaches its build to a **public GitHub Release** — this is a public repo, so it is downloadable by anyone the moment it is created; `prerelease: true` only keeps it off the "Latest" badge, it restricts nothing (§3A).

| Target | Workflow | Lands in | Store credentials |
|---|---|---|---|
| Linux AppImage | `appimage.yml` | GitHub Release (prerelease) | **none** — a repo setting instead |
| Linux Snap | `snapcraft.yml` | Snap Store `edge` | 1 |
| Android | `playstore.yml` | Play **Internal testing** | 5 |
| Windows | `microsoft-store.yml` | Store certification → live listing | 5 |
| iOS | `appstore-ios.yml` | TestFlight | 6 |
| macOS | `appstore-macos.yml` | TestFlight | 6 (3 shared with iOS) |

All six additionally read `IN_SENTRY_DSN`, which is optional — 21 secret names in total. `ci.yaml` and `_test.yaml` use **no secrets at all**, so nothing in this guide affects them.

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

The Play, Partner Center, and Snap Store **listings already exist** — you are wiring credentials to existing apps, not creating new ones. That matters for Google Play in particular: a brand-new package requires one manual bundle upload in the Console before the API will accept anything, and that is already satisfied here. **Confirm the Apple side yourself** — the iOS and macOS app records must exist on App Store Connect (§3E step 5); unlike Play, ASC then accepts the very first build over the API with no prior manual upload.

---

## 2. Master secret table

All 21, grouped by what they unlock. `IN_SENTRY_DSN` is the only cross-cutting one.

### Shared

| Secret | Used by | What it is | How to produce it |
|---|---|---|---|
| `IN_SENTRY_DSN` | all 6 | Sentry DSN, baked in at compile time via `--dart-define` | Copy from the Sentry project settings. Safe to leave unset. |

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

### Windows — `microsoft-store.yml`

| Secret | What it is | How to produce it |
|---|---|---|
| `PARTNER_CENTER_TENANT_ID` | Entra directory (tenant) ID | Entra admin center → app registration → Overview |
| `PARTNER_CENTER_CLIENT_ID` | Entra application (client) ID | Same page |
| `PARTNER_CENTER_CLIENT_SECRET` | Entra client secret **value** | Certificates & secrets → New client secret. The *value* is shown once. |
| `PARTNER_CENTER_SELLER_ID` | Partner Center Seller ID | Partner Center account settings. **Not** the `9N…` Store ID. |
| `MS_STORE_PRODUCT_ID` | Partner Center **Product ID** (~12 chars) | App Overview page, or `msstore apps list`. **Not** the `9N…` Store ID. |

### Apple — shared by `appstore-ios.yml` and `appstore-macos.yml`

| Secret | What it is | How to produce it |
|---|---|---|
| `APP_STORE_CONNECT_ISSUER_ID` | ASC API issuer UUID | App Store Connect → Users and Access → Integrations |
| `APP_STORE_CONNECT_KEY_ID` | ASC API key ID | Same page |
| `APP_STORE_CONNECT_PRIVATE_KEY` | The `.p8` private key, **raw text — NOT base64** | `gh secret set APP_STORE_CONNECT_PRIVATE_KEY < AuthKey_<KEYID>.p8` |

### Apple — iOS only

| Secret | What it is | How to produce it |
|---|---|---|
| `APPLE_DISTRIBUTION_CERT_P12_BASE64` | Apple Distribution cert + private key | `base64 -i dist.p12` |
| `APPLE_DISTRIBUTION_CERT_PASSWORD` | The `.p12` export password | Whatever you set on export |
| `IOS_APPSTORE_PROVISIONING_PROFILE_BASE64` | iOS App Store profile | `base64 -i profile.mobileprovision` |

### Apple — macOS only

| Secret | What it is | How to produce it |
|---|---|---|
| `MAC_DISTRIBUTION_CERTS_P12_BASE64` | **One combined `.p12`** with **both** Mac distribution identities | `base64 -i certs.p12` — see §3E for why it must be combined |
| `MAC_DISTRIBUTION_CERTS_PASSWORD` | That `.p12`'s export password | Whatever you set on export |
| `MACOS_APPSTORE_PROVISIONING_PROFILE_BASE64` | Mac App Store profile (distinct from the iOS one) | `base64 -i profile.provisionprofile` |

---

## 3. Per-store setup

Ordered easiest → hardest. Working in this order means you validate the pipeline before spending time on certificates.

### A. AppImage — no store credentials *(do this first)*

The only workflow that needs no store credential — it still reads the optional `IN_SENTRY_DSN`, but authenticates with the built-in `GITHUB_TOKEN`. It's also the one workflow that writes back to the repo (it creates the `v<version>` tag and GitHub Release), so what it needs is a repo *setting* rather than a secret.

> **The release it creates is public.** `invoiceninja/flutter` is a public repo, so the attached AppImage is downloadable by anyone as soon as the release exists. `prerelease: true` only keeps it off the "Latest release" badge — it is not an access control. Use the dry run below for validation; a real dispatch is a real release.

**One-time setup**

1. Settings → Actions → General → **Workflow permissions** → **Read and write permissions**. Without it, `action-gh-release` fails at the very end, after a full build.
2. Nothing else. GitHub Releases need no enabling.

**Verify** — dispatch `Deploy to GitHub Releases` with the **`publish` checkbox unchecked**. That's a build-only dry run: it still runs the test gate, builds the AppImage, smoke-checks it, and uploads it as a run artifact — but creates no tag and no Release. Download the artifact from the run summary to confirm.

This single dry run exercises checkout → test gate → Flutter build → packaging → artifact upload. If it's green, the shared half of every other workflow is known good.

> A `v*` tag-protection rule or repository ruleset would block this workflow. If the release step fails on the tag rather than the upload, check Settings → Rules.

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

**Verify** — dispatch `Deploy to Google Play`. Success lands a release on the **Internal testing** track. Promote internal → closed → production by hand in the Console.

### D. Windows / Microsoft Store — 5 secrets

> **This is the only pipeline with no manual gate.** A dispatch uploads *and commits* the submission: it enters Store certification automatically and goes live on the listing once certified. There is no `edge` / `internal` / TestFlight equivalent. If you want a gate, add `--noCommit` to the publish step in `microsoft-store.yml` (leaves it a draft you publish in Partner Center) or target a package flight with `-f <flightId>`.

**One-time setup**

1. Associate a **Microsoft Entra tenant** with your Partner Center account (Partner Center → Account settings → Tenants).
2. Entra admin center → **App registrations** → New registration. Record the **Directory (tenant) ID** and **Application (client) ID**.
3. That app → **Certificates & secrets** → **New client secret**. Copy the **Value** immediately — it is shown once and cannot be retrieved later.
4. Partner Center → **User management** → **Microsoft Entra applications** → add the app you registered with the **Manager** role.
5. Record the **Seller ID** (Partner Center account settings) and the app's **Product ID** (app Overview page).

**Two ID traps** — both fail confusingly if you get them wrong:

- `PARTNER_CENTER_SELLER_ID` is the Partner Center **Seller ID**, *not* the `9N…` Store ID.
- `MS_STORE_PRODUCT_ID` is the ~12-character **Product ID**, *also* not the `9N…` Store ID from the `apps.microsoft.com/detail/...` URL. Run `msstore apps list` to print the correct value.

**Check the package identity matches Partner Center.** The `msix_config` block in `pubspec.yaml` must exactly match Partner Center → Product identity, or upload validation rejects the package:

```yaml
identity_name: InvoiceNinja.AdminPortal
publisher: CN=2B7AA393-06A0-46F5-AF85-1917142440C3
publisher_display_name: Invoice Ninja
```

**Verify** — dispatch `Deploy to Microsoft Store`. Success means the submission is committed; certification typically takes hours. Watch it in Partner Center.

### E. Apple — iOS + macOS, 9 secrets

The hardest of the six, and the one where order matters: **App ID capabilities → certificates → provisioning profiles → API key**. A profile is minted against the capabilities and certificates that exist *at that moment*, so doing this out of order means re-issuing profiles.

#### Step 1 — App ID capabilities

The App ID for `com.invoiceninja.admin` must have the capabilities the entitlements files declare, or `xcodebuild archive` fails on a mismatch:

| Target | Required capabilities | Declared in |
|---|---|---|
| iOS | **Sign in with Apple** | `ios/Runner/Runner.entitlements` |
| macOS | **Sign in with Apple**, **App Sandbox**, **Keychain Sharing** | `macos/Runner/Release.entitlements` |

#### Step 2 — Certificates

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

Create **two** App Store profiles for `com.invoiceninja.admin` — one **iOS App Store**, one **Mac App Store** — each embedding the certificate from step 2.

```sh
base64 -i profile.mobileprovision  | gh secret set IOS_APPSTORE_PROVISIONING_PROFILE_BASE64
base64 -i profile.provisionprofile | gh secret set MACOS_APPSTORE_PROVISIONING_PROFILE_BASE64
```

**The profile names must match what's committed.** The workflows and export options reference profiles by name:

| File / setting | Expects |
|---|---|
| `ios/ExportOptions.plist` | `Invoice Ninja Admin App Store` |
| `macos/ExportOptions.plist` | `Invoice Ninja macOS App Store` |
| `appstore-macos.yml` `PROVISIONING_PROFILE_SPECIFIER` | `Invoice Ninja macOS App Store` |
| `appstore-ios.yml` `PROVISIONING_PROFILE_SPECIFIER` | `Invoice Ninja Admin App Store` |

Name the profiles exactly that in the portal, **or** edit those four places to match the names you used.

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

> Your local Xcode projects are untouched by any of this. Both still use Automatic signing with an Apple Development identity; CI forces manual signing via `xcodebuild` command-line overrides, so local development keeps working.

---

## 4. First dispatch

Run them in this order — cheapest failure first:

1. **AppImage** (dry run, `publish: false`) — validates checkout, the test gate, and the Flutter build with zero credentials, and publishes nothing.
2. **AppImage** (real) — validates the release-writing permission. **This publishes a public GitHub Release** (§3A), so treat it as a real release, not a rehearsal.
3. **Snap** — one secret, reversible (edge channel).
4. **Google Play** — five secrets, lands on a testing track.
5. **iOS**, then **macOS** — most credential surface; TestFlight is still testers-only.
6. **Microsoft Store** — last, because it is the only one that auto-publishes to the listing.

**Bump the version first** (§5) for **Play, iOS, macOS, and Microsoft** — each rejects a re-used build number. **Snap** and **AppImage** don't require it, but know what skipping it means for AppImage: it re-uses the existing `v<version>` tag and *replaces the asset on that release* rather than cutting a new one.

**What success looks like**

| Target | Where the build lands | How to promote |
|---|---|---|
| AppImage | GitHub Release `v<version>`, marked prerelease | Uncheck "pre-release" on the Release |
| Snap | `edge` channel | `snapcraft release invoiceninja <rev> <channel>` — blocked for stable while `grade: devel` |
| Play | Internal testing track | Play Console: internal → closed → production |
| iOS / macOS | TestFlight | App Store Connect: submit for review |
| Microsoft | Certification, then the live listing | Automatic — no promotion step |

---

## 5. Per release

```sh
tools/bump_client_version.sh     # patch +1 and build +1, e.g. 5.1.6+9 → 5.1.7+10
git commit -am "Bump version"
# then dispatch the workflows you want
```

The bump rewrites three files in lockstep — `lib/app/version.dart` (`kClientVersion`), `pubspec.yaml` (`version:`), and `snap/snapcraft.yaml` (display `version:`) — and `test/app/version_test.dart` asserts they stay in sync.

**The bump is mandatory** because Play, App Store Connect, and the Microsoft Store each reject a re-used build number:

| Store | Rejects on | Derived from |
|---|---|---|
| Play | `versionCode` already used | pubspec `+N` |
| App Store Connect | `CFBundleVersion` ≤ an existing build | pubspec `+N` |
| Microsoft Store | duplicate MSIX version | pubspec `version:` → `x.y.z.0` |

Two exceptions:

- **Snap** is revision-ordered — no bump needed to publish.
- **AppImage** keys off the display version, so re-dispatching the same version *updates* that Release in place and replaces the asset. Bump to cut a new one.

---

## 6. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `ANDROID_KEYSTORE_BASE64 is empty — cannot produce a Play-signed bundle` | Secret not set. The workflow hard-fails deliberately: without it the build would silently fall back to **debug** signing, which Play rejects on upload. |
| `IOS_APPSTORE_PROVISIONING_PROFILE_BASE64 is empty` / same for macOS | Same deliberate guard. Set the secret. |
| Play: *"Version code N has already been used"* | You didn't bump. Run `tools/bump_client_version.sh`, commit, re-dispatch. |
| Play: *"Changes cannot be sent for review automatically. Please set … changesNotSentForReview to true"* | Account/app-state dependent. Add `changesNotSentForReview: true` under the publish step in `playstore.yml`. Leave it unset by default — some accounts get the inverse error when it *is* set. |
| ASC: *"the bundle version must be higher than the previously uploaded version"* | You didn't bump. iOS and macOS share the pubspec version. |
| Archive fails on an entitlement mismatch | The App ID is missing a capability the entitlements declare — Sign in with Apple (both), App Sandbox + Keychain Sharing (macOS). See §3E step 1. |
| macOS: package rejected by App Store Connect | The combined `.p12` is missing the **Mac Installer Distribution** identity. Re-export both identities together. |
| Apple upload auth fails | `APP_STORE_CONNECT_PRIVATE_KEY` was base64-encoded. It must be the **raw** `.p8` text. |
| Store: upload validation rejects the package | `msix_config` `identity_name` / `publisher` / `publisher_display_name` in `pubspec.yaml` don't exactly match Partner Center → Product identity. |
| `msstore publish` fails on `--appId` | You used the `9N…` Store ID. Use the ~12-char **Product ID** (`msstore apps list`). |
| Snap publish fails after months of working | `SNAPCRAFT_STORE_CREDENTIALS` expired. Re-run `snapcraft export-login`. |
| Snap installs but can't save / can't open its database | Not a CI problem — the user must run `snap connect invoiceninja:password-manager-service`. |
| AppImage build is green but no Release appears | Either you dispatched with `publish` unchecked, or Settings → Actions → Workflow permissions is not **Read and write**. |

---

## 7. Beta → GA flips *(not required for setup)*

These are deliberate beta-posture settings, listed so they aren't mistaken for setup gaps. None of them blocks a dispatch.

| Where | Current | At GA |
|---|---|---|
| `snap/snapcraft.yaml` | `grade: devel` | `grade: stable` — a `devel` snap *cannot* be released to stable/candidate. Blocked until the `password-manager-service` auto-connect issue is resolved. |
| `pubspec.yaml` `msix_config` | `display_name: Invoice Ninja - Beta` | Drop the ` - Beta` |
| `appimage.yml` | `prerelease: true` | Decide per release |
| `ios/Runner/Info.plist` | `CFBundleDisplayName = Admin`, `CFBundleName = admin` | Worth confirming this is intentional — every other platform shows "Invoice Ninja", and the exported `.ipa` filename derives from `CFBundleDisplayName`. |

---

## See also

- `docs/setup.md` § Shipping to the stores — per-platform rationale, build mechanics, and the design decisions behind each pipeline.
- `tools/build_release.sh` — local release builds (not CI).
- `tools/build_appimage.sh` — the AppImage builder, also runnable locally on a Linux host.
