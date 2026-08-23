# Settings screens

Companion to CLAUDE.md § Settings screens. The main file carries the 5-second decision tree, the three style names, and the User-Details anti-pattern. This doc carries the page skeletons (one recipe per style), the tabbed-shell pattern, and the rule for screens that mix top-level and cascade-aware fields.

## Smallest new-page skeleton

Each shape collapses to a short recipe. Don't write more than this — every other concern (Save button, dirty guard, FormSaveScope, override checkbox, company-switch rebuild, scope banner) already lives in the scaffold or the field widgets.

### Cascade-aware (`company.settings.*`)

Reference: `lib/ui/features/settings/views/basic/localization/localization_screen.dart`.

1. Add bindings for any new `company.settings.*` keys to `lib/ui/features/settings/widgets/settings_field_bindings.dart` (the `(read, write)` projection pair). Skip if the key is already there.
2. Write a one-line VM subclass: `class FooViewModel extends SettingsDraftViewModel { FooViewModel({required super.repo, required super.companyId}); }` — usually no body needed.
3. Build the screen as a `StatelessWidget` returning `CascadeSettingsScaffold(titleKey: 'foo', companyVmFactory: ({required repo, required companyId}) => FooViewModel(repo: repo, companyId: companyId), body: const _FooBody())`. **If your screen also touches top-level `company.*` fields (`sizeId`, `industryId`, anything not under `company.settings.*`), switch to the company-only skeleton instead** — `CascadeSettingsScaffold` swaps in `ClientSettingsDraftViewModel` at client scope where `updateCompany` is a no-op, so top-level edits would be silently dropped. See § Mixing both kinds of fields on one screen below.
4. The body is `SettingsFormShell(sections: [FormSection(title: ..., children: [OverridableTextField(apiKey: ..., label: ...), OverridableSearchableDropdownField<…>(apiKey: ..., ...), ...])])`. Drop in any `Overridable*` widget — the cascade-override semantics are wired by `OverridableField.bind` inside.
5. Export `const kFooSearchKeys = <String>[...]` from the screen file and add `'foo': [...kFooSearchKeys]` to `kSettingsSearchCatalog` in `lib/ui/features/settings/settings_search_catalog.dart`. `search_catalog_consistency_test` will fail until both ends match.
6. Register the sidebar entry in `kSettingsSections` (also in `settings_search_catalog.dart`).

### Company-only (`company.*` top-level, no cascade)

Also the right pick when the page mixes `company.*` *and* `company.settings.*`. Reference: `lib/ui/features/settings/views/basic/company_details/company_details_screen.dart` + `company_details_shell.dart`.

1. Subclass `SettingsDraftViewModel` (same one-liner as above). The company-only VM is just a `SettingsDraftViewModel` — `updateCompany` is already on the base.
2. Wrap in `SettingsCompanyScopedHost<FooViewModel>(create: …, builder: (context, vm) => SettingsPageScaffold<FooViewModel>(titleKey: 'foo', viewModel: vm, body: const _FooBody()))`. The host owns the company-switch rebuild; do not use `CascadeSettingsScaffold` here.
3. Body uses plain `TextField` / `DropdownButtonFormField` / `SearchableDropdownField` that call `vm.updateCompany((c) => c.copyWith(...))`. No `Overridable*` widgets — top-level fields don't cascade.
4. Group cascade-aware (`company.settings.*`) and company-only fields into separate `FormSection`s if the page touches both, so the override-checkbox visibility lines up at client scope.
5. Search catalog + sidebar entry same as cascade-aware (steps 5–6).

### Device-local (no server, no VM)

Reference: `lib/ui/features/settings/views/basic/device_settings_screen.dart`.

1. Build the screen as a `StatelessWidget` returning `SettingsScreenScaffold(titleKey: 'foo', body: SettingsFormShell(sections: [FormSection(title: ..., children: [ThemeTile(), BiometricToggleTile(), ...])]))`. No VM, no `Provider`, no Save button.
2. Each tile reads + writes its own controller directly (`services.theme`, `services.locale`, `services.biometric`, …). New tiles belong as their own typed widget (`FooTile`) in `lib/ui/features/settings/widgets/`, not as inline `ListTile`s.
3. Pass `spacing: 0` to `FormSection` only when the tiles want their own row separators (a `Divider(height: 1)` between them, like `preferences_screen.dart`). Otherwise let `FormSection` auto-spacing handle it.
4. Search catalog + sidebar entry same as the server-backed shapes.

### Tabbed shells

Reference: `lib/ui/features/settings/views/basic/company_details/company_details_shell.dart`.

