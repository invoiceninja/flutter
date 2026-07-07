import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/payment_api_model.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/payment_status.dart';

part 'payment.freezed.dart';

/// Clean domain model the UI consumes. `Payment.fromApi(...)` walks the
/// raw [PaymentApi] DTO. The `isDirty` flag is local-only — `fromApi`
/// defaults it to `false`, and [PaymentRepository._fromRow] overlays the
/// Drift row's value so unsaved edits survive app restart.
///
/// Money is `Decimal` (never `double`). Date-only fields use the custom
/// [Date] type; timestamps stay as `DateTime`.
@freezed
abstract class Payment with _$Payment {
  const factory Payment({
    required String id,
    required String number,
    required String statusId,
    required String typeId,
    required String clientId,
    required String clientContactId,
    required String companyGatewayId,
    required String gatewayTypeId,
    required String projectId,
    required String vendorId,
    required String invitationId,
    required String currencyId,
    required String exchangeCurrencyId,
    required String transactionReference,
    required String transactionId,
    required String privateNotes,
    required String customValue1,
    required String customValue2,
    required String customValue3,
    required String customValue4,
    required String userId,
    required String createdUserId,
    required String assignedUserId,
    required Date? date,
    required Decimal amount,
    required Decimal applied,
    required Decimal refunded,
    required Decimal exchangeRate,
    required bool isManual,
    required bool isDeleted,
    required DateTime updatedAt,
    required DateTime createdAt,
    required DateTime? archivedAt,
    @Default(<Paymentable>[]) List<Paymentable> paymentables,
    @Default(<PaymentInvoiceRef>[]) List<PaymentInvoiceRef> invoices,
    @Default(<PaymentCreditRef>[]) List<PaymentCreditRef> credits,
    @Default(<Document>[]) List<Document> documents,
    @Default(false) bool isDirty,
  }) = _Payment;

  factory Payment.fromApi(PaymentApi a) => Payment(
    id: a.id,
    number: a.number,
    statusId: a.statusId,
    typeId: a.typeId,
    clientId: a.clientId,
    clientContactId: a.clientContactId,
    companyGatewayId: a.companyGatewayId,
    gatewayTypeId: a.gatewayTypeId,
    projectId: a.projectId,
    vendorId: a.vendorId,
    invitationId: a.invitationId,
    currencyId: a.currencyId,
    exchangeCurrencyId: a.exchangeCurrencyId,
    transactionReference: a.transactionReference,
    transactionId: a.transactionId,
    privateNotes: a.privateNotes,
    customValue1: a.customValue1,
    customValue2: a.customValue2,
    customValue3: a.customValue3,
    customValue4: a.customValue4,
    // `created_user_id` is the canonical wire field on most responses, but
    // some endpoints only return `user_id`; treat either as the creator.
    userId: a.userId,
    createdUserId: a.createdUserId.isNotEmpty ? a.createdUserId : a.userId,
    assignedUserId: a.assignedUserId,
    date: Date.tryParse(a.date),
    amount: parseMoney(a.amount),
    applied: parseMoney(a.applied),
    refunded: parseMoney(a.refunded),
    exchangeRate: parseMoney(a.exchangeRate),
    isManual: a.isManual,
    isDeleted: a.isDeleted,
    updatedAt: epochSecondsToUtc(a.updatedAt),
    createdAt: epochSecondsToUtc(a.createdAt),
    archivedAt: epochSecondsToUtcOrNull(a.archivedAt),
    paymentables: (a.paymentables ?? const <PaymentableApi>[])
        .map(Paymentable.fromApi)
        .toList(growable: false),
    invoices: (a.invoices ?? const <PaymentInvoiceRefApi>[])
        .map(PaymentInvoiceRef.fromApi)
        .toList(growable: false),
    credits: (a.credits ?? const <PaymentCreditRefApi>[])
        .map(PaymentCreditRef.fromApi)
        .toList(growable: false),
    documents: mapDocuments(a.documents),
  );
}

/// One row in a payment's allocations list. `invoiceId` and `creditId` are
/// mutually exclusive — exactly one is set.
@freezed
abstract class Paymentable with _$Paymentable {
  const factory Paymentable({
    @Default('') String id,
    @Default('') String invoiceId,
    @Default('') String creditId,
    required Decimal amount,
    required Decimal refunded,
    @Default(0) int createdAt,
    @Default(0) int updatedAt,
    @Default(0) int archivedAt,
  }) = _Paymentable;

  factory Paymentable.fromApi(PaymentableApi a) => Paymentable(
    id: a.id,
    invoiceId: a.invoiceId,
    creditId: a.creditId,
    amount: parseMoney(a.amount),
    refunded: parseMoney(a.refunded),
    createdAt: a.createdAt,
    updatedAt: a.updatedAt,
    archivedAt: a.archivedAt,
  );
}

/// Lightweight invoice reference for the refund flow.
@freezed
abstract class PaymentInvoiceRef with _$PaymentInvoiceRef {
  const factory PaymentInvoiceRef({
    @Default('') String id,
    @Default('') String number,
    required Decimal amount,
    required Decimal balance,
    required Decimal paidToDate,
  }) = _PaymentInvoiceRef;

  factory PaymentInvoiceRef.fromApi(PaymentInvoiceRefApi a) =>
      PaymentInvoiceRef(
        id: a.id,
        number: a.number,
        amount: parseMoney(a.amount),
        balance: parseMoney(a.balance),
        paidToDate: parseMoney(a.paidToDate),
      );
}

