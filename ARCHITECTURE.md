# Architecture

> **Audience:** new developers joining the Invoice Ninja Flutter v2 admin app.
> Read this top-to-bottom before opening the code. Companion docs:
> - [`CLAUDE.md`](CLAUDE.md) — strict rules and invariants (read second)
> - [`docs/architecture.md`](docs/architecture.md) — layer-level technical reference
> - [`docs/adding-an-entity.md`](docs/adding-an-entity.md) — the 13-step recipe for a new CRUD entity
> - [`docs/settings-screens.md`](docs/settings-screens.md) — recipes for new settings panels

## The 30-second version

- **Layered MVVM.** View → ViewModel → Repository → { Drift, Outbox, id_remap } → HTTP service.
- **No Redux, no bloc, no Riverpod.** `ChangeNotifier` + `ListenableBuilder`. That's it.
- **Drift is the local source of truth.** The UI watches Drift streams. The network only writes *into* Drift; it never feeds the UI directly.
- **Every write goes through an outbox.** Repositories enqueue a mutation row; a drain loop POSTs it later. This is how the app keeps working offline.
- **Multi-company.** Every list is scoped by `company_id`; every DAO mixes in `CompanyScopedDao` (a lint enforces this).
- **Encrypted at rest.** Drift sits on SQLCipher with a per-install key in `flutter_secure_storage`.

If you want one sentence: *the app stays usable offline because every change lands in Drift first and is reconciled with the server later through a strictly-ordered outbox.*

---

## 1. Top-level layout

```
lib/
├── main.dart                    boot sequence (DI, restore, runApp)
├── app/                         DI bag, router, theme, logging, env
├── data/
│   ├── models/                  freezed domain + API DTOs
│   ├── services/                HTTP clients (one per entity + shared ApiClient)
│   ├── repositories/            single source of truth per entity
│   └── db/                      Drift database + DAOs + tables
├── domain/                      entity types, registry, sync dispatchers
├── ui/
│   ├── core/                    generic list/detail/edit scaffolds, shared widgets
│   └── features/                feature folders (auth, clients, products, …)
├── l10n/                        Localization delegate, supported locales
└── utils/                       Formatter, parsing helpers, etc.
```

Every entity gets the same shape under `data/` and `ui/features/`. When in doubt, mirror Client.

---

## 2. The five layers, with Client as the reference

```
┌──────────────────────────────────────────────────────────────────┐
│  View (StatelessWidget)                                          │
│   ↳ user interaction → vm.method()                               │
├──────────────────────────────────────────────────────────────────┤
│  ViewModel (ChangeNotifier)                                      │
│   ↳ watches repo streams, dispatches saves                       │
├──────────────────────────────────────────────────────────────────┤
│  Repository                                                      │
│   ↳ reads/watches Drift, enqueues mutations to the outbox        │
├──────────────────────────────────────────────────────────────────┤
│  Drift  +  Outbox  +  id_remap (offline-create temp→real)        │
│   ↑                                                              │
│   │ drained by SyncRepository                                    │
│  HTTP service (POST /api/v1/…)                                   │
└──────────────────────────────────────────────────────────────────┘
```

| Layer | Client example |
|-------|----------------|
| View — List | `lib/ui/features/clients/views/client_list_screen.dart` |
| View — Detail | `lib/ui/features/clients/views/client_detail_screen.dart` |
| View — Edit | `lib/ui/features/clients/views/client_edit_screen.dart` |
| ViewModel | `lib/ui/features/clients/view_models/client_{list,detail,edit}_view_model.dart` |
| Repository | `lib/data/repositories/client_repository.dart` |
| Drift table | `lib/data/db/tables/clients_table.dart` |
| DAO | `lib/data/db/dao/client_dao.dart` |
| HTTP service | `lib/data/services/clients_api.dart` |

Every other entity (Product, Task, Vendor, Expense, …) follows the same shape. The generic bases live in `lib/data/repositories/base_entity_repository.dart` and `lib/ui/core/{list,detail,edit}/`. ViewModels typically extend `GenericListViewModel<T>` / `GenericEditViewModel<T>` and override only what's entity-specific.

---

## 3. The `Services` DI bag

A plain bag of singletons built once at startup and exposed via `Provider<Services>`.

