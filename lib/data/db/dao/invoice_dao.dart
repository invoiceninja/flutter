import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';
import 'package:admin/data/db/dao/_payload_search.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/invoices_table.dart';
import 'package:admin/domain/entity_state.dart';

part 'invoice_dao.g.dart';

/// Stable field-id constants used by the list ViewModel for column +
/// sort selection. Keep in sync with `InvoiceRepository.watchPage` +
/// `InvoiceDao._sortExpression`.
class InvoiceFieldIds {
  static const String number = 'number';
  static const String status = 'status_id';
  static const String clientId = 'client_id';
  static const String vendorId = 'vendor_id';
  static const String projectId = 'project_id';
  static const String date = 'date';
  static const String dueDate = 'due_date';
  static const String partialDueDate = 'partial_due_date';
  static const String amount = 'amount';
  static const String balance = 'balance';
  static const String paidToDate = 'paid_to_date';
  static const String partial = 'partial';
  static const String poNumber = 'po_number';
  static const String recurringId = 'recurring_id';
  static const String designId = 'design_id';
  static const String assignedUserId = 'assigned_user_id';
  static const String publicNotes = 'public_notes';
  static const String privateNotes = 'private_notes';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
  static const String customValue1 = 'custom_value1';
  static const String customValue2 = 'custom_value2';
  static const String customValue3 = 'custom_value3';
  static const String customValue4 = 'custom_value4';
  // Display-only (tags live in the payload) — never add to sortOptions.
  static const String tagIds = 'invoice_tag_ids';
}

