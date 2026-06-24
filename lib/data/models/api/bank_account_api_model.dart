import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'bank_account_api_model.freezed.dart';
part 'bank_account_api_model.g.dart';

/// Wire shape of `/api/v1/bank_integrations/{id}`.
///
/// Money fields stay as `Object` (the server flips between number and
/// string) and are parsed via `parseMoney` in [BankAccount.fromApi].
@freezed
abstract class BankAccountApi with _$BankAccountApi {
  @JsonSerializable(includeIfNull: false)
  const factory BankAccountApi({
    @Default('') String id,
    @JsonKey(name: 'bank_account_name') @Default('') String bankAccountName,
    @JsonKey(name: 'bank_account_status') @Default('') String bankAccountStatus,
    @JsonKey(name: 'bank_account_type') @Default('') String bankAccountType,
    @JsonKey(name: 'provider_name') @Default('') String providerName,
    @Default('0') Object balance,
    @Default('') String currency,
    @JsonKey(name: 'from_date') @Default('') String fromDate,
    @JsonKey(name: 'auto_sync') @Default(false) bool autoSync,
    @JsonKey(name: 'disabled_upstream') @Default(false) bool disabledUpstream,
    @JsonKey(name: 'integration_type') @Default('') String integrationType,
    @JsonKey(name: 'nordigen_institution_id')
    @Default('')
    String nordigenInstitutionId,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
  }) = _BankAccountApi;

  factory BankAccountApi.fromJson(Map<String, dynamic> json) =>
      _$BankAccountApiFromJson(json);
}

/// `GET /bank_integrations` envelope.
@freezed
abstract class BankAccountListApi with _$BankAccountListApi {
  const factory BankAccountListApi({
    @JsonKey(fromJson: _bankAccountListData)
    @Default([])
    List<BankAccountApi> data,
  }) = _BankAccountListApi;

  factory BankAccountListApi.fromJson(Map<String, dynamic> json) =>
      _$BankAccountListApiFromJson(json);
}

/// `POST/PUT /bank_integrations/{id}` single-item envelope.
@freezed
abstract class BankAccountItemApi with _$BankAccountItemApi {
  const factory BankAccountItemApi({required BankAccountApi data}) =
      _BankAccountItemApi;

  factory BankAccountItemApi.fromJson(Map<String, dynamic> json) =>
      _$BankAccountItemApiFromJson(json);
}

List<BankAccountApi> _bankAccountListData(Object? raw) =>
    tolerantList(raw, BankAccountApi.fromJson, label: 'bank_account');
