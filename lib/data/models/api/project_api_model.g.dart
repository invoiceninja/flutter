// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProjectApi _$ProjectApiFromJson(Map<String, dynamic> json) => _ProjectApi(
  id: json['id'] as String? ?? '',
  userId: json['user_id'] as String? ?? '',
  assignedUserId: json['assigned_user_id'] as String? ?? '',
  clientId: json['client_id'] as String? ?? '',
  number: json['number'] as String? ?? '',
  name: json['name'] as String? ?? '',
  taskRate: json['task_rate'] as Object? ?? '0',
  dueDate: json['due_date'] as String? ?? '',
  privateNotes: json['private_notes'] as String? ?? '',
  publicNotes: json['public_notes'] as String? ?? '',
  budgetedHours: json['budgeted_hours'] as num? ?? 0,
  budgetedAmount: json['budgeted_amount'] as Object? ?? '0',
  currentHours: json['current_hours'] as num? ?? 0,
  customValue1: json['custom_value1'] as String? ?? '',
  customValue2: json['custom_value2'] as String? ?? '',
  customValue3: json['custom_value3'] as String? ?? '',
  customValue4: json['custom_value4'] as String? ?? '',
  color: json['color'] as String? ?? '',
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
  isDeleted: json['is_deleted'] as bool? ?? false,
  documents: (json['documents'] as List<dynamic>?)
      ?.map((e) => DocumentApi.fromJson(e as Map<String, dynamic>))
      .toList(),
  tags: json['tags'] == null
      ? const <TagRefApi>[]
      : const EmbeddedTagsConverter().fromJson(json['tags']),
);

Map<String, dynamic> _$ProjectApiToJson(_ProjectApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'assigned_user_id': instance.assignedUserId,
      'client_id': instance.clientId,
      'number': instance.number,
      'name': instance.name,
      'task_rate': instance.taskRate,
      'due_date': instance.dueDate,
      'private_notes': instance.privateNotes,
      'public_notes': instance.publicNotes,
      'budgeted_hours': instance.budgetedHours,
      'budgeted_amount': instance.budgetedAmount,
      'current_hours': instance.currentHours,
      'custom_value1': instance.customValue1,
      'custom_value2': instance.customValue2,
      'custom_value3': instance.customValue3,
      'custom_value4': instance.customValue4,
      'color': instance.color,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'is_deleted': instance.isDeleted,
      'documents': instance.documents,
      'tags': const EmbeddedTagsConverter().toJson(instance.tags),
    };

_ProjectListApi _$ProjectListApiFromJson(Map<String, dynamic> json) =>
    _ProjectListApi(
      data: json['data'] == null ? const [] : _projectListData(json['data']),
    );

Map<String, dynamic> _$ProjectListApiToJson(_ProjectListApi instance) =>
    <String, dynamic>{'data': instance.data};

_ProjectItemApi _$ProjectItemApiFromJson(Map<String, dynamic> json) =>
    _ProjectItemApi(
      data: ProjectApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ProjectItemApiToJson(_ProjectItemApi instance) =>
    <String, dynamic>{'data': instance.data};
