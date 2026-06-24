// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserItemApi {

 UserApi get data;
/// Create a copy of UserItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserItemApiCopyWith<UserItemApi> get copyWith => _$UserItemApiCopyWithImpl<UserItemApi>(this as UserItemApi, _$identity);

  /// Serializes this UserItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'UserItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $UserItemApiCopyWith<$Res>  {
  factory $UserItemApiCopyWith(UserItemApi value, $Res Function(UserItemApi) _then) = _$UserItemApiCopyWithImpl;
@useResult
$Res call({
 UserApi data
});


$UserApiCopyWith<$Res> get data;

}
/// @nodoc
class _$UserItemApiCopyWithImpl<$Res>
    implements $UserItemApiCopyWith<$Res> {
  _$UserItemApiCopyWithImpl(this._self, this._then);

  final UserItemApi _self;
  final $Res Function(UserItemApi) _then;

/// Create a copy of UserItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as UserApi,
  ));
}
/// Create a copy of UserItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserApiCopyWith<$Res> get data {
  
  return $UserApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserItemApi].
extension UserItemApiPatterns on UserItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserItemApi value)  $default,){
final _that = this;
switch (_that) {
case _UserItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _UserItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UserApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UserApi data)  $default,) {final _that = this;
switch (_that) {
case _UserItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UserApi data)?  $default,) {final _that = this;
switch (_that) {
case _UserItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserItemApi implements UserItemApi {
  const _UserItemApi({required this.data});
  factory _UserItemApi.fromJson(Map<String, dynamic> json) => _$UserItemApiFromJson(json);

@override final  UserApi data;

/// Create a copy of UserItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserItemApiCopyWith<_UserItemApi> get copyWith => __$UserItemApiCopyWithImpl<_UserItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'UserItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$UserItemApiCopyWith<$Res> implements $UserItemApiCopyWith<$Res> {
  factory _$UserItemApiCopyWith(_UserItemApi value, $Res Function(_UserItemApi) _then) = __$UserItemApiCopyWithImpl;
@override @useResult
$Res call({
 UserApi data
});


@override $UserApiCopyWith<$Res> get data;

}
/// @nodoc
class __$UserItemApiCopyWithImpl<$Res>
    implements _$UserItemApiCopyWith<$Res> {
  __$UserItemApiCopyWithImpl(this._self, this._then);

  final _UserItemApi _self;
  final $Res Function(_UserItemApi) _then;

/// Create a copy of UserItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_UserItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as UserApi,
  ));
}

/// Create a copy of UserItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserApiCopyWith<$Res> get data {
  
  return $UserApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// @nodoc
mixin _$UserListApi {

@JsonKey(fromJson: _userListData) List<UserApi> get data;
/// Create a copy of UserListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserListApiCopyWith<UserListApi> get copyWith => _$UserListApiCopyWithImpl<UserListApi>(this as UserListApi, _$identity);

  /// Serializes this UserListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'UserListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $UserListApiCopyWith<$Res>  {
  factory $UserListApiCopyWith(UserListApi value, $Res Function(UserListApi) _then) = _$UserListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _userListData) List<UserApi> data
});




}
/// @nodoc
class _$UserListApiCopyWithImpl<$Res>
    implements $UserListApiCopyWith<$Res> {
  _$UserListApiCopyWithImpl(this._self, this._then);

  final UserListApi _self;
  final $Res Function(UserListApi) _then;

/// Create a copy of UserListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<UserApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [UserListApi].
extension UserListApiPatterns on UserListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserListApi value)  $default,){
final _that = this;
switch (_that) {
case _UserListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserListApi value)?  $default,){
final _that = this;
switch (_that) {
case _UserListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _userListData)  List<UserApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _userListData)  List<UserApi> data)  $default,) {final _that = this;
switch (_that) {
case _UserListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _userListData)  List<UserApi> data)?  $default,) {final _that = this;
switch (_that) {
case _UserListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserListApi implements UserListApi {
  const _UserListApi({@JsonKey(fromJson: _userListData) final  List<UserApi> data = const <UserApi>[]}): _data = data;
  factory _UserListApi.fromJson(Map<String, dynamic> json) => _$UserListApiFromJson(json);

 final  List<UserApi> _data;
@override@JsonKey(fromJson: _userListData) List<UserApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of UserListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserListApiCopyWith<_UserListApi> get copyWith => __$UserListApiCopyWithImpl<_UserListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'UserListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$UserListApiCopyWith<$Res> implements $UserListApiCopyWith<$Res> {
  factory _$UserListApiCopyWith(_UserListApi value, $Res Function(_UserListApi) _then) = __$UserListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _userListData) List<UserApi> data
});




}
/// @nodoc
class __$UserListApiCopyWithImpl<$Res>
    implements _$UserListApiCopyWith<$Res> {
  __$UserListApiCopyWithImpl(this._self, this._then);

  final _UserListApi _self;
  final $Res Function(_UserListApi) _then;

/// Create a copy of UserListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_UserListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<UserApi>,
  ));
}


}


