// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Product {

 String get id; String get productKey; String get notes; Decimal get cost; Decimal get price; Decimal get quantity; Decimal get maxQuantity; String get productImage; Decimal get inStockQuantity; bool get stockNotification; Decimal get stockNotificationThreshold; String get taxName1; Decimal get taxRate1; String get taxName2; Decimal get taxRate2; String get taxName3; Decimal get taxRate3; String get taxId; String get customValue1; String get customValue2; String get customValue3; String get customValue4; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; bool get isDeleted;// Read-only server fields. Surfaced so edits round-trip them instead of
// dropping them — `_domainToCompanion` rewrites the local payload column
// from `toApiJson` on every save. `userId` is the creator. Mirrors Client.
 String get userId; String get assignedUserId; String get incomeAccountId; List<Document> get documents; List<String> get tagIds; bool get isDirty;
/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductCopyWith<Product> get copyWith => _$ProductCopyWithImpl<Product>(this as Product, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Product&&(identical(other.id, id) || other.id == id)&&(identical(other.productKey, productKey) || other.productKey == productKey)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.price, price) || other.price == price)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.maxQuantity, maxQuantity) || other.maxQuantity == maxQuantity)&&(identical(other.productImage, productImage) || other.productImage == productImage)&&(identical(other.inStockQuantity, inStockQuantity) || other.inStockQuantity == inStockQuantity)&&(identical(other.stockNotification, stockNotification) || other.stockNotification == stockNotification)&&(identical(other.stockNotificationThreshold, stockNotificationThreshold) || other.stockNotificationThreshold == stockNotificationThreshold)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxRate1, taxRate1) || other.taxRate1 == taxRate1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxRate2, taxRate2) || other.taxRate2 == taxRate2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&(identical(other.taxRate3, taxRate3) || other.taxRate3 == taxRate3)&&(identical(other.taxId, taxId) || other.taxId == taxId)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.incomeAccountId, incomeAccountId) || other.incomeAccountId == incomeAccountId)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.tagIds, tagIds)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,productKey,notes,cost,price,quantity,maxQuantity,productImage,inStockQuantity,stockNotification,stockNotificationThreshold,taxName1,taxRate1,taxName2,taxRate2,taxName3,taxRate3,taxId,customValue1,customValue2,customValue3,customValue4,updatedAt,createdAt,archivedAt,isDeleted,userId,assignedUserId,incomeAccountId,const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(tagIds),isDirty]);

