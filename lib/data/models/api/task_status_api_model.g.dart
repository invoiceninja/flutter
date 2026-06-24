// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_status_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskStatusApi _$TaskStatusApiFromJson(Map<String, dynamic> json) =>
    _TaskStatusApi(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '',
      statusOrder: (json['status_order'] as num?)?.toInt(),
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );

Map<String, dynamic> _$TaskStatusApiToJson(_TaskStatusApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'color': instance.color,
      'status_order': instance.statusOrder,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'is_deleted': instance.isDeleted,
    };

_TaskStatusListApi _$TaskStatusListApiFromJson(Map<String, dynamic> json) =>
    _TaskStatusListApi(
      data: json['data'] == null ? const [] : _taskStatusListData(json['data']),
    );

Map<String, dynamic> _$TaskStatusListApiToJson(_TaskStatusListApi instance) =>
    <String, dynamic>{'data': instance.data};

_TaskStatusItemApi _$TaskStatusItemApiFromJson(Map<String, dynamic> json) =>
    _TaskStatusItemApi(
      data: TaskStatusApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TaskStatusItemApiToJson(_TaskStatusItemApi instance) =>
    <String, dynamic>{'data': instance.data};
