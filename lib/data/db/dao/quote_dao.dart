import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';
import 'package:admin/data/db/dao/_payload_search.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/quotes_table.dart';
import 'package:admin/domain/entity_state.dart';

part 'quote_dao.g.dart';

/// Stable field-id constants for column + sort selection. Mirrors
/// `InvoiceFieldIds` — same fields minus the invoice-only `paid_to_date`,
/// `partial_due_date`, `partial`.
class QuoteFieldIds {
  static const String number = 'number';
  static const String status = 'status_id';
  static const String clientId = 'client_id';
  static const String vendorId = 'vendor_id';
  static const String projectId = 'project_id';
  static const String date = 'date';
  static const String dueDate = 'due_date';
  static const String amount = 'amount';
  static const String balance = 'balance';
  static const String poNumber = 'po_number';
  static const String designId = 'design_id';
  static const String assignedUserId = 'assigned_user_id';
  static const String invoiceId = 'invoice_id';
  static const String publicNotes = 'public_notes';
  static const String privateNotes = 'private_notes';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
  static const String customValue1 = 'custom_value1';
  static const String customValue2 = 'custom_value2';
  static const String customValue3 = 'custom_value3';
  static const String customValue4 = 'custom_value4';
  // Display-only (tags live in the payload) — never add to sortOptions.
  static const String tagIds = 'quote_tag_ids';
}

@DriftAccessor(tables: [Quotes])
class QuoteDao extends BaseEntityDao<$QuotesTable, QuoteRow>
    with _$QuoteDaoMixin {
  QuoteDao(super.db);

  @override
  $QuotesTable get table => quotes;
  @override
  GeneratedColumn<String> get idColumn => quotes.id;
  @override
  GeneratedColumn<String> get companyIdColumn => quotes.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => quotes.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => quotes.isDirty;

  Stream<List<QuoteRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = QuoteFieldIds.number,
    bool sortAscending = false,
    String? clientId,
    String? projectId,
    Set<String> clientIds = const {},
    Set<String> statuses = const {},
    Set<String> customValues1 = const {},
    Set<String> customValues2 = const {},
    Set<String> customValues3 = const {},
    Set<String> customValues4 = const {},
    String? statusAsOf,
    String? dateOp,
    String? dateValue,
    String? dueDateOp,
    String? dueDateValue,
    String? dateStart,
    String? dateEnd,
    String? dueDateStart,
    String? dueDateEnd,
  }) {
    final q = select(quotes)..where((e) => e.companyId.equals(companyId));

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
    if (statuses.isNotEmpty) {
      // `client_status` is the computed quote status. Mirror the domain
      // getters (`Quote.isConverted/isApproved/isExpired`,
      // `quote_status.dart`): draft='1' sent='2' approved='3'
      // converted='4' rejected='5'. `converted` also covers a set `invoice_id`;
      // `expired`/`upcoming` split non-terminal quotes by whether the
      // (non-empty) due date is before/onafter `statusAsOf` (the domain's
      // `Date.today()`). Approximation: precedence isn't applied (a
      // past-due draft matches both `draft` and `expired`) and `viewed`
      // isn't reachable locally — invitations live in the payload, not a
      // column. Selecting multiple statuses ORs, so the overlap is benign.
      final today = statusAsOf ?? '';
      final notConverted =
          quotes.statusId.equals('4').not() & quotes.invoiceId.equals('');
      final notApproved = quotes.statusId.equals('3').not();
      final notRejected = quotes.statusId.equals('5').not();
      const dueNN = CustomExpression<String>("NULLIF(due_date, '')");
      q.where((e) {
        Expression<bool>? clause;
        void add(Expression<bool> p) =>
            clause = clause == null ? p : clause! | p;
        for (final s in statuses) {
          switch (s) {
            case 'draft':
              add(e.statusId.equals('1'));
            case 'sent':
              // Server `QuoteFilters::client_status` scopes `sent` to
              // NOT-yet-expired quotes (`due_date IS NULL OR due_date >=
              // today`); expired ones belong to the `expired` bucket. Without
              // the guard the local watch surfaced past-due quotes under the
              // Sent chip — each rendering an "Expired" pill — and the same
              // rows appeared again under Expired.
              add(
                e.statusId.equals('2') &
                    (dueNN.isNull() | dueNN.isBiggerOrEqualValue(today)),
              );
            case 'approved':
              add(e.statusId.equals('3'));
            case 'converted':
              add(e.statusId.equals('4') | e.invoiceId.equals('').not());
            case 'rejected':
              add(e.statusId.equals('5'));
            case 'expired':
              add(
                notConverted &
                    notApproved &
                    notRejected &
                    dueNN.isNotNull() &
                    dueNN.isSmallerThanValue(today),
              );
            case 'upcoming':
              add(
                notConverted &
                    notApproved &
                    notRejected &
                    dueNN.isNotNull() &
                    dueNN.isBiggerOrEqualValue(today),
              );
          }
        }
        return clause ?? const Constant(false);
      });
    }
    if (dateStart != null && dateEnd != null) {
      q.where((e) => e.date.isBetweenValues(dateStart, dateEnd));
    }
    // Single-date comparators (>, >=, <, <=, =) live in the `op:value`
    // slot; without this mirror the chip narrowed only the server fetch.
    final datePred = comparableDatePredicate(
      quotes.date,
      op: dateOp,
      value: dateValue,
    );
    if (datePred != null) q.where((e) => datePred);
    final dueDatePred = comparableDatePredicate(
      quotes.dueDate,
      op: dueDateOp,
      value: dueDateValue,
    );
    if (dueDatePred != null) q.where((e) => dueDatePred);
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

  Expression _sortExpression(Quotes e, String field) {
    switch (field) {
      case QuoteFieldIds.number:
        return e.number.lower();
      case QuoteFieldIds.status:
        return e.statusId;
      case QuoteFieldIds.clientId:
        return e.clientId;
      case QuoteFieldIds.vendorId:
        return e.vendorId;
      case QuoteFieldIds.projectId:
        return e.projectId;
      case QuoteFieldIds.date:
        return e.date;
      case QuoteFieldIds.dueDate:
        return e.dueDate;
      case QuoteFieldIds.amount:
        return e.amount.cast<double>();
      case QuoteFieldIds.balance:
        return e.balance.cast<double>();
      case QuoteFieldIds.poNumber:
        return e.poNumber.lower();
      case QuoteFieldIds.designId:
        return e.designId;
      case QuoteFieldIds.assignedUserId:
        return e.assignedUserId;
      case QuoteFieldIds.invoiceId:
        return e.invoiceId;
      case QuoteFieldIds.updatedAt:
        return e.updatedAt;
      case QuoteFieldIds.createdAt:
        return e.createdAt;
      case QuoteFieldIds.customValue1:
        return e.customValue1.lower();
      case QuoteFieldIds.customValue2:
        return e.customValue2.lower();
      case QuoteFieldIds.customValue3:
        return e.customValue3.lower();
      case QuoteFieldIds.customValue4:
        return e.customValue4.lower();
      default:
        throw ArgumentError(
          'Unknown sort field "$field" for Quote — add a case in '
          '_sortExpression or stop exposing it as a sort option.',
        );
    }
  }

  Stream<List<QuoteRow>> watchForClient({
    required String companyId,
    required String clientId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(quotes)
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

  Stream<List<QuoteRow>> watchForProject({
    required String companyId,
    required String projectId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(quotes)
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

extension on Quotes {
  Expression<bool> notesLikePayload(String needle) =>
      payloadJsonLike(needle, const ['public_notes', 'private_notes']);
}
