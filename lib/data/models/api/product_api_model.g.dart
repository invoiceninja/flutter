// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProductApi _$ProductApiFromJson(Map<String, dynamic> json) => _ProductApi(
  id: json['id'] as String? ?? '',
  userId: json['user_id'] as String? ?? '',
  assignedUserId: json['assigned_user_id'] as String? ?? '',
  productKey: json['product_key'] as String? ?? '',
  notes: json['notes'] as String? ?? '',
  cost: json['cost'] as Object? ?? '0',
  price: json['price'] as Object? ?? '0',
  quantity: json['quantity'] as Object? ?? '0',
  taxName1: json['tax_name1'] as String? ?? '',
  taxRate1: json['tax_rate1'] as num? ?? 0,
  taxName2: json['tax_name2'] as String? ?? '',
  taxRate2: json['tax_rate2'] as num? ?? 0,
  taxName3: json['tax_name3'] as String? ?? '',
  taxRate3: json['tax_rate3'] as num? ?? 0,
  taxId: json['tax_id'] as String? ?? '',
  customValue1: json['custom_value1'] as String? ?? '',
  customValue2: json['custom_value2'] as String? ?? '',
  customValue3: json['custom_value3'] as String? ?? '',
  customValue4: json['custom_value4'] as String? ?? '',
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
  isDeleted: json['is_deleted'] as bool? ?? false,
  inStockQuantity: json['in_stock_quantity'] as num? ?? 0,
  stockNotification: json['stock_notification'] as bool? ?? false,
  stockNotificationThreshold: json['stock_notification_threshold'] as num? ?? 0,
  maxQuantity: json['max_quantity'] as num? ?? 0,
  productImage: json['product_image'] as String? ?? '',
  incomeAccountId: json['income_account_id'] as String? ?? '',
  tags: json['tags'] == null
      ? const <TagRefApi>[]
      : const EmbeddedTagsConverter().fromJson(json['tags']),
  documents: (json['documents'] as List<dynamic>?)
      ?.map((e) => DocumentApi.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ProductApiToJson(_ProductApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'assigned_user_id': instance.assignedUserId,
      'product_key': instance.productKey,
      'notes': instance.notes,
      'cost': instance.cost,
      'price': instance.price,
      'quantity': instance.quantity,
      'tax_name1': instance.taxName1,
      'tax_rate1': instance.taxRate1,
      'tax_name2': instance.taxName2,
      'tax_rate2': instance.taxRate2,
      'tax_name3': instance.taxName3,
      'tax_rate3': instance.taxRate3,
      'tax_id': instance.taxId,
      'custom_value1': instance.customValue1,
      'custom_value2': instance.customValue2,
      'custom_value3': instance.customValue3,
      'custom_value4': instance.customValue4,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'is_deleted': instance.isDeleted,
      'in_stock_quantity': instance.inStockQuantity,
      'stock_notification': instance.stockNotification,
      'stock_notification_threshold': instance.stockNotificationThreshold,
      'max_quantity': instance.maxQuantity,
      'product_image': instance.productImage,
      'income_account_id': instance.incomeAccountId,
      'tags': const EmbeddedTagsConverter().toJson(instance.tags),
      'documents': instance.documents,
    };

_ProductListApi _$ProductListApiFromJson(Map<String, dynamic> json) =>
    _ProductListApi(
      data: json['data'] == null ? const [] : _productListData(json['data']),
    );

Map<String, dynamic> _$ProductListApiToJson(_ProductListApi instance) =>
    <String, dynamic>{'data': instance.data};

_ProductItemApi _$ProductItemApiFromJson(Map<String, dynamic> json) =>
    _ProductItemApi(
      data: ProductApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ProductItemApiToJson(_ProductItemApi instance) =>
    <String, dynamic>{'data': instance.data};