- **Definition:** `lib/app/services.dart:79` (`class Services`)
- **Factory:** `Services.build(...)` at `lib/app/services.dart:336`
- **Per-entity wiring:** `lib/app/services_entity_wiring.dart` — registers each entity's API + repository + sync dispatcher
- **Module metadata** (routes, icons, screen builders): `lib/app/entity_modules.dart`

In a screen:

```dart
final services = context.read<Services>();
final clients = services.clients;        // ClientRepository
final auth = services.auth;              // AuthRepository
```

In a ViewModel: take the repo by constructor injection. ViewModels don't read `Services` directly.

Notable members of `Services`:

- `auth` (`AuthRepository`) — session, tokens, login/logout, company switching
- Entity repos: `clients`, `products`, `tasks`, `vendors`, `expenses`, `projects`, `recurringExpenses`, `taskStatuses`, `companyGateways`, `paymentTerms`, `taxRates`, `groupSettings`, `designs`, `expenseCategories`
- `sync` (`SyncRepository`) — outbox drain loop
- `apiClient` (`ApiClient`) — shared HTTP client (auth, version, error mapping)
- Controllers: `ThemeController`, `LocaleController`, `SidebarController`, `SettingsLevelController`, `AccentColorController`, `ResyncController`
- `diagnosticsLog` (debug only, `null` in release)

---

## 4. Code flow — Login

What happens when the user enters email + password and taps "Sign in":

1. **Login screen.** `lib/ui/features/auth/views/login_screen.dart:72` — `_onEmailSubmit` calls `vm.submit()`. The submit button (key `login_submit`) is at line 232; password field's `onSubmitted` (Enter to submit) is wired through `FormSaveScope` at line 220.

2. **ViewModel.** `lib/ui/features/auth/view_models/login_view_model.dart:131` — `LoginViewModel.submit()` flips `_busy = true`, calls `auth.login(...)` at line 144, and on exception sets `_errorKey`/`_errorMessage` for the screen to render.

3. **Repository.** `lib/data/repositories/auth_repository.dart:124` — `AuthRepository.login()` calls the auth service, then runs `_persistAndActivate(response)` at line 138.

4. **HTTP request.** `lib/data/services/api_client.dart:208` builds the headers (`X-API-Token`, version header, Accept) via `_buildHeaders` at line 631. The auth service issues `POST /api/v1/login` with email + password (and optional MFA code).

5. **Response handling.** `lib/data/services/api_client.dart:558` `_raiseFromResponse` maps non-2xx into typed exceptions: `case 412` (line 582) → `PasswordRequiredException`, 401 → unauthorized + single-flight logout, 422 → `ValidationException` carrying field errors.

6. **`_persistAndActivate`.** `lib/data/repositories/auth_repository.dart:604` — one Drift transaction that:
   - Merges per-company API tokens.
   - Picks the active company (preserves the one the user was on, otherwise `defaultCompanyId`).
   - Wipes + upserts `companies`, `users`, `user_settings`.
   - Fans out to bundled-entity repos via `onPersistBundles` (task statuses, company gateways, payment terms) — these come in the login envelope and don't need their own fetch.
   - Sets `_session.value` and `_credentials.value`.
   - Fires `onActiveCompanyChanged(currentId)` at line 890 so the outbox starts draining for the new company.

7. **Router redirect.** `lib/app/router.dart:112` — `buildRouter()` registers a `redirect` (line 121) that watches `credentials`. With creds present: if biometric is required → `/lock` (line 148, encoding the intended destination), otherwise → `defaultPostLoginRoute(session)` (line 28) which returns `/dashboard` if the user has `view_dashboard` permission, else `/clients`.

8. **Outbox drain kicks.** `AuthRepository.onActiveCompanyChanged` (declared at `auth_repository.dart:68`) is wired in `Services.build` to `SyncRepository.drainOnce` — so any pending mutations from a previous session start sending immediately.

### Restore on next launch

`lib/main.dart:67` builds `Services`, `lib/main.dart:69` calls `services.auth.restore()` (defined at `auth_repository.dart:450`) which re-hydrates the session from secure storage + Drift and fires a best-effort `/refresh`. `lib/main.dart:95` reads the saved route from `NavStateDao.current()` and passes it as `initialLocation` to `go_router` at line 208 — so the user lands back where they left off.

