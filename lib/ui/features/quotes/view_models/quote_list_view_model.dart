import 'package:admin/data/db/dao/quote_dao.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/quote_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_sheet.dart';

class QuoteListViewModel extends GenericListViewModel<Quote> {
  QuoteListViewModel({
    required this.repo,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
    this.clientId,
    this.projectId,
  });

  final QuoteRepository repo;

  /// When non-null, scopes the watch + fetch to one client. Used by the
  /// embedded list inside `ClientDetailScreen`'s Quotes tab.
  final String? clientId;

  /// When non-null, scopes the watch + fetch to one project. Used by the
  /// embedded list inside `ProjectDetailScreen`'s Quotes tab.
  final String? projectId;

  @override
  Set<String> get lockedFilterKeyIds => {
    if (clientId != null) 'client',
    if (projectId != null) 'project',
  };

  @override
  EntityType get entityType => EntityType.quote;

  @override
  List<ColumnDefinition<Quote>> get allColumns => kAllQuoteColumns;

  @override
  List<String> get defaultColumnIds => kDefaultQuoteColumns;

  @override
  String get defaultSortField => QuoteFieldIds.number;

  /// Newest first: quote number ascending would bury every new record at the
  /// bottom of the list, off the first page.
  @override
  bool get defaultSortAscending => false;

  /// Must match the repo's page size — the Drift watch window is
  /// `pageSize * loadedPages` (see `GenericListViewModel.pageSize`).
  @override
  int get pageSize => repo.pageSize;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(quoteColumnsById, field) ||
      field == QuoteFieldIds.updatedAt;

  @override
  String idOf(Quote item) => item.id;

  @override
  bool isArchived(Quote item) => item.archivedAt != null;

  @override
  bool isDeleted(Quote item) => item.isDeleted;

  @override
  Stream<List<Quote>> watchPage() => repo.watchPage(
    badgeModeId: activeBadgeModeId,
    companyId: companyId,
    loadedPages: loadedPages,
    search: search.isEmpty ? null : search,
    states: states,
    sortField: sortField,
    sortAscending: sortAscending,
    clientId: clientId,
    projectId: projectId,
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
    final base = extraFilters;
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

  /// Quotes is the one project-scoped embedded list with no server filter to
  /// send: `QuoteFilters.php` has no project method (Invoices, Expenses and
  /// Tasks all do, and use it). Project scope therefore narrows only the DAO
  /// predicate, so a page the predicate guts down must auto-chain the next one
  /// — otherwise a project's Quotes tab dead-ends on a false "No records
  /// found" whenever the project's quotes aren't among the newest page
  /// company-wide.
  @override
  bool get localOnlyFilterActive =>
      super.localOnlyFilterActive || projectId != null;

  @override
  Future<void> refreshAll() => repo.refreshAll(companyId: companyId);

  @override
  Iterable<BulkAction<Quote>> get bulkActions => [
    ...standardCrudBulkActions(
      isArchived: isArchived,
      isDeleted: isDeleted,
      archive: (id) => repo.archive(companyId: companyId, id: id),
      restore: (id) => repo.restore(companyId: companyId, id: id),
      delete: (id) => repo.delete(companyId: companyId, id: id),
    ),
    BulkAction<Quote>(
      // Outward-facing and hard to reverse over a whole selection — the
      // single-record twin already prompts. `_onBulk` shows one dialog when
      // this is set, gated on the device Confirm-actions preference.
      confirm: true,
      id: 'mark_sent',
      labelKey: 'mark_sent',
      eligible: (q) => q.isDraft && !isDeleted(q),
      apply: (id) => repo.markSent(companyId: companyId, id: id),
    ),
    BulkAction<Quote>(
      // Outward-facing and hard to reverse over a whole selection — the
      // single-record twin already prompts. `_onBulk` shows one dialog when
      // this is set, gated on the device Confirm-actions preference.
      confirm: true,
      id: 'approve',
      labelKey: 'approve',
      // Draft or sent only — never approved/converted/rejected (matches
      // the detail screen + React). See quote_actions.dart canApprove.
      eligible: (q) => (q.isDraft || q.isSent) && !isDeleted(q),
      apply: (id) => repo.approve(companyId: companyId, id: id),
    ),
    BulkAction<Quote>(
      // Outward-facing and hard to reverse over a whole selection — the
      // single-record twin already prompts. `_onBulk` shows one dialog when
      // this is set, gated on the device Confirm-actions preference.
      confirm: true,
      id: 'convert_to_invoice',
      labelKey: 'convert_to_invoice',
      eligible: (q) => !q.isConverted && !isDeleted(q),
      apply: (id) => repo.convertToInvoice(companyId: companyId, id: id),
    ),
    BulkAction<Quote>(
      id: 'email',
      labelKey: 'email',
      eligible: (q) => !isDeleted(q),
      applyArg: (id, arg) {
        final r = arg as BillingEmailResult;
        final scheduledFor = r.scheduledFor;
        if (scheduledFor != null) {
          return repo.scheduleEmail(
            companyId: companyId,
            id: id,
            template: r.template,
            // LOCAL, never `.toUtc()`. The server truncates `sendAt` to a
            // date-only `next_run`, so converting shifts an evening pick to
            // the next calendar day east of UTC and to the previous one west
            // of it — firing a day late, or immediately because the date is
            // already past. `billing_doc_email_screen.dart` fixed exactly this
            // for the single-document composer and spells out the reason; the
            // four bulk call sites never got it.
            sendAt: scheduledFor.toIso8601String(),
            subject: r.subject.isEmpty ? null : r.subject,
            body: r.body.isEmpty ? null : r.body,
            // Forwarded on the `email` branch below but silently dropped here,
            // so a CC typed into the bulk compose sheet never reached anyone.
            ccEmail: r.ccEmail.isEmpty ? null : r.ccEmail,
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
    BulkAction<Quote>(
      id: 'run_template',
      labelKey: 'run_template',
      eligible: (q) => !isDeleted(q),
      applyArg: (id, arg) => repo.runTemplate(
        companyId: companyId,
        id: id,
        templateId: arg as String,
      ),
    ),
    // Selection-level PDF actions — the list screen's onSelection does the real
    // work (server-merged print / async zip+email download). `eligible` drives
    // the empty-selection guard + the count handed to the handler.
    BulkAction<Quote>(
      id: 'download_pdf',
      labelKey: 'download_pdf',
      eligible: (q) => !isDeleted(q) && !q.id.startsWith('tmp_'),
      apply: (_) async {},
    ),
    BulkAction<Quote>(
      id: 'print_pdf',
      labelKey: 'print_pdf',
      eligible: (q) => !isDeleted(q) && !q.id.startsWith('tmp_'),
      apply: (_) async {},
    ),
  ];
}
