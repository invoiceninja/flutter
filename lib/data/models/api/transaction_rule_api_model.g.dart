// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_rule_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RuleCriterionApi _$RuleCriterionApiFromJson(Map<String, dynamic> json) =>
    _RuleCriterionApi(
      searchKey: json['search_key'] as String? ?? '',
      operator: json['operator'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );

Map<String, dynamic> _$RuleCriterionApiToJson(_RuleCriterionApi instance) =>
    <String, dynamic>{
      'search_key': instance.searchKey,
      'operator': instance.operator,
      'value': instance.value,
    };

_TransactionRuleApi _$TransactionRuleApiFromJson(Map<String, dynamic> json) =>
    _TransactionRuleApi(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      appliesTo: json['applies_to'] as String? ?? 'DEBIT',
      matchesOnAll: json['matches_on_all'] as bool? ?? true,
      autoConvert: json['auto_convert'] as bool? ?? false,
      vendorId: json['vendor_id'] as String? ?? '',
      categoryId: json['category_id'] as String? ?? '',
      rules:
          (json['rules'] as List<dynamic>?)
              ?.map((e) => RuleCriterionApi.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <RuleCriterionApi>[],
      vendor: json['vendor'] as Map<String, dynamic>?,
      expenseCategory: json['expense_category'] as Map<String, dynamic>?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$TransactionRuleApiToJson(_TransactionRuleApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'applies_to': instance.appliesTo,
      'matches_on_all': instance.matchesOnAll,
      'auto_convert': instance.autoConvert,
      'vendor_id': instance.vendorId,
      'category_id': instance.categoryId,
      'rules': instance.rules,
      'vendor': ?instance.vendor,
      'expense_category': ?instance.expenseCategory,
      'is_deleted': instance.isDeleted,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
    };

_TransactionRuleListApi _$TransactionRuleListApiFromJson(
  Map<String, dynamic> json,
) => _TransactionRuleListApi(
  data: json['data'] == null
      ? const []
      : _transactionRuleListData(json['data']),
);

Map<String, dynamic> _$TransactionRuleListApiToJson(
  _TransactionRuleListApi instance,
) => <String, dynamic>{'data': instance.data};

_TransactionRuleItemApi _$TransactionRuleItemApiFromJson(
  Map<String, dynamic> json,
) => _TransactionRuleItemApi(
  data: TransactionRuleApi.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TransactionRuleItemApiToJson(
  _TransactionRuleItemApi instance,
) => <String, dynamic>{'data': instance.data};
