import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';
import 'package:admin/data/db/dao/_payload_search.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/recurring_expenses_table.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/recurring_expense_status.dart';

part 'recurring_expense_dao.g.dart';

/// Stable field-id constants used by the list ViewModel for column +
/// sort selection. Keep in sync with `RecurringExpenseRepository.watchPage`.
class RecurringExpenseFieldIds {
  static const String number = 'number';
  static const String date = 'date';
  static const String paymentDate = 'payment_date';
  static const String amount = 'amount';
  static const String vendorId = 'vendor_id';
  static const String clientId = 'client_id';
  static const String projectId = 'project_id';
  static const String categoryId = 'category_id';
  static const String invoiceId = 'invoice_id';
  static const String currencyId = 'currency_id';
  static const String status = 'status';
  static const String frequency = 'frequency';
  static const String nextSendDate = 'next_send_date';
  static const String lastSentDate = 'last_sent_date';
  static const String remainingCycles = 'remaining_cycles';
  static const String publicNotes = 'public_notes';
  static const String privateNotes = 'private_notes';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
  static const String customValue1 = 'custom_value1';
  static const String customValue2 = 'custom_value2';
  static const String customValue3 = 'custom_value3';
  static const String customValue4 = 'custom_value4';
  // Display-only (tags live in the payload) — never add to sortOptions.
  static const String tagIds = 'recurring_expense_tag_ids';
}

