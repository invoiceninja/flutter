// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProductApi {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'assigned_user_id') String get assignedUserId;@JsonKey(name: 'product_key') String get productKey; String get notes;@JsonKey(name: 'cost') Object get cost;@JsonKey(name: 'price') Object get price;@JsonKey(name: 'quantity') Object get quantity;@JsonKey(name: 'tax_name1') String get taxName1;@JsonKey(name: 'tax_rate1') num get taxRate1;@JsonKey(name: 'tax_name2') String get taxName2;@JsonKey(name: 'tax_rate2') num get taxRate2;@JsonKey(name: 'tax_name3') String get taxName3;@JsonKey(name: 'tax_rate3') num get taxRate3;@JsonKey(name: 'tax_id') String get taxId;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'in_stock_quantity') num get inStockQuantity;@JsonKey(name: 'stock_notification') bool get stockNotification;@JsonKey(name: 'stock_notification_threshold') num get stockNotificationThreshold;@JsonKey(name: 'max_quantity') num get maxQuantity;@JsonKey(name: 'product_image') String get productImage;@JsonKey(name: 'income_account_id') String get incomeAccountId;// Attached tags — `[{id, name, color}]` from the server (or bare ids on the
// Drift-payload round-trip). The domain keeps just the ids.
@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags;// Nullable so JSON-omitted (→ null) is distinguishable from
// JSON-present-and-empty (→ `const []`). See `ClientApi.documents` for
// the rationale.
 List<DocumentApi>? get documents;
/// Create a copy of ProductApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductApiCopyWith<ProductApi> get copyWith => _$ProductApiCopyWithImpl<ProductApi>(this as ProductApi, _$identity);

  /// Serializes this ProductApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.productKey, productKey) || other.productKey == productKey)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other.cost, cost)&&const DeepCollectionEquality().equals(other.price, price)&&const DeepCollectionEquality().equals(other.quantity, quantity)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxRate1, taxRate1) || other.taxRate1 == taxRate1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxRate2, taxRate2) || other.taxRate2 == taxRate2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&(identical(other.taxRate3, taxRate3) || other.taxRate3 == taxRate3)&&(identical(other.taxId, taxId) || other.taxId == taxId)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.inStockQuantity, inStockQuantity) || other.inStockQuantity == inStockQuantity)&&(identical(other.stockNotification, stockNotification) || other.stockNotification == stockNotification)&&(identical(other.stockNotificationThreshold, stockNotificationThreshold) || other.stockNotificationThreshold == stockNotificationThreshold)&&(identical(other.maxQuantity, maxQuantity) || other.maxQuantity == maxQuantity)&&(identical(other.productImage, productImage) || other.productImage == productImage)&&(identical(other.incomeAccountId, incomeAccountId) || other.incomeAccountId == incomeAccountId)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.documents, documents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,productKey,notes,const DeepCollectionEquality().hash(cost),const DeepCollectionEquality().hash(price),const DeepCollectionEquality().hash(quantity),taxName1,taxRate1,taxName2,taxRate2,taxName3,taxRate3,taxId,customValue1,customValue2,customValue3,customValue4,createdAt,updatedAt,archivedAt,isDeleted,inStockQuantity,stockNotification,stockNotificationThreshold,maxQuantity,productImage,incomeAccountId,const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(documents)]);

@override
String toString() {
  return 'ProductApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, productKey: $productKey, notes: $notes, cost: $cost, price: $price, quantity: $quantity, taxName1: $taxName1, taxRate1: $taxRate1, taxName2: $taxName2, taxRate2: $taxRate2, taxName3: $taxName3, taxRate3: $taxRate3, taxId: $taxId, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, inStockQuantity: $inStockQuantity, stockNotification: $stockNotification, stockNotificationThreshold: $stockNotificationThreshold, maxQuantity: $maxQuantity, productImage: $productImage, incomeAccountId: $incomeAccountId, tags: $tags, documents: $documents)';
}


}

