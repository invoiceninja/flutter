# Upstream-bug workarounds

The single registry of workarounds this app carries for **open upstream bugs/limitations** — in Flutter, Dart, third-party pub packages, or platform SDKs — that we expect to **remove once the upstream ships a fix**.

Keep it current (see CLAUDE.md § Strict rules): whenever you add, change, or remove such a workaround, update the matching entry here.

## How to use this file

Each entry tags every code change as:

- **MUST-REVERT** — the actual workaround; undo it when the upstream is fixed.
- **KEEP** — an independent improvement made along the way that is correct regardless; leave it.

Each entry gives a **minimal revert** (undo just the workaround) and, where relevant, a **full revert** (exact prior state). When the changes are committed, record the **commit SHA(s)** so `git revert <sha>` is a one-shot undo — ideally commit each workaround on its own so the revert is clean.

When an upstream fix ships: follow the revert, verify, then **delete the entry**.

> Not here: permanent adaptations we will *not* revert (see "Considered but not tracked" below), and **server-side** changes we're waiting on our backend partner for — those live in [`BACKEND.md`](../BACKEND.md).

### Entry template

```
## <short title>
- Issue / waiting on: <link(s) + status>   • Found: <date / "pre-existing"> • Flutter: <version>
- Symptom: <what breaks, and how it surfaces>
- Root cause: <one line>
- Commit ref: <sha(s), or "not yet committed">
- Change(s):
  - `<file>` — **MUST-REVERT** | **KEEP**: <what changed>
- Revert: <minimal steps> (+ full-revert / ordering notes if relevant)
- Recheck trigger: <when/how to test whether upstream is fixed>
```

---

## 1. Flutter 3.44: dev-dependency plugin still emitted into GeneratedPluginRegistrant

