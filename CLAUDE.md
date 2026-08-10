# Invoice Ninja — Flutter App (rebuild)

This is a clean-room rebuild of `/Users/hillel/Code/admin-portal`. Read this file before changing anything substantial.

## What this app is

A multi-platform Invoice Ninja admin client. Replaces the Redux-based admin-portal with three goals:
1. **Page-by-page data loading** — never `per_page=999999`.
2. **True offline editing** — every change lands in a local mutation outbox and syncs when online.
3. **No Redux** — plain Flutter state management.

Plus two non-negotiables carried from admin-portal:
- App restart restores exactly where the user left off (route, company, filters).
- Multi-company support.

## Quick Index

| When you're doing… | Look at |
|---|---|
| Adding a new entity | § Adding a new entity + `docs/adding-an-entity.md` |
| Adding / editing a settings screen | § Settings screens + `docs/settings-screens.md` |
| Wiring a form field, picker, or Enter-to-save | § Forms |
| Anything money / date / parsing | § Strict rules + § Forms |
| Dialog buttons rendering stacked | § Design system (v2) |
| Sync / outbox / 401-403-404-409-412-422 behavior | § Sync — non-obvious rules |
| Bundled vs per-entity data loading | § Data loading — bundled vs per-entity |
| Architecture, write pipeline, project layout | § Architecture — at a glance + `docs/architecture.md` |
| Changing the Drift schema (forward migration) | `docs/migrations.md` |
| Adding / changing a sidebar count badge | § Sidebar counters + `lib/domain/sidebar_badge_modes.dart` |
| Localization / Transifex import | § Localization |
| Cross-checking against legacy admin-portal / React / API docs | § Reference points |
| macOS entitlement, dev login pre-fill, platform targets | `docs/setup.md` |
| Building a release app / injecting the Sentry DSN | `tools/build_release.sh` (CLI) · `tools/xcode_inject_sentry_dsn.sh` + Runner scheme pre-actions (Xcode IDE archives) · `docs/setup.md` § Release builds with Sentry |
| Writing release notes for a new version | § Release Notes |
| Probing the demo API for live response shapes | `docs/probing-the-demo-api.md` |
| Server-side filter gaps / required API changes | `BACKEND.md` |
| Running integration tests | `docs/integration-tests.md` |
| Editing a CI / release workflow (test gate, job wiring) | `.github/workflows/_test.yaml` + `docs/setup.md` § Shipping to the stores |
| Debugging a runtime error or stale outbox row | § Diagnostics log + `docs/diagnostics.md` |
| Desktop window persistence (native runners) | `docs/desktop-window-state.md` |
| Rotating the `is_system` API token (blocked on server) | `docs/token-rotation.md` |
| Checking what's built vs what's left | `FEATURES.md` (kept current — see § Strict rules) |
| Working around an open upstream (Flutter/pub) bug — or undoing one later | `docs/upstream-workarounds.md` |

## Strict rules

Rules that turn into bugs or CI failures if forgotten. Read this block first.

