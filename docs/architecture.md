# Architecture

Companion to CLAUDE.md § Architecture — at a glance. The MVVM block diagram and the layered-split summary live there; this doc carries the DI / routing / persistence / HTTP detail, the offline-first write pipeline, and the on-disk project layout.

## Layer details

- **DI**: `Services` (`lib/app/services.dart`) is a plain bag of singletons built once in `main.dart` and exposed to the widget tree via `Provider<Services>.value`. Screens grab dependencies with `context.read<Services>()`; ViewModels take their repos by constructor injection.
- **Routing**: `go_router` with a `StatefulShellRoute.indexedStack` for the authenticated shell (NavigationRail on ≥600 px, NavigationBar on <600 px).
- **State**: `ChangeNotifier` + `ListenableBuilder` in views. **No Redux. No flutter_bloc. No Riverpod.** If you're tempted to add one, talk to the team first.
- **Models**: `freezed` + `json_serializable`. API DTOs in `lib/data/models/api/`, clean domain models in `lib/data/models/domain/`. Domain models are what flow up to ViewModels.
- **Persistence**: Drift. On **native** (iOS/macOS): on top of SQLCipher (`sqlite3mc`); the DB file is encrypted at rest with a per-install 256-bit key held in `flutter_secure_storage` under `invoiceninja.db.key.v1`. On **web**: drift `WasmDatabase` over IndexedDB/OPFS, unencrypted (no SQLCipher, no PRAGMA key — the browser origin sandbox is the trust boundary). The platform split is behind `lib/data/db/database_opener.dart` (conditional import); `openAppDatabase()` — the `SELECT 1` probe, `isSchemaIntact` check, catch→reset flow — is identical on every target. Drift's reactive streams drive the UI — the network layer only writes; the UI only reads from Drift. Tests use `NativeDatabase.memory()` (unencrypted, no PRAGMA key) — SQLCipher's binary accepts both. See CLAUDE.md § Web.
- **HTTP**: `package:http`. Large list parses go through `compute()`.

### Navigation

**Page navigation is declarative.** Use `go_router` and the typed entity
helpers in `lib/app/router.dart` — `goEntityRecord`, `goEntityFullDetail`,
`goEntityEdit`, `goEntity`. Anything that is a routable destination (a list,
detail, edit, or settings page the user can deep-link to or land on after a
restart) belongs in the route tree, never an imperative `Navigator.push`.

**Raw `Navigator.push` is reserved for modal full-screen sub-flows** that are
not routable destinations — image crop, the design editor, full-screen
previews, pickers, the license page. These must go through a named top-level
`show*Screen` / `show*` helper colocated with the destination screen (e.g.
`showLogoCropScreen`, `showDesignEditScreen`, `showTemplatePreviewScreen`,
`showCascadeFullScreenPreview`, `showAppLicensePage`). **Never write an inline
`MaterialPageRoute(...)` at the call-site** — the helper keeps the route
construction in one place and makes the "this is a deliberate modal, not a
missing route" intent explicit.

Scope note: this rule covers `Navigator.push`. `Navigator.pop` and
`Navigator.of(context, rootNavigator: true)` (drawer dismissal, root-scoped
dialogs) are out of scope and may stay inline.

**Back is *history* back, and the platform back event is bound to it.** Because
everything is `go()`, go_router holds no back stack — `NavHistoryController`
(`lib/app/nav_history_controller.dart`) is the app's back model, and
`SystemBackGate` (`lib/ui/features/shell/widgets/system_back_gate.dart`) wires
Android's back gesture to it alongside the sidebar arrows, `Cmd/Alt+←/→`, and
the mouse thumb buttons. The gate sits on the `StatefulShellRoute` page — the
root navigator's route — so go_router's innermost-first walk lets dialogs,
bottom sheets, pushed modal sub-flows, an open drawer, `/settings/**` and
`/x/:id/edit` consume back first; it only runs when nothing else did. The pane's
leading `←` keeps performing structural *up* (`entityCloseTargetPath`); the two
are Android's Back / Up pair and must not be conflated.

