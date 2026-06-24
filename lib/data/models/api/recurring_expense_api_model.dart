import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';

part 'recurring_expense_api_model.freezed.dart';
part 'recurring_expense_api_model.g.dart';

/// Raw JSON shape of a recurring expense as returned by
/// `/api/v1/recurring_expenses`.
///
/// Mirrors `ExpenseApi` field-for-field plus the recurring schedule deltas
/// (`frequency_id`, `remaining_cycles`, `next_send_date`, `last_sent_date`,
/// `status_id`, and the optional `recurring_dates` array surfaced when the
/// caller sets `?show_dates=true`). Money fields stay as `Object` and are
/// parsed via `parseMoney` in the domain factory.
@freezed
abstract class RecurringExpenseApi with _$RecurringExpenseApi {
  const factory RecurringExpenseApi({
    @Default('') String id,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'assigned_user_id') @Default('') String assignedUserId,
    @JsonKey(name: 'vendor_id') @Default('') String vendorId,
    @JsonKey(name: 'invoice_id') @Default('') String invoiceId,
    @JsonKey(name: 'client_id') @Default('') String clientId,
    @JsonKey(name: 'bank_id') @Default('') String bankId,
    @JsonKey(name: 'invoice_currency_id') @Default('') String invoiceCurrencyId,
    @JsonKey(name: 'expense_currency_id') @Default('') String expenseCurrencyId,
    @JsonKey(name: 'currency_id') @Default('') String currencyId,
    @JsonKey(name: 'category_id') @Default('') String categoryId,
    @JsonKey(name: 'payment_type_id') @Default('') String paymentTypeId,
    @JsonKey(name: 'recurring_expense_id')
    @Default('')
    String recurringExpenseId,
    @JsonKey(name: 'private_notes') @Default('') String privateNotes,
    @JsonKey(name: 'public_notes') @Default('') String publicNotes,
    @JsonKey(name: 'transaction_reference')
    @Default('')
    String transactionReference,
    @JsonKey(name: 'transaction_id') @Default('') String transactionId,
    @Default('') String date,
    @Default('') String number,
    @JsonKey(name: 'payment_date') @Default('') String paymentDate,
    @JsonKey(name: 'custom_value1') @Default('') String customValue1,
    @JsonKey(name: 'custom_value2') @Default('') String customValue2,
    @JsonKey(name: 'custom_value3') @Default('') String customValue3,
    @JsonKey(name: 'custom_value4') @Default('') String customValue4,
    @JsonKey(name: 'tax_name1') @Default('') String taxName1,
    @JsonKey(name: 'tax_name2') @Default('') String taxName2,
    @JsonKey(name: 'tax_name3') @Default('') String taxName3,
    @JsonKey(name: 'project_id') @Default('') String projectId,
    @JsonKey(name: 'entity_type') @Default('') String entityType,
    // Recurring schedule deltas.
    @JsonKey(name: 'frequency_id') @Default('5') String frequencyId,
    @JsonKey(name: 'remaining_cycles') @Default(-1) int remainingCycles,
    @JsonKey(name: 'next_send_date') @Default('') String nextSendDate,
    @JsonKey(name: 'last_sent_date') @Default('') String lastSentDate,
    @JsonKey(name: 'status_id') String? statusId,
    // Only populated when the server replies with `?show_dates=true`.
    @JsonKey(name: 'recurring_dates') List<RecurringDateApi>? recurringDates,
    // Money — Object so number / string are both decoded.
    @Default('0') Object amount,
    @JsonKey(name: 'foreign_amount') @Default('0') Object foreignAmount,
    @JsonKey(name: 'exchange_rate') @Default('1') Object exchangeRate,
    @JsonKey(name: 'tax_amount1') @Default('0') Object taxAmount1,
    @JsonKey(name: 'tax_amount2') @Default('0') Object taxAmount2,
    @JsonKey(name: 'tax_amount3') @Default('0') Object taxAmount3,
    @JsonKey(name: 'tax_rate1') @Default('0') Object taxRate1,
    @JsonKey(name: 'tax_rate2') @Default('0') Object taxRate2,
    @JsonKey(name: 'tax_rate3') @Default('0') Object taxRate3,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'should_be_invoiced') @Default(false) bool shouldBeInvoiced,
    @JsonKey(name: 'invoice_documents') @Default(false) bool invoiceDocuments,
    @JsonKey(name: 'uses_inclusive_taxes')
    @Default(false)
    bool usesInclusiveTaxes,
    @JsonKey(name: 'calculate_tax_by_amount')
    @Default(false)
    bool calculateTaxByAmount,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    List<DocumentApi>? documents,
  }) = _RecurringExpenseApi;

  factory RecurringExpenseApi.fromJson(Map<String, dynamic> json) =>
      _$RecurringExpenseApiFromJson(json);
}

/// One scheduled send date returned in the optional
/// `recurring_dates` array (requested with `?show_dates=true`). The server
/// includes a few previewed `send_date`s so the detail screen can show the
/// next runs without computing them client-side.
@freezed
abstract class RecurringDateApi with _$RecurringDateApi {
  const factory RecurringDateApi({
    @JsonKey(name: 'send_date') @Default('') String sendDate,
  }) = _RecurringDateApi;

  factory RecurringDateApi.fromJson(Map<String, dynamic> json) =>
      _$RecurringDateApiFromJson(json);
}

/// `GET /recurring_expenses` response envelope.
@freezed
abstract class RecurringExpenseListApi with _$RecurringExpenseListApi {
  const factory RecurringExpenseListApi({
    @JsonKey(fromJson: _recurringExpenseListData)
    @Default([])
    List<RecurringExpenseApi> data,
  }) = _RecurringExpenseListApi;

  factory RecurringExpenseListApi.fromJson(Map<String, dynamic> json) =>
      _$RecurringExpenseListApiFromJson(json);
}

/// `POST/PUT /recurring_expenses/{id}` single-item envelope.
@freezed
abstract class RecurringExpenseItemApi with _$RecurringExpenseItemApi {
  const factory RecurringExpenseItemApi({required RecurringExpenseApi data}) =
      _RecurringExpenseItemApi;

  factory RecurringExpenseItemApi.fromJson(Map<String, dynamic> json) =>
      _$RecurringExpenseItemApiFromJson(json);
}

List<RecurringExpenseApi> _recurringExpenseListData(Object? raw) =>
    tolerantList(raw, RecurringExpenseApi.fromJson, label: 'recurring_expense');
