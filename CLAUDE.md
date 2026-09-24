# Invoice Ninja — Flutter App (rebuild)

This is a clean-room rebuild of `/Users/hillel/Code/admin-portal`. Read this file before changing anything substantial.

**This file is an index of rules, not a record of investigations.** It is capped so a session can read it whole. When you learn something worth keeping:

- **The rule goes here** — one bolded sentence, enforceable on its own, as a bullet under the matching `##` / `###`, ending `→ docs/<file>.md`.
- **The evidence goes in that doc** — the mechanism, the SDK/server source that explains it, the measured numbers, the failure it shipped as, the test that pins it. Append it under a `##` heading named the same as the bullet.
- **Move a paragraph out only if it is ≥ ~2 KB *and* joins ≥ 3 paragraphs on one topic.** A lone short rule, or a recipe carrying a value you need while typing, stays here.
- **If no doc fits, create one named for the question it answers** (`docs/touch-targets.md` — never a grab-bag name, and never just the name of the section it came from). Open it with `Companion to CLAUDE.md § <Section>. <what lives where>` and add **one** Quick Index row.
- **No paragraph here runs past ~4 lines.** If a rule needs a second paragraph, that paragraph belongs in its doc. `test/lint/claude_md_size_test.dart` enforces the cap, the line length, and that every `§` citation in the repo still resolves.

Citations elsewhere in this repo read `CLAUDE.md § <Section>` or a bare `§ <Section>`. Every such section still exists here; where it holds only a rules list, the evidence is in the `docs/` file named on the bullet.

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
| Wiring a form field, picker, or Enter-to-save | § Forms · `docs/pickers.md` · `docs/form-fields.md` |
| Keyboard type, autofill, capitalization, or a negative amount on touch | § Forms — Input types · `docs/form-fields.md` · `test/lint/field_input_types_test.dart` |
| A picker popover that won't close on touch or Android back, the ✕, or the ▾ on a picker | `docs/popup-dismissal.md` · `lib/ui/core/widgets/picker_dismissal.dart` · `test/lint/picker_popover_wiring_test.dart` |
| Adding a hand-rolled `OverlayPortal`, or Android back not closing one | `docs/popup-dismissal.md` § Android back is the other dismissal · `test/lint/overlay_back_dismiss_test.dart` |
| A picker showing a dead empty box or stuck on "Loading", or blanking when its value is archived | `docs/pickers.md` § A picker's empty state has to say something · `lib/ui/core/widgets/entity_picker_field.dart` |
| A Client / Vendor field that must stop being editable once the record is saved | `docs/pickers.md` § A field the server freezes is a locked row, not a disabled picker · `lib/ui/core/widgets/locked_entity_field_row.dart` · `test/lint/frozen_party_field_wiring_test.dart` |
| Adding an Assigned User or task Status picker, or a field to the create-task-from-a-line sheet | `docs/pickers.md` § The assignee roster has one home · `lib/ui/core/widgets/assigned_user_picker_field.dart` |
| Hiding unverified users from Assigned User fields, or the "never onboarded" rule | `docs/pickers.md` § Hiding unverified users · `lib/domain/assignable_users.dart` · `test/lint/assigned_user_picker_wiring_test.dart` |
| Anything money / date / parsing | § Strict rules + § Forms |
| Changing invoice / quote / credit totals math | `docs/sync.md` § The server's rounding scale is a two-level map · `tool/totals_oracle.php` |
| Dialog buttons rendering stacked | § Design system (v2) |
| Picking the icon for an overflow / "more" menu | § Design system (v2) · `test/lint/no_horizontal_more_icon_test.dart` |
| Adding a `MenuAnchor` / overflow menu, or Android back not closing one | `docs/popup-dismissal.md` § A `MenuAnchor` is not a route · `test/lint/menu_anchor_back_dismiss_test.dart` |
| Adding a sign-out / session-ending surface | § Action confirmations · `docs/adding-an-entity.md` § Action confirmations — the sign-out case |
| A shortcut that stops working until you click, a macOS beep, or a bare key served by the wrong screen | `docs/keyboard.md` § The whole keyboard layer hangs off one focus node · `test/lint/focus_owner_wiring_test.dart` |
| Adding or changing a `G`-leader jump (`G` then a letter) | `docs/keyboard.md` § The `G`-leader table has one copy · `lib/domain/leader_shortcuts.dart` |
| Sync / outbox / 400-401-403-404-409-412-422 behavior | § Sync — non-obvious rules (all 33 rules) · `docs/sync.md` (the evidence) |
| Bundled vs per-entity data loading | § Data loading — bundled vs per-entity |
| Architecture, write pipeline, project layout | § Architecture — at a glance + `docs/architecture.md` |
| Changing the Drift schema (forward migration) | `docs/migrations.md` |
| Adding / changing a sidebar count badge | § Sidebar counters · `docs/entity-lists.md` § Sidebar counters · `lib/domain/sidebar_badge_modes.dart` |
| Changing the main menu's layout, order, or which rows it can hide | `docs/sidebar-and-shell.md` § The main menu is a preference · `lib/domain/sidebar_menu.dart` |
| Moving the pinned Settings / Outbox rows, or changing a nav row's selected treatment | `docs/sidebar-and-shell.md` § Settings and Outbox are chrome · `test/lint/sidebar_menu_wiring_test.dart` |
| Adding / changing a list's status tabs | § List status tabs · `docs/entity-lists.md` · `lib/domain/list_status_tabs.dart` |
| Changing a list's State (active / archived / deleted) filter | § List state filter · `docs/entity-lists.md` · `lib/domain/entity_state.dart` |
| Adding a column to an entity list (or a custom-field column) | § List columns · `docs/entity-lists.md` · `lib/domain/columns/` |
| Adding a report, its date field, grouping granularity, or the report chart | § Reports · `docs/reports.md` · `lib/domain/reports/report_registry.dart` |
| Adding a dashboard panel, hiding empty ones, or the task-calendar panel's colours / month fetch | § Dashboard panels · `docs/dashboard-panels.md` · `lib/ui/features/dashboard/helpers/enabled_panel_kinds.dart` · `lib/ui/features/dashboard/widgets/hidden_empty_panels_builder.dart` |
| An entry in the dashboard's `+` create sheet, who is offered it, or the running-timer pill sitting on a FAB | `docs/dashboard-panels.md` § The `+` is a FAB that opens a create sheet · `lib/domain/quick_create.dart` · `runningTimerPillBottom` |
| A task that is booked but not started, the Start/Resume label, or billing booked time | `docs/task-scheduling.md` · `lib/domain/tasks/task_schedule.dart` · `test/lint/task_start_rules_test.dart` |
| Changing the Tasks layout view (list / daily / weekly / calendar / kanban) or how it sticks | § Tasks layout view · `docs/tasks-views.md` · `lib/domain/tasks/tasks_view_mode.dart` |
| Adding a create affordance to the kanban board (its `+ New Task` footer, or a FAB) | `docs/tasks-views.md` § The kanban board is the one Tasks view with no create FAB · `test/lint/tasks_view_wiring_test.dart` |
| Collapsing a filter bar to an icon, or the removable-chip strip that replaces it | `docs/pane-width-and-overflow.md` § A filter surface too tall for its pane becomes an icon · `lib/ui/core/widgets/filter_icon_button.dart` |
| Changing a Tasks view header (day / week / month nav), or its narrow branch | `docs/pane-width-and-overflow.md` § The three time-oriented Tasks headers · `lib/ui/features/tasks/widgets/calendar/task_calendar_header.dart` |
| Viewing an older version of an invoice / quote / credit / PO / recurring invoice, or its History tab | § Document version history · `docs/document-version-history.md` · `lib/data/services/document_versions_api.dart` |
| Adding a tab to a billing-doc edit screen, the PDF preview button, or a scrollable strip that runs off the edge | `docs/pane-width-and-overflow.md` § A tab strip is a width budget · `lib/ui/core/widgets/scroll_edge_fades.dart` |
| Changing the Items tab's add affordances or empty state on a billing-doc edit screen, or a FAB there | `docs/pane-width-and-overflow.md` § A `Stack` mounted for a FAB · `test/lint/billing_items_affordance_test.dart` |
| A create `+` covering the last row of a list, or adding a FAB over any scrollable | `docs/pane-width-and-overflow.md` § A floating button is a bottom inset · `lib/ui/core/utils/fab_clearance.dart` · `test/lint/fab_clearance_wiring_test.dart` |
| Making a name in a list row or table cell tappable (or a link visible on touch) | `docs/row-actions-and-values.md` § A narrow list row has exactly one destination · `test/lint/no_list_tile_name_link_test.dart` |
| Adding an action that only navigates (View client / View vendor) | `docs/row-actions-and-values.md` § A pure navigation action must never reach an edit screen · `test/lint/view_party_action_coverage_test.dart` |
| Building a list tile cell, empty state, search field, or detail KPI cell | `lib/ui/core/list/cell_slot.dart` · `entity_list_empty_state.dart` · `search/entity_token_search_field.dart` · `lib/ui/core/detail/kpi_cell.dart` · `test/lint/shared_list_widgets_test.dart` |
| A pull-to-refresh that won't start on a short list, or giving a refreshable list a `ScrollController` | `docs/pull-to-refresh.md` · `test/lint/refresh_indicator_physics_test.dart` · `test/ui/core/list/entity_list_pull_to_refresh_test.dart` |
| Deciding whether a zero renders, dashes, or disappears | `docs/row-actions-and-values.md` §§ An empty value… · A zero in a detail KPI cell… |
| An "Email History" tab listing contacts nothing was sent to, an invisible spam complaint, or either email tab's empty copy | `docs/contacts-and-invitations.md` § An invitation is created when the document is saved · `lib/data/models/domain/billing/invitation.dart` |
| Localization / Transifex import | § Localization |
| Email-template `$variables` as chips (T&R subject/body, Send Email subject/body), which variables a template supports, the value probe, or linkify mangling a typed `$token` | `docs/template-variables.md` · `lib/domain/email_template_variables.dart` · `test/domain/email_template_variables_test.dart` |
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
| Changing the desktop title bar, its drawn window buttons, or where the nav arrows live — including hiding them behind the browser's own | `docs/desktop-window-state.md` § Drawn window buttons · § The sidebar's history arrows hide behind the browser's own · `lib/ui/features/shell/widgets/window_frame.dart` · `lib/app/browser_chrome.dart` |
| Sharing a link to a record, or handling an incoming one | § Deep links · `docs/deep-links.md` |
| Enabling https App Links / Universal Links (Apple capability, Play fingerprints, deploy order) | `APP_LINKS.md` |
| Contacts sync (client contacts → device address book) | `docs/contacts-sync.md` |
| Surfacing a record's comments (the Comments card / tab), how a note renders, or a detail screen's tab order | `docs/comments-and-activity.md` · `lib/ui/features/billing_shared/activity/` |
| Making an activity row open the record it names, or adding an inline link to a rich-text sentence | `docs/comments-and-activity.md` § An inline link in a sentence cannot be hit by a finger · `lib/domain/activity/activity_refs.dart` |
| A `Viewed` pill that should lead to its activity, when a doc was looked at, or an activity row wearing the wrong icon | `docs/comments-and-activity.md` § A `Viewed` pill is the way into the activity that recorded the view · `lib/ui/features/billing_shared/viewed_status_pill_link.dart` |
| A `Semantics` role that a screen reader can announce but not activate | `docs/row-actions-and-values.md` § A narrow list row has exactly one destination · `test/lint/semantics_excludes_need_ontap_test.dart` |
| Tap-to-call / SMS on a phone number, its business-hours warning, a call button (billing-doc header, list row), or logging a call into Activity | `docs/tap-to-call.md` (§ Non-obvious rules for the traps) |
| Rotating the `is_system` API token (blocked on server) | `docs/token-rotation.md` |
| Checking what's built vs what's left | `FEATURES.md` (kept current — see § Strict rules) |
| Working around an open upstream (Flutter/pub) bug — or undoing one later | `docs/upstream-workarounds.md` |
| Sizing a tap target, or a row that grew taller than you expected | `docs/touch-targets.md` · `lib/ui/core/adaptive.dart` |
| A keyboard covering a field, an invisible ripple, or sidebar spacing | `docs/sidebar-and-shell.md` · `test/lint/no_ink_widget_test.dart` |
| A contact row reading `(no name)`, or an email address nobody typed | `docs/contacts-and-invitations.md` · `lib/data/models/value/parsing.dart` |
| A markdown field: inbound HTML, the mobile caret, read-only mode | `docs/rich-text-editing.md` · `lib/ui/core/widgets/markdown_text_field.dart` |
| Writing a notes / terms / footer value, or rendering one read-only | `docs/rich-text-editing.md` · `lib/utils/editor_html.dart` · `lib/utils/notes_html.dart` |
| Finding the right doc at all | `docs/README.md` (one line per doc) |