/// @nodoc
abstract mixin class $ProductApiCopyWith<$Res>  {
  factory $ProductApiCopyWith(ProductApi value, $Res Function(ProductApi) _then) = _$ProductApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'product_key') String productKey, String notes,@JsonKey(name: 'cost') Object cost,@JsonKey(name: 'price') Object price,@JsonKey(name: 'quantity') Object quantity,@JsonKey(name: 'tax_name1') String taxName1,@JsonKey(name: 'tax_rate1') num taxRate1,@JsonKey(name: 'tax_name2') String taxName2,@JsonKey(name: 'tax_rate2') num taxRate2,@JsonKey(name: 'tax_name3') String taxName3,@JsonKey(name: 'tax_rate3') num taxRate3,@JsonKey(name: 'tax_id') String taxId,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'in_stock_quantity') num inStockQuantity,@JsonKey(name: 'stock_notification') bool stockNotification,@JsonKey(name: 'stock_notification_threshold') num stockNotificationThreshold,@JsonKey(name: 'max_quantity') num maxQuantity,@JsonKey(name: 'product_image') String productImage,@JsonKey(name: 'income_account_id') String incomeAccountId,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags, List<DocumentApi>? documents
});




}
/// @nodoc
class _$ProductApiCopyWithImpl<$Res>
    implements $ProductApiCopyWith<$Res> {
  _$ProductApiCopyWithImpl(this._self, this._then);

  final ProductApi _self;
  final $Res Function(ProductApi) _then;

/// Create a copy of ProductApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? productKey = null,Object? notes = null,Object? cost = null,Object? price = null,Object? quantity = null,Object? taxName1 = null,Object? taxRate1 = null,Object? taxName2 = null,Object? taxRate2 = null,Object? taxName3 = null,Object? taxRate3 = null,Object? taxId = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? inStockQuantity = null,Object? stockNotification = null,Object? stockNotificationThreshold = null,Object? maxQuantity = null,Object? productImage = null,Object? incomeAccountId = null,Object? tags = null,Object? documents = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,productKey: null == productKey ? _self.productKey : productKey // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,cost: null == cost ? _self.cost : cost ,price: null == price ? _self.price : price ,quantity: null == quantity ? _self.quantity : quantity ,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 // ignore: cast_nullable_to_non_nullable
as num,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 // ignore: cast_nullable_to_non_nullable
as num,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 // ignore: cast_nullable_to_non_nullable
as num,taxId: null == taxId ? _self.taxId : taxId // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,inStockQuantity: null == inStockQuantity ? _self.inStockQuantity : inStockQuantity // ignore: cast_nullable_to_non_nullable
as num,stockNotification: null == stockNotification ? _self.stockNotification : stockNotification // ignore: cast_nullable_to_non_nullable
as bool,stockNotificationThreshold: null == stockNotificationThreshold ? _self.stockNotificationThreshold : stockNotificationThreshold // ignore: cast_nullable_to_non_nullable
as num,maxQuantity: null == maxQuantity ? _self.maxQuantity : maxQuantity // ignore: cast_nullable_to_non_nullable
as num,productImage: null == productImage ? _self.productImage : productImage // ignore: cast_nullable_to_non_nullable
as String,incomeAccountId: null == incomeAccountId ? _self.incomeAccountId : incomeAccountId // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,documents: freezed == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductApi].
extension ProductApiPatterns on ProductApi {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductApi() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductApi value)  $default,){
final _that = this;
switch (_that) {
case _ProductApi():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductApi value)?  $default,){
final _that = this;
switch (_that) {
case _ProductApi() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'product_key')  String productKey,  String notes, @JsonKey(name: 'cost')  Object cost, @JsonKey(name: 'price')  Object price, @JsonKey(name: 'quantity')  Object quantity, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_rate1')  num taxRate1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_rate2')  num taxRate2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'tax_rate3')  num taxRate3, @JsonKey(name: 'tax_id')  String taxId, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'in_stock_quantity')  num inStockQuantity, @JsonKey(name: 'stock_notification')  bool stockNotification, @JsonKey(name: 'stock_notification_threshold')  num stockNotificationThreshold, @JsonKey(name: 'max_quantity')  num maxQuantity, @JsonKey(name: 'product_image')  String productImage, @JsonKey(name: 'income_account_id')  String incomeAccountId, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags,  List<DocumentApi>? documents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.productKey,_that.notes,_that.cost,_that.price,_that.quantity,_that.taxName1,_that.taxRate1,_that.taxName2,_that.taxRate2,_that.taxName3,_that.taxRate3,_that.taxId,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.inStockQuantity,_that.stockNotification,_that.stockNotificationThreshold,_that.maxQuantity,_that.productImage,_that.incomeAccountId,_that.tags,_that.documents);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'product_key')  String productKey,  String notes, @JsonKey(name: 'cost')  Object cost, @JsonKey(name: 'price')  Object price, @JsonKey(name: 'quantity')  Object quantity, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_rate1')  num taxRate1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_rate2')  num taxRate2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'tax_rate3')  num taxRate3, @JsonKey(name: 'tax_id')  String taxId, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'in_stock_quantity')  num inStockQuantity, @JsonKey(name: 'stock_notification')  bool stockNotification, @JsonKey(name: 'stock_notification_threshold')  num stockNotificationThreshold, @JsonKey(name: 'max_quantity')  num maxQuantity, @JsonKey(name: 'product_image')  String productImage, @JsonKey(name: 'income_account_id')  String incomeAccountId, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags,  List<DocumentApi>? documents)  $default,) {final _that = this;
switch (_that) {
case _ProductApi():
return $default(_that.id,_that.userId,_that.assignedUserId,_that.productKey,_that.notes,_that.cost,_that.price,_that.quantity,_that.taxName1,_that.taxRate1,_that.taxName2,_that.taxRate2,_that.taxName3,_that.taxRate3,_that.taxId,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.inStockQuantity,_that.stockNotification,_that.stockNotificationThreshold,_that.maxQuantity,_that.productImage,_that.incomeAccountId,_that.tags,_that.documents);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'product_key')  String productKey,  String notes, @JsonKey(name: 'cost')  Object cost, @JsonKey(name: 'price')  Object price, @JsonKey(name: 'quantity')  Object quantity, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_rate1')  num taxRate1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_rate2')  num taxRate2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'tax_rate3')  num taxRate3, @JsonKey(name: 'tax_id')  String taxId, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'in_stock_quantity')  num inStockQuantity, @JsonKey(name: 'stock_notification')  bool stockNotification, @JsonKey(name: 'stock_notification_threshold')  num stockNotificationThreshold, @JsonKey(name: 'max_quantity')  num maxQuantity, @JsonKey(name: 'product_image')  String productImage, @JsonKey(name: 'income_account_id')  String incomeAccountId, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags,  List<DocumentApi>? documents)?  $default,) {final _that = this;
switch (_that) {
case _ProductApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.productKey,_that.notes,_that.cost,_that.price,_that.quantity,_that.taxName1,_that.taxRate1,_that.taxName2,_that.taxRate2,_that.taxName3,_that.taxRate3,_that.taxId,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.inStockQuantity,_that.stockNotification,_that.stockNotificationThreshold,_that.maxQuantity,_that.productImage,_that.incomeAccountId,_that.tags,_that.documents);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductApi implements ProductApi {
  const _ProductApi({this.id = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', @JsonKey(name: 'product_key') this.productKey = '', this.notes = '', @JsonKey(name: 'cost') this.cost = '0', @JsonKey(name: 'price') this.price = '0', @JsonKey(name: 'quantity') this.quantity = '0', @JsonKey(name: 'tax_name1') this.taxName1 = '', @JsonKey(name: 'tax_rate1') this.taxRate1 = 0, @JsonKey(name: 'tax_name2') this.taxName2 = '', @JsonKey(name: 'tax_rate2') this.taxRate2 = 0, @JsonKey(name: 'tax_name3') this.taxName3 = '', @JsonKey(name: 'tax_rate3') this.taxRate3 = 0, @JsonKey(name: 'tax_id') this.taxId = '', @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'in_stock_quantity') this.inStockQuantity = 0, @JsonKey(name: 'stock_notification') this.stockNotification = false, @JsonKey(name: 'stock_notification_threshold') this.stockNotificationThreshold = 0, @JsonKey(name: 'max_quantity') this.maxQuantity = 0, @JsonKey(name: 'product_image') this.productImage = '', @JsonKey(name: 'income_account_id') this.incomeAccountId = '', @JsonKey(name: 'tags')@EmbeddedTagsConverter() final  List<TagRefApi> tags = const <TagRefApi>[], final  List<DocumentApi>? documents}): _tags = tags,_documents = documents;
  factory _ProductApi.fromJson(Map<String, dynamic> json) => _$ProductApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'assigned_user_id') final  String assignedUserId;
@override@JsonKey(name: 'product_key') final  String productKey;
@override@JsonKey() final  String notes;
@override@JsonKey(name: 'cost') final  Object cost;
@override@JsonKey(name: 'price') final  Object price;
@override@JsonKey(name: 'quantity') final  Object quantity;
@override@JsonKey(name: 'tax_name1') final  String taxName1;
@override@JsonKey(name: 'tax_rate1') final  num taxRate1;
@override@JsonKey(name: 'tax_name2') final  String taxName2;
@override@JsonKey(name: 'tax_rate2') final  num taxRate2;
@override@JsonKey(name: 'tax_name3') final  String taxName3;
@override@JsonKey(name: 'tax_rate3') final  num taxRate3;
@override@JsonKey(name: 'tax_id') final  String taxId;
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'in_stock_quantity') final  num inStockQuantity;
@override@JsonKey(name: 'stock_notification') final  bool stockNotification;
@override@JsonKey(name: 'stock_notification_threshold') final  num stockNotificationThreshold;
@override@JsonKey(name: 'max_quantity') final  num maxQuantity;
@override@JsonKey(name: 'product_image') final  String productImage;
@override@JsonKey(name: 'income_account_id') final  String incomeAccountId;
// Attached tags — `[{id, name, color}]` from the server (or bare ids on the
// Drift-payload round-trip). The domain keeps just the ids.
 final  List<TagRefApi> _tags;
// Attached tags — `[{id, name, color}]` from the server (or bare ids on the
// Drift-payload round-trip). The domain keeps just the ids.
@override@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

// Nullable so JSON-omitted (→ null) is distinguishable from
// JSON-present-and-empty (→ `const []`). See `ClientApi.documents` for
// the rationale.
 final  List<DocumentApi>? _documents;
// Nullable so JSON-omitted (→ null) is distinguishable from
// JSON-present-and-empty (→ `const []`). See `ClientApi.documents` for
// the rationale.
@override List<DocumentApi>? get documents {
  final value = _documents;
  if (value == null) return null;
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of ProductApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductApiCopyWith<_ProductApi> get copyWith => __$ProductApiCopyWithImpl<_ProductApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.productKey, productKey) || other.productKey == productKey)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other.cost, cost)&&const DeepCollectionEquality().equals(other.price, price)&&const DeepCollectionEquality().equals(other.quantity, quantity)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxRate1, taxRate1) || other.taxRate1 == taxRate1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxRate2, taxRate2) || other.taxRate2 == taxRate2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&(identical(other.taxRate3, taxRate3) || other.taxRate3 == taxRate3)&&(identical(other.taxId, taxId) || other.taxId == taxId)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.inStockQuantity, inStockQuantity) || other.inStockQuantity == inStockQuantity)&&(identical(other.stockNotification, stockNotification) || other.stockNotification == stockNotification)&&(identical(other.stockNotificationThreshold, stockNotificationThreshold) || other.stockNotificationThreshold == stockNotificationThreshold)&&(identical(other.maxQuantity, maxQuantity) || other.maxQuantity == maxQuantity)&&(identical(other.productImage, productImage) || other.productImage == productImage)&&(identical(other.incomeAccountId, incomeAccountId) || other.incomeAccountId == incomeAccountId)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._documents, _documents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,productKey,notes,const DeepCollectionEquality().hash(cost),const DeepCollectionEquality().hash(price),const DeepCollectionEquality().hash(quantity),taxName1,taxRate1,taxName2,taxRate2,taxName3,taxRate3,taxId,customValue1,customValue2,customValue3,customValue4,createdAt,updatedAt,archivedAt,isDeleted,inStockQuantity,stockNotification,stockNotificationThreshold,maxQuantity,productImage,incomeAccountId,const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_documents)]);

