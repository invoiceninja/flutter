import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/columns/ids/vendor_column_ids.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/vendors_table.dart';
import 'package:admin/data/models/domain/purchase_order_status.dart';

part 'vendor_dao.g.dart';

@DriftAccessor(tables: [Vendors])
class VendorDao extends BaseEntityDao<$VendorsTable, VendorRow>
    with _$VendorDaoMixin {
  VendorDao(super.db);

  @override
  $VendorsTable get table => vendors;
  @override
  GeneratedColumn<String> get idColumn => vendors.id;
  @override
  GeneratedColumn<String> get companyIdColumn => vendors.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => vendors.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => vendors.isDirty;

  @override
  GeneratedColumn<int>? get archivedAtColumn => vendors.archivedAt;

  /// The vendors table itself has no status, balance or date to count — so
  /// both counters here look *outward*, at what the user owes each vendor.
  /// The number is a count of **vendors**, not documents: "3" means three
  /// vendors need attention, which is what a row labelled Vendors should say.
  ///
  /// Both use the subquery idiom from [clientNotDeletedFilter]; Drift registers
  /// the subquery's table, so the badge re-emits when an expense or purchase
  /// order changes, not only when a vendor does.
  @override
  Expression<bool>? badgeModePredicate(
    String modeId, {
    required String companyId,
    required String currentUserId,
  }) => switch (modeId) {
    'unpaid_expenses' => vendors.id.isInQuery(
      _unpaidExpenseVendorIds(companyId),
    ),
    'open_purchase_orders' => vendors.id.isInQuery(
      _openPurchaseOrderVendorIds(companyId),
    ),
    _ => null,
  };

  /// Vendor ids with at least one active, unpaid expense in [companyId].
  JoinedSelectStatement<HasResultSet, dynamic> _unpaidExpenseVendorIds(
    String companyId,
  ) {
    final expenses = attachedDatabase.expenses;
    return selectOnly(expenses)
      ..addColumns([expenses.vendorId])
      ..where(
        expenses.companyId.equals(companyId) &
            expenses.isDeleted.equals(false) &
            expenses.archivedAt.isNull() &
            expenses.isPaid.equals(false) &
            // Vendor-less expenses would otherwise contribute an empty id that
            // matches no vendor — harmless, but skip the rows outright.
            expenses.vendorId.equals('').not(),
      );
  }

  /// Vendor ids with at least one active purchase order still in play — draft
  /// or sent, i.e. not yet accepted / received / cancelled.
  JoinedSelectStatement<HasResultSet, dynamic> _openPurchaseOrderVendorIds(
    String companyId,
  ) {
    final orders = attachedDatabase.purchaseOrders;
    return selectOnly(orders)
      ..addColumns([orders.vendorId])
      ..where(
        orders.companyId.equals(companyId) &
            orders.isDeleted.equals(false) &
            orders.archivedAt.isNull() &
            orders.statusId.isIn([
              PurchaseOrderStatus.draft.wireId,
              PurchaseOrderStatus.sent.wireId,
            ]) &
            orders.vendorId.equals('').not(),
      );
  }

  Stream<List<VendorRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = VendorFieldIds.name,
    bool sortAscending = true,
    Set<String> customValues1 = const {},
    Set<String> customValues2 = const {},
    Set<String> customValues3 = const {},
    Set<String> customValues4 = const {},
  }) {
    final q = select(vendors)..where((v) => v.companyId.equals(companyId));

    if (states.isNotEmpty) {
      q.where(
        (v) => entityStateFilter(
          states: states,
          archivedAt: v.archivedAt,
          isDeleted: v.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final pattern = '%$search%';
      q.where(
        (v) =>
            v.name.like(pattern) |
            v.number.like(pattern) |
            v.displayName.like(pattern) |
            v.idNumber.like(pattern) |
            v.customValue1.like(pattern) |
            v.customValue2.like(pattern) |
            v.customValue3.like(pattern) |
            v.customValue4.like(pattern),
      );
    }

    if (customValues1.isNotEmpty) {
      q.where((v) => v.customValue1.isIn(customValues1.toList()));
    }
    if (customValues2.isNotEmpty) {
      q.where((v) => v.customValue2.isIn(customValues2.toList()));
    }
    if (customValues3.isNotEmpty) {
      q.where((v) => v.customValue3.isIn(customValues3.toList()));
    }
    if (customValues4.isNotEmpty) {
      q.where((v) => v.customValue4.isIn(customValues4.toList()));
    }

    final mode = sortAscending ? OrderingMode.asc : OrderingMode.desc;
    q.orderBy([
      (v) =>
          OrderingTerm(expression: _sortExpression(v, sortField), mode: mode),
      // Always tiebreak on id so paginated reads are stable when the primary
      // sort has duplicates (common for balance=0 or empty number).
      (v) => OrderingTerm(expression: v.id, mode: mode),
    ]);
    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  /// Wire-id → Drift ordering expression. Mirrors `ClientDao._sortExpression`.
  Expression _sortExpression(Vendors v, String field) {
    assert(
      kVendorColumnIds.contains(field),
      'VendorDao._sortExpression: unknown column id "$field". '
      'Validate against kVendorColumnIds in the ViewModel before calling.',
    );
    if (!kVendorColumnIds.contains(field)) {
      return v.name; // release-mode safety net for the assert above.
    }
    switch (field) {
      case VendorFieldIds.name:
        return v.name;
      case VendorFieldIds.number:
        return v.number;
      case VendorFieldIds.updatedAt:
        return v.updatedAt;
      case VendorFieldIds.createdAt:
        return v.createdAt;
      case VendorFieldIds.archivedAt:
        return v.archivedAt;
      case VendorFieldIds.city:
        return v.city;
      case VendorFieldIds.idNumber:
        return v.idNumber;
      case VendorFieldIds.vatNumber:
        return v.vatNumber;
      case VendorFieldIds.phone:
        return v.phone;
      case VendorFieldIds.custom1:
        return v.customValue1;
      case VendorFieldIds.custom2:
        return v.customValue2;
      case VendorFieldIds.custom3:
        return v.customValue3;
      case VendorFieldIds.custom4:
        return v.customValue4;
    }
    // Contact columns are derived from the `contacts[]` array — their column
    // ids are not payload keys, so the generic fallback below returned NULL
    // for every row and the sort silently collapsed to the id tiebreak.
    // Vendors have no denormalized contact column, so these sort on
    // `contacts[0]`: an approximation vs the displayed primary contact, and
    // the same one the server makes.
    switch (field) {
      case VendorFieldIds.contactName:
        return CustomExpression<String>(
          "LOWER(TRIM(COALESCE(json_extract(payload, '\$.contacts[0].first_name'), '') "
          "|| ' ' || COALESCE(json_extract(payload, '\$.contacts[0].last_name'), '')))",
        );
      case VendorFieldIds.contactEmail:
        return CustomExpression<String>(
          "LOWER(COALESCE(json_extract(payload, '\$.contacts[0].email'), ''))",
        );
      case VendorFieldIds.lastLogin:
        // `Vendor.toApiJson` emits `last_login` only when non-null while
        // `VendorApi` always emits 0, so never-logged-in vendors are 0 when
        // server-synced and ABSENT after a local edit — COALESCE keeps both
        // spellings in one group. Same guard client already has.
        return CustomExpression<int>(
          "COALESCE(json_extract(payload, '\$.last_login'), 0)",
        );
      case VendorFieldIds.contactPhone:
        return CustomExpression<String>(
          "COALESCE(json_extract(payload, '\$.contacts[0].phone'), '')",
        );
    }
    // Generic payload fallback. `LOWER(COALESCE(...))` matches every explicit
    // case above: without it SQLite's BINARY collation sorts "Zurich" before
    // "amsterdam" on City / State / Website / Notes, while the adjacent Name
    // column on the same screen sorts case-insensitively.
    return CustomExpression<String>(
      "LOWER(COALESCE(json_extract(payload, '\$.$field'), ''))",
    );
  }

  /// Stream `(id, name)` pairs for active vendors in this company. Cheap
  /// alternative to `watchPage` for picker dropdowns (Expense form's vendor
  /// picker, downstream entity navigation) and chip name resolution —
  /// selects only the two columns needed and orders by display name.
  Stream<List<({String id, String name})>> watchActiveNames({
    required String companyId,
  }) {
    final q = selectOnly(vendors)
      ..addColumns([vendors.id, vendors.displayName])
      ..where(
        vendors.companyId.equals(companyId) &
            vendors.isDeleted.equals(false) &
            vendors.archivedAt.isNull(),
      )
      ..orderBy([OrderingTerm(expression: vendors.displayName.lower())]);
    return q
        .map((row) {
          return (
            id: row.read<String>(vendors.id) ?? '',
            name: row.read<String>(vendors.displayName) ?? '',
          );
        })
        .watch()
        .distinctRows();
  }

  /// Distinct non-empty values of `custom_value{columnIndex}` for the given
  /// company, ordered ascending. Drives the bottom-sheet option list for
  /// custom-field filtering — same shape as `ClientDao.watchDistinctCustomValues`.
  Stream<List<String>> watchDistinctCustomValues({
    required String companyId,
    required int columnIndex,
  }) {
    final column = switch (columnIndex) {
      1 => vendors.customValue1,
      2 => vendors.customValue2,
      3 => vendors.customValue3,
      4 => vendors.customValue4,
      _ => throw ArgumentError('columnIndex must be 1..4 (got $columnIndex)'),
    };
    final q = selectOnly(vendors, distinct: true)
      ..addColumns([column])
      ..where(vendors.companyId.equals(companyId) & column.equals('').not())
      ..orderBy([OrderingTerm(expression: column)]);
    return q.map((row) => row.read(column)!).watch().distinctRows();
  }
}
