// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction_rule_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RuleCriterionApi {

@JsonKey(name: 'search_key') String get searchKey; String get operator; String get value;
/// Create a copy of RuleCriterionApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleCriterionApiCopyWith<RuleCriterionApi> get copyWith => _$RuleCriterionApiCopyWithImpl<RuleCriterionApi>(this as RuleCriterionApi, _$identity);

  /// Serializes this RuleCriterionApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuleCriterionApi&&(identical(other.searchKey, searchKey) || other.searchKey == searchKey)&&(identical(other.operator, operator) || other.operator == operator)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,searchKey,operator,value);

@override
String toString() {
  return 'RuleCriterionApi(searchKey: $searchKey, operator: $operator, value: $value)';
}


}

/// @nodoc
abstract mixin class $RuleCriterionApiCopyWith<$Res>  {
  factory $RuleCriterionApiCopyWith(RuleCriterionApi value, $Res Function(RuleCriterionApi) _then) = _$RuleCriterionApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'search_key') String searchKey, String operator, String value
});




}
/// @nodoc
class _$RuleCriterionApiCopyWithImpl<$Res>
    implements $RuleCriterionApiCopyWith<$Res> {
  _$RuleCriterionApiCopyWithImpl(this._self, this._then);

  final RuleCriterionApi _self;
  final $Res Function(RuleCriterionApi) _then;

/// Create a copy of RuleCriterionApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? searchKey = null,Object? operator = null,Object? value = null,}) {
  return _then(_self.copyWith(
searchKey: null == searchKey ? _self.searchKey : searchKey // ignore: cast_nullable_to_non_nullable
as String,operator: null == operator ? _self.operator : operator // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RuleCriterionApi].
extension RuleCriterionApiPatterns on RuleCriterionApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuleCriterionApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuleCriterionApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuleCriterionApi value)  $default,){
final _that = this;
switch (_that) {
case _RuleCriterionApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuleCriterionApi value)?  $default,){
final _that = this;
switch (_that) {
case _RuleCriterionApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'search_key')  String searchKey,  String operator,  String value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuleCriterionApi() when $default != null:
return $default(_that.searchKey,_that.operator,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'search_key')  String searchKey,  String operator,  String value)  $default,) {final _that = this;
switch (_that) {
case _RuleCriterionApi():
return $default(_that.searchKey,_that.operator,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'search_key')  String searchKey,  String operator,  String value)?  $default,) {final _that = this;
switch (_that) {
case _RuleCriterionApi() when $default != null:
return $default(_that.searchKey,_that.operator,_that.value);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _RuleCriterionApi implements RuleCriterionApi {
  const _RuleCriterionApi({@JsonKey(name: 'search_key') this.searchKey = '', this.operator = '', this.value = ''});
  factory _RuleCriterionApi.fromJson(Map<String, dynamic> json) => _$RuleCriterionApiFromJson(json);

@override@JsonKey(name: 'search_key') final  String searchKey;
@override@JsonKey() final  String operator;
@override@JsonKey() final  String value;

/// Create a copy of RuleCriterionApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleCriterionApiCopyWith<_RuleCriterionApi> get copyWith => __$RuleCriterionApiCopyWithImpl<_RuleCriterionApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RuleCriterionApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuleCriterionApi&&(identical(other.searchKey, searchKey) || other.searchKey == searchKey)&&(identical(other.operator, operator) || other.operator == operator)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,searchKey,operator,value);

@override
String toString() {
  return 'RuleCriterionApi(searchKey: $searchKey, operator: $operator, value: $value)';
}


}

/// @nodoc
abstract mixin class _$RuleCriterionApiCopyWith<$Res> implements $RuleCriterionApiCopyWith<$Res> {
  factory _$RuleCriterionApiCopyWith(_RuleCriterionApi value, $Res Function(_RuleCriterionApi) _then) = __$RuleCriterionApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'search_key') String searchKey, String operator, String value
});




}
/// @nodoc
class __$RuleCriterionApiCopyWithImpl<$Res>
    implements _$RuleCriterionApiCopyWith<$Res> {
  __$RuleCriterionApiCopyWithImpl(this._self, this._then);

  final _RuleCriterionApi _self;
  final $Res Function(_RuleCriterionApi) _then;

/// Create a copy of RuleCriterionApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? searchKey = null,Object? operator = null,Object? value = null,}) {
  return _then(_RuleCriterionApi(
searchKey: null == searchKey ? _self.searchKey : searchKey // ignore: cast_nullable_to_non_nullable
as String,operator: null == operator ? _self.operator : operator // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TransactionRuleApi {

 String get id; String get name;@JsonKey(name: 'applies_to') String get appliesTo;@JsonKey(name: 'matches_on_all') bool get matchesOnAll;@JsonKey(name: 'auto_convert') bool get autoConvert;@JsonKey(name: 'vendor_id') String get vendorId;@JsonKey(name: 'category_id') String get categoryId; List<RuleCriterionApi> get rules; Map<String, dynamic>? get vendor;@JsonKey(name: 'expense_category') Map<String, dynamic>? get expenseCategory;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;
/// Create a copy of TransactionRuleApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransactionRuleApiCopyWith<TransactionRuleApi> get copyWith => _$TransactionRuleApiCopyWithImpl<TransactionRuleApi>(this as TransactionRuleApi, _$identity);

  /// Serializes this TransactionRuleApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransactionRuleApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.appliesTo, appliesTo) || other.appliesTo == appliesTo)&&(identical(other.matchesOnAll, matchesOnAll) || other.matchesOnAll == matchesOnAll)&&(identical(other.autoConvert, autoConvert) || other.autoConvert == autoConvert)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&const DeepCollectionEquality().equals(other.rules, rules)&&const DeepCollectionEquality().equals(other.vendor, vendor)&&const DeepCollectionEquality().equals(other.expenseCategory, expenseCategory)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,appliesTo,matchesOnAll,autoConvert,vendorId,categoryId,const DeepCollectionEquality().hash(rules),const DeepCollectionEquality().hash(vendor),const DeepCollectionEquality().hash(expenseCategory),isDeleted,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'TransactionRuleApi(id: $id, name: $name, appliesTo: $appliesTo, matchesOnAll: $matchesOnAll, autoConvert: $autoConvert, vendorId: $vendorId, categoryId: $categoryId, rules: $rules, vendor: $vendor, expenseCategory: $expenseCategory, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class $TransactionRuleApiCopyWith<$Res>  {
  factory $TransactionRuleApiCopyWith(TransactionRuleApi value, $Res Function(TransactionRuleApi) _then) = _$TransactionRuleApiCopyWithImpl;
@useResult
$Res call({
 String id, String name,@JsonKey(name: 'applies_to') String appliesTo,@JsonKey(name: 'matches_on_all') bool matchesOnAll,@JsonKey(name: 'auto_convert') bool autoConvert,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'category_id') String categoryId, List<RuleCriterionApi> rules, Map<String, dynamic>? vendor,@JsonKey(name: 'expense_category') Map<String, dynamic>? expenseCategory,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class _$TransactionRuleApiCopyWithImpl<$Res>
    implements $TransactionRuleApiCopyWith<$Res> {
  _$TransactionRuleApiCopyWithImpl(this._self, this._then);

  final TransactionRuleApi _self;
  final $Res Function(TransactionRuleApi) _then;

/// Create a copy of TransactionRuleApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? appliesTo = null,Object? matchesOnAll = null,Object? autoConvert = null,Object? vendorId = null,Object? categoryId = null,Object? rules = null,Object? vendor = freezed,Object? expenseCategory = freezed,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,appliesTo: null == appliesTo ? _self.appliesTo : appliesTo // ignore: cast_nullable_to_non_nullable
as String,matchesOnAll: null == matchesOnAll ? _self.matchesOnAll : matchesOnAll // ignore: cast_nullable_to_non_nullable
as bool,autoConvert: null == autoConvert ? _self.autoConvert : autoConvert // ignore: cast_nullable_to_non_nullable
as bool,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,rules: null == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as List<RuleCriterionApi>,vendor: freezed == vendor ? _self.vendor : vendor // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,expenseCategory: freezed == expenseCategory ? _self.expenseCategory : expenseCategory // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TransactionRuleApi].
extension TransactionRuleApiPatterns on TransactionRuleApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransactionRuleApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransactionRuleApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransactionRuleApi value)  $default,){
final _that = this;
switch (_that) {
case _TransactionRuleApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransactionRuleApi value)?  $default,){
final _that = this;
switch (_that) {
case _TransactionRuleApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'applies_to')  String appliesTo, @JsonKey(name: 'matches_on_all')  bool matchesOnAll, @JsonKey(name: 'auto_convert')  bool autoConvert, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'category_id')  String categoryId,  List<RuleCriterionApi> rules,  Map<String, dynamic>? vendor, @JsonKey(name: 'expense_category')  Map<String, dynamic>? expenseCategory, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransactionRuleApi() when $default != null:
return $default(_that.id,_that.name,_that.appliesTo,_that.matchesOnAll,_that.autoConvert,_that.vendorId,_that.categoryId,_that.rules,_that.vendor,_that.expenseCategory,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'applies_to')  String appliesTo, @JsonKey(name: 'matches_on_all')  bool matchesOnAll, @JsonKey(name: 'auto_convert')  bool autoConvert, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'category_id')  String categoryId,  List<RuleCriterionApi> rules,  Map<String, dynamic>? vendor, @JsonKey(name: 'expense_category')  Map<String, dynamic>? expenseCategory, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)  $default,) {final _that = this;
switch (_that) {
case _TransactionRuleApi():
return $default(_that.id,_that.name,_that.appliesTo,_that.matchesOnAll,_that.autoConvert,_that.vendorId,_that.categoryId,_that.rules,_that.vendor,_that.expenseCategory,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name, @JsonKey(name: 'applies_to')  String appliesTo, @JsonKey(name: 'matches_on_all')  bool matchesOnAll, @JsonKey(name: 'auto_convert')  bool autoConvert, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'category_id')  String categoryId,  List<RuleCriterionApi> rules,  Map<String, dynamic>? vendor, @JsonKey(name: 'expense_category')  Map<String, dynamic>? expenseCategory, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _TransactionRuleApi() when $default != null:
return $default(_that.id,_that.name,_that.appliesTo,_that.matchesOnAll,_that.autoConvert,_that.vendorId,_that.categoryId,_that.rules,_that.vendor,_that.expenseCategory,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _TransactionRuleApi implements TransactionRuleApi {
  const _TransactionRuleApi({this.id = '', this.name = '', @JsonKey(name: 'applies_to') this.appliesTo = 'DEBIT', @JsonKey(name: 'matches_on_all') this.matchesOnAll = true, @JsonKey(name: 'auto_convert') this.autoConvert = false, @JsonKey(name: 'vendor_id') this.vendorId = '', @JsonKey(name: 'category_id') this.categoryId = '', final  List<RuleCriterionApi> rules = const <RuleCriterionApi>[], final  Map<String, dynamic>? vendor, @JsonKey(name: 'expense_category') final  Map<String, dynamic>? expenseCategory, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0}): _rules = rules,_vendor = vendor,_expenseCategory = expenseCategory;
  factory _TransactionRuleApi.fromJson(Map<String, dynamic> json) => _$TransactionRuleApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String name;
@override@JsonKey(name: 'applies_to') final  String appliesTo;
@override@JsonKey(name: 'matches_on_all') final  bool matchesOnAll;
@override@JsonKey(name: 'auto_convert') final  bool autoConvert;
@override@JsonKey(name: 'vendor_id') final  String vendorId;
@override@JsonKey(name: 'category_id') final  String categoryId;
 final  List<RuleCriterionApi> _rules;
@override@JsonKey() List<RuleCriterionApi> get rules {
  if (_rules is EqualUnmodifiableListView) return _rules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rules);
}

 final  Map<String, dynamic>? _vendor;
@override Map<String, dynamic>? get vendor {
  final value = _vendor;
  if (value == null) return null;
  if (_vendor is EqualUnmodifiableMapView) return _vendor;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _expenseCategory;
@override@JsonKey(name: 'expense_category') Map<String, dynamic>? get expenseCategory {
  final value = _expenseCategory;
  if (value == null) return null;
  if (_expenseCategory is EqualUnmodifiableMapView) return _expenseCategory;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;

/// Create a copy of TransactionRuleApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransactionRuleApiCopyWith<_TransactionRuleApi> get copyWith => __$TransactionRuleApiCopyWithImpl<_TransactionRuleApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransactionRuleApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransactionRuleApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.appliesTo, appliesTo) || other.appliesTo == appliesTo)&&(identical(other.matchesOnAll, matchesOnAll) || other.matchesOnAll == matchesOnAll)&&(identical(other.autoConvert, autoConvert) || other.autoConvert == autoConvert)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&const DeepCollectionEquality().equals(other._rules, _rules)&&const DeepCollectionEquality().equals(other._vendor, _vendor)&&const DeepCollectionEquality().equals(other._expenseCategory, _expenseCategory)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,appliesTo,matchesOnAll,autoConvert,vendorId,categoryId,const DeepCollectionEquality().hash(_rules),const DeepCollectionEquality().hash(_vendor),const DeepCollectionEquality().hash(_expenseCategory),isDeleted,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'TransactionRuleApi(id: $id, name: $name, appliesTo: $appliesTo, matchesOnAll: $matchesOnAll, autoConvert: $autoConvert, vendorId: $vendorId, categoryId: $categoryId, rules: $rules, vendor: $vendor, expenseCategory: $expenseCategory, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$TransactionRuleApiCopyWith<$Res> implements $TransactionRuleApiCopyWith<$Res> {
  factory _$TransactionRuleApiCopyWith(_TransactionRuleApi value, $Res Function(_TransactionRuleApi) _then) = __$TransactionRuleApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String name,@JsonKey(name: 'applies_to') String appliesTo,@JsonKey(name: 'matches_on_all') bool matchesOnAll,@JsonKey(name: 'auto_convert') bool autoConvert,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'category_id') String categoryId, List<RuleCriterionApi> rules, Map<String, dynamic>? vendor,@JsonKey(name: 'expense_category') Map<String, dynamic>? expenseCategory,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class __$TransactionRuleApiCopyWithImpl<$Res>
    implements _$TransactionRuleApiCopyWith<$Res> {
  __$TransactionRuleApiCopyWithImpl(this._self, this._then);

  final _TransactionRuleApi _self;
  final $Res Function(_TransactionRuleApi) _then;

/// Create a copy of TransactionRuleApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? appliesTo = null,Object? matchesOnAll = null,Object? autoConvert = null,Object? vendorId = null,Object? categoryId = null,Object? rules = null,Object? vendor = freezed,Object? expenseCategory = freezed,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_TransactionRuleApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,appliesTo: null == appliesTo ? _self.appliesTo : appliesTo // ignore: cast_nullable_to_non_nullable
as String,matchesOnAll: null == matchesOnAll ? _self.matchesOnAll : matchesOnAll // ignore: cast_nullable_to_non_nullable
as bool,autoConvert: null == autoConvert ? _self.autoConvert : autoConvert // ignore: cast_nullable_to_non_nullable
as bool,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,rules: null == rules ? _self._rules : rules // ignore: cast_nullable_to_non_nullable
as List<RuleCriterionApi>,vendor: freezed == vendor ? _self._vendor : vendor // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,expenseCategory: freezed == expenseCategory ? _self._expenseCategory : expenseCategory // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TransactionRuleListApi {

@JsonKey(fromJson: _transactionRuleListData) List<TransactionRuleApi> get data;
/// Create a copy of TransactionRuleListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransactionRuleListApiCopyWith<TransactionRuleListApi> get copyWith => _$TransactionRuleListApiCopyWithImpl<TransactionRuleListApi>(this as TransactionRuleListApi, _$identity);

  /// Serializes this TransactionRuleListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransactionRuleListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'TransactionRuleListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $TransactionRuleListApiCopyWith<$Res>  {
  factory $TransactionRuleListApiCopyWith(TransactionRuleListApi value, $Res Function(TransactionRuleListApi) _then) = _$TransactionRuleListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _transactionRuleListData) List<TransactionRuleApi> data
});




}
/// @nodoc
class _$TransactionRuleListApiCopyWithImpl<$Res>
    implements $TransactionRuleListApiCopyWith<$Res> {
  _$TransactionRuleListApiCopyWithImpl(this._self, this._then);

  final TransactionRuleListApi _self;
  final $Res Function(TransactionRuleListApi) _then;

/// Create a copy of TransactionRuleListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<TransactionRuleApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [TransactionRuleListApi].
extension TransactionRuleListApiPatterns on TransactionRuleListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransactionRuleListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransactionRuleListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransactionRuleListApi value)  $default,){
final _that = this;
switch (_that) {
case _TransactionRuleListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransactionRuleListApi value)?  $default,){
final _that = this;
switch (_that) {
case _TransactionRuleListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _transactionRuleListData)  List<TransactionRuleApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransactionRuleListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _transactionRuleListData)  List<TransactionRuleApi> data)  $default,) {final _that = this;
switch (_that) {
case _TransactionRuleListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _transactionRuleListData)  List<TransactionRuleApi> data)?  $default,) {final _that = this;
switch (_that) {
case _TransactionRuleListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TransactionRuleListApi implements TransactionRuleListApi {
  const _TransactionRuleListApi({@JsonKey(fromJson: _transactionRuleListData) final  List<TransactionRuleApi> data = const []}): _data = data;
  factory _TransactionRuleListApi.fromJson(Map<String, dynamic> json) => _$TransactionRuleListApiFromJson(json);

 final  List<TransactionRuleApi> _data;
@override@JsonKey(fromJson: _transactionRuleListData) List<TransactionRuleApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of TransactionRuleListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransactionRuleListApiCopyWith<_TransactionRuleListApi> get copyWith => __$TransactionRuleListApiCopyWithImpl<_TransactionRuleListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransactionRuleListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransactionRuleListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'TransactionRuleListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$TransactionRuleListApiCopyWith<$Res> implements $TransactionRuleListApiCopyWith<$Res> {
  factory _$TransactionRuleListApiCopyWith(_TransactionRuleListApi value, $Res Function(_TransactionRuleListApi) _then) = __$TransactionRuleListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _transactionRuleListData) List<TransactionRuleApi> data
});




}
/// @nodoc
class __$TransactionRuleListApiCopyWithImpl<$Res>
    implements _$TransactionRuleListApiCopyWith<$Res> {
  __$TransactionRuleListApiCopyWithImpl(this._self, this._then);

  final _TransactionRuleListApi _self;
  final $Res Function(_TransactionRuleListApi) _then;

/// Create a copy of TransactionRuleListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_TransactionRuleListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<TransactionRuleApi>,
  ));
}


}


