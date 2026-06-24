// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_rate_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaxRateApi _$TaxRateApiFromJson(Map<String, dynamic> json) => _TaxRateApi(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
  rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
  isDeleted: json['is_deleted'] as bool? ?? false,
);

Map<String, dynamic> _$TaxRateApiToJson(_TaxRateApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'rate': instance.rate,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'is_deleted': instance.isDeleted,
    };

_TaxRateListApi _$TaxRateListApiFromJson(Map<String, dynamic> json) =>
    _TaxRateListApi(
      data: json['data'] == null ? const [] : _taxRateListData(json['data']),
    );

Map<String, dynamic> _$TaxRateListApiToJson(_TaxRateListApi instance) =>
    <String, dynamic>{'data': instance.data};

_TaxRateItemApi _$TaxRateItemApiFromJson(Map<String, dynamic> json) =>
    _TaxRateItemApi(
      data: TaxRateApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TaxRateItemApiToJson(_TaxRateItemApi instance) =>
    <String, dynamic>{'data': instance.data};
