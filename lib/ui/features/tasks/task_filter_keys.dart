import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/project_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/repositories/task_status_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/client_filter_key.dart';
import 'package:admin/ui/core/list/search/custom_field_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_keys_common.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/membership_filter_key.dart';
import 'package:admin/ui/core/list/search/record_chip_names.dart';
import 'package:admin/ui/core/list/search/server_name_suggestions.dart';
import 'package:admin/ui/core/list/search/tag_filter_key.dart';

/// Tasks expose state (active/archived/deleted) as their built-in
/// filter dimension plus per-client, per-project and per-status filters
/// resolved through their respective repository name suggestions.
List<FilterKey> buildTaskFilterKeys({
  required ClientRepository clients,
  required ProjectRepository projects,
  required TaskStatusRepository statuses,
  required TagRepository tags,
  required String companyId,
  Company? company,
  String? Function(String id)? nameForClientId,
  String? Function(String id)? nameForProjectId,
}) => <FilterKey>[
  const IsFilterKey(),
  // `client:` — the shared multi-value key every `client_id`-honouring list
  // uses. Mirrored locally by `TaskDao.watchPage`'s `clientIds` predicate.
  // Central to the "bill this client's work across every project" flow:
  // narrow to the client, select all, Invoice.
  ClientFilterKey(
    clients: clients,
    companyId: companyId,
    nameForClientId: nameForClientId,
  ),
  ProjectFilterKey(
    projects: projects,
    companyId: companyId,
    nameForProjectId: nameForProjectId,
  ),
  StatusFilterKey(statuses: statuses, companyId: companyId),
  TagFilterKey(tags: tags, companyId: companyId, entityType: 'task'),
  // Window only: the task API filters due dates by `due_date_range` alone
  // (React #3380); `TaskDao.watchPage` mirrors it locally.
  const DateColumnFilterKey(
    id: 'due_date',
    serverKey: 'due_date',
    labelKey: 'due_date',
    windowOnly: true,
    lookAhead: true,
  ),
  for (var i = 1; i <= 4; i++)
    CustomFieldFilterKey(
      columnIndex: i,
      configuredLabel: company?.customFieldLabel('task$i') ?? '',
    ),
];

/// `status:foo` — multi-valued, resolved through the task-status
/// repository. `serverKey` is `task_status` (`TaskFilters::task_status` —
/// CSV of status ids).
///
/// Server quirk: `task_status` also applies `whereNull('invoice_id')`, so
/// filtering by any task status additionally hides invoiced tasks. That's
/// server-side and not adjustable from the client.
class StatusFilterKey extends MembershipFilterKey {
  StatusFilterKey({required this.statuses, required this.companyId}) {
    // Populate an `id → name` cache so chips render the status name instead
    // of the raw hashid. Reuses the same stream that backs the suggestion
    // dropdown — task statuses are bundled and few, so watching the full list
    // is cheap and none is ever missing from it.
    _namesSub = statuses.watchAll(companyId: companyId).listen((rows) {
      _names
        ..clear()
        ..addEntries(rows.map((s) => MapEntry(s.id, s.name)));
    });
  }

  final TaskStatusRepository statuses;
  final String companyId;
  final Map<String, String> _names = <String, String>{};
  StreamSubscription<List<TaskStatus>>? _namesSub;

  @override
  String get id => 'status';

  @override
  bool get acceptsTypedValue => false;

  @override
  int? get idleSuggestionCap => 50;

  @override
  bool get isPrimary => true;

  @override
  String get serverKey => 'task_status';

  /// Render checkboxes — inherits the single-write `selectExclusive` from
  /// [MembershipFilterKey].
  @override
  bool get checkboxMultiSelect => true;

  @override
  String displayLabel(BuildContext context) => context.tr('status');

  /// Resolve a status id to its name for the chip label; falls back to the
  /// raw id until the names stream has produced its first event.
  @override
  String displayValueFor(String rawValue) {
    final cached = _names[rawValue];
    if (cached != null && cached.isNotEmpty) return cached;
    return rawValue;
  }

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    return statuses.watchAll(companyId: companyId).map((all) {
      final filtered = q.isEmpty
          ? all.take(idleSuggestionCap!)
          : all.where((s) => s.name.toLowerCase().contains(q));
      return [
        for (final s in filtered)
          FilterValueSuggestion(
            rawValue: s.id,
            displayLabel: s.name.isEmpty ? s.id : s.name,
          ),
      ];
    });
  }

  /// Release the names-cache subscription when the filter key is replaced
  /// (company switch) or its hosting field unmounts.
  @override
  void dispose() {
    _namesSub?.cancel();
    _namesSub = null;
  }
}

/// `project:foo` — **single-valued**, resolved through the project
/// repository. The server filter is `TaskFilters::project_tasks`, which
/// takes exactly one project id (`where('project_id', decode($v))`), so
/// picking a project replaces any prior selection rather than unioning.
/// Raw value is the server project id; the suggestion menu streams the
/// cheap `(id, name)` projection from `ProjectRepository.watchActiveNames`.
///
/// The chip names its project through [nameForProjectId] — the search
/// field's live `projectChipNames` map, archived and deleted included — and
/// a project the cache has never held is fetched once
/// ([RecordChipNameHydrator]), as a `client:` chip's client is.
class ProjectFilterKey extends MembershipFilterKey {
  ProjectFilterKey({
    required this.projects,
    required this.companyId,
    this.nameForProjectId,
  });

  final ProjectRepository projects;
  final String companyId;

  /// Synchronous `project_id → name` lookup from the search field's name
  /// streams — see `ClientFilterKey.nameForClientId`.
  final String? Function(String id)? nameForProjectId;

  late final RecordChipNameHydrator _names = RecordChipNameHydrator(
    (id) => projects.ensureLoaded(companyId: companyId, id: id),
  );

  @override
  String get id => 'project';

  @override
  bool get acceptsTypedValue => false;

  @override
  int? get idleSuggestionCap => 50;

  @override
  String get serverKey => 'project_tasks';

  /// Server `project_tasks` accepts a single project — selecting one
  /// replaces the prior selection (no multi-union).
  @override
  bool get singleValue => true;

  @override
  Future<void> addValue(GenericListViewModel<dynamic> vm, String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return Future.value();
    return writeSingleExtraFilter(vm, serverKey, trimmed);
  }

  @override
  String displayLabel(BuildContext context) => context.tr('project');

  @override
  String displayValueFor(String rawValue) =>
      _names.resolve(rawValue, nameForProjectId);

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final idle = query.trim().isEmpty;
    return namesWithServerSearch(
      names: projects.watchActiveNames(companyId: companyId),
      query: query,
      fetch: (q) =>
          projects.ensurePageLoaded(companyId: companyId, page: 1, search: q),
      searchedIds: (q) => projects
          .watchPage(companyId: companyId, search: q)
          .map((rows) => [for (final p in rows) p.id]),
    ).map(
      (rows) => [
        for (final p in idle ? rows.take(idleSuggestionCap!) : rows)
          FilterValueSuggestion(
            rawValue: p.id,
            displayLabel: p.name.isEmpty ? p.id : p.name,
          ),
      ],
    );
  }
}
