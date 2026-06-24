// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_category_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ExpenseCategoryApi _$ExpenseCategoryApiFromJson(Map<String, dynamic> json) =>
    _ExpenseCategoryApi(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      assignedUserId: json['assigned_user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );

Map<String, dynamic> _$ExpenseCategoryApiToJson(_ExpenseCategoryApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'assigned_user_id': instance.assignedUserId,
      'name': instance.name,
      'color': instance.color,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'is_deleted': instance.isDeleted,
    };

_ExpenseCategoryListApi _$ExpenseCategoryListApiFromJson(
  Map<String, dynamic> json,
) => _ExpenseCategoryListApi(
  data: json['data'] == null
      ? const []
      : _expenseCategoryListData(json['data']),
);

Map<String, dynamic> _$ExpenseCategoryListApiToJson(
  _ExpenseCategoryListApi instance,
) => <String, dynamic>{'data': instance.data};

_ExpenseCategoryItemApi _$ExpenseCategoryItemApiFromJson(
  Map<String, dynamic> json,
) => _ExpenseCategoryItemApi(
  data: ExpenseCategoryApi.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ExpenseCategoryItemApiToJson(
  _ExpenseCategoryItemApi instance,
) => <String, dynamic>{'data': instance.data};
