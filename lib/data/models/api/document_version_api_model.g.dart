// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_version_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DocumentVersionItemApi _$DocumentVersionItemApiFromJson(
  Map<String, dynamic> json,
) => _DocumentVersionItemApi(
  data: json['data'] == null
      ? const DocumentVersionEntityApi()
      : _versionEntity(json['data']),
);

Map<String, dynamic> _$DocumentVersionItemApiToJson(
  _DocumentVersionItemApi instance,
) => <String, dynamic>{'data': instance.data};

_DocumentVersionEntityApi _$DocumentVersionEntityApiFromJson(
  Map<String, dynamic> json,
) => _DocumentVersionEntityApi(
  activities: json['activities'] == null
      ? const []
      : _versionActivities(json['activities']),
);

Map<String, dynamic> _$DocumentVersionEntityApiToJson(
  _DocumentVersionEntityApi instance,
) => <String, dynamic>{'activities': instance.activities};

_DocumentVersionActivityApi _$DocumentVersionActivityApiFromJson(
  Map<String, dynamic> json,
) => _DocumentVersionActivityApi(
  id: json['id'] == null ? '' : jsonScalarToStringOrEmpty(json['id']),
  activityTypeId: json['activity_type_id'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['activity_type_id']),
  userId: json['user_id'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['user_id']),
  contactId: json['contact_id'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['contact_id']),
  isSystem: json['is_system'] as bool? ?? false,
  history: json['history'] == null
      ? null
      : DocumentVersionHistoryApi.fromJson(
          json['history'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$DocumentVersionActivityApiToJson(
  _DocumentVersionActivityApi instance,
) => <String, dynamic>{
  'id': instance.id,
  'activity_type_id': instance.activityTypeId,
  'user_id': instance.userId,
  'contact_id': instance.contactId,
  'is_system': instance.isSystem,
  'history': instance.history,
};

_DocumentVersionHistoryApi _$DocumentVersionHistoryApiFromJson(
  Map<String, dynamic> json,
) => _DocumentVersionHistoryApi(
  id: json['id'] == null ? '' : jsonScalarToStringOrEmpty(json['id']),
  activityId: json['activity_id'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['activity_id']),
  amount: json['amount'] as Object? ?? '0',
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$DocumentVersionHistoryApiToJson(
  _DocumentVersionHistoryApi instance,
) => <String, dynamic>{
  'id': instance.id,
  'activity_id': instance.activityId,
  'amount': instance.amount,
  'created_at': instance.createdAt,
};