For company-only screens whose content is split across tabs, compose `TabbedSettingsShell<V>` (`lib/ui/features/settings/widgets/tabbed_settings_shell.dart`) with a `List<TabbedSettingsTab>` (each entry is `slug + labelKey + body` — the first tab uses an empty slug). Register the matching route entries with `tabbedSettingsRoutePair(...)` in `settings_routes.dart`. The shell owns the `TabController`, the URL ↔ tab-index sync, and the shared-page-key trick that keeps the draft VM alive across the bare-URL and per-tab routes — do not re-implement these inline. Per-screen specifics (e.g. Company Details' statics warm-up for the Size/Industry dropdowns) sit in a thin `StatefulWidget` wrapper around `TabbedSettingsShell`, not inside the shell itself.

### Bundled-entity CRUD (list + edit)

Reference: `lib/ui/features/settings/views/advanced/payment_terms_screen.dart` and `payment_terms_edit_screen.dart`.

For server-bundled reference entities reachable from the settings sidebar (payment terms, task statuses, group settings, tax rates, expense categories, schedules, …): the entity has a list screen at `/settings/<slug>` and an edit screen at `/settings/<slug>/new` + `/:id`. Both ends share the same chrome — `SettingsEntityListScaffold<T>` and `SettingsEntityEditScaffold<T, VM>` (both under `lib/ui/features/settings/widgets/`) — so a new entity only declares its rows, fields, and `canSave` predicate.

Use this pattern for entities that are **bundled** in `/refresh?first_load=true` (currently `task_statuses`, `company_gateways`, `payment_terms`; `tax_rates` and `designs` on deck per `lib/data/models/api/login_response_api_model.dart` § "Add new bundles here"). Full paginated entities (clients, invoices, products, …) still use `EntityListScreenScaffold` + `EntityEditScreenScaffold` from `docs/adding-an-entity.md`.

Both scaffolds take **extractor closures** (`idOf`, `isArchivedOf`, `isDeletedOf`) instead of marker interfaces. Keeps domain models free of mixin ceremony and reads naturally with freezed getters.

#### Edit screen — full skeleton

```dart
class TaxRatesEditScreen extends StatelessWidget {
  const TaxRatesEditScreen({this.existingId, super.key});
  final String? existingId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.taxRates;

    return SettingsEntityEditScaffold<TaxRate, TaxRateEditViewModel>(
      existingId: existingId,
      backRoute: '/settings/tax_rates',
      createTitleKey: 'new_tax_rate',
      editTitleKey: 'edit_tax_rate',
      wireName: 'tax_rate',
      watchById: (id) => repo.watch(companyId: companyId, id: id),
      refreshAll: () => repo.refreshAll(companyId: companyId),
      onArchive: (id) => repo.archive(companyId: companyId, id: id),
      onRestore: (id) => repo.restore(companyId: companyId, id: id),
      onDelete:  (id) => repo.delete(companyId: companyId, id: id),
      vmFactory: ({existing}) => TaxRateEditViewModel(
        repo: repo, companyId: companyId, existing: existing,
      ),
      isArchivedOf: (t) => t.archivedAt != null,
      isDeletedOf:  (t) => t.isDeleted,
      canSave: (vm) =>
          !vm.isSaving && vm.isDirty && vm.draft.name.trim().isNotEmpty,
      bodyBuilder: (context, vm) => [
        FormSection(
          title: context.tr('tax_rate'),
          children: [
            SettingsTextField(
              initialValue: vm.draft.name,
              labelKey: 'name',
              onChanged: vm.setName,
              errorText: vm.fieldErrorFor('name'),
              externalSyncKey: vm.original?.id,
            ),
          ],
        ),
      ],
    );
  }
}
```

The scaffold owns the load → vm-build → save lifecycle, the AppBar overflow + Save button, and the `FormSaveScope` + `SettingsFormShell` wrapping. `bodyBuilder` returns a list of `FormSection`s so a screen can compose multiple cards (e.g. "Tax rate" + "Advanced") if needed.

Use `SettingsTextField` (`lib/ui/features/settings/widgets/settings_text_field.dart`) instead of rolling a per-screen `_NameField`. It owns the `TextEditingController`, wires `FormSaveScope` for Enter-to-save, and **reseeds the controller when `externalSyncKey` changes** so external draft mutations (deep-link arrival, unsaved-changes-guard Discard) repopulate the field instead of being silently dropped. Pass `vm.original?.id` as the sync key.

#### List screen — full skeleton

```dart
class TaxRatesScreen extends StatelessWidget {
  const TaxRatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.taxRates;

    return SettingsEntityListScaffold<TaxRate>(
      titleKey: 'tax_rates',
      sectionTitleKey: 'tax_rates',
      newRoute: '/settings/tax_rates/new',
      newLabelKey: 'new_tax_rate',
      emptyIcon: Icons.percent_outlined,
      emptyTitleKey: 'no_tax_rates',
      emptyHintKey: 'no_tax_rates_hint',
      supportsArchive: true,
      // Guard the empty-companyId race during logout / pre-tenant-pick
      // — the scaffold fires refreshAll unconditionally in initState.
      refreshAll: () async {
        if (companyId.isEmpty) return;
        await repo.refreshAll(companyId: companyId);
      },
      stream: ({required includeArchived}) => includeArchived
          ? repo.watchAllIncludingArchived(companyId: companyId)
          : repo.watchAll(companyId: companyId),
      isArchivedOf: (t) => t.archivedAt != null,
      isDeletedOf:  (t) => t.isDeleted,
      rowBuilder: (t) => _TaxRateRow(key: ValueKey(t.id), rate: t),
      archivedRowBuilder: (t) =>
          _TaxRateRow.archived(key: ValueKey(t.id), rate: t),
    );
  }
}
```

The scaffold owns the `StreamBuilder`, the empty state, the `FormSection` container, the "+ New" tile, the Show Archived / Show Active toggle in the AppBar, and the archived section. Each row builder is a thin `StatelessWidget` rendering a `ListTile` + `Divider` (see `_PaymentTermRow` for the canonical layout including the muted "Archived" pill for the `archivedRowBuilder` variant).

#### Reorderable lists

When the entity supports drag-to-reorder (task statuses today; schedules likely), pass an additional `onReorder` callback and a `reorderableRowBuilder: Widget Function(T item, int index)`. The scaffold owns the optimistic snapshot so the drag drop repaints instantly, and the row's `index` is what the caller wires into `ReorderableDragStartListener(index: index, ...)`. Reference: `task_statuses_screen.dart`.

## Mixing both kinds of fields on one screen

When a single page touches *both* `company.settings.*` (cascade-aware) and `company.*` (top-level) fields — e.g. Company Details "Details" tab — do **not** use `CascadeSettingsScaffold`. The cascade scaffold swaps in `ClientSettingsDraftViewModel` at client scope, where `updateCompany` is a no-op (top-level fields don't apply per-client) — the UI would silently drop the user's edits to those fields. Use `SettingsPageScaffold<V>` directly with a company-only VM (`SettingsDraftViewModel` subclass), the way `CompanyDetailsShell` does. Group cascade-aware and company-only fields into separate `FormSection`s so the override-checkbox visibility lines up; reference: `_SizeField` and `_IndustryField` under the "business" section in `lib/ui/features/settings/views/basic/company_details/company_details_screen.dart`.

Reminder: every new settings page must also contribute its field labels to `kSettingsSearchCatalog` — see CLAUDE.md § Settings search catalog.

## Adding a top-level `company.*` field

A field under `company.settings.*` round-trips automatically through the `settings` JSON blob. A **top-level** `company.*` field does not — it needs a dedicated column and five coordinated edits, and skipping any one of them loses the server's value silently:

1. `CompanyApi` declaration (`lib/data/models/api/company_api_model.dart`) with the wire `@JsonKey` name.
2. Domain `Company`: field + `fromApi` + `toApiJson()` (`lib/data/models/domain/company.dart`).
3. Drift column in `companies_table.dart` — plus a forward migration (`docs/migrations.md`), since the app is shipped.
4. `CompanyRepository`: the `updateCompany` companion, the `applyUpdateResponse` companion, and `_fromRow`.
5. **`CompanyEnvelopeApi` (`lib/data/models/api/login_response_api_model.dart`) *and* the `CompaniesCompanion.insert` in `AuthRepository._persistAndActivate`.**

Step 5 is the one that used to get skipped. `_persistAndActivate` re-writes the companies row from the envelope on every login/refresh, so a column the envelope doesn't declare lands its Drift **table default** — overwriting whatever the server actually sent. That's issue #29: the SMTP block was modelled everywhere except the envelope, so every app launch blanked the user's mail credentials, and a save made from that blanked draft pushed the blanks back to the server.

There is no "applyUpdateResponse-only" exemption. `/login` and `/refresh` build the company with the same `CompanyTransformer` as `GET /companies/{id}`, so every top-level column is already on the wire — declare it on the envelope and mirror it in the login insert. Sole exception: a **write-only** secret the server never returns (`e_invoice_certificate_passphrase` — only its `has_…` flag comes back). Verify with a probe (`docs/probing-the-demo-api.md`) if you're unsure a key is returned.

If the money/date `Formatter` reads the field, also overlay it from the row in `Services._buildFormatter`.

## Company Details style — when each option applies

- **Cascade-aware (fields on `company.settings.*`)** → wrap in `CascadeSettingsScaffold` (`lib/ui/features/settings/widgets/cascade_settings_scaffold.dart`). It picks the right VM for the active `SettingsLevelController` (your factory at company scope, the shared `ClientSettingsDraftViewModel` at client scope), delegates VM lifecycle (build, load, dispose, company-switch rebuild) to `SettingsCompanyScopedHost`, and hands the result to `SettingsPageScaffold`. Caller supplies just `titleKey`, `companyVmFactory`, and `body`. Reference: `lib/ui/features/settings/views/basic/localization/localization_screen.dart`.
- **Company-only (also touches top-level `Company` fields like `sizeId` / `industryId`)** → wrap in `SettingsPageScaffold<V>` directly with a company-only VM. The cascade scaffold isn't appropriate because the client scope wouldn't apply to top-level Company fields. Reference: `lib/ui/features/settings/views/basic/company_details/company_details_shell.dart` (which uses `SettingsCompanyScopedHost` directly because it needs to own its own `TabController` outside the scaffold).
- **Action-only sub-shape (no editable fields)**: some Company Details tabs render server state and trigger uploads instead of editing fields — `documents_screen.dart` and `logo_screen.dart` are the precedent. They're still Company Details style: same `SettingsFormShell` + `FormSection` chrome, same VM, same Save button (just no contribution to it). The async upload writes outside the outbox via `services.company.upload*()` because file uploads aren't replayable; that's a deliberate exception, not a third style.
- Body in either case: `SettingsFormShell(sections: [FormSection(title: ..., children: [...]), ...])`. The shell handles centering + max-width + padding; `FormSection` is the bordered card with header + divider + content column. **`FormSection` auto-inserts `InSpacing.lg` between adjacent children** — drop the manual `SizedBox(height: InSpacing.lg)` interleaves. Pass `spacing: 0` only when the section owns its own row separators (e.g. a `Divider` between tiles, like `preferences_screen.dart`).
- Field widgets — pick by **where the field is stored**:
  - `company.settings.*` (cascade-aware) → `OverridableTextField` / `OverridableDropdownField` / `OverridableSearchableDropdownField` / `OverridableMarkdownField`. They render the override checkbox at group/client scope and hide it at company scope, so one call site covers both.
  - `company.*` (top-level: `sizeId`, `industryId`, `customFields`, `legalEntityId`, …) → plain `DropdownButtonFormField` / `SearchableDropdownField` / `TextField` that call `vm.updateCompany((c) => c.copyWith(...))`. These do not cascade and do not get the override wrapper. Group cascade-aware and company-only fields into separate `FormSection`s when they're on the same screen — Company Details "Details" tab is the canonical example.

## Width cap: every body under `/settings/...` goes through `SettingsFormShell`

`SettingsFormShell` (`lib/ui/features/settings/widgets/settings_form_shell.dart`) wraps its body in `ListView → Center → ConstrainedBox(maxWidth: 720)` and adds the outer `EdgeInsets.all(InSpacing.xl)` padding. **Every screen the user reaches from the settings sidebar renders its body through it** so the column width matches across Localization, Online Payments, Company Details, etc.

This rule applies even when the surrounding chrome isn't the standard settings scaffold. The gateway-edit screen lives under `/settings/company_gateways/.../edit` but uses `EntityEditScreenScaffold` (the same chrome Clients / Products / Tasks use) because it's a full CRUD entity. `EntityEditScreenScaffold` deliberately does **not** constrain width (Clients / Products / Tasks live outside `/settings/...` and want the full window). To get the right look under `/settings/...`, each of the four gateway-edit tab bodies wraps in `SettingsFormShell`:

- Pure-`FormSection` bodies → `SettingsFormShell(sections: [FormSection(...), ...])`. Reference: `gateway_settings_tab.dart`, `gateway_required_fields_tab.dart`.
- Tabs with a leading non-section element (a Learn-more button, a chip selector) → `SettingsFormShell(child: Column(crossAxisAlignment: stretch, mainAxisSize: min, children: [..., FormSection(...), ...]))`. Reference: `gateway_config_form.dart`, `gateway_limits_fees_tab.dart`.

The anti-pattern: a top-level `ListView(padding: EdgeInsets.all(InSpacing.lg), children: [...])` inside a settings tab. The body stretches full-width on a wide window and visibly diverges from neighboring settings screens. The fix is mechanical: hand the same children to `SettingsFormShell` and drop the manual `ListView` + padding.

The TabBar above an entity's edit tabs stays full-width — TabBars conventionally span the full bottom of the AppBar (matches `CascadeTabbedSettingsShell` for Localization). Only the per-tab body gets capped.

## AppBar chrome: back arrow vs hamburger

`SettingsScreenScaffold` picks the leading widget; ~40 screens funnel through it,
so don't hand-roll one. The rule is **not** width alone (that was issue #40 —
the hamburger owned the slot at every narrow width, so the arrow could never
appear, and the screen offered no way back to the Settings menu):

- **Section list beside you** (`SettingsTwoPaneScope.of(context)`, published by
  `SettingsShell` from the `LayoutBuilder` that decides the split) → no leading.
  An arrow would be actively wrong there: `/settings` redirects straight back
  out to Company Details at that width.
- **Otherwise, a sub-page** (`Navigator.canPop()`) → `const BackButton()`. It
  pops, which runs the page's `PopScope` discard guard and matches what the
  Android back gesture does. Settings routes carry no `GoRoute.onExit`, so a
  `go()`-based back would skip the guard silently.
- **Otherwise, narrow** → `DrawerHamburger()` + the `AppDrawer`. This is the
  `/settings` index, a nav root. Sub-pages deliberately drop `drawer:` so the
  Scaffold's edge-drag can't fight the back gesture.
- An explicit `leading:` still wins at every width, for drill-ins that want an
  arrow even on two-pane.

`automaticallyImplyLeading` is **always false** here. Leave it inferred and
`AppBar` synthesizes its own back button from `impliesAppBarDismissal` — true on
every nested settings page — putting an arrow on the two-pane layout.

Settings destinations that are *entity lists* (Credit Cards & Banks, Payment
Links, Expense Categories) don't reach this scaffold; `settingsBackTargetFor`
(`settings_two_pane_scope.dart`) gives `EntityListScreenScaffold` the same
affordance. Note the arrow is structural **Up**, not history Back: landing on
the URL-parent makes `NavHistoryController` *replace* the entry rather than
append (CLAUDE.md § Strict rules).

## Anti-pattern: User Details ListView+ListTile shape (full version)

Do not introduce raw `ListView` + `ListTile` layouts (icon-leading row tiles, dividers between rows) for new settings panels. Even simple toggles or single actions belong inside a `FormSection` so the whole settings sidebar reads as one design system. The User Details and Preferences screens use FormSection cards now too — they're the right precedent, not the old pre-conversion shape.

A `ListTile` *itself* is fine when wrapped in a typed control widget (`ThemeTile`, `BiometricToggleTile`, `_LocaleTile` in Preferences) and dropped inside a `FormSection`. The anti-pattern is the unwrapped `ListView`-of-bare-`ListTile`s with no card chrome — that's what the old User Details screen was, and that shape doesn't come back.

This rule applies to **read-only diagnostic screens and action-only screens too**, not just editable forms. Even a single button or a list of key/value rows belongs inside a `FormSection` so the settings sidebar reads as one design system. References: `views/basic/account_management/overview_screen.dart` (single-action `FormSection` with `spacing: 0`) and `views/advanced/system_logs_screen.dart` (multiple `FormSection` cards of read-only rows, with a private `_DiagnosticRow` helper for the label/value layout).

## Settings search catalog

`lib/ui/features/settings/settings_search_catalog.dart` is the single source of truth for both the settings sidebar layout (`kSettingsSections`) and the in-app settings search (`kSettingsSearchCatalog`). Whenever you add, rename, or remove a user-facing field on any screen under `lib/ui/features/settings/views/**`, update the matching section's entry in `kSettingsSearchCatalog`.

- Section keys are the route slugs (e.g. `company_details`, `online_payments`).
- Field entries are **localization keys** (not rendered labels) — search lowercases the resolved string per locale.
- Adding a brand-new settings section means adding both a `SettingsSectionDef` entry and a `kSettingsSearchCatalog` entry.
- Each tab/page also exports a `kFooSearchKeys` constant alongside its widget; `search_catalog_consistency_test` enforces both ends match.

## Custom field placement — single home

All custom-field **definitions** live under `Settings > Custom Fields` (`lib/ui/features/settings/views/advanced/custom_fields/`) — the only surface where the per-entity (`user1`–`user4`, `client1`–`client4`, etc.) definitions are configured. Deviation from React (which also exposes a Custom Fields tab on Settings > User Details): the Flutter app drops that tab to keep every definition in one place. Per-user custom *values* (the four `user1…user4` inputs the React Details tab surfaces) also live alongside the generic custom-field rendering used elsewhere — not via a duplicate path on the profile screen.