/// @nodoc
mixin _$UserApi {

 String get id;@JsonKey(name: 'first_name') String get firstName;@JsonKey(name: 'last_name') String get lastName; String get email; String get phone; String get signature;@JsonKey(name: 'language_id') String get languageId;// -- Connect tab inputs ---------------------------------------------------
@JsonKey(name: 'oauth_provider_id') String get oauthProviderId;@JsonKey(name: 'oauth_user_token') String get oauthUserToken;@JsonKey(name: 'oauth_user_refresh_token') String get oauthUserRefreshToken;// -- Two-factor / phone -------------------------------------------------
@JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson) bool get google2faSecret;@JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson) bool get verifiedPhoneNumber;// -- Misc ---------------------------------------------------------------
@JsonKey(name: 'has_password') bool get hasPassword;@JsonKey(name: 'last_login') int get lastLogin;@JsonKey(name: 'email_verified_at') int get emailVerifiedAt;@JsonKey(name: 'user_logged_in_notification', fromJson: _boolFromJson) bool get userLoggedInNotification;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;// -- Custom fields (gated on company.custom_fields.user1..4 in the UI) -
@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;// -- Per-company-user (active company only when ?include=company_user) -
@JsonKey(name: 'company_user') CompanyUserApi? get companyUser;
/// Create a copy of UserApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserApiCopyWith<UserApi> get copyWith => _$UserApiCopyWithImpl<UserApi>(this as UserApi, _$identity);

  /// Serializes this UserApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserApi&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.oauthProviderId, oauthProviderId) || other.oauthProviderId == oauthProviderId)&&(identical(other.oauthUserToken, oauthUserToken) || other.oauthUserToken == oauthUserToken)&&(identical(other.oauthUserRefreshToken, oauthUserRefreshToken) || other.oauthUserRefreshToken == oauthUserRefreshToken)&&(identical(other.google2faSecret, google2faSecret) || other.google2faSecret == google2faSecret)&&(identical(other.verifiedPhoneNumber, verifiedPhoneNumber) || other.verifiedPhoneNumber == verifiedPhoneNumber)&&(identical(other.hasPassword, hasPassword) || other.hasPassword == hasPassword)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&(identical(other.emailVerifiedAt, emailVerifiedAt) || other.emailVerifiedAt == emailVerifiedAt)&&(identical(other.userLoggedInNotification, userLoggedInNotification) || other.userLoggedInNotification == userLoggedInNotification)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.companyUser, companyUser) || other.companyUser == companyUser));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,firstName,lastName,email,phone,signature,languageId,oauthProviderId,oauthUserToken,oauthUserRefreshToken,google2faSecret,verifiedPhoneNumber,hasPassword,lastLogin,emailVerifiedAt,userLoggedInNotification,createdAt,updatedAt,archivedAt,isDeleted,customValue1,customValue2,customValue3,customValue4,companyUser]);

