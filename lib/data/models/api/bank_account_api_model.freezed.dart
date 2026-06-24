// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bank_account_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BankAccountApi {

 String get id;@JsonKey(name: 'bank_account_name') String get bankAccountName;@JsonKey(name: 'bank_account_status') String get bankAccountStatus;@JsonKey(name: 'bank_account_type') String get bankAccountType;@JsonKey(name: 'provider_name') String get providerName; Object get balance; String get currency;@JsonKey(name: 'from_date') String get fromDate;@JsonKey(name: 'auto_sync') bool get autoSync;@JsonKey(name: 'disabled_upstream') bool get disabledUpstream;@JsonKey(name: 'integration_type') String get integrationType;@JsonKey(name: 'nordigen_institution_id') String get nordigenInstitutionId;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;
/// Create a copy of BankAccountApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BankAccountApiCopyWith<BankAccountApi> get copyWith => _$BankAccountApiCopyWithImpl<BankAccountApi>(this as BankAccountApi, _$identity);

  /// Serializes this BankAccountApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BankAccountApi&&(identical(other.id, id) || other.id == id)&&(identical(other.bankAccountName, bankAccountName) || other.bankAccountName == bankAccountName)&&(identical(other.bankAccountStatus, bankAccountStatus) || other.bankAccountStatus == bankAccountStatus)&&(identical(other.bankAccountType, bankAccountType) || other.bankAccountType == bankAccountType)&&(identical(other.providerName, providerName) || other.providerName == providerName)&&const DeepCollectionEquality().equals(other.balance, balance)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.fromDate, fromDate) || other.fromDate == fromDate)&&(identical(other.autoSync, autoSync) || other.autoSync == autoSync)&&(identical(other.disabledUpstream, disabledUpstream) || other.disabledUpstream == disabledUpstream)&&(identical(other.integrationType, integrationType) || other.integrationType == integrationType)&&(identical(other.nordigenInstitutionId, nordigenInstitutionId) || other.nordigenInstitutionId == nordigenInstitutionId)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bankAccountName,bankAccountStatus,bankAccountType,providerName,const DeepCollectionEquality().hash(balance),currency,fromDate,autoSync,disabledUpstream,integrationType,nordigenInstitutionId,isDeleted,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'BankAccountApi(id: $id, bankAccountName: $bankAccountName, bankAccountStatus: $bankAccountStatus, bankAccountType: $bankAccountType, providerName: $providerName, balance: $balance, currency: $currency, fromDate: $fromDate, autoSync: $autoSync, disabledUpstream: $disabledUpstream, integrationType: $integrationType, nordigenInstitutionId: $nordigenInstitutionId, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class $BankAccountApiCopyWith<$Res>  {
  factory $BankAccountApiCopyWith(BankAccountApi value, $Res Function(BankAccountApi) _then) = _$BankAccountApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'bank_account_name') String bankAccountName,@JsonKey(name: 'bank_account_status') String bankAccountStatus,@JsonKey(name: 'bank_account_type') String bankAccountType,@JsonKey(name: 'provider_name') String providerName, Object balance, String currency,@JsonKey(name: 'from_date') String fromDate,@JsonKey(name: 'auto_sync') bool autoSync,@JsonKey(name: 'disabled_upstream') bool disabledUpstream,@JsonKey(name: 'integration_type') String integrationType,@JsonKey(name: 'nordigen_institution_id') String nordigenInstitutionId,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class _$BankAccountApiCopyWithImpl<$Res>
    implements $BankAccountApiCopyWith<$Res> {
  _$BankAccountApiCopyWithImpl(this._self, this._then);

  final BankAccountApi _self;
  final $Res Function(BankAccountApi) _then;

/// Create a copy of BankAccountApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bankAccountName = null,Object? bankAccountStatus = null,Object? bankAccountType = null,Object? providerName = null,Object? balance = null,Object? currency = null,Object? fromDate = null,Object? autoSync = null,Object? disabledUpstream = null,Object? integrationType = null,Object? nordigenInstitutionId = null,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bankAccountName: null == bankAccountName ? _self.bankAccountName : bankAccountName // ignore: cast_nullable_to_non_nullable
as String,bankAccountStatus: null == bankAccountStatus ? _self.bankAccountStatus : bankAccountStatus // ignore: cast_nullable_to_non_nullable
as String,bankAccountType: null == bankAccountType ? _self.bankAccountType : bankAccountType // ignore: cast_nullable_to_non_nullable
as String,providerName: null == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String,balance: null == balance ? _self.balance : balance ,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,fromDate: null == fromDate ? _self.fromDate : fromDate // ignore: cast_nullable_to_non_nullable
as String,autoSync: null == autoSync ? _self.autoSync : autoSync // ignore: cast_nullable_to_non_nullable
as bool,disabledUpstream: null == disabledUpstream ? _self.disabledUpstream : disabledUpstream // ignore: cast_nullable_to_non_nullable
as bool,integrationType: null == integrationType ? _self.integrationType : integrationType // ignore: cast_nullable_to_non_nullable
as String,nordigenInstitutionId: null == nordigenInstitutionId ? _self.nordigenInstitutionId : nordigenInstitutionId // ignore: cast_nullable_to_non_nullable
as String,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BankAccountApi].
extension BankAccountApiPatterns on BankAccountApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BankAccountApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BankAccountApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BankAccountApi value)  $default,){
final _that = this;
switch (_that) {
case _BankAccountApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BankAccountApi value)?  $default,){
final _that = this;
switch (_that) {
case _BankAccountApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'bank_account_name')  String bankAccountName, @JsonKey(name: 'bank_account_status')  String bankAccountStatus, @JsonKey(name: 'bank_account_type')  String bankAccountType, @JsonKey(name: 'provider_name')  String providerName,  Object balance,  String currency, @JsonKey(name: 'from_date')  String fromDate, @JsonKey(name: 'auto_sync')  bool autoSync, @JsonKey(name: 'disabled_upstream')  bool disabledUpstream, @JsonKey(name: 'integration_type')  String integrationType, @JsonKey(name: 'nordigen_institution_id')  String nordigenInstitutionId, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BankAccountApi() when $default != null:
return $default(_that.id,_that.bankAccountName,_that.bankAccountStatus,_that.bankAccountType,_that.providerName,_that.balance,_that.currency,_that.fromDate,_that.autoSync,_that.disabledUpstream,_that.integrationType,_that.nordigenInstitutionId,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'bank_account_name')  String bankAccountName, @JsonKey(name: 'bank_account_status')  String bankAccountStatus, @JsonKey(name: 'bank_account_type')  String bankAccountType, @JsonKey(name: 'provider_name')  String providerName,  Object balance,  String currency, @JsonKey(name: 'from_date')  String fromDate, @JsonKey(name: 'auto_sync')  bool autoSync, @JsonKey(name: 'disabled_upstream')  bool disabledUpstream, @JsonKey(name: 'integration_type')  String integrationType, @JsonKey(name: 'nordigen_institution_id')  String nordigenInstitutionId, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)  $default,) {final _that = this;
switch (_that) {
case _BankAccountApi():
return $default(_that.id,_that.bankAccountName,_that.bankAccountStatus,_that.bankAccountType,_that.providerName,_that.balance,_that.currency,_that.fromDate,_that.autoSync,_that.disabledUpstream,_that.integrationType,_that.nordigenInstitutionId,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'bank_account_name')  String bankAccountName, @JsonKey(name: 'bank_account_status')  String bankAccountStatus, @JsonKey(name: 'bank_account_type')  String bankAccountType, @JsonKey(name: 'provider_name')  String providerName,  Object balance,  String currency, @JsonKey(name: 'from_date')  String fromDate, @JsonKey(name: 'auto_sync')  bool autoSync, @JsonKey(name: 'disabled_upstream')  bool disabledUpstream, @JsonKey(name: 'integration_type')  String integrationType, @JsonKey(name: 'nordigen_institution_id')  String nordigenInstitutionId, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _BankAccountApi() when $default != null:
return $default(_that.id,_that.bankAccountName,_that.bankAccountStatus,_that.bankAccountType,_that.providerName,_that.balance,_that.currency,_that.fromDate,_that.autoSync,_that.disabledUpstream,_that.integrationType,_that.nordigenInstitutionId,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _BankAccountApi implements BankAccountApi {
  const _BankAccountApi({this.id = '', @JsonKey(name: 'bank_account_name') this.bankAccountName = '', @JsonKey(name: 'bank_account_status') this.bankAccountStatus = '', @JsonKey(name: 'bank_account_type') this.bankAccountType = '', @JsonKey(name: 'provider_name') this.providerName = '', this.balance = '0', this.currency = '', @JsonKey(name: 'from_date') this.fromDate = '', @JsonKey(name: 'auto_sync') this.autoSync = false, @JsonKey(name: 'disabled_upstream') this.disabledUpstream = false, @JsonKey(name: 'integration_type') this.integrationType = '', @JsonKey(name: 'nordigen_institution_id') this.nordigenInstitutionId = '', @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0});
  factory _BankAccountApi.fromJson(Map<String, dynamic> json) => _$BankAccountApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'bank_account_name') final  String bankAccountName;
@override@JsonKey(name: 'bank_account_status') final  String bankAccountStatus;
@override@JsonKey(name: 'bank_account_type') final  String bankAccountType;
@override@JsonKey(name: 'provider_name') final  String providerName;
@override@JsonKey() final  Object balance;
@override@JsonKey() final  String currency;
@override@JsonKey(name: 'from_date') final  String fromDate;
@override@JsonKey(name: 'auto_sync') final  bool autoSync;
@override@JsonKey(name: 'disabled_upstream') final  bool disabledUpstream;
@override@JsonKey(name: 'integration_type') final  String integrationType;
@override@JsonKey(name: 'nordigen_institution_id') final  String nordigenInstitutionId;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;

/// Create a copy of BankAccountApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BankAccountApiCopyWith<_BankAccountApi> get copyWith => __$BankAccountApiCopyWithImpl<_BankAccountApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BankAccountApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BankAccountApi&&(identical(other.id, id) || other.id == id)&&(identical(other.bankAccountName, bankAccountName) || other.bankAccountName == bankAccountName)&&(identical(other.bankAccountStatus, bankAccountStatus) || other.bankAccountStatus == bankAccountStatus)&&(identical(other.bankAccountType, bankAccountType) || other.bankAccountType == bankAccountType)&&(identical(other.providerName, providerName) || other.providerName == providerName)&&const DeepCollectionEquality().equals(other.balance, balance)&&(identical(other.currency, currency) || other.currency == currency)&&(identical(other.fromDate, fromDate) || other.fromDate == fromDate)&&(identical(other.autoSync, autoSync) || other.autoSync == autoSync)&&(identical(other.disabledUpstream, disabledUpstream) || other.disabledUpstream == disabledUpstream)&&(identical(other.integrationType, integrationType) || other.integrationType == integrationType)&&(identical(other.nordigenInstitutionId, nordigenInstitutionId) || other.nordigenInstitutionId == nordigenInstitutionId)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bankAccountName,bankAccountStatus,bankAccountType,providerName,const DeepCollectionEquality().hash(balance),currency,fromDate,autoSync,disabledUpstream,integrationType,nordigenInstitutionId,isDeleted,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'BankAccountApi(id: $id, bankAccountName: $bankAccountName, bankAccountStatus: $bankAccountStatus, bankAccountType: $bankAccountType, providerName: $providerName, balance: $balance, currency: $currency, fromDate: $fromDate, autoSync: $autoSync, disabledUpstream: $disabledUpstream, integrationType: $integrationType, nordigenInstitutionId: $nordigenInstitutionId, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$BankAccountApiCopyWith<$Res> implements $BankAccountApiCopyWith<$Res> {
  factory _$BankAccountApiCopyWith(_BankAccountApi value, $Res Function(_BankAccountApi) _then) = __$BankAccountApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'bank_account_name') String bankAccountName,@JsonKey(name: 'bank_account_status') String bankAccountStatus,@JsonKey(name: 'bank_account_type') String bankAccountType,@JsonKey(name: 'provider_name') String providerName, Object balance, String currency,@JsonKey(name: 'from_date') String fromDate,@JsonKey(name: 'auto_sync') bool autoSync,@JsonKey(name: 'disabled_upstream') bool disabledUpstream,@JsonKey(name: 'integration_type') String integrationType,@JsonKey(name: 'nordigen_institution_id') String nordigenInstitutionId,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class __$BankAccountApiCopyWithImpl<$Res>
    implements _$BankAccountApiCopyWith<$Res> {
  __$BankAccountApiCopyWithImpl(this._self, this._then);

  final _BankAccountApi _self;
  final $Res Function(_BankAccountApi) _then;

/// Create a copy of BankAccountApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bankAccountName = null,Object? bankAccountStatus = null,Object? bankAccountType = null,Object? providerName = null,Object? balance = null,Object? currency = null,Object? fromDate = null,Object? autoSync = null,Object? disabledUpstream = null,Object? integrationType = null,Object? nordigenInstitutionId = null,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_BankAccountApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bankAccountName: null == bankAccountName ? _self.bankAccountName : bankAccountName // ignore: cast_nullable_to_non_nullable
as String,bankAccountStatus: null == bankAccountStatus ? _self.bankAccountStatus : bankAccountStatus // ignore: cast_nullable_to_non_nullable
as String,bankAccountType: null == bankAccountType ? _self.bankAccountType : bankAccountType // ignore: cast_nullable_to_non_nullable
as String,providerName: null == providerName ? _self.providerName : providerName // ignore: cast_nullable_to_non_nullable
as String,balance: null == balance ? _self.balance : balance ,currency: null == currency ? _self.currency : currency // ignore: cast_nullable_to_non_nullable
as String,fromDate: null == fromDate ? _self.fromDate : fromDate // ignore: cast_nullable_to_non_nullable
as String,autoSync: null == autoSync ? _self.autoSync : autoSync // ignore: cast_nullable_to_non_nullable
as bool,disabledUpstream: null == disabledUpstream ? _self.disabledUpstream : disabledUpstream // ignore: cast_nullable_to_non_nullable
as bool,integrationType: null == integrationType ? _self.integrationType : integrationType // ignore: cast_nullable_to_non_nullable
as String,nordigenInstitutionId: null == nordigenInstitutionId ? _self.nordigenInstitutionId : nordigenInstitutionId // ignore: cast_nullable_to_non_nullable
as String,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$BankAccountListApi {

@JsonKey(fromJson: _bankAccountListData) List<BankAccountApi> get data;
/// Create a copy of BankAccountListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BankAccountListApiCopyWith<BankAccountListApi> get copyWith => _$BankAccountListApiCopyWithImpl<BankAccountListApi>(this as BankAccountListApi, _$identity);

  /// Serializes this BankAccountListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BankAccountListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'BankAccountListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $BankAccountListApiCopyWith<$Res>  {
  factory $BankAccountListApiCopyWith(BankAccountListApi value, $Res Function(BankAccountListApi) _then) = _$BankAccountListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _bankAccountListData) List<BankAccountApi> data
});




}
/// @nodoc
class _$BankAccountListApiCopyWithImpl<$Res>
    implements $BankAccountListApiCopyWith<$Res> {
  _$BankAccountListApiCopyWithImpl(this._self, this._then);

  final BankAccountListApi _self;
  final $Res Function(BankAccountListApi) _then;

/// Create a copy of BankAccountListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<BankAccountApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [BankAccountListApi].
extension BankAccountListApiPatterns on BankAccountListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BankAccountListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BankAccountListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BankAccountListApi value)  $default,){
final _that = this;
switch (_that) {
case _BankAccountListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BankAccountListApi value)?  $default,){
final _that = this;
switch (_that) {
case _BankAccountListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _bankAccountListData)  List<BankAccountApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BankAccountListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _bankAccountListData)  List<BankAccountApi> data)  $default,) {final _that = this;
switch (_that) {
case _BankAccountListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _bankAccountListData)  List<BankAccountApi> data)?  $default,) {final _that = this;
switch (_that) {
case _BankAccountListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BankAccountListApi implements BankAccountListApi {
  const _BankAccountListApi({@JsonKey(fromJson: _bankAccountListData) final  List<BankAccountApi> data = const []}): _data = data;
  factory _BankAccountListApi.fromJson(Map<String, dynamic> json) => _$BankAccountListApiFromJson(json);

 final  List<BankAccountApi> _data;
@override@JsonKey(fromJson: _bankAccountListData) List<BankAccountApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of BankAccountListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BankAccountListApiCopyWith<_BankAccountListApi> get copyWith => __$BankAccountListApiCopyWithImpl<_BankAccountListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BankAccountListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BankAccountListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'BankAccountListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$BankAccountListApiCopyWith<$Res> implements $BankAccountListApiCopyWith<$Res> {
  factory _$BankAccountListApiCopyWith(_BankAccountListApi value, $Res Function(_BankAccountListApi) _then) = __$BankAccountListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _bankAccountListData) List<BankAccountApi> data
});




}
/// @nodoc
class __$BankAccountListApiCopyWithImpl<$Res>
    implements _$BankAccountListApiCopyWith<$Res> {
  __$BankAccountListApiCopyWithImpl(this._self, this._then);

  final _BankAccountListApi _self;
  final $Res Function(_BankAccountListApi) _then;

/// Create a copy of BankAccountListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_BankAccountListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<BankAccountApi>,
  ));
}


}


