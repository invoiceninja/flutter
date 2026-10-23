// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'line_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LineItem {

 String get productKey; String get notes; Decimal get cost; Decimal get productCost; Decimal get quantity; String get taxName1; String get taxName2; String get taxName3; Decimal get taxRate1; Decimal get taxRate2; Decimal get taxRate3; LineItemType get typeId; String get customValue1; String get customValue2; String get customValue3; String get customValue4; Decimal get discount; String? get taskId; String? get expenseId; String get taxCategoryId; int? get createdAt;
/// Create a copy of LineItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LineItemCopyWith<LineItem> get copyWith => _$LineItemCopyWithImpl<LineItem>(this as LineItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LineItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LineItem&&(identical(other.productKey, _this.productKey) || other.productKey == _this.productKey)&&(identical(other.notes, _this.notes) || other.notes == _this.notes)&&(identical(other.cost, _this.cost) || other.cost == _this.cost)&&(identical(other.productCost, _this.productCost) || other.productCost == _this.productCost)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity)&&(identical(other.taxName1, _this.taxName1) || other.taxName1 == _this.taxName1)&&(identical(other.taxName2, _this.taxName2) || other.taxName2 == _this.taxName2)&&(identical(other.taxName3, _this.taxName3) || other.taxName3 == _this.taxName3)&&(identical(other.taxRate1, _this.taxRate1) || other.taxRate1 == _this.taxRate1)&&(identical(other.taxRate2, _this.taxRate2) || other.taxRate2 == _this.taxRate2)&&(identical(other.taxRate3, _this.taxRate3) || other.taxRate3 == _this.taxRate3)&&(identical(other.typeId, _this.typeId) || other.typeId == _this.typeId)&&(identical(other.customValue1, _this.customValue1) || other.customValue1 == _this.customValue1)&&(identical(other.customValue2, _this.customValue2) || other.customValue2 == _this.customValue2)&&(identical(other.customValue3, _this.customValue3) || other.customValue3 == _this.customValue3)&&(identical(other.customValue4, _this.customValue4) || other.customValue4 == _this.customValue4)&&(identical(other.discount, _this.discount) || other.discount == _this.discount)&&(identical(other.taskId, _this.taskId) || other.taskId == _this.taskId)&&(identical(other.expenseId, _this.expenseId) || other.expenseId == _this.expenseId)&&(identical(other.taxCategoryId, _this.taxCategoryId) || other.taxCategoryId == _this.taxCategoryId)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}


@override
int get hashCode {
  final _this = this as LineItem;
  return Object.hashAll([runtimeType,_this.productKey,_this.notes,_this.cost,_this.productCost,_this.quantity,_this.taxName1,_this.taxName2,_this.taxName3,_this.taxRate1,_this.taxRate2,_this.taxRate3,_this.typeId,_this.customValue1,_this.customValue2,_this.customValue3,_this.customValue4,_this.discount,_this.taskId,_this.expenseId,_this.taxCategoryId,_this.createdAt]);
}