- Issue / waiting on: [flutter/flutter#186800](https://github.com/flutter/flutter/issues/186800) (open, P1), [#169336](https://github.com/flutter/flutter/issues/169336), [#175621](https://github.com/flutter/flutter/issues/175621). • Found: 2026-06-11 • Flutter: 3.44.1
- Symptom: release build fails at `:app:compileReleaseJavaWithJavac` — `package dev.flutter.plugins.integration_test does not exist`. `flutter clean` does **not** help. Affects Android **and** iOS/macOS release builds.
- Root cause: dev-dependency plugins are dropped from the release native classpath but still emitted into `GeneratedPluginRegistrant.java`.
- Commit ref: _not yet committed — fill in the SHA(s) when committed._
- Changes:
  - `pubspec.yaml` — **MUST-REVERT**: `integration_test` moved `dev_dependencies` → `dependencies` (+ explanatory comment).
  - `android/app/build.gradle.kts` — **KEEP**: release signing falls back to debug when `key.properties` is absent; removed the dead double-assigned `signingConfig`. (Independent hardening; enables the CI release gate.)
  - `.github/workflows/ci.yaml` — **KEEP**: `build-android` gate now `flutter build apk --release` (was `--debug`).
- Revert (minimal, recommended): move `integration_test` back to `dev_dependencies`, delete its comment, run `flutter pub get` (regenerates `pubspec.lock` + `.flutter-plugins-dependencies`), confirm `flutter build appbundle` succeeds.
  - Full revert ("undo everything"): `git revert` the workaround commit(s), or also restore the original `build.gradle.kts` signing block and the `ci.yaml` `--debug` line — note that reintroduces the prior crash-when-`key.properties`-absent and the weaker debug-only gate, so **KEEP** is recommended over a full revert.
  - **Revert ordering (important):** don't revert until dev + CI are on a Flutter version that fixed the issue. The CI `apk --release` gate fails if the bug is still present — that's the built-in safety check.
- Recheck trigger: when the issues close — temporarily move `integration_test` back to `dev_dependencies` and run `flutter build appbundle`.

## 2. isolate_manager: transitive `dart:html` blocks `flutter build web --wasm`

- Issue / waiting on: `re_editor` (`^0.9.0`) to resolve a wasm-clean `isolate_manager` (≥6, on `package:web`), or `isolate_contactor` to drop `dart:html`. No single tracking bug — watch `re_editor`'s pub releases / its `isolate_manager` constraint. Context: `dart:html` is unavailable under dart2wasm ([flutter#148825](https://github.com/flutter/flutter/issues/148825), [#160318](https://github.com/flutter/flutter/issues/160318)). • Found: pre-existing
- Symptom: `flutter build web --wasm` fails (`dart:html` not available) via `re_editor` → `isolate_manager` 4.x → `isolate_contactor`.
- Root cause: `re_editor`'s transitive `isolate_manager` 4.x pulls `isolate_contactor`, which uses `dart:html`.
- Change:
  - `pubspec.yaml` `dependency_overrides:` — **MUST-REVERT**: `isolate_manager: ^6.3.2`.
- Revert: remove the override line; `flutter pub get`; confirm `flutter build web --wasm` still compiles.
- Recheck trigger: when a `re_editor` release pulls `isolate_manager` ≥6 transitively — drop the override and build `--wasm`.

## 3. super_editor: published package lags Flutter 3.44 IME

- Issue / waiting on: a pub.dev `super_editor` release that supports the Flutter 3.44 IME surface (`TextInputConnection.updateStyle`). The published package ([superlistapp](https://github.com/superlistapp/super_editor)) ships dev-only releases that lag 3.44; active dev is the [Flutter-Bounty-Hunters fork](https://github.com/Flutter-Bounty-Hunters/super_editor). Watch: [pub.dev/packages/super_editor/versions](https://pub.dev/packages/super_editor/versions). • Found: pre-existing
- Symptom: the pub `super_editor` won't compile under Flutter 3.44 — its `TextInputConnectionDecorator` misses the `TextInputConnection.updateStyle` override.
- Root cause: the canonical (superlistapp) package stalled pre-3.44; the 3.44 IME surface only exists on the FBH fork.
- Change:
  - `pubspec.yaml` `dependency_overrides:` — **MUST-REVERT**: `super_editor` git pin (FBH `stable` @ `2408aa52579a6d13479b38da980dc3093c2982a8`). Powers the rich-text editor (`super_editor` + `super_editor_markdown`; see CLAUDE.md § Rich text editing). `super_editor: any` in `dependencies` pairs with this pin.
- Revert: remove the git override; set `super_editor:` in `dependencies` to the released pub version (currently `any`); `flutter pub get`; build + sanity-check the markdown editor (e.g. an email/invoice template override field).
- Recheck trigger: when pub.dev `super_editor` supports Flutter 3.44 — drop the override and build.

## 4. Flutter desktop integration tests: one file per `flutter test` invocation

- Issue / waiting on: [flutter/flutter#135673](https://github.com/flutter/flutter/issues/135673). • Found: pre-existing
- Symptom: `flutter test integration_test/ -d macos` (bare glob) runs only the FIRST file; later files die with "Error waiting for a debug connection" — the tool reuses a debug-connection stream that breaks on the second app launch.
- Root cause: the desktop integration runner can't relaunch the app across multiple files in one invocation.
- Change:
  - `tools/run_integration_local.sh` — **MUST-REVERT**: runs one file per invocation (the upstream-recommended workaround) with a per-file timeout.
- Revert: replace the per-file loop with the bare-glob `flutter test integration_test/ -d <device>`.
- Recheck trigger: when #135673 closes — try the bare glob locally.

## 5. Dart analyzer lags the 3.11 parser on null-aware elements

- Issue / waiting on: analyzer/SDK version lag (no issue number cited in-tree). • Found: pre-existing
- Symptom: `?'key': value` (null-aware map/collection elements) is parser-supported in Dart 3.11 but the bundled analyzer rejects it, so the `use_null_aware_elements` lint can't be satisfied.
- Root cause: the bundled analyzer trails the language parser for this syntax.
- Change:
  - `analysis_options.yaml` — **MUST-REVERT**: `use_null_aware_elements: ignore` (with the "re-enable when the analyzer catches up" comment).
- Revert: remove that `ignore` line after a Dart/analyzer bump; run `flutter analyze`.
- Recheck trigger: after each SDK bump — drop the ignore and analyze.

## 6. local_auth_windows / cppwinrt plugins: `<experimental/coroutine>` hard-errors on MSVC 14.51

- Issue / waiting on: [flutter/flutter#186452](https://github.com/flutter/flutter/issues/186452) (VS 18.6 / MSVC 14.51 breakage), [microsoft/cppwinrt#1520](https://github.com/microsoft/cppwinrt/issues/1520) (root cause), and a `local_auth_windows` release that migrates off the deprecated experimental coroutine header — all open. • Found: 2026-07-09 • Flutter: 3.44.1
- Symptom: `flutter build windows` (the CI `build-windows` gate + the `deploy-msstore` job) fails compiling `local_auth_windows_plugin.vcxproj` with `error C2338: static assertion failed: 'error STL1011: The /await compiler option, <experimental/coroutine>, ... are deprecated ...'`. Surfaces on CI (`windows-latest` now ships Visual Studio 18 / MSVC 14.51) and on any dev machine with VS ≥ 18.6.
- Root cause: `local_auth_windows` 2.0.1 compiles WinRT coroutines (`/await` + `cxx_std_20`, `#include <pplawait.h>` / `<ppltasks.h>`, `co_await` / `winrt::fire_and_forget`, bundled cppwinrt 2.0.220418.1) through the deprecated `<experimental/coroutine>` header; MSVC 14.51 turned that deprecation into a hard `static_assert` unless `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` is defined.
- Commit ref: _not yet committed — fill in the SHA when committed._
- Change(s):
  - `windows/CMakeLists.txt` — **MUST-REVERT**: `add_compile_definitions(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)` placed immediately before `include(flutter/generated_plugins.cmake)`, so every plugin subdirectory inherits it (directory-scoped, forward-proof against sibling cppwinrt plugins tripping the same assert).
- Revert: delete that `add_compile_definitions(...)` line and its comment block; rebuild `flutter build windows`.
- Recheck trigger: when `local_auth_windows` publishes a release whose changelog cites the C++20 `<coroutine>` migration (or MSVC 14.51 / VS 18.6) — bump `local_auth`, drop the line, and rebuild `flutter build windows`.

## 7. RawAutocomplete: no way to reopen the options view without changing the text

- Issue / waiting on: no dedicated tracker for "show/reopen the options view on demand". Closest open issues: [flutter/flutter#140662](https://github.com/flutter/flutter/issues/140662) (let `Autocomplete`/`RawAutocomplete` distinguish focus from tap), [#99164](https://github.com/flutter/flutter/issues/99164) (missing features desktop/web users expect). What we actually need is a public `showOptions()` / controller on `RawAutocompleteState`. • Found: 2026-08-15 (invoiceninja/flutter#34) • Flutter: 3.44.1
- Symptom: after the user picks an option, tapping the same field again reopens nothing at all — neither the text nor the focus changed, so no code path recomputes the options.
- Root cause: `RawAutocomplete` recomputes `_options` **only** from its `TextEditingController` listener, and `_onChangedField` early-returns unless `value.text != _lastFieldText` (`packages/flutter/lib/src/widgets/autocomplete.dart`). `_canShowOptionsView` additionally requires `_options` to be non-empty, and nothing else can populate it.
- Commit ref: _not yet committed — fill in the SHA when committed._
- Change(s):
  - `lib/ui/core/widgets/searchable_dropdown_field.dart` — **MUST-REVERT**: `_reopenOptions()` plus its `onTap:` wiring on the field, and the `_resetHighlight` flag with the post-frame `_highlight?.value = 0` it drives (dead code without the bounce, which is the only thing that can reopen the list on a carried-over highlight).
  - `lib/ui/core/widgets/client_picker_field.dart` — **MUST-REVERT**: the same `_reopenOptions()` + `onTap:`.
  - `searchable_dropdown_field.dart` — **KEEP**: `_isPristine`, the hoisted-and-checked committed option, the committed row's direct `onChanged`, `OptionsViewOpenDirection.mostSpace`, no self-`Align`, the text-scaled row extent, and the suffix arrow. **KEEP** in `client_picker_field.dart`: `_isPristine` (the only part of the #34 fix that file needed). All of it is correct regardless of what the SDK does about reopening.
- Revert: delete `_reopenOptions()` and the `onTap: _reopenOptions` lines in both files, plus `_resetHighlight` and its post-frame callback (and the "tapping again after a pick reopens the list" test). Everything else stays — the pristine rule alone still handles first-focus and refocus.
- Recheck trigger: when `RawAutocomplete` exposes a way to show its options view imperatively (or recomputes on focus) — drop the two hooks and confirm `test/ui/core/widgets/searchable_dropdown_field_test.dart` still passes, in particular "tapping again after a pick reopens the list".

## 8. Flutter SwiftPM: generated package manifest ignores the project's iOS deployment target

- Issue / waiting on: [flutter/flutter#162196](https://github.com/flutter/flutter/issues/162196) (open, P3 — "Xcode build does not update the generated package's supported platforms"). Related, already-fixed context: [#162072](https://github.com/flutter/flutter/issues/162072). • Found: 2026-08-25 • Flutter: 3.44.1
- Symptom: a hand-built iOS **Product → Archive** from Xcode fails during Swift package resolution — `The package product 'file-picker' requires minimum platform version 14.0 for the iOS platform, but this target supports 13.0` — even though `ios/Podfile` and all three project-level `IPHONEOS_DEPLOYMENT_TARGET` entries in `ios/Runner.xcodeproj/project.pbxproj` are already `14.0`. CLI builds (`tools/build_release.sh ios` → `flutter build ipa`) and CI (`appstore-ios.yml`, which carries its own `--config-only` step) are unaffected, so it only bites a developer archiving from the IDE.
- Root cause: `flutter_tools` writes `ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift` — the top-level SwiftPM package the Runner target links — at its **hardcoded** iOS default (`packages/flutter_tools/lib/src/darwin/darwin.dart` → `ios => Version(13, 0, null)`), and raises it to the project's real target only in `SwiftPackageManager.updateMinimumDeployment`, which is called from a single site inside `flutter build ios`/`ipa`/`run` (`packages/flutter_tools/lib/src/ios/mac.dart`). Xcode's archive path never calls it, and every `flutter pub get` regenerates the manifest back down to 13.0. The 14.0 floor itself is legitimate: `file_picker` ≥ 12 declares `.iOS("14.0")` and is the only plugin in the graph above 13.0.
- Commit ref: _not yet committed — fill in the SHA when committed._
- Change(s):
  - `tools/prepare_ios_archive.sh` — **MUST-REVERT**: new script. Runs `flutter build ios --release --config-only`, then verifies the regenerated manifest against the project's `IPHONEOS_DEPLOYMENT_TARGET` and against the highest iOS floor declared by any package under `ios/Flutter/ephemeral/Packages/.packages/`, exiting non-zero (and naming the package) when the manifest can't clear it. The verification half is what makes it more than a one-line wrapper: it predicts the *next* occurrence, when some plugin bumps past the project target.
  - `docs/setup.md` § Release builds with Sentry — **MUST-REVERT**: the `**iOS archives need one terminal command first (SwiftPM).**` paragraph (run `tools/prepare_ios_archive.sh` before each Xcode archive).
  - `docs/setup.md` § Platform targets — **KEEP**: the `**Minimum OS versions.**` paragraph. Recording iOS 14.0 / macOS 10.15 is correct regardless of upstream, and its absence is what made "raise the deployment target" look like the fix when it was already done.
  - `CLAUDE.md` Quick Index — **MUST-REVERT**: the "iOS Product → Archive failing on a plugin's minimum platform version" row.
- Revert: delete `tools/prepare_ios_archive.sh`, the `docs/setup.md` § Release builds with Sentry paragraph, the script mentions in § Platform targets and § iOS / macOS — App Store & TestFlight, and the `CLAUDE.md` Quick Index row; keep the § Platform targets paragraph itself. Nothing in `lib/` or the Xcode/Podfile build config is touched — the workaround is a manual step plus the script that performs and checks it.
- **Do not** try to automate this with a Runner scheme pre-action or a build-phase script. Xcode resolves the Swift package graph *before* either runs, so a hook can only ever fix the *next* archive — and a `flutter build … --config-only` pre-action is the exact thing that previously hung iOS archives (see the header comment in `tools/xcode_inject_sentry_dsn.sh`). Hand-editing the manifest is also futile: it is gitignored (`ios/.gitignore`) and rewritten by the next `flutter pub get`.
- Recheck trigger: when #162196 closes — bump Flutter, run `flutter pub get`, confirm `grep 'iOS(' ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift` reports `14.0` without a `flutter build`, then archive from Xcode with no prep step.

---

## Considered but NOT tracked (permanent adaptations — do not revert)

These look workaround-shaped but are correct-forever (or inherent), not "waiting on an upstream fix". Listed so they aren't re-litigated:

- `lib/app/mdi_icons.dart` — Flutter 3.44 made `IconData` `final`; Material Design Icons are vendored as a TTF + plain `const IconData`. Permanent (CI guards re-adding `material_design_icons_flutter`).
- `Material(type: MaterialType.transparency)` ink-ancestor wraps (`lib/ui/core/detail/entity_detail_tabs.dart`, `lib/ui/core/list/master_detail_layout.dart`, `lib/ui/features/settings/widgets/form_section.dart`, …) — the correct, long-standing Flutter pattern so an `InkWell` has a surface to paint ink on.
- `lib/ui/core/utils/text_input_focus.dart` — walks the element tree because `EditableText` hosts its `focusNode` on an inner `Focus` widget; by-design Flutter behavior.
- `lib/utils/formatting.dart` `.999999` rounding nudge — corrects inherent binary-float accumulation, not a package bug.
- clipboard-read-hang test technique (`test/ui/core/widgets/copyable_value_test.dart`) — `Clipboard.getData()` hangs under the widget-test fake-async zone; assert the `setData` channel call instead. A technique, nothing to revert.
- Capped transitive dependencies / `intl: any` (the comment block at the top of `pubspec.yaml`) — version ceilings imposed by upstreams (freezed/pdf/qr_flutter/SDK pins), not workarounds. The routine-bump recipe lives in `docs/setup.md` § Dependency updates.
- CI macOS integration suite — **decided, not a pending workaround**: the macOS-desktop integration suite is intentionally NOT run on CI and the diagnostic forensics step was removed (2026-06-14). A headless hosted `macos-26` runner has no Metal device (`MTLCreateSystemDefaultDevice()` nil → the app can't launch; `actions/runner-images#1779`, `flutter/flutter#118469`), and the earlier Metal-toolchain-install / Impeller-vs-Skia hardening was tried and removed as insufficient. The suite runs locally only — see `docs/integration-tests.md`. (Don't re-add it to CI without a GPU-capable runner.)

## See also

- [`BACKEND.md`](../BACKEND.md) — **server-side** changes we're waiting on our backend partner for (web CORS `Idempotency-Key`, server-side idempotency dedup, company write-envelope completion, list filter/sort gaps). A separate category from third-party upstream; don't duplicate those here.