/// @nodoc
mixin _$BankAccountItemApi {

 BankAccountApi get data;
/// Create a copy of BankAccountItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BankAccountItemApiCopyWith<BankAccountItemApi> get copyWith => _$BankAccountItemApiCopyWithImpl<BankAccountItemApi>(this as BankAccountItemApi, _$identity);

  /// Serializes this BankAccountItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BankAccountItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'BankAccountItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $BankAccountItemApiCopyWith<$Res>  {
  factory $BankAccountItemApiCopyWith(BankAccountItemApi value, $Res Function(BankAccountItemApi) _then) = _$BankAccountItemApiCopyWithImpl;
@useResult
$Res call({
 BankAccountApi data
});


$BankAccountApiCopyWith<$Res> get data;

}
/// @nodoc
class _$BankAccountItemApiCopyWithImpl<$Res>
    implements $BankAccountItemApiCopyWith<$Res> {
  _$BankAccountItemApiCopyWithImpl(this._self, this._then);

  final BankAccountItemApi _self;
  final $Res Function(BankAccountItemApi) _then;

/// Create a copy of BankAccountItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as BankAccountApi,
  ));
}
/// Create a copy of BankAccountItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BankAccountApiCopyWith<$Res> get data {
  
  return $BankAccountApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [BankAccountItemApi].
