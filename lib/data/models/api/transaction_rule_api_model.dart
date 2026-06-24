import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'transaction_rule_api_model.freezed.dart';
part 'transaction_rule_api_model.g.dart';

/// One rule-criterion row. `search_key` names the transaction field (or
/// `$invoice.…` / `$payment.…` / `$client.…` placeholder for CREDIT rules);
/// `operator` is one of the string operators (`is`, `contains`,
/// `starts_with`, `is_empty`) or numeric operators (`=`, `<`, `<=`, `>`,
/// `>=`, `is_empty`); `value` is the literal to compare against.
@freezed
abstract class RuleCriterionApi with _$RuleCriterionApi {
  @JsonSerializable(includeIfNull: false)
  const factory RuleCriterionApi({
    @JsonKey(name: 'search_key') @Default('') String searchKey,
    @Default('') String operator,
    @Default('') String value,
  }) = _RuleCriterionApi;

  factory RuleCriterionApi.fromJson(Map<String, dynamic> json) =>
      _$RuleCriterionApiFromJson(json);
}

/// Wire shape of `/api/v1/bank_transaction_rules/{id}`.
///
/// `vendor` / `expense_category` are joined records returned only when the
/// list call uses `?include=vendor,expense_category`. They're kept as
/// loose `Map`s so the domain model can extract just the `name` it needs
/// without locking us into the full Vendor / ExpenseCategory shape (which
/// pulls in heavy `Decimal` parsing this surface never touches).
@freezed
abstract class TransactionRuleApi with _$TransactionRuleApi {
  @JsonSerializable(includeIfNull: false)
  const factory TransactionRuleApi({
    @Default('') String id,
    @Default('') String name,
    @JsonKey(name: 'applies_to') @Default('DEBIT') String appliesTo,
    @JsonKey(name: 'matches_on_all') @Default(true) bool matchesOnAll,
    @JsonKey(name: 'auto_convert') @Default(false) bool autoConvert,
    @JsonKey(name: 'vendor_id') @Default('') String vendorId,
    @JsonKey(name: 'category_id') @Default('') String categoryId,
    @Default(<RuleCriterionApi>[]) List<RuleCriterionApi> rules,
    Map<String, dynamic>? vendor,
    @JsonKey(name: 'expense_category') Map<String, dynamic>? expenseCategory,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
  }) = _TransactionRuleApi;

  factory TransactionRuleApi.fromJson(Map<String, dynamic> json) =>
      _$TransactionRuleApiFromJson(json);
}

/// `GET /bank_transaction_rules` envelope.
@freezed
abstract class TransactionRuleListApi with _$TransactionRuleListApi {
  const factory TransactionRuleListApi({
    @JsonKey(fromJson: _transactionRuleListData)
    @Default([])
    List<TransactionRuleApi> data,
  }) = _TransactionRuleListApi;

  factory TransactionRuleListApi.fromJson(Map<String, dynamic> json) =>
      _$TransactionRuleListApiFromJson(json);
}

/// `POST/PUT /bank_transaction_rules/{id}` single-item envelope.
@freezed
abstract class TransactionRuleItemApi with _$TransactionRuleItemApi {
  const factory TransactionRuleItemApi({required TransactionRuleApi data}) =
      _TransactionRuleItemApi;

  factory TransactionRuleItemApi.fromJson(Map<String, dynamic> json) =>
      _$TransactionRuleItemApiFromJson(json);
}

List<TransactionRuleApi> _transactionRuleListData(Object? raw) =>
    tolerantList(raw, TransactionRuleApi.fromJson, label: 'transaction_rule');