---

## 5. Code flow — Creating a product

What happens when the user fills out the New Product form and taps "Save". This is the canonical offline-first write path; if you understand this, every other mutation in the app works the same way.

1. **Edit screen.** `lib/ui/features/products/views/product_edit_screen.dart` — a thin wrapper around `EntityEditScreenScaffold<Product, ProductEditViewModel>`. The Save button calls `vm.save()` (defined on the generic base `GenericEditViewModel`).

2. **ViewModel.** `lib/ui/features/products/view_models/product_edit_view_model.dart:34` — `performSave()` checks `isCreate` (line 35) and calls `repo.create(...)` at line 36 for a new product or `repo.save(...)` at line 38 for an update.

3. **Repository — mint temp ID + Drift insert + outbox enqueue.** `lib/data/repositories/product_repository.dart:210` — `ProductRepository.create()`:

   ```dart
   final tmpId = mintTempId();              // 'tmp_<uuid>'  (base class line 127)
   final stored = draft.copyWith(id: tmpId);
   await db.transaction(() async {
     await db.productDao.upsert(...);        // is_dirty = true
     await enqueueMutation(                  // line 220
       companyId: companyId,
       entityId: tmpId,
       kind: MutationKind.create,
       payload: stored.toApiJson(),
     );
   });
   return stored;
   ```

   The repository returns the temp-ID product **before** the network ever happens. The UI re-renders instantly.

4. **Outbox enqueue.** `lib/data/repositories/base_entity_repository.dart:93` — `enqueueMutation` writes one row into the `outbox` table with `state = pending`, `attempts = 0`, and a fresh `idempotency_key = uuid.v4()` that's reused on every retry. After the transaction commits, line 116 schedules `onEnqueued(companyId)` which (in production wiring) calls `SyncRepository.drainOnce`.

5. **UI updates.** The Drift watch stream re-emits; the products list shows the new row immediately with a "pending sync" indicator if the device is offline.

6. **Drain loop.** `lib/data/repositories/sync_repository.dart:111` — `drainOnce(companyId)` pulls the oldest pending row via `OutboxDao.nextReady`, looks up the dispatcher for `EntityType.product` (registered in `lib/app/services_entity_wiring.dart`), and invokes the create handler.

7. **HTTP POST.** The dispatcher calls `ProductsApi.create(payload)` → `lib/data/services/api_client.dart:288` includes the `Idempotency-Key: <uuid>` header (line 646 in `_buildHeaders`) so retries are safe. Server returns the real product with its assigned `id`.

