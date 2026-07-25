import 'package:admin/data/db/dao/credit_dao.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/credit_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_sheet.dart';

class CreditListViewModel extends GenericListViewModel<Credit> {
  CreditListViewModel({
    required this.repo,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
    this.clientId,
  });

  final CreditRepository repo;

  /// When non-null, scopes the watch + fetch to one client.
  final String? clientId;

  @override
  Set<String> get lockedFilterKeyIds => {if (clientId != null) 'client'};

  @override
  EntityType get entityType => EntityType.credit;

  @override
  List<ColumnDefinition<Credit>> get allColumns => kAllCreditColumns;

  @override
  List<String> get defaultColumnIds => kDefaultCreditColumns;

  @override
  String get defaultSortField => CreditFieldIds.number;

  @override
  bool isValidColumnId(String field) =>
      creditColumnsById.containsKey(field) || field == CreditFieldIds.updatedAt;

  @override
  String idOf(Credit item) => item.id;

  @override
  bool isArchived(Credit item) => item.archivedAt != null;

  @override
  bool isDeleted(Credit item) => item.isDeleted;

  /// `tag_ids` is applied post-decode over the loaded window (repo.watchPage),
  /// so a short filtered result must auto-chain page fetches (see the base).
  @override
  bool get localOnlyFilterActive =>
      (extraFilters['tag_ids'] ?? const <String>{}).isNotEmpty;

  @override
  Stream<List<Credit>> watchPage() => repo.watchPage(
    companyId: companyId,
    loadedPages: loadedPages,
    search: search.isEmpty ? null : search,
    states: states,
    sortField: sortField,
    sortAscending: sortAscending,
    clientId: clientId,
    customFilters: customFilters,
    extraFilters: extraFilters,
  );

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) {
    // `tag_ids` is applied locally (post-decode in repo.watchPage) — strip it.
    final base = GenericListViewModel.extraFiltersWithout(
      extraFilters,
      'tag_ids',
    );
    final filters = clientId == null
        ? base
        : {
            ...base,
            'client_id': {clientId!},
          };
    return repo.ensurePageLoaded(
      companyId: companyId,
      page: page,
      search: search,
      states: states,
      extraFilters: filters,
      ignoreCursor: ignoreCursor,
    );
  }

  @override
  Future<void> refreshAll() => repo.refreshAll(companyId: companyId);

  @override
  Iterable<BulkAction<Credit>> get bulkActions => [
    ...standardCrudBulkActions(
      isArchived: isArchived,
      isDeleted: isDeleted,
      archive: (id) => repo.archive(companyId: companyId, id: id),
      restore: (id) => repo.restore(companyId: companyId, id: id),
      delete: (id) => repo.delete(companyId: companyId, id: id),
    ),
    BulkAction<Credit>(
      id: 'mark_sent',
      labelKey: 'mark_sent',
      eligible: (c) => c.isDraft && !isDeleted(c),
      apply: (id) => repo.markSent(companyId: companyId, id: id),
    ),
    BulkAction<Credit>(
      id: 'email',
      labelKey: 'email',
      eligible: (c) => !isDeleted(c),
      applyArg: (id, arg) {
        final r = arg as BillingEmailResult;
        final scheduledFor = r.scheduledFor;
        if (scheduledFor != null) {
          return repo.scheduleEmail(
            companyId: companyId,
            id: id,
            template: r.template,
            sendAt: scheduledFor.toUtc().toIso8601String(),
            subject: r.subject.isEmpty ? null : r.subject,
            body: r.body.isEmpty ? null : r.body,
          );
        }
        return repo.email(
          companyId: companyId,
          id: id,
          template: r.template,
          subject: r.subject.isEmpty ? null : r.subject,
          body: r.body.isEmpty ? null : r.body,
          ccEmail: r.ccEmail.isEmpty ? null : r.ccEmail,
        );
      },
    ),
    BulkAction<Credit>(
      id: 'run_template',
      labelKey: 'run_template',
      eligible: (c) => !isDeleted(c),
      applyArg: (id, arg) => repo.runTemplate(
        companyId: companyId,
        id: id,
        templateId: arg as String,
      ),
    ),
    // Selection-level PDF actions — the list screen's onSelection does the real
    // work (server-merged print / async zip+email download). `eligible` drives
    // the empty-selection guard + the count handed to the handler.
    BulkAction<Credit>(
      id: 'download_pdf',
      labelKey: 'download_pdf',
      eligible: (c) => !isDeleted(c) && !c.id.startsWith('tmp_'),
      apply: (_) async {},
    ),
    BulkAction<Credit>(
      id: 'print_pdf',
      labelKey: 'print_pdf',
      eligible: (c) => !isDeleted(c) && !c.id.startsWith('tmp_'),
      apply: (_) async {},
    ),
  ];
}
