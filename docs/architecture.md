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

### Deep links

Two sources feed one entry point, `Services.deepLinks.open(Uri)`
(`lib/app/deep_link_router.dart`): the OS, via `AppDeepLinks`
(`app_links`, native only), and the user, by pasting a link into the command
palette — which is the only path on web and Linux, where the OS never hands the
app a custom-scheme URI.

The OS hands over two shapes now: the `invoiceninja://` scheme it always did,
and — on the one host the manifest and entitlements can claim — the `https`
links Copy/Share actually emits (invoiceninja/flutter#144). Both reach the same
entry point.

`open` validates the URI against the entity registry, refuses one that names a
different instance, holds it if the app is signed out or biometric-locked,
switches company through the same guarded helper the company picker uses, and
only then `go()`s to the record. The link
grammar, the reasons behind the constant `app` host, and the five silent
failure modes are in `docs/deep-links.md` (CLAUDE.md § Deep links has the rules); the parse/build helpers are a leaf
(`lib/app/entity_links.dart`) so they unit-test without a widget tree.

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

## Strict-rule evidence

Two of CLAUDE.md § Strict rules' bullets are investigations rather than rules. The rule stays there; the history is here. Both concern structure this doc already owns — the import graph, and § Navigation above.

## Why `lib/data/**` must not reach `lib/ui/**`

**`lib/data/**` must not reach `lib/ui/**` — not even transitively.** Enforced by `test/lint/layering_test.dart`. This was a real regression, not a hypothetical: six imports of `lib/domain/columns/<entity>_columns.dart` (for `static const String` id constants, in files that also build Widgets and import `app/router.dart`) put **917 of 1,602 files — 57% of `lib/`, every DAO and `app_database.dart` included — into one strongly-connected import cycle**. Opening `client_repository.dart` compiled 1,395 files, 929 of them UI, so every data-layer test built the whole app. The column id constants now live in `lib/domain/columns/ids/<entity>_column_ids.dart`, which **imports nothing**; each `<entity>_columns.dart` re-exports its leaf so UI call sites are unchanged, and `bank_transaction_dao.dart` re-exports it for the same reason. A DAO that needs to validate a sort field uses the leaf's `k<Entity>ColumnIds` set, never the Widget-bearing `<entity>ColumnsById` map; `test/domain/columns/column_ids_match_registry_test.dart` keeps the two in lockstep (the drift is silent otherwise — a new column renders fine but sorting by it degrades to name-order in release). The failure mode this rule exists for analyzes clean, builds clean, and passes every other test.

## Why Android system back needs three things to keep working

**Android system back == the sidebar `←` (history back), and three things keep it working.** The app only ever calls `go()`, so no navigator can pop and Android used to kill the Activity from every entity detail screen (flutter#39). `SystemBackGate` (`lib/ui/features/shell/widgets/system_back_gate.dart`) binds the platform back event to `NavHistoryController` from the `StatefulShellRoute` page, so dialogs / sheets / pushed modals / the drawer / `/settings/**` / `/x/:id/edit` all still consume back first. Don't break: (1) **any** `ShellRoute` layout that renders something other than its `child` must still keep that child mounted — wrap it in `HiddenShellNavigator` (`MasterDetailLayout` on a bare list URL, `SettingsShell` on the wide `/settings` index) — because go_router dereferences every shell's `navigatorKey` with a bang while walking for a pop target, and an unmounted one throws; never mute its `TickerMode`, or the route the user just closed never finishes its pop and is never disposed; (2) the gate's `NavigationNotification` listener must stay — `WidgetsApp` applies the *last* notification it sees and an inner navigator swapping a page announces `canHandlePop: false`, so without the upgrade the fix works exactly once per screen; (3) a new "close / back" affordance must `go()` to the current location's **URL-parent** (or call `navHistory.back()`), because `isUpNavigation` is what makes the controller *replace* rather than append — otherwise back walks straight into the screen the user just closed. The pane's leading `←` stays structural *up* (`entityCloseTargetPath`); Back and Up are deliberately different. Full rationale: `docs/architecture.md` § Navigation.

## Why boot must always reach `runApp()`

Nothing renders until `runApp()` is called, and on web the consequence is total:
`web/index.html` removes its boot spinner on the engine's `flutter-first-frame`
event, so a `main()` that throws or stalls before `runApp()` leaves the user on
that spinner forever. After 30s the HTML safety-net swaps in "This is taking
longer than expected." with a Reload button — which cannot help, because a
deterministic boot failure reproduces on every load.

That shipped in the 2026-09-22 web demo. Returning visitors wedged while a fresh
incognito window loaded fine; the network tab showed a *fully successful*
authenticated session (`refresh?first_load=true`, then every entity page) with no
frame ever painted. Those reconcile because an unhandled error in `main()`'s async
body does not kill the isolate: fire-and-forget work already scheduled by
`AuthRepository.restore()` (the background refresh at `auth_repository.dart:1462`
and the `onActiveCompanyChanged` prefetch fan-out) runs to completion while
`runApp()` is never reached.

Two independent defects produced it, and both are now closed:

**1. Unbounded, uncaught awaits in front of `runApp()`.** The *network* steps were
carefully bounded (demo `loginWithToken` 15s, `statics.ensureLoaded()` 10s, both in
`try`/`catch`) but the *database* steps were not:

- `openAppDatabase()` recovers from a bad store by destroying and reopening it, but
  `resetAndReopen()` can itself throw — on web a second `WasmDatabase.open` timing
  out against a store still locked by a stale browser context. `main()` caught only
  `KeyringUnavailableException`, so that `TimeoutException` escaped and `runApp()`
  never ran. There is now a catch-all that renders `LocalDataUnavailableApp`.
- `Future.wait([...16 restore() calls])` — all sixteen read the same single
  `nav_state` row over one connection, so a wedged store stalls the lot. Now
  `.timeout(_kRestoreBudget)` + `catch`; every controller has a working default, so
  a failure costs the launch's *preferences*, never the app. (Since v12 the
  preferences are one `devicePrefs.load()` — `docs/device-preferences.md`.)
- `navStateDao.current()` — the last await before `runApp()`, so a stall there is
  indistinguishable from a hung app. Now `.timeout(_kNavStateBudget)` + `catch`,
  falling back to the default route.

The budgets are deliberately generous: they must only ever fire on a genuinely
wedged store, never on a cold, slow disk.

**2. On web the failure was invisible.** Three sinks were all silent at once, which
is why this took a reproduction attempt rather than a glance at the console:

- `_zoneOnError` wrote only to `_diagnosticsLogRef` (always null on web —
  `diagnostics_log.dart` is disabled there) and `_debugCaptureStoreRef` (null until
  `Services` is built, i.e. null for most of the window that matters), and
  `runZonedGuarded` suppresses Dart's own console print. It now `debugPrint`s first,
  unconditionally.
- `initLogging()` routes every record to `dart:developer`'s `log`, which is a no-op
  on the web compile targets — so even `_log.severe('Drift open failed…')` was
  invisible. It now mirrors to `debugPrint` under `kIsWeb`.
- The `mark()` cold-start instrumentation was `kDebugMode`-only. It now also runs in
  release **on web**, because the last stage printed is the only thing that names the
  await that never returned on the one platform you cannot attach a debugger to.

The rule that falls out: **treat `runApp()` as unconditional.** Anything between
`WidgetsFlutterBinding.ensureInitialized()` and `runApp()` either has a timeout and a
`catch` that degrades to a working default, or it renders an actionable screen — the
`_SecureStorageUnavailableApp` / `LocalDataUnavailableApp` pattern. A boot path that
can only either succeed or hang is a bug even when it always succeeds in testing.


## Why the web database reset needs a store it can abandon

A reset must leave the caller with a database it can actually write to. On
native that is easy: `database_opener_io.dart` renames the file to
`<name>.broken.<ts>` and the next open creates a new one. On web the equivalent
was "delete the IndexedDB store", and **the browser is allowed to refuse**.

`IndexedDB.deleteDatabase` blocks for as long as any connection is open. Drift's
shared worker holds one, and it releases asynchronously — several message-port
hops and a work-queue drain after the page's own `close()` future has already
resolved, with no signal back to the page. So a store this page has already
opened generally cannot be deleted *in* this page. Worse, drift 2.33's
`CompleteIdbRequest.complete` (`src/web/wasm_setup/shared.dart`) reads
`IDBRequest.error` inside its `blocked` listener while the request is still
pending; that getter throws, the exception escapes the listener, and the
completer is **never completed** — so the delete does not fail, it hangs.

That is what shipped on 2026-09-22. The 4s bound turned the hang into a
`TimeoutException`, `destroyDatabaseStore()` swallowed it as "best-effort", and
`resetAndReopen()` reopened the *same* store and returned `wasReset: true`. The
app then ran on a schema-drifted database: every read of `nav_state` threw
`Null check operator used on a null value` (drift's generated mapper does
`data['confirm_actions']!` on a column that isn't there) and every write to
`tasks` / `projects` threw `no column named tag_names`. Only the screens that
touch neither — Dashboard, Reports, Activity — appeared to work, and no reload
could ever fix it because each one repeated the same failed delete.

Three rules came out of it:

**1. A reset reports what it achieved, not what it attempted.**
`destroyDatabaseStore()` returns `bool`, and `resetAndReopen()` re-runs
`isSchemaIntact()` on the reopened database. If the store was not cleared, or
the reopened one is still drifted, it throws `DatabaseResetFailedException`
instead of returning `wasReset: true`. `main` renders `LocalDataUnavailableApp`
for it. An error screen the user can act on beats a silently unusable app.

**2. A store that cannot be deleted is abandoned instead.** The live store name
carries a *generation* in `localStorage` (`invoiceninja`, then
`invoiceninja_g1`, …). When the delete is refused, the generation is bumped and
the old name recorded as an orphan, so the next open gets an empty store without
needing IndexedDB's cooperation. This is the web mirror of `.broken.<ts>`, and
it is why the user is never stuck.

**3. Orphans are swept at the one moment deletion works** — once per page load,
at the top of `openDatabaseExecutor()`, *before* anything has opened a store.
A store abandoned on an earlier load has no live handle, so deleting it there
succeeds. The sweep is gated on the orphan list being non-empty, so a normal
boot spawns nothing and pays nothing.

The delete itself goes through `IndexedDbFileSystem.deleteDatabase`
(`package:sqlite3/wasm.dart`), not drift's `probe.deleteDatabase`: the probe
re-attaches to the same shared worker (so it can re-block the delete it is about
to attempt), leaks a `SharedWorker` and a `Worker` on every call, and reaches the
never-completing code path above. The sqlite3 helper carries its own 1s bound.
Deletion is then **verified** against `IndexedDbFileSystem.databases()` rather
than trusted.

## Why the billing documents share one edit layout

Invoice, quote, credit, purchase order and recurring invoice had five edit layouts of 1,200–1,450 lines each, 76–92% identical, and five edit view models 89% identical — and fixes kept reaching four of the five: the credit rendered custom fields 1 and 3 twice, the recurring invoice lacked the notes-field focus guard, the purchase order showed two number fields on a phone and dropped a line-item edit typed just before Save on a tablet. Nothing built any of the layouts in a test.

- **The model:** the five freezed classes implement `BillingDocFields` (`lib/data/models/domain/billing/billing_doc_fields.dart` — the 51 fields they share, same name and type) and `BillingDocPartialFields` (all but the purchase order). Getters only: freezed classes share no `copyWith`, so each view model supplies a `BillingDocWriter` of one-line closures. `BillingDocTotals.totalsInput` replaced eight hand-written `BillingTotalsInput` mappings.
- **The view model:** `BillingDocEditViewModel<T extends BillingDocFields>` holds the bridges, every shared setter and `performSave`; a subclass supplies its repository calls (`createDocument` / `saveDocument`), `validate`, the balance rule in `copyWithStampedTotals` (invoice and credit subtract `paidToDate`) and its own extra fields. `BillingDocPartialSetters` is mixed in by invoice, quote and credit — the recurring invoice's model has the fields, its form does not.
- **The layout:** `BillingDocEditLayout` (`lib/ui/features/billing_shared/edit/billing_doc_edit_layout.dart`) is the one body; each `*_edit_layout.dart` is a wrapper passing its `BillingDocType` and `BillingDocEditSlots` — the PDF fetcher, the E-Invoice tab, the invoice's auto-bill toggle and delivery note, the recurring invoice's schedule and auto-bill mode. Every other difference is a value on `BillingDocType`: the party (client / vendor), the labels, the partial field's placement, create-task-from-line-item, save-as-default keys, hero tags.
- **Accidental differences were kept, not unified:** the partial field sits in three places on a phone (`BillingDocPartialPlacement`), and the recurring invoice's desktop number label says "Invoice Number" while its narrow one says "Recurring Number". Unifying them is a product decision; `billing_doc_type_test.dart` pins every value so a change is deliberate.

`billing_doc_edit_layout_characterization_test.dart` (every tab's fields at 390 / 900 / 1440 px, the e-invoice variants, hero tags and the drift invariants) was written against the five copies and passed unchanged against the shared layout; `billing_doc_edit_vm_setters_test.dart` does the same for the setters. `billing_edit_tab_strip_wiring_test`, `billing_items_affordance_test` and `frozen_party_field_wiring_test` assert the shared wiring once, and that no wrapper grows a copy of it back.
