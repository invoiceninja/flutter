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
| Sync / outbox / 400-401-403-404-409-412-422 behavior | § Sync — non-obvious rules |
| Bundled vs per-entity data loading | § Data loading — bundled vs per-entity |
| Architecture, write pipeline, project layout | § Architecture — at a glance + `docs/architecture.md` |
| Changing the Drift schema (forward migration) | `docs/migrations.md` |
| Adding / changing a sidebar count badge | § Sidebar counters + `lib/domain/sidebar_badge_modes.dart` |
| Adding / changing a list's status tabs | § List status tabs + `lib/domain/list_status_tabs.dart` |
| Adding a column to an entity list (or a custom-field column) | § List columns + `lib/domain/columns/` |
| Localization / Transifex import | § Localization |
| Cross-checking against legacy admin-portal / React / API docs | § Reference points |
| macOS entitlement, dev login pre-fill, platform targets | `docs/setup.md` |
| Building a release app / injecting the Sentry DSN | `tools/build_release.sh` (CLI) · `tools/xcode_inject_sentry_dsn.sh` + Runner scheme pre-actions (Xcode IDE archives) · `docs/setup.md` § Release builds with Sentry |
| iOS Product → Archive failing on a plugin's minimum platform version | `tools/prepare_ios_archive.sh` (run it first) · `docs/setup.md` § Release builds with Sentry · `docs/upstream-workarounds.md` § 8 |
| Writing release notes for a new version | § Release Notes |
| Setting up store deploys / CI signing secrets | `docs/store-deployment-setup.md` (runbook) · `docs/setup.md` § Shipping to the stores (reference) |
| Regenerating app icons (Windows / web / Snap) | `dart run tools/gen_app_icons.dart` · `docs/setup.md` § App icons |
| Probing the demo API for live response shapes | `docs/probing-the-demo-api.md` |
| Server-side filter gaps / required API changes | `BACKEND.md` |
| Running integration tests | `docs/integration-tests.md` |
| Editing a CI / release workflow (test gate, job wiring) | `.github/workflows/_test.yaml` + `docs/setup.md` § Shipping to the stores |
| Debugging a runtime error or stale outbox row | § Diagnostics log + `docs/diagnostics.md` |
| Desktop window persistence (native runners) | `docs/desktop-window-state.md` |
| Sharing a link to a record, or handling an incoming one | § Deep links |
| Contacts sync (client contacts → device address book) | `docs/contacts-sync.md` |
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
- **`lib/data/**` must not reach `lib/ui/**` — not even transitively.** Enforced by `test/lint/layering_test.dart`. This was a real regression, not a hypothetical: six imports of `lib/domain/columns/<entity>_columns.dart` (for `static const String` id constants, in files that also build Widgets and import `app/router.dart`) put **917 of 1,602 files — 57% of `lib/`, every DAO and `app_database.dart` included — into one strongly-connected import cycle**. Opening `client_repository.dart` compiled 1,395 files, 929 of them UI, so every data-layer test built the whole app. The column id constants now live in `lib/domain/columns/ids/<entity>_column_ids.dart`, which **imports nothing**; each `<entity>_columns.dart` re-exports its leaf so UI call sites are unchanged, and `bank_transaction_dao.dart` re-exports it for the same reason. A DAO that needs to validate a sort field uses the leaf's `k<Entity>ColumnIds` set, never the Widget-bearing `<entity>ColumnsById` map; `test/domain/columns/column_ids_match_registry_test.dart` keeps the two in lockstep (the drift is silent otherwise — a new column renders fine but sorting by it degrades to name-order in release). The failure mode this rule exists for analyzes clean, builds clean, and passes every other test.
- **CI runs in UTC; the dev machines here don't.** Any test fixture whose expectation depends on a *calendar day* or a *wall-clock time* must sit far from midnight UTC — the ~11:00–13:00 UTC band is the same local day from UTC−11 through UTC+10. Anything built on `DateTime.toLocal()` is affected; task time-log grouping (`_isoDay`, `lib/domain/tasks/task_invoice_notes.dart`) is the live example, where a fixture 2 hours before midnight UTC is one local day on a UTC+2 laptop and two on CI. Green locally is not green on CI — check a date/time-sensitive test with `TZ=UTC flutter test <file>` before pushing.
- **Don't run integration tests locally unless the user explicitly asks** — they take over the foreground app and interrupt the session. Never run them proactively or as incidental verification; let CI run them. On-request procedure: `docs/integration-tests.md`.
- **`FEATURES.md` is the parity tracker — keep it current.** It compares every user-facing feature across React (`/Users/hillel/Code/react`), Flutter v1 (`/Users/hillel/Code/admin-portal`), and this rebuild. When a PR flips a row to ✅ in the Flutter v2 column, update that row in the same PR; a feature with no React/v1 precedent gets a fresh row (`—` / `—` / `✅`); a scaffolded-but-incomplete screen is 🟡, not ❌. Hand-edited — don't generate it. Legend: ✅ done end-to-end, 🟡 partial/scaffolded, ❌ not implemented, — N/A.
- **Pub packages OK; npm / pip / brew etc. require explicit approval.** A Dart/Flutter dep via `pubspec.yaml` + `flutter pub get` is fine — that's the project's package surface and reviewers see the lockfile diff. For anything outside that (`npm`, `pip`, `brew`, `gem`, `cargo`, system installers) stop and ask first, so a stray tool can't silently shift the build environment.
- **Never add a Claude / AI `Co-Authored-By` (or any "Generated with" / assistant) trailer or line** to commit messages or PR bodies. Commit messages contain only the human-authored description. This overrides the harness default.
- **Never create, switch, rename, or delete git branches in this working tree** (no `git branch`, `git checkout <branch>`, `git switch`). Multiple Claude sessions share this single checkout; a branch create/switch in one corrupts every other in-flight session. Work on whatever branch is checked out; commit there only when the user asks; if a task seems to need its own branch, stop and ask. This overrides the harness default ("branch first"). **Sole exception:** the integration-test procedure (`docs/integration-tests.md`), which branches inside an *isolated sibling worktree*, never this checkout.
- **Android system back == the sidebar `←` (history back), and three things keep it working.** The app only ever calls `go()`, so no navigator can pop and Android used to kill the Activity from every entity detail screen (flutter#39). `SystemBackGate` (`lib/ui/features/shell/widgets/system_back_gate.dart`) binds the platform back event to `NavHistoryController` from the `StatefulShellRoute` page, so dialogs / sheets / pushed modals / the drawer / `/settings/**` / `/x/:id/edit` all still consume back first. Don't break: (1) **any** `ShellRoute` layout that renders something other than its `child` must still keep that child mounted — wrap it in `HiddenShellNavigator` (`MasterDetailLayout` on a bare list URL, `SettingsShell` on the wide `/settings` index) — because go_router dereferences every shell's `navigatorKey` with a bang while walking for a pop target, and an unmounted one throws; never mute its `TickerMode`, or the route the user just closed never finishes its pop and is never disposed; (2) the gate's `NavigationNotification` listener must stay — `WidgetsApp` applies the *last* notification it sees and an inner navigator swapping a page announces `canHandlePop: false`, so without the upgrade the fix works exactly once per screen; (3) a new "close / back" affordance must `go()` to the current location's **URL-parent** (or call `navHistory.back()`), because `isUpNavigation` is what makes the controller *replace* rather than append — otherwise back walks straight into the screen the user just closed. The pane's leading `←` stays structural *up* (`entityCloseTargetPath`); Back and Up are deliberately different. Full rationale: `docs/architecture.md` § Navigation.
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

**Touch targets are gated on the platform, not the viewport.** `InSizes.touchTarget` (44 — the app's long-standing button floor and the iOS HIG minimum) is applied when `Env.isTouchPrimary` is true, i.e. iOS/Android **including a mobile browser** (unlike `Env.isMobile`, which is native-only — don't reach for it here). Every other responsive branch in the app keys off width (bar one — see the next paragraph), but hit-area size is a property of the input device: a narrow desktop window still has a mouse, and a tablet at ≥600 px still has fingers. The sidebar (`InSidebar` → `SidebarNavItem` / `SidebarFooterActions` / `NavHistoryButtons`) reads the flag once and threads it down as an explicit `touch:` param, so the leaf widgets stay pure and pumpable. Note `touch` and `compact` (the 64 px collapsed rail) **do** co-occur — a tablet gets the persistent rail *and* a 44 px collapse toggle, so it reaches the collapsed touch rail in one tap; a comment claiming otherwise was wrong and is gone. Grow **width** only where the container has room — the 64 px collapsed rail overflows. Five traps if you extend this, each of which silently produces the wrong size rather than failing:

1. Express a row floor as `ConstrainedBox(minHeight:)`, never `SizedBox(height:)` — a fixed height clamps the label's line box and slices descenders at large text scale.
2. An `IconButton`'s explicit `constraints` are run through `visualDensity.effectiveConstraints` (M3 routes them into `ButtonStyle` `minimumSize`/`maximumSize`, then `button_style_button.dart` adjusts), so `compact` subtracts 8 and a `tightFor(44, 44)` renders **36**. Drop the density on touch; the theme default is already `standard` there.
3. `ThemeData.materialTapTargetSize` is `padded` on iOS/Android, which inflates an `IconButton`'s **layout** size (not just its hit area) to `kMinInteractiveDimension` = 48 and ignores your constraints. Pass `tapTargetSize: MaterialTapTargetSize.shrinkWrap` — the sidebar's icon buttons all do.
4. A `SidebarNavItem`'s `trailing` sits inside the row's `Row`, so it drives the cross axis and the row's own padding stacks on top: a 44 px trailing makes a 58 px row. Cap trailing widgets to the row's content box (target − vertical padding), not the target.
5. **A fixed-width slot holding `IconButton`s must be sized from the touch branch, and the buttons pinned.** Traps 2 and 3 each describe half of this; neither predicts the interaction. Left implicit, an `IconButton`'s layout box is floored at `kMinInteractiveDimension` + the density adjustment whenever `materialTapTargetSize` is `padded` (its default on Android/iOS) — 48 − 8 = 40 under `VisualDensity.compact`. Put two in a `Row` inside a tight-width box and the sum blows the box: silent in release, painting over the neighbour, with the overflowing edge outside the parent's bounds and therefore un-hit-testable. Fix it in one direction — pin the size with `IconButton.styleFrom(fixedSize:` + `minimumSize: Size.zero` + `maximumSize: Size.infinite` + `tapTargetSize: shrinkWrap)` (the zeroed min/max matter: `fixedSize` is clamped *by* them, and the M3 default `minimumSize` is 48), then derive the container width from the same number. `EntityActionsPopupButton` + `colWMoreMenu()` (`lib/ui/core/list/entity_list_constants.dart`) is the reference; it was invoiceninja/flutter#89.

**The company switcher is a control, not a label — never gate it out of existence.** `CompanyPicker` owns the app's **only** "New company" entry (`new_company` appears nowhere else in `lib/`), so hiding its entry point at `companies.length <= 1` locks a one-company owner out of ever having two — a self-locking failure that looks fine in every test. Issue #16 already removed one such gate (the button went inert below two companies, stranding a user whose roster had wrongly *shrunk*), and issue #104 asked for the same shape again for vertical space. The answer both times is **relocate, never hide**: the single-company mobile drawer drops `SidebarHeader` entirely and re-homes the switcher as `SidebarCompanyFooterAction` (`sidebar_footer_actions.dart`) while Sync moves into the toolbar row. Sign out is the softer half — Settings → User Details has one too, and its `sign_out` search key makes it findable from the settings search and the command palette — but "New company" has no second home, so any future change here must keep a live path to the picker.

**A landscape phone is not a small desktop.** `Breakpoints.isPhone(context)` (`lib/ui/core/adaptive.dart`) — `Env.isTouchPrimary` **and** `MediaQuery.sizeOf(context).shortestSide < 600` — is the app's second responsive **layout** gate keyed on the device rather than the viewport. (`Env.isMobile` also gates *behavior* — `SelectionArea`, copy haptics — which is a different question.) Width can't answer this one: a phone in landscape is a ~890 px *window*, so the persistent rail comes up and its 232 still leaves a ~660 px pane, which every width test reads as "desktop" on a viewport only ~412 px tall — and the wide layout then spends that width on full-label chrome the handset can't carry (invoiceninja/flutter#51, where the dashboard's desktop top bar truncated the company name and wrapped its five buttons onto two runs). Both halves are load-bearing: without `isTouchPrimary` a short desktop window (890×412) matches on `shortestSide` alone. **Wire it in per screen, deliberately** — `Breakpoints.isWide` stays the default gate and the callers are a small, deliberate set (`DashboardScreen`, and `showCommandPalette`, which uses it to pick its whole presentation — a full-screen `Scaffold` page on a phone, the floating Spotlight card everywhere else — plus its keyboard-only hints); other wide layouts (`MasterDetailLayout`, entity lists) still hand a landscape phone the desktop branch.

