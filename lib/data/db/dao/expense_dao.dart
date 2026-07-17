import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';
import 'package:admin/data/db/dao/_payload_search.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/expenses_table.dart';
import 'package:admin/domain/entity_state.dart';

part 'expense_dao.g.dart';

/// Stable field-id constants used by the list ViewModel for column +
/// sort selection. Keep in sync with `ExpenseRepository.watchPage`.
class ExpenseFieldIds {
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
  static const String publicNotes = 'public_notes';
  static const String privateNotes = 'private_notes';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
  static const String customValue1 = 'custom_value1';
  static const String customValue2 = 'custom_value2';
  static const String customValue3 = 'custom_value3';
  static const String customValue4 = 'custom_value4';
}

@DriftAccessor(tables: [Expenses])
class ExpenseDao extends BaseEntityDao<$ExpensesTable, ExpenseRow>
    with _$ExpenseDaoMixin {
  ExpenseDao(super.db);

  @override
  $ExpensesTable get table => expenses;
  @override
  GeneratedColumn<String> get idColumn => expenses.id;
  @override
  GeneratedColumn<String> get companyIdColumn => expenses.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => expenses.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => expenses.isDirty;

  /// Windowed list watch. Filters: state (active/archived/deleted), free-text
  /// search across number + public_notes + private_notes (via payload JSON
  /// extract). Sort field is one of [ExpenseFieldIds].
  Stream<List<ExpenseRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = ExpenseFieldIds.date,
    bool sortAscending = false,
    String? clientId,
    String? vendorId,
    String? projectId,
    Set<String> clientIds = const {},
    Set<String> categoryIds = const {},
    Set<String> projectIds = const {},
    Set<String> vendorIds = const {},
    Set<String> statuses = const {},
  }) {
    final q = select(expenses)..where((e) => e.companyId.equals(companyId));

    if (clientId != null && clientId.isNotEmpty) {
      q.where((e) => e.clientId.equals(clientId));
    }
    if (vendorId != null && vendorId.isNotEmpty) {
      q.where((e) => e.vendorId.equals(vendorId));
    }
    // Project-scoped embedded list (Project detail tab). Single FK equals,
    // distinct from the server-CSV `projectIds` set below.
    if (projectId != null && projectId.isNotEmpty) {
      q.where((e) => e.projectId.equals(projectId));
    }
    if (clientIds.isNotEmpty) {
      q.where((e) => e.clientId.isIn(clientIds.toList()));
    }
    // Workspace list: hide rows of soft-deleted clients (offline parity with
    // the server `without_deleted_clients` filter). Suppressed under an explicit
    // client scope so a client's detail tabs still show its rows. Client-less
    // expenses (empty client_id) are preserved by the helper.
    if ((clientId == null || clientId.isEmpty) && clientIds.isEmpty) {
      q.where(
        (e) =>
            clientNotDeletedFilter(clientId: e.clientId, companyId: companyId),
      );
    }
    if (categoryIds.isNotEmpty) {
      q.where((e) => e.categoryId.isIn(categoryIds.toList()));
    }
    // Server `project_ids` / `vendor_ids` (CSV hashids) — mirror locally on
    // the already-denormalized FK columns, no decode.
    if (projectIds.isNotEmpty) {
      q.where((e) => e.projectId.isIn(projectIds.toList()));
    }
    if (vendorIds.isNotEmpty) {
      q.where((e) => e.vendorId.isIn(vendorIds.toList()));
    }

    if (statuses.isNotEmpty) {
      // Computed expense status — mirror admin-portal `Expense.matchesStatuses`
      // over the denormalized columns: invoiced = invoice_id set; pending =
      // not-invoiced + should_be_invoiced; logged = not-invoiced + not-pending;
      // paid / unpaid = the `is_paid` triple. Selecting multiple ORs, so the
      // paid/unpaid overlap with the lifecycle statuses is intentional.
      q.where((e) {
        final notInvoiced = e.invoiceId.equals('');
        Expression<bool>? clause;
        void add(Expression<bool> p) =>
            clause = clause == null ? p : clause! | p;
        for (final s in statuses) {
          switch (s) {
            case 'invoiced':
              add(notInvoiced.not());
            case 'pending':
              add(notInvoiced & e.shouldBeInvoiced.equals(true));
            case 'logged':
              add(notInvoiced & e.shouldBeInvoiced.equals(false));
            case 'paid':
              add(e.isPaid.equals(true));
            case 'unpaid':
              add(e.isPaid.equals(false));
          }
        }
        return clause ?? const Constant(true);
      });
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
            clientNameMatchesFilter(
              clientId: e.clientId,
              companyId: companyId,
              needle: needle,
            ) |
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

  Expression _sortExpression(Expenses e, String field) {
    switch (field) {
      case ExpenseFieldIds.number:
        return e.number.lower();
      case ExpenseFieldIds.date:
        return e.date;
      case ExpenseFieldIds.paymentDate:
        return e.paymentDate;
      case ExpenseFieldIds.amount:
        return e.amount.cast<double>();
      case ExpenseFieldIds.vendorId:
        return e.vendorId;
      case ExpenseFieldIds.clientId:
        return e.clientId;
      case ExpenseFieldIds.projectId:
        return e.projectId;
      case ExpenseFieldIds.categoryId:
        return e.categoryId;
      case ExpenseFieldIds.invoiceId:
        return e.invoiceId;
      case ExpenseFieldIds.currencyId:
        return e.currencyId;
      case ExpenseFieldIds.createdAt:
        return e.createdAt;
      case ExpenseFieldIds.updatedAt:
        return e.updatedAt;
      case ExpenseFieldIds.customValue1:
        return e.customValue1.lower();
      case ExpenseFieldIds.customValue2:
        return e.customValue2.lower();
      case ExpenseFieldIds.customValue3:
        return e.customValue3.lower();
      case ExpenseFieldIds.customValue4:
        return e.customValue4.lower();
      default:
        // Silent fallback masks the real failure (user clicks a column
        // header → list re-orders by date with no error). The
        // user-facing sort dropdown only exposes mapped ids, so this
        // case is unreachable today — but if a future code path
        // (saved view, deep link, column-header click) passes an
        // unmapped id, we want to hear about it loudly.
        throw ArgumentError(
          'Unknown sort field "$field" for Expense — add a case in '
          '_sortExpression or stop exposing it as a sort option.',
        );
    }
  }

  /// Cheap streams used by cross-entity navigation (vendor/client/project
  /// detail pages → "Linked expenses" card). Each filters by a single id +
  /// excludes deleted rows.

  Stream<List<ExpenseRow>> watchForVendor({
    required String companyId,
    required String vendorId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(expenses)
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
      (e) => OrderingTerm(expression: e.date, mode: OrderingMode.desc),
    ]);
    return q.watch().distinctRows();
  }

  Stream<List<ExpenseRow>> watchForClient({
    required String companyId,
    required String clientId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(expenses)
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
      (e) => OrderingTerm(expression: e.date, mode: OrderingMode.desc),
    ]);
    return q.watch().distinctRows();
  }

  Stream<List<ExpenseRow>> watchForProject({
    required String companyId,
    required String projectId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(expenses)
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
      (e) => OrderingTerm(expression: e.date, mode: OrderingMode.desc),
    ]);
    return q.watch().distinctRows();
  }

  Stream<List<ExpenseRow>> watchForCategory({
    required String companyId,
    required String categoryId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(expenses)
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
      (e) => OrderingTerm(expression: e.date, mode: OrderingMode.desc),
    ]);
    return q.watch().distinctRows();
  }
}

/// Free-text search helper. SQLite's JSON1 `json_extract` digs the
/// transaction_reference + notes out of the `payload` blob so we don't have
/// to denormalize all of them. Mirrors the technique used in
/// `task_dao.dart` for description search.
extension on Expenses {
  Expression<bool> transactionReferenceLikePayload(String needle) =>
      payloadJsonLike(needle, const [
        'transaction_reference',
        'public_notes',
        'private_notes',
      ]);
}