@DriftAccessor(tables: [RecurringExpenses])
class RecurringExpenseDao
    extends BaseEntityDao<$RecurringExpensesTable, RecurringExpenseRow>
    with _$RecurringExpenseDaoMixin {
  RecurringExpenseDao(super.db);

  @override
  $RecurringExpensesTable get table => recurringExpenses;
  @override
  GeneratedColumn<String> get idColumn => recurringExpenses.id;
  @override
  GeneratedColumn<String> get companyIdColumn => recurringExpenses.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => recurringExpenses.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => recurringExpenses.isDirty;

  @override
  GeneratedColumn<int>? get archivedAtColumn => recurringExpenses.archivedAt;

  /// Windowed list watch. Filter by state + free-text search + status chip
  /// (the 5 [kRecurringExpenseStatus*] values, or `null` for "all"). The
  /// status SQL fragments mirror admin-portal `expense_model.dart:817-854`
  /// — no computed column, just a tiny SQL switch.
  Stream<List<RecurringExpenseRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    String? recurringStatus,
    Set<EntityState> states = const {EntityState.active},
    String sortField = RecurringExpenseFieldIds.nextSendDate,
    bool sortAscending = false,
    String? vendorId,
    Set<String> customValues1 = const {},
    Set<String> customValues2 = const {},
    Set<String> customValues3 = const {},
    Set<String> customValues4 = const {},
    String? badgeModeId,
  }) {
    final q = select(recurringExpenses)
      ..where((e) => e.companyId.equals(companyId));
    // Status-tab strip (#98): the SAME predicate the tab's count uses, so
    // the number above the list and the rows in it can't disagree. Applied
    // here (pre-LIMIT) rather than post-decode, so the Drift window stays
    // aligned with the page count.
    final badgeFilter = badgeModeListFilter(badgeModeId, companyId: companyId);
    if (badgeFilter != null) q.where((_) => badgeFilter);

    if (vendorId != null && vendorId.isNotEmpty) {
      q.where((e) => e.vendorId.equals(vendorId));
    }
    // Custom-field filters mirror server `custom_value1..4` (exact-set local
    // predicate is source of truth — same idiom as ClientDao/InvoiceDao).
    if (customValues1.isNotEmpty) {
      q.where((e) => e.customValue1.isIn(customValues1.toList()));
    }
    if (customValues2.isNotEmpty) {
      q.where((e) => e.customValue2.isIn(customValues2.toList()));
    }
    if (customValues3.isNotEmpty) {
      q.where((e) => e.customValue3.isIn(customValues3.toList()));
    }
    if (customValues4.isNotEmpty) {
      q.where((e) => e.customValue4.isIn(customValues4.toList()));
    }

    if (states.isNotEmpty) {
      q.where(
        (e) => entityStateFilter(
          states: states,
          archivedAt: e.archivedAt,
          isDeleted: e.isDeleted,
        ),
      );
    }

    if (recurringStatus != null) {
      q.where((e) => _statusChipFilter(e, recurringStatus));
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where(
        (e) =>
            e.number.lower().like(needle) |
            e.transactionReferenceLikePayload(needle) |
            e.customValue1.lower().like(needle) |
            e.customValue2.lower().like(needle) |
            e.customValue3.lower().like(needle) |
            e.customValue4.lower().like(needle) |
            vendorNameMatchesFilter(
              vendorId: e.vendorId,
              companyId: companyId,
              needle: needle,
            ) |
            categoryNameMatchesFilter(
              categoryId: e.categoryId,
              companyId: companyId,
              needle: needle,
            ),
      );
    }

    q.orderBy([
      (e) => OrderingTerm(
        expression: _sortExpression(e, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (e) => OrderingTerm(expression: e.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  /// Cheap count for the per-status chip badges. Same WHERE shape as
  /// [watchPage] minus pagination + sort + search.
  Stream<int> watchCountForStatus({
    required String companyId,
    String? recurringStatus,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final countExp = recurringExpenses.id.count();
    final q = selectOnly(recurringExpenses)
      ..addColumns([countExp])
      ..where(recurringExpenses.companyId.equals(companyId));
    if (states.isNotEmpty) {
      q.where(
        entityStateFilter(
          states: states,
          archivedAt: recurringExpenses.archivedAt,
          isDeleted: recurringExpenses.isDeleted,
        ),
      );
    }
    if (recurringStatus != null) {
      q.where(_statusChipFilter(recurringExpenses, recurringStatus));
    }
    return q.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  @override
  Expression<bool>? badgeModePredicate(
    String modeId, {
    required String companyId,
    required String currentUserId,
  }) => switch (modeId) {
    // The chip filter already models the whole computed-status cascade
    // (including "exhausted rows display as Completed"), so reuse it verbatim
    // rather than re-deriving a second, subtly-different version here. It
    // keys on the wire id, not the label, hence the hop through the map.
    'pending' => _statusChipFilter(
      recurringExpenses,
      kRecurringExpenseStatusPending,
    ),
    'active' => _statusChipFilter(
      recurringExpenses,
      kRecurringExpenseStatusActive,
    ),
    'paused' => _statusChipFilter(
      recurringExpenses,
      kRecurringExpenseStatusPaused,
    ),
    'draft' => _statusChipFilter(
      recurringExpenses,
      kRecurringExpenseStatusDraft,
    ),
    _ => null,
  };

  Expression<bool> _statusChipFilter(
    RecurringExpenses e,
    String recurringStatus,
  ) {
    switch (recurringStatus) {
      // `remaining_cycles == 0` takes precedence in
      // `RecurringExpenseStatus.calculatedStatusId`, so such a row DISPLAYS as
      // Completed no matter what `status_id` says. Every chip must therefore
      // exclude exhausted rows or it matches rows labelled with a different
      // status (and inflates the chip's count badge).
      case kRecurringExpenseStatusDraft:
        return e.statusId.equals(kRecurringExpenseStatusDraft) &
            e.remainingCycles.equals(0).not();
      case kRecurringExpenseStatusActive:
        return e.statusId.equals(kRecurringExpenseStatusActive) &
            e.remainingCycles.equals(0).not() &
            e.lastSentDate.isNotNull() &
            e.lastSentDate.equals('').not();
      case kRecurringExpenseStatusPaused:
        return e.statusId.equals(kRecurringExpenseStatusPaused) &
            e.remainingCycles.equals(0).not();
      case kRecurringExpenseStatusCompleted:
        return e.statusId.equals(kRecurringExpenseStatusCompleted) |
            e.remainingCycles.equals(0);
      case kRecurringExpenseStatusPending:
        return e.statusId.equals(kRecurringExpenseStatusActive) &
            e.remainingCycles.equals(0).not() &
            (e.lastSentDate.isNull() | e.lastSentDate.equals(''));
      default:
        // Unknown — treat as "no filter" so a stray value doesn't blank
        // the list.
        return const Constant(true);
    }
  }

  Expression _sortExpression(RecurringExpenses e, String field) {
    switch (field) {
      case RecurringExpenseFieldIds.number:
        return e.number.lower();
      case RecurringExpenseFieldIds.date:
        return e.date;
      case RecurringExpenseFieldIds.paymentDate:
        return e.paymentDate;
      case RecurringExpenseFieldIds.nextSendDate:
        return e.nextSendDate;
      case RecurringExpenseFieldIds.lastSentDate:
        return e.lastSentDate;
      case RecurringExpenseFieldIds.amount:
        return e.amount.cast<double>();
      case RecurringExpenseFieldIds.vendorId:
        return e.vendorId;
      case RecurringExpenseFieldIds.clientId:
        return e.clientId;
      case RecurringExpenseFieldIds.projectId:
        return e.projectId;
      case RecurringExpenseFieldIds.categoryId:
        return e.categoryId;
      case RecurringExpenseFieldIds.invoiceId:
        return e.invoiceId;
      case RecurringExpenseFieldIds.currencyId:
        return e.currencyId;
      case RecurringExpenseFieldIds.frequency:
        return e.frequencyId;
      case RecurringExpenseFieldIds.remainingCycles:
        return e.remainingCycles;
      case RecurringExpenseFieldIds.createdAt:
        return e.createdAt;
      case RecurringExpenseFieldIds.updatedAt:
        return e.updatedAt;
      case RecurringExpenseFieldIds.customValue1:
        return e.customValue1.lower();
      case RecurringExpenseFieldIds.customValue2:
        return e.customValue2.lower();
      case RecurringExpenseFieldIds.customValue3:
        return e.customValue3.lower();
      case RecurringExpenseFieldIds.customValue4:
        return e.customValue4.lower();
      default:
        // Silent fallback masks the real failure (user clicks a column
        // header → list re-orders by next-send-date with no error).
        // Mirrors `ExpenseDao._sortExpression`.
        throw ArgumentError(
          'Unknown sort field "$field" for RecurringExpense — add a case '
          'in _sortExpression or stop exposing it as a sort option.',
        );
    }
  }

  // ── Cross-entity navigation streams ───────────────────────────────────

  Stream<List<RecurringExpenseRow>> watchForVendor({
    required String companyId,
    required String vendorId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(recurringExpenses)
      ..where(
        (e) => e.companyId.equals(companyId) & e.vendorId.equals(vendorId),
      );
    if (states.isNotEmpty) {
      q.where(
        (e) => entityStateFilter(
          states: states,
          archivedAt: e.archivedAt,
          isDeleted: e.isDeleted,
        ),
      );
    }
    q.orderBy([
      (e) => OrderingTerm(expression: e.nextSendDate, mode: OrderingMode.desc),
    ]);
    return q.watch().distinctRows();
  }

  Stream<List<RecurringExpenseRow>> watchForClient({
    required String companyId,
    required String clientId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(recurringExpenses)
      ..where(
        (e) => e.companyId.equals(companyId) & e.clientId.equals(clientId),
      );
    if (states.isNotEmpty) {
      q.where(
        (e) => entityStateFilter(
          states: states,
          archivedAt: e.archivedAt,
          isDeleted: e.isDeleted,
        ),
      );
    }
    q.orderBy([
      (e) => OrderingTerm(expression: e.nextSendDate, mode: OrderingMode.desc),
    ]);
    return q.watch().distinctRows();
  }

  Stream<List<RecurringExpenseRow>> watchForProject({
    required String companyId,
    required String projectId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(recurringExpenses)
      ..where(
        (e) => e.companyId.equals(companyId) & e.projectId.equals(projectId),
      );
    if (states.isNotEmpty) {
      q.where(
        (e) => entityStateFilter(
          states: states,
          archivedAt: e.archivedAt,
          isDeleted: e.isDeleted,
        ),
      );
    }
    q.orderBy([
      (e) => OrderingTerm(expression: e.nextSendDate, mode: OrderingMode.desc),
    ]);
    return q.watch().distinctRows();
  }

  Stream<List<RecurringExpenseRow>> watchForCategory({
    required String companyId,
    required String categoryId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(recurringExpenses)
      ..where(
        (e) => e.companyId.equals(companyId) & e.categoryId.equals(categoryId),
      );
    if (states.isNotEmpty) {
      q.where(
        (e) => entityStateFilter(
          states: states,
          archivedAt: e.archivedAt,
          isDeleted: e.isDeleted,
        ),
      );
    }
    q.orderBy([
      (e) => OrderingTerm(expression: e.nextSendDate, mode: OrderingMode.desc),
    ]);
    return q.watch().distinctRows();
  }
}

/// Free-text search helper. Mirrors `expense_dao.dart` — JSON1
/// `json_extract` pulls transaction_reference + notes out of the `payload`
/// blob so we don't have to denormalize them.
extension on RecurringExpenses {
  Expression<bool> transactionReferenceLikePayload(String needle) =>
      payloadJsonLike(needle, const [
        'transaction_reference',
        'public_notes',
        'private_notes',
      ]);
}
