// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bank_account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BankAccount {

 String get id; String get name; String get status; String get type; String get provider; Decimal get balance; String get currency; Date? get fromDate; bool get autoSync; bool get disabledUpstream; String get integrationType; String get nordigenInstitutionId; bool get isDeleted; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; bool get isDirty;
/// Create a copy of BankAccount
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BankAccountCopyWith<BankAccount> get copyWith => _$BankAccountCopyWithImpl<BankAccount>(this as BankAccount, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BankAccount;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BankAccount&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.provider, _this.provider) || other.provider == _this.provider)&&(identical(other.balance, _this.balance) || other.balance == _this.balance)&&(identical(other.currency, _this.currency) || other.currency == _this.currency)&&(identical(other.fromDate, _this.fromDate) || other.fromDate == _this.fromDate)&&(identical(other.autoSync, _this.autoSync) || other.autoSync == _this.autoSync)&&(identical(other.disabledUpstream, _this.disabledUpstream) || other.disabledUpstream == _this.disabledUpstream)&&(identical(other.integrationType, _this.integrationType) || other.integrationType == _this.integrationType)&&(identical(other.nordigenInstitutionId, _this.nordigenInstitutionId) || other.nordigenInstitutionId == _this.nordigenInstitutionId)&&(identical(other.isDeleted, _this.isDeleted) || other.isDeleted == _this.isDeleted)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.archivedAt, _this.archivedAt) || other.archivedAt == _this.archivedAt)&&(identical(other.isDirty, _this.isDirty) || other.isDirty == _this.isDirty));
}


@override
int get hashCode {
  final _this = this as BankAccount;
  return Object.hash(runtimeType,_this.id,_this.name,_this.status,_this.type,_this.provider,_this.balance,_this.currency,_this.fromDate,_this.autoSync,_this.disabledUpstream,_this.integrationType,_this.nordigenInstitutionId,_this.isDeleted,_this.updatedAt,_this.createdAt,_this.archivedAt,_this.isDirty);
}

@override
String toString() {
  final _this = this as BankAccount;
  return 'BankAccount(id: ${_this.id}, name: ${_this.name}, status: ${_this.status}, type: ${_this.type}, provider: ${_this.provider}, balance: ${_this.balance}, currency: ${_this.currency}, fromDate: ${_this.fromDate}, autoSync: ${_this.autoSync}, disabledUpstream: ${_this.disabledUpstream}, integrationType: ${_this.integrationType}, nordigenInstitutionId: ${_this.nordigenInstitutionId}, isDeleted: ${_this.isDeleted}, updatedAt: ${_this.updatedAt}, createdAt: ${_this.createdAt}, archivedAt: ${_this.archivedAt}, isDirty: ${_this.isDirty})';
}


}

