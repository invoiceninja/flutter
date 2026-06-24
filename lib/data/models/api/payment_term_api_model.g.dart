// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_term_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaymentTermApi _$PaymentTermApiFromJson(Map<String, dynamic> json) =>
    _PaymentTermApi(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      numDays: (json['num_days'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );

Map<String, dynamic> _$PaymentTermApiToJson(_PaymentTermApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'num_days': instance.numDays,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'is_deleted': instance.isDeleted,
    };

_PaymentTermListApi _$PaymentTermListApiFromJson(Map<String, dynamic> json) =>
    _PaymentTermListApi(
      data: json['data'] == null
          ? const []
          : _paymentTermListData(json['data']),
    );

Map<String, dynamic> _$PaymentTermListApiToJson(_PaymentTermListApi instance) =>
    <String, dynamic>{'data': instance.data};

_PaymentTermItemApi _$PaymentTermItemApiFromJson(Map<String, dynamic> json) =>
    _PaymentTermItemApi(
      data: PaymentTermApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PaymentTermItemApiToJson(_PaymentTermItemApi instance) =>
    <String, dynamic>{'data': instance.data};
