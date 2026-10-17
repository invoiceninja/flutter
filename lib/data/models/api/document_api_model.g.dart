// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DocumentApi _$DocumentApiFromJson(Map<String, dynamic> json) => _DocumentApi(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
  hash: json['hash'] as String? ?? '',
  type: json['type'] as String? ?? '',
  url: json['url'] as String? ?? '',
  size: (json['size'] as num?)?.toInt() ?? 0,
  width: (json['width'] as num?)?.toInt() ?? 0,
  height: (json['height'] as num?)?.toInt() ?? 0,
  userId: json['user_id'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['user_id']),
  assignedUserId: json['assigned_user_id'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['assigned_user_id']),
  isDefault: json['is_default'] as bool? ?? false,
  isPublic: json['is_public'] as bool? ?? true,
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
  documentableType: jsonScalarToString(json['documentable_type']),
  documentableId: jsonScalarToString(json['documentable_id']),
);

Map<String, dynamic> _$DocumentApiToJson(_DocumentApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'hash': instance.hash,
      'type': instance.type,
      'url': instance.url,
      'size': instance.size,
      'width': instance.width,
      'height': instance.height,
      'user_id': instance.userId,
      'assigned_user_id': instance.assignedUserId,
      'is_default': instance.isDefault,
      'is_public': instance.isPublic,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'documentable_type': ?instance.documentableType,
      'documentable_id': ?instance.documentableId,
    };

_DocumentListApi _$DocumentListApiFromJson(Map<String, dynamic> json) =>
    _DocumentListApi(
      data: json['data'] == null
          ? const <DocumentApi>[]
          : _documentListData(json['data']),
    );

Map<String, dynamic> _$DocumentListApiToJson(_DocumentListApi instance) =>
    <String, dynamic>{'data': instance.data};

_DocumentItemApi _$DocumentItemApiFromJson(Map<String, dynamic> json) =>
    _DocumentItemApi(
      data: DocumentApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DocumentItemApiToJson(_DocumentItemApi instance) =>
    <String, dynamic>{'data': instance.data};