@override
String toString() {
  return 'UserApi(id: $id, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, signature: $signature, languageId: $languageId, oauthProviderId: $oauthProviderId, oauthUserToken: $oauthUserToken, oauthUserRefreshToken: $oauthUserRefreshToken, google2faSecret: $google2faSecret, verifiedPhoneNumber: $verifiedPhoneNumber, hasPassword: $hasPassword, lastLogin: $lastLogin, emailVerifiedAt: $emailVerifiedAt, userLoggedInNotification: $userLoggedInNotification, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, companyUser: $companyUser)';
}


}

/// @nodoc
abstract mixin class $UserApiCopyWith<$Res>  {
  factory $UserApiCopyWith(UserApi value, $Res Function(UserApi) _then) = _$UserApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'first_name') String firstName,@JsonKey(name: 'last_name') String lastName, String email, String phone, String signature,@JsonKey(name: 'language_id') String languageId,@JsonKey(name: 'oauth_provider_id') String oauthProviderId,@JsonKey(name: 'oauth_user_token') String oauthUserToken,@JsonKey(name: 'oauth_user_refresh_token') String oauthUserRefreshToken,@JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson) bool google2faSecret,@JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson) bool verifiedPhoneNumber,@JsonKey(name: 'has_password') bool hasPassword,@JsonKey(name: 'last_login') int lastLogin,@JsonKey(name: 'email_verified_at') int emailVerifiedAt,@JsonKey(name: 'user_logged_in_notification', fromJson: _boolFromJson) bool userLoggedInNotification,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'company_user') CompanyUserApi? companyUser
});


