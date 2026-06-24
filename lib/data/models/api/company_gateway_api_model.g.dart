// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'company_gateway_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FeesAndLimitsApi _$FeesAndLimitsApiFromJson(Map<String, dynamic> json) =>
    _FeesAndLimitsApi(
      minLimit: (json['min_limit'] as num?)?.toDouble() ?? -1.0,
      maxLimit: (json['max_limit'] as num?)?.toDouble() ?? -1.0,
      feeAmount: (json['fee_amount'] as num?)?.toDouble() ?? 0.0,
      feePercent: (json['fee_percent'] as num?)?.toDouble() ?? 0.0,
      feeCap: (json['fee_cap'] as num?)?.toDouble() ?? 0.0,
      feeTaxRate1: (json['fee_tax_rate1'] as num?)?.toDouble() ?? 0.0,
      feeTaxName1: json['fee_tax_name1'] as String? ?? '',
      feeTaxRate2: (json['fee_tax_rate2'] as num?)?.toDouble() ?? 0.0,
      feeTaxName2: json['fee_tax_name2'] as String? ?? '',
      feeTaxRate3: (json['fee_tax_rate3'] as num?)?.toDouble() ?? 0.0,
      feeTaxName3: json['fee_tax_name3'] as String? ?? '',
      adjustFeePercent: json['adjust_fee_percent'] as bool? ?? false,
      isEnabled: json['is_enabled'] as bool? ?? true,
    );

Map<String, dynamic> _$FeesAndLimitsApiToJson(_FeesAndLimitsApi instance) =>
    <String, dynamic>{
      'min_limit': instance.minLimit,
      'max_limit': instance.maxLimit,
      'fee_amount': instance.feeAmount,
      'fee_percent': instance.feePercent,
      'fee_cap': instance.feeCap,
      'fee_tax_rate1': instance.feeTaxRate1,
      'fee_tax_name1': instance.feeTaxName1,
      'fee_tax_rate2': instance.feeTaxRate2,
      'fee_tax_name2': instance.feeTaxName2,
      'fee_tax_rate3': instance.feeTaxRate3,
      'fee_tax_name3': instance.feeTaxName3,
      'adjust_fee_percent': instance.adjustFeePercent,
      'is_enabled': instance.isEnabled,
    };

_CompanyGatewayApi _$CompanyGatewayApiFromJson(
  Map<String, dynamic> json,
) => _CompanyGatewayApi(
  id: json['id'] as String? ?? '',
  gatewayKey: json['gateway_key'] as String? ?? '',
  acceptedCreditCards: (json['accepted_credit_cards'] as num?)?.toInt() ?? 0,
  requireCvv: json['require_cvv'] as bool? ?? false,
  requireBillingAddress: json['require_billing_address'] as bool? ?? false,
  requireShippingAddress: json['require_shipping_address'] as bool? ?? false,
  requireClientName: json['require_client_name'] as bool? ?? false,
  requireClientPhone: json['require_client_phone'] as bool? ?? false,
  requireContactName: json['require_contact_name'] as bool? ?? false,
  requireContactEmail: json['require_contact_email'] as bool? ?? true,
  requirePostalCode: json['require_postal_code'] as bool? ?? true,
  requireCustomValue1: json['require_custom_value1'] as bool? ?? false,
  requireCustomValue2: json['require_custom_value2'] as bool? ?? false,
  requireCustomValue3: json['require_custom_value3'] as bool? ?? false,
  requireCustomValue4: json['require_custom_value4'] as bool? ?? false,
  updateDetails: json['update_details'] as bool? ?? false,
  alwaysShowRequiredFields:
      json['always_show_required_fields'] as bool? ?? true,
  tokenBilling: json['token_billing'] as String? ?? 'off',
  label: json['label'] as String? ?? '',
  config: json['config'] as String? ?? '',
  feesAndLimits: json['fees_and_limits'] == null
      ? const <String, FeesAndLimitsApi>{}
      : _feesAndLimitsFromJson(json['fees_and_limits']),
  testMode: json['test_mode'] as bool? ?? false,
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
  isDeleted: json['is_deleted'] as bool? ?? false,
);

Map<String, dynamic> _$CompanyGatewayApiToJson(_CompanyGatewayApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'gateway_key': instance.gatewayKey,
      'accepted_credit_cards': instance.acceptedCreditCards,
      'require_cvv': instance.requireCvv,
      'require_billing_address': instance.requireBillingAddress,
      'require_shipping_address': instance.requireShippingAddress,
      'require_client_name': instance.requireClientName,
      'require_client_phone': instance.requireClientPhone,
      'require_contact_name': instance.requireContactName,
      'require_contact_email': instance.requireContactEmail,
      'require_postal_code': instance.requirePostalCode,
      'require_custom_value1': instance.requireCustomValue1,
      'require_custom_value2': instance.requireCustomValue2,
      'require_custom_value3': instance.requireCustomValue3,
      'require_custom_value4': instance.requireCustomValue4,
      'update_details': instance.updateDetails,
      'always_show_required_fields': instance.alwaysShowRequiredFields,
      'token_billing': instance.tokenBilling,
      'label': instance.label,
      'config': instance.config,
      'fees_and_limits': instance.feesAndLimits,
      'test_mode': instance.testMode,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'is_deleted': instance.isDeleted,
    };

_CompanyGatewayListApi _$CompanyGatewayListApiFromJson(
  Map<String, dynamic> json,
) => _CompanyGatewayListApi(
  data: json['data'] == null ? const [] : _companyGatewayListData(json['data']),
);

Map<String, dynamic> _$CompanyGatewayListApiToJson(
  _CompanyGatewayListApi instance,
) => <String, dynamic>{'data': instance.data};

_CompanyGatewayItemApi _$CompanyGatewayItemApiFromJson(
  Map<String, dynamic> json,
) => _CompanyGatewayItemApi(
  data: CompanyGatewayApi.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CompanyGatewayItemApiToJson(
  _CompanyGatewayItemApi instance,
) => <String, dynamic>{'data': instance.data};
