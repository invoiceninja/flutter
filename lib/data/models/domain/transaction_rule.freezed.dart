// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transaction_rule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RuleCriterion {

 String get searchKey; String get operator; String get value;
/// Create a copy of RuleCriterion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RuleCriterionCopyWith<RuleCriterion> get copyWith => _$RuleCriterionCopyWithImpl<RuleCriterion>(this as RuleCriterion, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RuleCriterion;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RuleCriterion&&(identical(other.searchKey, _this.searchKey) || other.searchKey == _this.searchKey)&&(identical(other.operator, _this.operator) || other.operator == _this.operator)&&(identical(other.value, _this.value) || other.value == _this.value));
}


@override
int get hashCode {
  final _this = this as RuleCriterion;
  return Object.hash(runtimeType,_this.searchKey,_this.operator,_this.value);
}

@override
String toString() {
  final _this = this as RuleCriterion;
  return 'RuleCriterion(searchKey: ${_this.searchKey}, operator: ${_this.operator}, value: ${_this.value})';
}


}

/// @nodoc
abstract mixin class $RuleCriterionCopyWith<$Res>  {
  factory $RuleCriterionCopyWith(RuleCriterion value, $Res Function(RuleCriterion) _then) = _$RuleCriterionCopyWithImpl;
@useResult
$Res call({
 String searchKey, String operator, String value
});




}
/// @nodoc
class _$RuleCriterionCopyWithImpl<$Res>
    implements $RuleCriterionCopyWith<$Res> {
  _$RuleCriterionCopyWithImpl(this._self, this._then);

  final RuleCriterion _self;
  final $Res Function(RuleCriterion) _then;

/// Create a copy of RuleCriterion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? searchKey = null,Object? operator = null,Object? value = null,}) {
  return _then(RuleCriterion(
searchKey: null == searchKey ? _self.searchKey : searchKey // ignore: cast_nullable_to_non_nullable
as String,operator: null == operator ? _self.operator : operator // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RuleCriterion].
extension RuleCriterionPatterns on RuleCriterion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RuleCriterion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RuleCriterion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RuleCriterion value)  $default,){
final _that = this;
switch (_that) {
case _RuleCriterion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RuleCriterion value)?  $default,){
final _that = this;
switch (_that) {
case _RuleCriterion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String searchKey,  String operator,  String value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RuleCriterion() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String searchKey,  String operator,  String value)  $default,) {final _that = this;
switch (_that) {
case _RuleCriterion():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String searchKey,  String operator,  String value)?  $default,) {final _that = this;
switch (_that) {
case _RuleCriterion() when $default != null:
return $default(_that.searchKey,_that.operator,_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _RuleCriterion extends RuleCriterion {
  const _RuleCriterion({this.searchKey = '', this.operator = '', this.value = ''}): super._();
  

@override@JsonKey() final  String searchKey;
@override@JsonKey() final  String operator;
@override@JsonKey() final  String value;

/// Create a copy of RuleCriterion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RuleCriterionCopyWith<_RuleCriterion> get copyWith => __$RuleCriterionCopyWithImpl<_RuleCriterion>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RuleCriterion&&(identical(other.searchKey, searchKey) || other.searchKey == searchKey)&&(identical(other.operator, operator) || other.operator == operator)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode {
    return Object.hash(runtimeType,searchKey,operator,value);
}

@override
String toString() {
    return 'RuleCriterion(searchKey: $searchKey, operator: $operator, value: $value)';
}


}

/// @nodoc
abstract mixin class _$RuleCriterionCopyWith<$Res> implements $RuleCriterionCopyWith<$Res> {
  factory _$RuleCriterionCopyWith(_RuleCriterion value, $Res Function(_RuleCriterion) _then) = __$RuleCriterionCopyWithImpl;
@override @useResult
$Res call({
 String searchKey, String operator, String value
});




}
/// @nodoc
class __$RuleCriterionCopyWithImpl<$Res>
    implements _$RuleCriterionCopyWith<$Res> {
  __$RuleCriterionCopyWithImpl(this._self, this._then);

  final _RuleCriterion _self;
  final $Res Function(_RuleCriterion) _then;

/// Create a copy of RuleCriterion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? searchKey = null,Object? operator = null,Object? value = null,}) {
  return _then(_RuleCriterion(
searchKey: null == searchKey ? _self.searchKey : searchKey // ignore: cast_nullable_to_non_nullable
as String,operator: null == operator ? _self.operator : operator // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$TransactionRule {

 String get id; String get name; String get appliesTo; bool get matchesOnAll; bool get autoConvert; String get vendorId; String get categoryId; List<RuleCriterion> get rules; String get vendorName; String get categoryName; bool get isDeleted; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; bool get isDirty;
/// Create a copy of TransactionRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransactionRuleCopyWith<TransactionRule> get copyWith => _$TransactionRuleCopyWithImpl<TransactionRule>(this as TransactionRule, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as TransactionRule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransactionRule&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.appliesTo, _this.appliesTo) || other.appliesTo == _this.appliesTo)&&(identical(other.matchesOnAll, _this.matchesOnAll) || other.matchesOnAll == _this.matchesOnAll)&&(identical(other.autoConvert, _this.autoConvert) || other.autoConvert == _this.autoConvert)&&(identical(other.vendorId, _this.vendorId) || other.vendorId == _this.vendorId)&&(identical(other.categoryId, _this.categoryId) || other.categoryId == _this.categoryId)&&const DeepCollectionEquality().equals(other.rules, _this.rules)&&(identical(other.vendorName, _this.vendorName) || other.vendorName == _this.vendorName)&&(identical(other.categoryName, _this.categoryName) || other.categoryName == _this.categoryName)&&(identical(other.isDeleted, _this.isDeleted) || other.isDeleted == _this.isDeleted)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.archivedAt, _this.archivedAt) || other.archivedAt == _this.archivedAt)&&(identical(other.isDirty, _this.isDirty) || other.isDirty == _this.isDirty));
}


@override
int get hashCode {
  final _this = this as TransactionRule;
  return Object.hash(runtimeType,_this.id,_this.name,_this.appliesTo,_this.matchesOnAll,_this.autoConvert,_this.vendorId,_this.categoryId,const DeepCollectionEquality().hash(_this.rules),_this.vendorName,_this.categoryName,_this.isDeleted,_this.updatedAt,_this.createdAt,_this.archivedAt,_this.isDirty);
}

@override
String toString() {
  final _this = this as TransactionRule;
  return 'TransactionRule(id: ${_this.id}, name: ${_this.name}, appliesTo: ${_this.appliesTo}, matchesOnAll: ${_this.matchesOnAll}, autoConvert: ${_this.autoConvert}, vendorId: ${_this.vendorId}, categoryId: ${_this.categoryId}, rules: ${_this.rules}, vendorName: ${_this.vendorName}, categoryName: ${_this.categoryName}, isDeleted: ${_this.isDeleted}, updatedAt: ${_this.updatedAt}, createdAt: ${_this.createdAt}, archivedAt: ${_this.archivedAt}, isDirty: ${_this.isDirty})';
}


}

/// @nodoc
abstract mixin class $TransactionRuleCopyWith<$Res>  {
  factory $TransactionRuleCopyWith(TransactionRule value, $Res Function(TransactionRule) _then) = _$TransactionRuleCopyWithImpl;
@useResult
$Res call({
 String id, String name, String appliesTo, bool matchesOnAll, bool autoConvert, String vendorId, String categoryId, List<RuleCriterion> rules, String vendorName, String categoryName, bool isDeleted, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDirty
});




}
/// @nodoc
class _$TransactionRuleCopyWithImpl<$Res>
    implements $TransactionRuleCopyWith<$Res> {
  _$TransactionRuleCopyWithImpl(this._self, this._then);

  final TransactionRule _self;
  final $Res Function(TransactionRule) _then;

/// Create a copy of TransactionRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? appliesTo = null,Object? matchesOnAll = null,Object? autoConvert = null,Object? vendorId = null,Object? categoryId = null,Object? rules = null,Object? vendorName = null,Object? categoryName = null,Object? isDeleted = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDirty = null,}) {
  return _then(TransactionRule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,appliesTo: null == appliesTo ? _self.appliesTo : appliesTo // ignore: cast_nullable_to_non_nullable
as String,matchesOnAll: null == matchesOnAll ? _self.matchesOnAll : matchesOnAll // ignore: cast_nullable_to_non_nullable
as bool,autoConvert: null == autoConvert ? _self.autoConvert : autoConvert // ignore: cast_nullable_to_non_nullable
as bool,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,rules: null == rules ? _self.rules : rules // ignore: cast_nullable_to_non_nullable
as List<RuleCriterion>,vendorName: null == vendorName ? _self.vendorName : vendorName // ignore: cast_nullable_to_non_nullable
as String,categoryName: null == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TransactionRule].
extension TransactionRulePatterns on TransactionRule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransactionRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransactionRule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransactionRule value)  $default,){
final _that = this;
switch (_that) {
case _TransactionRule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransactionRule value)?  $default,){
final _that = this;
switch (_that) {
case _TransactionRule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String appliesTo,  bool matchesOnAll,  bool autoConvert,  String vendorId,  String categoryId,  List<RuleCriterion> rules,  String vendorName,  String categoryName,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransactionRule() when $default != null:
return $default(_that.id,_that.name,_that.appliesTo,_that.matchesOnAll,_that.autoConvert,_that.vendorId,_that.categoryId,_that.rules,_that.vendorName,_that.categoryName,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String appliesTo,  bool matchesOnAll,  bool autoConvert,  String vendorId,  String categoryId,  List<RuleCriterion> rules,  String vendorName,  String categoryName,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _TransactionRule():
return $default(_that.id,_that.name,_that.appliesTo,_that.matchesOnAll,_that.autoConvert,_that.vendorId,_that.categoryId,_that.rules,_that.vendorName,_that.categoryName,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String appliesTo,  bool matchesOnAll,  bool autoConvert,  String vendorId,  String categoryId,  List<RuleCriterion> rules,  String vendorName,  String categoryName,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _TransactionRule() when $default != null:
return $default(_that.id,_that.name,_that.appliesTo,_that.matchesOnAll,_that.autoConvert,_that.vendorId,_that.categoryId,_that.rules,_that.vendorName,_that.categoryName,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _TransactionRule extends TransactionRule {
  const _TransactionRule({required this.id, required this.name, required this.appliesTo, required this.matchesOnAll, required this.autoConvert, required this.vendorId, required this.categoryId,  List<RuleCriterion> rules = const <RuleCriterion>[], this.vendorName = '', this.categoryName = '', required this.isDeleted, required this.updatedAt, required this.createdAt, required this.archivedAt, this.isDirty = false}): _rules = rules,super._();
  

@override final  String id;
@override final  String name;
@override final  String appliesTo;
@override final  bool matchesOnAll;
@override final  bool autoConvert;
@override final  String vendorId;
@override final  String categoryId;
 final  List<RuleCriterion> _rules;
@override@JsonKey() List<RuleCriterion> get rules {
  if (_rules is EqualUnmodifiableListView) return _rules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rules);
}

@override@JsonKey() final  String vendorName;
@override@JsonKey() final  String categoryName;
@override final  bool isDeleted;
@override final  DateTime updatedAt;
@override final  DateTime createdAt;
@override final  DateTime? archivedAt;
@override@JsonKey() final  bool isDirty;

/// Create a copy of TransactionRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransactionRuleCopyWith<_TransactionRule> get copyWith => __$TransactionRuleCopyWithImpl<_TransactionRule>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransactionRule&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.appliesTo, appliesTo) || other.appliesTo == appliesTo)&&(identical(other.matchesOnAll, matchesOnAll) || other.matchesOnAll == matchesOnAll)&&(identical(other.autoConvert, autoConvert) || other.autoConvert == autoConvert)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&const DeepCollectionEquality().equals(other.rules, _rules)&&(identical(other.vendorName, vendorName) || other.vendorName == vendorName)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,appliesTo,matchesOnAll,autoConvert,vendorId,categoryId,const DeepCollectionEquality().hash(_rules),vendorName,categoryName,isDeleted,updatedAt,createdAt,archivedAt,isDirty);
}

@override
String toString() {
    return 'TransactionRule(id: $id, name: $name, appliesTo: $appliesTo, matchesOnAll: $matchesOnAll, autoConvert: $autoConvert, vendorId: $vendorId, categoryId: $categoryId, rules: $rules, vendorName: $vendorName, categoryName: $categoryName, isDeleted: $isDeleted, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$TransactionRuleCopyWith<$Res> implements $TransactionRuleCopyWith<$Res> {
  factory _$TransactionRuleCopyWith(_TransactionRule value, $Res Function(_TransactionRule) _then) = __$TransactionRuleCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String appliesTo, bool matchesOnAll, bool autoConvert, String vendorId, String categoryId, List<RuleCriterion> rules, String vendorName, String categoryName, bool isDeleted, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDirty
});




}
/// @nodoc
class __$TransactionRuleCopyWithImpl<$Res>
    implements _$TransactionRuleCopyWith<$Res> {
  __$TransactionRuleCopyWithImpl(this._self, this._then);

  final _TransactionRule _self;
  final $Res Function(_TransactionRule) _then;

/// Create a copy of TransactionRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? appliesTo = null,Object? matchesOnAll = null,Object? autoConvert = null,Object? vendorId = null,Object? categoryId = null,Object? rules = null,Object? vendorName = null,Object? categoryName = null,Object? isDeleted = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDirty = null,}) {
  return _then(_TransactionRule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,appliesTo: null == appliesTo ? _self.appliesTo : appliesTo // ignore: cast_nullable_to_non_nullable
as String,matchesOnAll: null == matchesOnAll ? _self.matchesOnAll : matchesOnAll // ignore: cast_nullable_to_non_nullable
as bool,autoConvert: null == autoConvert ? _self.autoConvert : autoConvert // ignore: cast_nullable_to_non_nullable
as bool,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,rules: null == rules ? _self._rules : rules // ignore: cast_nullable_to_non_nullable
as List<RuleCriterion>,vendorName: null == vendorName ? _self.vendorName : vendorName // ignore: cast_nullable_to_non_nullable
as String,categoryName: null == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
