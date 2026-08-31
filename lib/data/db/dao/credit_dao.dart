import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';
import 'package:admin/data/db/dao/_payload_search.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/credits_table.dart';
import 'package:admin/data/models/domain/credit_status.dart';
import 'package:admin/domain/entity_state.dart';

part 'credit_dao.g.dart';

class CreditFieldIds {
  static const String number = 'number';
  static const String status = 'status_id';
  static const String clientId = 'client_id';
  static const String vendorId = 'vendor_id';
  static const String projectId = 'project_id';
  static const String date = 'date';
  static const String dueDate = 'due_date';
  static const String amount = 'amount';
  static const String balance = 'balance';
  static const String paidToDate = 'paid_to_date';
  static const String poNumber = 'po_number';
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
  static const String tagIds = 'credit_tag_ids';
}

@DriftAccessor(tables: [Credits])
class CreditDao extends BaseEntityDao<$CreditsTable, CreditRow>
    with _$CreditDaoMixin {
  CreditDao(super.db);

  @override
  $CreditsTable get table => credits;
  @override
  GeneratedColumn<String> get idColumn => credits.id;
  @override
  GeneratedColumn<String> get companyIdColumn => credits.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => credits.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => credits.isDirty;

  @override
  GeneratedColumn<int>? get archivedAtColumn => credits.archivedAt;

  @override
  Expression<bool>? badgeModePredicate(
    String modeId, {
    required String companyId,
    required String currentUserId,
  }) => switch (modeId) {
    // Credit still owed back to the client — issued (not a draft) with some
    // balance left to apply. The actionable one for this row.
    'unapplied' =>
      credits.statusId.equals(CreditStatus.draft.wireId).not() &
          credits.balance.cast<double>().isBiggerThanValue(0),
    'draft' => credits.statusId.equals(CreditStatus.draft.wireId),
    'sent' => credits.statusId.equals(CreditStatus.sent.wireId),
    kBadgeModeAssignedToMe => assignedToUserFilter(
      currentUserId,
      column: credits.assignedUserId,
    ),
    _ => null,
  };

  Stream<List<CreditRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = CreditFieldIds.number,
    bool sortAscending = false,
    String? clientId,
    Set<String> clientIds = const {},
    Set<String> statuses = const {},
    Set<String> customValues1 = const {},
    Set<String> customValues2 = const {},
    Set<String> customValues3 = const {},
    Set<String> customValues4 = const {},
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
    final q = select(credits)..where((e) => e.companyId.equals(companyId));
    // Status-tab strip (#98): the SAME predicate the tab's count uses, so
    // the number above the list and the rows in it can't disagree. Applied
    // here (pre-LIMIT) rather than post-decode, so the Drift window stays
    // aligned with the page count.
    final badgeFilter = badgeModeListFilter(badgeModeId, companyId: companyId);
    if (badgeFilter != null) q.where((_) => badgeFilter);
    if (clientId != null && clientId.isNotEmpty) {
      q.where((e) => e.clientId.equals(clientId));
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
    if (dateStart != null && dateEnd != null) {
      q.where((e) => e.date.isBetweenValues(dateStart, dateEnd));
    }
    // Single-date comparators (>, >=, <, <=, =) live in the `op:value`
    // slot; without this mirror the chip narrowed only the server fetch.
    final datePred = comparableDatePredicate(
      credits.date,
      op: dateOp,
      value: dateValue,
    );
    if (datePred != null) q.where((e) => datePred);
    final dueDatePred = comparableDatePredicate(
      credits.dueDate,
      op: dueDateOp,
      value: dueDateValue,
    );
    if (dueDatePred != null) q.where((e) => dueDatePred);
    if (dueDateStart != null && dueDateEnd != null) {
      q.where((e) => e.dueDate.isBetweenValues(dueDateStart, dueDateEnd));
    }
    // Credit `client_status` filter. Each label maps 1:1 to a stored
    // `status_id` wire id (draft=1/sent=2/partial=3/applied=4) — no computed
    // states like quotes, so this is a plain membership test. The repository
    // maps the labels to wire ids (`parseCreditStatusFilter`); multi-select
    // ORs. Mirrors the server `CreditFilters::client_status`
    // (`whereIn('status_id', …)`).
    if (statuses.isNotEmpty) {
      q.where((e) => e.statusId.isIn(statuses.toList()));
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

  Expression _sortExpression(Credits e, String field) {
    switch (field) {
      case CreditFieldIds.number:
        return e.number.lower();
      case CreditFieldIds.status:
        return e.statusId;
      case CreditFieldIds.clientId:
        return e.clientId;
      case CreditFieldIds.vendorId:
        return e.vendorId;
      case CreditFieldIds.projectId:
        return e.projectId;
      case CreditFieldIds.date:
        return e.date;
      case CreditFieldIds.dueDate:
        return e.dueDate;
      case CreditFieldIds.amount:
        return e.amount.cast<double>();
      case CreditFieldIds.balance:
        return e.balance.cast<double>();
      case CreditFieldIds.paidToDate:
        return e.paidToDate.cast<double>();
      case CreditFieldIds.poNumber:
        return e.poNumber.lower();
      case CreditFieldIds.designId:
        return e.designId;
      case CreditFieldIds.assignedUserId:
        return e.assignedUserId;
      case CreditFieldIds.updatedAt:
        return e.updatedAt;
      case CreditFieldIds.createdAt:
        return e.createdAt;
      case CreditFieldIds.customValue1:
        return e.customValue1.lower();
      case CreditFieldIds.customValue2:
        return e.customValue2.lower();
      case CreditFieldIds.customValue3:
        return e.customValue3.lower();
      case CreditFieldIds.customValue4:
        return e.customValue4.lower();
      default:
        throw ArgumentError(
          'Unknown sort field "$field" for Credit — add a case in '
          '_sortExpression or stop exposing it as a sort option.',
        );
    }
  }

  Stream<List<CreditRow>> watchForClient({
    required String companyId,
    required String clientId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(credits)
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
}

extension on Credits {
  Expression<bool> notesLikePayload(String needle) =>
      payloadJsonLike(needle, const ['public_notes', 'private_notes']);
}