/// @nodoc
abstract mixin class $BankAccountCopyWith<$Res>  {
  factory $BankAccountCopyWith(BankAccount value, $Res Function(BankAccount) _then) = _$BankAccountCopyWithImpl;
@useResult
$Res call({
 String id, String name, String status, String type, String provider, Decimal balance, String currency, Date? fromDate, bool autoSync, bool disabledUpstream, String integrationType, String nordigenInstitutionId, bool isDeleted, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDirty
});




}
/// @nodoc
class _$BankAccountCopyWithImpl<$Res>
    implements $BankAccountCopyWith<$Res> {
  _$BankAccountCopyWithImpl(this._self, this._then);

  final BankAccount _self;
  final $Res Function(BankAccount) _then;

/// Create a copy of BankAccount
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? status = null,Object? type = null,Object? provider = null,Object? balance = null,Object? currency = null,Object? fromDate = freezed,Object? autoSync = null,Object? disabledUpstream = null,Object? integrationType = null,Object? nordigenInstitutionId = null,Object? isDeleted = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDirty = null,}) {
  return _then(BankAccount(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as Decimal,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,fromDate: freezed == fromDate ? _self.fromDate : fromDate // ignore: cast_nullable_to_non_nullable
as Date?,autoSync: null == autoSync ? _self.autoSync : autoSync // ignore: cast_nullable_to_non_nullable
as bool,disabledUpstream: null == disabledUpstream ? _self.disabledUpstream : disabledUpstream // ignore: cast_nullable_to_non_nullable
as bool,integrationType: null == integrationType ? _self.integrationType : integrationType // ignore: cast_nullable_to_non_nullable
as String,nordigenInstitutionId: null == nordigenInstitutionId ? _self.nordigenInstitutionId : nordigenInstitutionId // ignore: cast_nullable_to_non_nullable
as String,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [BankAccount].
extension BankAccountPatterns on BankAccount {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BankAccount value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BankAccount() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BankAccount value)  $default,){
final _that = this;
switch (_that) {
case _BankAccount():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BankAccount value)?  $default,){
final _that = this;
switch (_that) {
case _BankAccount() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String status,  String type,  String provider,  Decimal balance,  String currency,  Date? fromDate,  bool autoSync,  bool disabledUpstream,  String integrationType,  String nordigenInstitutionId,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BankAccount() when $default != null:
return $default(_that.id,_that.name,_that.status,_that.type,_that.provider,_that.balance,_that.currency,_that.fromDate,_that.autoSync,_that.disabledUpstream,_that.integrationType,_that.nordigenInstitutionId,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String status,  String type,  String provider,  Decimal balance,  String currency,  Date? fromDate,  bool autoSync,  bool disabledUpstream,  String integrationType,  String nordigenInstitutionId,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _BankAccount():
return $default(_that.id,_that.name,_that.status,_that.type,_that.provider,_that.balance,_that.currency,_that.fromDate,_that.autoSync,_that.disabledUpstream,_that.integrationType,_that.nordigenInstitutionId,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String status,  String type,  String provider,  Decimal balance,  String currency,  Date? fromDate,  bool autoSync,  bool disabledUpstream,  String integrationType,  String nordigenInstitutionId,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _BankAccount() when $default != null:
return $default(_that.id,_that.name,_that.status,_that.type,_that.provider,_that.balance,_that.currency,_that.fromDate,_that.autoSync,_that.disabledUpstream,_that.integrationType,_that.nordigenInstitutionId,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _BankAccount extends BankAccount {
  const _BankAccount({required this.id, required this.name, required this.status, required this.type, required this.provider, required this.balance, required this.currency, required this.fromDate, required this.autoSync, required this.disabledUpstream, required this.integrationType, required this.nordigenInstitutionId, required this.isDeleted, required this.updatedAt, required this.createdAt, required this.archivedAt, this.isDirty = false}): super._();
  

@override final  String id;
@override final  String name;
@override final  String status;
@override final  String type;
@override final  String provider;
@override final  Decimal balance;
@override final  String currency;
@override final  Date? fromDate;
@override final  bool autoSync;
@override final  bool disabledUpstream;
@override final  String integrationType;
@override final  String nordigenInstitutionId;
@override final  bool isDeleted;
@override final  DateTime updatedAt;
@override final  DateTime createdAt;
@override final  DateTime? archivedAt;
@override@JsonKey() final  bool isDirty;

/// Create a copy of BankAccount
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BankAccountCopyWith<_BankAccount> get copyWith => __$BankAccountCopyWithImpl<_BankAccount>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BankAccount&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.status, status) || other.status == status)&&(identical(other.type, type) || other.type == type)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.fromDate, fromDate) || other.fromDate == fromDate)&&(identical(other.autoSync, autoSync) || other.autoSync == autoSync)&&(identical(other.disabledUpstream, disabledUpstream) || other.disabledUpstream == disabledUpstream)&&(identical(other.integrationType, integrationType) || other.integrationType == integrationType)&&(identical(other.nordigenInstitutionId, nordigenInstitutionId) || other.nordigenInstitutionId == nordigenInstitutionId)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,status,type,provider,balance,currency,fromDate,autoSync,disabledUpstream,integrationType,nordigenInstitutionId,isDeleted,updatedAt,createdAt,archivedAt,isDirty);
}

@override
String toString() {
    return 'BankAccount(id: $id, name: $name, status: $status, type: $type, provider: $provider, balance: $balance, currency: $currency, fromDate: $fromDate, autoSync: $autoSync, disabledUpstream: $disabledUpstream, integrationType: $integrationType, nordigenInstitutionId: $nordigenInstitutionId, isDeleted: $isDeleted, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$BankAccountCopyWith<$Res> implements $BankAccountCopyWith<$Res> {
  factory _$BankAccountCopyWith(_BankAccount value, $Res Function(_BankAccount) _then) = __$BankAccountCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String status, String type, String provider, Decimal balance, String currency, Date? fromDate, bool autoSync, bool disabledUpstream, String integrationType, String nordigenInstitutionId, bool isDeleted, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDirty
});




}
/// @nodoc
class __$BankAccountCopyWithImpl<$Res>
    implements _$BankAccountCopyWith<$Res> {
  __$BankAccountCopyWithImpl(this._self, this._then);

  final _BankAccount _self;
  final $Res Function(_BankAccount) _then;

/// Create a copy of BankAccount
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? status = null,Object? type = null,Object? provider = null,Object? balance = null,Object? currency = null,Object? fromDate = freezed,Object? autoSync = null,Object? disabledUpstream = null,Object? integrationType = null,Object? nordigenInstitutionId = null,Object? isDeleted = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDirty = null,}) {
  return _then(_BankAccount(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as Decimal,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,fromDate: freezed == fromDate ? _self.fromDate : fromDate // ignore: cast_nullable_to_non_nullable
as Date?,autoSync: null == autoSync ? _self.autoSync : autoSync // ignore: cast_nullable_to_non_nullable
as bool,disabledUpstream: null == disabledUpstream ? _self.disabledUpstream : disabledUpstream // ignore: cast_nullable_to_non_nullable
as bool,integrationType: null == integrationType ? _self.integrationType : integrationType // ignore: cast_nullable_to_non_nullable
as String,nordigenInstitutionId: null == nordigenInstitutionId ? _self.nordigenInstitutionId : nordigenInstitutionId // ignore: cast_nullable_to_non_nullable
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