8. **Apply response + ID remap.** `lib/data/repositories/product_repository.dart:340` — `applyCreateResponse`:
   - Upserts the product row under the **real** server ID.
   - Deletes the `tmp_<uuid>` row.
   - Calls `recordCreateSuccess(tempId, realId)` (`base_entity_repository.dart:132`) which writes an `id_remap` row **and** rewrites any other pending outbox payloads that referenced the temp ID. (E.g. if the user created a product offline, then created an invoice line-item referencing it, the invoice's outbox payload still pointed at `tmp_…` — this step swaps it to the real ID before the invoice ever sends.)

9. **Open detail screen survives the swap.** `base_entity_repository.dart:66` — `resolveId` translates `tmp_…` to the real ID via `id_remap`, so a user with the product detail open at `/products/tmp_a1b2…` keeps seeing the same product without a URL change.

### Offline path

If the device is offline at step 7, the drain attempt fails. The outbox row stays in `pending` with `attempts` incremented and `next_attempt_at` pushed out by the backoff schedule. When connectivity returns, `ConnectivityWatcher` and `SyncLifecycleObserver` (wired in `lib/main.dart:219`) re-trigger the drain. From the user's perspective: the product was saved the instant they tapped Save; sync happens later, transparently.

---

## 6. Cross-cutting concerns

Each row points to the one file to open if you want to learn more. Details live in `CLAUDE.md` and `docs/architecture.md`; this is just a directory.

| Concern | Where to look |
|---|---|
| Outbox + retries (FIFO, backoff, dead-letter) | `lib/data/repositories/sync_repository.dart` |
| 401 single-flight logout | `lib/data/services/api_client.dart:549` (`_logoutFuture`) |
| 412 password gate | `lib/data/services/api_exception.dart:18` (`PasswordRequiredException`) + `lib/ui/features/shell/widgets/sync_event_listener.dart:78` (opens `ConfirmPasswordSheet`) |
| 422 validation errors | `lib/data/services/api_exception.dart:23` (`ValidationException` carries `Map<String, List<String>>`) |
| 409 conflicts | `ConflictResolutionSheet` — entry from outbox screen |
| Idempotency keys | generated in `base_entity_repository.dart:108`, attached in `api_client.dart:646` |
| Encrypted Drift | key `invoiceninja.db.key.v1` in `flutter_secure_storage` (see `lib/data/db/app_database.dart`) |
| `CompanyScopedDao` (multi-company lint) | `lib/data/db/company_scoped_dao.dart` |
| Data-layer import boundary (`lib/data` ↛ `lib/ui`) | `test/lint/layering_test.dart` + `lib/domain/columns/ids/` |
| Restore-on-restart (route + company) | `lib/app/nav_state_persister.dart` + `lib/main.dart:95` |
| Localization (`context.tr('key')`) | `lib/l10n/localization.dart` + `assets/i18n/<locale>.json` |
| Design tokens (`InTheme`) | `lib/app/design_tokens.dart` → wired into `MaterialApp` in `lib/app/theme.dart` |
| Diagnostics log (debug only) | `lib/app/diagnostics_log.dart` |
| Formatter (money / dates / addresses) | `lib/utils/formatting.dart` |

---

## 7. Testing

- **Unit tests** mirror `lib/` under `test/`. Run with `flutter test`.
- **Layering is enforced, not just described.** `test/lint/layering_test.dart` walks the transitive
  `package:admin/` import graph and fails if anything under `lib/data/` reaches `lib/ui/` or a
  Widget-bearing column registry. Keeping that boundary is what lets a data-layer test
  compile ~140 files instead of ~1,395. See CLAUDE.md § Strict rules for the history.
- **Repository contract harness**: `test/data/repositories/_base_entity_repository_contract.dart`. Every per-entity repo test registers the fixture and inherits a dozen-plus shared tests (offline create + id-remap, save dirty flag, delete, applyCreateResponse, conflicts, etc.). Look at `test/data/repositories/product_repository_test.dart` for the canonical invocation.
- **Integration tests**: `integration_test/app_smoke_test.dart` boots the real `InvoiceNinjaApp` against in-memory Drift + `MockClient`. **CI only** — don't run them locally; they steal focus from the dev's session. Stable widget keys (`login_submit`, `lock_unlock`, `lock_sign_out`) keep assertions locale-independent.
- **Widget previews**: `@Preview` annotations on `lib/ui/core/widgets/` light up Flutter Widget Preview in the IDE — useful for the design-system widgets (`EmptyState`, `ErrorView`, `StatusPill`, `LinkText`). Feature screens depend on `Services` and aren't preview-friendly.

---

## 8. I want to…

| Task | Start here |
|---|---|
| Add a new entity (full CRUD) | [`docs/adding-an-entity.md`](docs/adding-an-entity.md). Mirror `lib/data/repositories/client_repository.dart`. |
| Add a settings screen | [`docs/settings-screens.md`](docs/settings-screens.md). |
| Understand the outbox / sync engine | `lib/data/repositories/sync_repository.dart` + `lib/data/repositories/base_entity_repository.dart:93` (`enqueueMutation`). |
| Debug a login / logout bug | `lib/data/repositories/auth_repository.dart` + `lib/data/services/api_client.dart:549`. |
| Probe the live API for a response shape | [`docs/probing-the-demo-api.md`](docs/probing-the-demo-api.md). |
| Tweak theme tokens (colors, radii, spacing) | `lib/app/design_tokens.dart` + `lib/app/theme.dart`. |
| Add a locale | `lib/l10n/supported_locales.dart` + `tools/import_transifex_zip.dart`. See `CLAUDE.md` § Localization for the Transifex workflow. |
| Track what's built vs what's left | [`FEATURES.md`](FEATURES.md). |
| Read a corrupt-state log from a user's session | `lib/app/diagnostics_log.dart` + Settings → Advanced → System Logs in the running app. |

---

When you change something architectural — a new top-level directory, a new layer, a new cross-cutting concern — update this file in the same PR.
