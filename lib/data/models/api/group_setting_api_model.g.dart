// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_setting_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GroupSettingApi _$GroupSettingApiFromJson(Map<String, dynamic> json) =>
    _GroupSettingApi(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      assignedUserId: json['assigned_user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      customValue1: json['custom_value1'] as String? ?? '',
      customValue2: json['custom_value2'] as String? ?? '',
      customValue3: json['custom_value3'] as String? ?? '',
      customValue4: json['custom_value4'] as String? ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
      isDeleted: json['is_deleted'] as bool? ?? false,
      settings: json['settings'] as Map<String, dynamic>?,
      documents: (json['documents'] as List<dynamic>?)
          ?.map((e) => DocumentApi.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$GroupSettingApiToJson(_GroupSettingApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'assigned_user_id': instance.assignedUserId,
      'name': instance.name,
      'custom_value1': instance.customValue1,
      'custom_value2': instance.customValue2,
      'custom_value3': instance.customValue3,
      'custom_value4': instance.customValue4,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'is_deleted': instance.isDeleted,
      'settings': ?instance.settings,
      'documents': instance.documents,
    };

_GroupSettingListApi _$GroupSettingListApiFromJson(Map<String, dynamic> json) =>
    _GroupSettingListApi(
      data: json['data'] == null
          ? const []
          : _groupSettingListData(json['data']),
    );

Map<String, dynamic> _$GroupSettingListApiToJson(
  _GroupSettingListApi instance,
) => <String, dynamic>{'data': instance.data};

_GroupSettingItemApi _$GroupSettingItemApiFromJson(Map<String, dynamic> json) =>
    _GroupSettingItemApi(
      data: GroupSettingApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$GroupSettingItemApiToJson(
  _GroupSettingItemApi instance,
) => <String, dynamic>{'data': instance.data};