extension BankAccountItemApiPatterns on BankAccountItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BankAccountItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BankAccountItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BankAccountItemApi value)  $default,){
final _that = this;
switch (_that) {
case _BankAccountItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BankAccountItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _BankAccountItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BankAccountApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BankAccountItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BankAccountApi data)  $default,) {final _that = this;
switch (_that) {
case _BankAccountItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BankAccountApi data)?  $default,) {final _that = this;
switch (_that) {
case _BankAccountItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BankAccountItemApi implements BankAccountItemApi {
  const _BankAccountItemApi({required this.data});
  factory _BankAccountItemApi.fromJson(Map<String, dynamic> json) => _$BankAccountItemApiFromJson(json);

@override final  BankAccountApi data;

/// Create a copy of BankAccountItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BankAccountItemApiCopyWith<_BankAccountItemApi> get copyWith => __$BankAccountItemApiCopyWithImpl<_BankAccountItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BankAccountItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BankAccountItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'BankAccountItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$BankAccountItemApiCopyWith<$Res> implements $BankAccountItemApiCopyWith<$Res> {
  factory _$BankAccountItemApiCopyWith(_BankAccountItemApi value, $Res Function(_BankAccountItemApi) _then) = __$BankAccountItemApiCopyWithImpl;
@override @useResult
$Res call({
 BankAccountApi data
});


@override $BankAccountApiCopyWith<$Res> get data;

}
/// @nodoc
class __$BankAccountItemApiCopyWithImpl<$Res>
    implements _$BankAccountItemApiCopyWith<$Res> {
  __$BankAccountItemApiCopyWithImpl(this._self, this._then);

  final _BankAccountItemApi _self;
  final $Res Function(_BankAccountItemApi) _then;

/// Create a copy of BankAccountItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_BankAccountItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as BankAccountApi,
  ));
}

/// Create a copy of BankAccountItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BankAccountApiCopyWith<$Res> get data {
  
  return $BankAccountApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
