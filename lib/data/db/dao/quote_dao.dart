import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';
import 'package:admin/data/db/dao/_payload_search.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/quotes_table.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

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

  // ── Standard record metadata ────────────────────────────────────────
  /// Real Drift column (`EntityTimestampColumns`) — sortable.
  static const String archivedAt = 'archived_at';

  /// Real Drift column (`EntityFlagColumns`) — sortable.
  static const String isDeleted = 'is_deleted';

  /// Derived from `archived_at` + `is_deleted`; no column to order by, so the
  /// column is display-only.
  static const String entityState = 'entity_state';

  /// Attachment count, read from the `documents` JSON column. Display-only.
  static const String documents = 'documents';

  /// Creator. Payload-only on every table — display-only.
  static const String userId = 'user_id';
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

  @override
  GeneratedColumn<int>? get archivedAtColumn => quotes.archivedAt;

  @override
  Expression<bool>? badgeModePredicate(
    String modeId, {
    required String companyId,
    required String currentUserId,
  }) => switch (modeId) {
    'expired' ||
    'draft' ||
    'sent' ||
    'approved' => quoteClientStatusFilter(quotes, modeId, Date.today().toIso()),
    kBadgeModeAssignedToMe => assignedToUserFilter(
      currentUserId,
      column: quotes.assignedUserId,
    ),
    _ => null,
  };

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
    String? badgeModeId,
  }) {
    final q = select(quotes)..where((e) => e.companyId.equals(companyId));
    // Status-tab strip (#98): the SAME predicate the tab's count uses, so
    // the number above the list and the rows in it can't disagree. Applied
    // here (pre-LIMIT) rather than post-decode, so the Drift window stays
    // aligned with the page count.
    final badgeFilter = badgeModeListFilter(badgeModeId, companyId: companyId);
    if (badgeFilter != null) q.where((_) => badgeFilter);

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
      q.where((e) {
        Expression<bool>? clause;
        for (final s in statuses) {
          final p = quoteClientStatusFilter(e, s, today);
          if (p == null) continue;
          clause = clause == null ? p : clause | p;
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
      case QuoteFieldIds.archivedAt:
        return e.archivedAt;
      case QuoteFieldIds.isDeleted:
        return e.isDeleted;
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

/// SQL mirror of the computed quote status (`Quote.calculatedStatusId` /
/// `Quote.isExpired`), shared by the list's `client_status` chip and the
/// sidebar counter. Returns null for a label this mirror doesn't model.
///
/// Wire ids: draft='1' sent='2' approved='3' converted='4' rejected='5'.
/// `converted` also covers a set `invoice_id`; `expired`/`upcoming` split
/// non-terminal quotes by whether the (non-empty) due date falls before or on
/// or after [asOf] — pass `Date.today().toIso()`.
///
/// Two known approximations, unchanged from when this was inline: status
/// precedence isn't applied (a past-due draft matches both `draft` and
/// `expired`), and `viewed` isn't reachable locally because invitations live
/// in the payload rather than a column. Selecting several statuses ORs them,
/// so the overlap is benign.
Expression<bool>? quoteClientStatusFilter(
  Quotes e,
  String status,
  String asOf,
) {
  const dueNN = CustomExpression<String>("NULLIF(due_date, '')");
  final notTerminal =
      e.statusId.equals('4').not() &
      e.invoiceId.equals('') &
      e.statusId.equals('3').not() &
      e.statusId.equals('5').not();
  return switch (status) {
    'draft' => e.statusId.equals('1'),
    // Server `QuoteFilters::client_status` scopes `sent` to NOT-yet-expired
    // quotes (`due_date IS NULL OR due_date >= today`); expired ones belong to
    // the `expired` bucket. Without the guard the local watch surfaced
    // past-due quotes under the Sent chip — each rendering an "Expired" pill —
    // and the same rows appeared again under Expired.
    'sent' =>
      e.statusId.equals('2') &
          (dueNN.isNull() | dueNN.isBiggerOrEqualValue(asOf)),
    'approved' => e.statusId.equals('3'),
    'converted' => e.statusId.equals('4') | e.invoiceId.equals('').not(),
    'rejected' => e.statusId.equals('5'),
    'expired' =>
      notTerminal & dueNN.isNotNull() & dueNN.isSmallerThanValue(asOf),
    'upcoming' =>
      notTerminal & dueNN.isNotNull() & dueNN.isBiggerOrEqualValue(asOf),
    _ => null,
  };
}