@override
String toString() {
  return 'Product(id: $id, productKey: $productKey, notes: $notes, cost: $cost, price: $price, quantity: $quantity, maxQuantity: $maxQuantity, productImage: $productImage, inStockQuantity: $inStockQuantity, stockNotification: $stockNotification, stockNotificationThreshold: $stockNotificationThreshold, taxName1: $taxName1, taxRate1: $taxRate1, taxName2: $taxName2, taxRate2: $taxRate2, taxName3: $taxName3, taxRate3: $taxRate3, taxId: $taxId, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDeleted: $isDeleted, userId: $userId, assignedUserId: $assignedUserId, incomeAccountId: $incomeAccountId, documents: $documents, tagIds: $tagIds, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class $ProductCopyWith<$Res>  {
  factory $ProductCopyWith(Product value, $Res Function(Product) _then) = _$ProductCopyWithImpl;
@useResult
$Res call({
 String id, String productKey, String notes, Decimal cost, Decimal price, Decimal quantity, Decimal maxQuantity, String productImage, Decimal inStockQuantity, bool stockNotification, Decimal stockNotificationThreshold, String taxName1, Decimal taxRate1, String taxName2, Decimal taxRate2, String taxName3, Decimal taxRate3, String taxId, String customValue1, String customValue2, String customValue3, String customValue4, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, String userId, String assignedUserId, String incomeAccountId, List<Document> documents, List<String> tagIds, bool isDirty
});




}
/// @nodoc
class _$ProductCopyWithImpl<$Res>
    implements $ProductCopyWith<$Res> {
  _$ProductCopyWithImpl(this._self, this._then);

  final Product _self;
  final $Res Function(Product) _then;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? productKey = null,Object? notes = null,Object? cost = null,Object? price = null,Object? quantity = null,Object? maxQuantity = null,Object? productImage = null,Object? inStockQuantity = null,Object? stockNotification = null,Object? stockNotificationThreshold = null,Object? taxName1 = null,Object? taxRate1 = null,Object? taxName2 = null,Object? taxRate2 = null,Object? taxName3 = null,Object? taxRate3 = null,Object? taxId = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? userId = null,Object? assignedUserId = null,Object? incomeAccountId = null,Object? documents = null,Object? tagIds = null,Object? isDirty = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,productKey: null == productKey ? _self.productKey : productKey // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,cost: null == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as Decimal,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as Decimal,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Decimal,maxQuantity: null == maxQuantity ? _self.maxQuantity : maxQuantity // ignore: cast_nullable_to_non_nullable
as Decimal,productImage: null == productImage ? _self.productImage : productImage // ignore: cast_nullable_to_non_nullable
as String,inStockQuantity: null == inStockQuantity ? _self.inStockQuantity : inStockQuantity // ignore: cast_nullable_to_non_nullable
as Decimal,stockNotification: null == stockNotification ? _self.stockNotification : stockNotification // ignore: cast_nullable_to_non_nullable
as bool,stockNotificationThreshold: null == stockNotificationThreshold ? _self.stockNotificationThreshold : stockNotificationThreshold // ignore: cast_nullable_to_non_nullable
as Decimal,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 // ignore: cast_nullable_to_non_nullable
as Decimal,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 // ignore: cast_nullable_to_non_nullable
as Decimal,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 // ignore: cast_nullable_to_non_nullable
as Decimal,taxId: null == taxId ? _self.taxId : taxId // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,incomeAccountId: null == incomeAccountId ? _self.incomeAccountId : incomeAccountId // ignore: cast_nullable_to_non_nullable
as String,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Product].
extension ProductPatterns on Product {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Product value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Product() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Product value)  $default,){
final _that = this;
switch (_that) {
case _Product():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Product value)?  $default,){
final _that = this;
switch (_that) {
case _Product() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String productKey,  String notes,  Decimal cost,  Decimal price,  Decimal quantity,  Decimal maxQuantity,  String productImage,  Decimal inStockQuantity,  bool stockNotification,  Decimal stockNotificationThreshold,  String taxName1,  Decimal taxRate1,  String taxName2,  Decimal taxRate2,  String taxName3,  Decimal taxRate3,  String taxId,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  String userId,  String assignedUserId,  String incomeAccountId,  List<Document> documents,  List<String> tagIds,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.id,_that.productKey,_that.notes,_that.cost,_that.price,_that.quantity,_that.maxQuantity,_that.productImage,_that.inStockQuantity,_that.stockNotification,_that.stockNotificationThreshold,_that.taxName1,_that.taxRate1,_that.taxName2,_that.taxRate2,_that.taxName3,_that.taxRate3,_that.taxId,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.userId,_that.assignedUserId,_that.incomeAccountId,_that.documents,_that.tagIds,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String productKey,  String notes,  Decimal cost,  Decimal price,  Decimal quantity,  Decimal maxQuantity,  String productImage,  Decimal inStockQuantity,  bool stockNotification,  Decimal stockNotificationThreshold,  String taxName1,  Decimal taxRate1,  String taxName2,  Decimal taxRate2,  String taxName3,  Decimal taxRate3,  String taxId,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  String userId,  String assignedUserId,  String incomeAccountId,  List<Document> documents,  List<String> tagIds,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _Product():
return $default(_that.id,_that.productKey,_that.notes,_that.cost,_that.price,_that.quantity,_that.maxQuantity,_that.productImage,_that.inStockQuantity,_that.stockNotification,_that.stockNotificationThreshold,_that.taxName1,_that.taxRate1,_that.taxName2,_that.taxRate2,_that.taxName3,_that.taxRate3,_that.taxId,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.userId,_that.assignedUserId,_that.incomeAccountId,_that.documents,_that.tagIds,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String productKey,  String notes,  Decimal cost,  Decimal price,  Decimal quantity,  Decimal maxQuantity,  String productImage,  Decimal inStockQuantity,  bool stockNotification,  Decimal stockNotificationThreshold,  String taxName1,  Decimal taxRate1,  String taxName2,  Decimal taxRate2,  String taxName3,  Decimal taxRate3,  String taxId,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  String userId,  String assignedUserId,  String incomeAccountId,  List<Document> documents,  List<String> tagIds,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.id,_that.productKey,_that.notes,_that.cost,_that.price,_that.quantity,_that.maxQuantity,_that.productImage,_that.inStockQuantity,_that.stockNotification,_that.stockNotificationThreshold,_that.taxName1,_that.taxRate1,_that.taxName2,_that.taxRate2,_that.taxName3,_that.taxRate3,_that.taxId,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.userId,_that.assignedUserId,_that.incomeAccountId,_that.documents,_that.tagIds,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _Product implements Product {
  const _Product({required this.id, required this.productKey, required this.notes, required this.cost, required this.price, required this.quantity, required this.maxQuantity, required this.productImage, required this.inStockQuantity, required this.stockNotification, required this.stockNotificationThreshold, required this.taxName1, required this.taxRate1, required this.taxName2, required this.taxRate2, required this.taxName3, required this.taxRate3, required this.taxId, required this.customValue1, required this.customValue2, required this.customValue3, required this.customValue4, required this.updatedAt, required this.createdAt, required this.archivedAt, required this.isDeleted, this.userId = '', this.assignedUserId = '', this.incomeAccountId = '', final  List<Document> documents = const <Document>[], final  List<String> tagIds = const <String>[], this.isDirty = false}): _documents = documents,_tagIds = tagIds;
  

@override final  String id;
@override final  String productKey;
@override final  String notes;
@override final  Decimal cost;
@override final  Decimal price;
@override final  Decimal quantity;
@override final  Decimal maxQuantity;
@override final  String productImage;
@override final  Decimal inStockQuantity;
@override final  bool stockNotification;
@override final  Decimal stockNotificationThreshold;
@override final  String taxName1;
@override final  Decimal taxRate1;
@override final  String taxName2;
@override final  Decimal taxRate2;
@override final  String taxName3;
@override final  Decimal taxRate3;
@override final  String taxId;
@override final  String customValue1;
@override final  String customValue2;
@override final  String customValue3;
@override final  String customValue4;
@override final  DateTime updatedAt;
@override final  DateTime createdAt;
@override final  DateTime? archivedAt;
@override final  bool isDeleted;
// Read-only server fields. Surfaced so edits round-trip them instead of
// dropping them — `_domainToCompanion` rewrites the local payload column
// from `toApiJson` on every save. `userId` is the creator. Mirrors Client.
@override@JsonKey() final  String userId;
@override@JsonKey() final  String assignedUserId;
@override@JsonKey() final  String incomeAccountId;
 final  List<Document> _documents;
@override@JsonKey() List<Document> get documents {
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_documents);
}

 final  List<String> _tagIds;
@override@JsonKey() List<String> get tagIds {
  if (_tagIds is EqualUnmodifiableListView) return _tagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tagIds);
}

@override@JsonKey() final  bool isDirty;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductCopyWith<_Product> get copyWith => __$ProductCopyWithImpl<_Product>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Product&&(identical(other.id, id) || other.id == id)&&(identical(other.productKey, productKey) || other.productKey == productKey)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.price, price) || other.price == price)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.maxQuantity, maxQuantity) || other.maxQuantity == maxQuantity)&&(identical(other.productImage, productImage) || other.productImage == productImage)&&(identical(other.inStockQuantity, inStockQuantity) || other.inStockQuantity == inStockQuantity)&&(identical(other.stockNotification, stockNotification) || other.stockNotification == stockNotification)&&(identical(other.stockNotificationThreshold, stockNotificationThreshold) || other.stockNotificationThreshold == stockNotificationThreshold)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxRate1, taxRate1) || other.taxRate1 == taxRate1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxRate2, taxRate2) || other.taxRate2 == taxRate2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&(identical(other.taxRate3, taxRate3) || other.taxRate3 == taxRate3)&&(identical(other.taxId, taxId) || other.taxId == taxId)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.incomeAccountId, incomeAccountId) || other.incomeAccountId == incomeAccountId)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._tagIds, _tagIds)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,productKey,notes,cost,price,quantity,maxQuantity,productImage,inStockQuantity,stockNotification,stockNotificationThreshold,taxName1,taxRate1,taxName2,taxRate2,taxName3,taxRate3,taxId,customValue1,customValue2,customValue3,customValue4,updatedAt,createdAt,archivedAt,isDeleted,userId,assignedUserId,incomeAccountId,const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_tagIds),isDirty]);

