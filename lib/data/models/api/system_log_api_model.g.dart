// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_log_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SystemLogApi _$SystemLogApiFromJson(Map<String, dynamic> json) =>
    _SystemLogApi(
      id: json['id'] as String? ?? '',
      companyId: json['company_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      clientId: json['client_id'] as String? ?? '',
      eventId: (json['event_id'] as num?)?.toInt() ?? 0,
      categoryId: (json['category_id'] as num?)?.toInt() ?? 0,
      typeId: (json['type_id'] as num?)?.toInt() ?? 0,
      log: json['log'] as String? ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$SystemLogApiToJson(_SystemLogApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'company_id': instance.companyId,
      'user_id': instance.userId,
      'client_id': instance.clientId,
      'event_id': instance.eventId,
      'category_id': instance.categoryId,
      'type_id': instance.typeId,
      'log': instance.log,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

_SystemLogListApi _$SystemLogListApiFromJson(Map<String, dynamic> json) =>
    _SystemLogListApi(
      data: json['data'] == null ? const [] : _systemLogListData(json['data']),
    );

Map<String, dynamic> _$SystemLogListApiToJson(_SystemLogListApi instance) =>
    <String, dynamic>{'data': instance.data};