@override
String toString() {
  final _this = this as LineItem;
  return 'LineItem(productKey: ${_this.productKey}, notes: ${_this.notes}, cost: ${_this.cost}, productCost: ${_this.productCost}, quantity: ${_this.quantity}, taxName1: ${_this.taxName1}, taxName2: ${_this.taxName2}, taxName3: ${_this.taxName3}, taxRate1: ${_this.taxRate1}, taxRate2: ${_this.taxRate2}, taxRate3: ${_this.taxRate3}, typeId: ${_this.typeId}, customValue1: ${_this.customValue1}, customValue2: ${_this.customValue2}, customValue3: ${_this.customValue3}, customValue4: ${_this.customValue4}, discount: ${_this.discount}, taskId: ${_this.taskId}, expenseId: ${_this.expenseId}, taxCategoryId: ${_this.taxCategoryId}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $LineItemCopyWith<$Res>  {
  factory $LineItemCopyWith(LineItem value, $Res Function(LineItem) _then) = _$LineItemCopyWithImpl;
@useResult
$Res call({
 String productKey, String notes, Decimal cost, Decimal productCost, Decimal quantity, String taxName1, String taxName2, String taxName3, Decimal taxRate1, Decimal taxRate2, Decimal taxRate3, LineItemType typeId, String customValue1, String customValue2, String customValue3, String customValue4, Decimal discount, String? taskId, String? expenseId, String taxCategoryId, int? createdAt
});




}
/// @nodoc
class _$LineItemCopyWithImpl<$Res>
    implements $LineItemCopyWith<$Res> {
  _$LineItemCopyWithImpl(this._self, this._then);

  final LineItem _self;
  final $Res Function(LineItem) _then;

/// Create a copy of LineItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productKey = null,Object? notes = null,Object? cost = null,Object? productCost = null,Object? quantity = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? typeId = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? discount = null,Object? taskId = freezed,Object? expenseId = freezed,Object? taxCategoryId = null,Object? createdAt = freezed,}) {
  return _then(LineItem(
productKey: null == productKey ? _self.productKey : productKey // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,cost: null == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as Decimal,productCost: null == productCost ? _self.productCost : productCost // ignore: cast_nullable_to_non_nullable
as Decimal,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Decimal,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 // ignore: cast_nullable_to_non_nullable
as Decimal,typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as LineItemType,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as Decimal,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,expenseId: freezed == expenseId ? _self.expenseId : expenseId // ignore: cast_nullable_to_non_nullable
as String?,taxCategoryId: null == taxCategoryId ? _self.taxCategoryId : taxCategoryId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LineItem].
extension LineItemPatterns on LineItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LineItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LineItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LineItem value)  $default,){
final _that = this;
switch (_that) {
case _LineItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LineItem value)?  $default,){
final _that = this;
switch (_that) {
case _LineItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String productKey,  String notes,  Decimal cost,  Decimal productCost,  Decimal quantity,  String taxName1,  String taxName2,  String taxName3,  Decimal taxRate1,  Decimal taxRate2,  Decimal taxRate3,  LineItemType typeId,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  Decimal discount,  String? taskId,  String? expenseId,  String taxCategoryId,  int? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LineItem() when $default != null:
return $default(_that.productKey,_that.notes,_that.cost,_that.productCost,_that.quantity,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.typeId,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.discount,_that.taskId,_that.expenseId,_that.taxCategoryId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String productKey,  String notes,  Decimal cost,  Decimal productCost,  Decimal quantity,  String taxName1,  String taxName2,  String taxName3,  Decimal taxRate1,  Decimal taxRate2,  Decimal taxRate3,  LineItemType typeId,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  Decimal discount,  String? taskId,  String? expenseId,  String taxCategoryId,  int? createdAt)  $default,) {final _that = this;
switch (_that) {
case _LineItem():
return $default(_that.productKey,_that.notes,_that.cost,_that.productCost,_that.quantity,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.typeId,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.discount,_that.taskId,_that.expenseId,_that.taxCategoryId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String productKey,  String notes,  Decimal cost,  Decimal productCost,  Decimal quantity,  String taxName1,  String taxName2,  String taxName3,  Decimal taxRate1,  Decimal taxRate2,  Decimal taxRate3,  LineItemType typeId,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  Decimal discount,  String? taskId,  String? expenseId,  String taxCategoryId,  int? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LineItem() when $default != null:
return $default(_that.productKey,_that.notes,_that.cost,_that.productCost,_that.quantity,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.typeId,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.discount,_that.taskId,_that.expenseId,_that.taxCategoryId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _LineItem implements LineItem {
  const _LineItem({required this.productKey, required this.notes, required this.cost, required this.productCost, required this.quantity, required this.taxName1, required this.taxName2, required this.taxName3, required this.taxRate1, required this.taxRate2, required this.taxRate3, required this.typeId, required this.customValue1, required this.customValue2, required this.customValue3, required this.customValue4, required this.discount, this.taskId, this.expenseId, required this.taxCategoryId, this.createdAt});
  

@override final  String productKey;
@override final  String notes;
@override final  Decimal cost;
@override final  Decimal productCost;
@override final  Decimal quantity;
@override final  String taxName1;
@override final  String taxName2;
@override final  String taxName3;
@override final  Decimal taxRate1;
@override final  Decimal taxRate2;
@override final  Decimal taxRate3;
@override final  LineItemType typeId;
@override final  String customValue1;
@override final  String customValue2;
@override final  String customValue3;
@override final  String customValue4;
@override final  Decimal discount;
@override final  String? taskId;
@override final  String? expenseId;
@override final  String taxCategoryId;
@override final  int? createdAt;

/// Create a copy of LineItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LineItemCopyWith<_LineItem> get copyWith => __$LineItemCopyWithImpl<_LineItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LineItem&&(identical(other.productKey, productKey) || other.productKey == productKey)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.productCost, productCost) || other.productCost == productCost)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&(identical(other.taxRate1, taxRate1) || other.taxRate1 == taxRate1)&&(identical(other.taxRate2, taxRate2) || other.taxRate2 == taxRate2)&&(identical(other.taxRate3, taxRate3) || other.taxRate3 == taxRate3)&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.discount, discount) || other.discount == discount)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.expenseId, expenseId) || other.expenseId == expenseId)&&(identical(other.taxCategoryId, taxCategoryId) || other.taxCategoryId == taxCategoryId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,productKey,notes,cost,productCost,quantity,taxName1,taxName2,taxName3,taxRate1,taxRate2,taxRate3,typeId,customValue1,customValue2,customValue3,customValue4,discount,taskId,expenseId,taxCategoryId,createdAt]);
}

@override
String toString() {
    return 'LineItem(productKey: $productKey, notes: $notes, cost: $cost, productCost: $productCost, quantity: $quantity, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, typeId: $typeId, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, discount: $discount, taskId: $taskId, expenseId: $expenseId, taxCategoryId: $taxCategoryId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LineItemCopyWith<$Res> implements $LineItemCopyWith<$Res> {
  factory _$LineItemCopyWith(_LineItem value, $Res Function(_LineItem) _then) = __$LineItemCopyWithImpl;
@override @useResult
$Res call({
 String productKey, String notes, Decimal cost, Decimal productCost, Decimal quantity, String taxName1, String taxName2, String taxName3, Decimal taxRate1, Decimal taxRate2, Decimal taxRate3, LineItemType typeId, String customValue1, String customValue2, String customValue3, String customValue4, Decimal discount, String? taskId, String? expenseId, String taxCategoryId, int? createdAt
});




}
/// @nodoc
class __$LineItemCopyWithImpl<$Res>
    implements _$LineItemCopyWith<$Res> {
  __$LineItemCopyWithImpl(this._self, this._then);

  final _LineItem _self;
  final $Res Function(_LineItem) _then;

/// Create a copy of LineItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productKey = null,Object? notes = null,Object? cost = null,Object? productCost = null,Object? quantity = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? typeId = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? discount = null,Object? taskId = freezed,Object? expenseId = freezed,Object? taxCategoryId = null,Object? createdAt = freezed,}) {
  return _then(_LineItem(
productKey: null == productKey ? _self.productKey : productKey // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,cost: null == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as Decimal,productCost: null == productCost ? _self.productCost : productCost // ignore: cast_nullable_to_non_nullable
as Decimal,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Decimal,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 // ignore: cast_nullable_to_non_nullable
as Decimal,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 // ignore: cast_nullable_to_non_nullable
as Decimal,typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as LineItemType,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,discount: null == discount ? _self.discount : discount // ignore: cast_nullable_to_non_nullable
as Decimal,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,expenseId: freezed == expenseId ? _self.expenseId : expenseId // ignore: cast_nullable_to_non_nullable
as String?,taxCategoryId: null == taxCategoryId ? _self.taxCategoryId : taxCategoryId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