Three invariants hold that together, each of which fails silently:

1. **A `ShellRoute`'s Navigator must stay mounted**, even where the layout
   renders something else instead — the bare list URL in `MasterDetailLayout`,
   the wide `/settings` index in `SettingsShell`. Both wrap it in
   `HiddenShellNavigator`, which also documents why muting its `TickerMode` is
   not an option (the route the user just closed would never finish its pop, so
   it would never be disposed). go_router resolves every shell's `navigatorKey`
   with a bang while looking for something to pop, so an unmounted one throws
   instead — which is why back could not dismiss a filter sheet or the drawer
   from a list screen.
2. **`SystemBackGate`'s `NavigationNotification` listener must stay.** Flutter
   applies whichever notification reaches `WidgetsApp` last, and an inner
   navigator swapping its single page announces `canHandlePop: false`; without
   the upgrade Android goes back to killing the Activity after one navigation.
3. **A new "close / back" affordance must navigate to the current location's
   URL-parent** (or call `navHistory.back()`). `NavHistoryController` treats an
   up-navigation as a replace, which is what keeps the pane `←` from leaving the
   screen the user just closed one step *forward* of the cursor. It records
   locations through `stripTransientQuery`, so a display-mode rewrite
   (`?view=full`) is not a new place; leaving a `/x/new` create form replaces
   its entry too, since a blank form is never a back destination.

## Offline-first write pipeline

Every write goes through this pipeline:

1. Repository writes the change to Drift (`is_dirty = true`). UI updates instantly via stream.
2. Repository appends a row to the `outbox` table with an `idempotency_key`, `payload`, `mutation_kind`, and (if needed) `requires_password`.
3. `SyncRepository` drains the outbox in FIFO order **per (company, entity_type)**. Retries follow exponential backoff (5s → 30s → 2m → 10m, dead after 5 attempts).
4. On success, the row is removed; the server response upserts into Drift.
5. On `422`: row marked `dead` — shown on the Outbox screen for user action.
6. On `409` or stale-data: emits `Conflict` → `ConflictResolutionSheet` modal.
7. On `412 password-required` (or the legacy `403` sniff): emits `PasswordRequired` → `ConfirmPasswordSheet`, **once per row**. The row then follows the same backoff as any 4xx and dies into the Outbox screen, so a cancelled or wrong password can't re-prompt forever; entering a password later resurrects the dead row (`OutboxDao.readyPasswordRows`).

**Offline create uses temp IDs** (`tmp_<uuid>`). When the server assigns a real ID, an `id_remap` row is written and any pending outbox payloads referencing the temp ID are rewritten before send. `Repository.watch(id)` resolves through `id_remap` so an open detail screen survives the swap without a URL change.

## Project layout

```
lib/
├── main.dart, app/            # bootstrap, DI, router, theme, logging, version, env
├── data/db/                   # Drift database + DAOs + tables/
├── data/services/             # api_client.dart + per-entity *_api.dart
├── data/repositories/         # one per entity + auth + sync + settings + statics + drafts
├── data/models/api/, domain/  # freezed models
├── domain/                    # entity_type.dart, entity_registry.dart, sync/
├── ui/core/widgets/           # AppScaffold, TwoPaneLayout, EmptyState, ErrorView,
│                              # OfflineBanner, ConfirmPasswordSheet, SyncStatusBadge
├── ui/features/<feature>/     # auth, shell, clients, settings, sync
└── l10n/                      # localization.dart + supported_locales.dart
assets/i18n/                   # bundled translation JSONs (one per supported locale)
tools/import_transifex_zip.dart
```

## Coding conventions — style

- Models are immutable (`freezed`). Use `copyWith` for edits.
- Repositories return **streams** for "watch" methods and **futures** for "ensure"/mutation methods. ViewModels expose `ValueListenable`-style state.
- Views are `StatelessWidget` whenever possible. Side effects go in the ViewModel.
- Avoid `setState` inside ViewModel-backed features.
- Run `dart run build_runner watch --delete-conflicting-outputs` during development.
- Format with `dart format .`; analyze with `flutter analyze`.
