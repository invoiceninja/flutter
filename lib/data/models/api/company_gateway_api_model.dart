import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'company_gateway_api_model.freezed.dart';
part 'company_gateway_api_model.g.dart';

/// Per-payment-type fees & limits record. Stored on `CompanyGatewayApi` as
/// `Map<gatewayTypeId, FeesAndLimitsApi>` under the `fees_and_limits` key.
///
/// Sentinel rules:
///   * `minLimit` / `maxLimit` of `-1.0` means "no limit"; `0` would block
///     all transactions.
///   * `isEnabled` controls whether the gateway accepts this payment type at
///     all — the legacy admin-portal also calls this the "enabled gateway
///     method" toggle on the Settings tab.
@freezed
abstract class FeesAndLimitsApi with _$FeesAndLimitsApi {
  @JsonSerializable(includeIfNull: false)
  const factory FeesAndLimitsApi({
    @JsonKey(name: 'min_limit') @Default(-1.0) double minLimit,
    @JsonKey(name: 'max_limit') @Default(-1.0) double maxLimit,
    @JsonKey(name: 'fee_amount') @Default(0.0) double feeAmount,
    @JsonKey(name: 'fee_percent') @Default(0.0) double feePercent,
    @JsonKey(name: 'fee_cap') @Default(0.0) double feeCap,
    @JsonKey(name: 'fee_tax_rate1') @Default(0.0) double feeTaxRate1,
    @JsonKey(name: 'fee_tax_name1') @Default('') String feeTaxName1,
    @JsonKey(name: 'fee_tax_rate2') @Default(0.0) double feeTaxRate2,
    @JsonKey(name: 'fee_tax_name2') @Default('') String feeTaxName2,
    @JsonKey(name: 'fee_tax_rate3') @Default(0.0) double feeTaxRate3,
    @JsonKey(name: 'fee_tax_name3') @Default('') String feeTaxName3,
    @JsonKey(name: 'adjust_fee_percent') @Default(false) bool adjustFeePercent,
    @JsonKey(name: 'is_enabled') @Default(true) bool isEnabled,
  }) = _FeesAndLimitsApi;

  factory FeesAndLimitsApi.fromJson(Map<String, dynamic> json) =>
      _$FeesAndLimitsApiFromJson(json);
}

/// PHP's `json_encode` serializes an empty associative array as `[]` instead
/// of `{}`. The strict generated parser crashes on the `Map` cast — coerce
/// a non-Map value to an empty map; otherwise rebuild each entry through
/// `FeesAndLimitsApi.fromJson`.
Map<String, FeesAndLimitsApi> _feesAndLimitsFromJson(Object? value) {
  if (value is Map) {
    return value.map(
      (k, v) => MapEntry(
        k.toString(),
        FeesAndLimitsApi.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
    );
  }
  return const <String, FeesAndLimitsApi>{};
}

/// Wire shape of `/api/v1/company_gateways/{id}`.
///
/// `config` carries credentials as a JSON-encoded string. The domain model's
/// `parsedConfig` getter decodes it lazily — never reach for `jsonDecode`
/// directly on the wire field.
///
/// `feesAndLimits` is keyed by `GatewayType.id` (e.g. "1" for credit_card).
/// Adding or removing a key flips that payment method on/off for this
/// gateway; the value's `is_enabled` further gates without losing fee data.
@freezed
abstract class CompanyGatewayApi with _$CompanyGatewayApi {
  @JsonSerializable(includeIfNull: false)
  const factory CompanyGatewayApi({
    @Default('') String id,
    @JsonKey(name: 'gateway_key') @Default('') String gatewayKey,
    @JsonKey(name: 'accepted_credit_cards') @Default(0) int acceptedCreditCards,
    @JsonKey(name: 'require_cvv') @Default(false) bool requireCvv,
    @JsonKey(name: 'require_billing_address')
    @Default(false)
    bool requireBillingAddress,
    @JsonKey(name: 'require_shipping_address')
    @Default(false)
    bool requireShippingAddress,
    @JsonKey(name: 'require_client_name')
    @Default(false)
    bool requireClientName,
    @JsonKey(name: 'require_client_phone')
    @Default(false)
    bool requireClientPhone,
    @JsonKey(name: 'require_contact_name')
    @Default(false)
    bool requireContactName,
    @JsonKey(name: 'require_contact_email')
    @Default(true)
    bool requireContactEmail,
    @JsonKey(name: 'require_postal_code') @Default(true) bool requirePostalCode,
    @JsonKey(name: 'require_custom_value1')
    @Default(false)
    bool requireCustomValue1,
    @JsonKey(name: 'require_custom_value2')
    @Default(false)
    bool requireCustomValue2,
    @JsonKey(name: 'require_custom_value3')
    @Default(false)
    bool requireCustomValue3,
    @JsonKey(name: 'require_custom_value4')
    @Default(false)
    bool requireCustomValue4,
    @JsonKey(name: 'update_details') @Default(false) bool updateDetails,
    @JsonKey(name: 'always_show_required_fields')
    @Default(true)
    bool alwaysShowRequiredFields,
    @JsonKey(name: 'token_billing') @Default('off') String tokenBilling,
    @Default('') String label,
    @Default('') String config,
    @JsonKey(name: 'fees_and_limits', fromJson: _feesAndLimitsFromJson)
    @Default(<String, FeesAndLimitsApi>{})
    Map<String, FeesAndLimitsApi> feesAndLimits,
    @JsonKey(name: 'test_mode') @Default(false) bool testMode,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
  }) = _CompanyGatewayApi;

  factory CompanyGatewayApi.fromJson(Map<String, dynamic> json) =>
      _$CompanyGatewayApiFromJson(json);
}

/// `GET /company_gateways` envelope.
@freezed
abstract class CompanyGatewayListApi with _$CompanyGatewayListApi {
  const factory CompanyGatewayListApi({
    @JsonKey(fromJson: _companyGatewayListData)
    @Default([])
    List<CompanyGatewayApi> data,
  }) = _CompanyGatewayListApi;

  factory CompanyGatewayListApi.fromJson(Map<String, dynamic> json) =>
      _$CompanyGatewayListApiFromJson(json);
}

/// `POST/PUT /company_gateways/{id}` single-item envelope.
@freezed
abstract class CompanyGatewayItemApi with _$CompanyGatewayItemApi {
  const factory CompanyGatewayItemApi({required CompanyGatewayApi data}) =
      _CompanyGatewayItemApi;

  factory CompanyGatewayItemApi.fromJson(Map<String, dynamic> json) =>
      _$CompanyGatewayItemApiFromJson(json);
}

List<CompanyGatewayApi> _companyGatewayListData(Object? raw) =>
    tolerantList(raw, CompanyGatewayApi.fromJson, label: 'company_gateway');