@override
String toString() {
  return 'ProductApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, productKey: $productKey, notes: $notes, cost: $cost, price: $price, quantity: $quantity, taxName1: $taxName1, taxRate1: $taxRate1, taxName2: $taxName2, taxRate2: $taxRate2, taxName3: $taxName3, taxRate3: $taxRate3, taxId: $taxId, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, inStockQuantity: $inStockQuantity, stockNotification: $stockNotification, stockNotificationThreshold: $stockNotificationThreshold, maxQuantity: $maxQuantity, productImage: $productImage, incomeAccountId: $incomeAccountId, tags: $tags, documents: $documents)';
}


}

/// @nodoc
abstract mixin class _$ProductApiCopyWith<$Res> implements $ProductApiCopyWith<$Res> {
  factory _$ProductApiCopyWith(_ProductApi value, $Res Function(_ProductApi) _then) = __$ProductApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'product_key') String productKey, String notes,@JsonKey(name: 'cost') Object cost,@JsonKey(name: 'price') Object price,@JsonKey(name: 'quantity') Object quantity,@JsonKey(name: 'tax_name1') String taxName1,@JsonKey(name: 'tax_rate1') num taxRate1,@JsonKey(name: 'tax_name2') String taxName2,@JsonKey(name: 'tax_rate2') num taxRate2,@JsonKey(name: 'tax_name3') String taxName3,@JsonKey(name: 'tax_rate3') num taxRate3,@JsonKey(name: 'tax_id') String taxId,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'in_stock_quantity') num inStockQuantity,@JsonKey(name: 'stock_notification') bool stockNotification,@JsonKey(name: 'stock_notification_threshold') num stockNotificationThreshold,@JsonKey(name: 'max_quantity') num maxQuantity,@JsonKey(name: 'product_image') String productImage,@JsonKey(name: 'income_account_id') String incomeAccountId,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags, List<DocumentApi>? documents
});




}
/// @nodoc
class __$ProductApiCopyWithImpl<$Res>
    implements _$ProductApiCopyWith<$Res> {
  __$ProductApiCopyWithImpl(this._self, this._then);

  final _ProductApi _self;
  final $Res Function(_ProductApi) _then;

/// Create a copy of ProductApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? productKey = null,Object? notes = null,Object? cost = null,Object? price = null,Object? quantity = null,Object? taxName1 = null,Object? taxRate1 = null,Object? taxName2 = null,Object? taxRate2 = null,Object? taxName3 = null,Object? taxRate3 = null,Object? taxId = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? inStockQuantity = null,Object? stockNotification = null,Object? stockNotificationThreshold = null,Object? maxQuantity = null,Object? productImage = null,Object? incomeAccountId = null,Object? tags = null,Object? documents = freezed,}) {
  return _then(_ProductApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,productKey: null == productKey ? _self.productKey : productKey // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,cost: null == cost ? _self.cost : cost ,price: null == price ? _self.price : price ,quantity: null == quantity ? _self.quantity : quantity ,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 // ignore: cast_nullable_to_non_nullable
as num,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 // ignore: cast_nullable_to_non_nullable
as num,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 // ignore: cast_nullable_to_non_nullable
as num,taxId: null == taxId ? _self.taxId : taxId // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,inStockQuantity: null == inStockQuantity ? _self.inStockQuantity : inStockQuantity // ignore: cast_nullable_to_non_nullable
as num,stockNotification: null == stockNotification ? _self.stockNotification : stockNotification // ignore: cast_nullable_to_non_nullable
as bool,stockNotificationThreshold: null == stockNotificationThreshold ? _self.stockNotificationThreshold : stockNotificationThreshold // ignore: cast_nullable_to_non_nullable
as num,maxQuantity: null == maxQuantity ? _self.maxQuantity : maxQuantity // ignore: cast_nullable_to_non_nullable
as num,productImage: null == productImage ? _self.productImage : productImage // ignore: cast_nullable_to_non_nullable
as String,incomeAccountId: null == incomeAccountId ? _self.incomeAccountId : incomeAccountId // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,documents: freezed == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,
  ));
}


}


