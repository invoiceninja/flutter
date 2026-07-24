import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/models/api/tag_api_model.dart';

part 'payment_api_model.freezed.dart';
part 'payment_api_model.g.dart';

/// Raw JSON shape of a payment as returned by `/api/v1/payments`.
///
/// Mirrors the server keys exactly so `fromJson` is mechanical. Money
/// fields stay as `Object` (the server flips between number and string)
/// and are parsed via `parseMoney` in [Payment.fromApi].
///
/// `paymentables` is the canonical allocations list. `invoices` and
/// `credits` are first-class server includes (`?include=credits`) used by
/// the refund flow to compute per-row refundable amounts — don't try to
/// derive them from `paymentables`.
@freezed
abstract class PaymentApi with _$PaymentApi {
  const factory PaymentApi({
    @Default('') String id,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'created_user_id') @Default('') String createdUserId,
    @JsonKey(name: 'assigned_user_id') @Default('') String assignedUserId,
    @Default('') String number,
    @JsonKey(name: 'status_id') @Default('') String statusId,
    @JsonKey(name: 'type_id') @Default('') String typeId,
    @JsonKey(name: 'client_id') @Default('') String clientId,
    @JsonKey(name: 'client_contact_id') @Default('') String clientContactId,
    @JsonKey(name: 'company_gateway_id') @Default('') String companyGatewayId,
    @JsonKey(name: 'gateway_type_id') @Default('') String gatewayTypeId,
    @JsonKey(name: 'project_id') @Default('') String projectId,
    @JsonKey(name: 'vendor_id') @Default('') String vendorId,
    @JsonKey(name: 'invitation_id') @Default('') String invitationId,
    @JsonKey(name: 'currency_id') @Default('') String currencyId,
    @JsonKey(name: 'exchange_currency_id')
    @Default('')
    String exchangeCurrencyId,
    @JsonKey(name: 'transaction_reference')
    @Default('')
    String transactionReference,
    @JsonKey(name: 'transaction_id') @Default('') String transactionId,
    @JsonKey(name: 'private_notes') @Default('') String privateNotes,
    @JsonKey(name: 'custom_value1') @Default('') String customValue1,
    @JsonKey(name: 'custom_value2') @Default('') String customValue2,
    @JsonKey(name: 'custom_value3') @Default('') String customValue3,
    @JsonKey(name: 'custom_value4') @Default('') String customValue4,
    @Default('') String date,
    // Money — Object so number / string both decode; parsed via parseMoney.
    @Default('0') Object amount,
    @Default('0') Object applied,
    @Default('0') Object refunded,
    @JsonKey(name: 'exchange_rate') @Default('1') Object exchangeRate,
    @JsonKey(name: 'is_manual') @Default(false) bool isManual,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    // Nested allocations + server-include refs. Nullable so JSON-omitted
    // (→ null) is distinguishable from JSON-present-and-empty (→ const []).
    List<PaymentableApi>? paymentables,
    List<PaymentInvoiceRefApi>? invoices,
    List<PaymentCreditRefApi>? credits,
    List<DocumentApi>? documents,
    @JsonKey(name: 'tags')
    @EmbeddedTagsConverter()
    @Default(<TagRefApi>[])
    List<TagRefApi> tags,
  }) = _PaymentApi;

  factory PaymentApi.fromJson(Map<String, dynamic> json) =>
      _$PaymentApiFromJson(json);
}

/// A single invoice or credit allocation belonging to a payment.
///
/// `invoice_id` and `credit_id` are mutually exclusive — exactly one is
/// set per row. `refunded` tracks per-allocation refund (React surfaces
/// this; legacy Flutter omits — keep it for parity).
@freezed
abstract class PaymentableApi with _$PaymentableApi {
  const factory PaymentableApi({
    @Default('') String id,
    @JsonKey(name: 'invoice_id') @Default('') String invoiceId,
    @JsonKey(name: 'credit_id') @Default('') String creditId,
    @Default('0') Object amount,
    @Default('0') Object refunded,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
  }) = _PaymentableApi;

  factory PaymentableApi.fromJson(Map<String, dynamic> json) =>
      _$PaymentableApiFromJson(json);
}

/// Lightweight invoice reference attached to a payment via
/// `?include=invoices`. The refund screen reads `amount` + `balance` to
/// compute per-row refundable amounts; full invoice records live in the
/// invoices repo.
@freezed
abstract class PaymentInvoiceRefApi with _$PaymentInvoiceRefApi {
  const factory PaymentInvoiceRefApi({
    @Default('') String id,
    @Default('') String number,
    @Default('0') Object amount,
    @Default('0') Object balance,
    @JsonKey(name: 'paid_to_date') @Default('0') Object paidToDate,
  }) = _PaymentInvoiceRefApi;

  factory PaymentInvoiceRefApi.fromJson(Map<String, dynamic> json) =>
      _$PaymentInvoiceRefApiFromJson(json);
}

/// Lightweight credit reference attached via `?include=credits`.
@freezed
abstract class PaymentCreditRefApi with _$PaymentCreditRefApi {
  const factory PaymentCreditRefApi({
    @Default('') String id,
    @Default('') String number,
    @Default('0') Object amount,
    @Default('0') Object balance,
  }) = _PaymentCreditRefApi;

  factory PaymentCreditRefApi.fromJson(Map<String, dynamic> json) =>
      _$PaymentCreditRefApiFromJson(json);
}

/// `GET /payments` response envelope.
@freezed
abstract class PaymentListApi with _$PaymentListApi {
  const factory PaymentListApi({
    @JsonKey(fromJson: _paymentListData) @Default([]) List<PaymentApi> data,
  }) = _PaymentListApi;

  factory PaymentListApi.fromJson(Map<String, dynamic> json) =>
      _$PaymentListApiFromJson(json);
}

/// `POST/PUT /payments/{id}` single-item envelope.
@freezed
abstract class PaymentItemApi with _$PaymentItemApi {
  const factory PaymentItemApi({required PaymentApi data}) = _PaymentItemApi;

  factory PaymentItemApi.fromJson(Map<String, dynamic> json) =>
      _$PaymentItemApiFromJson(json);
}

List<PaymentApi> _paymentListData(Object? raw) =>
    tolerantList(raw, PaymentApi.fromJson, label: 'payment');