$CompanyUserApiCopyWith<$Res>? get companyUser;

}
/// @nodoc
class _$UserApiCopyWithImpl<$Res>
    implements $UserApiCopyWith<$Res> {
  _$UserApiCopyWithImpl(this._self, this._then);

  final UserApi _self;
  final $Res Function(UserApi) _then;

/// Create a copy of UserApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? signature = null,Object? languageId = null,Object? oauthProviderId = null,Object? oauthUserToken = null,Object? oauthUserRefreshToken = null,Object? google2faSecret = null,Object? verifiedPhoneNumber = null,Object? hasPassword = null,Object? lastLogin = null,Object? emailVerifiedAt = null,Object? userLoggedInNotification = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? companyUser = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,languageId: null == languageId ? _self.languageId : languageId // ignore: cast_nullable_to_non_nullable
as String,oauthProviderId: null == oauthProviderId ? _self.oauthProviderId : oauthProviderId // ignore: cast_nullable_to_non_nullable
as String,oauthUserToken: null == oauthUserToken ? _self.oauthUserToken : oauthUserToken // ignore: cast_nullable_to_non_nullable
as String,oauthUserRefreshToken: null == oauthUserRefreshToken ? _self.oauthUserRefreshToken : oauthUserRefreshToken // ignore: cast_nullable_to_non_nullable
as String,google2faSecret: null == google2faSecret ? _self.google2faSecret : google2faSecret // ignore: cast_nullable_to_non_nullable
as bool,verifiedPhoneNumber: null == verifiedPhoneNumber ? _self.verifiedPhoneNumber : verifiedPhoneNumber // ignore: cast_nullable_to_non_nullable
as bool,hasPassword: null == hasPassword ? _self.hasPassword : hasPassword // ignore: cast_nullable_to_non_nullable
as bool,lastLogin: null == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as int,emailVerifiedAt: null == emailVerifiedAt ? _self.emailVerifiedAt : emailVerifiedAt // ignore: cast_nullable_to_non_nullable
as int,userLoggedInNotification: null == userLoggedInNotification ? _self.userLoggedInNotification : userLoggedInNotification // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,companyUser: freezed == companyUser ? _self.companyUser : companyUser // ignore: cast_nullable_to_non_nullable
as CompanyUserApi?,
  ));
}
/// Create a copy of UserApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanyUserApiCopyWith<$Res>? get companyUser {
    if (_self.companyUser == null) {
    return null;
  }

  return $CompanyUserApiCopyWith<$Res>(_self.companyUser!, (value) {
    return _then(_self.copyWith(companyUser: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserApi].
extension UserApiPatterns on UserApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserApi value)  $default,){
final _that = this;
switch (_that) {
case _UserApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserApi value)?  $default,){
final _that = this;
switch (_that) {
case _UserApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'first_name')  String firstName, @JsonKey(name: 'last_name')  String lastName,  String email,  String phone,  String signature, @JsonKey(name: 'language_id')  String languageId, @JsonKey(name: 'oauth_provider_id')  String oauthProviderId, @JsonKey(name: 'oauth_user_token')  String oauthUserToken, @JsonKey(name: 'oauth_user_refresh_token')  String oauthUserRefreshToken, @JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson)  bool google2faSecret, @JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson)  bool verifiedPhoneNumber, @JsonKey(name: 'has_password')  bool hasPassword, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'email_verified_at')  int emailVerifiedAt, @JsonKey(name: 'user_logged_in_notification', fromJson: _boolFromJson)  bool userLoggedInNotification, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'company_user')  CompanyUserApi? companyUser)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserApi() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.signature,_that.languageId,_that.oauthProviderId,_that.oauthUserToken,_that.oauthUserRefreshToken,_that.google2faSecret,_that.verifiedPhoneNumber,_that.hasPassword,_that.lastLogin,_that.emailVerifiedAt,_that.userLoggedInNotification,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.companyUser);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'first_name')  String firstName, @JsonKey(name: 'last_name')  String lastName,  String email,  String phone,  String signature, @JsonKey(name: 'language_id')  String languageId, @JsonKey(name: 'oauth_provider_id')  String oauthProviderId, @JsonKey(name: 'oauth_user_token')  String oauthUserToken, @JsonKey(name: 'oauth_user_refresh_token')  String oauthUserRefreshToken, @JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson)  bool google2faSecret, @JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson)  bool verifiedPhoneNumber, @JsonKey(name: 'has_password')  bool hasPassword, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'email_verified_at')  int emailVerifiedAt, @JsonKey(name: 'user_logged_in_notification', fromJson: _boolFromJson)  bool userLoggedInNotification, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'company_user')  CompanyUserApi? companyUser)  $default,) {final _that = this;
switch (_that) {
case _UserApi():
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.signature,_that.languageId,_that.oauthProviderId,_that.oauthUserToken,_that.oauthUserRefreshToken,_that.google2faSecret,_that.verifiedPhoneNumber,_that.hasPassword,_that.lastLogin,_that.emailVerifiedAt,_that.userLoggedInNotification,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.companyUser);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'first_name')  String firstName, @JsonKey(name: 'last_name')  String lastName,  String email,  String phone,  String signature, @JsonKey(name: 'language_id')  String languageId, @JsonKey(name: 'oauth_provider_id')  String oauthProviderId, @JsonKey(name: 'oauth_user_token')  String oauthUserToken, @JsonKey(name: 'oauth_user_refresh_token')  String oauthUserRefreshToken, @JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson)  bool google2faSecret, @JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson)  bool verifiedPhoneNumber, @JsonKey(name: 'has_password')  bool hasPassword, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'email_verified_at')  int emailVerifiedAt, @JsonKey(name: 'user_logged_in_notification', fromJson: _boolFromJson)  bool userLoggedInNotification, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'company_user')  CompanyUserApi? companyUser)?  $default,) {final _that = this;
switch (_that) {
case _UserApi() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.signature,_that.languageId,_that.oauthProviderId,_that.oauthUserToken,_that.oauthUserRefreshToken,_that.google2faSecret,_that.verifiedPhoneNumber,_that.hasPassword,_that.lastLogin,_that.emailVerifiedAt,_that.userLoggedInNotification,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.companyUser);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserApi implements UserApi {
  const _UserApi({this.id = '', @JsonKey(name: 'first_name') this.firstName = '', @JsonKey(name: 'last_name') this.lastName = '', this.email = '', this.phone = '', this.signature = '', @JsonKey(name: 'language_id') this.languageId = '', @JsonKey(name: 'oauth_provider_id') this.oauthProviderId = '', @JsonKey(name: 'oauth_user_token') this.oauthUserToken = '', @JsonKey(name: 'oauth_user_refresh_token') this.oauthUserRefreshToken = '', @JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson) this.google2faSecret = false, @JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson) this.verifiedPhoneNumber = false, @JsonKey(name: 'has_password') this.hasPassword = false, @JsonKey(name: 'last_login') this.lastLogin = 0, @JsonKey(name: 'email_verified_at') this.emailVerifiedAt = 0, @JsonKey(name: 'user_logged_in_notification', fromJson: _boolFromJson) this.userLoggedInNotification = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'company_user') this.companyUser});
  factory _UserApi.fromJson(Map<String, dynamic> json) => _$UserApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'first_name') final  String firstName;
