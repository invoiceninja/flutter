import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';

part 'expense_api_model.freezed.dart';
part 'expense_api_model.g.dart';

/// Raw JSON shape of an expense as returned by `/api/v1/expenses`.
///
/// Mirrors the server keys exactly so `fromJson` is mechanical. Money fields
/// stay as `Object` (the server flips between number and string) and are
/// parsed via `parseMoney` in [Expense.fromApi]. Tax-rate fields are also
/// `Object` for the same reason — they're parsed to `Decimal` (not `double`)
/// to match Product's precedent + the CI lint test.
@freezed
abstract class ExpenseApi with _$ExpenseApi {
  const factory ExpenseApi({
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
    // Money — Object so number / string are both decoded; parsed via
    // parseMoney in the domain factory.
    @Default('0') Object amount,
    @JsonKey(name: 'foreign_amount') @Default('0') Object foreignAmount,
    @JsonKey(name: 'exchange_rate') @Default('1') Object exchangeRate,
    @JsonKey(name: 'tax_amount1') @Default('0') Object taxAmount1,
    @JsonKey(name: 'tax_amount2') @Default('0') Object taxAmount2,
    @JsonKey(name: 'tax_amount3') @Default('0') Object taxAmount3,
    @JsonKey(name: 'tax_rate1') @Default('0') Object taxRate1,
    @JsonKey(name: 'tax_rate2') @Default('0') Object taxRate2,
    @JsonKey(name: 'tax_rate3') @Default('0') Object taxRate3,
    // Bools
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'should_be_invoiced') @Default(false) bool shouldBeInvoiced,
    @JsonKey(name: 'invoice_documents') @Default(false) bool invoiceDocuments,
    @JsonKey(name: 'uses_inclusive_taxes')
    @Default(false)
    bool usesInclusiveTaxes,
    @JsonKey(name: 'calculate_tax_by_amount')
    @Default(false)
    bool calculateTaxByAmount,
    // Timestamps
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    // Nullable so JSON-omitted (→ null) is distinguishable from
    // JSON-present-and-empty (→ const []). Same convention as `ProjectApi`.
    List<DocumentApi>? documents,
  }) = _ExpenseApi;

  factory ExpenseApi.fromJson(Map<String, dynamic> json) =>
      _$ExpenseApiFromJson(json);
}

/// `GET /expenses` response envelope.
@freezed
abstract class ExpenseListApi with _$ExpenseListApi {
  const factory ExpenseListApi({
    @JsonKey(fromJson: _expenseListData) @Default([]) List<ExpenseApi> data,
  }) = _ExpenseListApi;

  factory ExpenseListApi.fromJson(Map<String, dynamic> json) =>
      _$ExpenseListApiFromJson(json);
}

/// `POST/PUT /expenses/{id}` single-item envelope.
@freezed
abstract class ExpenseItemApi with _$ExpenseItemApi {
  const factory ExpenseItemApi({required ExpenseApi data}) = _ExpenseItemApi;

  factory ExpenseItemApi.fromJson(Map<String, dynamic> json) =>
      _$ExpenseItemApiFromJson(json);
}

List<ExpenseApi> _expenseListData(Object? raw) =>
    tolerantList(raw, ExpenseApi.fromJson, label: 'expense');
