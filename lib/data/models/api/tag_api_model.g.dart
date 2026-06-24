// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TagApi _$TagApiFromJson(Map<String, dynamic> json) => _TagApi(
  id: json['id'] as String? ?? '',
  entityType: json['entity_type'] as String? ?? '',
  name: json['name'] as String? ?? '',
  color: json['color'] as String?,
  isDeleted: json['is_deleted'] as bool? ?? false,
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TagApiToJson(_TagApi instance) => <String, dynamic>{
  'id': instance.id,
  'entity_type': instance.entityType,
  'name': instance.name,
  'color': instance.color,
  'is_deleted': instance.isDeleted,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'archived_at': instance.archivedAt,
};

_TagRefApi _$TagRefApiFromJson(Map<String, dynamic> json) => _TagRefApi(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
  color: json['color'] as String?,
);

Map<String, dynamic> _$TagRefApiToJson(_TagRefApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'color': instance.color,
    };

_TagListApi _$TagListApiFromJson(Map<String, dynamic> json) => _TagListApi(
  data: json['data'] == null ? const [] : _tagListData(json['data']),
);

Map<String, dynamic> _$TagListApiToJson(_TagListApi instance) =>
    <String, dynamic>{'data': instance.data};

_TagItemApi _$TagItemApiFromJson(Map<String, dynamic> json) =>
    _TagItemApi(data: TagApi.fromJson(json['data'] as Map<String, dynamic>));

Map<String, dynamic> _$TagItemApiToJson(_TagItemApi instance) =>
    <String, dynamic>{'data': instance.data};