**On a narrow viewport nothing above a screen owns a `Scaffold`, so every full-page host must bring its own — and a missing one costs keyboard avoidance, silently.** `ScaffoldWithNav`'s narrow (<600) branch is a deliberate passthrough ("each top-level screen renders its own Scaffold… avoids `Scaffold.of(context)` ambiguity"); its wide branch has one. `Scaffold` is the **only** thing that *resizes a screen* for `MediaQuery.viewInsets.bottom` — everything else that copes with the keyboard (the toast host, the bottom sheets, the date-range popover) pads by it by hand. Every `Scaffold(` in `lib/` relies on the default `resizeToAvoidBottomInset: true`; only the narrow pane below writes it out, because there it is the whole point rather than incidental. Miss it and the screen keeps its full window height under the on-screen keyboard, so `EditableText`'s caret reveal asks the ancestor `Scrollable` to make the caret visible, finds it already inside a viewport that extends *behind* the keyboard, and never scrolls: a field low in a long form is simply covered. That was invoiceninja/flutter#105 — the `MasterDetailLayout` narrow pane wrapped itself in a bare `Material`, and since the list's Scaffold is a **sibling** in that Stack (`Offstage`) rather than an ancestor, every entity edit / detail screen on a phone had none. It now builds a `Scaffold`; the wide branch deliberately does not (the shell's Scaffold owns the inset there, and the 600–1024 band goes through the narrow pane *under* that shell — nested Scaffolds can't double-inset, since the outer one hands its body `removeViewInsets(removeBottom: true)`). A route-by-route audit found no other gap: auth, dashboard, reports, activity, outbox, every entity **list**, every `/settings/**` screen and every `Navigator.push` destination build their own — bar `showCascadeFullScreenPreview` (`cascade_tabbed_settings_shell.dart`), which pushes a caller-supplied builder with no chrome of its own and is only safe today because every caller happens to bring a Scaffold and none has a text input. Two corollaries: a `Scaffold` body reads `viewInsets.bottom` as **0**, so padding by it in there is dead code — `templates_reminders_body.dart` has one such line that has never done anything, and note an `OverlayPortal` popover resolves inherited widgets from the *portal's* position, so a picker's open-direction math sees that zero too; and **`showModalBottomSheet` lifts nothing by itself** — a sheet with a text input must pad by `MediaQuery.viewInsetsOf(ctx).bottom` in its `builder`, which also fixes a `heightFactor` / `maxHeight` budget otherwise measured against the unshrunk screen. `line_item_picker_sheet.dart` is the reference; five sheets had forgotten it, two of them autofocusing their field.