/// @nodoc
mixin _$TransactionRuleItemApi {

 TransactionRuleApi get data;
/// Create a copy of TransactionRuleItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransactionRuleItemApiCopyWith<TransactionRuleItemApi> get copyWith => _$TransactionRuleItemApiCopyWithImpl<TransactionRuleItemApi>(this as TransactionRuleItemApi, _$identity);

  /// Serializes this TransactionRuleItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransactionRuleItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'TransactionRuleItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $TransactionRuleItemApiCopyWith<$Res>  {
  factory $TransactionRuleItemApiCopyWith(TransactionRuleItemApi value, $Res Function(TransactionRuleItemApi) _then) = _$TransactionRuleItemApiCopyWithImpl;
@useResult
$Res call({
 TransactionRuleApi data
});


$TransactionRuleApiCopyWith<$Res> get data;

}
/// @nodoc
class _$TransactionRuleItemApiCopyWithImpl<$Res>
    implements $TransactionRuleItemApiCopyWith<$Res> {
  _$TransactionRuleItemApiCopyWithImpl(this._self, this._then);

  final TransactionRuleItemApi _self;
  final $Res Function(TransactionRuleItemApi) _then;

/// Create a copy of TransactionRuleItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TransactionRuleApi,
  ));
}
/// Create a copy of TransactionRuleItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TransactionRuleApiCopyWith<$Res> get data {
  
  return $TransactionRuleApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [TransactionRuleItemApi].
