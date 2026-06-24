// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ScheduleApi _$ScheduleApiFromJson(Map<String, dynamic> json) => _ScheduleApi(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
  template: json['template'] as String? ?? '',
  frequencyId: json['frequency_id'] as String? ?? '',
  nextRun: json['next_run'] as String? ?? '',
  isPaused: json['is_paused'] as bool? ?? false,
  remainingCycles: (json['remaining_cycles'] as num?)?.toInt() ?? -1,
  parameters:
      json['parameters'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
  isDeleted: json['is_deleted'] as bool? ?? false,
  userId: json['user_id'] as String? ?? '',
  assignedUserId: json['assigned_user_id'] as String? ?? '',
);

Map<String, dynamic> _$ScheduleApiToJson(_ScheduleApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'template': instance.template,
      'frequency_id': instance.frequencyId,
      'next_run': instance.nextRun,
      'is_paused': instance.isPaused,
      'remaining_cycles': instance.remainingCycles,
      'parameters': instance.parameters,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'is_deleted': instance.isDeleted,
      'user_id': instance.userId,
      'assigned_user_id': instance.assignedUserId,
    };

_ScheduleListApi _$ScheduleListApiFromJson(Map<String, dynamic> json) =>
    _ScheduleListApi(
      data: json['data'] == null ? const [] : _scheduleListData(json['data']),
    );

Map<String, dynamic> _$ScheduleListApiToJson(_ScheduleListApi instance) =>
    <String, dynamic>{'data': instance.data};

_ScheduleItemApi _$ScheduleItemApiFromJson(Map<String, dynamic> json) =>
    _ScheduleItemApi(
      data: ScheduleApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ScheduleItemApiToJson(_ScheduleItemApi instance) =>
    <String, dynamic>{'data': instance.data};
