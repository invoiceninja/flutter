import 'package:flutter/foundation.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/ui/features/settings/view_models/draft_stream_host.dart';
import 'package:admin/ui/features/settings/widgets/settings_field_bindings.dart';

/// Public host interface consumed by widgets that bind to a settings draft
/// (`OverridableTextField`, `OverridableMarkdownField`, future settings-bound
/// widgets) and by the surrounding [SettingsPageScaffold] (load, dirty,
/// save lifecycle). Widgets read this off
/// `context.{read,watch}<SettingsDraftHost>` so they're decoupled from the
/// concrete VM type.
///
/// Extends [ChangeNotifier] so concrete subclasses inherit the
/// add/remove-listener machinery without separately mixing it in. Three
/// shapes ship with this codebase: the company-scoped
/// [SettingsDraftViewModel] and the User-Details-scoped
/// [UserDetailsViewModel] both inherit lifecycle from [DraftStreamHost];
/// the client-scoped [ClientSettingsDraftViewModel] extends this directly
/// because its state shape (sparse override blob) doesn't fit the
/// stream-a-typed-row pattern.
///
/// The cascade-shaped methods ([settings], [updateSettings], [isOverridden],
/// etc.) default to **no-op stubs** so a host that doesn't participate in
/// the cascade (User Details) doesn't have to write boilerplate. Cascade-
/// bound hosts override them.
abstract class SettingsDraftHost extends ChangeNotifier {
  // -- Field surface (read/write via SettingsBinding) ----------------------

  /// Merged-view CompanySettings — what the bound widgets render. At
  /// company scope this is the company's own settings; at client scope
  /// this is the company defaults overlaid with the client's overrides.
  /// Default is empty for hosts that don't participate in the cascade.
  CompanySettings get settings => const CompanySettings();

  /// The entity's *own* draft, never the merged view. At company scope
  /// this equals [settings]; at client scope it returns the sparse
  /// override blob (every null field means "inherit"). Used by
  /// `OverridableField.bindInline` to detect whether a dynamically-keyed
  /// field is locally overridden — `[settings]` would lie at client
  /// scope because it overlays the company defaults.
  CompanySettings get draftSettings => const CompanySettings();

  Company? get draft => null;

  /// True at the cascade (client / group) scopes, false at company scope.
  /// Clear-writes pick their sentinel by this: at company scope an explicit
  /// '' / 0 / {} survives the `{...rawSettings, ...}` PUT merge (a typed
  /// null is omitted by toJson and resurrects from the raw snapshot); at
  /// cascade scope the right clear is a typed null — it removes the
  /// override from the sparse draft locally, and the client/group save
  /// strips nulls. Writing '' at cascade scope instead creates a phantom
  /// local override the server's blank-stripping saver ignores — the app
  /// and server-rendered PDFs would disagree.
  bool get isCascadeScope => draft == null;

  /// The company this settings draft belongs to. At company scope this is the
  /// [draft]; at client scope [draft] is null, so cascade pages that need
  /// company-level fields (e.g. Tax Settings reading the company's tax-rate
  /// slot counts / decimal-separator setting) read them here instead. The
  /// client-scoped host overrides this with a sparse [Company] built from the
  /// loaded company row. Never write through it — it's read-only context.
  Company? get companyContext => draft;

  /// The company as last loaded or saved — the baseline [draft] started
  /// from, so a field compared against it reads "unsaved" while the user is
  /// still typing. Null at the cascade scopes and before [load] resolves.
  /// A saved value has not necessarily reached the server: it waits in the
  /// outbox until it syncs.
  Company? get initialCompany => null;

  /// The baseline settings the draft started from. Email Settings's
  /// send-time sync prompt compares the draft's `entitySendTime`
  /// against this to decide whether to show the "Also apply to existing
  /// entities" checkbox.
  ///
  /// At company scope, this is the loaded company's settings; at
  /// client scope, the loaded client's sparse override blob. Empty
  /// (`const CompanySettings()`) before [load] has resolved.
  CompanySettings get initialSettings => const CompanySettings();

  /// Apply a freezed copyWith to the settings blob. No-op by default;
  /// cascade-bound hosts override.
  void updateSettings(CompanySettings Function(CompanySettings) edit) {}

  /// Apply a freezed copyWith to the top-level company (size_id,
  /// industry_id, custom_fields, …). No-op by default; company-scoped
  /// hosts override.
  void updateCompany(Company Function(Company) edit) {}

  /// True when the entity's *own* settings have a non-null value for the
  /// given API key. Used by [OverridableField] to decide whether the
  /// field is currently overriding the cascaded default. Default false
  /// for hosts that don't participate in the cascade.
  bool isOverridden(String apiKey) => false;

  /// Toggle an override for the given API key. No-op by default;
  /// cascade-bound hosts override.
  void setOverride({
    required String apiKey,
    required bool enabled,
    String? cascadedValue,
  }) {}

  /// Per-field validation errors, keyed by apiKey. Populated by [save]
  /// when the server returns 422; cleared on the next edit. Empty by
  /// default.
  Map<String, List<String>> get fieldErrors;

