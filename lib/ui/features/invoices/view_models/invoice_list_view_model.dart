import 'package:admin/data/db/dao/invoice_dao.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/invoice_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_sheet.dart';

/// List ViewModel for the Invoices screen. Mirrors `ExpenseListViewModel` —
/// pagination / search / sort / multiselect / columns all live on the
/// generic base. M2+ extends `bulkActions` with mark_sent, mark_paid,
/// auto_bill, email, schedule_email, and run_template.
class InvoiceListViewModel extends GenericListViewModel<Invoice> {
  InvoiceListViewModel({
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

  final InvoiceRepository repo;

  /// When non-null, scopes the watch + fetch to one client. Used by the
  /// embedded list inside `ClientDetailScreen`'s Invoices tab.
  final String? clientId;

  /// When non-null, scopes the watch + fetch to one project. Used by the
  /// embedded list inside `ProjectDetailScreen`'s Invoices tab.
  final String? projectId;

  @override
  Set<String> get lockedFilterKeyIds => {
    if (clientId != null) 'client',
    if (projectId != null) 'project',
  };

  @override
  EntityType get entityType => EntityType.invoice;

  @override
  List<ColumnDefinition<Invoice>> get allColumns => kAllInvoiceColumns;

  @override
  List<String> get defaultColumnIds => kDefaultInvoiceColumns;

  /// Default sort is by invoice number descending (see
  /// [defaultSortAscending]) — matches admin-portal's "newest invoice first"
  /// convention.
  @override
  String get defaultSortField => InvoiceFieldIds.number;

  /// Newest first: invoice number ascending would bury every new record at the
  /// bottom of the list, off the first page.
  @override
  bool get defaultSortAscending => false;

  /// Must match the repo's page size — the Drift watch window is
  /// `pageSize * loadedPages` (see `GenericListViewModel.pageSize`).
  @override
  int get pageSize => repo.pageSize;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(invoiceColumnsById, field) ||
      field == InvoiceFieldIds.updatedAt;

  @override
  String idOf(Invoice item) => item.id;

  @override
  bool isArchived(Invoice item) => item.archivedAt != null;

  @override
  bool isDeleted(Invoice item) => item.isDeleted;

  @override
  Stream<List<Invoice>> watchPage() => repo.watchPage(
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
    // Embedded mode: thread the client scope through to the server via the
    // standard `extraFilters` plumbing so pagination cursors stay aligned
    // with the on-screen rows.
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

  @override
  Future<void> refreshAll() => repo.refreshAll(companyId: companyId);

  @override
  Iterable<BulkAction<Invoice>> get bulkActions => [
    ...standardCrudBulkActions(
      isArchived: isArchived,
      isDeleted: isDeleted,
      archive: (id) => repo.archive(companyId: companyId, id: id),
      restore: (id) => repo.restore(companyId: companyId, id: id),
      delete: (id) => repo.delete(companyId: companyId, id: id),
    ),
    BulkAction<Invoice>(
      id: 'mark_sent',
      labelKey: 'mark_sent',
      eligible: (i) => i.isDraft && !i.isDeleted,
      apply: (id) => repo.markSent(companyId: companyId, id: id),
    ),
    BulkAction<Invoice>(
      id: 'mark_paid',
      labelKey: 'mark_paid',
      eligible: (i) =>
          !i.isPaid && !i.isCancelled && !i.isReversed && !i.isDeleted,
      apply: (id) => repo.markPaid(companyId: companyId, id: id),
    ),
    BulkAction<Invoice>(
      id: 'auto_bill',
      labelKey: 'auto_bill',
      eligible: (i) => i.isSent && !i.isPaid && !i.isDeleted,
      apply: (id) => repo.autoBill(companyId: companyId, id: id),
    ),
    BulkAction<Invoice>(
      id: 'email',
      labelKey: 'email',
      eligible: (i) => !i.isDeleted,
      // `arg` is the BillingEmailResult from the compose sheet (prepare).
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
    BulkAction<Invoice>(
      id: 'run_template',
      labelKey: 'run_template',
      eligible: (i) => !i.isDeleted,
      // `arg` is the chosen design id from showRunTemplateDialog (prepare).
      applyArg: (id, arg) => repo.runTemplate(
        companyId: companyId,
        id: id,
        templateId: arg as String,
      ),
    ),
    // Selection-level PDF actions — the list screen's onSelection does the real
    // work (server-merged print / async zip+email download). `eligible` drives
    // the empty-selection guard + the count handed to the handler.
    BulkAction<Invoice>(
      id: 'download_pdf',
      labelKey: 'download_pdf',
      eligible: (i) => !i.isDeleted && !i.id.startsWith('tmp_'),
      apply: (_) async {},
    ),
    BulkAction<Invoice>(
      id: 'print_pdf',
      labelKey: 'print_pdf',
      eligible: (i) => !i.isDeleted && !i.id.startsWith('tmp_'),
      apply: (_) async {},
    ),
  ];
}