/// @nodoc
mixin _$ProductListApi {

@JsonKey(fromJson: _productListData) List<ProductApi> get data;
/// Create a copy of ProductListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductListApiCopyWith<ProductListApi> get copyWith => _$ProductListApiCopyWithImpl<ProductListApi>(this as ProductListApi, _$identity);

  /// Serializes this ProductListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'ProductListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $ProductListApiCopyWith<$Res>  {
  factory $ProductListApiCopyWith(ProductListApi value, $Res Function(ProductListApi) _then) = _$ProductListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _productListData) List<ProductApi> data
});




}
/// @nodoc
class _$ProductListApiCopyWithImpl<$Res>
    implements $ProductListApiCopyWith<$Res> {
  _$ProductListApiCopyWithImpl(this._self, this._then);

  final ProductListApi _self;
  final $Res Function(ProductListApi) _then;

/// Create a copy of ProductListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<ProductApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductListApi].
extension ProductListApiPatterns on ProductListApi {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductListApi() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductListApi value)  $default,){
final _that = this;
switch (_that) {
case _ProductListApi():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductListApi value)?  $default,){
final _that = this;
switch (_that) {
case _ProductListApi() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _productListData)  List<ProductApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductListApi() when $default != null:
return $default(_that.data);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _productListData)  List<ProductApi> data)  $default,) {final _that = this;
switch (_that) {
case _ProductListApi():
return $default(_that.data);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _productListData)  List<ProductApi> data)?  $default,) {final _that = this;
switch (_that) {
case _ProductListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductListApi implements ProductListApi {
  const _ProductListApi({@JsonKey(fromJson: _productListData) final  List<ProductApi> data = const []}): _data = data;
  factory _ProductListApi.fromJson(Map<String, dynamic> json) => _$ProductListApiFromJson(json);

 final  List<ProductApi> _data;
@override@JsonKey(fromJson: _productListData) List<ProductApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of ProductListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductListApiCopyWith<_ProductListApi> get copyWith => __$ProductListApiCopyWithImpl<_ProductListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'ProductListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ProductListApiCopyWith<$Res> implements $ProductListApiCopyWith<$Res> {
  factory _$ProductListApiCopyWith(_ProductListApi value, $Res Function(_ProductListApi) _then) = __$ProductListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _productListData) List<ProductApi> data
});




}
/// @nodoc
class __$ProductListApiCopyWithImpl<$Res>
    implements _$ProductListApiCopyWith<$Res> {
  __$ProductListApiCopyWithImpl(this._self, this._then);

  final _ProductListApi _self;
  final $Res Function(_ProductListApi) _then;

/// Create a copy of ProductListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_ProductListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<ProductApi>,
  ));
}


}


