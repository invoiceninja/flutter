import 'package:admin/data/db/dao/bank_transaction_dao.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/data/repositories/bank_transaction_repository.dart';
import 'package:admin/data/repositories/tag_denormalization.dart';
import 'package:admin/domain/columns/bank_transaction_columns.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

/// List ViewModel for the workspace `/transactions` screen and the embedded
/// transactions list inside `BankAccountDetailScreen`.
///
/// The optional [bankAccountId] gates the watch+fetch to a single bank
/// integration — set when this VM drives the embedded list (the standalone
/// screen leaves it null and shows transactions across all integrations).
class TransactionListViewModel extends GenericListViewModel<BankTransaction> {
  TransactionListViewModel({
    required this.repo,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
    this.bankAccountId,
  });

  final BankTransactionRepository repo;

  /// When non-null, scopes the watch + fetch to one bank integration's
  /// transactions. Used by `BankAccountDetailScreen`'s embedded list.
  final String? bankAccountId;

  // Embedded (bank-account-scoped) list: lock a filter dimension so the base
  // `GenericListViewModel.isEmbedded` is true and this list neither reads nor
  // writes the standalone `/transactions` nav_state slot. Bank scope isn't a
  // user-facing filter chip (it's threaded via `bank_integration_ids`), so
  // there's nothing to actually suppress — this is purely the embedded signal.
  // Empty when standalone (`bankAccountId == null`), so the main list persists
  // its filters normally.
  @override
  Set<String> get lockedFilterKeyIds => {
    if (bankAccountId != null) 'bank_account',
  };

  @override
  EntityType get entityType => EntityType.transaction;

  @override
  List<ColumnDefinition<BankTransaction>> get allColumns =>
      kAllBankTransactionColumns;

  @override
  List<String> get defaultColumnIds => kDefaultBankTransactionColumns;

  /// Default sort: most recent transactions first. Bank feeds drop in
  /// chronologically and users overwhelmingly look at the latest rows.
  @override
  String get defaultSortField => BankTransactionFieldIds.date;

  /// Newest first: date ascending would bury every new record at the
  /// bottom of the list, off the first page.
  @override
  bool get defaultSortAscending => false;

  /// Must match the repo's page size — the Drift watch window is
  /// `pageSize * loadedPages` (see `GenericListViewModel.pageSize`).
  @override
  int get pageSize => repo.pageSize;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(bankTransactionColumnsById, field) ||
      field == BankTransactionFieldIds.updatedAt ||
      field == BankTransactionFieldIds.amount;

  @override
  String idOf(BankTransaction item) => item.id;

  @override
  bool isArchived(BankTransaction item) => item.archivedAt != null;

  @override
  bool isDeleted(BankTransaction item) => item.isDeleted;