@override
String toString() {
  return 'Product(id: $id, productKey: $productKey, notes: $notes, cost: $cost, price: $price, quantity: $quantity, maxQuantity: $maxQuantity, productImage: $productImage, inStockQuantity: $inStockQuantity, stockNotification: $stockNotification, stockNotificationThreshold: $stockNotificationThreshold, taxName1: $taxName1, taxRate1: $taxRate1, taxName2: $taxName2, taxRate2: $taxRate2, taxName3: $taxName3, taxRate3: $taxRate3, taxId: $taxId, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDeleted: $isDeleted, userId: $userId, assignedUserId: $assignedUserId, incomeAccountId: $incomeAccountId, documents: $documents, tagIds: $tagIds, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$ProductCopyWith<$Res> implements $ProductCopyWith<$Res> {
  factory _$ProductCopyWith(_Product value, $Res Function(_Product) _then) = __$ProductCopyWithImpl;
@override @useResult
$Res call({
 String id, String productKey, String notes, Decimal cost, Decimal price, Decimal quantity, Decimal maxQuantity, String productImage, Decimal inStockQuantity, bool stockNotification, Decimal stockNotificationThreshold, String taxName1, Decimal taxRate1, String taxName2, Decimal taxRate2, String taxName3, Decimal taxRate3, String taxId, String customValue1, String customValue2, String customValue3, String customValue4, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, String userId, String assignedUserId, String incomeAccountId, List<Document> documents, List<String> tagIds, bool isDirty
});




}
/// @nodoc
class __$ProductCopyWithImpl<$Res>
    implements _$ProductCopyWith<$Res> {
  __$ProductCopyWithImpl(this._self, this._then);

  final _Product _self;
  final $Res Function(_Product) _then;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? productKey = null,Object? notes = null,Object? cost = null,Object? price = null,Object? quantity = null,Object? maxQuantity = null,Object? productImage = null,Object? inStockQuantity = null,Object? stockNotification = null,Object? stockNotificationThreshold = null,Object? taxName1 = null,Object? taxRate1 = null,Object? taxName2 = null,Object? taxRate2 = null,Object? taxName3 = null,Object? taxRate3 = null,Object? taxId = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? userId = null,Object? assignedUserId = null,Object? incomeAccountId = null,Object? documents = null,Object? tagIds = null,Object? isDirty = null,}) {
  return _then(_Product(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,productKey: null == productKey ? _self.productKey : productKey // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,cost: null == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as Decimal,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as Decimal,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Decimal,maxQuantity: null == maxQuantity ? _self.maxQuantity : maxQuantity // ignore: cast_nullable_to_non_nullable
as Decimal,productImage: null == productImage ? _self.productImage : productImage // ignore: cast_nullable_to_non_nullable
as String,inStockQuantity: null == inStockQuantity ? _self.inStockQuantity : inStockQuantity // ignore: cast_nullable_to_non_nullable
as Decimal,stockNotification: null == stockNotification ? _self.stockNotification : stockNotification // ignore: cast_nullable_to_non_nullable
as bool,stockNotificationThreshold: null == stockNotificationThreshold ? _self.stockNotificationThreshold : stockNotificationThreshold // ignore: cast_nullable_to_non_nullable
as Decimal,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 // ignore: cast_nullable_to_non_nullable
as Decimal,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 // ignore: cast_nullable_to_non_nullable
as Decimal,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 // ignore: cast_nullable_to_non_nullable
as Decimal,taxId: null == taxId ? _self.taxId : taxId // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,incomeAccountId: null == incomeAccountId ? _self.incomeAccountId : incomeAccountId // ignore: cast_nullable_to_non_nullable
as String,documents: null == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
