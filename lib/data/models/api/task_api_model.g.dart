// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskApi _$TaskApiFromJson(Map<String, dynamic> json) => _TaskApi(
  id: json['id'] as String? ?? '',
  userId: json['user_id'] as String? ?? '',
  assignedUserId: json['assigned_user_id'] as String? ?? '',
  number: json['number'] as String? ?? '',
  description: json['description'] as String? ?? '',
  rate: json['rate'] as Object? ?? '0',
  invoiceId: json['invoice_id'] as String? ?? '',
  clientId: json['client_id'] as String? ?? '',
  projectId: json['project_id'] as String? ?? '',
  statusId: json['status_id'] as String? ?? '',
  statusOrder: (json['status_order'] as num?)?.toInt(),
  timeLog: json['time_log'] as String? ?? '',
  customValue1: json['custom_value1'] as String? ?? '',
  customValue2: json['custom_value2'] as String? ?? '',
  customValue3: json['custom_value3'] as String? ?? '',
  customValue4: json['custom_value4'] as String? ?? '',
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
  isDeleted: json['is_deleted'] as bool? ?? false,
  isRunning: json['is_running'] as bool? ?? false,
  isDateBased: json['is_date_based'] as bool? ?? false,
  documents: (json['documents'] as List<dynamic>?)
      ?.map((e) => DocumentApi.fromJson(e as Map<String, dynamic>))
      .toList(),
  tags: json['tags'] == null
      ? const <TagRefApi>[]
      : const EmbeddedTagsConverter().fromJson(json['tags']),
  meta: const TaskMetaConverter().fromJson(json['meta']),
);

Map<String, dynamic> _$TaskApiToJson(_TaskApi instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'assigned_user_id': instance.assignedUserId,
  'number': instance.number,
  'description': instance.description,
  'rate': instance.rate,
  'invoice_id': instance.invoiceId,
  'client_id': instance.clientId,
  'project_id': instance.projectId,
  'status_id': instance.statusId,
  'status_order': instance.statusOrder,
  'time_log': instance.timeLog,
  'custom_value1': instance.customValue1,
  'custom_value2': instance.customValue2,
  'custom_value3': instance.customValue3,
  'custom_value4': instance.customValue4,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'archived_at': instance.archivedAt,
  'is_deleted': instance.isDeleted,
  'is_running': instance.isRunning,
  'is_date_based': instance.isDateBased,
  'documents': instance.documents,
  'tags': const EmbeddedTagsConverter().toJson(instance.tags),
  'meta': const TaskMetaConverter().toJson(instance.meta),
};

_TaskMetaApi _$TaskMetaApiFromJson(Map<String, dynamic> json) =>
    _TaskMetaApi(calendarEventId: json['calendar_event_id'] as String? ?? '');

Map<String, dynamic> _$TaskMetaApiToJson(_TaskMetaApi instance) =>
    <String, dynamic>{'calendar_event_id': instance.calendarEventId};

_TaskListApi _$TaskListApiFromJson(Map<String, dynamic> json) => _TaskListApi(
  data: json['data'] == null ? const [] : _taskListData(json['data']),
);

Map<String, dynamic> _$TaskListApiToJson(_TaskListApi instance) =>
    <String, dynamic>{'data': instance.data};

_TaskItemApi _$TaskItemApiFromJson(Map<String, dynamic> json) =>
    _TaskItemApi(data: TaskApi.fromJson(json['data'] as Map<String, dynamic>));

Map<String, dynamic> _$TaskItemApiToJson(_TaskItemApi instance) =>
    <String, dynamic>{'data': instance.data};