  // -- Lifecycle surface (consumed by SettingsPageScaffold) ----------------

  /// True once the initial load has resolved.
  bool get isLoaded;

  /// True when the host has populated whatever shape its overridable
  /// widgets read against (e.g. a non-null `Company` draft). Defaults to
  /// `true` for hosts that don't carry a separate "draft" object beyond
  /// [settings] — implementations whose first paint needs an extra
  /// frame should override. Used by [SettingsPageScaffold] to hold the
  /// spinner past [isLoaded].
  bool get draftReady => true;

  /// True when the draft has diverged from the loaded baseline.
  bool get isDirty;

  /// True while a [save] call is in flight.
  bool get isSaving;

  /// Non-null when the initial load failed. The page renders a banner
  /// above the body so the user can still see whatever subset of the
  /// draft loaded.
  String? get loadError;

  /// Non-null when the most recent [save] threw. Surfaced as the detail
  /// line in the "save failed" toast.
  String? get submitError;

  /// Restore the draft to the last-loaded baseline. Called from the
  /// unsaved-changes guard's Discard path.
  void reset();

  /// Persist the draft. Returns non-null on success (the saved entity,
  /// type is intentionally [Object] so different backings can return
  /// whatever they like) and null on failure — `runSettingsSave`
  /// distinguishes the two without caring about the concrete return
  /// type.
  Future<Object?> save();

  /// Subscribe to whatever backing store this host watches and kick off
  /// any background server refresh. Idempotent — every implementation
  /// no-ops on re-entry. [CascadeSettingsScaffold] (and any future
  /// generic chrome) can invoke this without dispatching on the
  /// concrete subclass.
  Future<void> load();
}

/// Settings VM for a [Company] draft. Owns nothing — the lifecycle
/// (load/watch/dirty-preserve/reset/save), the load/submit error
/// surface, and the table-driven override path all live in
/// [DraftStreamHost]. This class supplies the Company-specific glue:
/// repo wiring, the cascade method overrides, and the
/// [extraOutboxPayload] hook.
///
/// New settings pages plug in by extending this with a one-line
/// subclass. Each page keeps its own subclass type so Provider lookups
/// stay typed and each page's draft is naturally scoped to its mount
/// lifecycle.
class SettingsDraftViewModel extends DraftStreamHost<Company> {
  SettingsDraftViewModel({required this.repo, required this.companyId});

  final CompanyRepository repo;
  final String companyId;

  // -- DraftStreamHost glue --------------------------------------------------

  @override
  Company get emptyValue => const Company();

  @override
  Stream<Company?> createWatch() => repo.watchCompany(companyId);

  @override
  Future<void> kickRefresh() => repo.refresh(companyId);

  @override
  Future<Company> performSave(Company draft) async {
    await repo.updateCompany(
      draft: draft,
      extraOutboxPayload: extraOutboxPayload(),
    );
    return draft;
  }

  // -- Cascade-bound overrides ------------------------------------------------

  /// Snapshot of the in-progress edit. Null until [load] resolves.
  @override
  Company? get draft => draftValue;

  @override
  CompanySettings get settings =>
      draftValue?.settings ?? const CompanySettings();

  /// Company scope has no separate "own vs. merged" — the company *is*
  /// the top of the cascade. Same value as [settings].
  @override
  CompanySettings get draftSettings => settings;

  @override
  CompanySettings get initialSettings =>
      initialValue?.settings ?? const CompanySettings();

  @override
  Company? get initialCompany => initialValue;

  @override
  void updateSettings(CompanySettings Function(CompanySettings) edit) {
    updateDraft((c) => c.copyWith(settings: edit(c.settings)));
  }

  @override
  void updateCompany(Company Function(Company) edit) {
    updateDraft(edit);
  }

  @override
  bool isOverridden(String apiKey) {
    final json = draftValue?.settings.toJson() ?? const <String, dynamic>{};
    return json.containsKey(apiKey) && json[apiKey] != null;
  }

  @override
  void setOverride({
    required String apiKey,
    required bool enabled,
    String? cascadedValue,
  }) {
    final draft = draftValue;
    if (draft == null) return;
    final value = enabled ? cascadedValue : null;
    final binding = settingsBindings()[apiKey];
    if (binding == null) {
      throw StateError(
        'Unknown settings binding "$apiKey" — add it to settings_field_bindings.dart',
      );
    }
    updateDraft((c) => c.copyWith(settings: binding.write(c.settings, value)));
  }

  // -- Extension point for subclasses ----------------------------------------

  /// One-shot control keys to piggyback onto the outbox payload on the
  /// next save. `null` (the default) leaves the payload untouched.
  /// Subclasses override to push transient flags through the sync
  /// layer — Email Settings uses this to carry `_sync_send_time` from
  /// the inline "Apply to existing" checkbox to the company PUT's query
  /// string. The returned map is read once per save; subclasses are
  /// responsible for clearing their own transient state afterward.
  Map<String, dynamic>? extraOutboxPayload() => null;
}
