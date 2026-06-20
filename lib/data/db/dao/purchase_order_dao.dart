import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';
import 'package:admin/data/db/dao/_payload_search.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/purchase_orders_table.dart';
import 'package:admin/domain/entity_state.dart';

part 'purchase_order_dao.g.dart';

class PurchaseOrderFieldIds {
  static const String number = 'number';
  static const String status = 'status_id';
  static const String clientId = 'client_id';
  static const String vendorId = 'vendor_id';
  static const String projectId = 'project_id';
  static const String expenseId = 'expense_id';
  static const String date = 'date';
  static const String dueDate = 'due_date';
  static const String amount = 'amount';
  static const String balance = 'balance';
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
}

@DriftAccessor(tables: [PurchaseOrders])
class PurchaseOrderDao
    extends BaseEntityDao<$PurchaseOrdersTable, PurchaseOrderRow>
    with _$PurchaseOrderDaoMixin {
  PurchaseOrderDao(super.db);

  @override
  $PurchaseOrdersTable get table => purchaseOrders;
  @override
  GeneratedColumn<String> get idColumn => purchaseOrders.id;
  @override
  GeneratedColumn<String> get companyIdColumn => purchaseOrders.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => purchaseOrders.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => purchaseOrders.isDirty;

  Stream<List<PurchaseOrderRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = PurchaseOrderFieldIds.number,
    bool sortAscending = false,
    String? vendorId,
    Set<String> customValues1 = const {},
    Set<String> customValues2 = const {},
    Set<String> customValues3 = const {},
    Set<String> customValues4 = const {},
  }) {
    final q = select(purchaseOrders)
      ..where((e) => e.companyId.equals(companyId));
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
    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where(
        (e) =>
            e.number.lower().like(needle) |
            e.poNumber.lower().like(needle) |
            e.notesLikePayload(needle) |
            vendorNameMatchesFilter(
              vendorId: e.vendorId,
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

  Expression _sortExpression(PurchaseOrders e, String field) {
    switch (field) {
      case PurchaseOrderFieldIds.number:
        return e.number.lower();
      case PurchaseOrderFieldIds.status:
        return e.statusId;
      case PurchaseOrderFieldIds.clientId:
        return e.clientId;
      case PurchaseOrderFieldIds.vendorId:
        return e.vendorId;
      case PurchaseOrderFieldIds.projectId:
        return e.projectId;
      case PurchaseOrderFieldIds.expenseId:
        return e.expenseId;
      case PurchaseOrderFieldIds.date:
        return e.date;
      case PurchaseOrderFieldIds.dueDate:
        return e.dueDate;
      case PurchaseOrderFieldIds.amount:
        return e.amount.cast<double>();
      case PurchaseOrderFieldIds.balance:
        return e.balance.cast<double>();
      case PurchaseOrderFieldIds.poNumber:
        return e.poNumber.lower();
      case PurchaseOrderFieldIds.designId:
        return e.designId;
      case PurchaseOrderFieldIds.assignedUserId:
        return e.assignedUserId;
      case PurchaseOrderFieldIds.updatedAt:
        return e.updatedAt;
      case PurchaseOrderFieldIds.createdAt:
        return e.createdAt;
      case PurchaseOrderFieldIds.customValue1:
        return e.customValue1.lower();
      case PurchaseOrderFieldIds.customValue2:
        return e.customValue2.lower();
      case PurchaseOrderFieldIds.customValue3:
        return e.customValue3.lower();
      case PurchaseOrderFieldIds.customValue4:
        return e.customValue4.lower();
      default:
        throw ArgumentError(
          'Unknown sort field "$field" for PurchaseOrder — add a case in '
          '_sortExpression or stop exposing it as a sort option.',
        );
    }
  }

  Stream<List<PurchaseOrderRow>> watchForVendor({
    required String companyId,
    required String vendorId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(purchaseOrders)
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
}

extension on PurchaseOrders {
  Expression<bool> notesLikePayload(String needle) =>
      payloadJsonLike(needle, const ['public_notes', 'private_notes']);
}