## Strict rules

Rules that turn into bugs or CI failures if forgotten. Read this block first.

- **No Redux. No bloc. No Riverpod.** `ChangeNotifier` only. Tempted to add one? Talk to the team first.
- **No `per_page=999999`.** Lists fetch one page at a time (50 rows default): the ViewModel calls `repo.ensurePageLoaded(N)` near the scroll edge, the repo writes the page to Drift, the UI reacts via the watch stream. A CI lint grep-fails the build if the literal appears in `lib/`.
- **Money is `Decimal`, never `double`.** Enforced by a CI test (greps entity models).
- **Date-only is the custom `Date` type; `DateTime` is for timestamps only.** Mixing them silently breaks invoice math.
- **Drift is the only thing the UI reads from.** The network writes to Drift; the UI watches Drift. Never read API responses straight into UI state.
- **Schema changes need a forward Drift migration now (post-beta).** The app is shipped — installed databases hold real user data and unsynced outbox edits. Any schema change (table / column / index) must bump `AppDatabase.schemaVersion`, add an `onUpgrade` step, re-dump (`drift_dev schema dump`) + re-generate (`schema generate`), and extend the matrix test. **Never re-squash to v1 or overwrite a shipped `drift_schemas/drift_schema_v*.json`** — a frozen-checksum CI test (`test/data/db/migration_test.dart`) fails the build if you do. Skipping the migration silently wipes the user's local DB (and pending offline edits) via the `isSchemaIntact()` reset backstop. Full workflow: `docs/migrations.md`.
- **Every `onUpgrade` step runs inside its one `transaction()` and must be safe to run twice — `_addColumnIfMissing`, never a bare `m.addColumn`.** → `docs/migrations.md` § Every upgrade step is idempotent and transactional
- **A failed database open destroys the store only when a fresh store fixes it** (corrupt, or drift / a failed upgrade that `repairSchema` can't fix); a lock — on web, just a second tab — a full disk or an unrecognised error leaves it untouched. → `docs/migrations.md` § A failed open destroys the store only when a fresh store fixes it
- **Every new table is classified durable / anchor / cache in `kTableRetention`** — repair may drop only cache tables. → `docs/migrations.md` § Drift is repaired in place, and only the cache may be dropped
- **A reset quarantines the store and an open imports its non-cache tables, once — the `.salvage` marker is taken *before* the import, because a second import resends delivered outbox rows.** → `docs/migrations.md` § A reset carries the user's own tables across
- **Auth user data flows in through `/refresh`, not `GET /users/{id}`.** `_persistAndActivate` upserts each `data[N].user` block into the `users` Drift table on every login/refresh. `GET /users/{id}` is 412-gated (password-required). `auth.refresh()` runs a full `_persistAndActivate` — use it for a fresh session snapshot, not for incidental work. Never call `UsersApi.get` from incidental paths.
- **Every write goes through the outbox.** Repositories never call mutation endpoints directly. (Accepted exceptions, each a synchronous UI flow that can't queue: the calendar-connection OAuth handshake/`setCalendars`/`disconnect` in `CalendarConnectionRepository`, and `QuickbooksRepository` — see their class docs.)
- **Every list query is scoped by `company_id`.** Use `CompanyScopedDao` — direct table access bypassing the DAO fails a lint check.
- **Idempotency keys are stable across retries** — generated when the outbox row is created, reused on every retry.
- **Format money / dates / addresses through `Formatter`** (`lib/utils/formatting.dart`). `Formatter.money(amount, clientCurrencyId: ...)` runs the per-client → company currency cascade + Euro override; `Formatter.date(date.toIso())` honors company `date_format_id`. Never render `Date.toIso()`, `DateFormat`, or `MaterialLocalizations.formatMediumDate` directly — `toIso()` is for storage/API/Drift keys only. Build the `Formatter` once per screen via `services.formatterFor(companyId)` and pass it down. Parse user input via `parseDecimal(input, useCommaAsDecimalPlace: ...)`.
- **No `vm.<entityName>` / `vm.<entityName>s` aliases on list/detail VMs.** Canonical accessors are `vm.item` (detail) and `vm.items` (list), defined on the generic bases.
- **Imports**: always `package:admin/...` inside `lib/`, never relative (`../`, `./`, bare) — and that covers `export` directives and *both* branches of a conditional `if (dart.library.io)` seam. `always_use_package_imports` only visits `import` directives in `lib/` (measured), so `test/lint/package_imports_test.dart` is the real gate. **The test tree is a deliberate exception** — `package:` resolves only into `lib/`, so a test importing a test helper (`test/_localization_helper.dart`, `_shell_test_helpers.dart`, …) stays relative and must not be "fixed"; what is banned there is a relative path reaching *into* `lib/`.
- **`lib/data/** → `docs/architecture.md` § Why `lib/data/**` must not reach `lib/ui/**`
- **CI runs in UTC; the dev machines here don't.** Any test fixture whose expectation depends on a *calendar day* or a *wall-clock time* must sit far from midnight UTC — the ~11:00–13:00 UTC band is the same local day from UTC−11 through UTC+10. Anything built on `DateTime.toLocal()` is affected; task time-log grouping (`_isoDay`, `lib/domain/tasks/task_invoice_notes.dart`) is the live example, where a fixture 2 hours before midnight UTC is one local day on a UTC+2 laptop and two on CI. Green locally is not green on CI — check a date/time-sensitive test with `TZ=UTC flutter test <file>` before pushing.
- **Don't run integration tests locally unless the user explicitly asks** — they take over the foreground app and interrupt the session. Never run them proactively or as incidental verification; let CI run them. On-request procedure: `docs/integration-tests.md`.
- **`FEATURES.md` is the parity tracker — keep it current.** It compares every user-facing feature across React (`/Users/hillel/Code/react`), Flutter v1 (`/Users/hillel/Code/admin-portal`), and this rebuild. When a PR flips a row to ✅ in the Flutter v2 column, update that row in the same PR; a feature with no React/v1 precedent gets a fresh row (`—` / `—` / `✅`); a scaffolded-but-incomplete screen is 🟡, not ❌. Hand-edited — don't generate it. Legend: ✅ done end-to-end, 🟡 partial/scaffolded, ❌ not implemented, — N/A.
- **Pub packages OK; npm / pip / brew etc. require explicit approval.** A Dart/Flutter dep via `pubspec.yaml` + `flutter pub get` is fine — that's the project's package surface and reviewers see the lockfile diff. For anything outside that (`npm`, `pip`, `brew`, `gem`, `cargo`, system installers) stop and ask first, so a stray tool can't silently shift the build environment.
- **Never add a Claude / AI `Co-Authored-By` (or any "Generated with" / assistant) trailer or line** to commit messages or PR bodies. Commit messages contain only the human-authored description. This overrides the harness default.
- **Never create, switch, rename, or delete git branches in this working tree** (no `git branch`, `git checkout <branch>`, `git switch`). Multiple Claude sessions share this single checkout; a branch create/switch in one corrupts every other in-flight session. Work on whatever branch is checked out; commit there only when the user asks; if a task seems to need its own branch, stop and ask. This overrides the harness default ("branch first"). **Sole exception:** the integration-test procedure (`docs/integration-tests.md`), which branches inside an *isolated sibling worktree*, never this checkout.
- **Android system back == the sidebar `←` (history back), and three things keep it working.** → `docs/architecture.md` § Why Android system back needs three things to keep working
- **Boot must always reach `runApp()` — every await in front of it is bounded and caught, and on web the failure has to be printed or it is invisible.** → `docs/architecture.md` § Why boot must always reach `runApp()`
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

- **The drawn window buttons are the one exception to every shape rule below.** → `docs/desktop-window-state.md` § The drawn window buttons are the one exception to every shape rule

**Always rounded rectangles, never pills.** Use `RoundedRectangleBorder(borderRadius: BorderRadius.circular(InRadii.r2))` (or `.r1` / `.r3` per size) — never `StadiumBorder`, never `BorderRadius.circular(999)`. Material 3 defaults `SegmentedButton` / `Chip` / `FloatingActionButton.extended` to pills, so `theme.dart` registers the rounded shape on every relevant component theme; new widgets inherit it. Add new component themes to `theme.dart` rather than overriding inline.

- **Always the vertical `⋮`, never the horizontal `⋯`.** → `docs/popup-dismissal.md` § Always the vertical ⋮, never the horizontal ⋯
- **Touch targets are gated on the platform, not the viewport.** → `docs/touch-targets.md` § Touch targets are gated on the platform, not the viewport

1. Express a row floor as `ConstrainedBox(minHeight:)`, never `SizedBox(height:)` — a fixed height clamps the label's line box and slices descenders at large text scale.
2. An `IconButton`'s explicit `constraints` are run through `visualDensity.effectiveConstraints` (M3 routes them into `ButtonStyle` `minimumSize`/`maximumSize`, then `button_style_button.dart` adjusts), so `compact` subtracts 8 and a `tightFor(44, 44)` renders **36**. Drop the density on touch; the theme default is already `standard` there.
3. `ThemeData.materialTapTargetSize` is `padded` on iOS/Android, which inflates an `IconButton`'s **layout** size (not just its hit area) to `kMinInteractiveDimension` = 48 and ignores your constraints. Pass `tapTargetSize: MaterialTapTargetSize.shrinkWrap` — the sidebar's icon buttons all do.
4. A `SidebarNavItem`'s `trailing` sits inside the row's `Row`, so it drives the cross axis and the row's own padding stacks on top: a 44 px trailing makes a 58 px row. Cap trailing widgets to the row's content box (target − vertical padding), not the target.
5. **A fixed-width slot holding `IconButton`s must be sized from the touch branch, and the buttons pinned.** → `docs/touch-targets.md` § Trap 5 — a fixed-width slot of `IconButton`s

- **A `MenuAnchor` is not a route, so Android's back has to be wired by hand — use `BackDismissibleMenuAnchor`** → `docs/popup-dismissal.md` § A `MenuAnchor` is not a route, so Android back has to be wired by hand
- **The company switcher is a control, not a label — never gate it out of existence.** → `docs/sidebar-and-shell.md` § The company switcher is a control, not a label — never gate it away
- **A filter surface too tall for its pane becomes an icon, and the chip strip that replaces it renders nothing at all when nothing is filtered.** → `docs/pane-width-and-overflow.md` § A filter surface too tall for its pane becomes an icon
- **The three time-oriented Tasks headers take the screen's pane bool, and the calendar one had no width branch at all.** → `docs/pane-width-and-overflow.md` § The three time-oriented Tasks headers take the screen's pane bool
- **A tab strip is a width budget, and Material spends 52 px of it before you write a line.** → `docs/pane-width-and-overflow.md` § A tab strip is a width budget, and Material spends 52 px first
- **A `Stack` mounted for a FAB loosens what is under it, and that is what left an empty state in the corner.** → `docs/pane-width-and-overflow.md` § A `Stack` mounted for a FAB loosens what is under it
- **A floating button is a bottom inset every scrollable under it has to pay, and passing that padding means owning the safe inset too.** → `docs/pane-width-and-overflow.md` § A floating button is a bottom inset every scrollable under it has to pay
- **A landscape phone is not a small desktop.** → `docs/touch-targets.md` § A landscape phone is not a small desktop
- **One surface, one safe-area owner — and the owner has to be the *last* thing, not the first.** → `docs/sidebar-and-shell.md` § One surface, one safe-area owner — and the owner must be last
- **`Ink` is banned (`test/lint/no_ink_widget_test.dart`) — paint a tappable surface on a *local* `Material`.** → `docs/sidebar-and-shell.md` § `Ink` is banned — paint a tappable surface on a local `Material`
- **A viewport can be too *short* for optional chrome, and `Breakpoints` cannot answer that.** → `docs/sidebar-and-shell.md` § A viewport can be too short for optional chrome
- **The main menu is a *preference*, and the two halves of that fail in opposite directions.** → `docs/sidebar-and-shell.md` § The main menu is a preference, and its two halves fail oppositely
- **Settings and Outbox are chrome, not destinations — they are pinned below the nav list, and their selected state drops the accent.** → `docs/sidebar-and-shell.md` § Settings and Outbox are chrome, pinned below the nav list


- **On a narrow viewport nothing above a screen owns a `Scaffold`, so every full-page host must bring its own — and a missing one costs keyboard avoidance, silently.** → `docs/sidebar-and-shell.md` § On a narrow viewport every full-page host must bring its own `Scaffold`
- **A scroll view under a `RefreshIndicator` that is handed a `controller:` must ask for `physics: const AlwaysScrollableScrollPhysics()` — the controller switches that default off, and a list shorter than its viewport can then never be pulled (`test/lint/refresh_indicator_physics_test.dart`).** → `docs/pull-to-refresh.md` § A controlled scroll view under a `RefreshIndicator` must ask for `AlwaysScrollableScrollPhysics`

**Pair related action buttons side-by-side**, not stacked — a `Row` with `SizedBox(width: InSpacing.md(context))` between them. Cancel sits next to the primary action, never above it.

**Spacing tokens `InSpacing.md` / `InSpacing.lg` are responsive context-aware static methods** (`lib/app/design_tokens.dart`), not const doubles — wider on desktop, tighter on mobile (`md`: 8 px narrow `<600` / 12 px wide `≥600`; `lg`: 12 / 16 px). Call with a `BuildContext`: `EdgeInsets.all(InSpacing.lg(context))`, `SizedBox(width: InSpacing.md(context))`. **Drop `const` from any wrapping `EdgeInsets` / `SizedBox` / `Padding`** — the value is no longer compile-time const (perf cost is nil: Flutter's `Element.canUpdate` matches on `runtimeType + key`, not `==`). `InSpacing.sm` (8 px) stays `const` for math contexts and small inter-icon gaps; `xs` / `xl` / `xxl` stay const too — not part of the responsive system.

**Bordered-card form sections use `InSpacing.lg(context)` interior padding by default.** That's what `FormSection`, `DashboardCardShell`, and the task-edit identity card use; new one-off bordered cards (`Container` with `tokens.border` + `BorderRadius.circular(InRadii.r3)`) match with `padding: EdgeInsets.all(InSpacing.lg(context))`. Column-aligned interior surfaces (table headers + rows + add-row tiles) use the horizontal value (`horizontal: InSpacing.lg(context)`) so cells line up with the section title. Card-to-card inset consistency is the point.

**Side-by-side dialog actions need a per-call `minimumSize` override.** A `FilledButton` / `FilledButton.tonal` / `OutlinedButton` inside `AlertDialog.actions` (or any `Row`) needs `style: FilledButton.styleFrom(minimumSize: const Size(64, 44))` (Outlined uses `Size(64, 40)`). The themes default to `Size.fromHeight(44)` = infinite width — right for column-stacked form buttons, but in a horizontal context `Row` crashes layout and `AlertDialog.actions` silently stacks via `OverflowBar`. Inline comments in `theme.dart` explain why.

**Dialog primary actions use `PrimaryDialogAction`** (`lib/ui/core/widgets/primary_dialog_action.dart`), not a hand-rolled `FilledButton`. It bakes in the `Size(64, 44)` override, `autofocus`, and a subtle trailing **Enter** affordance (a dimmed `↵` — the app's standard Enter glyph) so users learn Enter submits. `variant:` selects plain / `.tonal` / `.destructive`; keep `autofocus: false` when a text field should own focus (Enter still submits via `FormSaveScope`/`onSubmitted`), and `showEnterHint: false` when Enter can't/shouldn't fire the primary. Two non-obvious `showEnterHint: false` cases (they cause a *lying* hint otherwise): **dropdown-only dialogs** — `SearchableDropdownField` consumes Enter to pick an option and never calls `FormSaveScope.trySubmit()`, so a scope around it is dead; and **primaries that start disabled** (`enabled: x != null`) — a disabled button can't take `autofocus`, so Enter never reaches it. References: `discard_changes_dialog.dart`, `company_picker.dart`, `type_to_confirm_dialog.dart` (destructive), `merge_client_dialog.dart` (dropdown → no hint).

**Centered single-action buttons must constrain their own width too.** The same `Size.fromHeight(44)` (= `Size(double.infinity, 44)`) default makes a bare `FilledButton` stretch full-width — wrong for an `EmptyState` action or any centered call-to-action (renders as one edge-to-edge bar). Pass `minimumSize: const Size(64, 44)` so it sizes to content. Don't create full-width `FilledButton`s outside a deliberately column-stacked form/footer context. Reference: the Reports empty-state "Run report" action in `lib/ui/features/reports/widgets/reports_body.dart`.

- **Keyboard-shortcut discoverability.** → `docs/keyboard.md` § Keyboard-shortcut discoverability
- **The whole keyboard layer hangs off one focus node, and every framework recovery path drops it somewhere that node cannot see.** → `docs/keyboard.md` § The whole keyboard layer hangs off one focus node
- **A keeper reclaims focus only when it escaped *upward* — never from a surface beside it, and a route check cannot tell the difference.** → `docs/keyboard.md` § A keeper reclaims focus only when it escaped upward
- **The `G`-leader table has one copy, and it is not in the shell.** → `docs/keyboard.md` § The `G`-leader table has one copy, and it is not in the shell
- **A chord is one cap per glyph, never a concatenated label.** → `docs/keyboard.md` § A chord is one cap per glyph, never a concatenated label
- **Inside a cap a key gets its printed name** → `docs/keyboard.md` § Inside a cap a key gets its printed name

**Task status colours resolve through `taskStatusColors`** (`lib/ui/core/utils/task_status_colors.dart`) — the list pill, kanban column dot, settings row dot, and settings live preview all call it; never parse `TaskStatus.color` inline. `''`, `#fff` and `#ffffff` all mean **unset**: the server creates a new company's four statuses with no colour (MySQL default `#fff`) and the API factory writes `''`. Unset + a recognised built-in name (`backlog` / `ready_to_do` / `in_progress` / `done`, matched against the active locale *and* English) maps onto the `draft` / `partial` / `sent` / `paid` token pairs so the defaults read grey / blue / amber / green; anything else unset stays `ink3`. A user-picked hex always wins.

**Initials avatars go through `InitialsAvatar`** (`lib/ui/core/widgets/initials_avatar.dart`) — the tinted rounded-square identity badge behind Client / Vendor list rows and the assigned-user badge on Task rows — with `initialsFor(name)` as the single Unicode-aware extractor (`\P{L}` strip, first + last word; returns **null** for a letterless identity like `#0009` so each caller picks its own fallback: the entity icon on the detail header, `'?'` on a list row). Seed on the entity **id**, never the display name, or a rename reshuffles the colour; tints come from `avatarTintFor` only. `UserAvatar` (`user_avatar.dart`) is the id→badge wrapper, resolving against the local roster exactly like its sibling `UserNameLabel` — an id the roster can't resolve stays a tinted `?` (an ex-employee's task is still *assigned*), which is deliberately not what `UserNameLabel` does with the same id. Two traps when a badge is a list row's `LeadingSelectSlot.defaultChild`: a `Tooltip` on it can never fire (hovering the slot swaps it for the selection checkbox — put the name in a column or on the detail screen instead), and it must keep the slot's 32×32 footprint even when there's nothing to show, so an unassigned Task renders a muted `person_outline` placeholder rather than collapsing and knocking the row's columns out of alignment.

- **A narrow list row has exactly one destination, and a link's at-rest affordance is gated on the input device.** → `docs/row-actions-and-values.md` § A narrow list row has exactly one destination
- **A pure navigation action must never reach an edit screen.** → `docs/row-actions-and-values.md` § A pure navigation action must never reach an edit screen
- **An empty value is an em dash in a *labelled* slot and nothing at all in an unlabelled one.** → `docs/row-actions-and-values.md` § An empty value is an em dash in a labelled slot, nothing in an unlabelled one
- **A zero in a detail KPI cell has three possible renderings, and picking the wrong one is invisible in review.** → `docs/row-actions-and-values.md` § A zero in a detail KPI cell has three possible renderings
- **A conditional KPI cell means the layout must be count-agnostic — which is now a solved problem, so don't re-solve it.** → `docs/row-actions-and-values.md` § A conditional KPI cell means the layout must be count-agnostic
- **The server seeds one all-blank contact per client and per vendor, so `contacts.isNotEmpty` is never the question — `isBlank` per row is.** → `docs/contacts-and-invitations.md` § The server seeds one blank contact, so `isBlank` per row is the question
- **An invitation is created when the DOCUMENT is saved, so `invitations.isNotEmpty` is never the question — `hasSendHistory` per row is.** → `docs/contacts-and-invitations.md` § An invitation is created when the document is saved, not when mail is sent
- **A contact's email can be one the *server* typed, and it is indistinguishable from the user's except by shape.** → `docs/contacts-and-invitations.md` § A contact's email can be one the server typed
- **A row that prints the same name twice is the *normal* state for an individual, and the only usable tell is string equality against the title the row is already rendering.** → `docs/contacts-and-invitations.md` § A row printing the same name twice is normal for an individual
- **A card that hides itself still costs a gap.** → `docs/comments-and-activity.md` § A card that hides itself still costs a gap
- **A record's comments live above the fold, and the card that shows them is the one place the gap rule inverts.** → `docs/comments-and-activity.md` § A record's comments live above the fold
- **The record's own history leads every detail strip, and the strip now scrolls itself.** → `docs/comments-and-activity.md` § The record's own history leads every detail strip
- **A note is not a sentence — the bypass is keyed on `isComment`, not `isCallNote`.** → `docs/comments-and-activity.md` § A note is not a sentence — the bypass is keyed on `isComment`
- **A client's comment feed is *mixed*, and the source record has to be named.** → `docs/comments-and-activity.md` § A client's comment feed is mixed, so the source record must be named
- **A comment cannot be edited or deleted, so the row offers what it honestly can and the dialog says so once.** → `docs/comments-and-activity.md` § A comment cannot be edited or deleted
- **An inline link inside a sentence cannot be hit by a finger, so the activity row itself is the target.** → `docs/comments-and-activity.md` § An inline link in a sentence cannot be hit by a finger
- **The per-entity activity fetch is eager, shared, debounced and stale-while-revalidate — and its cache is user-scoped.** → `docs/comments-and-activity.md` § The per-entity activity fetch is eager, shared and user-scoped
- **A `Viewed` pill is the way into the activity that recorded the view, and the caption beside it is what survives the status moving on.** → `docs/comments-and-activity.md` § A `Viewed` pill is the way into the activity that recorded the view
- **A status pill that leads somewhere paints its ink inside its own tint, and on touch it says so with an underline.** → `docs/comments-and-activity.md` § A status pill that leads somewhere paints its ink inside its own tint
- **A one-shot reveal outlives its consumer, and the row scrolls itself.** → `docs/comments-and-activity.md` § A one-shot reveal outlives its consumer, and the row scrolls itself
- **The `activity_type_id` → tone map is the server's catalog, not a guess — and the bundled template is the test.** → `docs/comments-and-activity.md` § The activity tone map is the server's catalog, not a guess

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

- **Opening a picker that already has a value shows the whole list, and that takes two cooperating rules — don't remove either.** → `docs/pickers.md` § Opening a picker that already has a value shows the whole list
- **The options popover must not wrap itself in an `Align`.** → `docs/pickers.md` § The options popover must not wrap itself in an `Align`
- **Touch gets a different picker without a different widget.** → `docs/pickers.md` § Touch gets a different picker without a different widget
- **On native touch nothing closes the options popover but a pick — so every `RawAutocomplete` field sets `onTapOutside`.** → `docs/popup-dismissal.md` § On native touch nothing closes the options popover but a pick
- **Android's back is the other dismissal, and a picker popover is not a route either — wrap it in `BackDismissiblePickerOverlay`** → `docs/popup-dismissal.md` § Android back is the other dismissal, and needs its own wrapper
- **The ▾ is the only *visible* way to close a picker, so it has to be a button.** → `docs/pickers.md` § The ▾ is the only visible way to close a picker, so it must be a button
- **A picker's empty state has to say something, and its selection must not be resolved by scanning the list.** → `docs/pickers.md` § A picker's empty state has to say something
- **The assignee roster has one home now, and the four rules it enforces are each invisible at a call site.** → `docs/pickers.md` § The assignee roster has one home, and four invisible rules
- **The create-task-from-a-line sheet seeds the Status and deliberately does not seed the assignee.** → `docs/pickers.md` § The create-task-from-a-line sheet seeds the Status, not the assignee
- **A re-pick of the value the field already holds is a real command, not a no-op.** → `docs/pickers.md` § Re-picking the value the field already holds is a real command
- **A picker that needs inline "create new \<entity\>" can't be a `SearchableDropdownField`.** → `docs/pickers.md` § A picker needing inline create can't be a `SearchableDropdownField`
- **A field the server freezes on UPDATE is a locked row, not a disabled picker, and the reason sits outside its tap surface.** → `docs/pickers.md` § A field the server freezes is a locked row, not a disabled picker

### Input types

Every text input declares the keyboard, capitalization and autofill its data
actually needs. None of this is visible under `flutter test` — a soft keyboard
never renders — so the invariants are pinned by
`test/lint/field_input_types_test.dart` (a source scan keyed on each field's
own label / `apiKey` token, with `// lint: allow-input-type <reason>` as the
opt-out) and by `test/ui/core/edit/entity_edit_field_test.dart`, which reads
the properties back off the underlying `TextField`.

- **`signed:` is checked before `decimal:`, so `decimal: true` alone means no minus key.** → `docs/form-fields.md` § `signed:` is checked before `decimal:`, so `decimal` alone means no minus
- **Autofill hints go only on the signed-in user's own identity or their own company.** → `docs/form-fields.md` § Autofill hints go only on the user's own identity or company
- **`TextInputType.multiline` is derived — never add it.** → `docs/form-fields.md` § `TextInputType.multiline` is derived — never add it

**Postal code is `text` + `TextCapitalization.characters`, never `number`.** US
ZIPs are numeric but UK / CA / NL / PL codes are not, so a numeric keypad makes
them untypeable.

- **A credential is obscured and keyboard-hardened; whether it also gets autofill depends on whose credential it is.** → `docs/form-fields.md` § A credential is obscured; whether it gets autofill depends on whose it is
- **`autocorrect: false` on identifier-shaped values** → `docs/form-fields.md` § `autocorrect: false` on identifier-shaped values
- **The three shared widgets take these as plain parameters** → `docs/form-fields.md` § The three shared widgets take these as plain parameters

### Template variable fields

Email-template `$variables` render as chips wherever a template is edited — the Templates & Reminders subject and body, and both Send Email fields — because non-technical users read raw tokens as code to replace: the report was someone backspacing `$company.name` and typing the company name on every send (invoiceninja/flutter#139). A chip shows a friendly label ("Company Name"); on Send Email it adds the document's value ("Company Name  Acme Ltd"), unless the value just repeats the label (`$view_button`); tapping one opens `showTemplateVariablePicker` (change, remove with an Undo toast, "Did you mean …" for a typo), and every field has a labelled "Insert variable".

- **Which variables a template supports is a property of the server engine, not of a list.** → `docs/template-variables.md` § Which variables a template supports is a property of the server engine
- **A single-line field can't hold chips and be edited as text,** → `docs/template-variables.md` § A single-line field can't hold chips and be edited as text
- **The default template is shown, never silently saved.** → `docs/template-variables.md` § The default template is shown, never silently saved
- **Values come from the server, exactly, or not at all.** → `docs/template-variables.md` § Values come from the server, exactly, or not at all
- **A rendered `raw_subject` / `raw_body` is the request echoed back, so a default is adopted only from a render that asked for it — and never survives a template switch.** → `docs/template-variables.md` § A rendered raw_body is the request echoed back
- **A markdown field reports both edges of "is this dirty", and the false one is what an edit that round-trips needs.** → `docs/template-variables.md` § A markdown field reports both edges of dirty
- **A field action is a labelled `FieldActionButton` outside the field — Insert variable above-right, Reset below-right — never a bare glyph in the suffix.** → `docs/template-variables.md` § A field action is a labelled button outside the field
- **A `defaultValue` that lands late is adopted only when the document is pristine and no editor is mounted over it.** → `docs/template-variables.md` § A late defaultValue waits for a pristine document

### Two-choice fields → radio, not dropdown

A fixed field with exactly two choices (occasionally up to ~4) uses a **radio group, not a dropdown** — both options stay visible instead of hiding one behind a tap. Cascade-aware settings use `OverridableRadioField<T>` (reference: the `empty_columns` field on Invoice Design → General). Dropdowns stay correct for longer fixed enums (~10 items); past ~20 options it must be a searchable picker (above).

### Date and time fields

Single-date and single-time-of-day inputs go through `InDateField` (`lib/ui/core/widgets/in_date_field.dart`) and `InTimeField` (`lib/ui/core/widgets/in_time_field.dart`) — a typed `TextField` with a trailing picker icon; users type shortcuts *or* tap the icon for the Material modal:

- Date shortcuts: `today` / `tomorrow` / `yesterday` / `now`; signed offsets `+1`, `-7`; bare day `14`; short slash `5/14` (current year, US/EU order from the active pattern); compact `051426` (2-digit-year heuristic); plus ISO `2026-05-14`, the company's active format, and short/long fallbacks.
- Time shortcuts: bare hour `9` → `9:00`; compact `930` → `9:30`; AM/PM suffix `9p` / `9am`; plus `HH:mm`, `H:mm`, `h:mm a`.

Commit-on-blur + Enter; silent revert on parse failure (the picker icon is the fallback — no red-border noise). Display format comes from the active company `Formatter` (`formatter.settings.dateFormatId`, `.enableMilitaryTime`); without one the field falls back to ISO date and 24-hour time. **Parsing of typed input is locale-independent** — `9` always means `9:00`, `9p` always `21:00`; only display rendering switches between 24-hour and 12-hour.

- **The placeholder is a worked example, never a format pattern.** → `docs/form-fields.md` § The date placeholder is a worked example, never a format pattern

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

- **Signing out is the one confirmation the preference cannot switch off, and it goes through `showConfirmSignOutDialog`** → `docs/adding-an-entity.md` § Signing out is the one confirmation the preference cannot switch off

## Sync — non-obvious rules

- Outbox FIFO is **per company, strict global id order** in M1 (only one entity type exists). The stronger "per (company, entity_type)" guarantee is needed once M2+ introduces cross-entity references with retry-driven head-of-line blocking — revisit `OutboxDao.nextReady` then.
- Every outbound request sends `Idempotency-Key: <uuid from the outbox row>`, generated once at row creation and never regenerated — **but the server ignores it, so it does not make a retry safe.** What a re-send may do is `MutationKind.deliverySafety`. → `docs/sync.md` § A retry is only as safe as what the endpoint does twice
- Logout / company-switch with active (pending / in-flight) outbox rows **prompts** the user (sync now / discard / cancel) — never silently drops user data.
- **A change that may already have reached the server goes `unconfirmed` and is never re-sent on its own** — it waits for Check / Resend / Discard and holds back later changes to its record; a write the server accepted is done, whatever fails after it. → `docs/sync.md` § A change that may already have gone through waits for the user
- **A failed (`dead`) change is still unsynced work — every destructive session end must count it.** → `docs/sync.md` § A failed change is still unsynced work
- **A server copy of one record goes through `applyEchoTemplate` / `applyCreateResponseTemplate` — never a bare upsert — so it can't overwrite a newer queued edit.** → `docs/sync.md` § A server copy never overwrites a newer queued edit
- **A discard abandons the *row*, not the *entity*.** → `docs/sync.md` § A discard abandons the row, not the entity
- Destructive ops (delete, purge, password change) require `X-API-PASSWORD-BASE64`. Password is captured by `ConfirmPasswordSheet`, held in a 5-min in-memory cache.
- **412 Precondition Failed = password-required.** → `docs/sync.md` § 412 Precondition Failed means password-required
- 401 forces `AuthRepository.logout()` and a redirect to `/login`. **Single-flight**: parallel 401s wait on the same logout future. That logout **preserves local data** (`preserveLocalData: true`) — an involuntary 401 is the same user, and wiping the Drift DB (outbox included) over a server-side token change is not a trade worth making; `logout()` still writes the re-lock gate, and `onSessionReset` / `onBeforeLogout` (the cross-user-leak fan-out) run on the preserve path anyway. Only a deliberate sign-out wipes.
- **A rejected *company* token fails the switch, not the session.** → `docs/sync.md` § A rejected company token fails the switch, not the session
- **A forced logout logs a WARNING naming the request.** → `docs/sync.md` § A forced logout logs a WARNING naming the request
- The `x-minimum-client-version` response header is checked on every request; below threshold throws `ClientTooOldException`.
- 422 validation errors carry `Map<String, List<String>> fieldErrors`. Edit forms surface these inline.
- **409 conflicts** are parked far in the future (1 year) instead of auto-retried. `ConflictResolutionSheet` either re-enqueues a fresh mutation or discards.
- **This server does not 404 for a missing entity — it 400s.** → `docs/sync.md` § The server does not 404 for a missing entity — it 400s
- **A soft-deleted record can't be edited; an archived one can.** → `docs/sync.md` § A soft-deleted record can't be edited; an archived one can
- **A rejected save must never be a dead end.** → `docs/sync.md` § A rejected save must never be a dead end
- **Server-side list ordering / cursor.** → `docs/sync.md` § Server-side list ordering and the cursor
- **A narrowed fetch neither reads nor advances the cursor** → `docs/sync.md` § A narrowed fetch neither reads nor advances the cursor
- **`hasMore` is not the gate for widening the Drift window.** → `docs/sync.md` § `hasMore` is not the gate for widening the Drift window
- **A bulk re-download re-arms mounted lists.** → `docs/sync.md` § A bulk re-download re-arms mounted lists
- **Lists sort newest-first where the sort key is monotonic.** → `docs/sync.md` § Lists sort newest-first where the sort key is monotonic
- **A `tmp_` id is a *display* problem too, not just a wire problem.** → `docs/sync.md` § A `tmp_` id is a display problem too, not just a wire problem
- **Offline never dead-letters.** → `docs/sync.md` § Offline never dead-letters
- **A page or a mutation is bound to the company whose token fetched it, and the binding is a `throw`.** → `docs/sync.md` § A page or mutation is bound to the company whose token fetched it
- **A different identity on the same device wipes the local database, and only the login entry points check.** → `docs/sync.md` § A different identity on the same device wipes the local database
- **The server's rounding scale is a two-level map, not one precision.** → `docs/sync.md` § The server's rounding scale is a two-level map, not one precision
- **`markPaid`'s confirmation is a hook, deliberately NOT `confirm: true`.** It opens its own dialog, and § Action confirmations is explicit that a second prompt in front of one is worse than none.
- **A Sync pass re-downloads the fourteen entity tables and nothing else — every cache that hangs off them is re-seeded by hand.** → `docs/sync.md` § A Sync pass re-downloads the entity tables and nothing else
- **A `/refresh` delta carries the fourteen browsable entity tables too, and they are applied as an upsert-only top-up — never on a full sync, and never over a newer local row.** → `docs/sync.md` § The refresh delta tops up the browsable tables
- **Anything that must fetch once a Sync pass is over listens to `ResyncController.lastCompletion` — the idle falling edge also fires for a cancelled pass.** → `docs/sync.md` § A screen that refetches after a Sync pass listens to `lastCompletion`
- The local `is_dirty` flag is **layered onto the domain model** in `<Repository>._fromRow` (e.g. `ClientRepository._fromRow`) — `<Entity>.fromApi` defaults it to `false`, the repo overlays the value from the Drift row. Without the overlay, an unsaved edit shows up as clean after app restart.

## Document version history

The five billing documents list their saved versions on a **History** tab, each opening that
version's PDF (invoiceninja/flutter#168). Every rule below is invisible at the call site.

- **A backup exists only for invoice / quote / credit / recurring invoice / purchase order, and it is a rendered HTML document — not a data snapshot, so nothing can diff or restore it.** → `docs/document-version-history.md`
- **`?include=activities.history` is the only include that works; `?include=history` is dropped and `POST /activities/entity` calls `->without('backup')`.** → `docs/document-version-history.md` § `activities.history` is the only include that works
- **The `history` object is serialized even when there is no backup, so `history.id` non-empty is the gate — never `history != null`.** → `docs/document-version-history.md` § The `history` object is present even when there is no backup
- **The list is capped at 50 activities with no pagination, free/trialing hosted accounts get no backups at all, and the UI says so rather than implying an empty or complete list.** → `docs/document-version-history.md` § Three server limits the UI has to admit
- **`download_entity` is the one call on this API where a 404 is a real data condition, not a bad URL.** → `docs/document-version-history.md` § A 404 here is a real data condition
- **A version label is legal on screen and illegal in a file name, so every name handed to `printing` goes through `sanitizeFileName` (`lib/utils/file_names.dart`) — the native share swallows the write error, so an illegal one is a Share button that does nothing.** → `docs/upstream-workarounds.md` § 12
- **Wide swaps the detail screen's existing PDF pane; only narrow routes to `/:id/pdf?activity_id=` — and that screen must never be re-keyed on the selection.** → `docs/document-version-history.md` § Wide swaps the pane; narrow routes
- **`no_history` is unusable (Greek in `fr.json`), and no bundle has a plural `versions` key — so the tab is `tr('history')` with `Icons.layers_outlined`, never the Activity tab's clock.** → `docs/document-version-history.md` § Two strings that look available and are not

## Data loading — bundled vs per-entity

Before adding a new module, decide how its data is fetched. Two buckets:

- **Bundled with the company on auth.** `/login` and `/refresh` accept `first_load=true`, which makes the server include company-scoped reference data alongside each company: tax rates, groups, designs, payment terms, expense categories, task statuses, subscriptions, schedulers, etc. The static catalog (currencies, countries, languages, industries, gateway types, date formats) is returned under `staticData` (`include_static=true`). `/refresh` already sends both — consume from that response, don't write a separate fetcher.
- **Loaded by their own routes.** High-volume, user-browsable entities: clients, invoices, products, payments, expenses, tasks, projects, quotes, credits, vendors, purchase orders, recurring invoices, etc. Full `BaseEntityApi` + page-by-page + Drift + outbox stack. **Never *load* these from `first_load`** — but the `/refresh` **delta** tops them up, and discarding it is what made a long session show days-old data. → `docs/sync.md` § The refresh delta tops up the browsable tables

Rule of thumb: small / mostly-read / company-shared / rarely-paginated (≲ a few hundred rows) → **bundled** (three-step seam in `docs/adding-an-entity.md` § Bundled entities: `CompanyEnvelopeApi` field + repo `applyBundle` + `AuthRepository.onPersistBundles` fan-out). The kind of list a user scrolls / searches / filters → **own route**, full per-entity stack. If unsure, probe `/api/v1/refresh?first_load=true&include_static=true` against the demo API — anything already there belongs in the bundled bucket.

**Bundled today**: the auth user record (`data[N].user`, written directly in `_persistAndActivate`), `task_statuses`, `company_gateways`. `applyBundle` is **upsert-only — never deletes** (`is_dirty=true` rows keep their outbox-bound payload until the next real sync); it advances the keyset cursor with `wasFullSync: true` so the screen's first `ensurePageLoaded` short-circuits.

## Sidebar counters

`lib/domain/sidebar_badge_modes.dart` is the single source of truth for what each sidebar row's count badge can count (`total` / `overdue` / `low_stock` / `assigned_to_me` / …, plus `none` to hide it). Every mode is answerable from columns already in Drift — **the badge never issues a network call**. The catalog now drives **two** surfaces — the rail's badge and the list's status tabs (below) — so adding or changing a mode is four coordinated edits:

1. the per-entity `SidebarBadgeMode` list here (+ its `badgeModes:` reference in `kWiredEntityModules`),
2. a case in that DAO's `badgeModePredicate` (`BaseEntityDao`; `BankTransactionDao` hand-rolls the same hook),
3. the mode's `labelKey`, plus an entry in `kSidebarBadgeModeSearchKeys` if it is a *specific* word worth surfacing in settings search (the generic status words — `draft` / `sent` / `approved` / `rejected` — are deliberately excluded, so most modes need no edit here),
4. a `ListStatusTabSpec` in `lib/domain/list_status_tabs.dart` — `list_status_tabs_test` fails the build if the two catalogs disagree, so a new mode can't quietly ship as a counter with no way to filter by it.

`sidebar_badge_count_test` fails the build if a declared mode has no predicate — the failure mode otherwise is silent, since a null predicate makes the badge count *every* row and still look like it works. Both pickers (the row's right-click menu and Settings → Device Settings → Sidebar counters) read the same registry list through `availableBadgeModes(...)`, so they can't drift apart.

- **Counts come from the local Drift cache, so on a large account a counter under-reports until the user browses or runs a Sync — making it exact needs a server-side count.** → `docs/entity-lists.md` § Counts come from the local Drift cache, so they can under-report
- **`Date.today()` is baked into a badge stream's SQL and the stream lives for the whole session, so leaving the app open past midnight keeps the date-sensitive counters on yesterday's date.** → `docs/entity-lists.md` § Date-sensitive counters go stale past midnight

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

- **Every field the entity's edit screen can set earns a column** → `docs/entity-lists.md` § Every field the edit screen can set earns a column
- **Real Drift column ⇒ `sortable: true` plus a `_sortExpression` case in the DAO. Derived or payload-only ⇒ `sortable: false` plus an entry in `sortable_columns_test`'s `displayOnly` map.** → `docs/entity-lists.md` § Sortable means a real Drift column and a `_sortExpression` case
- **Custom-field slots go through `customFieldColumns` (`custom_field_columns.dart`), never a hand-written `custom1` column.** → `docs/entity-lists.md` § Custom-field slots go through `customFieldColumns`
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
- **A server mapping must return a SUPERSET of the local predicate.** → `docs/entity-lists.md` § A server mapping must return a superset of the local predicate
- **A widened mapping MUST be marked `widened: true`, and that flag is not bookkeeping.** → `docs/entity-lists.md` § A widened mapping must be marked `widened: true`
- **Don't map a mode whose only superset is nearly the whole table.** Payment / credit `unapplied` were mapped once (`completed,partially_refunded` and every non-draft status): no useful narrowing, and `isNarrowedFetch` then costs the delta cursor too. Local-only plus the auto-chain is strictly better there. This is about supersets that buy nothing — an **exact** mapping pays the same cursor cost and it isn't a cost, because the fetch discards nothing after it lands, so a true offset page of precisely the tab's rows beats a delta slice.
- **A tab whose predicate reads another entity's table has to fetch that table too, or it reads zero.** → `docs/entity-lists.md` § A tab reading another entity's table has to fetch that table too
- **No strip on an embedded list** (`widget.embedded`): the counts are company-wide, so "Draft 47" on one client's Invoices tab would be a flat lie.
- **The strip renders whenever a tab is active, even with the device setting off** — a `badge_mode` restored from `nav_state` or applied by a saved view is a live filter, and hiding its only control would leave the list narrowed with nothing but "Clear filters" to escape. `_hydrate` drops a `badge_mode` naming a mode this build no longer offers, for the same reason `_migrateLegacyUpdatedBetween` exists.
- Counts are **active-only**, so the badges stand down (tabs keep filtering) when the list is showing archived / deleted rows, and they carry the same local-cache under-reporting caveat as the rail. A zero renders in the neutral palette whatever the bucket's tone — a red `0` would claim urgency about the one outcome that means there's nothing to do.
- Device-toggleable, default **on**: Settings → Device Settings → Status tabs (`nav_state.status_tabs`, schema v6, `StatusTabsController`).
- **The strip's edge fades are gated on the scroll position, like `EntityDetailTabs`'.** → `docs/entity-lists.md` § The strip's edge fades are gated on scroll position
- **The strip has a second, wrapped layout, used only by the dashboard's Invoices & Quotes panel — and selection there is a fill, not the underline.** → `docs/dashboard-panels.md` § A strip of counts is payload, so it wraps
- **Quote `rejected` is a tab but not a chip, and the difference is what reaches the wire.** → `docs/entity-lists.md` § Quote `rejected` is a tab but not a chip

## List state filter

The lifecycle dimension (`is:` / `state:` — active / archived / deleted) is a **`Set<EntityState>` that is never empty**, and deleted rows therefore appear only when somebody asks for them. `normalizeListStates` (`lib/domain/entity_state.dart`) makes that true by construction at **three** writers, not one: `setStates` — which is the choke point for every *user gesture*, since the filter key's `clear` / `addValue` / `removeValue` back the chip `×`, the checkbox picker and Backspace-on-an-empty-search-box alike — plus `_applyDecoded` (nav_state hydrate and saved-view apply) and `_applyIntentState` (dashboard deep links), which assign `_states` directly and so normalize themselves. Keep the three in step. A fourth site writes the *snapshot* rather than the set — see `docs/entity-lists.md` § A snapshot on disk needs healing at every site that reads one.

- **The empty set looked like the *absence* of a decision while being the widest possible one — three ordinary gestures reached it and nothing could get back out.** → `docs/entity-lists.md` § Why the empty set was a one-way trap (flutter#126)
- **Normalize on the list VM only — never at the DAO or repository seam.** → `docs/entity-lists.md` § Normalize on the list VM only, never at the DAO or repository seam
- **A key at its default renders no chip, and that guard must live in `TokenSearchController`, not in `tokensFrom`.** → `docs/entity-lists.md` § A key at its default renders no chip
- **Two consequences that are the rule rather than bugs: this reverses the old Sentry-style removable-chip choice, and the State picker's Active row goes inert on a default list.** → `docs/entity-lists.md` § Two consequences that are the rule, not bugs
- **A snapshot already on disk needs healing at every site that reads one — three that compare, and one that writes.** → `docs/entity-lists.md` § A snapshot on disk needs healing at every site that reads one

## Tasks layout view

The Tasks screen has five layouts (list / daily / weekly / calendar / kanban). The layout is **`?view=` on the URL as the override, `nav_state.tasks_view` as the fallback** — `tasksViewModeFromQuery` + `resolveTasksViewMode` (`lib/domain/tasks/tasks_view_mode.dart`, a leaf that imports nothing so `lib/app/tasks_view_controller.dart` need not import a UI screen; `task_list_screen.dart` re-exports the enum). Before invoiceninja/flutter#133 the URL was the only carrier, and since every structural "up" navigation drops the query string by construction, the mode was lost the moment the user tapped the FAB: `goToCreateRoute` `go`s a bare `/tasks/new`, `MasterDetailLayout` auto-promotes that to `?view=full`, and `entityCloseTargetPath` returns the bare `basePath` — so cancelling a new task landed on the plain list. Three sibling paths lost it too (closing a card's detail pane, re-tapping the already-active Tasks sidebar row, a company switch made from `/tasks/<id>`); Android back and the sidebar `←` never did, because `NavHistoryController` records the full URL. Five things are load-bearing.

- **The `view` key is overloaded, so `'full'` must parse to null.** → `docs/tasks-views.md` § The `view` key is overloaded, so `full` must parse to null
- **The fallback is suppressed whenever the screen can only be the plain list** → `docs/tasks-views.md` § The fallback is suppressed when the screen can only be the list
- **The toggle emits no `?view=` at all — a view switch is not a history step.** → `docs/tasks-views.md` § The toggle emits no `?view=` — a view switch is not a history step
- **`_RememberedTasksView` is the second writer, it writes post-frame, and its `ValueListenableBuilder` is unconditional.** → `docs/tasks-views.md` § `_RememberedTasksView` is the second writer, and its builder is unconditional
- **`stripTransientQuery`'s carve-out for a non-`full` `view` must stay** → `docs/tasks-views.md` § `stripTransientQuery`'s carve-out for a non-`full` view must stay
- **The kanban board is the one Tasks view with no create FAB, and the gate that makes that safe is not the one it looks like.** → `docs/tasks-views.md` § The kanban board is the one Tasks view with no create FAB
- **A booked block and a finished session are the same four wire slots, so "start the timer" is a decision, not an append.** → `docs/task-scheduling.md` § A booked block and a finished session are the same four wire slots

## Dashboard panels

The bottom grid's panels are ordered and hidden per device — `DashboardKind.panelKinds` is the registry, `DashboardPanelPref` the stored `"<kind>|<1|0>"` entry, and `DashboardViewModel._hydrate` places any kind missing from a saved arrangement **at its canonical rank** in `panelKinds`, visible-by-default. So a new panel needs no schema bump and no migration, and it goes at the slot it should occupy. (It used to append, which made a declared slot unreachable for anyone who had ever changed the date range — that persists the blob — so a new panel landed last on every existing install and first on a fresh one. → `docs/dashboard-panels.md` § A new panel goes at its canonical rank) `panelTitleKey` maps a kind to its l10n key (its `_ => kind` fallthrough makes an arm whose kind and key coincide a no-op — write it anyway, so the switch reads as the complete map it is). **The module gate lives in exactly one place**, `enabledPanelKinds` (`lib/ui/features/dashboard/helpers/enabled_panel_kinds.dart`): it was copied three times — the wide `_bottomGrid`, the mobile body's trailing list, and the manage sheet's Panels pane — and those three copies are precisely where a new panel half-ships, rendered on desktop, missing on mobile and inert in the manage sheet, each failure looking correct on its own screen. It takes predicates rather than a session so it stays a leaf and the whole module × permission matrix is unit-testable.

- **The task-calendar panel (invoiceninja/flutter#137) is the first Drift-backed one, and almost everything load-bearing about it is invisible at the call site.** → `docs/dashboard-panels.md` § The task-calendar panel, and the eleven things that hold it up
- **Per-day load is one rule in one leaf, and it buckets per time ENTRY.** → `docs/dashboard-panels.md` § Per-day load buckets per time entry, not per task
- **The month window is fetched from the server, by the view model, and it is month-aligned for a reason.** → `docs/dashboard-panels.md` § The month window is fetched by the view model, month-aligned
- **`hasLoaded` is not enough to claim availability, and the gate for that claim is not `Opacity`.** → `docs/dashboard-panels.md` § `hasLoaded` is not enough to claim availability
- **The "today" marker takes `onAccent`, never `accentInk`.** → `docs/dashboard-panels.md` § The today marker takes `onAccent`, never `accentInk`
- **The consolidated Invoices & Quotes panel is a *view* over two badge catalogs, and both DAO seams fail OPEN on a mode they don't recognise.** → `docs/dashboard-panels.md` § The Invoices & Quotes panel, and why its per-entity ids are explicit
- **A strip whose items carry counts wraps; one that carries navigation scrolls.** → `docs/dashboard-panels.md` § A strip of counts is payload, so it wraps
- **"Most recent" needs a tie-break, and `created_at == 0` means *newest*, not oldest.** → `docs/dashboard-panels.md` § Most recent needs a tie-break, and epoch 0 leads
- **A tabbed card is the one dashboard panel whose empty state may be the generic string.** → `docs/dashboard-panels.md` § A tabbed card is the one place the generic empty string is right
- **"Hide empty panels" is a device preference (null = automatic = on for a phone), a panel is empty only once its section loaded with no rows, the two Drift-backed panels never qualify, and the list drops the panel through `HiddenEmptyPanelsBuilder` — the card never hides itself.** → `docs/dashboard-panels.md` § An empty panel is dropped from the list, not hidden by the card
- **The narrow dashboard's `+` is a FAB opening a create sheet on the root navigator, and `quickCreateEntities` is the one gate for it and the wide New Invoice button — create route, module (payments ride the invoices bit), and `create_<entity>` (transactions are `bank_transaction`).** → `docs/dashboard-panels.md` § The `+` is a FAB that opens a create sheet

## Tap to call

Tapping a phone number on a detail screen or contact card opens the platform dialer
(invoiceninja/flutter#109). Device-local preference, five fields in one blob
(`nav_state.phone_actions_json`, schema v7); full rationale in `docs/tap-to-call.md`. Four things
here are not obvious:

- **The `tapToCall` default is `Env.isTouchPrimary`, not `true`** → `docs/tap-to-call.md` § The `tapToCall` default is the platform, not `true`
- **`tel:` / `sms:` deliberately bypass `isSafeWebUrl`.** → `docs/tap-to-call.md` § `tel:` / `sms:` deliberately bypass `isSafeWebUrl`
- **`cleanPhoneNumber` is where a wrong number comes from.** → `docs/tap-to-call.md` § `cleanPhoneNumber` is where a wrong number comes from
- **Every phone surface listens via `PhoneActionsScope`.** → `docs/tap-to-call.md` § Every phone surface listens via `PhoneActionsScope`
- **The billing-doc header call button is sized on the axis that has room** → `docs/tap-to-call.md` § The billing-doc header button is sized on the axis that has room
- **The list-row call button reclaims the touch target on the axis the *row* has** → `docs/tap-to-call.md` § The list-row button reclaims the target on the axis the row has
- **A logged call is an activity *note*, and the note is the only storage there is** → `docs/tap-to-call.md` § A logged call is an activity note, and the note is the only storage
- **The post-call offer is gated on `Env.isMobile`, not `Env.isTouchPrimary`** → `docs/tap-to-call.md` § The post-call offer is gated on `Env.isMobile`

## Reports

The whole feature is **server-backed**: `runPreview` POSTs `<endpoint>?output=json`, polls for a hash, and everything after that — filtering, sorting, grouping, totals, the chart — is local `ReportEngine` work over the returned rows. A report is one `const ReportDefinition` in `lib/domain/reports/report_registry.dart`; there is no per-report Dart.

- **The date range filters a column the report never used to name, and that column is not always one you can group by.** → `docs/reports.md` § The date range filters a column the report never names
- **A column the server omits can still be asked for, and that is how "new clients per month" works at all.** → `docs/reports.md` § Asking for a column the server omits
- **A period with no rows has no bucket, so a chart plotting buckets by index closes the gap.** → `docs/reports.md` § A period with no rows has no bucket
- **`GroupTotals.count` is a chart series, and bucket keys are identity.** → `docs/reports.md` § The count series, and bucket keys as identity
- **A non-date grouping splits by period (user × month) through a composite `<group>␟<period>` key that only `_rowGroupKeyFn` derives, and it never reaches the server.** → `docs/reports.md` § A non-date grouping splits by period through a composite key

## Localization

- Source of truth: **Transifex** (`explore.transifex.com/invoice-ninja/invoice-ninja`).
- Files in the zip are PHP arrays (`textsphp-<locale>.php`).
- `tools/import_transifex_zip.dart <zip>` parses those PHP files for locales in `kSupportedLocales` and writes `assets/i18n/<locale>.json`.
- Workflow per release: download zip → run the importer → commit the changed JSONs.
- Runtime: `Localization` loads the active locale's JSON from `rootBundle`. English is always loaded as a fallback. There is **no** server fetch and **no** override table — the bundle is the only source.
- Adding a locale = (a) add it to `kSupportedLocales`, (b) re-run the importer.
- **The upstream PHP is HTML-escaped — the importer decodes entities, don't bypass it.** Transifex ships `&#39;`, `&quot;`, `&gt;`, `&amp;`, `&eacute;` inside translated strings, and Flutter's `Text` has no HTML layer to undo them, so whatever lands in the JSON is literally what the user reads: Italian Settings showed `Colore dell&#39;accento`, French `Cl&eacute; d&#39;acc&egrave;s`. 504 strings across 7 locales shipped that way, invisible to the team because **English has zero entities**. `TransifexPhpParser.parse` now runs values through `decodeHtmlEntities` (`lib/l10n/transifex_php_parser.dart`, mirrored in the importer's own inline copy — keep them in sync). That function is the app's single entity decoder, not an l10n-private one — `lib/utils/notes_html.dart` imports it for the read-only notes surfaces — so don't narrow it to the importer's needs. It is deliberately a **single pass** so `&amp;#39;` stays the literal text `&#39;` rather than double-decoding to an apostrophe, and it leaves unrecognized entities, bare `&`, and markup tags (`<p>`, `<br>`) alone. `test/l10n/no_html_entities_test.dart` fails the build if an escaped string reaches `assets/i18n/`.
- **`_app_pending.json` can only *add* a key, never override one.** Lookup order is active locale → `en.json` → pending → raw key, so a pending entry whose key already has a non-blank `en.json` value is dead and never renders. 41 such entries had accumulated — one of them (`fees_sample`) left the gateway fee preview naming the *total* as the fee. `no_unsubstituted_placeholders_test` now fails the build on a shadowed entry; give deliberate rewordings a distinct name (`*_label` / `*_short` / `*_detailed`).
- **A placeholder name that prefixes another needs no care — because `lookup` sorts longest-first.**
  `":time in :timezone"` substituted in map-insertion order rewrites the second token to
  `"<value>zone"`, which then never matches: rendered garbage, not a missing string, so no `tr()`
  lint sees it, and which token wins depends on the caller's literal map order. `Localization.lookup`
  therefore replaces the longest name first (the single-param hot path returns before the sort).
  Five bundled keys have this shape — `activity_10`/`_39`/`_40`/`_41` (`:payment` + `:payment_amount`)
  and `entity_number_placeholder` (`:entity` + `:entity_number`); the activity templates dodge it
  only because `activity_description.dart` tokenizes with a regex instead of coming through `lookup`.
- **Never render a string carrying a `:placeholder` without filling it.** Many Transifex keys ship in two flavours: a parameterised one for when the app knows the value (`add_to_invoice` = "Add to invoice :invoice") and a plain verb for when it doesn't (`action_add_to_invoice` = "Add To Invoice"). Pointing a menu label at the former leaks the raw token (invoiceninja/flutter#35). Fix one, in this order: **(1) pass the params** — usually possible and always keeps the translation (`copyToClipboard` fills `:value` this way, with a `label:` when the payload is a blob); **(2) point at a placeholder-free Transifex sibling** (`action_add_to_invoice`, `invoice_sent_notification_label`, `min_amount`); **(3) last resort, add a distinctly-named app-local key** — that file is English-only, so this costs every non-English user their translation, and it's only right when the bundle has no clean variant (`view_expense_label`, `download_documents_label`). **Don't blank the token and `.trim()`**: German and Japanese put `:invoice` mid-string, so that leaves a double space. `test/lint/no_unsubstituted_placeholders_test.dart` fails the build on a leak it can see; keys reached through a variable, a const list, or a positional arg are invisible to it, so a renderer that looks up keys from a structure needs the invariant asserted in that structure's own test (`settings_search_catalog_test` does this).

## Rich text editing

`lib/ui/core/widgets/markdown_text_field.dart` is the shared WYSIWYG editor for every markdown-bearing field — the four billing-doc notes fields on all five entities, the 8 Defaults terms/footers, email settings, reminder templates, the user signature. It wraps `super_editor`, pinned in `dependency_overrides` to a monorepo SHA; the markdown serializer lives inside that package (the separate `super_editor_markdown` dependency is gone).

- **One-way data flow.** Parent owns the stored string (HTML — see the bullets below) and feeds `initialValue` + `externalValueKey`. The widget debounces edits (default 300 ms) and emits serialized markdown via `onChanged`. Force a reseed after an external write (e.g. an override toggle resetting to a cascaded parent value) by changing `externalValueKey` — the `(apiKey, value, isOverridden)` hash works well; see `overridable_markdown_field.dart`.
- **Server content is safe by construction.** `super_editor` deserializes markdown into Flutter's widget AST — no HTML/JS execution context.
- **These fields are HTML on the wire, so the editor emits HTML — and that HTML must carry no newline characters.** → `docs/rich-text-editing.md` § These fields are HTML on the wire, so the editor emits HTML
- **A read-only render of a notes field goes through `plainTextFromHtml`, and so does every "is it empty" gate in front of one.** → `docs/rich-text-editing.md` § A read-only render of a notes field goes through `plainTextFromHtml`
- **A field with no editor converts at its seams: seeded from a stored value ⇒ `htmlFromEditableValue`; always typed ⇒ `htmlFromPlainText`.** → `docs/rich-text-editing.md` § A field with no editor converts at its seams, and which converter depends on where its value came from
- **A report's string cells are flattened at the parse, not at the widget — five surfaces read the same string.** → `docs/rich-text-editing.md` § Report cells are flattened at the parse, not at the widget
- **Inbound HTML is folded to markdown by `markdownFromLegacyHtml` (`lib/utils/legacy_html_markdown.dart`) — never handed to the deserializer raw, and never with a hand-rolled `replaceAll`.** → `docs/rich-text-editing.md` § Inbound HTML is folded to markdown, never handed to the deserializer raw
- **A break the author typed accumulates, a break that two block tags both ask for merges, and inside a list both clamp to one.** → `docs/rich-text-editing.md` § A typed break accumulates, a block boundary merges
- **A marker construct that closes with no text in it must release the break hold, or it swallows the rest of the document.** → `docs/rich-text-editing.md` § An empty marker construct must release the break hold
- **A read-only editor blocks pointers at the *sliver*, never around the scroll host.** → `docs/rich-text-editing.md` § A read-only editor blocks pointers at the sliver, not around the host
- **The mobile caret is themed through `Theme.of(context).primaryColor`, and the `DefaultCaretOverlayBuilder` sitting right next to it is desktop-only.** → `docs/rich-text-editing.md` § The mobile caret is themed through `primaryColor`
- **`height` is a floor, not a size.** The field grows with its content up to `maxHeight` (half the viewport, capped 480) and only then scrolls internally; a contradiction resolves in favour of the floor (asserted). `expand: true` opts out — the parent bounds it, which is what the desktop notes pane does.
- **Template variables are inline placeholders the markdown never sees.** → `docs/template-variables.md` § Template variables are inline placeholders the markdown never sees
- **Every markdown field guards `$variables` from linkify.** → `docs/template-variables.md` § Every markdown field guards `$variables` from linkify
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

A record's actions menu offers **Share Link** on touch and **Copy Link**
everywhere else, handing out a link that opens the app on that record, switching
company first if it came from another workspace (invoiceninja/flutter#96). The
same `app_links` subscription also carries the calendar OAuth return, which is
what it was originally built for.

```
https://<instance>/app/<in-app route>?company=<companyId>   <- what ships
https://invoicing.co/app/clients/Wpmbk5ezJn?company=Xrtq1oa8Aq
invoiceninja://app/clients/Wpmbk5ezJn?company=Xrtq1oa8Aq     <- fallback, still parsed
```

- **The link is https because a custom scheme is not a link.** → `docs/deep-links.md` § The link is https because a custom scheme is not a link
- **Only `kHostedAppLinkHost` can ever be OS-verified, and the `/app/` prefix is what keeps that claim narrow.** → `docs/deep-links.md` § Only the hosted host can be OS-verified
- **Flutter's own deep linking must stay off, and turning it off costs iOS its cold start unless the shim stays too.** → `docs/deep-links.md` § Flutter's own deep linking must stay off
- **A link that names another instance is refused, not followed.** → `docs/deep-links.md` § A link naming another instance is refused
- **The whole route lives in the URI path, behind a constant `app` host.** → `docs/deep-links.md` § The route lives in the URI path, behind a constant host
- **Four pieces, deliberately split — `entity_links.dart` (a leaf), `deep_link_router.dart` (arrival choreography), `app_deep_links.dart` (the platform bridge), and `switch_company_guarded.dart`.** → `docs/deep-links.md` § The four pieces, deliberately split
- **Five things fail silently if you change this: double cold-start delivery, the dropped query string, the auth + biometric gate, the guarded company switch, and validating a path before `go()`.** → `docs/deep-links.md` § Five things that fail silently
- **Every detail screen passes `hydrate:` to `EntityDetailScaffold`, and `emptyAction:` gives a genuinely missing record a way onward — landing on an unopened record is the normal case.** → `docs/deep-links.md` § Landing on a record the recipient never opened
- **Two registry notes: a settings-hosted entity must still declare `detailBuilder`, and a settings `:id` route needs its own id-keyed subtree.** → `docs/deep-links.md` § Two registry notes this depends on
- **On web nothing delivers the link — it *is* the page URL, so `?company=` is honoured once at boot and stripped before it can persist.** → `docs/deep-links.md` § On web the link is the page URL

**Adding an entity?** `test/lint/entity_copy_link_coverage_test.dart` fails the
build unless its action enum declares `copyLink` — nothing in the type system
would otherwise notice a new entity shipping with no way to link to it.

## Desktop window state

Each desktop runner persists window size, position, and fullscreen across launches via the host OS's native preference store — one short native function per platform, no Dart/Flutter package. **N/A on web** (the browser owns the window chrome). The shared three-step contract and per-platform implementations (macOS + Windows done; Linux when added) are in `docs/desktop-window-state.md`.

## Web

Web is a supported target (`flutter run -d chrome`, `flutter build web`). Native (iOS/macOS) behavior is **byte-identical** — every platform difference is a `kIsWeb` branch or a conditional-import seam that resolves to the unchanged native code on native.

**Persistence.** drift WASM over IndexedDB/OPFS, unencrypted (no SQLCipher, no `PRAGMA key`) — the browser origin sandbox is the trust boundary, a locked product decision; don't add a web encryption layer without re-deciding. The auth token lives in `window.localStorage` (`LocalStorageTokenStorage`), not `flutter_secure_storage`. IndexedDB eviction (storage pressure / private mode) surfaces as the existing `dbWasReset` "fresh sync" flow, not a crash.

- **A web database reset must be verified, and a store the browser won't delete is abandoned (generation-bumped), never reopened.** → `docs/architecture.md` § Why the web database reset needs a store it can abandon

**Conditional-import seams** (default file = web, `if (dart.library.io)` override = native):
- `lib/data/db/database_opener.dart` → `_io` (SQLCipher file + keychain key + `.broken.<ts>` recovery) / `_web` (`WasmDatabase` + IndexedDB delete on reset). `pruneBrokenDbFiles` is native-only (`database_opener_io.dart`).
- `lib/data/services/token_storage_factory.dart` → `defaultTokenStorage()`: `SecureTokenStorage` (native) / `LocalStorageTokenStorage` (web).
- `WebBiometricService` (`biometric_service.dart`) — `isAvailable() => false`; selected via `kIsWeb` in `Services.build`. Biometric/lock UI hides itself.

**Vendored WASM assets** (committed in `web/`, served from app root): `web/sqlite3.wasm` (plain unencrypted build, from the [sqlite3.dart releases](https://github.com/simolus3/sqlite3.dart/releases) — must match the resolved `sqlite3` Dart package version) and `web/drift_worker.js` (`dart compile js -O4 -o web/drift_worker.js web/drift_worker.dart`). **Regenerate both on any `drift`/`sqlite3` bump** — version skew between the vendored assets and the Dart packages is the #1 web runtime failure mode. `database_opener_web.dart` logs `WasmDatabase` `missingFeatures` at boot.

**URL strategy: hash (`/#/clients`), the Flutter default.** Intentionally left as-is (no `setUrlStrategy`) so the build deploys to any static host with no rewrite-to-index config. Locked decision (see the comment near `runApp` in `main.dart`) — don't switch to `PathUrlStrategy`.

**`dart:io` compiles on web.** Flutter's web toolchain provides a compile-time `dart:io` stub; `import 'dart:io'` does **not** break `flutter build web` — the classes (`File`, `Directory`, `Platform`) throw `UnsupportedError` only when *used* at runtime, so a `kIsWeb` guard before the call suffices (no conditional-import file needed just for the compiler). Prefer `defaultTargetPlatform` + `kIsWeb` over `Platform.isX` in new code (`env.dart` / `support_api.dart` are the reference).

**Disabled on web** (already guarded): native splash/window theming, biometric, in-app purchase (upgrade routes web→Stripe portal via `upgrade_launcher`), Google + Apple OAuth login buttons (email/password only — there is no in-app OAuth callback handler).

**Web does not send `Idempotency-Key`.** The API's CORS allow-list omits it, so the browser's preflight rejected every web write — while the server ignores the key anyway. `ApiClient(sendIdempotencyKey:)` defaults to `!kIsWeb`; re-enable it on web once the server allows **and** honours the header (`BACKEND.md` § Web platform CORS).

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
