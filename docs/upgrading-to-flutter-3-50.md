# Upgrading to Flutter 3.50

Companion to CLAUDE.md § Strict rules (the pinned toolchain) and `docs/setup.md` § Dependency updates. What was done on 3.47.7 so the move to Flutter 3.50 is a pin change, what 3.50 still needs on the day, and what was measured against 3.50.0 before any pin moved.

## The app was prepared on 3.47.7 and checked against 3.50.0 before any pin moved

Prepared 2026-11-12, against the `3.50.0` tag (Dart 3.14.0). Every change below builds and passes on 3.47.7, the pinned SDK, and was then run on 3.50.0 in a detached worktree of this repo with a separate 3.50.0 SDK, so the shared checkout and CI never saw 3.50.

**Already on main:**

- **Android toolchain** (`bd44f623`): AGP 8.11.1 → 9.1.1, Gradle 8.14 → 9.3.1, Kotlin Gradle plugin 2.2.20 → 2.4.10, the lowest versions 3.50 accepts (it refuses AGP below 9.1.1, Gradle below 9.3.1, KGP below 2.4.10) and within what 3.47.7 knows. `android.builtInKotlin=false` and `android.newDsl=false` (added by Flutter's migrator) keep the plugins building. AGP 9 checks each library's compileSdk against its dependencies' AAR metadata, and super_keyboard still compiles against 34, so the root build raises plugin modules below 36 to 36 (`docs/upstream-workarounds.md` § 20). On 3.47.7: debug APK, release bundle, per-ABI release APKs (version codes 271/272/273), and CI's store and FOSS Android builds all pass.
- **`strict-raw-types` → the `no_raw_types` lint** (`bd44f623`), its replacement ([flutter#187692](https://github.com/flutter/flutter/pull/187692), dart-lang/sdk#63517). `strict-casts` and `strict-inference` are not deprecated and stay.
- **A Dart 3.14 AOT compiler crash** (`da6bef16`): every *release* build on 3.50 failed in the register allocator (`linearscan.cc: 3013: error: unreachable code`), set off by one closure in `SearchableDropdownField`. Debug builds and tests never compile ahead of time, so only the CI trial's release builds found it. The closure is rewritten, and `docs/upstream-workarounds.md` § 21 says how to find the function if another one trips it.
- **Five widget tests** that failed only on 3.50 (`700b7a58`): work on the real event loop (a Drift query before a cold-miss fetch; google_fonts loading the designer's bundled Roboto) landed after the test body on 3.50. They now let it settle (`test/_support/google_fonts_settle.dart`).

**Measured on 3.50.0:**

| Check | Result |
|---|---|
| `flutter pub get` | resolves; only the SDK-pinned `test` / `test_api` / `test_core` move, and `listen` is added |
| `flutter analyze` | 1,512 infos, all `deprecated_member_use`: 1,499 `package:flutter/material.dart` imports, 9 `GlobalMaterialLocalizations`, 4 `GlobalCupertinoLocalizations`. No errors or warnings. |
| Tests | every chunk passes except `store_sdk_boundary_test`'s FOSS-lock check, because the lock moved (step 3 below) |
| `flutter build web --wasm` | builds; notes that `--pwa-strategy` is deprecated |
| `flutter build apk --debug` | builds; warns that Gradle 9.3.1, AGP 9.1.1 and KGP 2.4.10 "will soon be dropped" (step 5) and that five plugins apply the Kotlin Gradle plugin (§ Left for later) |
| `flutter build macos --debug` | builds; not launched (the debug app asks for keychain access) |
| CI trial (2026-11-12) | Android, Linux and Windows release builds crashed the AOT compiler until `da6bef16`; after it every job passed: analyze, the whole test suite, web and its integration test, Android (store and FOSS), Linux, Windows, iOS and macOS |
| iOS / macOS minimums | unchanged: iOS 15.0, macOS 12.0, Xcode 15 required and 16 recommended |

## CI can try 3.50 before any pin moves

`ci.yaml` takes a `flutter_version` input: `gh workflow run ci.yaml --ref main -f flutter_version=3.50.0`. Blank, every job runs on the pin. Given a version, every job runs on it as upgrade day would: `_test.yaml` and the FOSS Android job resolve the FOSS lock anew (step 3 below), and both analyze steps pass `--no-fatal-infos`, so the Material deprecations show without failing the run. The release workflows call `_test.yaml` without the input, so they always build on the pin. This is how the platforms this Mac can't build (Windows, the Linux desktop, the CI Xcode's iOS) were checked before the pin moved.

## Material moves to material_ui, and the app can't follow until its dependencies do

Flutter 3.50 deprecates `package:flutter/material.dart` and `cupertino.dart` in favour of the standalone `material_ui` / `cupertino_ui` packages (`dart fix --apply --code=migrate_design_widgets`). It is a deprecation, not a removal: the framework's own Material still ships and works.

`material_ui` is a **separate copy** of the Material library, not a re-export: its `ThemeData`, `MaterialApp` and the rest are different types from the framework's. Most of our dependencies that touch Material (super_editor, printing, flutter_localizations, go_router 17's `MaterialPage`) still use the framework's, so moving our imports alone would split the app across two incompatible sets of types. `docs/setup.md` already holds go_router 18 and google_fonts 9 back for the same reason. Migrate when those dependencies have moved, as one project, with `dart fix` and the `MaterialUiCompatibilityBridge` the guide offers for the stragglers.

Until then 3.50's analyzer reports every Material import as deprecated, and `flutter analyze` fails on infos. Upgrade day has to choose one of:

1. **`deprecated_member_use: ignore` under `analyzer: errors:`**, with a comment pointing here. Simple, but it also hides every *other* deprecation until it is removed again.
2. **Do the material_ui migration first**, if the dependencies are ready by then.

### The migration is mechanical, and was tried on 3.50.0

Run on a scratch copy (2026-11-12, material_ui 1.11.0), it took three commands and one hand edit, and left `flutter analyze` clean:

```sh
flutter pub add material_ui cupertino_ui
dart fix --apply --code=deprecated_member_use        # 1,512 fixes: the imports and the localizations
# 19 ambiguous_import errors remain, in the 8 files that import both material_ui and
# flutter_localizations: add `hide GlobalCupertinoLocalizations, GlobalMaterialLocalizations`
# to their flutter_localizations import
dart fix --apply --code=duplicate_import --code=unused_import --code=unnecessary_import
```

The whole test suite then ran on it: 14,275 passed and 4 failed. One is the FOSS lock (step 3). The other three are the split this section warns about, and none is a test bug to paper over:

- **super_editor's mobile caret** came out Material's default purple, not our accent (`markdown_text_field_test`): it reads `Theme.of(context).primaryColor` from the framework's Theme, which our `buildInTheme` no longer fills.
- **The edit page's slide-in** no longer keeps the detail page under it (`edit_route_opaque_page_test`): go_router's pages read their transition from the framework's Theme too.
- **`find.byTooltip`** finds nothing (`sidebar_footer_actions_widget_test`): flutter_test's finder matches the framework's `Tooltip`, and the app's tooltips are now material_ui's. This one is the test, not the app.

`MaterialUiCompatibilityBridge` maps the colour scheme, text theme and density into a framework Theme, but not component themes or ThemeExtensions (`context.inTheme` is one), so wrapping the app in it should carry the caret colour and may not carry the rest (untested). Whatever is chosen, run the app and look at every surface a dependency draws (the rich-text editor, the PDF preview, page transitions) before shipping it.

## Upgrade day, in order

1. Change `3.47.7` to `3.50.0` in every workflow (`_test.yaml`, `appimage.yml` (F-Droid and Flathub read their Flutter from it), `appstore-ios.yml`, `appstore-macos.yml`, `ci.yaml` ×8 and its comment, `microsoft-store.yml`, `perf.yaml`, `playstore.yml`, `snapcraft.yml`, `web.yml`), plus the 3.47.7 mentions in `pubspec.yaml`'s version comment and `docs/setup.md`. In `ci.yaml` and `_test.yaml` the pin is the default of the trial input (`${{ inputs.flutter_version || '3.47.7' }}`); `fdroid_recipe_test` reads it there and fails if any workflow disagrees.
2. `flutter pub get` and commit `pubspec.lock`.
3. `tools/prepare_foss.sh --update-lock` and commit `tools/foss/pubspec.lock` (`store_sdk_boundary_test` checks it).
4. The analyzer decision above. Migrating is the commands in § The migration is mechanical, and was tried on 3.50.0, then the three failures it lists and a visual check.
5. Raise Android to what 3.50 recommends, to silence its warnings: AGP 9.3.1, KGP 2.4.20, Gradle 9.5.0 (`android/settings.gradle.kts`, the wrapper). Not before the pin moves: 3.47.7 knows AGP only up to 9.2 and Gradle up to 9.3.1 (`maxKnownAndSupported*` in its `gradle_utils.dart`). Its NDK is unchanged (28.2.13676358 in both), so the F-Droid recipe's `ndk:` stays.
6. macOS: 3.50 carries the fix for Impeller's garbled text on Intel Macs ([flutter#191538](https://github.com/flutter/flutter/issues/191538), on main since 2026-08-25, inside the 3.50.0 tag). Remove `FLTEnableImpeller` from `macos/Runner/Info.plist` **only after** running the 3.50 build on an Intel Mac with an AMD GPU (`docs/upstream-workarounds.md` § 16).
7. Recheck `docs/upstream-workarounds.md` § 4 (desktop integration tests one file per run): [flutter#189192](https://github.com/flutter/flutter/pull/189192), the fix it waited on, is in 3.50.
8. Android: release builds now ignore engine flags and `route` / `dart_entrypoint` / cached-engine extras on untrusted intents. `MainActivity` already strips every extra, so nothing should change, but check a share and a deep link on a release build on Android 13 and on 14 or newer.
9. **Flatpak.** Flathub builds the release itself: its **Update app** workflow regenerates the offline sources from the tag with a pinned `theappgineer/flatpak-flutter` image (0.15.0, June 2026, the newest when this was written). 0.15.0 built 5.1.24 on 3.47.7, and nothing in its releases or issues mentions 3.50. Read against 3.50.0 (2026-11-12), it should still work: its generator reads `bin/internal/engine.version`, `gradle_wrapper.version` and `material_fonts.version`, all still there; the `shared.sh` it patches is byte-identical to 3.47.7's; the one bootstrap script 3.50 changed, `update_dart_sdk.sh`, only runs when the Dart SDK stamp is stale, and flatpak-flutter writes that stamp; and 3.50's cache code adds no Linux engine artifact. That is a reading, not a build, so the first 3.50 release's update PR is still where an incompatibility would show up: a failed `flathub/build`, which turns Deploy to all's `flathub` leg red. Before the release, look for a newer flatpak-flutter that names 3.50 or Dart 3.14 (github.com/TheAppgineer/flatpak-flutter/releases). Moving its pin, or any other change on the Flathub side, is Hillel's by hand (`docs/flatpak.md`, Flathub's AI policy). A failed update build breaks nothing for users: Flathub keeps serving the previous version until a build passes.
10. Run the whole test suite, a Deploy to Web test run and CI, then release.

## Left for later

- **Built-in Kotlin.** 3.50 warns that five plugins still apply the Kotlin Gradle plugin, and a future Flutter will refuse them: desktop_drop, in_app_review, sentry_flutter, super_keyboard and our own `packages/store_services`. Ours can move to built-in Kotlin on its own (Flutter's "migrate to built-in Kotlin for plugin authors" guide); the others wait on their maintainers, and `android.builtInKotlin=false` stays until they do.
- **`--pwa-strategy`** is deprecated in 3.50. When it goes, Deploy to Web switches to a custom `web/flutter_bootstrap.js` (`docs/web-deploy.md`).
- **Not in 3.50:** the RenderEditable and Scribble null-check PRs from the Sentry sweep (#196219, #196220), RawAutocomplete reopen (#140662), and the SwiftPM deployment target (#162196). Their workarounds stay.