extension TransactionRuleItemApiPatterns on TransactionRuleItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransactionRuleItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransactionRuleItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransactionRuleItemApi value)  $default,){
final _that = this;
switch (_that) {
case _TransactionRuleItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransactionRuleItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _TransactionRuleItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TransactionRuleApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransactionRuleItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TransactionRuleApi data)  $default,) {final _that = this;
switch (_that) {
case _TransactionRuleItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TransactionRuleApi data)?  $default,) {final _that = this;
switch (_that) {
case _TransactionRuleItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TransactionRuleItemApi implements TransactionRuleItemApi {
  const _TransactionRuleItemApi({required this.data});
  factory _TransactionRuleItemApi.fromJson(Map<String, dynamic> json) => _$TransactionRuleItemApiFromJson(json);

@override final  TransactionRuleApi data;

/// Create a copy of TransactionRuleItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransactionRuleItemApiCopyWith<_TransactionRuleItemApi> get copyWith => __$TransactionRuleItemApiCopyWithImpl<_TransactionRuleItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TransactionRuleItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransactionRuleItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'TransactionRuleItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$TransactionRuleItemApiCopyWith<$Res> implements $TransactionRuleItemApiCopyWith<$Res> {
  factory _$TransactionRuleItemApiCopyWith(_TransactionRuleItemApi value, $Res Function(_TransactionRuleItemApi) _then) = __$TransactionRuleItemApiCopyWithImpl;
@override @useResult
$Res call({
 TransactionRuleApi data
});


@override $TransactionRuleApiCopyWith<$Res> get data;

}
/// @nodoc
class __$TransactionRuleItemApiCopyWithImpl<$Res>
    implements _$TransactionRuleItemApiCopyWith<$Res> {
  __$TransactionRuleItemApiCopyWithImpl(this._self, this._then);

  final _TransactionRuleItemApi _self;
  final $Res Function(_TransactionRuleItemApi) _then;

/// Create a copy of TransactionRuleItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_TransactionRuleItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TransactionRuleApi,
  ));
}

/// Create a copy of TransactionRuleItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TransactionRuleApiCopyWith<$Res> get data {
  
  return $TransactionRuleApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