  @override
  Stream<List<BankTransaction>> watchPage() {
    // Mirror the status + type chips into the local Drift query. The server
    // fetch only narrows which rows are paged in; the watch re-emits the whole
    // company cache otherwise, so the chips would look like they do nothing
    // (the same gap billing_extra_filters.dart closes for the billing lists).
    // Slot names match the FilterKey serverKeys in transaction_filter_keys.dart.
    final baseTypes = extraFilters['base_type'];
    // Date filter mirror: the `between` window (`date_range` slot) and the
    // single-date comparator (`date` slot). The transactions `date` filter is
    // not backed server-side (no `date()` handler), so the local mirror is what
    // makes it work; the range also narrows the server fetch via `date_range`.
    final dateRange = parseDateRangeFilter(extraFilters);
    final dateCmp = parseComparableDateFilter(extraFilters, 'date');
    return repo
        .watchPage(
          companyId: companyId,
          loadedPages: loadedPages,
          search: search.isEmpty ? null : search,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
          bankAccountId: bankAccountId,
          statusIds: extraFilters['status_id'],
          baseType: (baseTypes == null || baseTypes.isEmpty)
              ? null
              : baseTypes.first,
          dateStart: dateRange.start,
          dateEnd: dateRange.end,
          dateOp: dateCmp.op,
          dateValue: dateCmp.value,
        )
        .map((items) {
          // `tag_ids` lives only in the payload — post-decode predicate.
          final tagIds = extraFilters['tag_ids'] ?? const <String>{};
          if (tagIds.isEmpty) return items;
          return items
              .where((t) => matchesTagIdFilter(t.tagIds, tagIds))
              .toList(growable: false);
        });
  }

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) {
    // Translate the status + type chips onto the server's single `client_status`
    // keyword param. `BankTransactionFilters` has no `status_id` / `base_type`
    // handler, and `QueryFilters::apply` silently skips params with no matching
    // method — so without this the server-side narrowing is a no-op.
    final filters = _toServerFilters(extraFilters);
    if (bankAccountId != null) {
      // Server filter is `bank_integration_ids` (plural) — see
      // `BankTransactionFilters::bank_integration_ids`, which decodes the comma
      // list via `transformKeys`. The singular form is silently ignored, so a
      // single id still goes through the plural key.
      filters['bank_integration_ids'] = {bankAccountId!};
    }
    return repo.ensurePageLoaded(
      companyId: companyId,
      page: page,
      search: search,
      states: states,
      extraFilters: filters,
      ignoreCursor: ignoreCursor,
    );
  }

  /// Map the local `status_id` (`1`/`2`/`3`) and `base_type` (`CREDIT`/`DEBIT`)
  /// filter slots onto the server's combined `client_status` keyword param
  /// (`unmatched`/`matched`/`converted` + `deposits`/`withdrawals`). The server
  /// ANDs the status and base-type `whereIn` groups in one closure
  /// (`BankTransactionFilters::client_status`), matching the local DAO's AND.
  /// Returns a fresh, deep-copied map with the raw (unhandled) slots removed so
  /// the VM's stored filter sets are never mutated.
  Map<String, Set<String>> _toServerFilters(
    Map<String, Set<String>> extraFilters,
  ) {
    final out = {
      for (final e in extraFilters.entries) e.key: {...e.value},
    };
    final clientStatus = <String>{};
    for (final s in out.remove('status_id') ?? const <String>{}) {
      final keyword = _statusKeyword(s);
      if (keyword != null) clientStatus.add(keyword);
    }
    for (final b in out.remove('base_type') ?? const <String>{}) {
      final keyword = _baseTypeKeyword(b);
      if (keyword != null) clientStatus.add(keyword);
    }
    if (clientStatus.isNotEmpty) out['client_status'] = clientStatus;
    // The single-date `date` comparator has no server handler (only `date_range`
    // is honored); it's applied locally via the watchPage mirror. Drop it so we
    // don't send a param the server silently ignores. `date_range` stays.
    out.remove('date');
    return out;
  }

  static String? _statusKeyword(String statusId) {
    if (statusId == kTransactionStatusUnmatched) return 'unmatched';
    if (statusId == kTransactionStatusMatched) return 'matched';
    if (statusId == kTransactionStatusConverted) return 'converted';
    return null;
  }

  static String? _baseTypeKeyword(String baseType) {
    if (baseType == kTransactionTypeCredit) return 'deposits';
    if (baseType == kTransactionTypeDebit) return 'withdrawals';
    return null;
  }

  @override
  Future<void> refreshAll() => repo.refreshAll(companyId: companyId);

  /// Standard CRUD trio + the unlink bulk action. Convert is row-level
  /// only (it creates server-side payments / expenses; we always show a
  /// confirmation dialog via `TransactionActions._confirmConvert`).
  /// Unlink is eligible for Matched + Converted rows because it's the
  /// recovery path on either side.
  @override
  Iterable<BulkAction<BankTransaction>> get bulkActions => [
    ...standardCrudBulkActions(
      isArchived: isArchived,
      isDeleted: isDeleted,
      archive: (id) => repo.archive(companyId: companyId, id: id),
      restore: (id) => repo.restore(companyId: companyId, id: id),
      delete: (id) => repo.delete(companyId: companyId, id: id),
    ),
    BulkAction<BankTransaction>(
      id: 'unlink',
      labelKey: 'unlink',
      eligible: (t) => t.isMatched || t.isConverted,
      apply: (id) =>
          repo.unlinkTransactions(companyId: companyId, transactionIds: [id]),
    ),
  ];
}
