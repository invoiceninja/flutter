# The F-Droid (FOSS) build

Companion to CLAUDE.md § Strict rules. This doc covers how the F-Droid build differs from the store
build, why each difference exists, the recipe F-Droid runs, and how the APK F-Droid publishes is
built, signed and checked (invoiceninja/flutter#175).

F-Droid builds the app from source on its own servers. It rejects proprietary code (Play
Services, Play Billing) and prebuilt binaries. The store build contains both, so the F-Droid
build is a *variant*. **Everything that differs is produced by one script,
`tools/prepare_foss.sh`, and no file in `lib/` has a twin.**

F-Droid then publishes **our** signed APK rather than one signed with its own key, but only after
its own rebuild matches ours byte for byte. That second half — the recipe, the build, signing, and
the check — is `tools/foss/com.invoiceninja.admin.yml` plus `tools/fdroid_build.sh`, run by
`.github/workflows/appimage.yml` ("Deploy to GitHub Releases").

## Store SDKs are imported only from packages/store_services

**Rule: the non-free SDKs (Google Sign-In, in-app purchase, Sentry) are imported only from
`packages/store_services`. The app imports that package's own API
(`package:store_services/store_services.dart`), never an SDK.** Enforced by
`test/lint/store_sdk_boundary_test.dart`.

- `packages/store_services`: the real SDKs, behind a narrow API with no SDK types in it:
  - `GoogleSignInClient`, wrapped by `lib/data/services/google_oauth.dart`
  - `StoreBilling`, used by `PurchaseService`
  - `runWithCrashReporting`, called from `main.dart`
- `packages/store_services_foss`: the **same package name**, the same declarations, and inert
  stubs:
  - `GoogleSignInClient.isSupported` is false, so the login and Connect screens hide their Google
    buttons.
  - `StoreBilling.isAvailable` is false, so `showUpgradeSheet` falls back to the web portal. That
    fallback already existed for a Play device whose billing is down.
  - `runWithCrashReporting` just runs the app.

  Its pubspec depends on nothing but Flutter, and the lint test keeps it that way.

`tools/prepare_foss.sh` swaps one package for the other with a root `pubspec_overrides.yaml`,
which pub reads natively. No import changes.

### Why a package, not conditional imports or a dart-define

Two facts force the non-free packages out of the dependency graph entirely:

- Dart's conditional imports key only on `dart.library.*`, not on a user flag.
- A plugin anywhere in the graph is compiled into the APK through `GeneratedPluginRegistrant`,
  even if tree-shaking removes every line of its Dart code.

A path package is the smallest unit pub can swap.

### Why not the old whole-file copies

admin-portal kept `pubspec.foss.yaml`, `AndroidManifest.foss.xml`, `settings.gradle.foss.kts`
and four `*.dart.foss` files, and `cp`-ed them over the real ones. Nothing built that variant
until release day, so the copies drifted. By 2026-09 the FOSS pubspec was on an older SDK floor
and older versions, and the FOSS manifest had lost `${applicationName}`, `taskAffinity` and the
`PROCESS_TEXT` query. Here the only copied file is the overrides file, and the lint test pins it
to `pubspec.yaml`.

This app needs **no manifest or Gradle variant**. The manifest carries no Google meta-data, and
there is no google-services plugin.

### What is non-free, and why

Measured by scanning every Android plugin's `build.gradle` (2026-09):

| Package | Android artifact | Why it goes |
|---|---|---|
| `google_sign_in` | `play-services-auth`, `googleid`, `credentials-play-services-auth` | Play Services |
| `in_app_purchase` | `com.android.billingclient:billing` | Play Billing |
| `in_app_purchase_storekit` | none (iOS only) | rides with `in_app_purchase` |
| `sentry_flutter` | sentry-android (MIT) | Free, but F-Droid tags it with the *Tracking* anti-feature, and it is inert anyway without the `IN_SENTRY_DSN` define |

Everything else is androidx, Kotlin, Tink (`flutter_secure_storage`) or Apache Tika
(`file_picker`). `jni` was pulled in only by Sentry. After the swap, `pub get` reports 13
packages no longer depended on, and `prepare_foss.sh` fails if any of them is still in
`pubspec.lock`.

**Adding a new store-only SDK**:

1. Depend on it from `packages/store_services`.
2. Expose it through a plain API there.
3. Add the same declarations, as stubs, to `packages/store_services_foss`.
4. Call it from `lib/` through `package:store_services`.

The lint test compares the two packages' public declarations. CI's `build-android-foss` job
compiles the app against the twin.

**What runs when.**
- `build-android-foss` is in `ci.yaml`, which runs only when CI is dispatched. It builds the
  variant natively, as a quick compile gate.
- Every release workflow calls `_test.yaml`, so every release runs the boundary lint test and
  `test/lint/fdroid_recipe_test.dart`.
- "Deploy to GitHub Releases" builds the real F-Droid APKs, with F-Droid's tooling, and checks
  them before it tags the version — § The F-Droid APK is built by F-Droid's own tooling.

## The overrides file replaces pubspec.yaml's dependency_overrides

**Rule: `tools/foss/pubspec_overrides.yaml` must repeat every entry of `pubspec.yaml`'s
`dependency_overrides`, verbatim.** Pub gives a root `pubspec_overrides.yaml` precedence: it
*replaces* the pubspec's `dependency_overrides` instead of merging with them
([dart.dev](https://dart.dev/tools/pub/dependencies)). Without the copies, the FOSS build would
silently lose `isolate_manager` (the wasm fix) and the pinned `super_editor` fork. The last test
in `store_sdk_boundary_test.dart` fails if the two drift.

Never commit a root `pubspec_overrides.yaml`. It is gitignored because in the store tree it would
swap in the FOSS twin without anyone noticing.

## SQLite is compiled from source

**Rule: the FOSS build compiles SQLite3MultipleCiphers from the pinned amalgamation. It never
downloads the prebuilt `libsqlite3mc.so`.**

- **The problem.** `package:sqlite3`'s build hook, as configured for the store
  (`hooks.user_defines.sqlite3.source: sqlite3mc`), downloads a precompiled library from the
  sqlite3.dart GitHub release (`hook/build.dart` → `PrecompiledBinary`). F-Droid forbids
  prebuilt binaries.
- **The fix.** The hook's `source: source` mode compiles a given C file with the NDK's clang.
  `prepare_foss.sh` fetches the sqlite3mc amalgamation into `native/sqlite3mc/` (gitignored),
  checks the sha256 of the zip, the `.c` and the `.h`, and rewrites the hook block to
  `source: source` + `path:`.
- **Why it edits `pubspec.yaml`.** Hook user-defines can only live in the root pubspec, not in
  `pubspec_overrides.yaml` ([dart.dev](https://dart.dev/tools/hooks)).
- **Same configuration as the store build.** Upstream builds its prebuilt binaries with this exact
  hook and defines: `tool/build_sqlite.dart` at the `sqlite3-3.3.2` tag runs `hook.main` with
  `source: source` and the default defines. So a from-source build is the same configuration the
  store APK downloads, not a lookalike. The cipher pragmas in `database_opener_io.dart`
  (`cipher = 'sqlcipher'`, `legacy = 4`) work unchanged.
- **Why fetch it rather than vendor it.** The amalgamation is 13 MB. `prepare_foss.sh` runs in
  F-Droid's `prebuild`, beside the `flutter pub get` that needs the network anyway, and the hashes
  pin exactly what it compiles. Another Flutter app on F-Droid vendors it instead
  ([cycle-app#11](https://github.com/BenediktBurger/cycle-app/pull/11)). If F-Droid's reviewers
  ask for that, commit the two files at the pinned hashes and drop the download step.
- **The CI check.** `build-android-foss` checks that every `libsqlite3.so` in the APK hashes to
  something *other* than the prebuilt `assetNameToSha256Hash` values in the resolved package's
  `lib/src/hook/asset_hashes.dart`. So a silently-downloaded binary fails the job.
- **Which compiler, and why the recipe names it.** Gradle's `ndkVersion` does not choose the
  compiler for a build hook. Flutter hands the hook the clang of the **newest** NDK under
  `$ANDROID_HOME/ndk/`, unless `ANDROID_NDK_HOME`, `ANDROID_NDK_PATH` or `ANDROID_NDK_ROOT` is set
  (`flutter_tools/lib/src/android/android_sdk.dart` `getNdkBinaryPath`, called from
  `isolated/native_assets/android/native_assets.dart`). A buildserver carrying a second NDK would
  therefore compile a different `libsqlite3.so`. Every recipe `build:` block exports
  `ANDROID_NDK_HOME=$$NDK$$` (the NDK it asked F-Droid for), and the lint test pins that.
- **What the library embeds.** Measured on a 3.44.1 arm64 build: no path strings and no
  build-ID note. Its `.comment` section holds only the clang version, which is the same on both
  sides because both build on Linux in the same image. (Built on a macOS host, that string
  differs from the Linux NDK's, per F-Droid's notes.)

### Bumping sqlite3mc

When `sqlite3` moves, read `tool/download_sqlite.dart` at the new `sqlite3-<version>` tag of
simolus3/sqlite3.dart. Copy its `sqliteMultipleCiphersSource` URL into `SQLITE3MC_URL`, then
update the three sha256 values in `prepare_foss.sh` (zip, `.c`, `.h`). Also update the `SQLITE3MC_*` pins mentioned in
`docs/setup.md` § Dependency updates.

## Building it

Run it in a throwaway worktree, never in the shared checkout. The script rewrites `pubspec.yaml`
and `pubspec.lock`, and its `pub get` regenerates the tracked plugin registrants and SwiftPM pins.

```sh
tools/prepare_foss.sh                # FLUTTER=/path/to/flutter if not on PATH
flutter build apk --release
tools/prepare_foss.sh --restore      # back to the store build, byte-for-byte
```

**`--restore` restores a snapshot; it does not re-resolve.** Before it touches anything, `prepare`
tars every tracked file it can change into `.dart_tool/foss_store_backup.tar`. Re-resolving is
not enough: once the store SDKs have left `pubspec.lock`, a fresh `pub get` picks *newer* versions
of them. Measured: `google_sign_in_android` went from 7.2.11 to 7.2.17 and Sentry from 9.21 to
9.30, and the macOS registrant changed with them. Restore also lays the snapshot down again
*after* its own `pub get`, because that `pub get` deletes the iOS `Package.resolved` when the
plugin set changes.

Two guards keep the snapshot honest:

- **The snapshot is retaken on every `prepare` from the store build.** An old one could predate a
  pull or a hand-restore, and restoring it would revert those changes. Only a re-run on an
  already-prepared tree keeps the existing snapshot.
- **`--restore` refuses if `pubspec.yaml` changed since `prepare`,** beyond the script's own hook
  edit, and prints the diff. `--restore --force` discards the change.

Pass no dart-defines, so there is no Sentry DSN and no Google client ID. Analyse with
`flutter analyze lib test packages/store_services_foss`. A whole-repo analyze also visits
`packages/store_services`, whose SDKs are, correctly, no longer resolved.

That local build is a compile check. The APK F-Droid publishes is built differently — split per
ABI, at a fixed path, by F-Droid's own tooling — § The F-Droid APK is built by F-Droid's own
tooling.

## The FOSS lock is a subset of the store lock

**Rule: after its `pub get`, `prepare_foss.sh` fails unless every package the FOSS graph resolves is
in the store build's `pubspec.lock`, at the same version and the same content pin.**

- **Why not `--enforce-lockfile`.** fdroiddata's Flutter template uses it, but it can't run here:
  the swap has to rewrite the lock. Dropping the store SDKs removes 13 packages, and
  `store_services` points somewhere else.
- **What is compared.** One `name source version pin` line per package. The pin is `sha256` for
  a hosted package and `resolved-ref` for a git one (`super_editor`).
  - Path packages are skipped, because swapping `store_services` is the point.
  - `dependency:` is ignored, because dropping the SDKs legitimately turns some `direct`
    entries into `transitive` ones and back.
- **Against what.** The snapshot `prepare` takes before it changes anything
  (`.dart_tool/foss_store_backup.tar`), which is the committed store lock.
- **Why it matters.** Pub checks every download against its locked `sha256`. So F-Droid's build
  resolves exactly the code the store build was tested with, which is also the precondition for
  F-Droid and us resolving the *same* code.
- **Measured** (2026-10-15): 238 pins, every one present in the store lock, and 13 store-only
  packages dropped. Changing one version on the store side makes the check name that package.

## The F-Droid APK is built by F-Droid's own tooling

**Rule: the F-Droid APK is built only by `fdroid build` running `tools/foss/com.invoiceninja.admin.yml`
in F-Droid's digest-pinned image, signed only by the F-Droid key, and published only after a varied
rebuild matches it.**

**How F-Droid decides.** A recipe that names `binary:` and `AllowedAPKSigningKeys` asks F-Droid to
publish the developer's APK instead of its own. F-Droid then:
1. builds the recipe itself, unsigned;
2. downloads our APK and copies its v2/v3 signature onto its own build (`apksigcopier`);
3. publishes our APK only if that verifies, which means the two are identical apart from the
   signing block.

Otherwise it skips that version ([Reproducible Builds](https://f-droid.org/docs/Reproducible_Builds/)).
So the bytes we sign must be the bytes that F-Droid's recipe produces on F-Droid's machine.

**What makes a Flutter build machine-dependent**, measured on this app's arm64 build (2026-10-15):

- **The build path.** `libapp.so` embeds
  `file://<project>/.dart_tool/flutter_build/dart_plugin_registrant.dart`.
  - Two builds of one commit at different paths differed in exactly one of 522 entries:
    `lib/arm64-v8a/libapp.so`.
  - Two builds at the same path, the second after `flutter clean`, matched byte for byte apart
    from the signing block, which is exactly F-Droid's test. The second was debug-signed by
    accident; with its APK Signing Block cut out, its SHA-256 equalled the first's.
  - So `prebuild` and `build` both move the source to `/build/com.invoiceninja.admin` and keep
    `PUB_CACHE` inside it. This is the move-and-move-back pattern of fdroiddata's
    `templates/build-flutter.yml`, and `docs/upstream-workarounds.md` § 13 tracks it.
- **The toolchain.**
  - The JDK's major version changes the DEX, so the recipe's `sudo:` installs JDK 21 and selects
    it, with the same `update-alternatives` line fdroiddata's CI uses.
  - The NDK compiles `libsqlite3.so`, so the recipe names it, and the build pins
    `ANDROID_NDK_HOME` (§ SQLite is compiled from source).
- **What F-Droid does to a source tree:** `remove_signing_keys`, `rm:`, `scandelete:`, the
  scanner. These are run, not re-imitated.

**What `tools/fdroid_build.sh build <abi>` does:**
1. **Sets up the scratch tree.** It works in `registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie`,
   pinned by digest; that is the image fdroiddata's own CI builds recipes in. It clones
   fdroidserver, plus fdroiddata's `config/` and flutter srclib, at pinned commits, into a scratch
   fdroiddata tree at `/home/vagrant` (the production layout).
2. **Lints.** It runs `fdroid lint` and `fdroid rewritemeta` on the recipe as committed. Those are
   the checks a fdroiddata merge request runs, so a recipe that would fail review fails here first.
3. **Rewrites the ABI's block** to this version and commit, which is exactly what F-Droid's
   checkupdates bot will do once the tag exists. It drops `binary:` and `AllowedAPKSigningKeys`,
   because those are publish-time checks against an APK that doesn't exist yet.
4. **Builds.** It runs `fdroid fetchsrclibs`, then `fdroid build --on-server --test`, invoked as
   fdroiddata CI's `fdroid build` job does: as `vagrant`, via sudo. Sudo is uninstalled after the
   recipe's `sudo:` block.
5. **Writes outputs.** The unsigned APK, plus `toolchain.txt`: the JDK, the NDK, platform and
   build-tools revisions, fdroidserver, Flutter, the CPU count and `TZ`.

`fdroid build` clones the recipe's `Repo:`, so the commit must be pushed. The script needs Docker
on Linux x86_64; on an arm64 Mac it would run under emulation, too slowly to be useful.

**The release workflow** (`.github/workflows/appimage.yml`, "Deploy to GitHub Releases"):

| Job | What it does |
|---|---|
| `preflight` | Fails if `v<version>` already points at another commit, because F-Droid builds the tag. Fails on a draft left by a failed run. Never lets attached APKs be replaced. |
| `fdroid-build` | 3 ABIs × (`build`, `rebuild --vary`). Starts beside the test gate, because nothing here publishes and these builds are the long pole. |
| `fdroid-sign` | `environment: fdroid-signing` signs the `build` APKs on the host. |
| `fdroid-compare` | F-Droid's own check against the varied rebuild (§ The reproducibility gate). |
| `publish` | Creates a new Release as a draft with the AppImage and the three APKs, then publishes it, so the tag never exists without its APKs. A re-dispatch replaces only the AppImage. |

A dry run (`publish` unchecked) builds, signs and checks everything, and publishes nothing.

### Bumping the F-Droid toolchain

- **Flutter.** Raise `srclibs: flutter@` in all three blocks together with the workflows'
  `flutter-version:`. Set `ndk:` to the new Flutter's `ndkVersion`
  (`packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt`).
  `test/lint/fdroid_recipe_test.dart` fails until both agree.
- **The image.** Move `IMAGE`'s digest, `FDROIDSERVER_COMMIT` and `FDROIDDATA_COMMIT` in
  `tools/fdroid_build.sh` together, to what fdroiddata's CI uses that day.
  - Read the digest from the registry:
    `curl -sI -H "Authorization: Bearer $(curl -s 'https://gitlab.com/jwt/auth?service=container_registry&scope=repository:fdroid/fdroidserver:pull' | jq -r .token)" -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' https://registry.gitlab.com/v2/fdroid/fdroidserver/manifests/buildserver-trixie | grep -i digest`.
  - Do it when F-Droid reports a mismatch our gate didn't, and their log shows newer components
    than our `toolchain.txt`, or when fdroiddata's CI changes image.
- **The JDK.** The recipe's `sudo:` JDK lines follow the `apt-get install … openjdk-*` /
  `update-alternatives` pair in fdroiddata's `.gitlab-ci.yml` `fdroid build` job.

## F-Droid's signing stripper must leave an unsigned build

**Rule: `android/app/build.gradle.kts` picks the release signing config on one space-free line,
`signingConfig = signingConfigs.getByName(releaseSigningConfig)`, which is the shape F-Droid's
stripper removes.**

- **What the stripper does.** `fdroid build` runs `fdroidserver.common.remove_signing_keys` on every
  `build.gradle(.kts)` before the recipe starts. It drops a `signingConfigs {` block by brace
  count, and otherwise only lines matching `^[\t ]*signingConfig\s*[= ]\s*[^ ]*$` (plus two
  Groovy shapes).
- **What broke before.** The old `signingConfig = if (keystorePropertiesFile.exists()) { … } else
  { signingConfigs.getByName("debug") }` has spaces after its `=`, so it survived. With no
  `key.properties` on F-Droid's machine, F-Droid's APK came out **debug-signed**, and a signed
  APK can never take our signature. Measured with a port of the stripper on the old file:
  `signingConfig = if …` and both `getByName` lines remain.
- **Now.** The choice lives in a top-level `val releaseSigningConfig`.
  - The store build and the debug fallback are unchanged.
  - Stripped, the release type has no signing config, and the build is unsigned:
    `apksigner verify` reports "Missing META-INF/MANIFEST.MF".
  - Flutter still copies it to `build/app/outputs/flutter-apk/app-<abi>-release.apk`, the
    recipe's `output:` (`FlutterPlugin.kt`'s `assembleTask.doLast`).
- **The test.** `test/lint/fdroid_recipe_test.dart` runs a Dart port of the stripper on the file.
- **Also there:** `dependenciesInfo { includeInApk = false }`. F-Droid flags the Google-encrypted
  dependency block in an APK; the bundle Play reads keeps it.

## Signing the F-Droid APK

**Rule: the F-Droid APK is signed with a dedicated key, never the Play key, by apksigner 35 with
`--alignment-preserved`.**

- **A dedicated key.** F-Droid pins its fingerprint (`AllowedAPKSigningKeys`) for good.
  - Rotating it means a v3 rotation lineage, which F-Droid has to accept.
  - **Losing it ends the listing**, since no update could ever be signed again. Keep an offline
    backup.
  - No key choice would let Play and F-Droid installs update each other: Play App Signing means
    Play installs carry Google's key, not ours.
  - Generating it: `docs/store-deployment-setup.md` § F-Droid signing key.
- **Where it lives.** Four secrets in the GitHub Environment `fdroid-signing`, deployable only
  from `main`, so a pushed branch can't dispatch a workflow that reads them.
  - Only `fdroid-sign` names the Environment.
  - It signs on the host, so the third-party image never shares a job with the key.
  - The script decodes the keystore into `$RUNNER_TEMP` and passes passwords as `env:`
    references, never on a command line.
- **apksigner 35, `--alignment-preserved`.**
  - Without the flag, build-tools ≥ 35 re-pads every entry with its own alignment extra field.
    The bytes then no longer match F-Droid's unsigned build, and the copied signature fails to
    verify.
  - build-tools 34 has no such flag (checked: "Unsupported option").
  - F-Droid's docs still say "use 34"; that predates the flag (the apksigcopier README describes
    the cause).
  - Schemes: v2 + v3, no v1 (minSdk 24), no v4.
- **What `sign` checks:**
  - 16 KB page alignment (`zipalign -c -P 16 4`). Native libraries are stored uncompressed, and
    `--alignment-preserved` keeps whatever AGP produced (measured: AGP 8.11 aligns them).
  - The certificate's SHA-256 equals the recipe's `AllowedAPKSigningKeys`. A wrong secret fails
    the job instead of publishing an APK F-Droid will reject.
- **No secrets** (a fork, or a branch the Environment refuses): `sign` uses an ephemeral key and marks the
  output `publishable=false`. That still proves the signature copies across; it is never
  attached.
- **The pinned key** (generated 2026-10-15) is
  `d17fac8d589599231c31ce52a5e6fde72bba9b7ddc8b180307e25cc68803c17d`.
  - A real release refuses to publish APKs signed with anything else, and refuses to publish
    without them.
  - `test/lint/fdroid_recipe_test.dart` fails on any `AllowedAPKSigningKeys` that isn't a
    64-character hex fingerprint.

## The reproducibility gate

**Rule: a Release carries the F-Droid APKs only after F-Droid's own `verify_apks` accepts our
signed APK against a second, independent build.**

- **The varied rebuild.** `fdroid-build` runs each ABI twice: `build`, which gets signed, and
  `rebuild` with `--vary`.
  - `--vary` means 2 CPUs (`--cpuset-cpus 0,1`), `TZ=Etc/GMT-14`, `umask 0077` and another
    hostname.
  - It doesn't vary the locale: `bsenv.sh` pins `LC_ALL=C.UTF-8` on every buildserver, and the
    image ships no other locale.
- **The check.** `fdroid-compare` runs `fdroidserver.common.verify_apks`, the function `fdroid
  publish` uses, twice per ABI:
  - signed against our own unsigned build, which proves signing preserved every byte;
  - signed against the varied rebuild, which proves the build is reproducible.

**When it fails:**
1. The job log names the differing files: fdroidserver's `compare_apks` extracts both and runs
   `diff -r`.
2. The next step diffs the two `toolchain.txt` files. If a revision differs, that is the answer.
3. Download the `fdroid-unsigned-<abi>-build` and `-rebuild` artifacts and run `diffoscope` on them
   on a Linux machine. Installing it is a pip/apt install, so ask first (CLAUDE.md § Strict rules).
4. Known causes:
   - **`assets/dexopt/baseline.prof` / `.profm`**, AGP's profile, whose ordering can depend on the
     CPU count. The fix is F-Droid's snippet in `android/app/build.gradle.kts`, logged in
     `docs/upstream-workarounds.md`:
     ```kotlin
     tasks.whenTaskAdded {
         if (name.contains("ArtProfile")) {
             enabled = false
         }
     }
     ```
     It isn't applied today. The two same-machine builds above matched, and the gate is what
     proves the CPU-count case.
   - **`platformBuildVersionName` in `AndroidManifest.xml`**, if Google ships a new
     `platforms;android-36` revision between our build and F-Droid's. There's no fix but a new
     release.

If F-Droid reports a mismatch our gate didn't catch, the two runs differed in what the gate can't
vary: the image or the JDK. Compare their build log with our `toolchain.txt`, then bump the pins
(§ Bumping the F-Droid toolchain).

## The F-Droid recipe

`tools/foss/com.invoiceninja.admin.yml` is the fdroiddata metadata file, ready to submit.

- **Listing metadata** is copied from the live `com.invoiceninja.app` listing:
  - `AntiFeatures: NonFreeNet`, because the server is Elastic-2.0;
  - `Categories: Finance Manager` (the earlier draft's `Money` is a retired category);
  - the author fields and the Transifex link.
- **One block per ABI**, with Flutter's split versionCodes: the ABI digit × 1000 + N, using
  `FlutterPluginConstants.ABI_VERSION` (1, 2 and 4).
  - `VercodeOperation` lists them in block order, and `CurrentVersionCode` is the highest
    (4000 + N).
  - A device installs the highest versionCode it can run, so an arm64 phone gets arm64.
  - Measured: the arm64 APK is 59.7 MB; the universal one was 169.5 MB.
- **`binary:`** per block, naming the asset `InvoiceNinja-<version>-<abi>.apk`. `sign` derives the
  file name from the same line.
- **`scanignore:` exists for one plugin, and the scan deletes rather than skips.**
  - `scandelete: .pub-cache` makes F-Droid's scanner delete every flagged file in the pub cache
    (`removeproblem` → `os.remove`), not just skip it.
  - `flutter_contacts` declares the Flutter engine's Maven repo,
    `https://storage.googleapis.com/download.flutter.io`, in its `android/build.gradle`, and that
    repo isn't on the scanner's `allowed_repos` list. The first CI run lost the file, and Gradle
    then failed configuring `:flutter_contacts` with a bare `NullPointerException`, under a
    misleading "AGP 9+ / android.newDsl" hint.
  - Ignoring it downloads nothing new: Flutter's Gradle plugin adds the same repo to
    `rootProject.allprojects` anyway (`FlutterPlugin.kt`). fdroiddata's Flutter template
    scanignores that repo for the same reason.
  - The lint test requires a `scanignore` for every resolved plugin that names an unknown repo,
    and no others, because an unused `scanignore` path fails F-Droid's scan.
- **The version fields follow `pubspec.yaml`, automatically.** `tools/bump_client_version.sh`
  rewrites each block's `versionName`, `versionCode` (ABI digit × 1000 + build) and
  `commit: v<version>`, plus `CurrentVersion` / `CurrentVersionCode`, as it does
  `snap/snapcraft.yaml`.
  - So the recipe already names the release that gets tagged, ready to submit.
  - The lint test fails if the recipe and pubspec disagree.
  - The bump refuses a build number of 1000 or more, where the ABIs' versionCodes would collide.
  - Once listed, F-Droid's checkupdates bot adds blocks for each new tag in fdroiddata's copy.
    Our CI rewrites the version lines for each build anyway.
- **After the fdroiddata merge request lands, fdroiddata's copy is authoritative.** Reviewers do
  edit recipes, so copy any change back here; otherwise our CI builds something F-Droid doesn't.
- **Listing text** lives in `fastlane/metadata/android/en-US/`:
  - `title.txt`. Without it, checkupdates would rename the app after the APK label, "Ninja Beta".
  - `short_description.txt` (≤ 80 characters) and `full_description.txt` (≤ 4000).
  - `images/icon.png`, one of the `tools/gen_app_icons.dart` outputs.
  - `images/phoneScreenshots/1.png` … `8.png`: 1080×2400 captures of the real app against the
    demo account, made by the UX sweep in phone emulation, with Android touch sizing and demo
    writes blocked:
    ```sh
    UX_OUT_DIR=build/fdroid-screens tools/capture_ux_review.sh "360x800@3:android:light:100:en"
    UX_OUT_DIR=build/fdroid-screens-dark tools/capture_ux_review.sh "360x800@3:android:dark:100:en"
    ```
    It needs a chromedriver on :4444 (see the script's header). The `@3` is what makes them
    full-resolution: Chrome emulates a 3× phone, where a plain `360x800` gives 360×800 images.
    - The eight, in order: dashboard; invoices; clients; the dashboard further down (overview
      chart, invoices and quotes); the invoice report (dark); payments; the task board; the
      report gallery (dark). Each screen appears once, and two are dark to show the theme.
    - The demo account's products and task titles are lorem ipsum, so the product and task lists
      are left out. The task board keeps its lorem titles, because the board is the point.
  - **Not yet written:** changelogs (`changelogs/<versionCode>.txt`, three per release with
    split APKs).

Decisions (2026-10):

- **Listing identity.** This is a new listing, `com.invoiceninja.admin`. The old
  `com.invoiceninja.app` listing (admin-portal, F-Droid-signed, versionCode 194) is untouched,
  and its users are not moved: it is a different application id, and local data would not carry
  over anyway.
- **Signing.** Our dedicated key (§ Signing the F-Droid APK). Play and F-Droid installs share
  `com.invoiceninja.admin` but have different signers, so neither can update the other.
  Switching means uninstalling, which **destroys the local database, including any unsynced
  Outbox rows**. The listing's description says to sync first.

**Submitting.** Once a Release carries pinned APKs, open a merge request on fdroiddata adding this
file as `metadata/com.invoiceninja.admin.yml`, or hand it, with the fingerprint, to the maintainer
on invoiceninja/flutter#175.