@DriftAccessor(tables: [Invoices])
class InvoiceDao extends BaseEntityDao<$InvoicesTable, InvoiceRow>
    with _$InvoiceDaoMixin {
  InvoiceDao(super.db);

  @override
  $InvoicesTable get table => invoices;
  @override
  GeneratedColumn<String> get idColumn => invoices.id;
  @override
  GeneratedColumn<String> get companyIdColumn => invoices.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => invoices.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => invoices.isDirty;

  /// Windowed list watch. Filters: state (active/archived/deleted), free-text
  /// search across number + public_notes + private_notes + po_number (via
  /// payload JSON extract). Sort field is one of [InvoiceFieldIds].
  Stream<List<InvoiceRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = InvoiceFieldIds.number,
    bool sortAscending = false,
    String? clientId,
    String? projectId,
    Set<String> clientIds = const {},
    Set<String> statusIds = const {},
    Set<String> customValues1 = const {},
    Set<String> customValues2 = const {},
    Set<String> customValues3 = const {},
    Set<String> customValues4 = const {},
    String? overdueAsOf,
    String? dateStart,
    String? dateEnd,
    String? dueDateStart,
    String? dueDateEnd,
  }) {
    final q = select(invoices)..where((e) => e.companyId.equals(companyId));

    if (clientId != null && clientId.isNotEmpty) {
      q.where((e) => e.clientId.equals(clientId));
    }
    // Project-scoped embedded list (Project detail tab). Single FK equals,
    // in-memory only — not forwarded as a server filter.
    if (projectId != null && projectId.isNotEmpty) {
      q.where((e) => e.projectId.equals(projectId));
    }
    if (clientIds.isNotEmpty) {
      q.where((e) => e.clientId.isIn(clientIds.toList()));
    }
    // Workspace list: hide rows of soft-deleted clients (offline parity with
    // the server `without_deleted_clients` filter). Suppressed under an explicit
    // client scope so a client's detail tabs still show its rows.
    if ((clientId == null || clientId.isEmpty) && clientIds.isEmpty) {
      q.where(
        (e) =>
            clientNotDeletedFilter(clientId: e.clientId, companyId: companyId),
      );
    }
    // Custom-field filters mirror the server `custom_value1..4` (single-value
    // substring server-side; the exact-set local predicate is the source of
    // truth — same idiom as ClientDao).
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
    if (statusIds.isNotEmpty) {
      q.where((e) => e.statusId.isIn(statusIds.toList()));
    }
    if (overdueAsOf != null) {
      // Mirror `Invoice.isPastDue` (the single source of truth): balance > 0,
      // not paid/cancelled/reversed, and the effective due date
      // (partial_due_date ?? due_date, ignoring empty strings) is before
      // `overdueAsOf` (the domain's `Date.today()`, passed in so the local
      // predicate and the getter use the same clock).
      const effectiveDue = CustomExpression<String>(
        "COALESCE(NULLIF(partial_due_date, ''), NULLIF(due_date, ''))",
      );
      q.where(
        (e) =>
            e.balance.cast<double>().isBiggerThanValue(0) &
            e.statusId.isIn(const ['4', '5', '6']).not() &
            effectiveDue.isNotNull() &
            effectiveDue.isSmallerThanValue(overdueAsOf),
      );
    }
    if (dateStart != null && dateEnd != null) {
      q.where((e) => e.date.isBetweenValues(dateStart, dateEnd));
    }
    if (dueDateStart != null && dueDateEnd != null) {
      q.where((e) => e.dueDate.isBetweenValues(dueDateStart, dueDateEnd));
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
            e.poNumber.lower().like(needle) |
            e.notesLikePayload(needle) |
            e.customValue1.lower().like(needle) |
            e.customValue2.lower().like(needle) |
            e.customValue3.lower().like(needle) |
            e.customValue4.lower().like(needle) |
            clientNameMatchesFilter(
              clientId: e.clientId,
              companyId: companyId,
              needle: needle,
            ) |
            projectNameMatchesFilter(
              projectId: e.projectId,
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

  Expression _sortExpression(Invoices e, String field) {
    switch (field) {
      case InvoiceFieldIds.number:
        return e.number.lower();
      case InvoiceFieldIds.status:
        return e.statusId;
      case InvoiceFieldIds.clientId:
        return e.clientId;
      case InvoiceFieldIds.vendorId:
        return e.vendorId;
      case InvoiceFieldIds.projectId:
        return e.projectId;
      case InvoiceFieldIds.date:
        return e.date;
      case InvoiceFieldIds.dueDate:
        return e.dueDate;
      case InvoiceFieldIds.partialDueDate:
        return e.partialDueDate;
      case InvoiceFieldIds.amount:
        return e.amount.cast<double>();
      case InvoiceFieldIds.balance:
        return e.balance.cast<double>();
      case InvoiceFieldIds.paidToDate:
        return e.paidToDate.cast<double>();
      case InvoiceFieldIds.partial:
        return e.partial.cast<double>();
      case InvoiceFieldIds.poNumber:
        return e.poNumber.lower();
      case InvoiceFieldIds.designId:
        return e.designId;
      case InvoiceFieldIds.assignedUserId:
        return e.assignedUserId;
      case InvoiceFieldIds.updatedAt:
        return e.updatedAt;
      case InvoiceFieldIds.createdAt:
        return e.createdAt;
      case InvoiceFieldIds.customValue1:
        return e.customValue1.lower();
      case InvoiceFieldIds.customValue2:
        return e.customValue2.lower();
      case InvoiceFieldIds.customValue3:
        return e.customValue3.lower();
      case InvoiceFieldIds.customValue4:
        return e.customValue4.lower();
      default:
        // Silent fallback would mask real failures — see expense_dao.dart
        // for the rationale.
        throw ArgumentError(
          'Unknown sort field "$field" for Invoice — add a case in '
          '_sortExpression or stop exposing it as a sort option.',
        );
    }
  }

  /// Cheap stream used by the Client detail page's "Invoices" card. Filters
  /// by `client_id` + excludes deleted rows by default.
  Stream<List<InvoiceRow>> watchForClient({
    required String companyId,
    required String clientId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(invoices)
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

  /// Cheap stream used by the Payment Link detail page's "Invoices" card.
  /// Filters by `subscription_id` + excludes deleted rows by default.
  Stream<List<InvoiceRow>> watchForSubscription({
    required String companyId,
    required String subscriptionId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(invoices)
      ..where(
        (e) =>
            e.companyId.equals(companyId) &
            e.subscriptionId.equals(subscriptionId),
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

  Stream<List<InvoiceRow>> watchForProject({
    required String companyId,
    required String projectId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(invoices)
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
}

/// Free-text search helper. SQLite's JSON1 `json_extract` digs notes out of
/// the `payload` blob; same technique as `task_dao.dart`/`expense_dao.dart`.
extension on Invoices {
  Expression<bool> notesLikePayload(String needle) =>
      payloadJsonLike(needle, const ['public_notes', 'private_notes']);
}