/// Lightweight credit reference for the refund / apply flows.
@freezed
abstract class PaymentCreditRef with _$PaymentCreditRef {
  const factory PaymentCreditRef({
    @Default('') String id,
    @Default('') String number,
    required Decimal amount,
    required Decimal balance,
  }) = _PaymentCreditRef;

  factory PaymentCreditRef.fromApi(PaymentCreditRefApi a) => PaymentCreditRef(
    id: a.id,
    number: a.number,
    amount: parseMoney(a.amount),
    balance: parseMoney(a.balance),
  );
}

/// Computed status + derived money totals. Mirrors admin-portal
/// `payment_model.dart` derivations so list + detail surfaces agree.
extension PaymentStatusExt on Payment {
  /// Returns the displayable status id, applying the two virtual states:
  ///   * `-2` partially unapplied  → some but not all applied
  ///   * `-1` unapplied             → nothing applied yet
  /// Otherwise returns the persisted [statusId].
  String get calculatedStatusId {
    final base = statusId;
    // Only completed / partially-refunded payments can carry unapplied funds.
    if (base != kPaymentStatusCompleted &&
        base != kPaymentStatusPartiallyRefunded) {
      return base;
    }
    if (applied == Decimal.zero && amount > Decimal.zero) {
      return kPaymentStatusUnapplied;
    }
    if (applied < amount) {
      return kPaymentStatusPartiallyUnapplied;
    }
    return base;
  }

  /// Amount still available to refund.
  Decimal get refundable => amount - refunded;

  /// Funds present but not yet allocated to an invoice.
  Decimal get unapplied => amount - applied;

  bool get hasUnappliedFunds => unapplied > Decimal.zero;

  /// `exchange_rate == 0` is the legacy "no conversion" sentinel; treat it as
  /// identity (1) for display math, mirroring [Expense.effectiveExchangeRate].
  /// The wire payload still sends the raw `exchange_rate`.
  Decimal get effectiveExchangeRate =>
      exchangeRate == Decimal.zero ? Decimal.one : exchangeRate;

  /// Whether this payment is allocated to at least one invoice. The refund
  /// screen can only refund against invoice allocations (matching React), so
  /// the Refund action is gated on this to avoid offering an action that
  /// dead-ends for an unapplied / client-account payment.
  bool get hasInvoiceAllocations =>
      paymentables.any((pa) => pa.invoiceId.isNotEmpty);

  bool get canRefund =>
      refundable > Decimal.zero &&
      (statusId == kPaymentStatusCompleted ||
          statusId == kPaymentStatusPartiallyRefunded);
}

/// Serialize back to the JSON shape the server expects on
/// `POST/PUT /payments`. The refund + apply flows have their own bodies
/// (see [PaymentsApi]).
extension PaymentPayload on Payment {
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) {
    return <String, dynamic>{
      if (preserveTempId || !id.startsWith('tmp_')) 'id': id,
      'number': number,
      'status_id': statusId,
      'type_id': typeId,
      'client_id': clientId,
      'client_contact_id': clientContactId,
      'company_gateway_id': companyGatewayId,
      'gateway_type_id': gatewayTypeId,
      'project_id': projectId,
      'vendor_id': vendorId,
      'invitation_id': invitationId,
      'currency_id': currencyId,
      'exchange_currency_id': exchangeCurrencyId,
      'transaction_reference': transactionReference,
      'transaction_id': transactionId,
      'private_notes': privateNotes,
      'custom_value1': customValue1,
      'custom_value2': customValue2,
      'custom_value3': customValue3,
      'custom_value4': customValue4,
      'user_id': userId,
      'assigned_user_id': assignedUserId,
      'date': date?.toIso() ?? '',
      'amount': amount.toString(),
      'applied': applied.toString(),
      'refunded': refunded.toString(),
      'exchange_rate': exchangeRate.toString(),
      'is_manual': isManual,
      // Allocations apply to invoices/credits ONLY when sent under the
      // `invoices` / `credits` wire keys — the server's StorePaymentRequest
      // rules + PaymentRepository::applyPayment gate every apply on
      // array_key_exists('invoices'|'credits', ...); a `paymentables` array
      // is ignored ($payment->fill() skips the HasMany relation), creating an
      // unapplied payment with the invoices left open. Mirrors React
      // Create.tsx and this app's own apply/refund flows. The per-row id is
      // omitted: applyPayment always inserts fresh Paymentable rows.
      //
      // Defensive filter: drop rows with no target id OR zero amount before
      // serialization. The edit-form UI gates against both, but stray zero-
      // amount rows can creep in from clear-then-save in the allocation editor.
      'invoices': paymentables
          .where((p) => p.invoiceId.isNotEmpty && p.amount > Decimal.zero)
          .map(
            (p) => <String, dynamic>{
              'invoice_id': p.invoiceId,
              'amount': p.amount.toString(),
            },
          )
          .toList(growable: false),
      'credits': paymentables
          .where((p) => p.creditId.isNotEmpty && p.amount > Decimal.zero)
          .map(
            (p) => <String, dynamic>{
              'credit_id': p.creditId,
              'amount': p.amount.toString(),
            },
          )
          .toList(growable: false),
    };
  }
}