**Pair related action buttons side-by-side**, not stacked — a `Row` with `SizedBox(width: InSpacing.md(context))` between them. Cancel sits next to the primary action, never above it.

**Spacing tokens `InSpacing.md` / `InSpacing.lg` are responsive context-aware static methods** (`lib/app/design_tokens.dart`), not const doubles — wider on desktop, tighter on mobile (`md`: 8 px narrow `<600` / 12 px wide `≥600`; `lg`: 12 / 16 px). Call with a `BuildContext`: `EdgeInsets.all(InSpacing.lg(context))`, `SizedBox(width: InSpacing.md(context))`. **Drop `const` from any wrapping `EdgeInsets` / `SizedBox` / `Padding`** — the value is no longer compile-time const (perf cost is nil: Flutter's `Element.canUpdate` matches on `runtimeType + key`, not `==`). `InSpacing.sm` (8 px) stays `const` for math contexts and small inter-icon gaps; `xs` / `xl` / `xxl` stay const too — not part of the responsive system.

**Bordered-card form sections use `InSpacing.lg(context)` interior padding by default.** That's what `FormSection`, `DashboardCardShell`, and the task-edit identity card use; new one-off bordered cards (`Container` with `tokens.border` + `BorderRadius.circular(InRadii.r3)`) match with `padding: EdgeInsets.all(InSpacing.lg(context))`. Column-aligned interior surfaces (table headers + rows + add-row tiles) use the horizontal value (`horizontal: InSpacing.lg(context)`) so cells line up with the section title. Card-to-card inset consistency is the point.

**Side-by-side dialog actions need a per-call `minimumSize` override.** A `FilledButton` / `FilledButton.tonal` / `OutlinedButton` inside `AlertDialog.actions` (or any `Row`) needs `style: FilledButton.styleFrom(minimumSize: const Size(64, 44))` (Outlined uses `Size(64, 40)`). The themes default to `Size.fromHeight(44)` = infinite width — right for column-stacked form buttons, but in a horizontal context `Row` crashes layout and `AlertDialog.actions` silently stacks via `OverflowBar`. Inline comments in `theme.dart` explain why.

**Dialog primary actions use `PrimaryDialogAction`** (`lib/ui/core/widgets/primary_dialog_action.dart`), not a hand-rolled `FilledButton`. It bakes in the `Size(64, 44)` override, `autofocus`, and a subtle trailing **Enter** affordance (a dimmed `↵` — the app's standard Enter glyph) so users learn Enter submits. `variant:` selects plain / `.tonal` / `.destructive`; keep `autofocus: false` when a text field should own focus (Enter still submits via `FormSaveScope`/`onSubmitted`), and `showEnterHint: false` when Enter can't/shouldn't fire the primary. Two non-obvious `showEnterHint: false` cases (they cause a *lying* hint otherwise): **dropdown-only dialogs** — `SearchableDropdownField` consumes Enter to pick an option and never calls `FormSaveScope.trySubmit()`, so a scope around it is dead; and **primaries that start disabled** (`enabled: x != null`) — a disabled button can't take `autofocus`, so Enter never reaches it. References: `discard_changes_dialog.dart`, `company_picker.dart`, `type_to_confirm_dialog.dart` (destructive), `merge_client_dialog.dart` (dropdown → no hint).

**Centered single-action buttons must constrain their own width too.** The same `Size.fromHeight(44)` (= `Size(double.infinity, 44)`) default makes a bare `FilledButton` stretch full-width — wrong for an `EmptyState` action or any centered call-to-action (renders as one edge-to-edge bar). Pass `minimumSize: const Size(64, 44)` so it sizes to content. Don't create full-width `FilledButton`s outside a deliberately column-stacked form/footer context. Reference: the Reports empty-state "Run report" action in `lib/ui/features/reports/widgets/reports_body.dart`.

**Keyboard-shortcut discoverability.** `KeyCap` (`lib/ui/core/widgets/key_cap.dart`) is the shared keycap chip; `platformModifierLabel()` (`lib/ui/core/utils/platform_modifier.dart`) gives `⌘`/`Ctrl`. Holding the platform modifier reveals a bottom-center hint bar (`ShortcutHintOverlay`, mounted beside `ToastHost` in `main.dart`) listing the modifier shortcuts registered for the current screen. Register context shortcuts by wrapping a body in `ShortcutHintScope(hints: [ShortcutHint(keys: [...], labelKey: '...')], child: ...)` — the shell registers the globals (⌘K/⌘//⌘B/⌘,), `entity_edit_scaffold` adds ⌘S, `billing_doc_edit_fab` adds ⌘N. Hovering a button can surface its shortcut via `ShortcutTooltip(label:, keys:)` (used on the list New button, company switcher, and sidebar leader rows). Note `ShortcutTooltip` uses `Tooltip.richMessage`, so it isn't matched by `find.byTooltip('<message>')` — don't add it to a button whose tests locate it that way; keep a plain `tooltip:` there. New screens with a context modifier shortcut should add a `ShortcutHintScope`.

**A chord is one cap per glyph, never a concatenated label.** `KeyCapRow` (`key_cap.dart`) is the unit — `KeyCapRow(keys: [platformModifierLabel(), '/'], label: context.tr('navigate'))` renders `[⌘][/] Navigate` — and it backs every hint surface: the hold-modifier bar, the palette's field chip and footer, the `?` dialog's key column, and both settings shortcut screens. A single `KeyCap(label: '⌘/')` reads as one key and paints `Ctrl/` with no gap on Windows and Linux (invoiceninja/flutter#103); `test/lint/keyboard_hints_use_keycaps_test.dart` fails the build on that shape and on two arrow glyphs in one literal. **Whitespace is the only separator** — no middots, no `+`: use `platformHistoryModifierGlyphs()`, not `platformHistoryModifierLabel()`, wherever the result becomes caps. `label` is an **already-localized string, not a key**, so `key_cap.dart` stays a leaf (`flutter/material` + `design_tokens.dart`) and each caller does its own `context.tr`; `dense: true` fits a narrow fixed-width popover. Two traps: `keys` means "the keys in this hint", not strictly a chord — the palette footer's `['↑', '↓']` is *either* arrow while the chip's `['⌘', '/']` is *both*, and where the difference must show (the `?` dialog) the caller renders one row per alternative joined by `tr('or')`, so **flattening an alternatives row into one chord silently turns "press either" into "press both"**; and a hint must never advertise a dead key — the palette gates its `↑↓`/`Enter` runs on `_recentMode || _results.isNotEmpty`, because a keycap makes a claim that grey 11-px text got away with mumbling.

**Inside a cap a key gets its printed name** — `Esc`, `Enter`, `Backspace` — with symbols only where the physical cap is one (`↑ ↓ ← → ⌘ ⇧`). That is what `KeyBinding._glyphForLogicalKey` emits for a rebind (it falls through to `LogicalKeyboardKey.keyLabel`), so a hand-written cap must match or one key gets two names across surfaces. The bare `↵` in `PrimaryDialogAction` / `FilterSuggestionMenu` is a **different tier** — an inline "press this" beside the control, never in a cap. Relatedly, **the bundled JetBrains Mono has no `↵`**: its `cmap` carries `↑ ↓ ← → ⌘ ⇧ ·` but not U+21B5, `⏎`, `↩`, `⌤`, `⎋` or `⌫`, so `KeyCap` carries `fontFamilyFallback: [kSansFontFamily]` — without it a symbol cap drops to Menlo / Segoe UI Symbol / Noto, a different face and metrics beside the cap next to it, and **no widget test can see it** (`flutter test` substitutes its own font). Check a new cap glyph against the bundled `cmap`. `KeyCapRow` also wraps in `MergeSemantics`, since `KeyCap` announces one screen-reader stop per cap (with an untranslated `'Key: '` prefix — a known gap); that merge is inert wherever the surface already sits in `ExcludeSemantics`, as `ShortcutHintOverlay` and the `re_editor` popover do.

**Task status colours resolve through `taskStatusColors`** (`lib/ui/core/utils/task_status_colors.dart`) — the list pill, kanban column dot, settings row dot, and settings live preview all call it; never parse `TaskStatus.color` inline. `''`, `#fff` and `#ffffff` all mean **unset**: the server creates a new company's four statuses with no colour (MySQL default `#fff`) and the API factory writes `''`. Unset + a recognised built-in name (`backlog` / `ready_to_do` / `in_progress` / `done`, matched against the active locale *and* English) maps onto the `draft` / `partial` / `sent` / `paid` token pairs so the defaults read grey / blue / amber / green; anything else unset stays `ink3`. A user-picked hex always wins.

**Initials avatars go through `InitialsAvatar`** (`lib/ui/core/widgets/initials_avatar.dart`) — the tinted rounded-square identity badge behind Client / Vendor list rows and the assigned-user badge on Task rows — with `initialsFor(name)` as the single Unicode-aware extractor (`\P{L}` strip, first + last word; returns **null** for a letterless identity like `#0009` so each caller picks its own fallback: the entity icon on the detail header, `'?'` on a list row). Seed on the entity **id**, never the display name, or a rename reshuffles the colour; tints come from `avatarTintFor` only. `UserAvatar` (`user_avatar.dart`) is the id→badge wrapper, resolving against the local roster exactly like its sibling `UserNameLabel` — an id the roster can't resolve stays a tinted `?` (an ex-employee's task is still *assigned*), which is deliberately not what `UserNameLabel` does with the same id. Two traps when a badge is a list row's `LeadingSelectSlot.defaultChild`: a `Tooltip` on it can never fire (hovering the slot swaps it for the selection checkbox — put the name in a column or on the detail screen instead), and it must keep the slot's 32×32 footprint even when there's nothing to show, so an unassigned Task renders a muted `person_outline` placeholder rather than collapsing and knocking the row's columns out of alignment.

**Toast strings are normalized centrally — don't hand-guard them.** `ToastController.show` (`lib/ui/core/widgets/toast_controller.dart`) collapses the message to a single trimmed line, keeps at most `kToastDetailMaxLines` non-blank detail lines, drops a blank-labelled action, promotes the detail into the title when the message is blank, and **queues nothing at all** when there's nothing renderable (returning `null`, plus a debug-only `Logger` warning with a stack trace so the producer shows up in the diagnostics log). That's the fix for a class of bug where a raw server string — `ApiException.message` is non-nullable, so `{"message":""}` arrives blank, and `ApiClient._raiseFromResponse` splices 240 raw bytes of a 5xx HTML page into it — painted a blank card stretched to ~2.4× normal height (`IntrinsicHeight` sizes the card to its text, and blank lines occupy full line boxes). Consequences for new code: **never rely on newlines in a toast *title*** (use `' · '` to join, as `import_export_screen._msg` does); don't add local `message.isEmpty ? … : …` guards — `Notify.error` / `Notify.warning` already fall back to `tr('an_error_occurred')`; and note the context-free path (`Notify.capture` → `toasts?.error(...)`) has **no** such fallback, so a captured-controller caller must pass a `tr()`-derived string, never a raw server one.

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

**Opening a picker that already has a value shows the whole list, and that takes two cooperating rules — don't remove either.** `RawAutocomplete` filters by the field's text, and the text of an untouched picker *is* the selected item's own name, so the naive reading offers back only the value the user already has; the ✕ (which also fires `onChanged(null)`) was the only escape. That was invoiceninja/flutter#34, and it applied to all ~109 call sites (plus 13 more through `OverridableSearchableDropdownField`), not just task Status. The fix: (1) `_isPristine` — while the text still equals the committed label the query counts as **empty**, so `optionsBuilder` returns the idle list; (2) an `onTap` bounce that writes the text away and straight back, because `RawAutocomplete` recomputes its options *only* on a text change (`_onChangedField`) and so a tap right after a selection would otherwise reopen nothing. Both are mirrored in `ClientPickerField`. Consequences worth knowing: the committed item is **hoisted to the top** of the idle list (it stays visible in a 250-row list, and the default highlight — row 0 — is then the current value, so Enter / Android's "Done" can't silently pick whatever sorts first); it carries a check and re-picking it routes through `unfocus()` rather than `onSelected`, because `RawAutocomplete._select` early-returns on an unchanged selection *before* hiding the overlay; and the hoist is **guarded** on `initialValue` still naming it, or the "add to a chip list" callers (`MultiEntityPicker` and friends, which keep `initialValue: null` and drop the picked item out of `items`) would re-offer what was just added.

**The options popover must not wrap itself in an `Align`.** `RawAutocomplete` already wraps `optionsViewBuilder`'s output in `ConstrainedBox(tight) → Align(topStart | bottomStart)`, and a bare `Align` shrink-wraps only under an infinite constraint — so one of ours would fill the whole bounding box, leave the SDK's alignment nothing to move, and strand an upward-opening popover at the top of the screen. Related: pass `optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace`, or a field low on a phone gets only the space beneath it, floored at a 48 px sliver.

**Touch gets a different picker without a different widget.** `Env.isTouchPrimary` grows option rows to `InSizes.touchTarget`, and a list of **≤6** options drops the soft keyboard via `keyboardType: TextInputType.none` (**not** `readOnly` — `EditableText._shouldCreateInputConnection` ignores `keyboardType` but honours `readOnly`, and since `flutter test` forces `TargetPlatform.android` that would break every `tester.enterText` into a short-list picker). Six, not the usual ~10 "short fixed enum" figure: at 10 the rule reaches pickers that mean to be typed into (the import/export column mapper says so in a comment) and the design pickers sit close enough that one extra custom design would silently flip it. Row height also scales with `MediaQuery.textScalerOf` — a fixed extent clips Inter Tight's descenders past ~1.14× text scale.

**A re-pick of the value the field already holds is a real command, not a no-op.** `RawAutocomplete._select` early-returns on an unchanged selection *before* hiding the overlay, so routing the committed row through it is a dead tap under a popover that stays open. The row calls `onChanged` and unfocuses directly instead — several callers depend on it (re-seeding a payment allocation's auto-filled amount, re-binding a stream, retrying a change their own handler vetoed, re-adding an item whose chip was deleted). Enter / Android "Done" deliberately does **not** do this: it dismisses, so the Done key can't silently re-add a chip-adder's last item.

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
- `BaseEntitySyncDispatcher<TItem, TInner>` (`lib/domain/sync/base_entity_sync_dispatcher.dart`) — wired in the entity's `_wire<Entity>(reg)` function (`lib/app/services_entity_wiring.dart`), no per-entity subclass. Document-bearing entities spread `documentMutationHandlers<TInner>(...)` (`lib/app/services_document_handlers.dart`) into their `customActions` map.
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
10. DI: one new `_wireFoo(reg)` function in `lib/app/services_entity_wiring.dart` (returning its `(api, repo)` record) plus one call from `wireEntities()` — build the API + repo, call `reg.wire<FooItemApi, FooApi>(type: EntityType.foo, api:, repo:, customActions:)`. Document-bearing → `customActions: documentMutationHandlers<FooApi>(...)`. Bundled → append a closure to `bundleAppliers`.
11. Branch order in `kBranchOrder` (append-only)
12. Actions + 7 translation keys (entity translation completeness test enforces) — including the mandatory `copyLink` action (`entity_copy_link_coverage_test` enforces)
13. Tests: contract fixture + entity-specific mapper / filter / conflict tests

Full step-by-step shapes, "Standard action helpers" factories, the "Non-standard actions" pattern (e.g. Invoice `markPaid` via `customActions:`), and the bundled-entity alternative live in `docs/adding-an-entity.md`. Clients and Products are the reference invocations to mirror.

### Action confirmations

A risky new action sets `confirm: true` on its `EntityActionItem` (plus `confirmSubject: _confirmSubject(x)` so the prompt names the record, `isDestructive: true` if it destroys data, and `confirmMessageKey:` when Transifex already has more precise copy than `are_you_sure`). The user-facing switch is Settings → Device Settings → Security → **Confirm actions**, device-local in `nav_state.confirm_actions` and **on by default** (invoiceninja/flutter#49).

Tag a verb iff it (a) fires a mutation immediately with no further UI step and (b) is outward-facing, financially significant, or hard to reverse — `approve`, `markSent`, `cancel`, `sendNow`, `autoBill`, and the shared `archive` / `delete` / `purge` factories. **Don't** tag one that already opens its own dialog (invoice `markPaid`, client `merge`/`purge`) or navigates to a screen with its own action button (`sendEmail` → the Send Email screen, `refund` → the refund screen) — a second prompt in front of those is worse than none. Bulk-toolbar items are `EntityActionItem`s too but stay untagged: `EntityListScreenScaffold._onBulk` owns that gate via `BulkAction.confirm`, and only for verbs that don't already stop for a password sheet or a prep dialog.

Every render surface must wire `guardedOnTap(context, item)` rather than `item.onTap` — it reads the preference at *tap* time, so a flipped switch reaches menus that are already built, and an untagged action never touches `Services` at all. Surfaces outside the item model (the Documents tab, Outbox → Discard, User → Archive) call `showConfirmActionDialog` (`lib/ui/core/dialogs/confirm_action_dialog.dart`) behind `services.confirmActions.value` themselves. That dialog autofocuses **Cancel**, never the confirm — a stray Enter must not complete the action it exists to guard.

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
- **This server does not 404 for a missing entity — it 400s.** `app/Exceptions/Handler.php` renders `ModelNotFoundException` as **400** `{"message":"No query results for model [App\\Models\\Quote] <id>"}` and emits **404 only** for `NotFoundHttpException` / `MethodNotAllowedHttpException` (`"Route does not exist"` / `"Method not supported for this route"`) — i.e. a 404 means *we* built a bad URL or verb. So `ApiClient._raiseFromResponse` sniffs the 400 body (`kEntityMissingMessageFragment`) to raise `NotFoundException`, and a bare 404 is a plain permanent `ServerException`. Getting this backwards was invoiceninja/flutter#36: any 404 opened the "record deleted on the server" sheet whose only forward option, Discard, **hard-deletes the local row** (`SyncEventListener._handleConflict` → `deleteLocalRecord`) — a client-side routing bug that destroyed user data. That branch is now gated on the explicit `ConflictEvent.isDeletedServerSide` flag, never on a status code; keep it that way. Entity-missing on drain still parks as a conflict (sheet: "delete locally" / "recreate"); on a delete/purge/archive the dispatcher still treats it as idempotent success.
- **A soft-deleted record can't be edited; an archived one can.** The server's guard (`ChecksEntityStatus::entityIsDeleted`, in 19 controllers) reads `is_deleted` **only**, so `PUT` on an *archived* row returns 200 and stays archived (verified live) — never add a client-side gate on editing archived records. A *deleted* row gets **400** `{"message":"Record is deleted and cannot be edited. Restore the record to enable editing"}` → `RecordDeletedException` → the row is marked dead carrying that message, and both the Outbox row and `SaveFailedBanner` drop the futile Retry and show the server's instruction. `isRecordDeletedRejection(statusCode, message)` re-derives this from a persisted row.
- **A rejected save must never be a dead end.** `SaveFailedBanner` renders whenever the VM holds a rejection (not just when `fieldErrors` is non-empty), always states the reason (`submitError` + every field-error message, including keys no field on the form renders), and offers **Retry** beside Discard. `GenericEditViewModel` keeps the 422's top-level message instead of nulling it, and `_hydrateFailedSync` replays a dead row's `last_error` / `last_status_code`, not only its `field_errors_json` — otherwise a non-422 death left the reopened form looking clean.
- **Server-side list ordering / cursor.** `ApiClient.getList` reads `data.last` as a keyset high-water mark (`updated_at` + `id`). Caveat verified against the server source: the default list order is actually `id DESC` (`QueryFilters::ensureDefaultOrder`), **not** ascending `updated_at`, and `since_id` has no server handler — so the load-bearing paging mechanism is plain **offset** (`page`/`per_page`), and the cursor's `updated_at` is applied only as a `>=` delta filter (it narrows, never reorders). Page-by-page lists converge via id-keyed upserts + periodic full `refreshAll`; don't assume the cursor alone guarantees completeness.
- **A narrowed fetch neither reads nor advances the cursor** — one predicate, `BaseEntityRepository.isNarrowedFetch`, backs both `shouldReadCursor` and `shouldAdvanceCursor`. Narrowing = parent scope, active search, any non-empty `extraFilters`, or a `states` set that isn't a baseline (`{active}`, `{}`, or all-states). Reading the cursor on a narrowed page ANDs `updated_at >= W` onto the user's filter, so the server returns only slice rows changed since the last sync — and after a Sync (W ≈ now) essentially nothing, leaving a false "No records found" a short list has no scroll extent to page out of. Advancing from one walks the shared watermark past rows the filter excluded. **Six repos hand-roll `ensurePageLoaded`** (invoice, quote, credit, recurring invoice, purchase order, group setting) — they must call `readCursorIfEligible`, not an open-coded gate; `list_pagination_wiring_test` fails the build otherwise. The two gates disagreed once and that was flutter#32.
- **`hasMore` is not the gate for widening the Drift window.** It answers "does the *server* have another page?", but the list renders entirely from Drift under `LIMIT pageSize * loadedPages` — so widening is gated on `GenericListViewModel.canLoadMore` (`hasMore || canWidenLocally`), where `canWidenLocally` means the last emission filled the window. Without it a filtered list latches `hasMore = false` early (a filter narrows the set, so page 2 comes back short) and can never widen again: a Sync lands rows in Drift the list can't reach, and only clearing the filter — which resets `loadedPages`/`hasMore` — brings them back. A local widen skips the network entirely. Under-counts for post-LIMIT filters (`tag_ids`, products `stock`), which converge via the auto-chain instead. A list VM's `pageSize` **must** equal its repo's (`=> repo.pageSize`) or the saturation check is wrong.
- **A bulk re-download re-arms mounted lists.** `refreshAll` and the Sync pass write only to Drift; nothing else told a list VM its paging state was stale. `GenericListViewModel.bindResync` (wired by `EntityListScreenScaffold` in `initState` *and* `_onSessionChanged`) re-arms on the pass's falling edge for its own company, and `refresh()` does the same after pull-to-refresh. Re-arm only — never `_resetAndReload`, which would snap a deep-scrolled user back to page 1. Corollary invariant: **never call `resync.run()` from a `build`**, since every bound list VM notifies on that edge.
- **Lists sort newest-first where the sort key is monotonic.** `GenericListViewModel.defaultSortAscending` defaults to `true` (right for name/key-sorted lists); invoice / quote / credit / purchase order / recurring invoice (`number`), expense / payment / transaction (`date`), and task (`updatedAt`) override it to `false` so a new record lands on page 1 instead of the bottom of the list. Only affects a list the user has never sorted — a persisted `nav_state` blob or saved view always wins.
- The local `is_dirty` flag is **layered onto the domain model** in `<Repository>._fromRow` (e.g. `ClientRepository._fromRow`) — `<Entity>.fromApi` defaults it to `false`, the repo overlays the value from the Drift row. Without the overlay, an unsaved edit shows up as clean after app restart.

## Data loading — bundled vs per-entity

Before adding a new module, decide how its data is fetched. Two buckets:

- **Bundled with the company on auth.** `/login` and `/refresh` accept `first_load=true`, which makes the server include company-scoped reference data alongside each company: tax rates, groups, designs, payment terms, expense categories, task statuses, subscriptions, schedulers, etc. The static catalog (currencies, countries, languages, industries, gateway types, date formats) is returned under `staticData` (`include_static=true`). `/refresh` already sends both — consume from that response, don't write a separate fetcher.
- **Loaded by their own routes.** High-volume, user-browsable entities: clients, invoices, products, payments, expenses, tasks, projects, quotes, credits, vendors, purchase orders, recurring invoices, etc. Full `BaseEntityApi` + page-by-page + Drift + outbox stack. Never bundle these into `first_load`.

Rule of thumb: small / mostly-read / company-shared / rarely-paginated (≲ a few hundred rows) → **bundled** (three-step seam in `docs/adding-an-entity.md` § Bundled entities: `CompanyEnvelopeApi` field + repo `applyBundle` + `AuthRepository.onPersistBundles` fan-out). The kind of list a user scrolls / searches / filters → **own route**, full per-entity stack. If unsure, probe `/api/v1/refresh?first_load=true&include_static=true` against the demo API — anything already there belongs in the bundled bucket.

**Bundled today**: the auth user record (`data[N].user`, written directly in `_persistAndActivate`), `task_statuses`, `company_gateways`. `applyBundle` is **upsert-only — never deletes** (`is_dirty=true` rows keep their outbox-bound payload until the next real sync); it advances the keyset cursor with `wasFullSync: true` so the screen's first `ensurePageLoaded` short-circuits.

## Sidebar counters

`lib/domain/sidebar_badge_modes.dart` is the single source of truth for what each sidebar row's count badge can count (`total` / `overdue` / `low_stock` / `assigned_to_me` / …, plus `none` to hide it). Every mode is answerable from columns already in Drift — **the badge never issues a network call**. The catalog now drives **two** surfaces — the rail's badge and the list's status tabs (below) — so adding or changing a mode is four coordinated edits:

1. the per-entity `SidebarBadgeMode` list here (+ its `badgeModes:` reference in `kWiredEntityModules`),
2. a case in that DAO's `badgeModePredicate` (`BaseEntityDao`; `BankTransactionDao` hand-rolls the same hook),
3. the mode's `labelKey` in `kSidebarBadgeModeLabelKeys`, which the settings-search catalog spreads,
4. a `ListStatusTabSpec` in `lib/domain/list_status_tabs.dart` — `list_status_tabs_test` fails the build if the two catalogs disagree, so a new mode can't quietly ship as a counter with no way to filter by it.

`sidebar_badge_count_test` fails the build if a declared mode has no predicate — the failure mode otherwise is silent, since a null predicate makes the badge count *every* row and still look like it works. Both pickers (the row's right-click menu and Settings → Device Settings → Sidebar counters) read the same registry list through `availableBadgeModes(...)`, so they can't drift apart.

Counts come from the **local Drift cache**, which after login holds page 1 per entity and fills in as the user browses (or runs Sync) — so on a large account a counter can under-report, exactly as the plain total always has. Making it exact needs a server-side count; `ApiClient.getList` currently discards the response `meta`.

Second known staleness: `Date.today()` is baked into the SQL when a badge stream is built, and a sidebar stream lives for the whole session — so **leaving the app open past midnight keeps the date-sensitive counters (invoice/client/project `overdue`, quote `expired`) on yesterday's date** until a restart or company switch. The list filter chip has always had this property; it's just more visible on a permanent surface. Fixing it needs a date-rollover trigger to re-key the streams — deliberately not built.

Note `BaseEntityDao.watchBadgeCount` counts **active** rows (`archived_at IS NULL`), unlike the older `watchCount`, which is archived-inclusive and still backs list empty-states.

## List columns

`lib/domain/columns/<entity>_columns.dart` is one registry per entity: an
ordered `kAll<Entity>Columns`, the `kDefault<Entity>Columns` subset shown
out-of-the-box, and a `<entity>ColumnsById` map. The user's selection lives in
`user_settings.table_columns` (**not** `nav_state`) in the same byte format the
legacy admin-portal uses, so **renaming a column id silently drops a user's
saved layout** — don't. (The one safe case is a constant no registry ever
referenced, i.e. one that cannot be in anybody's stored list: that is why
`ProjectFieldIds.customValue1..4` could become `custom1..4`.)

- **Every field the entity's edit screen can set earns a column** (that rule is
  what invoiceninja/flutter#106 was about), plus the shared metadata block:
  created / archived / state / deleted / documents / created-by / assigned user.
  Build those with the factories in `lib/domain/columns/column_factories.dart`
  rather than hand-rolling a fifteenth copy.
- **Real Drift column ⇒ `sortable: true` plus a `_sortExpression` case in the
  DAO. Derived or payload-only ⇒ `sortable: false` plus an entry in
  `sortable_columns_test`'s `displayOnly` map.** Every header is a sort control,
  and most DAOs throw on an unmapped field — `sortable_columns_test` detects the
  gap by catching that throw, so a DAO that falls back silently instead makes
  its own dead headers invisible (that is how `task.duration` shipped).
  **`ClientDao`, `VendorDao` and `UserDao` are the exceptions**: the first two
  assert against `k<Entity>ColumnIds` and then fall through to a generic
  `json_extract(payload, '$.<id>')` — which is what legitimately sorts their
  address / notes / contact columns, but also means the probe can never fail
  for them. Adding a sortable client or vendor column means checking the
  `_sortExpression` arm by hand; the id-set test only proves the id is *known*.
- **Custom-field slots go through `customFieldColumns` (`custom_field_columns.dart`),
  never a hand-written `custom1` column.** `GenericListViewModel.availableColumns`
  then decorates them per company: the header and picker show the *configured*
  label ("Region"), values format by configured type (date → company date
  format, switch → localized Yes/No), and an unconfigured slot is dropped from
  both. Read the label through `column.resolveLabel(context)` — a bare
  `context.tr(labelKey)` loses it. Note the slot **prefix is not the entity
  name**: quotes / credits / purchase orders / recurring invoices all read
  `invoice1..4`, and recurring expenses read `expense1..4`.
- Hiding a column is **never** destructive: `_resolveColumns` drops an id it
  can't render while `_columnIds` (and `user_settings`) keep it, and
  `EntityColumnPickerSheet` re-inserts it at its original index on Done.
- **Client and Vendor ids must also join `k<Entity>ColumnIds`** in
  `lib/domain/columns/ids/` — their DAOs guard `_sortExpression` on that set and
  degrade to name-order in release when an id is missing.
  `column_ids_match_registry_test` is the guard.
- A user-facing label needs a placeholder-free key: use `user` for created-by,
  never `created_by` ("Created by :name").

## List status tabs

A one-tap status strip above every entity list — `All / Draft / Unpaid / Overdue` on Invoices, and so on for the other 13 entities that declare status counters (invoiceninja/flutter#98: reaching a draft through the search field's filter menu cost three or four taps). It is a **view over the sidebar-counter catalog**, not a second one: `lib/domain/list_status_tabs.dart` adds only the tab *order* (lifecycle, deliberately not the badge lists' "most actionable first") and the optional server translation. Labels, tones and the inventory gate all resolve from the entity's own `badgeModes` at render time.

- **The count and the rows are one predicate.** The badge reads `watchBadgeCount(modeId:)`; the list passes `badgeModeId:` down VM → repo → DAO, where `BaseEntityDao.badgeModeListFilter` applies the *same* `badgeModePredicate` inside `watchPage`'s WHERE (pre-`LIMIT`, so the Drift window stays aligned with the page count). `list_status_tab_filter_test` asserts `rows == count` for all 14 entities × every mode; that test is the feature.
- **The whole state is `extraFilters['badge_mode'] = {modeId}`** — one key, so `currentSnapshot()` carries it into `nav_state` and saved views for free, `clearAllFilters()` resets the strip without knowing it exists, and the strip's selection is always literally that value (no second source to drift). It is **app-private and never reaches the wire**: `_serverExtraFilters()` strips it and splices in the entity's real query params instead.
- **A server mapping must return a SUPERSET of the local predicate.** Over-fetching is free (the local predicate discards the extras); under-fetching silently hides rows — the tab reads "Expired 12" over eight rows and the missing four never arrive. Where the obvious value is a subset, *widen* it (quotes send `client_status=expired,draft` because the app also counts a past-due draft as expired) rather than dropping to local-only. Eight modes are deliberately unmapped; each says why in `list_status_tabs.dart`, and `list_status_tabs_test` pins the exact set so mapping one later is a deliberate edit.
- **A widened mapping MUST be marked `widened: true`, and that flag is not bookkeeping.** `statusTabNarrowsLocally` — the gate on `localOnlyFilterActive`, i.e. on the auto-chain — is true for an unmapped tab **and** for a widened one, because in both the Drift predicate is still throwing rows away after the fetch lands. Gate the chain on "has no server mapping" instead and five tabs break the same way: a widened fetch fills page 1 with rows the local predicate discards (Quotes → Expired pulling 50 drafts to find 3 expired quotes), the emission is shorter than a page, there is no scroll extent for the load-more trigger, and the tab renders "Expired 3" over a false "No records found". Only an **exact** mapping — server clause and badge predicate select the same rows — leaves the chain off.
- **Don't map a mode whose only superset is nearly the whole table.** Payment / credit `unapplied` were mapped once (`completed,partially_refunded` and every non-draft status): no useful narrowing, and `isNarrowedFetch` then costs the delta cursor too. Local-only plus the auto-chain is strictly better there.
- **No strip on an embedded list** (`widget.embedded`): the counts are company-wide, so "Draft 47" on one client's Invoices tab would be a flat lie.
- **The strip renders whenever a tab is active, even with the device setting off** — a `badge_mode` restored from `nav_state` or applied by a saved view is a live filter, and hiding its only control would leave the list narrowed with nothing but "Clear filters" to escape. `_hydrate` drops a `badge_mode` naming a mode this build no longer offers, for the same reason `_migrateLegacyUpdatedBetween` exists.
- Counts are **active-only**, so the badges stand down (tabs keep filtering) when the list is showing archived / deleted rows, and they carry the same local-cache under-reporting caveat as the rail. A zero renders in the neutral palette whatever the bucket's tone — a red `0` would claim urgency about the one outcome that means there's nothing to do.
- Device-toggleable, default **on**: Settings → Device Settings → Status tabs (`nav_state.status_tabs`, schema v6, `StatusTabsController`).

## Localization

- Source of truth: **Transifex** (`explore.transifex.com/invoice-ninja/invoice-ninja`).
- Files in the zip are PHP arrays (`textsphp-<locale>.php`).
- `tools/import_transifex_zip.dart <zip>` parses those PHP files for locales in `kSupportedLocales` and writes `assets/i18n/<locale>.json`.
- Workflow per release: download zip → run the importer → commit the changed JSONs.
- Runtime: `Localization` loads the active locale's JSON from `rootBundle`. English is always loaded as a fallback. There is **no** server fetch and **no** override table — the bundle is the only source.
- Adding a locale = (a) add it to `kSupportedLocales`, (b) re-run the importer.
- **The upstream PHP is HTML-escaped — the importer decodes entities, don't bypass it.** Transifex ships `&#39;`, `&quot;`, `&gt;`, `&amp;`, `&eacute;` inside translated strings, and Flutter's `Text` has no HTML layer to undo them, so whatever lands in the JSON is literally what the user reads: Italian Settings showed `Colore dell&#39;accento`, French `Cl&eacute; d&#39;acc&egrave;s`. 504 strings across 7 locales shipped that way, invisible to the team because **English has zero entities**. `TransifexPhpParser.parse` now runs values through `decodeHtmlEntities` (`lib/l10n/transifex_php_parser.dart`, mirrored in the importer's own inline copy — keep them in sync). It is deliberately a **single pass** so `&amp;#39;` stays the literal text `&#39;` rather than double-decoding to an apostrophe, and it leaves unrecognized entities, bare `&`, and markup tags (`<p>`, `<br>`) alone. `test/l10n/no_html_entities_test.dart` fails the build if an escaped string reaches `assets/i18n/`.
- **`_app_pending.json` can only *add* a key, never override one.** Lookup order is active locale → `en.json` → pending → raw key, so a pending entry whose key already has a non-blank `en.json` value is dead and never renders. 41 such entries had accumulated — one of them (`fees_sample`) left the gateway fee preview naming the *total* as the fee. `no_unsubstituted_placeholders_test` now fails the build on a shadowed entry; give deliberate rewordings a distinct name (`*_label` / `*_short` / `*_detailed`).
- **Never render a string carrying a `:placeholder` without filling it.** Many Transifex keys ship in two flavours: a parameterised one for when the app knows the value (`add_to_invoice` = "Add to invoice :invoice") and a plain verb for when it doesn't (`action_add_to_invoice` = "Add To Invoice"). Pointing a menu label at the former leaks the raw token (invoiceninja/flutter#35). Fix one, in this order: **(1) pass the params** — usually possible and always keeps the translation (`copyToClipboard` fills `:value` this way, with a `label:` when the payload is a blob); **(2) point at a placeholder-free Transifex sibling** (`action_add_to_invoice`, `invoice_sent_notification_label`, `min_amount`); **(3) last resort, add a distinctly-named app-local key** — that file is English-only, so this costs every non-English user their translation, and it's only right when the bundle has no clean variant (`view_expense_label`, `download_documents_label`). **Don't blank the token and `.trim()`**: German and Japanese put `:invoice` mid-string, so that leaves a double space. `test/lint/no_unsubstituted_placeholders_test.dart` fails the build on a leak it can see; keys reached through a variable, a const list, or a positional arg are invisible to it, so a renderer that looks up keys from a structure needs the invariant asserted in that structure's own test (`settings_search_catalog_test` does this).

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

## Deep links

A record's actions menu offers **Copy Link**, which puts a shareable
`invoiceninja://` URL on the clipboard; following it opens the app on that
record, switching company first if the link came from another workspace
(invoiceninja/flutter#96). The same `app_links` subscription also carries the
calendar OAuth return, which is what it was originally built for.

```
invoiceninja://app/<in-app route, leading slash dropped>?company=<companyId>
invoiceninja://app/clients/Wpmbk5ezJn?company=Xrtq1oa8Aq
```

**The whole route lives in the URI path, behind a constant `app` host.** That
is not cosmetic: `Uri.parse` lower-cases a reg-name host (`_normalizeRegName`
in the SDK's `uri.dart`) and never the path, and entity ids are case-sensitive
hashids — so encoding the route *as* the host would work only for as long as
every `routePath` happens to be lowercase snake_case, and would fail silently
the day one isn't. The constant host also keeps record links in a different
namespace from server-owned OAuth-return hosts (`calendar_connection`), which
is what lets Android keep **host-pinned** intent filters instead of claiming
the whole scheme.

Four pieces, deliberately split:

- `lib/app/entity_links.dart` — a **leaf** (imports only the registry) holding
  `buildEntityDeepLink` / `parseAppDeepLink` / `parseCalendarCompleteLink`, plus
  `entityRecordPath`, which lives here and is re-exported from `router.dart` so
  link building doesn't drag in the router's whole UI graph. Build uses
  `entityRecordPath`, so a shared link opens exactly what tapping the row opens
   — **never `entityDestination`**, whose `user`/`company`/`design` cases point
  at the reader's own settings screens rather than a record.
- `lib/app/deep_link_router.dart` — `Services.deepLinks`, the arrival
  choreography. Takes only the auth slice it needs (session + lock listenables
  + an `isAuthenticated` predicate) so it is testable with plain fakes, and
  `attach(go:, contextOf:)` wires navigation once `MaterialApp.router` exists.
- `lib/app/app_deep_links.dart` — the platform bridge (`app_links`), which only
  transports URIs into `deepLinks.open`. The **command palette is the second
  source**: paste a link into ⌘K and it routes through the same `open`. That is
  the only way to follow a link on web and Linux (neither ever receives one from
  the OS) and the fallback wherever a messenger renders the scheme as inert text.
- `lib/ui/features/shell/widgets/switch_company_guarded.dart` — the company
  switch, shared with `CompanyPicker` so a link can't fork it (trap 4).

Five things fail silently if you change this:

1. **Every platform delivers a cold-start link twice** — Android, iOS, macOS and
   Windows all replay the cached `initialLink` into the stream on `onListen`
   *and* return it from `getInitialLink()`, and the bridge subscribes to both.
   Harmless for the calendar return; for a record link it means two
   unsaved-changes prompts and two pending-outbox prompts. `_pending` de-dups
   and `_inFlight` serialises two *different* links arriving mid-dialog. Scope
   `_pending` to what is **in flight**, never to history: the palette feeds the
   same `open`, where re-following a link is an ordinary user action, and a
   history guard silently killed it for the rest of the session.
2. **`parseAppDeepLink` drops the entire query string**, not just `company`.
   `stripTransientQuery` only knows `module_off` and `view=full`, so anything
   else would be written into `nav_state.current_route` and replayed on every
   cold start.
3. **Nothing modal runs before the auth + biometric gate.** The lock screen is
   an ordinary `Scaffold` — a `showDialog` lands right on top of it — so a link
   arriving while signed out or locked is *held* and replayed once both clear.
   This is also why there is no `/login?from=` round-trip: a route can't carry
   the company, and holding the parsed link can. **The gate must listen to
   `auth.credentials`, not just `auth.session`**: `AuthRepository` assigns
   `_session` before `_credentials` on both login and `restore()`, so a gate
   that reads `isAuthenticated` (credentials) while waking on the session edge
   sees `false`, drops the link, and then replays it minutes later off an
   unrelated background refresh. `main.dart` merges `credentials` first into the
   router's own `refreshListenable` for the same reason. And a held link is
   dropped on logout (`deepLinks.reset()` from `onBeforeLogout`) — it belongs to
   the account that was signed in when it arrived.
4. **A company switch goes through `switchCompanyGuarded`**
   (`lib/ui/features/shell/widgets/switch_company_guarded.dart`, shared with
   `CompanyPicker`), never `auth.switchCompany` directly — the unsaved-changes
   and pending-outbox prompts are non-negotiable. Navigation afterwards is the
   record path, **never `companySafeLocation`**, which strips `/clients/<id>`
   back to `/clients`.
5. **An unvalidated path must never reach `go()`** — go_router's top-level
   `errorBuilder` replaces the whole app with the route-error screen, outside
   the shell with the sidebar gone.

Landing on a record the recipient has never opened is the normal case, so every
detail screen passes `hydrate:` to `EntityDetailScaffold` (`repo.ensureLoaded`)
and the scaffold holds its spinner until that resolves — without it the screen
flashes "not found" for the length of the fetch. `emptyAction:` gives a genuinely
missing record a way onward instead of a dead end.

Two registry notes this depends on. `EntityHandlers.detailBuilder` is read as
"does this entity have a detail screen?" by `entityRecordPath`, so a
settings-hosted entity whose detail screen is registered by the *settings*
router still has to declare it (bank accounts do — the builder there registers
no route, since the entity has no branch); leave it null and the shared link
points at the editor while the list's own row tap goes to the viewer. And a
settings `:id` route needs its own id-keyed subtree (`_settingsRoute` adds one):
go_router derives `state.pageKey` from the route *pattern*, so every id under a
root shares one page, and these screens bind their VM from `widget.id` in
`initState` — without the key, going straight from record A to record B keeps
showing A. The entity branches already do this in `buildEntityRouteBlock`.

**Adding an entity?** `test/lint/entity_copy_link_coverage_test.dart` fails the
build unless its action enum declares `copyLink` — nothing in the type system
would otherwise notice a new entity shipping with no way to link to it.

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
