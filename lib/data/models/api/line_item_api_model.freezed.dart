// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'line_item_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LineItemApi {

@JsonKey(name: 'product_key', fromJson: jsonScalarToStringOrEmpty) String get productKey;@JsonKey(fromJson: jsonScalarToStringOrEmpty) String get notes; Object get cost;@JsonKey(name: 'product_cost') Object get productCost; Object get quantity;@JsonKey(name: 'tax_name1', fromJson: jsonScalarToStringOrEmpty) String get taxName1;@JsonKey(name: 'tax_name2', fromJson: jsonScalarToStringOrEmpty) String get taxName2;@JsonKey(name: 'tax_name3', fromJson: jsonScalarToStringOrEmpty) String get taxName3;@JsonKey(name: 'tax_rate1') Object get taxRate1;@JsonKey(name: 'tax_rate2') Object get taxRate2;@JsonKey(name: 'tax_rate3') Object get taxRate3;@JsonKey(name: 'type_id', fromJson: jsonScalarToStringOrEmpty) String get typeId;@JsonKey(name: 'custom_value1', fromJson: jsonScalarToStringOrEmpty) String get customValue1;@JsonKey(name: 'custom_value2', fromJson: jsonScalarToStringOrEmpty) String get customValue2;@JsonKey(name: 'custom_value3', fromJson: jsonScalarToStringOrEmpty) String get customValue3;@JsonKey(name: 'custom_value4', fromJson: jsonScalarToStringOrEmpty) String get customValue4; Object get discount;@JsonKey(name: 'task_id', fromJson: jsonScalarToString) String? get taskId;@JsonKey(name: 'expense_id', fromJson: jsonScalarToString) String? get expenseId;// Legacy admin-portal calls this `tax_id` on the wire; the domain
// model surfaces it as `taxCategoryId` so it doesn't collide with
// the `taxName1` / `taxRate1` triple.
@JsonKey(name: 'tax_id', fromJson: jsonScalarToStringOrEmpty) String get taxCategoryId;@JsonKey(name: 'created_at') int? get createdAt;
/// Create a copy of LineItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LineItemApiCopyWith<LineItemApi> get copyWith => _$LineItemApiCopyWithImpl<LineItemApi>(this as LineItemApi, _$identity);

  /// Serializes this LineItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LineItemApi&&(identical(other.productKey, productKey) || other.productKey == productKey)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other.cost, cost)&&const DeepCollectionEquality().equals(other.productCost, productCost)&&const DeepCollectionEquality().equals(other.quantity, quantity)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&const DeepCollectionEquality().equals(other.taxRate1, taxRate1)&&const DeepCollectionEquality().equals(other.taxRate2, taxRate2)&&const DeepCollectionEquality().equals(other.taxRate3, taxRate3)&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&const DeepCollectionEquality().equals(other.discount, discount)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.expenseId, expenseId) || other.expenseId == expenseId)&&(identical(other.taxCategoryId, taxCategoryId) || other.taxCategoryId == taxCategoryId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,productKey,notes,const DeepCollectionEquality().hash(cost),const DeepCollectionEquality().hash(productCost),const DeepCollectionEquality().hash(quantity),taxName1,taxName2,taxName3,const DeepCollectionEquality().hash(taxRate1),const DeepCollectionEquality().hash(taxRate2),const DeepCollectionEquality().hash(taxRate3),typeId,customValue1,customValue2,customValue3,customValue4,const DeepCollectionEquality().hash(discount),taskId,expenseId,taxCategoryId,createdAt]);

