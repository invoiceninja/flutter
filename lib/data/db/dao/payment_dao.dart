import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';
import 'package:admin/data/db/dao/_payload_search.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/payments_table.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/payment_status.dart';

part 'payment_dao.g.dart';

/// Stable field-id constants used by the list ViewModel for column +
/// sort selection. Keep in sync with `PaymentRepository.watchPage`.
class PaymentFieldIds {
  static const String number = 'number';
  static const String date = 'date';
  static const String amount = 'amount';
  static const String applied = 'applied';
  static const String refunded = 'refunded';
  static const String clientId = 'client_id';
  static const String vendorId = 'vendor_id';
  static const String projectId = 'project_id';
  static const String currencyId = 'currency_id';
  static const String exchangeCurrencyId = 'exchange_currency_id';
  static const String typeId = 'type_id';
  static const String statusId = 'status_id';
  static const String gatewayId = 'company_gateway_id';
  static const String transactionReference = 'transaction_reference';
  static const String privateNotes = 'private_notes';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
  static const String customValue1 = 'custom_value1';
  static const String customValue2 = 'custom_value2';
  static const String customValue3 = 'custom_value3';
  static const String customValue4 = 'custom_value4';
}

@DriftAccessor(tables: [Payments])
class PaymentDao extends BaseEntityDao<$PaymentsTable, PaymentRow>
    with _$PaymentDaoMixin {
  PaymentDao(super.db);

  @override
  $PaymentsTable get table => payments;
  @override
  GeneratedColumn<String> get idColumn => payments.id;
  @override
  GeneratedColumn<String> get companyIdColumn => payments.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => payments.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => payments.isDirty;

  /// Windowed list watch. Filters: state (active/archived/deleted), free-text
  /// search across number + transaction_reference + private_notes (payload
  /// JSON extract), optional status set, optional has-unapplied-funds chip
  /// (filters to rows where `applied < amount` — Decimal comparison via
  /// CAST). Sort field is one of [PaymentFieldIds].
  Stream<List<PaymentRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Set<String> statusIds = const {},
    bool hasUnappliedFundsOnly = false,
    String sortField = PaymentFieldIds.date,
    bool sortAscending = false,
    String? clientId,
    Set<String> clientIds = const {},
    Set<String> customValues1 = const {},
    Set<String> customValues2 = const {},
    Set<String> customValues3 = const {},
    Set<String> customValues4 = const {},
    String? dateStart,
    String? dateEnd,
  }) {
    final q = select(payments)..where((p) => p.companyId.equals(companyId));

    if (clientId != null && clientId.isNotEmpty) {
      q.where((p) => p.clientId.equals(clientId));
    }
    if (clientIds.isNotEmpty) {
      q.where((p) => p.clientId.isIn(clientIds.toList()));
    }
    // Workspace list: hide rows of soft-deleted clients (offline parity with
    // the server `without_deleted_clients` filter). Suppressed under an explicit
    // client scope so a client's detail tabs still show its rows.
    if ((clientId == null || clientId.isEmpty) && clientIds.isEmpty) {
      q.where(
        (p) =>
            clientNotDeletedFilter(clientId: p.clientId, companyId: companyId),
      );
    }
    // Custom-field filters mirror server `custom_value1..4` (exact-set local
    // predicate is source of truth — same idiom as ClientDao/InvoiceDao).
    if (customValues1.isNotEmpty) {
      q.where((p) => p.customValue1.isIn(customValues1.toList()));
    }
    if (customValues2.isNotEmpty) {
      q.where((p) => p.customValue2.isIn(customValues2.toList()));
    }
    if (customValues3.isNotEmpty) {
      q.where((p) => p.customValue3.isIn(customValues3.toList()));
    }
    if (customValues4.isNotEmpty) {
      q.where((p) => p.customValue4.isIn(customValues4.toList()));
    }
    if (dateStart != null && dateEnd != null) {
      q.where((p) => p.date.isBetweenValues(dateStart, dateEnd));
    }

    if (states.isNotEmpty) {
      q.where(
        (p) => entityStateFilter(
          states: states,
          archivedAt: p.archivedAt,
          isDeleted: p.isDeleted,
        ),
      );
    }

    if (statusIds.isNotEmpty) {
      // The two virtual statuses (`-1` / `-2`) translate to a balance
      // predicate on `applied < amount` since the server never persists
      // them. Strip them out of the IN clause and OR in the predicate.
      final hasVirtual =
          statusIds.contains(kPaymentStatusUnapplied) ||
          statusIds.contains(kPaymentStatusPartiallyUnapplied);
      final persisted = statusIds
          .where(
            (id) =>
                id != kPaymentStatusUnapplied &&
                id != kPaymentStatusPartiallyUnapplied,
          )
          .toList(growable: false);
      q.where((p) {
        Expression<bool>? clause;
        if (persisted.isNotEmpty) {
          clause = p.statusId.isIn(persisted);
        }
        if (hasVirtual) {
          // Virtual codes (-1 unapplied / -2 partially unapplied) are only
          // reachable from completed or partially-refunded payments — same
          // gate `Payment.calculatedStatusId` enforces. Without this filter,
          // pending / failed / cancelled rows with `applied < amount`
          // (which is just the normal pre-completion state) would leak in.
          final completedish =
              p.statusId.equals(kPaymentStatusCompleted) |
              p.statusId.equals(kPaymentStatusPartiallyRefunded);
          final unapplied =
              completedish &
              p.amount.cast<double>().isBiggerThan(p.applied.cast<double>());
          clause = clause == null ? unapplied : clause | unapplied;
        }
        return clause ?? const Constant(true);
      });
    }

    if (hasUnappliedFundsOnly) {
      q.where(
        (p) => p.amount.cast<double>().isBiggerThan(p.applied.cast<double>()),
      );
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where(
        (p) =>
            p.number.lower().like(needle) |
            p.transactionReference.lower().like(needle) |
            p.privateNotesLikePayload(needle) |
            clientNameMatchesFilter(
              clientId: p.clientId,
              companyId: companyId,
              needle: needle,
            ),
      );
    }

    q.orderBy([
      (p) => OrderingTerm(
        expression: _sortExpression(p, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (p) => OrderingTerm(expression: p.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(Payments p, String field) {
    switch (field) {
      case PaymentFieldIds.number:
        return p.number.lower();
      case PaymentFieldIds.date:
        return p.date;
      case PaymentFieldIds.amount:
        return p.amount.cast<double>();
      case PaymentFieldIds.applied:
        return p.applied.cast<double>();
      case PaymentFieldIds.refunded:
        return p.refunded.cast<double>();
      case PaymentFieldIds.clientId:
        return p.clientId;
      case PaymentFieldIds.vendorId:
        return p.vendorId;
      case PaymentFieldIds.projectId:
        return p.projectId;
      case PaymentFieldIds.currencyId:
        return p.currencyId;
      case PaymentFieldIds.exchangeCurrencyId:
        return p.exchangeCurrencyId;
      case PaymentFieldIds.typeId:
        return p.typeId;
      case PaymentFieldIds.statusId:
        return p.statusId;
      case PaymentFieldIds.gatewayId:
        return p.companyGatewayId;
      case PaymentFieldIds.transactionReference:
        return p.transactionReference.lower();
      case PaymentFieldIds.updatedAt:
        return p.updatedAt;
      case PaymentFieldIds.createdAt:
        return p.createdAt;
      case PaymentFieldIds.customValue1:
        return p.customValue1.lower();
      case PaymentFieldIds.customValue2:
        return p.customValue2.lower();
      case PaymentFieldIds.customValue3:
        return p.customValue3.lower();
      case PaymentFieldIds.customValue4:
        return p.customValue4.lower();
      default:
        throw ArgumentError(
          'Unknown sort field "$field" for Payment — add a case in '
          '_sortExpression or stop exposing it as a sort option.',
        );
    }
  }

  /// Cheap streams used by cross-entity navigation (client / invoice detail
  /// pages → "Linked payments" card). Filters by a single id + excludes
  /// deleted rows.

  Stream<List<PaymentRow>> watchForClient({
    required String companyId,
    required String clientId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(payments)
      ..where(
        (p) => p.companyId.equals(companyId) & p.clientId.equals(clientId),
      );
    if (states.isNotEmpty) {
      q.where(
        (p) => entityStateFilter(
          states: states,
          archivedAt: p.archivedAt,
          isDeleted: p.isDeleted,
        ),
      );
    }
    q.orderBy([
      (p) => OrderingTerm(expression: p.date, mode: OrderingMode.desc),
    ]);
    return q.watch().distinctRows();
  }

  /// Watch payments that reference a given invoice in their `paymentables`
  /// JSON array. Used by the Invoice detail page's "Payments" card.
  Stream<List<PaymentRow>> watchForInvoice({
    required String companyId,
    required String invoiceId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(payments)
      ..where(
        (p) =>
            p.companyId.equals(companyId) &
            p.paymentablesContainsInvoice(invoiceId),
      );
    if (states.isNotEmpty) {
      q.where(
        (p) => entityStateFilter(
          states: states,
          archivedAt: p.archivedAt,
          isDeleted: p.isDeleted,
        ),
      );
    }
    q.orderBy([
      (p) => OrderingTerm(expression: p.date, mode: OrderingMode.desc),
    ]);
    return q.watch().distinctRows();
  }
}

/// Free-text search + paymentables-contains helpers. SQLite's JSON1
/// `json_extract` digs the private_notes out of the `payload` blob;
/// `EXISTS (SELECT 1 FROM json_each(paymentables) ...)` scans the
/// allocations list without normalizing.
extension on Payments {
  Expression<bool> privateNotesLikePayload(String needle) =>
      payloadJsonLike(needle, const ['private_notes']);

  Expression<bool> paymentablesContainsInvoice(String invoiceId) {
    final escaped = invoiceId.replaceAll("'", "''");
    return CustomExpression<bool>(
      "EXISTS (SELECT 1 FROM json_each(COALESCE(paymentables, '[]')) "
      "WHERE json_extract(value, '\$.invoice_id') = '$escaped')",
    );
  }
}