@override@JsonKey(name: 'last_name') final  String lastName;
@override@JsonKey() final  String email;
@override@JsonKey() final  String phone;
@override@JsonKey() final  String signature;
@override@JsonKey(name: 'language_id') final  String languageId;
// -- Connect tab inputs ---------------------------------------------------
@override@JsonKey(name: 'oauth_provider_id') final  String oauthProviderId;
@override@JsonKey(name: 'oauth_user_token') final  String oauthUserToken;
@override@JsonKey(name: 'oauth_user_refresh_token') final  String oauthUserRefreshToken;
// -- Two-factor / phone -------------------------------------------------
@override@JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson) final  bool google2faSecret;
@override@JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson) final  bool verifiedPhoneNumber;
// -- Misc ---------------------------------------------------------------
@override@JsonKey(name: 'has_password') final  bool hasPassword;
@override@JsonKey(name: 'last_login') final  int lastLogin;
@override@JsonKey(name: 'email_verified_at') final  int emailVerifiedAt;
@override@JsonKey(name: 'user_logged_in_notification', fromJson: _boolFromJson) final  bool userLoggedInNotification;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
// -- Custom fields (gated on company.custom_fields.user1..4 in the UI) -
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
// -- Per-company-user (active company only when ?include=company_user) -
@override@JsonKey(name: 'company_user') final  CompanyUserApi? companyUser;

/// Create a copy of UserApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserApiCopyWith<_UserApi> get copyWith => __$UserApiCopyWithImpl<_UserApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserApi&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.oauthProviderId, oauthProviderId) || other.oauthProviderId == oauthProviderId)&&(identical(other.oauthUserToken, oauthUserToken) || other.oauthUserToken == oauthUserToken)&&(identical(other.oauthUserRefreshToken, oauthUserRefreshToken) || other.oauthUserRefreshToken == oauthUserRefreshToken)&&(identical(other.google2faSecret, google2faSecret) || other.google2faSecret == google2faSecret)&&(identical(other.verifiedPhoneNumber, verifiedPhoneNumber) || other.verifiedPhoneNumber == verifiedPhoneNumber)&&(identical(other.hasPassword, hasPassword) || other.hasPassword == hasPassword)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&(identical(other.emailVerifiedAt, emailVerifiedAt) || other.emailVerifiedAt == emailVerifiedAt)&&(identical(other.userLoggedInNotification, userLoggedInNotification) || other.userLoggedInNotification == userLoggedInNotification)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.companyUser, companyUser) || other.companyUser == companyUser));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,firstName,lastName,email,phone,signature,languageId,oauthProviderId,oauthUserToken,oauthUserRefreshToken,google2faSecret,verifiedPhoneNumber,hasPassword,lastLogin,emailVerifiedAt,userLoggedInNotification,createdAt,updatedAt,archivedAt,isDeleted,customValue1,customValue2,customValue3,customValue4,companyUser]);

@override
String toString() {
  return 'UserApi(id: $id, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, signature: $signature, languageId: $languageId, oauthProviderId: $oauthProviderId, oauthUserToken: $oauthUserToken, oauthUserRefreshToken: $oauthUserRefreshToken, google2faSecret: $google2faSecret, verifiedPhoneNumber: $verifiedPhoneNumber, hasPassword: $hasPassword, lastLogin: $lastLogin, emailVerifiedAt: $emailVerifiedAt, userLoggedInNotification: $userLoggedInNotification, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, companyUser: $companyUser)';
}


}

