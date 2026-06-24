// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bank_account_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BankAccountApi _$BankAccountApiFromJson(Map<String, dynamic> json) =>
    _BankAccountApi(
      id: json['id'] as String? ?? '',
      bankAccountName: json['bank_account_name'] as String? ?? '',
      bankAccountStatus: json['bank_account_status'] as String? ?? '',
      bankAccountType: json['bank_account_type'] as String? ?? '',
      providerName: json['provider_name'] as String? ?? '',
      balance: json['balance'] as Object? ?? '0',
      currency: json['currency'] as String? ?? '',
      fromDate: json['from_date'] as String? ?? '',
      autoSync: json['auto_sync'] as bool? ?? false,
      disabledUpstream: json['disabled_upstream'] as bool? ?? false,
      integrationType: json['integration_type'] as String? ?? '',
      nordigenInstitutionId: json['nordigen_institution_id'] as String? ?? '',
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$BankAccountApiToJson(_BankAccountApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bank_account_name': instance.bankAccountName,
      'bank_account_status': instance.bankAccountStatus,
      'bank_account_type': instance.bankAccountType,
      'provider_name': instance.providerName,
      'balance': instance.balance,
      'currency': instance.currency,
      'from_date': instance.fromDate,
      'auto_sync': instance.autoSync,
      'disabled_upstream': instance.disabledUpstream,
      'integration_type': instance.integrationType,
      'nordigen_institution_id': instance.nordigenInstitutionId,
      'is_deleted': instance.isDeleted,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
    };

_BankAccountListApi _$BankAccountListApiFromJson(Map<String, dynamic> json) =>
    _BankAccountListApi(
      data: json['data'] == null
          ? const []
          : _bankAccountListData(json['data']),
    );

Map<String, dynamic> _$BankAccountListApiToJson(_BankAccountListApi instance) =>
    <String, dynamic>{'data': instance.data};

_BankAccountItemApi _$BankAccountItemApiFromJson(Map<String, dynamic> json) =>
    _BankAccountItemApi(
      data: BankAccountApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BankAccountItemApiToJson(_BankAccountItemApi instance) =>
    <String, dynamic>{'data': instance.data};
