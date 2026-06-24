// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TokenApi _$TokenApiFromJson(Map<String, dynamic> json) => _TokenApi(
  id: json['id'] as String? ?? '',
  userId: json['user_id'] as String? ?? '',
  token: json['token'] as String? ?? '',
  name: json['name'] as String? ?? '',
  isSystem: json['is_system'] as bool? ?? false,
  isDeleted: json['is_deleted'] as bool? ?? false,
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TokenApiToJson(_TokenApi instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'token': instance.token,
  'name': instance.name,
  'is_system': instance.isSystem,
  'is_deleted': instance.isDeleted,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'archived_at': instance.archivedAt,
};

_TokenListApi _$TokenListApiFromJson(Map<String, dynamic> json) =>
    _TokenListApi(
      data: json['data'] == null ? const [] : _tokenListData(json['data']),
    );

Map<String, dynamic> _$TokenListApiToJson(_TokenListApi instance) =>
    <String, dynamic>{'data': instance.data};

_TokenItemApi _$TokenItemApiFromJson(Map<String, dynamic> json) =>
    _TokenItemApi(
      data: TokenApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TokenItemApiToJson(_TokenItemApi instance) =>
    <String, dynamic>{'data': instance.data};