/// @nodoc
abstract mixin class _$UserApiCopyWith<$Res> implements $UserApiCopyWith<$Res> {
  factory _$UserApiCopyWith(_UserApi value, $Res Function(_UserApi) _then) = __$UserApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'first_name') String firstName,@JsonKey(name: 'last_name') String lastName, String email, String phone, String signature,@JsonKey(name: 'language_id') String languageId,@JsonKey(name: 'oauth_provider_id') String oauthProviderId,@JsonKey(name: 'oauth_user_token') String oauthUserToken,@JsonKey(name: 'oauth_user_refresh_token') String oauthUserRefreshToken,@JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson) bool google2faSecret,@JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson) bool verifiedPhoneNumber,@JsonKey(name: 'has_password') bool hasPassword,@JsonKey(name: 'last_login') int lastLogin,@JsonKey(name: 'email_verified_at') int emailVerifiedAt,@JsonKey(name: 'user_logged_in_notification', fromJson: _boolFromJson) bool userLoggedInNotification,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'company_user') CompanyUserApi? companyUser
});


@override $CompanyUserApiCopyWith<$Res>? get companyUser;

}
/// @nodoc
class __$UserApiCopyWithImpl<$Res>
    implements _$UserApiCopyWith<$Res> {
  __$UserApiCopyWithImpl(this._self, this._then);

  final _UserApi _self;
  final $Res Function(_UserApi) _then;

/// Create a copy of UserApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? signature = null,Object? languageId = null,Object? oauthProviderId = null,Object? oauthUserToken = null,Object? oauthUserRefreshToken = null,Object? google2faSecret = null,Object? verifiedPhoneNumber = null,Object? hasPassword = null,Object? lastLogin = null,Object? emailVerifiedAt = null,Object? userLoggedInNotification = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? companyUser = freezed,}) {
  return _then(_UserApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,languageId: null == languageId ? _self.languageId : languageId // ignore: cast_nullable_to_non_nullable
as String,oauthProviderId: null == oauthProviderId ? _self.oauthProviderId : oauthProviderId // ignore: cast_nullable_to_non_nullable
as String,oauthUserToken: null == oauthUserToken ? _self.oauthUserToken : oauthUserToken // ignore: cast_nullable_to_non_nullable
as String,oauthUserRefreshToken: null == oauthUserRefreshToken ? _self.oauthUserRefreshToken : oauthUserRefreshToken // ignore: cast_nullable_to_non_nullable
as String,google2faSecret: null == google2faSecret ? _self.google2faSecret : google2faSecret // ignore: cast_nullable_to_non_nullable
as bool,verifiedPhoneNumber: null == verifiedPhoneNumber ? _self.verifiedPhoneNumber : verifiedPhoneNumber // ignore: cast_nullable_to_non_nullable
as bool,hasPassword: null == hasPassword ? _self.hasPassword : hasPassword // ignore: cast_nullable_to_non_nullable
as bool,lastLogin: null == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as int,emailVerifiedAt: null == emailVerifiedAt ? _self.emailVerifiedAt : emailVerifiedAt // ignore: cast_nullable_to_non_nullable
as int,userLoggedInNotification: null == userLoggedInNotification ? _self.userLoggedInNotification : userLoggedInNotification // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,companyUser: freezed == companyUser ? _self.companyUser : companyUser // ignore: cast_nullable_to_non_nullable
as CompanyUserApi?,
  ));
}

/// Create a copy of UserApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanyUserApiCopyWith<$Res>? get companyUser {
    if (_self.companyUser == null) {
    return null;
  }

  return $CompanyUserApiCopyWith<$Res>(_self.companyUser!, (value) {
    return _then(_self.copyWith(companyUser: value));
  });
}
}


