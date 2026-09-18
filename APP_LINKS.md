# App Links — the steps only a person can do

Shared record links (invoiceninja/flutter#144) are ordinary https URLs:

```
https://invoicing.co/app/invoices/rlNbW6Jayg?company=VolejRejNm        (hosted)
https://billing.example.com/app/invoices/rlNbW6Jayg?company=VolejRejNm (self-hosted)
```

Everything in the three repos is code. What is left is four things that live in
Apple's and Google's consoles, and they have to happen **in this order** —
two of them break something if taken early.

| | what | where | breaks if skipped |
|---|---|---|---|
| 1 | Enable Associated Domains | Apple Developer portal | iOS device builds stop signing |
| 2 | Collect the Android SHA-256 fingerprints | Play Console | `assetlinks.json` verifies nothing |
| 3 | Deploy the server | hosted | links keep opening in the browser |
| 4 | Release the apps | stores | — |

## The checklist

- [ ] **1a** Associated Domains ticked on App ID `com.invoiceninja.admin` (team `NPC44Y2C98`)
- [ ] **1b** Provisioning profiles refreshed — and the CI secret updated if it holds a manual one
- [ ] **1c** A device build signs and an archive completes
- [ ] **2a** SHA-256 of the Play **app signing** key copied from Play Console
- [ ] **2b** SHA-256 of the **upload** key copied too, so a locally-built release verifies
- [ ] **2c** Both set as `APP_LINKS_ANDROID_FINGERPRINTS` (comma-separated) or as the default in `config/ninja.php`
- [ ] **3a** Server deployed; both `.well-known` documents return **JSON**, not the SPA shell
- [ ] **3b** Google's and Apple's verifiers both resolve the domain
- [ ] **4a** Apps released; `pm get-app-links` reports `verified` on a device
- [ ] **4b** A link tapped from Messages/WhatsApp opens the app, and opens the record in the browser with the app uninstalled

Nothing here changes a store listing: no new permissions, no new privacy
declarations (see § Store submission notes at the bottom).

---

## 1. Apple — enable Associated Domains (before the entitlement merges)

`ios/Runner/Runner.entitlements` and `macos/Runner/Release.entitlements` now
declare `applinks:invoicing.co`. Xcode will not sign a build whose provisioning
profile lacks the matching capability, and iOS has a **single** entitlements file
for Debug and Release — so until this is done, `flutter run -d ios` on a physical
device fails too, not just the archive.

1. developer.apple.com → Certificates, Identifiers & Profiles → **Identifiers**
2. `com.invoiceninja.admin` (team `NPC44Y2C98`) → tick **Associated Domains** → Save
3. Repeat for the macOS App ID if it is a separate identifier
4. Refresh provisioning profiles. Automatic signing re-issues them on the next
   build; if the CI signing secret holds a **manual** profile, re-download it and
   update the secret (see `docs/store-deployment-setup.md`)

Confirm: a device build signs, and an archive completes.

## 2. Google — collect the signing fingerprints (before deploying the server)

`assetlinks.json` names the certificate an install must be signed with. The
wrong one — or none — fails verification **silently**: no error anywhere, links
just keep opening in the browser.

1. Play Console → your app → **Protected with Play** → the **Play Store
   protection / distribution** card → **Go to Play app signing**
2. Scroll to **App signing key** and copy its **SHA-256**. That is what users'
   installs are signed with when the app is enrolled in Play App Signing
3. Scroll on to **Upload key certificate** and copy that SHA-256 too, so a
   release you build and install locally verifies as well
4. Optionally add the debug key, if you want to test from a debug build:
   `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`

> Google moves this page. It was Release → Setup → App integrity, then
> Test and release → Setup → App integrity, and as of 2026 the signing keys
> live under **Protected with Play** while "App integrity" now means the Play
> Integrity API — a different thing that is not what you want here. If the
> names have moved again, the method below does not depend on them.

**The console-independent way, which is also the better check.** The console
tells you what Google *says* it signs with; the device tells you what an install
actually carries, which is what verification compares. On a phone that installed
the app from Play (an internal-test build counts):

```bash
adb shell pm path com.invoiceninja.admin          # note the base.apk line
adb pull /data/app/.../base.apk /tmp/in.apk
~/Library/Android/sdk/build-tools/35.0.0/apksigner verify --print-certs /tmp/in.apk
```

`apksigner` prints the digest as unbroken lowercase hex, and `assetlinks.json`
wants colon-separated pairs — this reformats it:

```bash
apksigner verify --print-certs /tmp/in.apk \
  | awk '/SHA-256 digest/ {print toupper($NF)}' \
  | sed 's/../&:/g; s/:$//'
```

(Use `apksigner`, not `keytool -printcert -jarfile`: modern Play APKs are signed
with scheme v2/v3 only, which `keytool` cannot read.)

If the app turns out **not** to be enrolled in Play App Signing, there is no app
signing key page at all, and the local keystore *is* the signing key:
`keytool -list -v -keystore android/app/key.jks -alias key`

> This repo records neither the fingerprint nor whether Play App Signing is
> enrolled. Write the answer down here once it is known.

Set them on the server as a comma-separated list — `APP_LINKS_ANDROID_FINGERPRINTS`
— or as the default in `config/ninja.php` (`ninja.app_links.android_fingerprints`).
Listing several is normal and expected.

## 3. Deploy the server (before releasing the apps)

Three routes ship in the backend: the two `.well-known` documents and the
`/app/{path}` bridge page. The bridge is what gives **self-hosted** installs an
app launch at all — their domain can never be verified, so the browser is the
only thing that can offer the native scheme.

Verify against the deployed host, checking the **body**, not the status code. A
200 proves nothing on its own: depending on how a host is configured an unknown
path comes back as an error page or as an SPA shell, both with a cheerful 200.
`app.invoicing.co` does exactly that today — both `.well-known` paths there
return `200 text/html` — which is how a missing file can look installed:

```bash
curl -s  https://invoicing.co/.well-known/assetlinks.json | head -c 80
curl -sI https://invoicing.co/.well-known/apple-app-site-association | grep -i content-type
```

Expect JSON and `application/json`, with no redirect (Apple's CDN does not
follow one).

Then the two verifiers:

```bash
# Google
curl -s 'https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://invoicing.co&relation=delegate_permission/common.handle_all_urls'

# Apple (populated within a day of the file going live)
curl -s https://app-site-association.cdn-apple.com/a/v1/invoicing.co
```

## 4. Release, then confirm on a device

```bash
adb shell pm get-app-links com.invoiceninja.admin        # expect: verified
adb shell am start -a android.intent.action.VIEW \
  -d "https://invoicing.co/app/invoices/<id>?company=<id>"
```

Then the two that matter more than the command output, because they are what a
recipient actually does:

- tap a link from **Messages or WhatsApp** (not from a browser address bar — see
  below) on a device with the app: it opens on the record;
- uninstall the app and tap the same link: it opens the record in the web client.

Anything short of that, work through § When verification fails — including the
two reasons a correct setup can still look broken by hand (an existing install
verifies only at install/update time, and some messengers open links in their own
in-app WebView).

---

## When verification fails

It fails **silently** — no error anywhere, links simply keep opening in the
browser — so work down this list in order. Each cause is checked with a command
rather than by inspection.

**The fingerprint is wrong.** By far the most common. An install from Play is
signed with Google's *app signing* key, not your upload key, so an
`assetlinks.json` listing only the upload key verifies nothing for real users
while a locally-built release verifies fine (and vice versa). List both. Compare
what the server publishes against what the device actually has:

```bash
curl -s https://invoicing.co/.well-known/assetlinks.json | python3 -m json.tool
adb shell pm get-app-links com.invoiceninja.admin        # shows the domain + state
```

The decisive comparison is against the installed APK rather than the console —
see § 2's `apksigner` recipe. If that digest is not in the published file, this
is your bug and nothing else here matters.

**The document isn't JSON.** Check the **body**, never the status code — a host
that answers unknown paths with an SPA shell returns a cheerful `200 text/html`:

```bash
curl -s https://invoicing.co/.well-known/assetlinks.json | head -c 40
curl -sI https://invoicing.co/.well-known/apple-app-site-association | grep -i 'content-type\|location'
```

Expect JSON and `application/json`. A `location:` header at all is a failure:
neither Google nor Apple follows a redirect to these.

**Apple is serving a cached copy.** Their CDN caches the association file for up
to about a day, and a device also caches what it fetched at install time:

```bash
curl -s https://app-site-association.cdn-apple.com/a/v1/invoicing.co
```

If that shows the old content, the fix is patience — which is why the
`components` scope wants to be right the first time.

**The device installed before the files went live.** Android verifies at
install/update time, so an existing install keeps its old answer:

```bash
adb shell pm verify-app-links --re-verify com.invoiceninja.admin
```

…or reinstall. A user can always override it by hand at Settings → Apps →
Invoice Ninja → **Open by default**.

**The app isn't enrolled in Play App Signing.** Then there is no "app signing
key certificate" page, and the local keystore *is* the signing key:

```bash
keytool -list -v -keystore android/app/key.jks -alias key
```

**It works on a device but not from a messenger.** Some Android apps open links
in their own in-app WebView, which bypasses App Links entirely; use their "Open
in browser" option. And on iOS a universal link tapped in Safari's address bar,
or followed from a page on the same domain, deliberately does not open the app —
test from Messages or Notes.

## Store submission notes

- **No App Store privacy change is needed** for the new `share_plus` dependency:
  it ships an empty `PrivacyInfo.xcprivacy` (no tracking domains, no accessed API
  types, no collected data types), and nothing else about the app's data handling
  changed.
- **No new Android permissions.** The App Links claim is an `<intent-filter>`,
  not a permission, and the share sheet uses `ACTION_SEND` through the plugin.
- **Play Console reports verification per release** once a build with the filter
  is live — look there as well as on a device, since it reflects what Google's
  crawler saw rather than what one handset cached.
- The claim is scoped to `/app/*` on one host, so it does not affect any other
  link on `invoicing.co` — the client portal and payment pages keep opening in
  the browser.

## What still won't work, and why

- **Self-hosted domains are never verified.** Android and Apple both need the
  host as a build-time literal in the app; a per-instance one cannot be. Those
  links go through the bridge page instead, which is **automatic on Android** —
  it hands Chrome an `intent://` URL that resolves to the app when installed and
  to the web client when not — and **one tap on iOS**, where firing a custom
  scheme without a tap risks an error page instead of a fallback. A desktop
  browser never sees the page: it is sent straight to the web client, so a
  self-hosted macOS or Windows user with the app installed is the one case that
  loses the offer (a hosted link is claimed by macOS before the browser is
  involved, and Windows has no verified-link mechanism either way).
- **`staging.invoicing.co` and `demo.invoiceninja.com` are not claimed**, so
  links copied from a staging or demo session take the bridge path. Worth
  knowing before testing there.
- **Notification emails are app links now.** The server emits
  `https://<instance>/app/<route>?company=<id>` wherever it used to hand out a
  React URL or a bare app root, so they open the app when it is installed and
  fall through the bridge when it is not.
- **Windows, Linux and web have no verified-link mechanism.** The links are
  ordinary URLs there: the browser opens, and the bridge hands them to the web
  client (Windows MSIX installs still register the custom scheme, so a pasted
  `invoiceninja://` link still resolves). The **web build** does follow one it is
  loaded with, including its `?company=` — see `docs/deep-links.md` § On web the
  link is the page URL.

## Where the pieces live

| Piece | Repo | File |
|---|---|---|
| Link building, parsing, the claimed host | this | `lib/app/entity_links.dart` |
| Android claim + Flutter's own deep linking off | this | `android/app/src/main/AndroidManifest.xml` |
| Apple claim | this | `ios/Runner/Runner.entitlements`, `macos/Runner/Release.entitlements` |
| Cold-start / macOS shims for `app_links` | this | `ios/Runner/SceneDelegate.swift`, `macos/Runner/AppDelegate.swift` |
| Wiring guard | this | `test/lint/universal_links_test.dart` |
| `.well-known` documents + bridge page | backend | `app/Http/Controllers/AppLinksController.php` |
| App route → web route translation | backend | `app/Utils/AppLinkPath.php` |
| Which web client the bridge falls back to | backend | `AppLink::flutterWebClient()` (`accounts.set_react_as_default_ap`) |
| Server-generated record links | backend | `app/Utils/AppLink.php` |
| `?company=` workspace selection | React client | `src/common/helpers/company-index.ts` |
| `?company=` on the web build | this | `DeepLinkRouter.openWebInitialLocation` |