@override
String toString() {
  return 'LineItemApi(productKey: $productKey, notes: $notes, cost: $cost, productCost: $productCost, quantity: $quantity, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, typeId: $typeId, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, discount: $discount, taskId: $taskId, expenseId: $expenseId, taxCategoryId: $taxCategoryId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $LineItemApiCopyWith<$Res>  {
  factory $LineItemApiCopyWith(LineItemApi value, $Res Function(LineItemApi) _then) = _$LineItemApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'product_key', fromJson: jsonScalarToStringOrEmpty) String productKey,@JsonKey(fromJson: jsonScalarToStringOrEmpty) String notes, Object cost,@JsonKey(name: 'product_cost') Object productCost, Object quantity,@JsonKey(name: 'tax_name1', fromJson: jsonScalarToStringOrEmpty) String taxName1,@JsonKey(name: 'tax_name2', fromJson: jsonScalarToStringOrEmpty) String taxName2,@JsonKey(name: 'tax_name3', fromJson: jsonScalarToStringOrEmpty) String taxName3,@JsonKey(name: 'tax_rate1') Object taxRate1,@JsonKey(name: 'tax_rate2') Object taxRate2,@JsonKey(name: 'tax_rate3') Object taxRate3,@JsonKey(name: 'type_id', fromJson: jsonScalarToStringOrEmpty) String typeId,@JsonKey(name: 'custom_value1', fromJson: jsonScalarToStringOrEmpty) String customValue1,@JsonKey(name: 'custom_value2', fromJson: jsonScalarToStringOrEmpty) String customValue2,@JsonKey(name: 'custom_value3', fromJson: jsonScalarToStringOrEmpty) String customValue3,@JsonKey(name: 'custom_value4', fromJson: jsonScalarToStringOrEmpty) String customValue4, Object discount,@JsonKey(name: 'task_id', fromJson: jsonScalarToString) String? taskId,@JsonKey(name: 'expense_id', fromJson: jsonScalarToString) String? expenseId,@JsonKey(name: 'tax_id', fromJson: jsonScalarToStringOrEmpty) String taxCategoryId,@JsonKey(name: 'created_at') int? createdAt
});




}
/// @nodoc
class _$LineItemApiCopyWithImpl<$Res>
    implements $LineItemApiCopyWith<$Res> {
  _$LineItemApiCopyWithImpl(this._self, this._then);

  final LineItemApi _self;
  final $Res Function(LineItemApi) _then;

/// Create a copy of LineItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productKey = null,Object? notes = null,Object? cost = null,Object? productCost = null,Object? quantity = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? typeId = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? discount = null,Object? taskId = freezed,Object? expenseId = freezed,Object? taxCategoryId = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
productKey: null == productKey ? _self.productKey : productKey // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,cost: null == cost ? _self.cost : cost ,productCost: null == productCost ? _self.productCost : productCost ,quantity: null == quantity ? _self.quantity : quantity ,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 ,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 ,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 ,typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,discount: null == discount ? _self.discount : discount ,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,expenseId: freezed == expenseId ? _self.expenseId : expenseId // ignore: cast_nullable_to_non_nullable
as String?,taxCategoryId: null == taxCategoryId ? _self.taxCategoryId : taxCategoryId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LineItemApi].
extension LineItemApiPatterns on LineItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LineItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LineItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LineItemApi value)  $default,){
final _that = this;
switch (_that) {
case _LineItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LineItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _LineItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'product_key', fromJson: jsonScalarToStringOrEmpty)  String productKey, @JsonKey(fromJson: jsonScalarToStringOrEmpty)  String notes,  Object cost, @JsonKey(name: 'product_cost')  Object productCost,  Object quantity, @JsonKey(name: 'tax_name1', fromJson: jsonScalarToStringOrEmpty)  String taxName1, @JsonKey(name: 'tax_name2', fromJson: jsonScalarToStringOrEmpty)  String taxName2, @JsonKey(name: 'tax_name3', fromJson: jsonScalarToStringOrEmpty)  String taxName3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'type_id', fromJson: jsonScalarToStringOrEmpty)  String typeId, @JsonKey(name: 'custom_value1', fromJson: jsonScalarToStringOrEmpty)  String customValue1, @JsonKey(name: 'custom_value2', fromJson: jsonScalarToStringOrEmpty)  String customValue2, @JsonKey(name: 'custom_value3', fromJson: jsonScalarToStringOrEmpty)  String customValue3, @JsonKey(name: 'custom_value4', fromJson: jsonScalarToStringOrEmpty)  String customValue4,  Object discount, @JsonKey(name: 'task_id', fromJson: jsonScalarToString)  String? taskId, @JsonKey(name: 'expense_id', fromJson: jsonScalarToString)  String? expenseId, @JsonKey(name: 'tax_id', fromJson: jsonScalarToStringOrEmpty)  String taxCategoryId, @JsonKey(name: 'created_at')  int? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LineItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'product_key', fromJson: jsonScalarToStringOrEmpty)  String productKey, @JsonKey(fromJson: jsonScalarToStringOrEmpty)  String notes,  Object cost, @JsonKey(name: 'product_cost')  Object productCost,  Object quantity, @JsonKey(name: 'tax_name1', fromJson: jsonScalarToStringOrEmpty)  String taxName1, @JsonKey(name: 'tax_name2', fromJson: jsonScalarToStringOrEmpty)  String taxName2, @JsonKey(name: 'tax_name3', fromJson: jsonScalarToStringOrEmpty)  String taxName3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'type_id', fromJson: jsonScalarToStringOrEmpty)  String typeId, @JsonKey(name: 'custom_value1', fromJson: jsonScalarToStringOrEmpty)  String customValue1, @JsonKey(name: 'custom_value2', fromJson: jsonScalarToStringOrEmpty)  String customValue2, @JsonKey(name: 'custom_value3', fromJson: jsonScalarToStringOrEmpty)  String customValue3, @JsonKey(name: 'custom_value4', fromJson: jsonScalarToStringOrEmpty)  String customValue4,  Object discount, @JsonKey(name: 'task_id', fromJson: jsonScalarToString)  String? taskId, @JsonKey(name: 'expense_id', fromJson: jsonScalarToString)  String? expenseId, @JsonKey(name: 'tax_id', fromJson: jsonScalarToStringOrEmpty)  String taxCategoryId, @JsonKey(name: 'created_at')  int? createdAt)  $default,) {final _that = this;
switch (_that) {
case _LineItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'product_key', fromJson: jsonScalarToStringOrEmpty)  String productKey, @JsonKey(fromJson: jsonScalarToStringOrEmpty)  String notes,  Object cost, @JsonKey(name: 'product_cost')  Object productCost,  Object quantity, @JsonKey(name: 'tax_name1', fromJson: jsonScalarToStringOrEmpty)  String taxName1, @JsonKey(name: 'tax_name2', fromJson: jsonScalarToStringOrEmpty)  String taxName2, @JsonKey(name: 'tax_name3', fromJson: jsonScalarToStringOrEmpty)  String taxName3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'type_id', fromJson: jsonScalarToStringOrEmpty)  String typeId, @JsonKey(name: 'custom_value1', fromJson: jsonScalarToStringOrEmpty)  String customValue1, @JsonKey(name: 'custom_value2', fromJson: jsonScalarToStringOrEmpty)  String customValue2, @JsonKey(name: 'custom_value3', fromJson: jsonScalarToStringOrEmpty)  String customValue3, @JsonKey(name: 'custom_value4', fromJson: jsonScalarToStringOrEmpty)  String customValue4,  Object discount, @JsonKey(name: 'task_id', fromJson: jsonScalarToString)  String? taskId, @JsonKey(name: 'expense_id', fromJson: jsonScalarToString)  String? expenseId, @JsonKey(name: 'tax_id', fromJson: jsonScalarToStringOrEmpty)  String taxCategoryId, @JsonKey(name: 'created_at')  int? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LineItemApi() when $default != null:
return $default(_that.productKey,_that.notes,_that.cost,_that.productCost,_that.quantity,_that.taxName1,_that.taxName2,_that.taxName3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.typeId,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.discount,_that.taskId,_that.expenseId,_that.taxCategoryId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LineItemApi implements LineItemApi {
  const _LineItemApi({@JsonKey(name: 'product_key', fromJson: jsonScalarToStringOrEmpty) this.productKey = '', @JsonKey(fromJson: jsonScalarToStringOrEmpty) this.notes = '', this.cost = '0', @JsonKey(name: 'product_cost') this.productCost = '0', this.quantity = '1', @JsonKey(name: 'tax_name1', fromJson: jsonScalarToStringOrEmpty) this.taxName1 = '', @JsonKey(name: 'tax_name2', fromJson: jsonScalarToStringOrEmpty) this.taxName2 = '', @JsonKey(name: 'tax_name3', fromJson: jsonScalarToStringOrEmpty) this.taxName3 = '', @JsonKey(name: 'tax_rate1') this.taxRate1 = '0', @JsonKey(name: 'tax_rate2') this.taxRate2 = '0', @JsonKey(name: 'tax_rate3') this.taxRate3 = '0', @JsonKey(name: 'type_id', fromJson: jsonScalarToStringOrEmpty) this.typeId = '1', @JsonKey(name: 'custom_value1', fromJson: jsonScalarToStringOrEmpty) this.customValue1 = '', @JsonKey(name: 'custom_value2', fromJson: jsonScalarToStringOrEmpty) this.customValue2 = '', @JsonKey(name: 'custom_value3', fromJson: jsonScalarToStringOrEmpty) this.customValue3 = '', @JsonKey(name: 'custom_value4', fromJson: jsonScalarToStringOrEmpty) this.customValue4 = '', this.discount = '0', @JsonKey(name: 'task_id', fromJson: jsonScalarToString) this.taskId, @JsonKey(name: 'expense_id', fromJson: jsonScalarToString) this.expenseId, @JsonKey(name: 'tax_id', fromJson: jsonScalarToStringOrEmpty) this.taxCategoryId = '', @JsonKey(name: 'created_at') this.createdAt});
  factory _LineItemApi.fromJson(Map<String, dynamic> json) => _$LineItemApiFromJson(json);

@override@JsonKey(name: 'product_key', fromJson: jsonScalarToStringOrEmpty) final  String productKey;
@override@JsonKey(fromJson: jsonScalarToStringOrEmpty) final  String notes;
@override@JsonKey() final  Object cost;
@override@JsonKey(name: 'product_cost') final  Object productCost;
@override@JsonKey() final  Object quantity;
@override@JsonKey(name: 'tax_name1', fromJson: jsonScalarToStringOrEmpty) final  String taxName1;
@override@JsonKey(name: 'tax_name2', fromJson: jsonScalarToStringOrEmpty) final  String taxName2;
@override@JsonKey(name: 'tax_name3', fromJson: jsonScalarToStringOrEmpty) final  String taxName3;
@override@JsonKey(name: 'tax_rate1') final  Object taxRate1;
@override@JsonKey(name: 'tax_rate2') final  Object taxRate2;
@override@JsonKey(name: 'tax_rate3') final  Object taxRate3;
@override@JsonKey(name: 'type_id', fromJson: jsonScalarToStringOrEmpty) final  String typeId;
@override@JsonKey(name: 'custom_value1', fromJson: jsonScalarToStringOrEmpty) final  String customValue1;
@override@JsonKey(name: 'custom_value2', fromJson: jsonScalarToStringOrEmpty) final  String customValue2;
@override@JsonKey(name: 'custom_value3', fromJson: jsonScalarToStringOrEmpty) final  String customValue3;
@override@JsonKey(name: 'custom_value4', fromJson: jsonScalarToStringOrEmpty) final  String customValue4;
@override@JsonKey() final  Object discount;
@override@JsonKey(name: 'task_id', fromJson: jsonScalarToString) final  String? taskId;
@override@JsonKey(name: 'expense_id', fromJson: jsonScalarToString) final  String? expenseId;
// Legacy admin-portal calls this `tax_id` on the wire; the domain
// model surfaces it as `taxCategoryId` so it doesn't collide with
// the `taxName1` / `taxRate1` triple.
@override@JsonKey(name: 'tax_id', fromJson: jsonScalarToStringOrEmpty) final  String taxCategoryId;
@override@JsonKey(name: 'created_at') final  int? createdAt;

/// Create a copy of LineItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LineItemApiCopyWith<_LineItemApi> get copyWith => __$LineItemApiCopyWithImpl<_LineItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LineItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LineItemApi&&(identical(other.productKey, productKey) || other.productKey == productKey)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other.cost, cost)&&const DeepCollectionEquality().equals(other.productCost, productCost)&&const DeepCollectionEquality().equals(other.quantity, quantity)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&const DeepCollectionEquality().equals(other.taxRate1, taxRate1)&&const DeepCollectionEquality().equals(other.taxRate2, taxRate2)&&const DeepCollectionEquality().equals(other.taxRate3, taxRate3)&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&const DeepCollectionEquality().equals(other.discount, discount)&&(identical(other.taskId, taskId) || other.taskId == taskId)&&(identical(other.expenseId, expenseId) || other.expenseId == expenseId)&&(identical(other.taxCategoryId, taxCategoryId) || other.taxCategoryId == taxCategoryId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,productKey,notes,const DeepCollectionEquality().hash(cost),const DeepCollectionEquality().hash(productCost),const DeepCollectionEquality().hash(quantity),taxName1,taxName2,taxName3,const DeepCollectionEquality().hash(taxRate1),const DeepCollectionEquality().hash(taxRate2),const DeepCollectionEquality().hash(taxRate3),typeId,customValue1,customValue2,customValue3,customValue4,const DeepCollectionEquality().hash(discount),taskId,expenseId,taxCategoryId,createdAt]);

@override
String toString() {
  return 'LineItemApi(productKey: $productKey, notes: $notes, cost: $cost, productCost: $productCost, quantity: $quantity, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, typeId: $typeId, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, discount: $discount, taskId: $taskId, expenseId: $expenseId, taxCategoryId: $taxCategoryId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LineItemApiCopyWith<$Res> implements $LineItemApiCopyWith<$Res> {
  factory _$LineItemApiCopyWith(_LineItemApi value, $Res Function(_LineItemApi) _then) = __$LineItemApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'product_key', fromJson: jsonScalarToStringOrEmpty) String productKey,@JsonKey(fromJson: jsonScalarToStringOrEmpty) String notes, Object cost,@JsonKey(name: 'product_cost') Object productCost, Object quantity,@JsonKey(name: 'tax_name1', fromJson: jsonScalarToStringOrEmpty) String taxName1,@JsonKey(name: 'tax_name2', fromJson: jsonScalarToStringOrEmpty) String taxName2,@JsonKey(name: 'tax_name3', fromJson: jsonScalarToStringOrEmpty) String taxName3,@JsonKey(name: 'tax_rate1') Object taxRate1,@JsonKey(name: 'tax_rate2') Object taxRate2,@JsonKey(name: 'tax_rate3') Object taxRate3,@JsonKey(name: 'type_id', fromJson: jsonScalarToStringOrEmpty) String typeId,@JsonKey(name: 'custom_value1', fromJson: jsonScalarToStringOrEmpty) String customValue1,@JsonKey(name: 'custom_value2', fromJson: jsonScalarToStringOrEmpty) String customValue2,@JsonKey(name: 'custom_value3', fromJson: jsonScalarToStringOrEmpty) String customValue3,@JsonKey(name: 'custom_value4', fromJson: jsonScalarToStringOrEmpty) String customValue4, Object discount,@JsonKey(name: 'task_id', fromJson: jsonScalarToString) String? taskId,@JsonKey(name: 'expense_id', fromJson: jsonScalarToString) String? expenseId,@JsonKey(name: 'tax_id', fromJson: jsonScalarToStringOrEmpty) String taxCategoryId,@JsonKey(name: 'created_at') int? createdAt
});




}
/// @nodoc
class __$LineItemApiCopyWithImpl<$Res>
    implements _$LineItemApiCopyWith<$Res> {
  __$LineItemApiCopyWithImpl(this._self, this._then);

  final _LineItemApi _self;
  final $Res Function(_LineItemApi) _then;

/// Create a copy of LineItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productKey = null,Object? notes = null,Object? cost = null,Object? productCost = null,Object? quantity = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? typeId = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? discount = null,Object? taskId = freezed,Object? expenseId = freezed,Object? taxCategoryId = null,Object? createdAt = freezed,}) {
  return _then(_LineItemApi(
productKey: null == productKey ? _self.productKey : productKey // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,cost: null == cost ? _self.cost : cost ,productCost: null == productCost ? _self.productCost : productCost ,quantity: null == quantity ? _self.quantity : quantity ,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 ,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 ,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 ,typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,discount: null == discount ? _self.discount : discount ,taskId: freezed == taskId ? _self.taskId : taskId // ignore: cast_nullable_to_non_nullable
as String?,expenseId: freezed == expenseId ? _self.expenseId : expenseId // ignore: cast_nullable_to_non_nullable
as String?,taxCategoryId: null == taxCategoryId ? _self.taxCategoryId : taxCategoryId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