- **No Redux. No bloc. No Riverpod.** `ChangeNotifier` only. Tempted to add one? Talk to the team first.
- **No `per_page=999999`.** Lists fetch one page at a time (50 rows default): the ViewModel calls `repo.ensurePageLoaded(N)` near the scroll edge, the repo writes the page to Drift, the UI reacts via the watch stream. A CI lint grep-fails the build if the literal appears in `lib/`.
- **Money is `Decimal`, never `double`.** Enforced by a CI test (greps entity models).
- **Date-only is the custom `Date` type; `DateTime` is for timestamps only.** Mixing them silently breaks invoice math.
- **Drift is the only thing the UI reads from.** The network writes to Drift; the UI watches Drift. Never read API responses straight into UI state.
- **Schema changes need a forward Drift migration now (post-beta).** The app is shipped — installed databases hold real user data and unsynced outbox edits. Any schema change (table / column / index) must bump `AppDatabase.schemaVersion`, add an `onUpgrade` step, re-dump (`drift_dev schema dump`) + re-generate (`schema generate`), and extend the matrix test. **Never re-squash to v1 or overwrite a shipped `drift_schemas/drift_schema_v*.json`** — a frozen-checksum CI test (`test/data/db/migration_test.dart`) fails the build if you do. Skipping the migration silently wipes the user's local DB (and pending offline edits) via the `isSchemaIntact()` reset backstop. Full workflow: `docs/migrations.md`.
- **Auth user data flows in through `/refresh`, not `GET /users/{id}`.** `_persistAndActivate` upserts each `data[N].user` block into the `users` Drift table on every login/refresh. `GET /users/{id}` is 412-gated (password-required). `auth.refresh()` runs a full `_persistAndActivate` — use it for a fresh session snapshot, not for incidental work. Never call `UsersApi.get` from incidental paths.
- **Every write goes through the outbox.** Repositories never call mutation endpoints directly. (Accepted exceptions, each a synchronous UI flow that can't queue: the calendar-connection OAuth handshake/`setCalendars`/`disconnect` in `CalendarConnectionRepository`, and `QuickbooksRepository` — see their class docs.)
- **Every list query is scoped by `company_id`.** Use `CompanyScopedDao` — direct table access bypassing the DAO fails a lint check.
- **Idempotency keys are stable across retries** — generated when the outbox row is created, reused on every retry.
- **Format money / dates / addresses through `Formatter`** (`lib/utils/formatting.dart`). `Formatter.money(amount, clientCurrencyId: ...)` runs the per-client → company currency cascade + Euro override; `Formatter.date(date.toIso())` honors company `date_format_id`. Never render `Date.toIso()`, `DateFormat`, or `MaterialLocalizations.formatMediumDate` directly — `toIso()` is for storage/API/Drift keys only. Build the `Formatter` once per screen via `services.formatterFor(companyId)` and pass it down. Parse user input via `parseDecimal(input, useCommaAsDecimalPlace: ...)`.
- **No `vm.<entityName>` / `vm.<entityName>s` aliases on list/detail VMs.** Canonical accessors are `vm.item` (detail) and `vm.items` (list), defined on the generic bases.
- **Imports**: always `package:admin/...`, never relative (`../`, `./`, bare) — enforced by `always_use_package_imports`.
- **Don't run integration tests locally unless the user explicitly asks** — they take over the foreground app and interrupt the session. Never run them proactively or as incidental verification; let CI run them. On-request procedure: `docs/integration-tests.md`.
- **`FEATURES.md` is the parity tracker — keep it current.** It compares every user-facing feature across React (`/Users/hillel/Code/react`), Flutter v1 (`/Users/hillel/Code/admin-portal`), and this rebuild. When a PR flips a row to ✅ in the Flutter v2 column, update that row in the same PR; a feature with no React/v1 precedent gets a fresh row (`—` / `—` / `✅`); a scaffolded-but-incomplete screen is 🟡, not ❌. Hand-edited — don't generate it. Legend: ✅ done end-to-end, 🟡 partial/scaffolded, ❌ not implemented, — N/A.
- **Pub packages OK; npm / pip / brew etc. require explicit approval.** A Dart/Flutter dep via `pubspec.yaml` + `flutter pub get` is fine — that's the project's package surface and reviewers see the lockfile diff. For anything outside that (`npm`, `pip`, `brew`, `gem`, `cargo`, system installers) stop and ask first, so a stray tool can't silently shift the build environment.
- **Never add a Claude / AI `Co-Authored-By` (or any "Generated with" / assistant) trailer or line** to commit messages or PR bodies. Commit messages contain only the human-authored description. This overrides the harness default.
- **Never create, switch, rename, or delete git branches in this working tree** (no `git branch`, `git checkout <branch>`, `git switch`). Multiple Claude sessions share this single checkout; a branch create/switch in one corrupts every other in-flight session. Work on whatever branch is checked out; commit there only when the user asks; if a task seems to need its own branch, stop and ask. This overrides the harness default ("branch first"). **Sole exception:** the integration-test procedure (`docs/integration-tests.md`), which branches inside an *isolated sibling worktree*, never this checkout.
- **Workarounds for open upstream bugs are logged in `docs/upstream-workarounds.md`.** When you add, change, or remove a workaround for an open Flutter/package bug, update that file — issue link, exact files/changes tagged KEEP vs MUST-REVERT, and revert steps — so it can be cleanly undone when the upstream fix ships.

## Architecture — at a glance

Layered MVVM:

```
View (StatelessWidget)
  └─ ViewModel (ChangeNotifier)
       └─ Repository (single source of truth for an entity)
            ├─ Drift database (local state, watched by streams)
            ├─ Outbox (mutation queue)
            └─ Service (HTTP client → /api/v1/...)
```

- **DI**: `Services` (`lib/app/services.dart`) — singleton bag built once in `main.dart`, exposed via `Provider<Services>.value`. Screens read via `context.read<Services>()`; ViewModels take repos by constructor injection.
- **State**: `ChangeNotifier` + `ListenableBuilder`. No Redux/bloc/Riverpod.
- **Models**: `freezed` + `json_serializable`. API DTOs in `lib/data/models/api/`, domain models in `lib/data/models/domain/`.
- **Persistence**: Drift. Native (iOS/macOS): SQLCipher, encrypted-at-rest with a per-install key in `flutter_secure_storage` (`invoiceninja.db.key.v1`). Web: unencrypted IndexedDB/OPFS via drift WASM (no SQLCipher/`PRAGMA key` — the browser origin sandbox is the trust boundary). The platform split lives behind `lib/data/db/database_opener.dart`; `openAppDatabase()` is platform-agnostic. Tests use `NativeDatabase.memory()`. See § Web.

See `docs/architecture.md` for the offline-first write pipeline (Drift→outbox→drain→apply, with `tmp_<uuid>` + `id_remap` for offline creates), the on-disk project layout, and the full coding-conventions checklist.

## Design system (v2)

Token-based visual language. (The original `docs/design/v2/*.jsx` mockups were removed in the "Clean up" pass — the Dart port is now the sole source of truth.)

- `lib/app/design_tokens.dart` — **the source of truth** for colors, radii, shadows, type. Read tokens via `context.inTheme.<name>` (e.g. `context.inTheme.surface`). **No new color constants** outside `InTheme`. `InRadii` / `InSpacing` are brightness-independent.
- `lib/app/theme.dart` — wires `InTheme.light` / `InTheme.dark` into `ThemeData` (incl. per-component button/shape themes).

When styling a page: read `design_tokens.dart`, reuse `InTheme`, prefer `Theme.of(context).colorScheme` + `context.inTheme` over hardcoded `Color(0x…)`.

**Always rounded rectangles, never pills.** Use `RoundedRectangleBorder(borderRadius: BorderRadius.circular(InRadii.r2))` (or `.r1` / `.r3` per size) — never `StadiumBorder`, never `BorderRadius.circular(999)`. Material 3 defaults `SegmentedButton` / `Chip` / `FloatingActionButton.extended` to pills, so `theme.dart` registers the rounded shape on every relevant component theme; new widgets inherit it. Add new component themes to `theme.dart` rather than overriding inline.

**Touch targets are gated on the platform, not the viewport.** `InSizes.touchTarget` (44 — the app's long-standing button floor and the iOS HIG minimum) is applied when `Env.isTouchPrimary` is true, i.e. iOS/Android **including a mobile browser** (unlike `Env.isMobile`, which is native-only — don't reach for it here). Every other responsive branch in the app keys off width, but hit-area size is a property of the input device: a narrow desktop window still has a mouse, and a tablet at ≥600 px still has fingers. The sidebar (`InSidebar` → `SidebarNavItem` / `SidebarFooterActions` / `NavHistoryButtons`) reads the flag once and threads it down as an explicit `touch:` param, so the leaf widgets stay pure and pumpable. Grow **width** only where the container has room — the 64 px collapsed rail overflows. Four traps if you extend this, each of which silently produces the wrong size rather than failing:

1. Express a row floor as `ConstrainedBox(minHeight:)`, never `SizedBox(height:)` — a fixed height clamps the label's line box and slices descenders at large text scale.
2. An `IconButton`'s explicit `constraints` are run through `visualDensity.effectiveConstraints` (M3 routes them into `ButtonStyle` `minimumSize`/`maximumSize`, then `button_style_button.dart` adjusts), so `compact` subtracts 8 and a `tightFor(44, 44)` renders **36**. Drop the density on touch; the theme default is already `standard` there.
3. `ThemeData.materialTapTargetSize` is `padded` on iOS/Android, which inflates an `IconButton`'s **layout** size (not just its hit area) to `kMinInteractiveDimension` = 48 and ignores your constraints. Pass `tapTargetSize: MaterialTapTargetSize.shrinkWrap` — the sidebar's icon buttons all do.
4. A `SidebarNavItem`'s `trailing` sits inside the row's `Row`, so it drives the cross axis and the row's own padding stacks on top: a 44 px trailing makes a 58 px row. Cap trailing widgets to the row's content box (target − vertical padding), not the target.

**Pair related action buttons side-by-side**, not stacked — a `Row` with `SizedBox(width: InSpacing.md(context))` between them. Cancel sits next to the primary action, never above it.

**Spacing tokens `InSpacing.md` / `InSpacing.lg` are responsive context-aware static methods** (`lib/app/design_tokens.dart`), not const doubles — wider on desktop, tighter on mobile (`md`: 8 px narrow `<600` / 12 px wide `≥600`; `lg`: 12 / 16 px). Call with a `BuildContext`: `EdgeInsets.all(InSpacing.lg(context))`, `SizedBox(width: InSpacing.md(context))`. **Drop `const` from any wrapping `EdgeInsets` / `SizedBox` / `Padding`** — the value is no longer compile-time const (perf cost is nil: Flutter's `Element.canUpdate` matches on `runtimeType + key`, not `==`). `InSpacing.sm` (8 px) stays `const` for math contexts and small inter-icon gaps; `xs` / `xl` / `xxl` stay const too — not part of the responsive system.

**Bordered-card form sections use `InSpacing.lg(context)` interior padding by default.** That's what `FormSection`, `DashboardCardShell`, and the task-edit identity card use; new one-off bordered cards (`Container` with `tokens.border` + `BorderRadius.circular(InRadii.r3)`) match with `padding: EdgeInsets.all(InSpacing.lg(context))`. Column-aligned interior surfaces (table headers + rows + add-row tiles) use the horizontal value (`horizontal: InSpacing.lg(context)`) so cells line up with the section title. Card-to-card inset consistency is the point.

**Side-by-side dialog actions need a per-call `minimumSize` override.** A `FilledButton` / `FilledButton.tonal` / `OutlinedButton` inside `AlertDialog.actions` (or any `Row`) needs `style: FilledButton.styleFrom(minimumSize: const Size(64, 44))` (Outlined uses `Size(64, 40)`). The themes default to `Size.fromHeight(44)` = infinite width — right for column-stacked form buttons, but in a horizontal context `Row` crashes layout and `AlertDialog.actions` silently stacks via `OverflowBar`. Inline comments in `theme.dart` explain why.

**Dialog primary actions use `PrimaryDialogAction`** (`lib/ui/core/widgets/primary_dialog_action.dart`), not a hand-rolled `FilledButton`. It bakes in the `Size(64, 44)` override, `autofocus`, and a subtle trailing **Enter** affordance (a dimmed `↵` — the app's standard Enter glyph) so users learn Enter submits. `variant:` selects plain / `.tonal` / `.destructive`; keep `autofocus: false` when a text field should own focus (Enter still submits via `FormSaveScope`/`onSubmitted`), and `showEnterHint: false` when Enter can't/shouldn't fire the primary. Two non-obvious `showEnterHint: false` cases (they cause a *lying* hint otherwise): **dropdown-only dialogs** — `SearchableDropdownField` consumes Enter to pick an option and never calls `FormSaveScope.trySubmit()`, so a scope around it is dead; and **primaries that start disabled** (`enabled: x != null`) — a disabled button can't take `autofocus`, so Enter never reaches it. References: `discard_changes_dialog.dart`, `company_picker.dart`, `type_to_confirm_dialog.dart` (destructive), `merge_client_dialog.dart` (dropdown → no hint).

**Centered single-action buttons must constrain their own width too.** The same `Size.fromHeight(44)` (= `Size(double.infinity, 44)`) default makes a bare `FilledButton` stretch full-width — wrong for an `EmptyState` action or any centered call-to-action (renders as one edge-to-edge bar). Pass `minimumSize: const Size(64, 44)` so it sizes to content. Don't create full-width `FilledButton`s outside a deliberately column-stacked form/footer context. Reference: the Reports empty-state "Run report" action in `lib/ui/features/reports/widgets/reports_body.dart`.

**Keyboard-shortcut discoverability.** `KeyCap` (`lib/ui/core/widgets/key_cap.dart`) is the shared keycap chip; `platformModifierLabel()` (`lib/ui/core/utils/platform_modifier.dart`) gives `⌘`/`Ctrl`. Holding the platform modifier reveals a bottom-center hint bar (`ShortcutHintOverlay`, mounted beside `ToastHost` in `main.dart`) listing the modifier shortcuts registered for the current screen. Register context shortcuts by wrapping a body in `ShortcutHintScope(hints: [ShortcutHint(keys: [...], labelKey: '...')], child: ...)` — the shell registers the globals (⌘K/⌘//⌘B/⌘,), `entity_edit_scaffold` adds ⌘S, `billing_doc_edit_fab` adds ⌘N. Hovering a button can surface its shortcut via `ShortcutTooltip(label:, keys:)` (used on the list New button, company switcher, and sidebar leader rows). Note `ShortcutTooltip` uses `Tooltip.richMessage`, so it isn't matched by `find.byTooltip('<message>')` — don't add it to a button whose tests locate it that way; keep a plain `tooltip:` there. New screens with a context modifier shortcut should add a `ShortcutHintScope`.

## Forms

### Enter to save

Pressing **Enter** in a single-line text field submits the surrounding form. Multi-line fields keep Enter for newlines — never submit from `maxLines > 1`.

Every edit/settings screen wraps its form body in `FormSaveScope` (`lib/ui/core/widgets/form_save_scope.dart`):

```dart
FormSaveScope(
  onSubmit: _onSave,     // same callback the Save button calls
  enabled: canSave,      // same flag — gates Enter while busy/invalid
  child: <form body>,
)
```

Reusable field widgets read the scope automatically (see `OverridableTextField`, `ClientEditField`). Raw `TextField`s with `maxLines == 1` should read `FormSaveScope.maybeOf(context)`, set `textInputAction: TextInputAction.done`, and pipe `onSubmitted` to `scope.trySubmit()`. Dialogs with a single text input + primary action: wrap the dialog body in `FormSaveScope` so Enter fires the primary action (login's password field is wired explicitly in `_PasswordField`, `lib/ui/features/auth/views/login_screen.dart`).

### Empty for blank numeric fields

Numeric edit fields seeded from a non-nullable `Decimal` must render **empty for zero**, not `"0"`. Use `decimalInputText(value)` (`lib/utils/formatting.dart`) when feeding a `Decimal` into an `EntityEditField`'s `initial:` — not `.toString()`. Reference: price / cost / quantity fields on `product_edit_screen.dart`. For money, prefer `Formatter.inputMoney(value, currencyId: ...)` (returns `''` for zero); `Formatter.inputAmount(value)` is the `num`-typed equivalent without forced precision.

### Searchable pickers

Any dropdown bound to a long list (countries, currencies, languages, industries, timezones — anything past ~20 options) **must** support type-to-search.

- **Plain pickers**: `SearchableDropdownField<T>` (`lib/ui/core/widgets/searchable_dropdown_field.dart`) — generic on the item type; takes `displayString` + `idOf` projections.
- **Settings pickers with cascade-override**: `OverridableSearchableDropdownField<T>` — same shape as `OverridableDropdownField`, use on settings pages.

Don't introduce new `DropdownButtonFormField`s for long lists. They're fine only for short fixed enums (~10 items max — Classification, Size, Custom Field Type).

**A picker that needs inline "create new \<entity\>" can't be a `SearchableDropdownField`.** Two of its properties defeat that, both silently: Flutter's `RawAutocomplete` only mounts the options overlay while the option list is **non-empty** (`_canShowOptionsView`, `autocomplete.dart`), so its `footerBuilder` is unreachable for a name that matches nothing — the one case inline-create exists for; and it renders a **disabled** placeholder when `items` is empty, so an account with no rows yet gets a dead field. Build a dedicated `RawAutocomplete` that appends a synthetic create option (keeping the list non-empty), and route that option from `InkWell.onTap` plus an `onSubmitted` interceptor — **never** through `onSelected`, because `RawAutocomplete._select` early-returns on an unchanged selection and `optionsBuilder` doesn't re-run for unchanged text, so the row goes permanently dead after one cancelled create. References: `ClientPickerField` (`lib/ui/core/widgets/client_picker_field.dart`), `_ProductCell` (`line_item_editor/line_item_table_desktop.dart`, which still has the `onSelected` bug). `searchable_dropdown_field_test.dart` pins the footer limitation.

### Two-choice fields → radio, not dropdown

A fixed field with exactly two choices (occasionally up to ~4) uses a **radio group, not a dropdown** — both options stay visible instead of hiding one behind a tap. Cascade-aware settings use `OverridableRadioField<T>` (reference: the `empty_columns` field on Invoice Design → General). Dropdowns stay correct for longer fixed enums (~10 items); past ~20 options it must be a searchable picker (above).

### Date and time fields

Single-date and single-time-of-day inputs go through `InDateField` (`lib/ui/core/widgets/in_date_field.dart`) and `InTimeField` (`lib/ui/core/widgets/in_time_field.dart`) — a typed `TextField` with a trailing picker icon; users type shortcuts *or* tap the icon for the Material modal:

- Date shortcuts: `today` / `tomorrow` / `yesterday` / `now`; signed offsets `+1`, `-7`; bare day `14`; short slash `5/14` (current year, US/EU order from the active pattern); compact `051426` (2-digit-year heuristic); plus ISO `2026-05-14`, the company's active format, and short/long fallbacks.
- Time shortcuts: bare hour `9` → `9:00`; compact `930` → `9:30`; AM/PM suffix `9p` / `9am`; plus `HH:mm`, `H:mm`, `h:mm a`.

Commit-on-blur + Enter; silent revert on parse failure (the picker icon is the fallback — no red-border noise). Placeholder hint and display format come from the active company `Formatter` (`formatter.settings.dateFormatId`, `.enableMilitaryTime`); without a `Formatter` the field falls back to ISO date and `HH:MM` time. **Parsing of typed input is locale-independent** — `9` always means `9:00`, `9p` always `21:00`; only display rendering switches between `HH:MM` and `h:mm AM`.

**Don't use `showDatePicker` / `showTimePicker` directly** for form fields — only one-tap *range* filters still warrant it (`DateRangePickerButton`, `lib/ui/features/dashboard/widgets/filters/`). Reference call sites for typed single-date / single-time inputs: time-log table (`lib/ui/features/tasks/widgets/edit/time_entry_table.dart`), time-entry editor sheet, project due-date field. Parsing rules live in `parseDateInput` / `parseTimeInput` (`lib/utils/formatting.dart`) — reuse those for the same shortcuts without the field chrome.

## Settings screens

Most new settings panels look like **Company Details** or **Device Settings**, never User Details. Both are FormSection-card layouts inside `SettingsFormShell(sections: [...])`; the difference is whether they're VM-backed and cascade-aware. Full skeletons (cascade-aware, company-only, device-local, tabbed shells, mixed fields) and conventions live in `docs/settings-screens.md`.

### Decision tree (5-second routing)

Ask: **"Does this field write to the server (`/api/v1/companies/...` or similar)?"**

- Server `company.settings.*` → **Company Details style** + `CascadeSettingsScaffold` + `Overridable*` widgets.
- Server `company.*` (top-level) → **Company Details style** + `SettingsPageScaffold` + plain widgets.
- Local controller only (theme, locale, biometric, …) → **Device Settings style** + `SettingsScreenScaffold`, no VM.
- Never the user-details `ListTile` shape (anti-pattern below).

Building a *custom* shell (e.g. tabbed like Company Details)? Reach for `SettingsCompanyScopedHost` instead of re-rolling the company-switch listener inline.

### Three styles

- **Cascade-aware** (`company.settings.*`): `CascadeSettingsScaffold` + a one-line `SettingsDraftViewModel` subclass + body of `OverridableTextField` / `OverridableDropdownField` / `OverridableSearchableDropdownField` / `OverridableMarkdownField`. The scaffold picks the right VM for the active `SettingsLevelController` (your factory at company scope; shared `ClientSettingsDraftViewModel` at client scope). Reference: `localization_screen.dart`.
- **Company-only** (`company.*` top-level, or mixed top-level + `company.settings.*`): `SettingsCompanyScopedHost<V>` → `SettingsPageScaffold<V>` directly, with plain `TextField` / `DropdownButtonFormField` / `SearchableDropdownField` calling `vm.updateCompany((c) => c.copyWith(...))`. Do **not** use `CascadeSettingsScaffold` here — it swaps to a client-scope VM where `updateCompany` is a no-op and edits get silently dropped. Reference: `company_details_shell.dart`.
- **Device Settings** (no server, no VM): `SettingsScreenScaffold` + `SettingsFormShell` + typed tiles (`ThemeTile`, `BiometricToggleTile`, …) that write directly to local controllers. Reference: `device_settings_screen.dart`.

### Width cap: every body under `/settings/...` goes through `SettingsFormShell`

`SettingsFormShell` (`lib/ui/features/settings/widgets/settings_form_shell.dart`) does the centering + 720 px max-width + outer scroll + outer padding. **Any screen routed under `/settings/...` renders its body through it** — including tab bodies inside an entity-edit scaffold (the gateway-edit tabs live under `/settings/company_gateways/.../edit`, use `EntityEditScreenScaffold` for chrome, but still wrap tab bodies in `SettingsFormShell` so they don't stretch full-width). Don't re-introduce a raw `ListView(padding: ...)` as the top-level body for a screen reached from the settings sidebar. (Clients / Products / Tasks correctly stretch full-width — they live outside `/settings/...`.)

### Anti-pattern: User Details ListView+ListTile shape

No raw `ListView` + bare `ListTile` layouts for new settings panels. Even single toggles or actions belong inside a `FormSection` so the sidebar reads as one design system. A `ListTile` wrapped in a typed control widget inside a `FormSection` is fine; the unwrapped `ListView`-of-bare-`ListTile`s with no card chrome is the anti-pattern. Read-only diagnostic and action-only screens follow the same rule (see `account_management/overview_screen.dart`, `advanced/system_logs_screen.dart`).

## Adding a new entity

The generic stack does most of the work. Five framework layers do the heavy lifting — touch them only to extend the framework, never to bend it for one entity:

- `BaseEntityApi<TList, TItem>` (`lib/data/services/base_entity_api.dart`)
- `BaseEntityRepository<TDomain, TApi>` (`lib/data/repositories/base_entity_repository.dart`)
- `BaseEntitySyncDispatcher<TItem, TInner>` (`lib/domain/sync/base_entity_sync_dispatcher.dart`) — wired in `wireEntities()` (`lib/app/services_entity_wiring.dart`), no per-entity subclass. Document-bearing entities spread `documentMutationHandlers<TInner>(...)` (`lib/app/services_document_handlers.dart`) into their `customActions` map.
- `GenericListViewModel<T>` (`lib/ui/core/list/generic_list_view_model.dart`)
- `EntityListScreenScaffold<T, VM>` / `EntityDetailScaffold<T>` / `EntityEditScreenScaffold<T, VM>`

`EntityRegistry` (`lib/domain/entity_registry.dart`) is the orchestrator: one entry per entity in `kWiredEntityModules` / `kDisabledEntityModules` (`lib/app/entity_modules.dart`) declares path, route, icon, parent/children, password-required mutations, sidebar metadata, and the four screen builders. Both files are entity-agnostic — adding an entity touches the module specs only.

Contract tests live in `test/data/repositories/_base_entity_repository_contract.dart` — register the fixture at the top of your `<entity>_repository_test.dart` for the universal coverage.

### The 13-step recipe (summary)

1. API DTO (`<entity>_api_model.dart`)
2. Domain model (`<entity>.dart`)
3. Drift table (`<entity>_table.dart`)
4. DAO + `CompanyScopedDao` mixin
5. Service (`<entity>s_api.dart` — plural)
6. Repository
7. List + Detail + Edit ViewModels
8. List + Detail + Edit screens (thin wrappers around the generic scaffolds)
9. Entity module spec in `kWiredEntityModules` (`lib/app/entity_modules.dart`)
10. DI: one block in `wireEntities()` (`lib/app/services_entity_wiring.dart`) — build the API + repo, call `wire<FooItemApi, FooApi>(type: EntityType.foo, api:, repo:, customActions:)`. Document-bearing → `customActions: documentMutationHandlers<FooApi>(...)`. Bundled → append a closure to `bundleAppliers`.
11. Branch order in `kBranchOrder` (append-only)
12. Actions + 7 translation keys (entity translation completeness test enforces)
13. Tests: contract fixture + entity-specific mapper / filter / conflict tests

Full step-by-step shapes, "Standard action helpers" factories, the "Non-standard actions" pattern (e.g. Invoice `markPaid` via `customActions:`), and the bundled-entity alternative live in `docs/adding-an-entity.md`. Clients and Products are the reference invocations to mirror.

## Sync — non-obvious rules

- Outbox FIFO is **per company, strict global id order** in M1 (only one entity type exists). The stronger "per (company, entity_type)" guarantee is needed once M2+ introduces cross-entity references with retry-driven head-of-line blocking — revisit `OutboxDao.nextReady` then.
- Every outbound request sends `Idempotency-Key: <uuid from the outbox row>` so retries are safe. Generated once at row creation; never regenerated.
- Logout / company-switch with pending non-dead outbox rows **prompts** the user (sync now / discard / cancel) — never silently drops user data.
- Destructive ops (delete, purge, password change) require `X-API-PASSWORD-BASE64`. Password is captured by `ConfirmPasswordSheet`, held in a 5-min in-memory cache.
- **412 Precondition Failed = password-required.** Body is `{"message":"Invalid Password", …}`. `ApiClient._raiseFromResponse` maps it to `PasswordRequiredException`; `SyncEventListener` surfaces `ConfirmPasswordSheet` for outbox-parked mutations. The 403 password-message sniff stays as a defensive fallback. `GET /api/v1/users/{id}` is 412-gated — User Details routes around it via `/refresh` (see § Strict rules). **`PasswordRequiredEvent` fires on a row's FIRST 412 only**, and the row then walks the normal backoff to `dead` — the sheet does no server-side validation, so re-prompting every retry turned a cancel (or a typo, or an OAuth-only account with no password) into a modal every 5 minutes forever. `OutboxDao.readyPasswordRows` resurrects `dead` + `requires_password` + 412 rows so a password supplied later still heals them.
- 401 forces `AuthRepository.logout()` and a redirect to `/login`. **Single-flight**: parallel 401s wait on the same logout future.
- The `x-minimum-client-version` response header is checked on every request; below threshold throws `ClientTooOldException`.
- 422 validation errors carry `Map<String, List<String>> fieldErrors`. Edit forms surface these inline.
- **409 conflicts** are parked far in the future (1 year) instead of auto-retried. `ConflictResolutionSheet` either re-enqueues a fresh mutation or discards.
- **404 on outbox drain** is treated as a conflict (entity deleted server-side while we held a pending mutation). Same `Conflict` path applies — the sheet offers "delete locally" / "recreate".
- **Server-side list ordering / cursor.** `ApiClient.getList` reads `data.last` as a keyset high-water mark (`updated_at` + `id`). Caveat verified against the server source: the default list order is actually `id DESC` (`QueryFilters::ensureDefaultOrder`), **not** ascending `updated_at`, and `since_id` has no server handler — so the load-bearing paging mechanism is plain **offset** (`page`/`per_page`), and the cursor's `updated_at` is applied only as a `>=` delta filter (it narrows, never reorders). Page-by-page lists converge via id-keyed upserts + periodic full `refreshAll`; don't assume the cursor alone guarantees completeness.
- The local `is_dirty` flag is **layered onto the domain model** in `<Repository>._fromRow` (e.g. `ClientRepository._fromRow`) — `<Entity>.fromApi` defaults it to `false`, the repo overlays the value from the Drift row. Without the overlay, an unsaved edit shows up as clean after app restart.

## Data loading — bundled vs per-entity

Before adding a new module, decide how its data is fetched. Two buckets:

- **Bundled with the company on auth.** `/login` and `/refresh` accept `first_load=true`, which makes the server include company-scoped reference data alongside each company: tax rates, groups, designs, payment terms, expense categories, task statuses, subscriptions, schedulers, etc. The static catalog (currencies, countries, languages, industries, gateway types, date formats) is returned under `staticData` (`include_static=true`). `/refresh` already sends both — consume from that response, don't write a separate fetcher.
- **Loaded by their own routes.** High-volume, user-browsable entities: clients, invoices, products, payments, expenses, tasks, projects, quotes, credits, vendors, purchase orders, recurring invoices, etc. Full `BaseEntityApi` + page-by-page + Drift + outbox stack. Never bundle these into `first_load`.

Rule of thumb: small / mostly-read / company-shared / rarely-paginated (≲ a few hundred rows) → **bundled** (three-step seam in `docs/adding-an-entity.md` § Bundled entities: `CompanyEnvelopeApi` field + repo `applyBundle` + `AuthRepository.onPersistBundles` fan-out). The kind of list a user scrolls / searches / filters → **own route**, full per-entity stack. If unsure, probe `/api/v1/refresh?first_load=true&include_static=true` against the demo API — anything already there belongs in the bundled bucket.

**Bundled today**: the auth user record (`data[N].user`, written directly in `_persistAndActivate`), `task_statuses`, `company_gateways`. `applyBundle` is **upsert-only — never deletes** (`is_dirty=true` rows keep their outbox-bound payload until the next real sync); it advances the keyset cursor with `wasFullSync: true` so the screen's first `ensurePageLoaded` short-circuits.

## Sidebar counters

`lib/domain/sidebar_badge_modes.dart` is the single source of truth for what each sidebar row's count badge can count (`total` / `overdue` / `low_stock` / `assigned_to_me` / …, plus `none` to hide it). Every mode is answerable from columns already in Drift — **the badge never issues a network call**. Adding or changing one is three coordinated edits:

1. the per-entity `SidebarBadgeMode` list here (+ its `badgeModes:` reference in `kWiredEntityModules`),
2. a case in that DAO's `badgeModePredicate` (`BaseEntityDao`; `BankTransactionDao` hand-rolls the same hook),
3. the mode's `labelKey` in `kSidebarBadgeModeLabelKeys`, which the settings-search catalog spreads.

`sidebar_badge_count_test` fails the build if a declared mode has no predicate — the failure mode otherwise is silent, since a null predicate makes the badge count *every* row and still look like it works. Both pickers (the row's right-click menu and Settings → Device Settings → Sidebar counters) read the same registry list through `availableBadgeModes(...)`, so they can't drift apart.

Counts come from the **local Drift cache**, which after login holds page 1 per entity and fills in as the user browses (or runs Sync) — so on a large account a counter can under-report, exactly as the plain total always has. Making it exact needs a server-side count; `ApiClient.getList` currently discards the response `meta`.

Second known staleness: `Date.today()` is baked into the SQL when a badge stream is built, and a sidebar stream lives for the whole session — so **leaving the app open past midnight keeps the date-sensitive counters (invoice/client/project `overdue`, quote `expired`) on yesterday's date** until a restart or company switch. The list filter chip has always had this property; it's just more visible on a permanent surface. Fixing it needs a date-rollover trigger to re-key the streams — deliberately not built.

Note `BaseEntityDao.watchBadgeCount` counts **active** rows (`archived_at IS NULL`), unlike the older `watchCount`, which is archived-inclusive and still backs list empty-states.

## Localization

- Source of truth: **Transifex** (`explore.transifex.com/invoice-ninja/invoice-ninja`).
- Files in the zip are PHP arrays (`textsphp-<locale>.php`).
- `tools/import_transifex_zip.dart <zip>` parses those PHP files for locales in `kSupportedLocales` and writes `assets/i18n/<locale>.json`.
- Workflow per release: download zip → run the importer → commit the changed JSONs.
- Runtime: `Localization` loads the active locale's JSON from `rootBundle`. English is always loaded as a fallback. There is **no** server fetch and **no** override table — the bundle is the only source.
- Adding a locale = (a) add it to `kSupportedLocales`, (b) re-run the importer.

## Rich text editing

`lib/ui/core/widgets/markdown_text_field.dart` is the shared WYSIWYG editor for markdown-bearing settings (e.g. email/invoice template overrides). It wraps `super_editor` + `super_editor_markdown`, both pinned via `dependency_overrides` to the same monorepo HEAD so editor and serializer stay in sync.

- **One-way data flow.** Parent owns the markdown string and feeds `initialValue` + `externalValueKey`. The widget debounces edits (default 300 ms) and emits serialized markdown via `onChanged`. Force a reseed after an external write (e.g. an override toggle resetting to a cascaded parent value) by changing `externalValueKey` — the `(apiKey, value, isOverridden)` hash works well; see `overridable_markdown_field.dart`.
- **Server content is safe by construction.** `super_editor` deserializes markdown into Flutter's widget AST — no HTML/JS execution context. The `_sanitize` helper strips `<p>` / `<div>` / `<br>` residue from legacy Quill data.
- **No new editor instances.** Don't reach for `TextField` + markdown post-processing for a free-text field that needs formatting — reuse `MarkdownTextField`.

## Widget previews

The four widgets in `lib/ui/core/widgets/` (`EmptyState`, `ErrorView`, `StatusPill`, `LinkText`) carry `@Preview` annotations wired through `appPreviewTheme()` (`widget_preview_support.dart`), so previews render against the real `InTheme` tokens. Launch via the IDE's "Flutter Widget Preview" tab or `flutter widget-preview start`. Add new previews to design-system widgets only — feature screens depend on `Services` via `Provider` and aren't preview-friendly without scaffolding.

## Integration tests

`integration_test/app_smoke_test.dart` boots the real `InvoiceNinjaApp` with in-memory Drift + `InMemoryTokenStorage` and a `MockClient`, guarding the DI graph, router, theme, and localization wiring. On CI (manual `workflow_dispatch`) only the `integration-web` job runs it — `app_smoke_test.dart` on headless Chrome, and it is **blocking** (the old `continue-on-error: true` is gone; don't re-add it to quiet a red run). The macOS-desktop suite (incl. the live `demo/*` CRUD tests) is **local/manual only**: a headless hosted runner has no Metal device (`MTLCreateSystemDefaultDevice()` is nil) so the desktop app can't launch, so it runs via `tools/run_integration_local.sh`, not on CI.

**Don't run integration tests locally unless the user explicitly asks** — they take over the foreground app and interrupt the developer's session. The on-request procedure (isolated worktree on a throwaway branch, the `flutter#135673` local-run workaround, widget-key and mocking conventions) is in `docs/integration-tests.md`.

## Diagnostics log

Debug-only on-disk capture (`getApplicationSupportDirectory()/claude-diagnostics.log`) so a future Claude session can read what went wrong without copy-pasted console output: uncaught Flutter/async errors and every `Logger` record at `WARNING` or higher. Wired in `lib/app/diagnostics_log.dart` + `lib/main.dart`; surfaced in Settings → Advanced → System Logs (which also has an "Append outbox snapshot" button for stale rows). **Disabled in release builds and on web.**

The user can say *"read the diagnostics log"* — the path resolves at runtime per platform, so get it from System Logs (copy button), the boot log line, or the macOS path convention. Full layout, rotation, capture details, and the path-resolution sources are in `docs/diagnostics.md`.

## Desktop window state

Each desktop runner persists window size, position, and fullscreen across launches via the host OS's native preference store — one short native function per platform, no Dart/Flutter package. **N/A on web** (the browser owns the window chrome). The shared three-step contract and per-platform implementations (macOS + Windows done; Linux when added) are in `docs/desktop-window-state.md`.

## Web

Web is a supported target (`flutter run -d chrome`, `flutter build web`). Native (iOS/macOS) behavior is **byte-identical** — every platform difference is a `kIsWeb` branch or a conditional-import seam that resolves to the unchanged native code on native.

**Persistence.** drift WASM over IndexedDB/OPFS, unencrypted (no SQLCipher, no `PRAGMA key`) — the browser origin sandbox is the trust boundary, a locked product decision; don't add a web encryption layer without re-deciding. The auth token lives in `window.localStorage` (`LocalStorageTokenStorage`), not `flutter_secure_storage`. IndexedDB eviction (storage pressure / private mode) surfaces as the existing `dbWasReset` "fresh sync" flow, not a crash.

**Conditional-import seams** (default file = web, `if (dart.library.io)` override = native):
- `lib/data/db/database_opener.dart` → `_io` (SQLCipher file + keychain key + `.broken.<ts>` recovery) / `_web` (`WasmDatabase` + IndexedDB delete on reset). `pruneBrokenDbFiles` is native-only (`database_opener_io.dart`).
- `lib/data/services/token_storage_factory.dart` → `defaultTokenStorage()`: `SecureTokenStorage` (native) / `LocalStorageTokenStorage` (web).
- `WebBiometricService` (`biometric_service.dart`) — `isAvailable() => false`; selected via `kIsWeb` in `Services.build`. Biometric/lock UI hides itself.

**Vendored WASM assets** (committed in `web/`, served from app root): `web/sqlite3.wasm` (plain unencrypted build, from the [sqlite3.dart releases](https://github.com/simolus3/sqlite3.dart/releases) — must match the resolved `sqlite3` Dart package version) and `web/drift_worker.js` (`dart compile js -O4 -o web/drift_worker.js web/drift_worker.dart`). **Regenerate both on any `drift`/`sqlite3` bump** — version skew between the vendored assets and the Dart packages is the #1 web runtime failure mode. `database_opener_web.dart` logs `WasmDatabase` `missingFeatures` at boot.

**URL strategy: hash (`/#/clients`), the Flutter default.** Intentionally left as-is (no `setUrlStrategy`) so the build deploys to any static host with no rewrite-to-index config. Locked decision (see the comment near `runApp` in `main.dart`) — don't switch to `PathUrlStrategy`.

**`dart:io` compiles on web.** Flutter's web toolchain provides a compile-time `dart:io` stub; `import 'dart:io'` does **not** break `flutter build web` — the classes (`File`, `Directory`, `Platform`) throw `UnsupportedError` only when *used* at runtime, so a `kIsWeb` guard before the call suffices (no conditional-import file needed just for the compiler). Prefer `defaultTargetPlatform` + `kIsWeb` over `Platform.isX` in new code (`env.dart` / `support_api.dart` are the reference).

**Disabled on web** (already guarded): native splash/window theming, biometric, in-app purchase (upgrade routes web→Stripe portal via `upgrade_launcher`), Google + Apple OAuth login buttons (email/password only — there is no in-app OAuth callback handler).

**Backend dependency:** web writes are blocked until the API server adds `Idempotency-Key` to its CORS `Access-Control-Allow-Headers` (every outbox write sends it). Verified missing on the demo server — full spec + acceptance check in `BACKEND.md` § Web platform CORS. Until it ships, web is read + login only; outbox drains fail at the network layer. No client change needed (the header is correct and required on every platform).

**Demo build.** The pre-authenticated GitHub Pages demo (`https://hillelcoren.github.io/admin/`) is produced by `tools/build_demo_web.sh` — a `--wasm` build based at `/admin/` with a baked demo token (`Env.demoApiToken` → `AuthRepository.loginWithToken`, inert in any build without the `--dart-define`). Full procedure + the `.nojekyll` requirement: `docs/setup.md` § Demo web build. CI builds web with `--wasm` so WebAssembly compatibility stays gated. The deploy script stamps a `?v=<content-hash>` cache-bust token onto the app entrypoints (`flutter_bootstrap.js` + `main.dart.{wasm,mjs,js}`) so a single browser refresh picks up a redeploy despite GitHub Pages' fixed filenames + `max-age=600` (no custom headers); `canvaskit/` engine files are left un-busted (immutable per SDK) — keep that stamping if you edit `build_demo_web.sh`.

## Release Notes

When the user asks for "release notes" (or "releasenotes"), generate the notes for the **next** version of the app and print the markdown in chat. Do not create a GitHub release/tag and do not bump version files unless explicitly asked separately. Follow the established style at <https://github.com/invoiceninja/flutter/releases>.

**Steps:**

1. **Find the last release and next version.** The authoritative last release is the latest git tag: `git tag --sort=-creatordate | head -1` (e.g. `v5.1.5`), cross-checked against `version:` in `pubspec.yaml` and `kClientVersion` in `lib/app/version.dart` (and `gh release view --json tagName,name` if GitHub Releases are in use). Versions are `vMAJOR.MINOR.PATCH`. The next version is a **patch bump** by default (`v5.1.5` → `v5.1.6`); only use a minor/major bump if the user asks.

2. **Review changes since the last release.** Run `git log <last-release-tag>..HEAD --oneline`. If the tag is missing locally (local tags can lag GitHub), run `git fetch --tags` first. Read the actual commits closely enough to describe each change accurately; for a referenced issue/PR you can read it with `gh issue view <n>` / `gh pr view <n>` for a clearer summary.

3. **Write short, user-facing bullets** matching the house style:
   - Bullet list only, each prefixed with `Added:`, `Updated:`, or `Fixed:`. No emoji.
   - Keep it short and sweet (aim for ~1-7 bullets). Describe user-facing impact, not implementation details.
   - Skip internal-only commits (test-only changes, version bumps, CI, dependency bumps, no-op refactors).
   - Merge related commits into a single bullet.
   - When a commit references an issue/PR number (e.g. `#7`), link it inline: `[#7](https://github.com/invoiceninja/flutter/issues/7)`.

4. **Output.** Print the version as the title followed by the bullet body, as markdown in chat, ready to paste into GitHub's release form.

**Example output:**

```
v5.1.6

- Added: Keyboard shortcuts across the app for faster navigation and saving.
- Updated: Login now supports a shared login secret.
- Fixed: Adding a payment to an invoice now marks the invoice as paid [#7](https://github.com/invoiceninja/flutter/issues/7)
```

## Reference points

Four read-only sources to mirror, never copy from:

- **`/Users/hillel/Code/admin-portal`** — the previous Flutter (Redux) admin app:
  - `lib/data/models/client_model.dart` — Client field set.
  - `lib/data/web_client.dart` — header set (213-231), version negotiation (245-258), demo mode (31, 266).
  - `lib/redux/auth/auth_middleware.dart` (102-120) — login response envelope.
  - `lib/redux/static/static_state.dart` — shape of the `/api/v1/statics` response.
  - `lib/redux/settings/settings_state.dart` (93-99) — settings cascade resolver.
  - `lib/data/models/entities.dart` — full EntityType enum + parent/child relationships.
- **`/Users/hillel/Code/react`** — the React web client. A second reference for entity shapes, request flows, and UI behaviors when admin-portal is unclear or out of date.
- **API reference** — <https://invoiceninja.github.io/docs/api-reference/invoice-ninja-api-reference>.
- **`/Users/hillel/Code/invoiceninja`** — the **latest Invoice Ninja backend code** — the **live Laravel API server source** (official `invoiceninja/invoiceninja`, branch `v5-develop`, kept current — what the backend partner actually ships). Authoritative answer to any API-contract question — accepted params, `include=` sets, transformer field shapes (`app/Transformers/`), validation `in:` lists (`app/Http/Requests/`), filter/order semantics (`app/Filters/`) — faster and surer than probing the demo API. Read the PHP; never copy from it. (`…/invoiceninja-fork` is the user's **personal fork for authoring upstream PRs** — it sits on feature branches and can go out of date, so don't read it for current contract; always use the canonical `invoiceninja` checkout above.)

Live-server probes go through `demo.invoiceninja.com`'s canned read credentials — see `docs/probing-the-demo-api.md` for the curl recipe and the 412 password-gate heads-up.

## Settings search catalog

`lib/ui/features/settings/settings_search_catalog.dart` is the single source of truth for the settings sidebar (`kSettingsSections`) AND the in-app search (`kSettingsSearchCatalog`). Whenever you add / rename / remove a user-facing field under `lib/ui/features/settings/views/**`, update its `kSettingsSearchCatalog` entry — `search_catalog_consistency_test` enforces both ends match. Full conventions (section keys = route slugs, field entries = localization keys, the `kFooSearchKeys` co-location pattern) and the related "custom fields live in one home only" rule are in `docs/settings-screens.md`.
