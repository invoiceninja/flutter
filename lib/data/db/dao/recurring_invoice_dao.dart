import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';
import 'package:admin/data/db/dao/_payload_search.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/models/domain/recurring_invoice_status.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/recurring_invoices_table.dart';
import 'package:admin/domain/entity_state.dart';

part 'recurring_invoice_dao.g.dart';

class RecurringInvoiceFieldIds {
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
  static const String frequencyId = 'frequency_id';
  static const String nextSendDate = 'next_send_date';
  static const String remainingCycles = 'remaining_cycles';
  static const String autoBill = 'auto_bill';
  static const String publicNotes = 'public_notes';
  static const String privateNotes = 'private_notes';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
  static const String customValue1 = 'custom_value1';
  static const String customValue2 = 'custom_value2';
  static const String customValue3 = 'custom_value3';
  static const String customValue4 = 'custom_value4';
  // Display-only (tags live in the payload) — never add to sortOptions.
  static const String tagIds = 'recurring_invoice_tag_ids';
}

@DriftAccessor(tables: [RecurringInvoices])
class RecurringInvoiceDao
    extends BaseEntityDao<$RecurringInvoicesTable, RecurringInvoiceRow>
    with _$RecurringInvoiceDaoMixin {
  RecurringInvoiceDao(super.db);

  @override
  $RecurringInvoicesTable get table => recurringInvoices;
  @override
  GeneratedColumn<String> get idColumn => recurringInvoices.id;
  @override
  GeneratedColumn<String> get companyIdColumn => recurringInvoices.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => recurringInvoices.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => recurringInvoices.isDirty;

  @override
  GeneratedColumn<int>? get archivedAtColumn => recurringInvoices.archivedAt;

  @override
  Expression<bool>? badgeModePredicate(
    String modeId, {
    required String companyId,
    required String currentUserId,
  }) => switch (modeId) {
    'active' => recurringInvoices.statusId.equals(
      RecurringInvoiceStatus.active.wireId,
    ),
    'paused' => recurringInvoices.statusId.equals(
      RecurringInvoiceStatus.paused.wireId,
    ),
    'draft' => recurringInvoices.statusId.equals(
      RecurringInvoiceStatus.draft.wireId,
    ),
    kBadgeModeAssignedToMe => assignedToUserFilter(
      currentUserId,
      column: recurringInvoices.assignedUserId,
    ),
    // No `pending` (active but never sent): that computed status needs
    // `last_sent_date`, which this table doesn't carry — recurring *expenses*
    // does, which is why the mode is offered there and not here.
    _ => null,
  };

  Stream<List<RecurringInvoiceRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = RecurringInvoiceFieldIds.number,
    bool sortAscending = false,
    String? clientId,
    Set<String> clientIds = const {},
    Set<String> statusIds = const {},
    Set<String> customValues1 = const {},
    Set<String> customValues2 = const {},
    Set<String> customValues3 = const {},
    Set<String> customValues4 = const {},
  }) {
    final q = select(recurringInvoices)
      ..where((e) => e.companyId.equals(companyId));
    if (clientId != null && clientId.isNotEmpty) {
      q.where((e) => e.clientId.equals(clientId));
    }
    // Local mirror of the `client:` chip's `client_id` server filter. This was
    // the only ClientFilterKey list missing it, so the chip narrowed the server
    // fetch while the watch kept emitting every cached recurring invoice — the
    // list looked unchanged and the chip looked broken.
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
    // Lifecycle status filter (draft/active/paused/completed) — exact-set
    // predicate on the stored `statusId` column, same idiom as InvoiceDao.
    if (statusIds.isNotEmpty) {
      q.where((e) => e.statusId.isIn(statusIds.toList()));
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

  Expression _sortExpression(RecurringInvoices e, String field) {
    switch (field) {
      case RecurringInvoiceFieldIds.number:
        return e.number.lower();
      case RecurringInvoiceFieldIds.status:
        // Sorts on the stored status_id, so a "pending" row (active with no
        // last_sent_date — a UI-computed pseudo-status) groups with active
        // rather than sorting separately. Faithfully reproducing
        // `calculatedStatusId` here would need a `last_sent_date` column (not
        // denormalized); accepted as a minor list-ordering nuance.
        return e.statusId;
      case RecurringInvoiceFieldIds.clientId:
        return e.clientId;
      case RecurringInvoiceFieldIds.vendorId:
        return e.vendorId;
      case RecurringInvoiceFieldIds.projectId:
        return e.projectId;
      case RecurringInvoiceFieldIds.date:
        return e.date;
      case RecurringInvoiceFieldIds.dueDate:
        return e.dueDate;
      case RecurringInvoiceFieldIds.amount:
        return e.amount.cast<double>();
      case RecurringInvoiceFieldIds.balance:
        return e.balance.cast<double>();
      case RecurringInvoiceFieldIds.poNumber:
        return e.poNumber.lower();
      case RecurringInvoiceFieldIds.designId:
        return e.designId;
      case RecurringInvoiceFieldIds.assignedUserId:
        return e.assignedUserId;
      case RecurringInvoiceFieldIds.frequencyId:
        return e.frequencyId;
      case RecurringInvoiceFieldIds.nextSendDate:
        return e.nextSendDate;
      case RecurringInvoiceFieldIds.remainingCycles:
        return e.remainingCycles;
      case RecurringInvoiceFieldIds.autoBill:
        return e.autoBill;
      case RecurringInvoiceFieldIds.updatedAt:
        return e.updatedAt;
      case RecurringInvoiceFieldIds.createdAt:
        return e.createdAt;
      case RecurringInvoiceFieldIds.customValue1:
        return e.customValue1.lower();
      case RecurringInvoiceFieldIds.customValue2:
        return e.customValue2.lower();
      case RecurringInvoiceFieldIds.customValue3:
        return e.customValue3.lower();
      case RecurringInvoiceFieldIds.customValue4:
        return e.customValue4.lower();
      default:
        throw ArgumentError(
          'Unknown sort field "$field" for RecurringInvoice — add a case in '
          '_sortExpression or stop exposing it as a sort option.',
        );
    }
  }

  Stream<List<RecurringInvoiceRow>> watchForClient({
    required String companyId,
    required String clientId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(recurringInvoices)
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

  /// Cheap stream used by the Payment Link detail page's "Recurring
  /// Invoices" card. Filters by `subscription_id` + excludes deleted rows.
  Stream<List<RecurringInvoiceRow>> watchForSubscription({
    required String companyId,
    required String subscriptionId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(recurringInvoices)
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
}

extension on RecurringInvoices {
  Expression<bool> notesLikePayload(String needle) =>
      payloadJsonLike(needle, const ['public_notes', 'private_notes']);
}