/// @nodoc
mixin _$CompanyUserApi {

 String get permissions;@JsonKey(name: 'is_owner') bool get isOwner;@JsonKey(name: 'is_admin') bool get isAdmin;@JsonKey(name: 'is_locked') bool get isLocked; Map<String, dynamic> get notifications; Map<String, dynamic> get settings;
/// Create a copy of CompanyUserApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyUserApiCopyWith<CompanyUserApi> get copyWith => _$CompanyUserApiCopyWithImpl<CompanyUserApi>(this as CompanyUserApi, _$identity);

  /// Serializes this CompanyUserApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanyUserApi&&(identical(other.permissions, permissions) || other.permissions == permissions)&&(identical(other.isOwner, isOwner) || other.isOwner == isOwner)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.isLocked, isLocked) || other.isLocked == isLocked)&&const DeepCollectionEquality().equals(other.notifications, notifications)&&const DeepCollectionEquality().equals(other.settings, settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,permissions,isOwner,isAdmin,isLocked,const DeepCollectionEquality().hash(notifications),const DeepCollectionEquality().hash(settings));

@override
String toString() {
  return 'CompanyUserApi(permissions: $permissions, isOwner: $isOwner, isAdmin: $isAdmin, isLocked: $isLocked, notifications: $notifications, settings: $settings)';
}


}

