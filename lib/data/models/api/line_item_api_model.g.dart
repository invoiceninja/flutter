// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'line_item_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LineItemApi _$LineItemApiFromJson(Map<String, dynamic> json) => _LineItemApi(
  productKey: json['product_key'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['product_key']),
  notes: json['notes'] == null ? '' : jsonScalarToStringOrEmpty(json['notes']),
  cost: json['cost'] as Object? ?? '0',
  productCost: json['product_cost'] as Object? ?? '0',
  quantity: json['quantity'] as Object? ?? '1',
  taxName1: json['tax_name1'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['tax_name1']),
  taxName2: json['tax_name2'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['tax_name2']),
  taxName3: json['tax_name3'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['tax_name3']),
  taxRate1: json['tax_rate1'] as Object? ?? '0',
  taxRate2: json['tax_rate2'] as Object? ?? '0',
  taxRate3: json['tax_rate3'] as Object? ?? '0',
  typeId: json['type_id'] == null
      ? '1'
      : jsonScalarToStringOrEmpty(json['type_id']),
  customValue1: json['custom_value1'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['custom_value1']),
  customValue2: json['custom_value2'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['custom_value2']),
  customValue3: json['custom_value3'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['custom_value3']),
  customValue4: json['custom_value4'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['custom_value4']),
  discount: json['discount'] as Object? ?? '0',
  taskId: jsonScalarToString(json['task_id']),
  expenseId: jsonScalarToString(json['expense_id']),
  taxCategoryId: json['tax_id'] == null
      ? ''
      : jsonScalarToStringOrEmpty(json['tax_id']),
  createdAt: (json['created_at'] as num?)?.toInt(),
);

Map<String, dynamic> _$LineItemApiToJson(_LineItemApi instance) =>
    <String, dynamic>{
      'product_key': instance.productKey,
      'notes': instance.notes,
      'cost': instance.cost,
      'product_cost': instance.productCost,
      'quantity': instance.quantity,
      'tax_name1': instance.taxName1,
      'tax_name2': instance.taxName2,
      'tax_name3': instance.taxName3,
      'tax_rate1': instance.taxRate1,
      'tax_rate2': instance.taxRate2,
      'tax_rate3': instance.taxRate3,
      'type_id': instance.typeId,
      'custom_value1': instance.customValue1,
      'custom_value2': instance.customValue2,
      'custom_value3': instance.customValue3,
      'custom_value4': instance.customValue4,
      'discount': instance.discount,
      'task_id': instance.taskId,
      'expense_id': instance.expenseId,
      'tax_id': instance.taxCategoryId,
      'created_at': instance.createdAt,
    };
