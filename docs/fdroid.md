# The F-Droid (FOSS) build

Companion to CLAUDE.md § Strict rules. This doc covers how the F-Droid build differs from the store
build, why each difference exists, and the recipe F-Droid runs.

F-Droid builds the app from source on its own servers. It rejects proprietary code (Play
Services, Play Billing) and prebuilt binaries. The store build contains both, so the F-Droid
build is a *variant*. **Everything that differs is produced by one script,
`tools/prepare_foss.sh`, and no file in `lib/` has a twin.**

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

**What runs when.** `build-android-foss` is in `ci.yaml`, which runs only when CI is dispatched.
The release workflows call `_test.yaml`, which runs `flutter test` and so the boundary lint test,
but not a FOSS APK build. So a release proves the imports, pubspec and API have not drifted, but
not that the FOSS APK builds. Dispatch CI before tagging a version for F-Droid.

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

## The F-Droid recipe

A draft of `metadata/com.invoiceninja.admin.yml` for fdroiddata. Pin `flutter@` to the version
CI pins (`flutter-version:` in `.github/workflows/ci.yaml`).

```yaml
Categories:
  - Money
License: AAL
SourceCode: https://github.com/invoiceninja/flutter
IssueTracker: https://github.com/invoiceninja/flutter/issues

AutoName: Invoice Ninja
RepoType: git
Repo: https://github.com/invoiceninja/flutter.git

Builds:
  - versionName: 5.1.12
    versionCode: 15
    commit: v5.1.12
    output: build/app/outputs/flutter-apk/app-release.apk
    srclibs:
      - flutter@3.44.1
    prebuild:
      - export FLUTTER=$$flutter$$/bin/flutter
      - tools/prepare_foss.sh
    build:
      - $$flutter$$/bin/flutter build apk --release

AutoUpdateMode: Version
UpdateCheckMode: Tags ^v\d+\.\d+\.\d+$
UpdateCheckData: pubspec.yaml|version:\s.+\+(\d+)|.|version:\s(.+)\+
CurrentVersion: 5.1.12
CurrentVersionCode: 15
```

Two decisions sit outside the code:

- **Listing identity.** The old app is on F-Droid as `com.invoiceninja.app`, at versionCode
  194. This app is `com.invoiceninja.admin`, at versionCode 15. As drafted it is a *new* listing,
  and the old listing's users are not upgraded to it. Continuing the old listing would need the
  applicationId overridden in the recipe and a versionCode above 194, and the two apps' local
  data would not carry over either way.
- **Signing.** F-Droid signs with its own key, so an F-Droid install and a Play install can't
  update each other. Reproducible builds signed with our key would change that, and cost
  byte-for-byte reproducibility work.
