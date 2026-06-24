// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webhook_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WebhookApi _$WebhookApiFromJson(Map<String, dynamic> json) => _WebhookApi(
  id: json['id'] as String? ?? '',
  eventId: json['event_id'] as String? ?? '',
  targetUrl: json['target_url'] as String? ?? '',
  format: json['format'] as String? ?? 'JSON',
  restMethod: json['rest_method'] as String? ?? 'post',
  headers: json['headers'] == null
      ? const <String, String>{}
      : _headersFromJson(json['headers']),
  isDeleted: json['is_deleted'] as bool? ?? false,
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$WebhookApiToJson(_WebhookApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'event_id': instance.eventId,
      'target_url': instance.targetUrl,
      'format': instance.format,
      'rest_method': instance.restMethod,
      'headers': instance.headers,
      'is_deleted': instance.isDeleted,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
    };

_WebhookListApi _$WebhookListApiFromJson(Map<String, dynamic> json) =>
    _WebhookListApi(
      data: json['data'] == null ? const [] : _webhookListData(json['data']),
    );

Map<String, dynamic> _$WebhookListApiToJson(_WebhookListApi instance) =>
    <String, dynamic>{'data': instance.data};

_WebhookItemApi _$WebhookItemApiFromJson(Map<String, dynamic> json) =>
    _WebhookItemApi(
      data: WebhookApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$WebhookItemApiToJson(_WebhookItemApi instance) =>
    <String, dynamic>{'data': instance.data};