/// @nodoc
abstract mixin class $CompanyUserApiCopyWith<$Res>  {
  factory $CompanyUserApiCopyWith(CompanyUserApi value, $Res Function(CompanyUserApi) _then) = _$CompanyUserApiCopyWithImpl;
@useResult
$Res call({
 String permissions,@JsonKey(name: 'is_owner') bool isOwner,@JsonKey(name: 'is_admin') bool isAdmin,@JsonKey(name: 'is_locked') bool isLocked, Map<String, dynamic> notifications, Map<String, dynamic> settings
});




}
/// @nodoc
class _$CompanyUserApiCopyWithImpl<$Res>
    implements $CompanyUserApiCopyWith<$Res> {
  _$CompanyUserApiCopyWithImpl(this._self, this._then);

  final CompanyUserApi _self;
  final $Res Function(CompanyUserApi) _then;

/// Create a copy of CompanyUserApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? permissions = null,Object? isOwner = null,Object? isAdmin = null,Object? isLocked = null,Object? notifications = null,Object? settings = null,}) {
  return _then(_self.copyWith(
permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as String,isOwner: null == isOwner ? _self.isOwner : isOwner // ignore: cast_nullable_to_non_nullable
as bool,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,isLocked: null == isLocked ? _self.isLocked : isLocked // ignore: cast_nullable_to_non_nullable
as bool,notifications: null == notifications ? _self.notifications : notifications // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [CompanyUserApi].
extension CompanyUserApiPatterns on CompanyUserApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompanyUserApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompanyUserApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompanyUserApi value)  $default,){
final _that = this;
switch (_that) {
case _CompanyUserApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompanyUserApi value)?  $default,){
final _that = this;
switch (_that) {
case _CompanyUserApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String permissions, @JsonKey(name: 'is_owner')  bool isOwner, @JsonKey(name: 'is_admin')  bool isAdmin, @JsonKey(name: 'is_locked')  bool isLocked,  Map<String, dynamic> notifications,  Map<String, dynamic> settings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompanyUserApi() when $default != null:
return $default(_that.permissions,_that.isOwner,_that.isAdmin,_that.isLocked,_that.notifications,_that.settings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String permissions, @JsonKey(name: 'is_owner')  bool isOwner, @JsonKey(name: 'is_admin')  bool isAdmin, @JsonKey(name: 'is_locked')  bool isLocked,  Map<String, dynamic> notifications,  Map<String, dynamic> settings)  $default,) {final _that = this;
switch (_that) {
case _CompanyUserApi():
return $default(_that.permissions,_that.isOwner,_that.isAdmin,_that.isLocked,_that.notifications,_that.settings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String permissions, @JsonKey(name: 'is_owner')  bool isOwner, @JsonKey(name: 'is_admin')  bool isAdmin, @JsonKey(name: 'is_locked')  bool isLocked,  Map<String, dynamic> notifications,  Map<String, dynamic> settings)?  $default,) {final _that = this;
switch (_that) {
case _CompanyUserApi() when $default != null:
return $default(_that.permissions,_that.isOwner,_that.isAdmin,_that.isLocked,_that.notifications,_that.settings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CompanyUserApi implements CompanyUserApi {
  const _CompanyUserApi({this.permissions = '', @JsonKey(name: 'is_owner') this.isOwner = false, @JsonKey(name: 'is_admin') this.isAdmin = false, @JsonKey(name: 'is_locked') this.isLocked = false, final  Map<String, dynamic> notifications = const <String, dynamic>{}, final  Map<String, dynamic> settings = const <String, dynamic>{}}): _notifications = notifications,_settings = settings;
  factory _CompanyUserApi.fromJson(Map<String, dynamic> json) => _$CompanyUserApiFromJson(json);

@override@JsonKey() final  String permissions;
@override@JsonKey(name: 'is_owner') final  bool isOwner;
@override@JsonKey(name: 'is_admin') final  bool isAdmin;
@override@JsonKey(name: 'is_locked') final  bool isLocked;
 final  Map<String, dynamic> _notifications;
@override@JsonKey() Map<String, dynamic> get notifications {
  if (_notifications is EqualUnmodifiableMapView) return _notifications;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_notifications);
}

 final  Map<String, dynamic> _settings;
@override@JsonKey() Map<String, dynamic> get settings {
  if (_settings is EqualUnmodifiableMapView) return _settings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_settings);
}


/// Create a copy of CompanyUserApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyUserApiCopyWith<_CompanyUserApi> get copyWith => __$CompanyUserApiCopyWithImpl<_CompanyUserApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanyUserApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompanyUserApi&&(identical(other.permissions, permissions) || other.permissions == permissions)&&(identical(other.isOwner, isOwner) || other.isOwner == isOwner)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.isLocked, isLocked) || other.isLocked == isLocked)&&const DeepCollectionEquality().equals(other._notifications, _notifications)&&const DeepCollectionEquality().equals(other._settings, _settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,permissions,isOwner,isAdmin,isLocked,const DeepCollectionEquality().hash(_notifications),const DeepCollectionEquality().hash(_settings));

@override
String toString() {
  return 'CompanyUserApi(permissions: $permissions, isOwner: $isOwner, isAdmin: $isAdmin, isLocked: $isLocked, notifications: $notifications, settings: $settings)';
}


}

/// @nodoc
abstract mixin class _$CompanyUserApiCopyWith<$Res> implements $CompanyUserApiCopyWith<$Res> {
  factory _$CompanyUserApiCopyWith(_CompanyUserApi value, $Res Function(_CompanyUserApi) _then) = __$CompanyUserApiCopyWithImpl;
@override @useResult
$Res call({
 String permissions,@JsonKey(name: 'is_owner') bool isOwner,@JsonKey(name: 'is_admin') bool isAdmin,@JsonKey(name: 'is_locked') bool isLocked, Map<String, dynamic> notifications, Map<String, dynamic> settings
});




}
/// @nodoc
class __$CompanyUserApiCopyWithImpl<$Res>
    implements _$CompanyUserApiCopyWith<$Res> {
  __$CompanyUserApiCopyWithImpl(this._self, this._then);

  final _CompanyUserApi _self;
  final $Res Function(_CompanyUserApi) _then;

/// Create a copy of CompanyUserApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? permissions = null,Object? isOwner = null,Object? isAdmin = null,Object? isLocked = null,Object? notifications = null,Object? settings = null,}) {
  return _then(_CompanyUserApi(
permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as String,isOwner: null == isOwner ? _self.isOwner : isOwner // ignore: cast_nullable_to_non_nullable
as bool,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,isLocked: null == isLocked ? _self.isLocked : isLocked // ignore: cast_nullable_to_non_nullable
as bool,notifications: null == notifications ? _self._notifications : notifications // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,settings: null == settings ? _self._settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
