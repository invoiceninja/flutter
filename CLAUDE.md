# Invoice Ninja — Flutter App (rebuild)

This is a clean-room rebuild of `/Users/hillel/Code/admin-portal`. Read this file before changing anything substantial.

**This file is an index of rules, not a record of investigations.** It loads into every session, so `test/lint/claude_md_size_test.dart` caps it. When you learn something worth keeping:

- **The rule goes here** — one bolded sentence, enforceable on its own, as a bullet under the matching `##` / `###`, ending `→ docs/<file>.md`. No `§` after the path: the doc carries a `##` heading worded like the bullet, so grep for it there.
- **The evidence goes in that doc**, under that heading — the mechanism, the SDK/server source that explains it, the measured numbers, the failure it shipped as, the test that pins it.
- **Nothing here runs past ~4 lines** (the lint caps a line at 800 characters). A paragraph that is neither a rule nor a recipe carrying a value you need while typing belongs in a doc, leaving its rule behind as one sentence.
- **If no doc fits, create one named for the question it answers** (`docs/touch-targets.md` — never a grab-bag name, never just the section's name). Open it with `Companion to CLAUDE.md § <Section>. <what lives where>` and add its line to `docs/README.md`.
- **The Quick Index is short on purpose.** Add a row only for a symptom no row covers; the full table is `docs/README.md` § Symptom index.

Citations elsewhere in this repo read `CLAUDE.md § <Section>` or a bare `§ <Section>`. **Never rename a heading** — the lint resolves every citation against the headings in CLAUDE.md, `docs/` and the root `*.md` files. Every `##` section here still exists, even where its body is one line and a pointer.

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
| Adding an entity, or one with no create screen (the Documents list) | § Adding a new entity · `docs/adding-an-entity.md` · `docs/documents-list.md` |
| A settings screen, or anything in the visual invoice designer | § Settings screens · `docs/settings-screens.md` · § Visual invoice designer · `docs/invoice-designer.md` |
| A form field: Enter-to-save, keyboard type, autofill, capitalization, a negative amount on touch | § Forms · `docs/form-fields.md` · `test/lint/field_input_types_test.dart` |
| A picker: won't close on touch / Android back, a dead empty box, a Client / Vendor that locks once saved, the assignee roster | `docs/pickers.md` · `docs/popup-dismissal.md` · `lib/ui/core/widgets/entity_picker_field.dart` |
| An overflow / `MenuAnchor` menu: which icon, or Android back not closing it | § Design system (v2) · `docs/popup-dismissal.md` |
| Money, dates, parsing, or invoice / quote / credit totals math | § Strict rules · § Forms · `docs/sync.md` (rounding scale) · `tool/totals_oracle.php` |
| Buttons that stack or stretch, spacing tokens, a blank or tall toast | § Design system (v2) · `docs/buttons-and-spacing.md` · `docs/toast-messages.md` |
| A risky action's confirmation, or a sign-out / session-ending surface | § Action confirmations · `docs/adding-an-entity.md` |
| A shortcut that needs a click first, a macOS beep, a `G`-leader jump | `docs/keyboard.md` · `lib/domain/leader_shortcuts.dart` |
| Sync / outbox / 400–422 behavior, or a hosted real-time push | § Sync — non-obvious rules · `docs/sync.md` · `docs/realtime-updates.md` |
| Bundled vs per-entity data loading | § Data loading — bundled vs per-entity |
| Architecture, write pipeline, project layout | § Architecture — at a glance · `docs/architecture.md` |
| A Drift schema change, or a device preference (which needs none) | `docs/migrations.md` · `docs/device-preferences.md` |
| The sidebar: count badges, menu order, the pinned Settings / Outbox rows | § Sidebar counters · `docs/sidebar-and-shell.md` · `lib/domain/sidebar_menu.dart` |
| An entity list's columns, status tabs or State filter | § List columns · § List status tabs · § List state filter · `docs/entity-lists.md` |
| A report, its date field, grouping, or chart | § Reports · `docs/reports.md` |
| A dashboard panel, hiding empty ones, the `+` create sheet | § Dashboard panels · `docs/dashboard-panels.md` · `lib/domain/quick_create.dart` |
| Tasks: a layout view, the kanban board, a booked-but-not-started task | § Tasks layout view · `docs/tasks-views.md` · `docs/task-scheduling.md` |
| Content that doesn't fit its pane: a filter bar, a tab strip, a Tasks header, a FAB over a list | `docs/pane-width-and-overflow.md` · `lib/ui/core/utils/fab_clearance.dart` |
| A billing-doc edit screen (invoice / quote / credit / PO / recurring), or its History tab | `lib/ui/features/billing_shared/edit/billing_doc_edit_layout.dart` · `BillingDocType` · § Document version history |
| A list row: its one tap target, a zero vs a dash, a screen-reader action, pull-to-refresh | `docs/row-actions-and-values.md` · `docs/pull-to-refresh.md` · `lib/ui/core/list/cell_slot.dart` |
| A record screen's layout, comments, activity rows, a `Viewed` pill | § Detail screens · `docs/detail-screen-layout.md` · `docs/comments-and-activity.md` |
| A contact reading `(no name)`, invitations, the Email History tab | `docs/contacts-and-invitations.md` |
| Localization / Transifex, a string showing `&#39;` or a raw `:placeholder` | § Localization · `docs/translated-string-rendering.md` |
| Email-template `$variables` as chips | `docs/template-variables.md` |
| A markdown / notes / terms field, edited or read-only | § Rich text editing · `docs/rich-text-editing.md` |
| Cross-checking admin-portal / React / the server, or probing the demo API | § Reference points · `docs/probing-the-demo-api.md` |
| A self-hosted server's TLS certificate the device refuses | `docs/trusting-a-self-hosted-certificate.md` |
| Setup: entitlements, dev login, Google Sign-In IDs, app icons | `docs/setup.md` |
| Release builds, Sentry DSN, iOS archive, F-Droid, store deploys | `docs/setup.md` § Release builds with Sentry · `docs/fdroid.md` · `docs/store-deployment-setup.md` |
| Writing release notes, or the What's New dialog after an update | § Release Notes · `docs/release-notes.md` · `docs/whats-new-dialog.md` |
| CI workflows, perf benchmarks, integration tests | `.github/workflows/_test.yaml` · `docs/performance-tracking.md` · `docs/integration-tests.md` |
| Server-side filter gaps / required API changes | `BACKEND.md` |
| A runtime error or a stale outbox row | § Diagnostics log · `docs/diagnostics.md` |
| Desktop window state, the title bar, its drawn buttons | `docs/desktop-window-state.md` |
| Deep links, App Links, a file shared into the app | § Deep links · `docs/deep-links.md` · `APP_LINKS.md` · `docs/sharing-files-into-the-app.md` |
| Running on the web | § Web · `docs/web-platform-differences.md` |
| Tap-to-call / SMS on a phone number | `docs/tap-to-call.md` |
| Tap-target sizes, row heights, list density, a keyboard covering a field | `docs/touch-targets.md` · `docs/list-density.md` · `docs/sidebar-and-shell.md` |
| An open upstream (Flutter / pub) bug workaround | `docs/upstream-workarounds.md` |
| What's built vs what's left | `FEATURES.md` |
| Anything not listed here | `docs/README.md` § Symptom index (the full table) · one line per doc above it |

## Strict rules

Rules that turn into bugs or CI failures if forgotten. Read this block first.

- **No Redux. No bloc. No Riverpod.** `ChangeNotifier` only. Tempted to add one? Talk to the team first.
- **No `per_page=999999`.** Lists fetch one page at a time (50 rows default): the ViewModel calls `repo.ensurePageLoaded(N)` near the scroll edge, the repo writes the page to Drift, the UI reacts via the watch stream. A CI lint grep-fails the build if the literal appears in `lib/`.
- **Money is `Decimal`, never `double`.** Enforced by a CI test (greps entity models).
- **Date-only is the custom `Date` type; `DateTime` is for timestamps only.** Mixing them silently breaks invoice math.
- **Drift is the only thing the UI reads from.** The network writes to Drift; the UI watches Drift. Never read API responses straight into UI state.
- **Schema changes need a forward Drift migration (the app is shipped).** Bump `AppDatabase.schemaVersion`, add an `onUpgrade` step, re-dump and re-generate the schema, extend the matrix test — and **never re-squash or overwrite a shipped `drift_schemas/drift_schema_v*.json`** (a frozen-checksum test fails the build). Skipping it wipes the user's local DB and unsynced edits. → `docs/migrations.md`
- **A device preference is a `DevicePrefKeys` entry, never a `nav_state` column or a schema change — its `PrefScope` decides whether a sign-out forgets it, and its controller follows `DevicePrefsStore`, so there is no reset hook to wire.** → `docs/device-preferences.md`
- **Every `onUpgrade` step runs inside its one `transaction()` and must be safe to run twice — `_addColumnIfMissing`, never a bare `m.addColumn`.** → `docs/migrations.md`
- **A failed database open destroys the store only when a fresh store fixes it** (corrupt, or drift / a failed upgrade that `repairSchema` can't fix); a lock — on web, just a second tab — a full disk or an unrecognised error leaves it untouched. → `docs/migrations.md`
- **Every new table is classified durable / anchor / cache in `kTableRetention`** — repair may drop only cache tables. → `docs/migrations.md`
- **A reset quarantines the store and an open imports its non-cache tables, once — the `.salvage` marker is taken *before* the import, because a second import resends delivered outbox rows — reading the snapshot with the key the open used, never a second keychain read.** → `docs/migrations.md`
- **A reset's outcome reaches the user once per launch, never over the lock screen — a toast when everything came across, a dialog when unsynced work may not have — and a copy it keeps leaves the device only through Device Settings → Data.** → `docs/migrations.md`
- **One process per store: `holdStoreLock` runs before the key is read and before any reset moves the store, and refuses only a lock another process holds — `inUse` gets no Reset.** → `docs/migrations.md`
- **Auth user data flows in through `/refresh`, not `GET /users/{id}`** (412-gated). `_persistAndActivate` upserts each `data[N].user` into `users` on every login/refresh; `auth.refresh()` is a full session snapshot, not for incidental work — never call `UsersApi.get` from incidental paths.
- **Every write goes through the outbox.** Repositories never call mutation endpoints directly. (Accepted exceptions, each a synchronous UI flow that can't queue: the calendar-connection OAuth handshake/`setCalendars`/`disconnect` in `CalendarConnectionRepository`, and `QuickbooksRepository` — see their class docs.)
- **Every list query is scoped by `company_id`.** Use `CompanyScopedDao` — direct table access bypassing the DAO fails a lint check.
- **Idempotency keys are stable across retries** — generated when the outbox row is created, reused on every retry.
- **Format money / dates / addresses through `Formatter`** (`lib/utils/formatting.dart`). `Formatter.money(amount, clientCurrencyId: ...)` runs the per-client → company currency cascade + Euro override; `Formatter.date(date.toIso())` honors company `date_format_id`. Never render `Date.toIso()`, `DateFormat`, or `MaterialLocalizations.formatMediumDate` directly — `toIso()` is for storage/API/Drift keys only. Build the `Formatter` once per screen via `services.formatterFor(companyId)` and pass it down. Parse user input via `parseDecimal(input, useCommaAsDecimalPlace: ...)`.
- **No `vm.<entityName>` / `vm.<entityName>s` aliases on list/detail VMs.** Canonical accessors are `vm.item` (detail) and `vm.items` (list), defined on the generic bases.
- **Imports are `package:admin/...` inside `lib/`, never relative** — `export`s and both branches of an `if (dart.library.io)` seam included; `test/lint/package_imports_test.dart` is the gate. **A test importing a test helper stays relative by design — don't "fix" it**; only a relative path into `lib/` is banned there. → `docs/architecture.md`
- **`lib/data/**` must not reach `lib/ui/**`, not even transitively.** → `docs/architecture.md`
- **CI runs in UTC; the dev machines here don't.** A fixture whose expectation depends on a calendar day or wall-clock time sits in the ~11:00–13:00 UTC band (the same local day from UTC−11 to UTC+10); `DateTime.toLocal()` is the trap and task time-log grouping (`_isoDay`, `lib/domain/tasks/task_invoice_notes.dart`) the live example. Check with `TZ=UTC flutter test <file>` before pushing.
- **Don't run integration tests locally unless the user explicitly asks** — they take over the foreground app and interrupt the session. Never run them proactively or as incidental verification; let CI run them. On-request procedure: `docs/integration-tests.md`.
- **`FEATURES.md` is the parity tracker — keep it current, by hand.** It compares React (`/Users/hillel/Code/react`), Flutter v1 (`/Users/hillel/Code/admin-portal`) and this rebuild; a PR that finishes a feature flips its Flutter v2 cell in the same PR (no precedent: `—` / `—` / `✅`; scaffolded: 🟡). Legend: ✅ done, 🟡 partial, ❌ not implemented, — N/A.
- **Store SDKs (Google Sign-In, in-app purchase, Sentry) are imported only from `packages/store_services`, never from `lib/` or the root pubspec — the F-Droid build swaps that package for its FOSS twin.** → `docs/fdroid.md`
- **The F-Droid APK is built only by `fdroid build` running `tools/foss/com.invoiceninja.admin.yml` in F-Droid's digest-pinned image, signed only by the dedicated F-Droid key, and published only after a varied rebuild matches it.** → `docs/fdroid.md`
- **The mobile-app promo never shows Android or Google Play on native macOS, never gates anything, and never carries purchase copy.** → `docs/mobile-app-promo.md`
- **Pub packages are fine (`pubspec.yaml` + `flutter pub get`); npm / pip / brew / gem / cargo / system installers need explicit approval first.**
- **Never add a Claude / AI `Co-Authored-By` (or any "Generated with" / assistant) trailer or line** to commit messages or PR bodies. Commit messages contain only the human-authored description. This overrides the harness default.
- **Never create, switch, rename, or delete git branches in this working tree** (`git branch`, `git checkout <branch>`, `git switch`) — several Claude sessions share this checkout. Commit on the current branch only when asked; if a task seems to need a branch, stop and ask. This overrides the harness default. Sole exception: the integration-test procedure's isolated sibling worktree (`docs/integration-tests.md`).
- **Android system back == the sidebar `←` (history back), and three things keep it working.** → `docs/architecture.md`
- **A refused certificate is accepted only when its leaf's SHA-256 is pinned for that self-hosted host:port; only `main.dart` installs the `HttpOverrides`, before `Services.build`, and nothing sets `badCertificateCallback` — it sees the chain top.** → `docs/trusting-a-self-hosted-certificate.md`
- **Boot must always reach `runApp()` — every await in front of it is bounded and caught, and on web the failure has to be printed or it is invisible.** → `docs/architecture.md`
- **Launch-time work is measured with `traceSync` / `traceAsync`, not guessed.** → `docs/startup-responsiveness.md`
- **A path users wait on gets a benchmark in `benchmark/perf/` and a budget; never rename a benchmark id — its history is filed under it.** → `docs/performance-tracking.md`
- **Contacts sync touches only a device contact it can prove it wrote — a link row whose recorded entry is the contact's only one (`ownsDeviceContact`) — never one found by label membership; Android merges cards into the user's own contacts, and a delete through the merged contact takes theirs.** → `docs/contacts-sync.md`
- **Workarounds for open upstream bugs are logged in `docs/upstream-workarounds.md`** — issue link, files tagged KEEP vs MUST-REVERT, revert steps — whenever you add, change or remove one.

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

- **The five billing documents share one edit layout (`BillingDocEditLayout`) and one view-model base (`BillingDocEditViewModel`); a difference between them is a `BillingDocType` value or a `BillingDocEditSlots` entry, never a copy.** → `docs/architecture.md`

## Design system (v2)

Token-based visual language; the Dart port is the sole source of truth.

- `lib/app/design_tokens.dart` — **the source of truth** for colors, radii, shadows, type. Read tokens via `context.inTheme.<name>` (e.g. `context.inTheme.surface`). **No new color constants** outside `InTheme`. `InRadii` / `InSpacing` are brightness-independent.
- `lib/app/theme.dart` — wires `InTheme.light` / `InTheme.dark` into `ThemeData` (incl. per-component button/shape themes).

When styling a page: read `design_tokens.dart`, reuse `InTheme`, prefer `Theme.of(context).colorScheme` + `context.inTheme` over hardcoded `Color(0x…)`.

- **The drawn window buttons are the one exception to every shape rule below.** → `docs/desktop-window-state.md`

**Always rounded rectangles, never pills.** Use `RoundedRectangleBorder(borderRadius: BorderRadius.circular(InRadii.r2))` (or `.r1` / `.r3` per size) — never `StadiumBorder`, never `BorderRadius.circular(999)`. Material 3 defaults `SegmentedButton` / `Chip` / `FloatingActionButton.extended` to pills, so `theme.dart` registers the rounded shape on every relevant component theme; new widgets inherit it. Add new component themes to `theme.dart` rather than overriding inline.

- **Always the vertical `⋮`, never the horizontal `⋯`.** → `docs/popup-dismissal.md`
- **Touch targets are gated on the platform, not the viewport** — and five traps each silently produce the wrong size (full text of each: `docs/touch-targets.md`):

1. A row floor is `ConstrainedBox(minHeight:)`, never `SizedBox(height:)` — a fixed height slices descenders at large text scale.
2. `VisualDensity.compact` subtracts 8 from an `IconButton`'s explicit constraints (`tightFor(44, 44)` renders 36) — drop the density on touch.
3. `padded` `materialTapTargetSize` (iOS/Android) inflates an `IconButton`'s *layout* to 48 — pass `tapTargetSize: shrinkWrap` (sidebar rows: `SidebarRowIconButton`; hover-revealed buttons too).
4. A `SidebarNavItem`'s `trailing` drives the row's cross axis — cap it to the row's content box, not the target.
5. **A fixed-width slot holding `IconButton`s is sized from the touch branch, and the buttons pinned.**

- **A `MenuAnchor` is not a route, so Android's back has to be wired by hand — use `BackDismissibleMenuAnchor`** → `docs/popup-dismissal.md`
- **The company switcher is a control, not a label — never gate it out of existence.** → `docs/sidebar-and-shell.md`
- **A filter surface too tall for its pane becomes an icon, and the chip strip that replaces it renders nothing at all when nothing is filtered.** → `docs/pane-width-and-overflow.md`
- **The three time-oriented Tasks headers take the screen's pane bool, and the calendar one had no width branch at all.** → `docs/pane-width-and-overflow.md`
- **A tab strip is a width budget, and Material spends 52 px of it before you write a line.** → `docs/pane-width-and-overflow.md`
- **A `Stack` mounted for a FAB loosens what is under it, and that is what left an empty state in the corner.** → `docs/pane-width-and-overflow.md`
- **A floating button is a bottom inset every scrollable under it has to pay, and passing that padding means owning the safe inset too.** → `docs/pane-width-and-overflow.md`
- **A landscape phone is not a small desktop.** → `docs/touch-targets.md`
- **One surface, one safe-area owner — and the owner has to be the *last* thing, not the first.** → `docs/sidebar-and-shell.md`
- **`Ink` is banned (`test/lint/no_ink_widget_test.dart`) — paint a tappable surface on a *local* `Material`.** → `docs/sidebar-and-shell.md`
- **A viewport can be too *short* for optional chrome, and `Breakpoints` cannot answer that.** → `docs/sidebar-and-shell.md`
- **The main menu is a *preference*, and the two halves of that fail in opposite directions.** → `docs/sidebar-and-shell.md`
- **Settings and Outbox are chrome, not destinations — they are pinned below the nav list, and their selected state drops the accent.** → `docs/sidebar-and-shell.md`


- **On a narrow viewport nothing above a screen owns a `Scaffold`, so every full-page host must bring its own — and a missing one costs keyboard avoidance, silently.** → `docs/sidebar-and-shell.md`
- **A scroll view under a `RefreshIndicator` that is handed a `controller:` must ask for `physics: const AlwaysScrollableScrollPhysics()` — the controller switches that default off, and a list shorter than its viewport can then never be pulled (`test/lint/refresh_indicator_physics_test.dart`).** → `docs/pull-to-refresh.md`

**Buttons and spacing** (evidence: `docs/buttons-and-spacing.md`):

- **Pair related action buttons side-by-side** — Cancel next to the primary, never above it: a `Row` with `SizedBox(width: InSpacing.md(context))` between.
- **In a `Row` or `AlertDialog.actions`, a `FilledButton` / `.tonal` needs `minimumSize: const Size(64, 44)` (`OutlinedButton`: `Size(64, 40)`).** The theme's `Size.fromHeight(44)` is infinite width — it crashes a `Row` and silently stacks dialog actions. A centred single button (an `EmptyState` action) needs the same override or renders edge to edge.
- **Dialog primaries use `PrimaryDialogAction`** (the override, `autofocus`, the dimmed `↵` Enter hint; `variant:` plain / `.tonal` / `.destructive`). Pass `showEnterHint: false` for a dropdown-only dialog and for a primary that starts disabled — Enter can't reach either.
- **`InSpacing.md` / `InSpacing.lg` are responsive and take a context** (`md` 8 / 12 px, `lg` 12 / 16 px, split at 600): `EdgeInsets.all(InSpacing.lg(context))`, so drop `const` from the wrapping `EdgeInsets` / `SizedBox` / `Padding`. `sm` (8), `xs`, `xl`, `xxl` stay const.
- **Bordered-card form sections pad with `InSpacing.lg(context)`** (`FormSection`, `DashboardCardShell`); column-aligned interiors use it horizontally so cells line up with the section title.

- **Keyboard-shortcut discoverability.** → `docs/keyboard.md`
- **The whole keyboard layer hangs off one focus node, and every framework recovery path drops it somewhere that node cannot see.** → `docs/keyboard.md`
- **A keeper reclaims focus only when it escaped *upward* — never from a surface beside it, and a route check cannot tell the difference.** → `docs/keyboard.md`
- **The `G`-leader table has one copy, and it is not in the shell.** → `docs/keyboard.md`
- **A chord is one cap per glyph, never a concatenated label.** → `docs/keyboard.md`
- **Inside a cap a key gets its printed name** → `docs/keyboard.md`

- **Task status colours resolve through `taskStatusColors`, never an inline parse of `TaskStatus.color`** — `''`, `#fff` and `#ffffff` all mean unset. → `docs/tasks-views.md`
- **Initials avatars go through `InitialsAvatar` + `initialsFor`, seeded on the entity id (never the name), and a row's badge keeps its 32×32 slot even when empty.** → `docs/row-actions-and-values.md`

- **A narrow list row has exactly one destination, and a link's at-rest affordance is gated on the input device.** → `docs/row-actions-and-values.md`
- **A pure navigation action must never reach an edit screen.** → `docs/row-actions-and-values.md`
- **An empty value is an em dash in a *labelled* slot and nothing at all in an unlabelled one.** → `docs/row-actions-and-values.md`
- **A zero in a detail KPI cell has three possible renderings, and picking the wrong one is invisible in review.** → `docs/row-actions-and-values.md`
- **A conditional KPI cell means the layout must be count-agnostic — which is now a solved problem, so don't re-solve it.** → `docs/row-actions-and-values.md`
- **The server seeds one all-blank contact per client and per vendor, so `contacts.isNotEmpty` is never the question — `isBlank` per row is.** → `docs/contacts-and-invitations.md`
- **An invitation is created when the DOCUMENT is saved, so `invitations.isNotEmpty` is never the question — `hasSendHistory` per row is.** → `docs/contacts-and-invitations.md`
- **A contact's email can be one the *server* typed, and it is indistinguishable from the user's except by shape.** → `docs/contacts-and-invitations.md`
- **A row that prints the same name twice is the *normal* state for an individual, and the only usable tell is string equality against the title the row is already rendering.** → `docs/contacts-and-invitations.md`
- **A card that hides itself still costs a gap.** → `docs/comments-and-activity.md`
- **A record's comments live above the fold, and the card that shows them is the one place the gap rule inverts.** → `docs/comments-and-activity.md`
- **The record's own history leads every detail strip, and the strip now scrolls itself.** → `docs/comments-and-activity.md`
- **A note is not a sentence — the bypass is keyed on `isComment`, not `isCallNote`.** → `docs/comments-and-activity.md`
- **A client's comment feed is *mixed*, and the source record has to be named.** → `docs/comments-and-activity.md`
- **A comment cannot be edited or deleted, so the row offers what it honestly can and the dialog says so once.** → `docs/comments-and-activity.md`
- **An inline link inside a sentence cannot be hit by a finger, so the activity row itself is the target.** → `docs/comments-and-activity.md`
- **The per-entity activity fetch is eager, shared, debounced and stale-while-revalidate — and its cache is user-scoped.** → `docs/comments-and-activity.md`
- **A `Viewed` pill is the way into the activity that recorded the view, and the caption beside it is what survives the status moving on.** → `docs/comments-and-activity.md`
- **A status pill that leads somewhere paints its ink inside its own tint, and on touch it says so with an underline.** → `docs/comments-and-activity.md`
- **A one-shot reveal outlives its consumer, and the row scrolls itself.** → `docs/comments-and-activity.md`
- **The `activity_type_id` → tone map is the server's catalog, not a guess — and the bundled template is the test.** → `docs/comments-and-activity.md`

- **The `/activity` timeline charts only the loaded window, and each count leaves out its own filter — the bars ignore the date range, the category chips ignore the categories.** → `docs/activity-timeline.md`
- **The activity cache row is shared with the dashboard card, so a fetch merges into it (never a gap, the fetch owns its span) — never replace it; Load more pages back with the feed's `before` cursor where the server honours it, else grows the window to `kActivityWindowMax`.** → `docs/activity-timeline.md`

- **A screen-reader heading sets both `header: true` and `headingLevel:` (1 for a dialog or sheet title, 2 for a section) — since Flutter 3.47 iOS and Android read only the level, while desktop and web still read the flag.** → `docs/screen-reader-headings.md`

- **Toast strings are normalized centrally by `ToastController.show` — don't hand-guard them, never put a newline in a title (join with `' · '`), and give the context-free `Notify.capture` path a `tr()` string, never a raw server one.** → `docs/toast-messages.md`

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

Reusable fields (`OverridableTextField`, `ClientEditField`) read the scope themselves. A raw single-line `TextField` reads `FormSaveScope.maybeOf(context)`, sets `textInputAction: TextInputAction.done` and pipes `onSubmitted` to `scope.trySubmit()`; a dialog with one text input wraps its body in `FormSaveScope` too. → `docs/form-fields.md`

### Empty for blank numeric fields

Numeric fields seeded from a non-nullable `Decimal` render **empty for zero**, not `"0"`: `decimalInputText(value)` for an `EntityEditField`'s `initial:` (never `.toString()`), `Formatter.inputMoney(value, currencyId: ...)` for money (`''` for zero), `Formatter.inputAmount(value)` for a `num`. Reference: `product_edit_screen.dart`.

### Searchable pickers

Any dropdown bound to a long list (countries, currencies, languages, industries, timezones — anything past ~20 options) **must** support type-to-search.

- **Plain pickers**: `SearchableDropdownField<T>` (`lib/ui/core/widgets/searchable_dropdown_field.dart`) — generic on the item type; takes `displayString` + `idOf` projections.
- **Settings pickers with cascade-override**: `OverridableSearchableDropdownField<T>` — same shape as `OverridableDropdownField`, use on settings pages.

Don't introduce new `DropdownButtonFormField`s for long lists. They're fine only for short fixed enums (~10 items max — Classification, Size, Custom Field Type).

- **Opening a picker that already has a value shows the whole list, and that takes two cooperating rules — don't remove either.** → `docs/pickers.md`
- **The options popover must not wrap itself in an `Align`.** → `docs/pickers.md`
- **Touch gets a different picker without a different widget.** → `docs/pickers.md`
- **On native touch nothing closes the options popover but a pick — so every `RawAutocomplete` field sets `onTapOutside`.** → `docs/popup-dismissal.md`
- **Android's back is the other dismissal, and a picker popover is not a route either — wrap it in `BackDismissiblePickerOverlay`** → `docs/popup-dismissal.md`
- **The ▾ is the only *visible* way to close a picker, so it has to be a button.** → `docs/pickers.md`
- **A picker's empty state has to say something, and its selection must not be resolved by scanning the list.** → `docs/pickers.md`
- **The assignee roster has one home now, and the five rules it enforces are each invisible at a call site.** → `docs/pickers.md`
- **The create-task-from-a-line sheet seeds the Status and deliberately does not seed the assignee.** → `docs/pickers.md`
- **A re-pick of the value the field already holds is a real command, not a no-op.** → `docs/pickers.md`
- **Inline create goes through `SearchableDropdownField.onCreateRequested` (via the shared `VendorPickerField` / `ExpenseCategoryPickerField` / `ClientPickerFieldWithCreate`), never `footerBuilder` — the footer is unreachable on an empty match.** → `docs/pickers.md`
- **A field the server freezes on UPDATE is a locked row, not a disabled picker, and the reason sits outside its tap surface.** → `docs/pickers.md`

### Input types

Every text input declares the keyboard, capitalization and autofill its data needs. A soft keyboard never renders under `flutter test`, so `test/lint/field_input_types_test.dart` pins it (`// lint: allow-input-type <reason>` opts out). → `docs/form-fields.md`

- **`signed:` is checked before `decimal:`, so `decimal: true` alone means no minus key.** → `docs/form-fields.md`
- **Autofill hints go only on the signed-in user's own identity or their own company.** → `docs/form-fields.md`
- **`TextInputType.multiline` is derived — never add it.** → `docs/form-fields.md`
- **Spell check goes through `LineItemSpellCheck` — a raw `SpellCheckConfiguration()` on a platform with no service throws in debug and draws nothing, and one held from the first build never checks the saved text.** → `docs/spell-check.md`

**Postal code is `text` + `TextCapitalization.characters`, never `number`** — UK / CA / NL / PL codes aren't numeric.

- **A credential is obscured and keyboard-hardened; whether it also gets autofill depends on whose credential it is.** → `docs/form-fields.md`
- **`autocorrect: false` on identifier-shaped values** → `docs/form-fields.md`
- **The three shared widgets take these as plain parameters** → `docs/form-fields.md`

### Template variable fields

Email-template `$variables` render as chips wherever a template is edited (Templates & Reminders, Send Email), because users read raw tokens as code to replace (invoiceninja/flutter#139). → `docs/template-variables.md`

- **Which variables a template supports is a property of the server engine, not of a list.** → `docs/template-variables.md`
- **A single-line field can't hold chips and be edited as text,** → `docs/template-variables.md`
- **The default template is shown, never silently saved.** → `docs/template-variables.md`
- **Values come from the server, exactly, or not at all.** → `docs/template-variables.md`
- **A rendered `raw_subject` / `raw_body` is the request echoed back, so a default is adopted only from a render that asked for it — and never survives a template switch.** → `docs/template-variables.md`
- **A markdown field reports both edges of "is this dirty", and the false one is what an edit that round-trips needs.** → `docs/template-variables.md`
- **A field action is a labelled `FieldActionButton` outside the field — Insert variable above-right, Reset below-right — never a bare glyph in the suffix.** → `docs/template-variables.md`
- **A `defaultValue` that lands late is adopted only when the document is pristine and no editor is mounted over it.** → `docs/template-variables.md`

### Two-choice fields → radio, not dropdown

A fixed field with two choices (occasionally up to ~4) is a **radio group, not a dropdown** — `OverridableRadioField<T>` on cascade settings (reference: `empty_columns` on Invoice Design → General).

### Date and time fields

Single dates and times go through `InDateField` / `InTimeField` (`lib/ui/core/widgets/`): a typed field taking shortcuts (`today`, `+7`, `5/14`; `9p`, `930`) plus a picker icon, committing on blur or Enter and silently reverting on a parse failure. Typed input parses locale-independently; only display follows the company `Formatter`. Reuse `parseDateInput` / `parseTimeInput` (`lib/utils/formatting.dart`) for the shortcuts without the chrome. → `docs/form-fields.md`

- **The placeholder is a worked example, never a format pattern.** → `docs/form-fields.md`

**Don't use `showDatePicker` / `showTimePicker` for form fields** — only one-tap *range* filters (`DateRangePickerButton`) still do.

## Settings screens

Most new settings panels look like **Company Details** or **Device Settings**, never User Details: `FormSection` cards inside `SettingsFormShell(sections: [...])`. Skeletons and conventions: `docs/settings-screens.md`.

### Decision tree (5-second routing)

Ask: **"Does this field write to the server (`/api/v1/companies/...` or similar)?"**

- Server `company.settings.*` → **Company Details style** + `CascadeSettingsScaffold` + `Overridable*` widgets.
- Server `company.*` (top-level) → **Company Details style** + `SettingsPageScaffold` + plain widgets.
- Local controller only (theme, locale, biometric, …) → **Device Settings style** + `SettingsScreenScaffold`, no VM.
- Never the user-details `ListTile` shape (anti-pattern below).

Building a *custom* shell (e.g. tabbed like Company Details)? Reach for `SettingsCompanyScopedHost` instead of re-rolling the company-switch listener inline.

### Three styles

- **Cascade-aware** (`company.settings.*`): `CascadeSettingsScaffold` + a one-line `SettingsDraftViewModel` subclass + `Overridable*` fields. Reference: `localization_screen.dart`.
- **Company-only** (`company.*`, or mixed): `SettingsCompanyScopedHost<V>` → `SettingsPageScaffold<V>` + plain fields calling `vm.updateCompany(...)`. **Never `CascadeSettingsScaffold` here** — at client scope it swaps to a VM whose `updateCompany` is a no-op, and edits are silently dropped. Reference: `company_details_shell.dart`.
- **Device Settings** (no server, no VM): `SettingsScreenScaffold` + `SettingsFormShell` + typed tiles writing to local controllers. Reference: `device_settings_screen.dart`.

### Width cap: every body under `/settings/...` goes through `SettingsFormShell`

Centred, 720 px max — including tab bodies inside an `EntityEditScreenScaffold` (the gateway-edit tabs). Never a raw top-level `ListView(padding: ...)`. → `docs/settings-screens.md`

### Anti-pattern: User Details ListView+ListTile shape

No raw `ListView` of bare `ListTile`s — even a single toggle or action sits in a `FormSection`; a `ListTile` wrapped in a typed control widget inside one is fine. → `docs/settings-screens.md`

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
10. DI: a `_wireFoo(reg)` in `lib/app/services_entity_wiring.dart` plus one call from `wireEntities()` (document-bearing → `documentMutationHandlers`; bundled → `bundleAppliers`)
11. Branch order in `kBranchOrder` (append-only)
12. Actions + 7 translation keys (entity translation completeness test enforces) — including the mandatory `copyLink` action (`entity_copy_link_coverage_test` enforces)
13. Tests: contract fixture + entity-specific mapper / filter / conflict tests

Full step-by-step shapes, "Standard action helpers" factories, the "Non-standard actions" pattern (e.g. Invoice `markPaid` via `customActions:`), and the bundled-entity alternative live in `docs/adding-an-entity.md`. Clients and Products are the reference invocations to mirror.

### Action confirmations

A risky action sets `confirm: true` on its `EntityActionItem` (+ `confirmSubject:`, `isDestructive:` if it destroys data, `confirmMessageKey:` for sharper copy). The switch is Device Settings → Security → **Confirm actions** (`DevicePrefKeys.confirmActions`, on by default). Tag a verb only if it fires a mutation at once **and** is outward-facing, financial or hard to reverse — never one that opens its own dialog or screen; bulk items stay untagged (`BulkAction.confirm` owns that).

Every surface calls `guardedOnTap(context, item)`, never `item.onTap`; surfaces outside the item model use `showConfirmActionDialog`, which autofocuses **Cancel**. → `docs/adding-an-entity.md`

- **Signing out is the one confirmation the preference cannot switch off, and it goes through `showConfirmSignOutDialog`** → `docs/adding-an-entity.md`

## Sync — non-obvious rules

- Outbox FIFO is **per company, strict global id order** (`OutboxDao.nextReady`); per (company, entity_type) ordering is a future need. → `docs/sync.md`
- Every outbound request sends `Idempotency-Key: <uuid from the outbox row>`, generated once at row creation and never regenerated — **but the server ignores it, so it does not make a retry safe.** What a re-send may do is `MutationKind.deliverySafety`. → `docs/sync.md`
- Logout / company-switch with active (pending / in-flight) outbox rows **prompts** the user (sync now / discard / cancel) — never silently drops user data.
- **A change that may already have reached the server goes `unconfirmed` and is never re-sent on its own** — it waits for Check / Resend / Discard and holds back later changes to its record; a write the server accepted is done, whatever fails after it. → `docs/sync.md`
- **A document upload or a comment holds nothing back — no later save of its record, no `/refresh` of the company — because it writes no field of the record (`writesNoRecordField`, and its SQL twin in `OutboxDao`).** → `docs/sync.md`
- **A failed (`dead`) change is still unsynced work — every destructive session end must count it.** → `docs/sync.md`
- **Local data is destroyed only by its owners** — wipes through `LocalDataDisposer`, outbox deletes through the sync engine (`test/lint/local_data_disposal_test.dart`) — and `logout` takes a required `LocalDataPolicy`. → `docs/sync.md`
- **A server copy of one record goes through `applyEchoTemplate` / `applyCreateResponseTemplate` — never a bare upsert — so it can't overwrite a newer queued edit.** → `docs/sync.md`
- **A discard abandons the *row*, not the *entity*.** → `docs/sync.md`
- Destructive ops (delete, purge, password change) need `X-API-PASSWORD-BASE64`, captured by `ConfirmPasswordSheet` into a 5-min cache; **an OAuth user is never asked when the company leaves `oauth_password_required` off** (`PasswordCache.isExempt`). → `docs/sync.md`
- **412 Precondition Failed = password-required.** → `docs/sync.md`
- 401 forces `AuthRepository.logout()` and a redirect to `/login` — **unless it is a permission denial** (Laravel's message, or `/ping` still answers → `PermissionDeniedException`, which ends nothing → `docs/sync.md` § A permission denial is a 401 too). **Single-flight**: parallel 401s wait on the same logout future. That logout **preserves local data** (`LocalDataPolicy.keep`) — an involuntary 401 is the same user, and wiping the Drift DB (outbox included) over a server-side token change is not a trade worth making; `logout()` still writes the re-lock gate, and `onSessionReset` / `onBeforeLogout` (the cross-user-leak fan-out) run on the preserve path anyway. Only a deliberate sign-out wipes.
- **A rejected *company* token fails the switch, not the session.** → `docs/sync.md`
- **A forced logout logs a WARNING naming the request.** → `docs/sync.md`
- The `x-minimum-client-version` response header is checked on every request; below threshold throws `ClientTooOldException`.
- 422 validation errors carry `Map<String, List<String>> fieldErrors`. Edit forms surface these inline.
- **409 conflicts** are parked far in the future (1 year) instead of auto-retried. `ConflictResolutionSheet` either re-enqueues a fresh mutation or discards.
- **This server does not 404 for a missing entity — it 400s.** → `docs/sync.md`
- **A soft-deleted record can't be edited; an archived one can.** → `docs/sync.md`
- **A rejected save must never be a dead end.** → `docs/sync.md`
- **Server-side list ordering / cursor.** → `docs/sync.md`
- **A narrowed fetch neither reads nor advances the cursor** → `docs/sync.md`
- **`hasMore` is not the gate for widening the Drift window.** → `docs/sync.md`
- **A bulk re-download re-arms mounted lists.** → `docs/sync.md`
- **Lists sort newest-first where the sort key is monotonic.** → `docs/sync.md`
- **Every local search predicate goes through `searchLike` (a contact through `contactSearchMatches`) — SQLite folds case for ASCII only, so a raw `.like()` or `.lower()` hides every capital umlaut the server matched.** → `docs/local-search-matching.md`
- **A `tmp_` id is a *display* problem too, not just a wire problem.** → `docs/sync.md`
- **Offline never dead-letters.** → `docs/sync.md`
- **A page or a mutation is bound to the company whose token fetched it, and the binding is a `throw`.** → `docs/sync.md`
- **A different identity on the same device wipes the local database, and only the login entry points check.** → `docs/sync.md`
- **The server's rounding scale is a two-level map, not one precision.** → `docs/sync.md`
- **`markPaid`'s confirmation is a hook, deliberately NOT `confirm: true`.** It opens its own dialog, and § Action confirmations is explicit that a second prompt in front of one is worse than none.
- **A Sync pass re-downloads the fifteen entity tables and nothing else — every cache that hangs off them is re-seeded by hand.** → `docs/sync.md`
- **A Documents-list row leaves only by a confirmed delete, a record whose complete `documents` no longer lists it, or a full Sync sweep that reached the end — never while dirty or named by an outbox row.** → `docs/documents-list.md`
- **A `/refresh` delta carries the fourteen browsable entity tables too, and they are applied as an upsert-only top-up (the Documents harvest also prunes, above) — never on a full sync, and never over a newer local row.** → `docs/sync.md`
- **Anything that must fetch once a Sync pass is over listens to `ResyncController.lastCompletion` — the idle falling edge also fires for a cancelled pass.** → `docs/sync.md`
- **A pushed server event never writes an entity — it only schedules the `/refresh` delta (`RefreshScheduler.requestSoon`), except a download-ready notice, which is shown, not refreshed — and only `main.dart` opens the socket (`Services.build(realtimeUpdates:)` defaults off).** → `docs/realtime-updates.md`
- **An edit of a record whose create failed saves as a create — `performSave` branches on `savesAsCreate`, never `isCreate`.** → `docs/sync.md`
- **The local `is_dirty` flag is layered onto the domain model in `<Repository>._decode`, which reads its row and nothing else.** → `docs/sync.md`

## Document version history

The five billing documents list their saved versions on a **History** tab, each opening that
version's PDF (invoiceninja/flutter#168). Every rule below is invisible at the call site.

- **A backup exists only for invoice / quote / credit / recurring invoice / purchase order, and it is a rendered HTML document — not a data snapshot, so nothing can diff or restore it.** → `docs/document-version-history.md`
- **`?include=activities.history` is the only include that works; `?include=history` is dropped and `POST /activities/entity` calls `->without('backup')`.** → `docs/document-version-history.md`
- **The `history` object is serialized even when there is no backup, so `history.id` non-empty is the gate — never `history != null`.** → `docs/document-version-history.md`
- **The list is capped at 50 activities with no pagination, free/trialing hosted accounts get no backups at all, and the UI says so rather than implying an empty or complete list.** → `docs/document-version-history.md`
- **`download_entity` is the one call on this API where a 404 is a real data condition, not a bad URL.** → `docs/document-version-history.md`
- **A version label is legal on screen and illegal in a file name, so every name handed to `printing` goes through `sanitizeFileName` (`lib/utils/file_names.dart`) — the native share swallows the write error, so an illegal one is a Share button that does nothing.** → `docs/upstream-workarounds.md`
- **Wide swaps the detail screen's existing PDF pane; only narrow routes to `/:id/pdf?activity_id=` — and that screen must never be re-keyed on the selection.** → `docs/document-version-history.md`
- **`no_history` is unusable (Greek in `fr.json`), and no bundle has a plural `versions` key — so the tab is `tr('history')` with `Icons.layers_outlined`, never the Activity tab's clock.** → `docs/document-version-history.md`

## Data loading — bundled vs per-entity

Before adding a new module, decide how its data is fetched. Two buckets:

- **Bundled with the company on auth.** `/login` and `/refresh` accept `first_load=true`, which makes the server include company-scoped reference data alongside each company: tax rates, groups, designs, payment terms, expense categories, task statuses, subscriptions, schedulers, etc. The static catalog (currencies, countries, languages, industries, gateway types, date formats) is returned under `staticData` (`include_static=true`). `/refresh` already sends both — consume from that response, don't write a separate fetcher.
- **Loaded by their own routes.** High-volume, user-browsable entities: clients, invoices, products, payments, expenses, tasks, projects, quotes, credits, vendors, purchase orders, recurring invoices, etc. Full `BaseEntityApi` + page-by-page + Drift + outbox stack. **Never *load* these from `first_load`** — but the `/refresh` **delta** tops them up, and discarding it is what made a long session show days-old data. → `docs/sync.md`

Rule of thumb: small / mostly-read / company-shared (≲ a few hundred rows) → **bundled** (`docs/adding-an-entity.md` § Bundled entities); something a user scrolls / searches / filters → **own route**. Unsure? Probe `/api/v1/refresh?first_load=true&include_static=true` on the demo API.

**Bundled today**: the auth user record (`data[N].user`, written directly in `_persistAndActivate`), `task_statuses`, `company_gateways`. `applyBundle` is **upsert-only — never deletes** (`is_dirty=true` rows keep their outbox-bound payload until the next real sync); it advances the keyset cursor with `wasFullSync: true` so the screen's first `ensurePageLoaded` short-circuits.

## Sidebar counters

`lib/domain/sidebar_badge_modes.dart` is the single source of truth for what a sidebar badge can count, and every mode is answerable from Drift — **the badge never issues a network call**. It drives the rail badge *and* the list status tabs, so a new or changed mode is four edits:

1. the entity's `SidebarBadgeMode` list (+ its `badgeModes:` in `kWiredEntityModules`),
2. a case in that DAO's `badgeModePredicate` (`sidebar_badge_count_test` fails on a missing one — a null predicate silently counts every row),
3. the mode's `labelKey` (+ `kSidebarBadgeModeSearchKeys` only for a specific word),
4. a `ListStatusTabSpec` in `lib/domain/list_status_tabs.dart` (`list_status_tabs_test` fails if the catalogs disagree).

- **Counts come from the local Drift cache, so on a large account a counter under-reports until the user browses or runs a Sync — making it exact needs a server-side count.** → `docs/entity-lists.md`
- **`Date.today()` is baked into a badge stream's SQL and the stream lives for the whole session, so leaving the app open past midnight keeps the date-sensitive counters on yesterday's date.** → `docs/entity-lists.md`
- `BaseEntityDao.watchBadgeCount` counts **active** rows; the older `watchCount` is archived-inclusive. → `docs/entity-lists.md`

## List columns

`lib/domain/columns/<entity>_columns.dart` is one registry per entity (`kAll…`, `kDefault…`, `…ColumnsById`). The user's selection lives in `user_settings.table_columns` in admin-portal's format, so **renaming a column id silently drops a saved layout** — don't. → `docs/entity-lists.md`

- **Every field the entity's edit screen can set earns a column** → `docs/entity-lists.md`
- **Real Drift column ⇒ `sortable: true` plus a `_sortExpression` case in the DAO. Derived or payload-only ⇒ `sortable: false` plus an entry in `sortable_columns_test`'s `displayOnly` map.** → `docs/entity-lists.md`
- **Custom-field slots go through `customFieldColumns` (`custom_field_columns.dart`), never a hand-written `custom1` column.** → `docs/entity-lists.md`
- **Client and Vendor ids must also join `k<Entity>ColumnIds`** (`column_ids_match_registry_test`); hiding a column is never destructive; label created-by with `user`, never `created_by`. → `docs/entity-lists.md`

## List status tabs

A one-tap status strip above every entity list (invoiceninja/flutter#98) — a **view over the sidebar-counter catalog**, not a second one: `lib/domain/list_status_tabs.dart` adds only the tab order and the optional server translation. → `docs/entity-lists.md`

- **The count and the rows are one predicate** — `list_status_tab_filter_test` asserts `rows == count` for every entity × mode; that test is the feature.
- **The whole state is `extraFilters['badge_mode'] = {modeId}`, and it never reaches the wire.**
- **A server mapping must return a SUPERSET of the local predicate.** → `docs/entity-lists.md`
- **A widened mapping MUST be marked `widened: true`, and that flag is not bookkeeping.** → `docs/entity-lists.md`
- **Don't map a mode whose only superset is nearly the whole table.**
- **A tab whose predicate reads another entity's table has to fetch that table too, or it reads zero.** → `docs/entity-lists.md`
- **No strip on an embedded list; the strip renders whenever a tab is active, even with the device setting off** (`DevicePrefKeys.statusTabs`, default on).
- **Counts are active-only, and a zero renders in the neutral palette.**
- **The strip's edge fades are gated on the scroll position, like `EntityDetailTabs`'.** → `docs/entity-lists.md`
- **The strip has a second, wrapped layout, used only by the dashboard's Invoices & Quotes panel — and selection there is a fill, not the underline.** → `docs/dashboard-panels.md`
- **A status tab and the Status chip are one filter — picking a tab drops the chip, setting the chip moves the strip to All, and a stored slot holding both keeps the tab (`exclusiveStatusFilters`, `kStatusChipServerKeys`, healed by `normalizeSnapshot`).** → `docs/entity-lists.md`
- **Quote `rejected` is a tab but not a chip, and the difference is what reaches the wire.** → `docs/entity-lists.md`

## List state filter

The lifecycle filter (`is:` / `state:` — active / archived / deleted) is a **`Set<EntityState>` that is never empty**: `normalizeListStates` (`lib/domain/entity_state.dart`) runs at all three writers (`setStates`, `_applyDecoded`, `_applyIntentState`) — keep them in step. → `docs/entity-lists.md`

- **The empty set looked like the *absence* of a decision while being the widest possible one — three ordinary gestures reached it and nothing could get back out.** → `docs/entity-lists.md`
- **Normalize on the list VM only — never at the DAO or repository seam.** → `docs/entity-lists.md`
- **A key at its default renders no chip, and that guard must live in `TokenSearchController`, not in `tokensFrom`.** → `docs/entity-lists.md`
- **Two consequences that are the rule rather than bugs: this reverses the old Sentry-style removable-chip choice, and the State picker's Active row goes inert on a default list.** → `docs/entity-lists.md`
- **A snapshot already on disk needs healing at every site that reads one — three that compare, and one that writes.** → `docs/entity-lists.md`

## Tasks layout view

Five layouts (list / daily / weekly / calendar / kanban). **`?view=` on the URL is the override, `DevicePrefKeys.tasksView` the fallback** — `tasksViewModeFromQuery` + `resolveTasksViewMode` in `lib/domain/tasks/tasks_view_mode.dart`, a leaf that imports nothing. → `docs/tasks-views.md`

- **The `view` key is overloaded, so `'full'` must parse to null.** → `docs/tasks-views.md`
- **The fallback is suppressed whenever the screen can only be the plain list** → `docs/tasks-views.md`
- **The toggle emits no `?view=` at all — a view switch is not a history step.** → `docs/tasks-views.md`
- **`_RememberedTasksView` is the second writer, it writes post-frame, and its `ValueListenableBuilder` is unconditional.** → `docs/tasks-views.md`
- **`stripTransientQuery`'s carve-out for a non-`full` `view` must stay** → `docs/tasks-views.md`
- **The kanban board is the one Tasks view with no create FAB, and the gate that makes that safe is not the one it looks like.** → `docs/tasks-views.md`
- **A booked block and a finished session are the same four wire slots, so "start the timer" is a decision, not an append.** → `docs/task-scheduling.md`

## Dashboard panels

Panels are ordered and hidden per user — `DashboardKind.panelKinds` is the registry, `DashboardPanelPref` the stored `"<kind>|<1|0>"` entry — and a kind missing from a saved arrangement goes at its canonical rank, visible (no migration). **The module gate lives only in `enabledPanelKinds`.** → `docs/dashboard-panels.md`

- **The cards, the chart's legend and grouping, and the panel arrangement sync through `company_user.react_settings` — the cards in React's own `dashboard_fields`, never the old app's `company_user.settings` — as a patch laid over the freshest blob, and never before that blob was captured (the server replaces it whole).** → `docs/dashboard-panels.md`
- **The needs-attention band leads both layouts, and its slot is always one list child.** → `docs/dashboard-panels.md`
- **A row's action runs on a re-read record, never on the cached row.** → `docs/dashboard-panels.md`
- **Unknown is not zero (`ValueSectionState`): placeholder, dash + Retry, or the value.** → `docs/dashboard-panels.md`
- **Outstanding is as of today (a `custom` window; `all_time` ends today); trends compare like with like.** → `docs/dashboard-panels.md`
- **The figures refetch when a change leaves the outbox.** → `docs/dashboard-panels.md`
- **Every dashboard list draws `DashboardRecordRow`; `layoutPanelRows` pairs the panels.** → `docs/dashboard-panels.md`
- **Nothing under an `IntrinsicHeight` row may be measured through a `LayoutBuilder`.** → `docs/dashboard-panels.md`
- **The task-calendar panel (flutter#137) is the first Drift-backed one; what holds it up is invisible at the call site.** → `docs/dashboard-panels.md`
- **Per-day load is one rule in one leaf, and it buckets per time ENTRY.** → `docs/dashboard-panels.md`
- **The month window is fetched by the view model, month-aligned.** → `docs/dashboard-panels.md`
- **`hasLoaded` is not enough to claim availability, and the gate is not `Opacity`.** → `docs/dashboard-panels.md`
- **The "today" marker takes `onAccent`, never `accentInk`.** → `docs/dashboard-panels.md`
- **The Invoices & Quotes panel is a *view* over two badge catalogs, and both DAO seams fail OPEN on a mode they don't recognise.** → `docs/dashboard-panels.md`
- **A strip whose items carry counts wraps; one that carries navigation scrolls.** → `docs/dashboard-panels.md`
- **"Most recent" needs a tie-break, and `created_at == 0` means *newest*.** → `docs/dashboard-panels.md`
- **A tabbed card is the one panel whose empty state may be the generic string.** → `docs/dashboard-panels.md`
- **"Hide empty panels" is a device preference (null = on for a phone); a panel is empty only once loaded with no rows, the two Drift-backed ones never are, and the list drops it through `HiddenEmptyPanelsBuilder` — the card never hides itself.** → `docs/dashboard-panels.md`
- **The narrow `+` is a FAB opening a create sheet on the root navigator; the wide bar draws the same creates as buttons; `quickCreateEntities` gates both — create route, module (payments ride the invoices bit), `create_<entity>` (transactions are `bank_transaction`).** → `docs/dashboard-panels.md`

## Detail screens

- **A record screen runs identity, quick actions, standing, comments and an always-shown profile above a pinned tab strip, in that order at every width.** → `docs/detail-screen-layout.md`
- **A quick-action tile is a second render of an existing `EntityActionItem`, never a second definition, and one that does not apply yields its slot.** → `docs/detail-screen-layout.md`
- **A figure the server does not supply is shown only when proven — the past-due line needs a complete fetch *and* a sum equal to the client's balance.** → `docs/detail-screen-layout.md`
- **Tab counts are server totals (`BaseEntityApi.count`); an unknown count draws no badge, never a zero.** → `docs/detail-screen-layout.md`
- **A deleted record is read-only through one banner and `EmbeddedListParentScope`; one that could not be fetched offers Retry, not "not found".** → `docs/detail-screen-layout.md`

## Tap to call

Tapping a phone number opens the dialer (invoiceninja/flutter#109), behind a device-local preference blob (`DevicePrefKeys.phoneActions`). → `docs/tap-to-call.md`

- **The `tapToCall` default is `Env.isTouchPrimary`, not `true`** → `docs/tap-to-call.md`
- **`tel:` / `sms:` deliberately bypass `isSafeWebUrl`.** → `docs/tap-to-call.md`
- **`cleanPhoneNumber` is where a wrong number comes from.** → `docs/tap-to-call.md`
- **Every phone surface listens via `PhoneActionsScope`.** → `docs/tap-to-call.md`
- **The billing-doc header call button is sized on the axis that has room** → `docs/tap-to-call.md`
- **The list-row call button reclaims the touch target on the axis the *row* has** → `docs/tap-to-call.md`
- **A logged call is an activity *note*, and the note is the only storage there is** → `docs/tap-to-call.md`
- **The post-call offer is gated on `Env.isMobile`, not `Env.isTouchPrimary`** → `docs/tap-to-call.md`

## Reports

`/reports` is a gallery; `/reports/:report` runs itself on opening. A report is one `const ReportDefinition` (`report_registry.dart`); rows come from `<endpoint>?output=json` — or, for Task Items, from the device — and the rest — filter, sort, group, total, chart — is local `ReportEngine` work.

- **The date range filters a column the report never names, not always one you can group by.** → `docs/reports.md`
- **A column the server omits can still be asked for ("new clients per month").** → `docs/reports.md`
- **A period with no rows has no bucket; `GroupTotals.count` is a series and bucket keys are identity.** → `docs/reports.md`
- **A non-date grouping splits by period through a composite key only `_rowGroupKeyFn` derives.** → `docs/reports.md`
- **The view model lives above the routes (`ReportsHost`); a run is debounced, superseding, never offline or plan-gated.** → `docs/reports.md`
- **Every report request states `send_email`; the server takes a missing one for true and emails the report.** → `docs/reports.md`
- **A cell's `id` is its field name, so a row links only through `rowIdKey`; totals never cross currencies or a parent's repeated lines.** → `docs/reports.md`
- **A file-only report is read back as a `ReportDocument`: nothing matches a header's text, and an unreadable file is a download.** → `docs/reports.md`
- **A comparison pairs periods by position, never by index; a saved view is a `saved_views` row of type `report`, not an `EntityType`.** → `docs/reports.md`
- **Task Items is built on the device — `/tasks?activity_dates` into Drift, a row per time entry on the day it started, and no server file, email or schedule.** → `docs/reports.md`
- **Credit Items, Recurring Expenses and Transactions are built on the device too — a `RecordReportSource` each: the list route narrowed by `date_range` into Drift, every filter applied on the device, each row's currency named by its `*.currency_id` column.** → `docs/reports.md`
- **The Tasks report merges the server's per-entry rows into one per task (`collapsesToRecord`) — each of them carries the task's whole duration.** → `docs/reports.md`
- **A duration is hours — decimal or `H:MM` as the device's hours-format preference says — never a day count.** → `docs/reports.md`

## Visual invoice designer

The block designer (`invoice_design/wysiwyg/`) is a picture of what the server prints, so its rules are the server's.

- **`blocks` is sent only when there are blocks — the server takes the key's presence, `[]` included, as a block design and ignores the Twig.** → `docs/invoice-designer.md`
- **A row is the blocks sharing an integer `y`; `x` is never a position and `h` is never read — go through `rowsOf` / `blocksFromRows`, never grid arithmetic.** → `docs/invoice-designer.md`
- **Empty space in a row is a gap cell (a zero-height spacer), so a row the user edits always totals 12 columns.** → `docs/invoice-designer.md`
- **A table `header` / info `title` prints verbatim (store `$…_label` tokens, not translation keys), and a block never ships without `properties`.** → `docs/invoice-designer.md`
- **Fields this app does not model ride in `extra` and are written back.** → `docs/invoice-designer.md`
- **Every key the workspace binds is a `GuardedShortcutAction`, and a bare key (arrows, Enter, Delete, Esc) acts only while the workspace's own node has focus — else Backspace on a focused panel control deletes the block.** → `docs/invoice-designer.md`
- **The designer's layout measures its pane (`DesignerPane`), never `MediaQuery` — the sidebar has 232px of the window — and every `showMenu` anchor goes through `menuAnchor`.** → `docs/invoice-designer.md`
- **The page, the panel's example values and the preview are filled from one document (`DesignerDocumentController`, `DesignerRenderScope.sampleOf`).** → `docs/invoice-designer.md`
- **The page is a physical document: it is laid out left-to-right in every locale, and only the designer's chrome mirrors.** → `docs/invoice-designer.md`

## Localization

- Source of truth: **Transifex** (`explore.transifex.com/invoice-ninja/invoice-ninja`).
- Files in the zip are PHP arrays (`textsphp-<locale>.php`).
- `tools/transifex_importer` (`dart run bin/import.dart <zip>`) parses those PHP files for locales in `kSupportedLocales`, drops every value identical to the zip's English (Transifex's copy of an untranslated key) or carrying a `:placeholder` the English lacks (a translator's rename, which renders raw), and writes `assets/i18n/<locale>.json`.
- Workflow per release: download zip → run the importer → commit the changed JSONs.
- Runtime: `Localization` loads the active locale's JSON from `rootBundle`. English is always loaded as a fallback. There is **no** server fetch; the one override is the company's Custom Labels (`CompanyLabelsScope`) → `docs/translated-string-rendering.md`.
- Adding a locale = the four steps on `kSupportedLocales` (`lib/l10n/supported_locales.dart`); `supported_locales_test` checks them. The app ships every language the server's `LanguageSeeder` offers, plus en_AU and zh_CN.
- **Arabic, Persian and Hebrew lay out right-to-left, so new layout code says start / end (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`), never left / right** (`no_physical_direction_test`; Debug Panel → Force right-to-left to look). → `docs/right-to-left-layout.md`
- **The window chrome, the invoice designer's page, a chart's time axis and a menu placed in global coordinates stay physical, marked `// rtl: physical <reason>`.** → `docs/right-to-left-layout.md`
- **The shell flips: the rail sits at the start edge and everything it pins follows, and Back is ⌘/Alt+→ in RTL.** → `docs/right-to-left-layout.md`
- **A value (amount, number, date, document number, email, phone, code) renders through `LtrText` and a value field is LTR; `tr()` and `Formatter` output stay plain text in every locale (they are also data) — isolate at render time, never in `Localization.lookup`.** → `docs/right-to-left-layout.md`
- **Arabic, Hebrew, Thai, Lao and Khmer render from the bundled Noto fonts (`kScriptFallbackFonts`), loaded by `ScriptFonts` (the UI language's before the first frame) — never declared under pubspec `fonts:`.** → `docs/right-to-left-layout.md`
- **The upstream PHP is HTML-escaped — the importer decodes entities (`decodeHtmlEntities`: a single pass, and the app's one entity decoder), don't bypass it.** → `docs/translated-string-rendering.md`
- **App-local strings are translated per locale in `_app_pending_<locale>.json`, laid over the locale's bundle wherever it has no real translation (blank, or Transifex's English copy) — so an entry outlives its `_app_pending.json` line and goes only when a real translation lands.** → `docs/translated-string-rendering.md`
- **`_app_pending.json` can only *add* a key, never override one — an entry whose key has a non-blank `en.json` value is dead, so a deliberate rewording takes a distinct name (`*_label` / `*_short` / `*_detailed`).** → `docs/translated-string-rendering.md`
- **A placeholder name that prefixes another needs no care — `Localization.lookup` substitutes longest-first.** → `docs/translated-string-rendering.md`
- **Never render a string carrying a `:placeholder` without filling it — pass the params; else point at a placeholder-free Transifex sibling; only last add a distinctly-named app-local key, and never blank the token and `.trim()`.** → `docs/translated-string-rendering.md`

## Rich text editing

`lib/ui/core/widgets/markdown_text_field.dart` (`super_editor`, pinned by SHA) is the shared WYSIWYG editor for every markdown-bearing field. → `docs/rich-text-editing.md`

- **One-way data flow:** the parent owns the stored string (`initialValue` + `externalValueKey`); the widget emits HTML via `onChanged`. → `docs/rich-text-editing.md`
- **A value the document cannot hold — a table, or text the fold would delete — is shown as its own HTML source, verbatim.** → `docs/rich-text-editing.md`
- **Server content is safe by construction** — no HTML/JS execution context. → `docs/rich-text-editing.md`
- **These fields are HTML on the wire, so the editor emits HTML — and that HTML must carry no newline characters.** → `docs/rich-text-editing.md`
- **A read-only render of a notes field goes through `plainTextFromHtml`, and so does every "is it empty" gate in front of one.** → `docs/rich-text-editing.md`
- **A field with no editor converts at its seams: seeded from a stored value ⇒ `htmlFromEditableValue`; always typed ⇒ `htmlFromPlainText`.** → `docs/rich-text-editing.md`
- **A report's string cells are flattened at the parse, not at the widget — five surfaces read the same string.** → `docs/rich-text-editing.md`
- **Inbound HTML is folded to markdown by `markdownFromLegacyHtml` (`lib/utils/legacy_html_markdown.dart`) — never handed to the deserializer raw, and never with a hand-rolled `replaceAll`.** → `docs/rich-text-editing.md`
- **A break the author typed accumulates, a break that two block tags both ask for merges, and inside a list both clamp to one.** → `docs/rich-text-editing.md`
- **A marker construct that closes with no text in it must release the break hold, or it swallows the rest of the document.** → `docs/rich-text-editing.md`
- **A read-only editor blocks pointers at the *sliver*, never around the scroll host.** → `docs/rich-text-editing.md`
- **The editor's own scroll host is `primary: false`, or the form around it cannot be dragged.** → `docs/rich-text-editing.md`
- **The editor reveals its caret in the enclosing form itself (`_revealCaret`) — super_editor scrolls only the field's own scroll view, so a field low in a form opened the keyboard over itself.** → `docs/rich-text-editing.md`
- **The mobile caret is themed through `Theme.of(context).primaryColor`, and the `DefaultCaretOverlayBuilder` sitting right next to it is desktop-only.** → `docs/rich-text-editing.md`
- **`height` is a floor, not a size** — the field grows to `maxHeight`, then scrolls; `expand: true` opts out. → `docs/rich-text-editing.md`
- **Template variables are inline placeholders the markdown never sees.** → `docs/template-variables.md`
- **Every markdown field guards `$variables` from linkify.** → `docs/template-variables.md`
- **No new editor instances** — reuse `MarkdownTextField`, never `TextField` + markdown post-processing. → `docs/rich-text-editing.md`

## Widget previews

The four design-system widgets (`EmptyState`, `ErrorView`, `StatusPill`, `LinkText`) carry `@Preview` annotations through `appPreviewTheme()` (`widget_preview_support.dart`); run `flutter widget-preview start`. Add previews to design-system widgets only — feature screens need `Services`.

## Integration tests

- **CI runs only `app_smoke_test.dart`, on headless Chrome, and it blocks — never re-add `continue-on-error`; the macOS suite (incl. `demo/*`) is local-only, via `tools/run_integration_local.sh` (no Metal on hosted runners).** → `docs/integration-tests.md`

## Diagnostics log

Debug-only capture of uncaught errors and every `WARNING`+ `Logger` record to `getApplicationSupportDirectory()/claude-diagnostics.log` (off in release and on web), surfaced in Settings → Advanced → System Logs. When the user says *"read the diagnostics log"*, take the path from System Logs or the boot log line. → `docs/diagnostics.md`

## Deep links

A record's actions menu offers **Share Link** (touch) / **Copy Link** (elsewhere): a link that opens the app on that record, switching company first (invoiceninja/flutter#96). The same `app_links` subscription carries the calendar OAuth return.

```
https://<instance>/app/<in-app route>?company=<companyId>   <- what ships
https://invoicing.co/app/clients/Wpmbk5ezJn?company=Xrtq1oa8Aq
invoiceninja://app/clients/Wpmbk5ezJn?company=Xrtq1oa8Aq     <- fallback, still parsed
```

- **The link is https because a custom scheme is not a link.** → `docs/deep-links.md`
- **Only `kHostedAppLinkHost` can ever be OS-verified, and the `/app/` prefix is what keeps that claim narrow.** → `docs/deep-links.md`
- **Flutter's own deep linking must stay off, and turning it off costs iOS its cold start unless the shim stays too.** → `docs/deep-links.md`
- **A link that names another instance is refused, not followed.** → `docs/deep-links.md`
- **The whole route lives in the URI path, behind a constant `app` host.** → `docs/deep-links.md`
- **Four pieces, deliberately split — `entity_links.dart` (a leaf), `deep_link_router.dart` (arrival choreography), `app_deep_links.dart` (the platform bridge), and `switch_company_guarded.dart`.** → `docs/deep-links.md`
- **Five things fail silently if you change this: double cold-start delivery, the dropped query string, the auth + biometric gate, the guarded company switch, and validating a path before `go()`.** → `docs/deep-links.md`
- **Every detail screen passes `hydrate:` to `EntityDetailScaffold`, and `emptyAction:` gives a genuinely missing record a way onward — landing on an unopened record is the normal case.** → `docs/deep-links.md`
- **Two registry notes: a settings-hosted entity must still declare `detailBuilder`, and a settings `:id` route needs its own id-keyed subtree.** → `docs/deep-links.md`
- **On web nothing delivers the link — it *is* the page URL, so `?company=` is honoured once at boot and stripped before it can persist.** → `docs/deep-links.md`
- **On Android a share or a link reaches MainActivity only through an engine-free trampoline carrying a one-time token, and MainActivity strips every extra before Flutter reads one.** → `docs/deep-links.md`
- **A shared file reaches Flutter only as a native copy in `shared_intake/`, and only `SharedIntakeFiles` deletes one.** → `docs/sharing-files-into-the-app.md`

**Adding an entity?** `test/lint/entity_copy_link_coverage_test.dart` fails the
build unless its action enum declares `copyLink` — nothing in the type system
would otherwise notice a new entity shipping with no way to link to it.

## Desktop window state

Each desktop runner persists window size, position, and fullscreen across launches via the host OS's native preference store — one short native function per platform, no Dart/Flutter package. **N/A on web** (the browser owns the window chrome). The shared three-step contract and per-platform implementations (macOS + Windows done; Linux when added) are in `docs/desktop-window-state.md`.

## Web

Web is a supported target; native behavior stays **byte-identical** — every difference is a `kIsWeb` branch or a conditional-import seam (default file = web, `if (dart.library.io)` = native). → `docs/web-platform-differences.md`

- **Web storage is unencrypted drift WASM over IndexedDB/OPFS, and the token lives in `localStorage` — a locked decision; don't add an encryption layer without re-deciding.**
- **A web database reset must be verified, and a store the browser won't delete is abandoned (generation-bumped), never reopened.** → `docs/architecture.md`
- **Regenerate the vendored `web/sqlite3.wasm` and `web/drift_worker.js` on any `drift` / `sqlite3` bump** — version skew is the #1 web runtime failure.
- **The URL strategy stays hash (`/#/clients`)** — locked, so any static host works; never `PathUrlStrategy`.
- **`dart:io` compiles on web; guard the call with `kIsWeb`**, and prefer `defaultTargetPlatform` + `kIsWeb` over `Platform.isX`.
- **Web does not send `Idempotency-Key`** (the CORS allow-list omits it): `ApiClient(sendIdempotencyKey:)` defaults to `!kIsWeb`.
- The pre-authenticated GitHub Pages demo is `tools/build_demo_web.sh` (a `--wasm` build with a baked demo token); CI builds web with `--wasm`.

## Release Notes

When the user asks for "release notes" (or "releasenotes"), follow `docs/release-notes.md`: notes for the **next** (patch-bumped) version, printed in chat **and** written to `release-notes-vX.Y.Z.md` in the repo root. Never tag, release or bump version files unless asked separately.

- **The release notes the app shows are bundled in `kReleaseNotes`, a bullet naming another platform or store is hidden on the App Store builds, and the dialog never links out.** → `docs/whats-new-dialog.md`
- **The bump script refuses a version with no kReleaseNotes entry, so the notes are written before the bump.** → `docs/whats-new-dialog.md`
- **Release notes never use an em dash (—) in any copy: GitHub, the root file, `kReleaseNotes`, the F-Droid changelog. A hyphen is fine.** → `docs/release-notes.md`

## Reference points

Four read-only sources to mirror, never copy from:

- **`/Users/hillel/Code/admin-portal`** — the previous Flutter (Redux) app; file pointers in `docs/probing-the-demo-api.md`.
- **`/Users/hillel/Code/react`** — the React web client. A second reference for entity shapes, request flows, and UI behaviors when admin-portal is unclear or out of date.
- **API reference** — <https://invoiceninja.github.io/docs/api-reference/invoice-ninja-api-reference>.
- **`/Users/hillel/Code/invoiceninja`** — the live Laravel API server source (official `invoiceninja/invoiceninja`, `v5-develop`, kept current) and the authoritative answer to any API-contract question: params, `include=` sets, transformers (`app/Transformers/`), validation (`app/Http/Requests/`), filters (`app/Filters/`). Read the PHP; never copy it. (`…/invoiceninja-fork` is a PR fork that can lag — never read it for the current contract.)

Live-server probes go through `demo.invoiceninja.com`'s canned read credentials — see `docs/probing-the-demo-api.md` for the curl recipe and the 412 password-gate heads-up.

## Settings search catalog

`lib/ui/features/settings/settings_search_catalog.dart` holds the sidebar (`kSettingsSections`) and the search (`kSettingsSearchCatalog`: a `SettingsSearchTab` per tab, spreading that screen's `kFooSearchKeys`). Change a field under `views/**` → change its constant; `search_catalog_consistency_test` + `settings_search_route_test` hold both ends. Conventions: `docs/settings-screens.md`.

- **A search hit reveals its field by label, not by anchor, so a catalog key must be the label the page renders.** → `docs/settings-screens.md`
