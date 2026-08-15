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
import 'package:admin/ui/core/list/search/client_filter_key.dart';
import 'package:admin/ui/core/list/search/custom_field_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_keys_common.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/membership_filter_key.dart';
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
  ProjectFilterKey(projects: projects, companyId: companyId),
  StatusFilterKey(statuses: statuses, companyId: companyId),
  TagFilterKey(tags: tags, companyId: companyId, entityType: 'task'),
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
    // of the raw hashid (mirrors [ProjectFilterKey]). Reuses the same stream
    // that backs the suggestion dropdown — task statuses are few, so watching
    // the full list is cheap.
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
          ? all.take(50)
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
/// cheap `(id, name)` projection from
/// `ProjectRepository.watchActiveNames` (no full row materialization).
/// The same stream populates an in-memory `id → name` cache so chip
/// text shows the project name instead of the raw id.
///
/// Caveat: chips render synchronously; the very first paint after picking
/// a project may show the raw id until the names stream produces its next
/// event. Reactive chip updates would require the chip widget itself to
/// subscribe — out of scope.
class ProjectFilterKey extends MembershipFilterKey {
  ProjectFilterKey({required this.projects, required this.companyId}) {
    _namesSub = projects.watchActiveNames(companyId: companyId).listen((rows) {
      _names
        ..clear()
        ..addEntries(rows.map((r) => MapEntry(r.id, r.name)));
    });
  }

  final ProjectRepository projects;
  final String companyId;
  final Map<String, String> _names = <String, String>{};
  StreamSubscription<List<({String id, String name})>>? _namesSub;

  @override
  String get id => 'project';

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
    return projects.watchActiveNames(companyId: companyId).map((all) {
      final filtered = q.isEmpty
          ? all.take(50)
          : all.where((p) => p.name.toLowerCase().contains(q));
      return [
        for (final p in filtered)
          FilterValueSuggestion(
            rawValue: p.id,
            displayLabel: p.name.isEmpty ? p.id : p.name,
          ),
      ];
    });
  }

  /// Release the names-cache subscription when the filter key is replaced
  /// (e.g. on company switch) or its hosting field unmounts.
  @override
  void dispose() {
    _namesSub?.cancel();
    _namesSub = null;
  }
}
