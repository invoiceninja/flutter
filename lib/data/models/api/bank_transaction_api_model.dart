import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/models/api/tag_api_model.dart';

part 'bank_transaction_api_model.freezed.dart';
part 'bank_transaction_api_model.g.dart';

/// Wire shape of `/api/v1/bank_transactions/{id}`.
@freezed
abstract class BankTransactionApi with _$BankTransactionApi {
  @JsonSerializable(includeIfNull: false)
  const factory BankTransactionApi({
    @Default('') String id,
    @Default('0') Object amount,
    @JsonKey(name: 'currency_id') @Default('') String currencyId,
    @JsonKey(name: 'category_type') @Default('') String categoryType,
    @JsonKey(name: 'base_type') @Default('') String baseType,
    @Default('') String date,
    @JsonKey(name: 'bank_integration_id') @Default('') String bankIntegrationId,
    @Default('') String description,
    @JsonKey(name: 'status_id') @Default('1') String statusId,
    @JsonKey(name: 'ninja_category_id') @Default('') String ninjaCategoryId,
    @JsonKey(name: 'invoice_ids') @Default('') String invoiceIds,
    @JsonKey(name: 'payment_id') @Default('') String paymentId,
    @JsonKey(name: 'expense_id') @Default('') String expenseId,
    @JsonKey(name: 'vendor_id') @Default('') String vendorId,
    // Provider transaction id — int on the wire, kept as Object so we
    // can accept either number or string.
    @JsonKey(name: 'transaction_id') @Default(0) Object transactionId,
    @JsonKey(name: 'bank_transaction_rule_id')
    @Default('')
    String bankTransactionRuleId,
    @JsonKey(name: 'participant_name') @Default('') String participantName,
    @Default('') String participant,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'tags')
    @EmbeddedTagsConverter()
    @Default(<TagRefApi>[])
    List<TagRefApi> tags,
  }) = _BankTransactionApi;

  factory BankTransactionApi.fromJson(Map<String, dynamic> json) =>
      _$BankTransactionApiFromJson(json);
}

/// `GET /bank_transactions` envelope.
@freezed
abstract class BankTransactionListApi with _$BankTransactionListApi {
  const factory BankTransactionListApi({
    @JsonKey(fromJson: _bankTransactionListData)
    @Default([])
    List<BankTransactionApi> data,
  }) = _BankTransactionListApi;

  factory BankTransactionListApi.fromJson(Map<String, dynamic> json) =>
      _$BankTransactionListApiFromJson(json);
}

/// `POST/PUT /bank_transactions/{id}` single-item envelope.
@freezed
abstract class BankTransactionItemApi with _$BankTransactionItemApi {
  const factory BankTransactionItemApi({required BankTransactionApi data}) =
      _BankTransactionItemApi;

  factory BankTransactionItemApi.fromJson(Map<String, dynamic> json) =>
      _$BankTransactionItemApiFromJson(json);
}

List<BankTransactionApi> _bankTransactionListData(Object? raw) =>
    tolerantList(raw, BankTransactionApi.fromJson, label: 'bank_transaction');