/// @nodoc
mixin _$ProductItemApi {

 ProductApi get data;
/// Create a copy of ProductItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductItemApiCopyWith<ProductItemApi> get copyWith => _$ProductItemApiCopyWithImpl<ProductItemApi>(this as ProductItemApi, _$identity);

  /// Serializes this ProductItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'ProductItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $ProductItemApiCopyWith<$Res>  {
  factory $ProductItemApiCopyWith(ProductItemApi value, $Res Function(ProductItemApi) _then) = _$ProductItemApiCopyWithImpl;
@useResult
$Res call({
 ProductApi data
});


$ProductApiCopyWith<$Res> get data;

}
/// @nodoc
class _$ProductItemApiCopyWithImpl<$Res>
    implements $ProductItemApiCopyWith<$Res> {
  _$ProductItemApiCopyWithImpl(this._self, this._then);

  final ProductItemApi _self;
  final $Res Function(ProductItemApi) _then;

/// Create a copy of ProductItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ProductApi,
  ));
}
/// Create a copy of ProductItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProductApiCopyWith<$Res> get data {
  
  return $ProductApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProductItemApi].
extension ProductItemApiPatterns on ProductItemApi {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductItemApi() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductItemApi value)  $default,){
final _that = this;
switch (_that) {
case _ProductItemApi():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _ProductItemApi() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ProductApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductItemApi() when $default != null:
return $default(_that.data);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ProductApi data)  $default,) {final _that = this;
switch (_that) {
case _ProductItemApi():
return $default(_that.data);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ProductApi data)?  $default,) {final _that = this;
switch (_that) {
case _ProductItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductItemApi implements ProductItemApi {
  const _ProductItemApi({required this.data});
  factory _ProductItemApi.fromJson(Map<String, dynamic> json) => _$ProductItemApiFromJson(json);

@override final  ProductApi data;

/// Create a copy of ProductItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductItemApiCopyWith<_ProductItemApi> get copyWith => __$ProductItemApiCopyWithImpl<_ProductItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'ProductItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ProductItemApiCopyWith<$Res> implements $ProductItemApiCopyWith<$Res> {
  factory _$ProductItemApiCopyWith(_ProductItemApi value, $Res Function(_ProductItemApi) _then) = __$ProductItemApiCopyWithImpl;
@override @useResult
$Res call({
 ProductApi data
});


@override $ProductApiCopyWith<$Res> get data;

}
/// @nodoc
class __$ProductItemApiCopyWithImpl<$Res>
    implements _$ProductItemApiCopyWith<$Res> {
  __$ProductItemApiCopyWithImpl(this._self, this._then);

  final _ProductItemApi _self;
  final $Res Function(_ProductItemApi) _then;

/// Create a copy of ProductItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_ProductItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ProductApi,
  ));
}

/// Create a copy of ProductItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProductApiCopyWith<$Res> get data {
  
  return $ProductApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
