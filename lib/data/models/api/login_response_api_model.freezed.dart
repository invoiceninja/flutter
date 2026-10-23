// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'login_response_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LoginResponseApi {

@JsonKey(fromJson: _userCompanyListData) List<UserCompanyApi> get data;@JsonKey(name: 'static') Map<String, dynamic> get staticData;
/// Create a copy of LoginResponseApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginResponseApiCopyWith<LoginResponseApi> get copyWith => _$LoginResponseApiCopyWithImpl<LoginResponseApi>(this as LoginResponseApi, _$identity);

  /// Serializes this LoginResponseApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LoginResponseApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginResponseApi&&const DeepCollectionEquality().equals(other.data, _this.data)&&const DeepCollectionEquality().equals(other.staticData, _this.staticData));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LoginResponseApi;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data),const DeepCollectionEquality().hash(_this.staticData));
}

@override
String toString() {
  final _this = this as LoginResponseApi;
  return 'LoginResponseApi(data: ${_this.data}, staticData: ${_this.staticData})';
}


}

/// @nodoc
abstract mixin class $LoginResponseApiCopyWith<$Res>  {
  factory $LoginResponseApiCopyWith(LoginResponseApi value, $Res Function(LoginResponseApi) _then) = _$LoginResponseApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _userCompanyListData) List<UserCompanyApi> data,@JsonKey(name: 'static') Map<String, dynamic> staticData
});




}
/// @nodoc
class _$LoginResponseApiCopyWithImpl<$Res>
    implements $LoginResponseApiCopyWith<$Res> {
  _$LoginResponseApiCopyWithImpl(this._self, this._then);

  final LoginResponseApi _self;
  final $Res Function(LoginResponseApi) _then;

/// Create a copy of LoginResponseApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? staticData = null,}) {
  return _then(LoginResponseApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<UserCompanyApi>,staticData: null == staticData ? _self.staticData : staticData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [LoginResponseApi].
extension LoginResponseApiPatterns on LoginResponseApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoginResponseApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoginResponseApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoginResponseApi value)  $default,){
final _that = this;
switch (_that) {
case _LoginResponseApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoginResponseApi value)?  $default,){
final _that = this;
switch (_that) {
case _LoginResponseApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _userCompanyListData)  List<UserCompanyApi> data, @JsonKey(name: 'static')  Map<String, dynamic> staticData)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoginResponseApi() when $default != null:
return $default(_that.data,_that.staticData);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _userCompanyListData)  List<UserCompanyApi> data, @JsonKey(name: 'static')  Map<String, dynamic> staticData)  $default,) {final _that = this;
switch (_that) {
case _LoginResponseApi():
return $default(_that.data,_that.staticData);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _userCompanyListData)  List<UserCompanyApi> data, @JsonKey(name: 'static')  Map<String, dynamic> staticData)?  $default,) {final _that = this;
switch (_that) {
case _LoginResponseApi() when $default != null:
return $default(_that.data,_that.staticData);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LoginResponseApi implements LoginResponseApi {
  const _LoginResponseApi({@JsonKey(fromJson: _userCompanyListData)  List<UserCompanyApi> data = const <UserCompanyApi>[], @JsonKey(name: 'static')  Map<String, dynamic> staticData = const <String, dynamic>{}}): _data = data,_staticData = staticData;
  factory _LoginResponseApi.fromJson(Map<String, dynamic> json) => _$LoginResponseApiFromJson(json);

 final  List<UserCompanyApi> _data;
@override@JsonKey(fromJson: _userCompanyListData) List<UserCompanyApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}

 final  Map<String, dynamic> _staticData;
@override@JsonKey(name: 'static') Map<String, dynamic> get staticData {
  if (_staticData is EqualUnmodifiableMapView) return _staticData;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_staticData);
}


/// Create a copy of LoginResponseApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginResponseApiCopyWith<_LoginResponseApi> get copyWith => __$LoginResponseApiCopyWithImpl<_LoginResponseApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LoginResponseApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginResponseApi&&const DeepCollectionEquality().equals(other.data, _data)&&const DeepCollectionEquality().equals(other.staticData, _staticData));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data),const DeepCollectionEquality().hash(_staticData));
}

@override
String toString() {
    return 'LoginResponseApi(data: $data, staticData: $staticData)';
}


}

/// @nodoc
abstract mixin class _$LoginResponseApiCopyWith<$Res> implements $LoginResponseApiCopyWith<$Res> {
  factory _$LoginResponseApiCopyWith(_LoginResponseApi value, $Res Function(_LoginResponseApi) _then) = __$LoginResponseApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _userCompanyListData) List<UserCompanyApi> data,@JsonKey(name: 'static') Map<String, dynamic> staticData
});




}
/// @nodoc
class __$LoginResponseApiCopyWithImpl<$Res>
    implements _$LoginResponseApiCopyWith<$Res> {
  __$LoginResponseApiCopyWithImpl(this._self, this._then);

  final _LoginResponseApi _self;
  final $Res Function(_LoginResponseApi) _then;

/// Create a copy of LoginResponseApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? staticData = null,}) {
  return _then(_LoginResponseApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<UserCompanyApi>,staticData: null == staticData ? _self._staticData : staticData // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}


/// @nodoc
mixin _$UserCompanyApi {

@JsonKey(name: 'is_admin') bool get isAdmin;@JsonKey(name: 'is_owner') bool get isOwner; String get permissions;@JsonKey(name: 'permissions_updated_at') int get permissionsUpdatedAt; CompanyEnvelopeApi get company; SessionTokenApi get token; AccountEnvelopeApi get account; Map<String, dynamic> get settings;@JsonKey(name: 'react_settings', fromJson: _reactSettingsFromJson) Map<String, dynamic>? get reactSettings;@JsonKey(name: 'user') UserSummaryApi get user;@JsonKey(name: 'ninja_portal_url') String get ninjaPortalUrl;
/// Create a copy of UserCompanyApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCompanyApiCopyWith<UserCompanyApi> get copyWith => _$UserCompanyApiCopyWithImpl<UserCompanyApi>(this as UserCompanyApi, _$identity);

  /// Serializes this UserCompanyApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UserCompanyApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserCompanyApi&&(identical(other.isAdmin, _this.isAdmin) || other.isAdmin == _this.isAdmin)&&(identical(other.isOwner, _this.isOwner) || other.isOwner == _this.isOwner)&&(identical(other.permissions, _this.permissions) || other.permissions == _this.permissions)&&(identical(other.permissionsUpdatedAt, _this.permissionsUpdatedAt) || other.permissionsUpdatedAt == _this.permissionsUpdatedAt)&&(identical(other.company, _this.company) || other.company == _this.company)&&(identical(other.token, _this.token) || other.token == _this.token)&&(identical(other.account, _this.account) || other.account == _this.account)&&const DeepCollectionEquality().equals(other.settings, _this.settings)&&const DeepCollectionEquality().equals(other.reactSettings, _this.reactSettings)&&(identical(other.user, _this.user) || other.user == _this.user)&&(identical(other.ninjaPortalUrl, _this.ninjaPortalUrl) || other.ninjaPortalUrl == _this.ninjaPortalUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserCompanyApi;
  return Object.hash(runtimeType,_this.isAdmin,_this.isOwner,_this.permissions,_this.permissionsUpdatedAt,_this.company,_this.token,_this.account,const DeepCollectionEquality().hash(_this.settings),const DeepCollectionEquality().hash(_this.reactSettings),_this.user,_this.ninjaPortalUrl);
}

@override
String toString() {
  final _this = this as UserCompanyApi;
  return 'UserCompanyApi(isAdmin: ${_this.isAdmin}, isOwner: ${_this.isOwner}, permissions: ${_this.permissions}, permissionsUpdatedAt: ${_this.permissionsUpdatedAt}, company: ${_this.company}, token: ${_this.token}, account: ${_this.account}, settings: ${_this.settings}, reactSettings: ${_this.reactSettings}, user: ${_this.user}, ninjaPortalUrl: ${_this.ninjaPortalUrl})';
}


}

/// @nodoc
abstract mixin class $UserCompanyApiCopyWith<$Res>  {
  factory $UserCompanyApiCopyWith(UserCompanyApi value, $Res Function(UserCompanyApi) _then) = _$UserCompanyApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'is_admin') bool isAdmin,@JsonKey(name: 'is_owner') bool isOwner, String permissions,@JsonKey(name: 'permissions_updated_at') int permissionsUpdatedAt, CompanyEnvelopeApi company, SessionTokenApi token, AccountEnvelopeApi account, Map<String, dynamic> settings,@JsonKey(name: 'react_settings', fromJson: _reactSettingsFromJson) Map<String, dynamic>? reactSettings,@JsonKey(name: 'user') UserSummaryApi user,@JsonKey(name: 'ninja_portal_url') String ninjaPortalUrl
});


$CompanyEnvelopeApiCopyWith<$Res> get company;$SessionTokenApiCopyWith<$Res> get token;$AccountEnvelopeApiCopyWith<$Res> get account;$UserSummaryApiCopyWith<$Res> get user;

}
/// @nodoc
class _$UserCompanyApiCopyWithImpl<$Res>
    implements $UserCompanyApiCopyWith<$Res> {
  _$UserCompanyApiCopyWithImpl(this._self, this._then);

  final UserCompanyApi _self;
  final $Res Function(UserCompanyApi) _then;

/// Create a copy of UserCompanyApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isAdmin = null,Object? isOwner = null,Object? permissions = null,Object? permissionsUpdatedAt = null,Object? company = null,Object? token = null,Object? account = null,Object? settings = null,Object? reactSettings = freezed,Object? user = null,Object? ninjaPortalUrl = null,}) {
  return _then(UserCompanyApi(
isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,isOwner: null == isOwner ? _self.isOwner : isOwner // ignore: cast_nullable_to_non_nullable
as bool,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as String,permissionsUpdatedAt: null == permissionsUpdatedAt ? _self.permissionsUpdatedAt : permissionsUpdatedAt // ignore: cast_nullable_to_non_nullable
as int,company: null == company ? _self.company : company // ignore: cast_nullable_to_non_nullable
as CompanyEnvelopeApi,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as SessionTokenApi,account: null == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as AccountEnvelopeApi,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,reactSettings: freezed == reactSettings ? _self.reactSettings : reactSettings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummaryApi,ninjaPortalUrl: null == ninjaPortalUrl ? _self.ninjaPortalUrl : ninjaPortalUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of UserCompanyApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanyEnvelopeApiCopyWith<$Res> get company {
  
  return $CompanyEnvelopeApiCopyWith<$Res>(_self.company, (value) {
    return _then(_self.copyWith(company: value));
  });
}/// Create a copy of UserCompanyApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionTokenApiCopyWith<$Res> get token {
  
  return $SessionTokenApiCopyWith<$Res>(_self.token, (value) {
    return _then(_self.copyWith(token: value));
  });
}/// Create a copy of UserCompanyApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccountEnvelopeApiCopyWith<$Res> get account {
  
  return $AccountEnvelopeApiCopyWith<$Res>(_self.account, (value) {
    return _then(_self.copyWith(account: value));
  });
}/// Create a copy of UserCompanyApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryApiCopyWith<$Res> get user {
  
  return $UserSummaryApiCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserCompanyApi].
extension UserCompanyApiPatterns on UserCompanyApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserCompanyApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserCompanyApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserCompanyApi value)  $default,){
final _that = this;
switch (_that) {
case _UserCompanyApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserCompanyApi value)?  $default,){
final _that = this;
switch (_that) {
case _UserCompanyApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'is_admin')  bool isAdmin, @JsonKey(name: 'is_owner')  bool isOwner,  String permissions, @JsonKey(name: 'permissions_updated_at')  int permissionsUpdatedAt,  CompanyEnvelopeApi company,  SessionTokenApi token,  AccountEnvelopeApi account,  Map<String, dynamic> settings, @JsonKey(name: 'react_settings', fromJson: _reactSettingsFromJson)  Map<String, dynamic>? reactSettings, @JsonKey(name: 'user')  UserSummaryApi user, @JsonKey(name: 'ninja_portal_url')  String ninjaPortalUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserCompanyApi() when $default != null:
return $default(_that.isAdmin,_that.isOwner,_that.permissions,_that.permissionsUpdatedAt,_that.company,_that.token,_that.account,_that.settings,_that.reactSettings,_that.user,_that.ninjaPortalUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'is_admin')  bool isAdmin, @JsonKey(name: 'is_owner')  bool isOwner,  String permissions, @JsonKey(name: 'permissions_updated_at')  int permissionsUpdatedAt,  CompanyEnvelopeApi company,  SessionTokenApi token,  AccountEnvelopeApi account,  Map<String, dynamic> settings, @JsonKey(name: 'react_settings', fromJson: _reactSettingsFromJson)  Map<String, dynamic>? reactSettings, @JsonKey(name: 'user')  UserSummaryApi user, @JsonKey(name: 'ninja_portal_url')  String ninjaPortalUrl)  $default,) {final _that = this;
switch (_that) {
case _UserCompanyApi():
return $default(_that.isAdmin,_that.isOwner,_that.permissions,_that.permissionsUpdatedAt,_that.company,_that.token,_that.account,_that.settings,_that.reactSettings,_that.user,_that.ninjaPortalUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'is_admin')  bool isAdmin, @JsonKey(name: 'is_owner')  bool isOwner,  String permissions, @JsonKey(name: 'permissions_updated_at')  int permissionsUpdatedAt,  CompanyEnvelopeApi company,  SessionTokenApi token,  AccountEnvelopeApi account,  Map<String, dynamic> settings, @JsonKey(name: 'react_settings', fromJson: _reactSettingsFromJson)  Map<String, dynamic>? reactSettings, @JsonKey(name: 'user')  UserSummaryApi user, @JsonKey(name: 'ninja_portal_url')  String ninjaPortalUrl)?  $default,) {final _that = this;
switch (_that) {
case _UserCompanyApi() when $default != null:
return $default(_that.isAdmin,_that.isOwner,_that.permissions,_that.permissionsUpdatedAt,_that.company,_that.token,_that.account,_that.settings,_that.reactSettings,_that.user,_that.ninjaPortalUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserCompanyApi implements UserCompanyApi {
  const _UserCompanyApi({@JsonKey(name: 'is_admin') this.isAdmin = false, @JsonKey(name: 'is_owner') this.isOwner = false, this.permissions = '', @JsonKey(name: 'permissions_updated_at') this.permissionsUpdatedAt = 0, required this.company, this.token = const SessionTokenApi(), required this.account,  Map<String, dynamic> settings = const <String, dynamic>{}, @JsonKey(name: 'react_settings', fromJson: _reactSettingsFromJson)  Map<String, dynamic>? reactSettings, @JsonKey(name: 'user') this.user = const UserSummaryApi(), @JsonKey(name: 'ninja_portal_url') this.ninjaPortalUrl = ''}): _settings = settings,_reactSettings = reactSettings;
  factory _UserCompanyApi.fromJson(Map<String, dynamic> json) => _$UserCompanyApiFromJson(json);

@override@JsonKey(name: 'is_admin') final  bool isAdmin;
@override@JsonKey(name: 'is_owner') final  bool isOwner;
@override@JsonKey() final  String permissions;
@override@JsonKey(name: 'permissions_updated_at') final  int permissionsUpdatedAt;
@override final  CompanyEnvelopeApi company;
@override@JsonKey() final  SessionTokenApi token;
@override final  AccountEnvelopeApi account;
 final  Map<String, dynamic> _settings;
@override@JsonKey() Map<String, dynamic> get settings {
  if (_settings is EqualUnmodifiableMapView) return _settings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_settings);
}

 final  Map<String, dynamic>? _reactSettings;
@override@JsonKey(name: 'react_settings', fromJson: _reactSettingsFromJson) Map<String, dynamic>? get reactSettings {
  final value = _reactSettings;
  if (value == null) return null;
  if (_reactSettings is EqualUnmodifiableMapView) return _reactSettings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'user') final  UserSummaryApi user;
@override@JsonKey(name: 'ninja_portal_url') final  String ninjaPortalUrl;

/// Create a copy of UserCompanyApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCompanyApiCopyWith<_UserCompanyApi> get copyWith => __$UserCompanyApiCopyWithImpl<_UserCompanyApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserCompanyApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserCompanyApi&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.isOwner, isOwner) || other.isOwner == isOwner)&&(identical(other.permissions, permissions) || other.permissions == permissions)&&(identical(other.permissionsUpdatedAt, permissionsUpdatedAt) || other.permissionsUpdatedAt == permissionsUpdatedAt)&&(identical(other.company, company) || other.company == company)&&(identical(other.token, token) || other.token == token)&&(identical(other.account, account) || other.account == account)&&const DeepCollectionEquality().equals(other.settings, _settings)&&const DeepCollectionEquality().equals(other.reactSettings, _reactSettings)&&(identical(other.user, user) || other.user == user)&&(identical(other.ninjaPortalUrl, ninjaPortalUrl) || other.ninjaPortalUrl == ninjaPortalUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,isAdmin,isOwner,permissions,permissionsUpdatedAt,company,token,account,const DeepCollectionEquality().hash(_settings),const DeepCollectionEquality().hash(_reactSettings),user,ninjaPortalUrl);
}

@override
String toString() {
    return 'UserCompanyApi(isAdmin: $isAdmin, isOwner: $isOwner, permissions: $permissions, permissionsUpdatedAt: $permissionsUpdatedAt, company: $company, token: $token, account: $account, settings: $settings, reactSettings: $reactSettings, user: $user, ninjaPortalUrl: $ninjaPortalUrl)';
}


}

/// @nodoc
abstract mixin class _$UserCompanyApiCopyWith<$Res> implements $UserCompanyApiCopyWith<$Res> {
  factory _$UserCompanyApiCopyWith(_UserCompanyApi value, $Res Function(_UserCompanyApi) _then) = __$UserCompanyApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'is_admin') bool isAdmin,@JsonKey(name: 'is_owner') bool isOwner, String permissions,@JsonKey(name: 'permissions_updated_at') int permissionsUpdatedAt, CompanyEnvelopeApi company, SessionTokenApi token, AccountEnvelopeApi account, Map<String, dynamic> settings,@JsonKey(name: 'react_settings', fromJson: _reactSettingsFromJson) Map<String, dynamic>? reactSettings,@JsonKey(name: 'user') UserSummaryApi user,@JsonKey(name: 'ninja_portal_url') String ninjaPortalUrl
});


@override $CompanyEnvelopeApiCopyWith<$Res> get company;@override $SessionTokenApiCopyWith<$Res> get token;@override $AccountEnvelopeApiCopyWith<$Res> get account;@override $UserSummaryApiCopyWith<$Res> get user;

}
/// @nodoc
class __$UserCompanyApiCopyWithImpl<$Res>
    implements _$UserCompanyApiCopyWith<$Res> {
  __$UserCompanyApiCopyWithImpl(this._self, this._then);

  final _UserCompanyApi _self;
  final $Res Function(_UserCompanyApi) _then;

/// Create a copy of UserCompanyApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isAdmin = null,Object? isOwner = null,Object? permissions = null,Object? permissionsUpdatedAt = null,Object? company = null,Object? token = null,Object? account = null,Object? settings = null,Object? reactSettings = freezed,Object? user = null,Object? ninjaPortalUrl = null,}) {
  return _then(_UserCompanyApi(
isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,isOwner: null == isOwner ? _self.isOwner : isOwner // ignore: cast_nullable_to_non_nullable
as bool,permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as String,permissionsUpdatedAt: null == permissionsUpdatedAt ? _self.permissionsUpdatedAt : permissionsUpdatedAt // ignore: cast_nullable_to_non_nullable
as int,company: null == company ? _self.company : company // ignore: cast_nullable_to_non_nullable
as CompanyEnvelopeApi,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as SessionTokenApi,account: null == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as AccountEnvelopeApi,settings: null == settings ? _self._settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,reactSettings: freezed == reactSettings ? _self._reactSettings : reactSettings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as UserSummaryApi,ninjaPortalUrl: null == ninjaPortalUrl ? _self.ninjaPortalUrl : ninjaPortalUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of UserCompanyApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanyEnvelopeApiCopyWith<$Res> get company {
  
  return $CompanyEnvelopeApiCopyWith<$Res>(_self.company, (value) {
    return _then(_self.copyWith(company: value));
  });
}/// Create a copy of UserCompanyApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SessionTokenApiCopyWith<$Res> get token {
  
  return $SessionTokenApiCopyWith<$Res>(_self.token, (value) {
    return _then(_self.copyWith(token: value));
  });
}/// Create a copy of UserCompanyApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccountEnvelopeApiCopyWith<$Res> get account {
  
  return $AccountEnvelopeApiCopyWith<$Res>(_self.account, (value) {
    return _then(_self.copyWith(account: value));
  });
}/// Create a copy of UserCompanyApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserSummaryApiCopyWith<$Res> get user {
  
  return $UserSummaryApiCopyWith<$Res>(_self.user, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// @nodoc
mixin _$UserSummaryApi {

 String get id;@JsonKey(name: 'first_name') String get firstName;@JsonKey(name: 'last_name') String get lastName;@JsonKey(name: 'email') String get email;@JsonKey(name: 'phone') String get phone;@JsonKey(name: 'signature') String get signature;@JsonKey(name: 'language_id') String get languageId;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;@JsonKey(name: 'oauth_provider_id') String get oauthProviderId;@JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson) bool get google2faSecret;@JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson) bool get verifiedPhoneNumber;@JsonKey(name: 'has_password', fromJson: _boolFromJson) bool get hasPassword;@JsonKey(name: 'oauth_user_token') String get oauthUserToken;@JsonKey(name: 'referral_code') String get referralCode;@JsonKey(name: 'referral_meta', fromJson: _referralMetaFromJson) Map<String, int> get referralMeta;
/// Create a copy of UserSummaryApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserSummaryApiCopyWith<UserSummaryApi> get copyWith => _$UserSummaryApiCopyWithImpl<UserSummaryApi>(this as UserSummaryApi, _$identity);

  /// Serializes this UserSummaryApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UserSummaryApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserSummaryApi&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.firstName, _this.firstName) || other.firstName == _this.firstName)&&(identical(other.lastName, _this.lastName) || other.lastName == _this.lastName)&&(identical(other.email, _this.email) || other.email == _this.email)&&(identical(other.phone, _this.phone) || other.phone == _this.phone)&&(identical(other.signature, _this.signature) || other.signature == _this.signature)&&(identical(other.languageId, _this.languageId) || other.languageId == _this.languageId)&&(identical(other.customValue1, _this.customValue1) || other.customValue1 == _this.customValue1)&&(identical(other.customValue2, _this.customValue2) || other.customValue2 == _this.customValue2)&&(identical(other.customValue3, _this.customValue3) || other.customValue3 == _this.customValue3)&&(identical(other.customValue4, _this.customValue4) || other.customValue4 == _this.customValue4)&&(identical(other.oauthProviderId, _this.oauthProviderId) || other.oauthProviderId == _this.oauthProviderId)&&(identical(other.google2faSecret, _this.google2faSecret) || other.google2faSecret == _this.google2faSecret)&&(identical(other.verifiedPhoneNumber, _this.verifiedPhoneNumber) || other.verifiedPhoneNumber == _this.verifiedPhoneNumber)&&(identical(other.hasPassword, _this.hasPassword) || other.hasPassword == _this.hasPassword)&&(identical(other.oauthUserToken, _this.oauthUserToken) || other.oauthUserToken == _this.oauthUserToken)&&(identical(other.referralCode, _this.referralCode) || other.referralCode == _this.referralCode)&&const DeepCollectionEquality().equals(other.referralMeta, _this.referralMeta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserSummaryApi;
  return Object.hash(runtimeType,_this.id,_this.firstName,_this.lastName,_this.email,_this.phone,_this.signature,_this.languageId,_this.customValue1,_this.customValue2,_this.customValue3,_this.customValue4,_this.oauthProviderId,_this.google2faSecret,_this.verifiedPhoneNumber,_this.hasPassword,_this.oauthUserToken,_this.referralCode,const DeepCollectionEquality().hash(_this.referralMeta));
}

@override
String toString() {
  final _this = this as UserSummaryApi;
  return 'UserSummaryApi(id: ${_this.id}, firstName: ${_this.firstName}, lastName: ${_this.lastName}, email: ${_this.email}, phone: ${_this.phone}, signature: ${_this.signature}, languageId: ${_this.languageId}, customValue1: ${_this.customValue1}, customValue2: ${_this.customValue2}, customValue3: ${_this.customValue3}, customValue4: ${_this.customValue4}, oauthProviderId: ${_this.oauthProviderId}, google2faSecret: ${_this.google2faSecret}, verifiedPhoneNumber: ${_this.verifiedPhoneNumber}, hasPassword: ${_this.hasPassword}, oauthUserToken: ${_this.oauthUserToken}, referralCode: ${_this.referralCode}, referralMeta: ${_this.referralMeta})';
}


}

/// @nodoc
abstract mixin class $UserSummaryApiCopyWith<$Res>  {
  factory $UserSummaryApiCopyWith(UserSummaryApi value, $Res Function(UserSummaryApi) _then) = _$UserSummaryApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'first_name') String firstName,@JsonKey(name: 'last_name') String lastName,@JsonKey(name: 'email') String email,@JsonKey(name: 'phone') String phone,@JsonKey(name: 'signature') String signature,@JsonKey(name: 'language_id') String languageId,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'oauth_provider_id') String oauthProviderId,@JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson) bool google2faSecret,@JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson) bool verifiedPhoneNumber,@JsonKey(name: 'has_password', fromJson: _boolFromJson) bool hasPassword,@JsonKey(name: 'oauth_user_token') String oauthUserToken,@JsonKey(name: 'referral_code') String referralCode,@JsonKey(name: 'referral_meta', fromJson: _referralMetaFromJson) Map<String, int> referralMeta
});




}
/// @nodoc
class _$UserSummaryApiCopyWithImpl<$Res>
    implements $UserSummaryApiCopyWith<$Res> {
  _$UserSummaryApiCopyWithImpl(this._self, this._then);

  final UserSummaryApi _self;
  final $Res Function(UserSummaryApi) _then;

/// Create a copy of UserSummaryApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? signature = null,Object? languageId = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? oauthProviderId = null,Object? google2faSecret = null,Object? verifiedPhoneNumber = null,Object? hasPassword = null,Object? oauthUserToken = null,Object? referralCode = null,Object? referralMeta = null,}) {
  return _then(UserSummaryApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,languageId: null == languageId ? _self.languageId : languageId // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,oauthProviderId: null == oauthProviderId ? _self.oauthProviderId : oauthProviderId // ignore: cast_nullable_to_non_nullable
as String,google2faSecret: null == google2faSecret ? _self.google2faSecret : google2faSecret // ignore: cast_nullable_to_non_nullable
as bool,verifiedPhoneNumber: null == verifiedPhoneNumber ? _self.verifiedPhoneNumber : verifiedPhoneNumber // ignore: cast_nullable_to_non_nullable
as bool,hasPassword: null == hasPassword ? _self.hasPassword : hasPassword // ignore: cast_nullable_to_non_nullable
as bool,oauthUserToken: null == oauthUserToken ? _self.oauthUserToken : oauthUserToken // ignore: cast_nullable_to_non_nullable
as String,referralCode: null == referralCode ? _self.referralCode : referralCode // ignore: cast_nullable_to_non_nullable
as String,referralMeta: null == referralMeta ? _self.referralMeta : referralMeta // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [UserSummaryApi].
extension UserSummaryApiPatterns on UserSummaryApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserSummaryApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserSummaryApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserSummaryApi value)  $default,){
final _that = this;
switch (_that) {
case _UserSummaryApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserSummaryApi value)?  $default,){
final _that = this;
switch (_that) {
case _UserSummaryApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'first_name')  String firstName, @JsonKey(name: 'last_name')  String lastName, @JsonKey(name: 'email')  String email, @JsonKey(name: 'phone')  String phone, @JsonKey(name: 'signature')  String signature, @JsonKey(name: 'language_id')  String languageId, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'oauth_provider_id')  String oauthProviderId, @JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson)  bool google2faSecret, @JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson)  bool verifiedPhoneNumber, @JsonKey(name: 'has_password', fromJson: _boolFromJson)  bool hasPassword, @JsonKey(name: 'oauth_user_token')  String oauthUserToken, @JsonKey(name: 'referral_code')  String referralCode, @JsonKey(name: 'referral_meta', fromJson: _referralMetaFromJson)  Map<String, int> referralMeta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserSummaryApi() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.signature,_that.languageId,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.oauthProviderId,_that.google2faSecret,_that.verifiedPhoneNumber,_that.hasPassword,_that.oauthUserToken,_that.referralCode,_that.referralMeta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'first_name')  String firstName, @JsonKey(name: 'last_name')  String lastName, @JsonKey(name: 'email')  String email, @JsonKey(name: 'phone')  String phone, @JsonKey(name: 'signature')  String signature, @JsonKey(name: 'language_id')  String languageId, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'oauth_provider_id')  String oauthProviderId, @JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson)  bool google2faSecret, @JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson)  bool verifiedPhoneNumber, @JsonKey(name: 'has_password', fromJson: _boolFromJson)  bool hasPassword, @JsonKey(name: 'oauth_user_token')  String oauthUserToken, @JsonKey(name: 'referral_code')  String referralCode, @JsonKey(name: 'referral_meta', fromJson: _referralMetaFromJson)  Map<String, int> referralMeta)  $default,) {final _that = this;
switch (_that) {
case _UserSummaryApi():
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.signature,_that.languageId,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.oauthProviderId,_that.google2faSecret,_that.verifiedPhoneNumber,_that.hasPassword,_that.oauthUserToken,_that.referralCode,_that.referralMeta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'first_name')  String firstName, @JsonKey(name: 'last_name')  String lastName, @JsonKey(name: 'email')  String email, @JsonKey(name: 'phone')  String phone, @JsonKey(name: 'signature')  String signature, @JsonKey(name: 'language_id')  String languageId, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'oauth_provider_id')  String oauthProviderId, @JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson)  bool google2faSecret, @JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson)  bool verifiedPhoneNumber, @JsonKey(name: 'has_password', fromJson: _boolFromJson)  bool hasPassword, @JsonKey(name: 'oauth_user_token')  String oauthUserToken, @JsonKey(name: 'referral_code')  String referralCode, @JsonKey(name: 'referral_meta', fromJson: _referralMetaFromJson)  Map<String, int> referralMeta)?  $default,) {final _that = this;
switch (_that) {
case _UserSummaryApi() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.signature,_that.languageId,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.oauthProviderId,_that.google2faSecret,_that.verifiedPhoneNumber,_that.hasPassword,_that.oauthUserToken,_that.referralCode,_that.referralMeta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserSummaryApi implements UserSummaryApi {
  const _UserSummaryApi({this.id = '', @JsonKey(name: 'first_name') this.firstName = '', @JsonKey(name: 'last_name') this.lastName = '', @JsonKey(name: 'email') this.email = '', @JsonKey(name: 'phone') this.phone = '', @JsonKey(name: 'signature') this.signature = '', @JsonKey(name: 'language_id') this.languageId = '', @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'oauth_provider_id') this.oauthProviderId = '', @JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson) this.google2faSecret = false, @JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson) this.verifiedPhoneNumber = false, @JsonKey(name: 'has_password', fromJson: _boolFromJson) this.hasPassword = true, @JsonKey(name: 'oauth_user_token') this.oauthUserToken = '', @JsonKey(name: 'referral_code') this.referralCode = '', @JsonKey(name: 'referral_meta', fromJson: _referralMetaFromJson)  Map<String, int> referralMeta = const <String, int>{}}): _referralMeta = referralMeta;
  factory _UserSummaryApi.fromJson(Map<String, dynamic> json) => _$UserSummaryApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'first_name') final  String firstName;
@override@JsonKey(name: 'last_name') final  String lastName;
@override@JsonKey(name: 'email') final  String email;
@override@JsonKey(name: 'phone') final  String phone;
@override@JsonKey(name: 'signature') final  String signature;
@override@JsonKey(name: 'language_id') final  String languageId;
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
@override@JsonKey(name: 'oauth_provider_id') final  String oauthProviderId;
@override@JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson) final  bool google2faSecret;
@override@JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson) final  bool verifiedPhoneNumber;
@override@JsonKey(name: 'has_password', fromJson: _boolFromJson) final  bool hasPassword;
@override@JsonKey(name: 'oauth_user_token') final  String oauthUserToken;
@override@JsonKey(name: 'referral_code') final  String referralCode;
 final  Map<String, int> _referralMeta;
@override@JsonKey(name: 'referral_meta', fromJson: _referralMetaFromJson) Map<String, int> get referralMeta {
  if (_referralMeta is EqualUnmodifiableMapView) return _referralMeta;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_referralMeta);
}


/// Create a copy of UserSummaryApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserSummaryApiCopyWith<_UserSummaryApi> get copyWith => __$UserSummaryApiCopyWithImpl<_UserSummaryApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserSummaryApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserSummaryApi&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.oauthProviderId, oauthProviderId) || other.oauthProviderId == oauthProviderId)&&(identical(other.google2faSecret, google2faSecret) || other.google2faSecret == google2faSecret)&&(identical(other.verifiedPhoneNumber, verifiedPhoneNumber) || other.verifiedPhoneNumber == verifiedPhoneNumber)&&(identical(other.hasPassword, hasPassword) || other.hasPassword == hasPassword)&&(identical(other.oauthUserToken, oauthUserToken) || other.oauthUserToken == oauthUserToken)&&(identical(other.referralCode, referralCode) || other.referralCode == referralCode)&&const DeepCollectionEquality().equals(other.referralMeta, _referralMeta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,firstName,lastName,email,phone,signature,languageId,customValue1,customValue2,customValue3,customValue4,oauthProviderId,google2faSecret,verifiedPhoneNumber,hasPassword,oauthUserToken,referralCode,const DeepCollectionEquality().hash(_referralMeta));
}

@override
String toString() {
    return 'UserSummaryApi(id: $id, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, signature: $signature, languageId: $languageId, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, oauthProviderId: $oauthProviderId, google2faSecret: $google2faSecret, verifiedPhoneNumber: $verifiedPhoneNumber, hasPassword: $hasPassword, oauthUserToken: $oauthUserToken, referralCode: $referralCode, referralMeta: $referralMeta)';
}


}

/// @nodoc
abstract mixin class _$UserSummaryApiCopyWith<$Res> implements $UserSummaryApiCopyWith<$Res> {
  factory _$UserSummaryApiCopyWith(_UserSummaryApi value, $Res Function(_UserSummaryApi) _then) = __$UserSummaryApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'first_name') String firstName,@JsonKey(name: 'last_name') String lastName,@JsonKey(name: 'email') String email,@JsonKey(name: 'phone') String phone,@JsonKey(name: 'signature') String signature,@JsonKey(name: 'language_id') String languageId,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'oauth_provider_id') String oauthProviderId,@JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson) bool google2faSecret,@JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson) bool verifiedPhoneNumber,@JsonKey(name: 'has_password', fromJson: _boolFromJson) bool hasPassword,@JsonKey(name: 'oauth_user_token') String oauthUserToken,@JsonKey(name: 'referral_code') String referralCode,@JsonKey(name: 'referral_meta', fromJson: _referralMetaFromJson) Map<String, int> referralMeta
});




}
/// @nodoc
class __$UserSummaryApiCopyWithImpl<$Res>
    implements _$UserSummaryApiCopyWith<$Res> {
  __$UserSummaryApiCopyWithImpl(this._self, this._then);

  final _UserSummaryApi _self;
  final $Res Function(_UserSummaryApi) _then;

/// Create a copy of UserSummaryApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? signature = null,Object? languageId = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? oauthProviderId = null,Object? google2faSecret = null,Object? verifiedPhoneNumber = null,Object? hasPassword = null,Object? oauthUserToken = null,Object? referralCode = null,Object? referralMeta = null,}) {
  return _then(_UserSummaryApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,signature: null == signature ? _self.signature : signature // ignore: cast_nullable_to_non_nullable
as String,languageId: null == languageId ? _self.languageId : languageId // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,oauthProviderId: null == oauthProviderId ? _self.oauthProviderId : oauthProviderId // ignore: cast_nullable_to_non_nullable
as String,google2faSecret: null == google2faSecret ? _self.google2faSecret : google2faSecret // ignore: cast_nullable_to_non_nullable
as bool,verifiedPhoneNumber: null == verifiedPhoneNumber ? _self.verifiedPhoneNumber : verifiedPhoneNumber // ignore: cast_nullable_to_non_nullable
as bool,hasPassword: null == hasPassword ? _self.hasPassword : hasPassword // ignore: cast_nullable_to_non_nullable
as bool,oauthUserToken: null == oauthUserToken ? _self.oauthUserToken : oauthUserToken // ignore: cast_nullable_to_non_nullable
as String,referralCode: null == referralCode ? _self.referralCode : referralCode // ignore: cast_nullable_to_non_nullable
as String,referralMeta: null == referralMeta ? _self._referralMeta : referralMeta // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}


}


/// @nodoc
mixin _$CompanyEnvelopeApi {

 String get id;@JsonKey(name: 'display_name') String get displayName; String get name;@JsonKey(name: 'company_key') String get companyKey;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'subdomain') String get subdomain;@JsonKey(name: 'portal_domain') String get portalDomain;@JsonKey(name: 'portal_mode') String get portalMode;@JsonKey(name: 'client_can_register') bool get clientCanRegister;@JsonKey(name: 'client_registration_fields', fromJson: _clientRegistrationFieldListData) List<ClientRegistrationFieldApi> get clientRegistrationFields;@JsonKey(name: 'custom_fields') Map<String, String> get customFields;@JsonKey(name: 'documents', fromJson: _companyDocumentListData) List<DocumentApi> get documents;@JsonKey(name: 'size_id') String get sizeId;@JsonKey(name: 'industry_id') String get industryId;@JsonKey(name: 'first_month_of_year') String get firstMonthOfYear;@JsonKey(name: 'first_day_of_week') String get firstDayOfWeek;@JsonKey(name: 'use_comma_as_decimal_place') bool get useCommaAsDecimalPlace;@JsonKey(name: 'legal_entity_id') int get legalEntityId;@JsonKey(name: 'enabled_modules') int get enabledModules; Map<String, dynamic> get settings;@JsonKey(name: 'users', fromJson: _bundledUserListData) List<UserApi> get users;@JsonKey(name: 'task_statuses', fromJson: _taskStatusListData) List<TaskStatusApi> get taskStatuses;@JsonKey(name: 'company_gateways', fromJson: _companyGatewayListData) List<CompanyGatewayApi> get companyGateways;@JsonKey(name: 'payment_terms', fromJson: _paymentTermListData) List<PaymentTermApi> get paymentTerms;@JsonKey(name: 'tax_rates', fromJson: _taxRateListData) List<TaxRateApi> get taxRates;@JsonKey(name: 'expense_categories', fromJson: _expenseCategoryListData) List<ExpenseCategoryApi> get expenseCategories;@JsonKey(name: 'groups', fromJson: _groupSettingListData) List<GroupSettingApi> get groups;@JsonKey(name: 'bank_transaction_rules', fromJson: _transactionRuleListData) List<TransactionRuleApi> get bankTransactionRules;@JsonKey(name: 'bank_integrations', fromJson: _bankIntegrationListData) List<BankAccountApi> get bankIntegrations;@JsonKey(name: 'webhooks', fromJson: _webhookListData) List<WebhookApi> get webhooks;@JsonKey(name: 'tokens_hashed', fromJson: _tokenListData) List<TokenApi> get tokensHashed;@JsonKey(name: 'task_schedulers', fromJson: _taskSchedulerListData) List<ScheduleApi> get taskSchedulers;@JsonKey(name: 'subscriptions', fromJson: _subscriptionListData) List<SubscriptionApi> get subscriptions;@JsonKey(name: 'designs', fromJson: _designListData) List<DesignApi> get designs;@JsonKey(name: 'clients', fromJson: _clientDeltaListData) List<ClientApi> get clients;@JsonKey(name: 'products', fromJson: _productDeltaListData) List<ProductApi> get products;@JsonKey(name: 'invoices', fromJson: _invoiceDeltaListData) List<InvoiceApi> get invoices;@JsonKey(name: 'recurring_invoices', fromJson: _recurringInvoiceDeltaListData) List<RecurringInvoiceApi> get recurringInvoices;@JsonKey(name: 'quotes', fromJson: _quoteDeltaListData) List<QuoteApi> get quotes;@JsonKey(name: 'credits', fromJson: _creditDeltaListData) List<CreditApi> get credits;@JsonKey(name: 'payments', fromJson: _paymentDeltaListData) List<PaymentApi> get payments;@JsonKey(name: 'tasks', fromJson: _taskDeltaListData) List<TaskApi> get tasks;@JsonKey(name: 'projects', fromJson: _projectDeltaListData) List<ProjectApi> get projects;@JsonKey(name: 'expenses', fromJson: _expenseDeltaListData) List<ExpenseApi> get expenses;@JsonKey(name: 'recurring_expenses', fromJson: _recurringExpenseDeltaListData) List<RecurringExpenseApi> get recurringExpenses;@JsonKey(name: 'vendors', fromJson: _vendorDeltaListData) List<VendorApi> get vendors;@JsonKey(name: 'purchase_orders', fromJson: _purchaseOrderDeltaListData) List<PurchaseOrderApi> get purchaseOrders;@JsonKey(name: 'bank_transactions', fromJson: _bankTransactionDeltaListData) List<BankTransactionApi> get bankTransactions;@JsonKey(name: 'enabled_tax_rates') int get enabledTaxRates;@JsonKey(name: 'enabled_item_tax_rates') int get enabledItemTaxRates;@JsonKey(name: 'enabled_expense_tax_rates') int get enabledExpenseTaxRates;@JsonKey(name: 'calculate_taxes') bool get calculateTaxes;@JsonKey(name: 'tax_data') TaxConfigApi? get taxData;@JsonKey(name: 'e_invoice', includeIfNull: false) Map<String, dynamic>? get eInvoice;@JsonKey(name: 'custom_surcharge_taxes1') bool get customSurchargeTaxes1;@JsonKey(name: 'custom_surcharge_taxes2') bool get customSurchargeTaxes2;@JsonKey(name: 'custom_surcharge_taxes3') bool get customSurchargeTaxes3;@JsonKey(name: 'custom_surcharge_taxes4') bool get customSurchargeTaxes4;@JsonKey(name: 'track_inventory') bool get trackInventory;@JsonKey(name: 'stock_notification') bool get stockNotification;@JsonKey(name: 'inventory_notification_threshold') int get inventoryNotificationThreshold;@JsonKey(name: 'enable_product_discount') bool get enableProductDiscount;@JsonKey(name: 'enable_product_cost') bool get enableProductCost;@JsonKey(name: 'enable_product_quantity') bool get enableProductQuantity;@JsonKey(name: 'default_quantity') bool get defaultQuantity;@JsonKey(name: 'show_product_details') bool get showProductDetails;@JsonKey(name: 'fill_products') bool get fillProducts;@JsonKey(name: 'update_products') bool get updateProducts;@JsonKey(name: 'convert_products') bool get convertProducts;@JsonKey(name: 'convert_rate_to_client') bool get convertRateToClient;@JsonKey(name: 'stop_on_unpaid_recurring') bool get stopOnUnpaidRecurring;@JsonKey(name: 'use_quote_terms_on_conversion') bool get useQuoteTermsOnConversion;@JsonKey(name: 'google_analytics_key') String get googleAnalyticsKey;@JsonKey(name: 'matomo_id') String get matomoId;@JsonKey(name: 'matomo_url') String get matomoUrl;@JsonKey(name: 'session_timeout') int get sessionTimeout;@JsonKey(name: 'default_password_timeout') int get defaultPasswordTimeout;@JsonKey(name: 'oauth_password_required') bool get oauthPasswordRequired;@JsonKey(name: 'is_disabled') bool get isDisabled;@JsonKey(name: 'markdown_enabled') bool get markdownEnabled;@JsonKey(name: 'markdown_email_enabled') bool get markdownEmailEnabled;@JsonKey(name: 'report_include_drafts') bool get reportIncludeDrafts;@JsonKey(name: 'report_include_deleted') bool get reportIncludeDeleted;@JsonKey(name: 'quickbooks') Map<String, dynamic>? get quickbooks;@JsonKey(name: 'smtp_host') String get smtpHost;@JsonKey(name: 'smtp_port') int get smtpPort;@JsonKey(name: 'smtp_encryption') String get smtpEncryption;@JsonKey(name: 'smtp_username') String get smtpUsername;@JsonKey(name: 'smtp_password') String get smtpPassword;@JsonKey(name: 'smtp_local_domain') String get smtpLocalDomain;@JsonKey(name: 'smtp_verify_peer') bool get smtpVerifyPeer;@JsonKey(name: 'expense_mailbox') String get expenseMailbox;@JsonKey(name: 'expense_mailbox_active') bool get expenseMailboxActive;@JsonKey(name: 'inbound_mailbox_allow_company_users') bool get inboundMailboxAllowCompanyUsers;@JsonKey(name: 'inbound_mailbox_allow_vendors') bool get inboundMailboxAllowVendors;@JsonKey(name: 'inbound_mailbox_allow_clients') bool get inboundMailboxAllowClients;@JsonKey(name: 'inbound_mailbox_allow_unknown') bool get inboundMailboxAllowUnknown;@JsonKey(name: 'inbound_mailbox_whitelist') String get inboundMailboxWhitelist;@JsonKey(name: 'inbound_mailbox_blacklist') String get inboundMailboxBlacklist;@JsonKey(name: 'expense_inclusive_taxes') bool get expenseInclusiveTaxes;@JsonKey(name: 'calculate_expense_tax_by_amount') bool get calculateExpenseTaxByAmount;@JsonKey(name: 'auto_start_tasks') bool get autoStartTasks;@JsonKey(name: 'show_task_end_date') bool get showTaskEndDate;@JsonKey(name: 'show_tasks_table') bool get showTasksTable;@JsonKey(name: 'invoice_task_datelog') bool get invoiceTaskDatelog;@JsonKey(name: 'invoice_task_timelog') bool get invoiceTaskTimelog;@JsonKey(name: 'invoice_task_hours') bool get invoiceTaskHours;@JsonKey(name: 'invoice_task_item_description') bool get invoiceTaskItemDescription;@JsonKey(name: 'invoice_task_project') bool get invoiceTaskProject;@JsonKey(name: 'invoice_task_project_header') bool get invoiceTaskProjectHeader;@JsonKey(name: 'invoice_task_lock') bool get invoiceTaskLock;@JsonKey(name: 'invoice_task_documents') bool get invoiceTaskDocuments;@JsonKey(name: 'mark_expenses_invoiceable') bool get markExpensesInvoiceable;@JsonKey(name: 'mark_expenses_paid') bool get markExpensesPaid;@JsonKey(name: 'invoice_expense_documents') bool get invoiceExpenseDocuments;@JsonKey(name: 'notify_vendor_when_paid') bool get notifyVendorWhenPaid;@JsonKey(name: 'enable_applying_payments') bool get enableApplyingPayments;@JsonKey(name: 'convert_payment_currency') bool get convertPaymentCurrency;@JsonKey(name: 'convert_expense_currency') bool get convertExpenseCurrency;@JsonKey(name: 'has_e_invoice_certificate') bool get hasEInvoiceCertificate;@JsonKey(name: 'has_e_invoice_certificate_passphrase') bool get hasEInvoiceCertificatePassphrase;
/// Create a copy of CompanyEnvelopeApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyEnvelopeApiCopyWith<CompanyEnvelopeApi> get copyWith => _$CompanyEnvelopeApiCopyWithImpl<CompanyEnvelopeApi>(this as CompanyEnvelopeApi, _$identity);

  /// Serializes this CompanyEnvelopeApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CompanyEnvelopeApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanyEnvelopeApi&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.displayName, _this.displayName) || other.displayName == _this.displayName)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.companyKey, _this.companyKey) || other.companyKey == _this.companyKey)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.subdomain, _this.subdomain) || other.subdomain == _this.subdomain)&&(identical(other.portalDomain, _this.portalDomain) || other.portalDomain == _this.portalDomain)&&(identical(other.portalMode, _this.portalMode) || other.portalMode == _this.portalMode)&&(identical(other.clientCanRegister, _this.clientCanRegister) || other.clientCanRegister == _this.clientCanRegister)&&const DeepCollectionEquality().equals(other.clientRegistrationFields, _this.clientRegistrationFields)&&const DeepCollectionEquality().equals(other.customFields, _this.customFields)&&const DeepCollectionEquality().equals(other.documents, _this.documents)&&(identical(other.sizeId, _this.sizeId) || other.sizeId == _this.sizeId)&&(identical(other.industryId, _this.industryId) || other.industryId == _this.industryId)&&(identical(other.firstMonthOfYear, _this.firstMonthOfYear) || other.firstMonthOfYear == _this.firstMonthOfYear)&&(identical(other.firstDayOfWeek, _this.firstDayOfWeek) || other.firstDayOfWeek == _this.firstDayOfWeek)&&(identical(other.useCommaAsDecimalPlace, _this.useCommaAsDecimalPlace) || other.useCommaAsDecimalPlace == _this.useCommaAsDecimalPlace)&&(identical(other.legalEntityId, _this.legalEntityId) || other.legalEntityId == _this.legalEntityId)&&(identical(other.enabledModules, _this.enabledModules) || other.enabledModules == _this.enabledModules)&&const DeepCollectionEquality().equals(other.settings, _this.settings)&&const DeepCollectionEquality().equals(other.users, _this.users)&&const DeepCollectionEquality().equals(other.taskStatuses, _this.taskStatuses)&&const DeepCollectionEquality().equals(other.companyGateways, _this.companyGateways)&&const DeepCollectionEquality().equals(other.paymentTerms, _this.paymentTerms)&&const DeepCollectionEquality().equals(other.taxRates, _this.taxRates)&&const DeepCollectionEquality().equals(other.expenseCategories, _this.expenseCategories)&&const DeepCollectionEquality().equals(other.groups, _this.groups)&&const DeepCollectionEquality().equals(other.bankTransactionRules, _this.bankTransactionRules)&&const DeepCollectionEquality().equals(other.bankIntegrations, _this.bankIntegrations)&&const DeepCollectionEquality().equals(other.webhooks, _this.webhooks)&&const DeepCollectionEquality().equals(other.tokensHashed, _this.tokensHashed)&&const DeepCollectionEquality().equals(other.taskSchedulers, _this.taskSchedulers)&&const DeepCollectionEquality().equals(other.subscriptions, _this.subscriptions)&&const DeepCollectionEquality().equals(other.designs, _this.designs)&&const DeepCollectionEquality().equals(other.clients, _this.clients)&&const DeepCollectionEquality().equals(other.products, _this.products)&&const DeepCollectionEquality().equals(other.invoices, _this.invoices)&&const DeepCollectionEquality().equals(other.recurringInvoices, _this.recurringInvoices)&&const DeepCollectionEquality().equals(other.quotes, _this.quotes)&&const DeepCollectionEquality().equals(other.credits, _this.credits)&&const DeepCollectionEquality().equals(other.payments, _this.payments)&&const DeepCollectionEquality().equals(other.tasks, _this.tasks)&&const DeepCollectionEquality().equals(other.projects, _this.projects)&&const DeepCollectionEquality().equals(other.expenses, _this.expenses)&&const DeepCollectionEquality().equals(other.recurringExpenses, _this.recurringExpenses)&&const DeepCollectionEquality().equals(other.vendors, _this.vendors)&&const DeepCollectionEquality().equals(other.purchaseOrders, _this.purchaseOrders)&&const DeepCollectionEquality().equals(other.bankTransactions, _this.bankTransactions)&&(identical(other.enabledTaxRates, _this.enabledTaxRates) || other.enabledTaxRates == _this.enabledTaxRates)&&(identical(other.enabledItemTaxRates, _this.enabledItemTaxRates) || other.enabledItemTaxRates == _this.enabledItemTaxRates)&&(identical(other.enabledExpenseTaxRates, _this.enabledExpenseTaxRates) || other.enabledExpenseTaxRates == _this.enabledExpenseTaxRates)&&(identical(other.calculateTaxes, _this.calculateTaxes) || other.calculateTaxes == _this.calculateTaxes)&&(identical(other.taxData, _this.taxData) || other.taxData == _this.taxData)&&const DeepCollectionEquality().equals(other.eInvoice, _this.eInvoice)&&(identical(other.customSurchargeTaxes1, _this.customSurchargeTaxes1) || other.customSurchargeTaxes1 == _this.customSurchargeTaxes1)&&(identical(other.customSurchargeTaxes2, _this.customSurchargeTaxes2) || other.customSurchargeTaxes2 == _this.customSurchargeTaxes2)&&(identical(other.customSurchargeTaxes3, _this.customSurchargeTaxes3) || other.customSurchargeTaxes3 == _this.customSurchargeTaxes3)&&(identical(other.customSurchargeTaxes4, _this.customSurchargeTaxes4) || other.customSurchargeTaxes4 == _this.customSurchargeTaxes4)&&(identical(other.trackInventory, _this.trackInventory) || other.trackInventory == _this.trackInventory)&&(identical(other.stockNotification, _this.stockNotification) || other.stockNotification == _this.stockNotification)&&(identical(other.inventoryNotificationThreshold, _this.inventoryNotificationThreshold) || other.inventoryNotificationThreshold == _this.inventoryNotificationThreshold)&&(identical(other.enableProductDiscount, _this.enableProductDiscount) || other.enableProductDiscount == _this.enableProductDiscount)&&(identical(other.enableProductCost, _this.enableProductCost) || other.enableProductCost == _this.enableProductCost)&&(identical(other.enableProductQuantity, _this.enableProductQuantity) || other.enableProductQuantity == _this.enableProductQuantity)&&(identical(other.defaultQuantity, _this.defaultQuantity) || other.defaultQuantity == _this.defaultQuantity)&&(identical(other.showProductDetails, _this.showProductDetails) || other.showProductDetails == _this.showProductDetails)&&(identical(other.fillProducts, _this.fillProducts) || other.fillProducts == _this.fillProducts)&&(identical(other.updateProducts, _this.updateProducts) || other.updateProducts == _this.updateProducts)&&(identical(other.convertProducts, _this.convertProducts) || other.convertProducts == _this.convertProducts)&&(identical(other.convertRateToClient, _this.convertRateToClient) || other.convertRateToClient == _this.convertRateToClient)&&(identical(other.stopOnUnpaidRecurring, _this.stopOnUnpaidRecurring) || other.stopOnUnpaidRecurring == _this.stopOnUnpaidRecurring)&&(identical(other.useQuoteTermsOnConversion, _this.useQuoteTermsOnConversion) || other.useQuoteTermsOnConversion == _this.useQuoteTermsOnConversion)&&(identical(other.googleAnalyticsKey, _this.googleAnalyticsKey) || other.googleAnalyticsKey == _this.googleAnalyticsKey)&&(identical(other.matomoId, _this.matomoId) || other.matomoId == _this.matomoId)&&(identical(other.matomoUrl, _this.matomoUrl) || other.matomoUrl == _this.matomoUrl)&&(identical(other.sessionTimeout, _this.sessionTimeout) || other.sessionTimeout == _this.sessionTimeout)&&(identical(other.defaultPasswordTimeout, _this.defaultPasswordTimeout) || other.defaultPasswordTimeout == _this.defaultPasswordTimeout)&&(identical(other.oauthPasswordRequired, _this.oauthPasswordRequired) || other.oauthPasswordRequired == _this.oauthPasswordRequired)&&(identical(other.isDisabled, _this.isDisabled) || other.isDisabled == _this.isDisabled)&&(identical(other.markdownEnabled, _this.markdownEnabled) || other.markdownEnabled == _this.markdownEnabled)&&(identical(other.markdownEmailEnabled, _this.markdownEmailEnabled) || other.markdownEmailEnabled == _this.markdownEmailEnabled)&&(identical(other.reportIncludeDrafts, _this.reportIncludeDrafts) || other.reportIncludeDrafts == _this.reportIncludeDrafts)&&(identical(other.reportIncludeDeleted, _this.reportIncludeDeleted) || other.reportIncludeDeleted == _this.reportIncludeDeleted)&&const DeepCollectionEquality().equals(other.quickbooks, _this.quickbooks)&&(identical(other.smtpHost, _this.smtpHost) || other.smtpHost == _this.smtpHost)&&(identical(other.smtpPort, _this.smtpPort) || other.smtpPort == _this.smtpPort)&&(identical(other.smtpEncryption, _this.smtpEncryption) || other.smtpEncryption == _this.smtpEncryption)&&(identical(other.smtpUsername, _this.smtpUsername) || other.smtpUsername == _this.smtpUsername)&&(identical(other.smtpPassword, _this.smtpPassword) || other.smtpPassword == _this.smtpPassword)&&(identical(other.smtpLocalDomain, _this.smtpLocalDomain) || other.smtpLocalDomain == _this.smtpLocalDomain)&&(identical(other.smtpVerifyPeer, _this.smtpVerifyPeer) || other.smtpVerifyPeer == _this.smtpVerifyPeer)&&(identical(other.expenseMailbox, _this.expenseMailbox) || other.expenseMailbox == _this.expenseMailbox)&&(identical(other.expenseMailboxActive, _this.expenseMailboxActive) || other.expenseMailboxActive == _this.expenseMailboxActive)&&(identical(other.inboundMailboxAllowCompanyUsers, _this.inboundMailboxAllowCompanyUsers) || other.inboundMailboxAllowCompanyUsers == _this.inboundMailboxAllowCompanyUsers)&&(identical(other.inboundMailboxAllowVendors, _this.inboundMailboxAllowVendors) || other.inboundMailboxAllowVendors == _this.inboundMailboxAllowVendors)&&(identical(other.inboundMailboxAllowClients, _this.inboundMailboxAllowClients) || other.inboundMailboxAllowClients == _this.inboundMailboxAllowClients)&&(identical(other.inboundMailboxAllowUnknown, _this.inboundMailboxAllowUnknown) || other.inboundMailboxAllowUnknown == _this.inboundMailboxAllowUnknown)&&(identical(other.inboundMailboxWhitelist, _this.inboundMailboxWhitelist) || other.inboundMailboxWhitelist == _this.inboundMailboxWhitelist)&&(identical(other.inboundMailboxBlacklist, _this.inboundMailboxBlacklist) || other.inboundMailboxBlacklist == _this.inboundMailboxBlacklist)&&(identical(other.expenseInclusiveTaxes, _this.expenseInclusiveTaxes) || other.expenseInclusiveTaxes == _this.expenseInclusiveTaxes)&&(identical(other.calculateExpenseTaxByAmount, _this.calculateExpenseTaxByAmount) || other.calculateExpenseTaxByAmount == _this.calculateExpenseTaxByAmount)&&(identical(other.autoStartTasks, _this.autoStartTasks) || other.autoStartTasks == _this.autoStartTasks)&&(identical(other.showTaskEndDate, _this.showTaskEndDate) || other.showTaskEndDate == _this.showTaskEndDate)&&(identical(other.showTasksTable, _this.showTasksTable) || other.showTasksTable == _this.showTasksTable)&&(identical(other.invoiceTaskDatelog, _this.invoiceTaskDatelog) || other.invoiceTaskDatelog == _this.invoiceTaskDatelog)&&(identical(other.invoiceTaskTimelog, _this.invoiceTaskTimelog) || other.invoiceTaskTimelog == _this.invoiceTaskTimelog)&&(identical(other.invoiceTaskHours, _this.invoiceTaskHours) || other.invoiceTaskHours == _this.invoiceTaskHours)&&(identical(other.invoiceTaskItemDescription, _this.invoiceTaskItemDescription) || other.invoiceTaskItemDescription == _this.invoiceTaskItemDescription)&&(identical(other.invoiceTaskProject, _this.invoiceTaskProject) || other.invoiceTaskProject == _this.invoiceTaskProject)&&(identical(other.invoiceTaskProjectHeader, _this.invoiceTaskProjectHeader) || other.invoiceTaskProjectHeader == _this.invoiceTaskProjectHeader)&&(identical(other.invoiceTaskLock, _this.invoiceTaskLock) || other.invoiceTaskLock == _this.invoiceTaskLock)&&(identical(other.invoiceTaskDocuments, _this.invoiceTaskDocuments) || other.invoiceTaskDocuments == _this.invoiceTaskDocuments)&&(identical(other.markExpensesInvoiceable, _this.markExpensesInvoiceable) || other.markExpensesInvoiceable == _this.markExpensesInvoiceable)&&(identical(other.markExpensesPaid, _this.markExpensesPaid) || other.markExpensesPaid == _this.markExpensesPaid)&&(identical(other.invoiceExpenseDocuments, _this.invoiceExpenseDocuments) || other.invoiceExpenseDocuments == _this.invoiceExpenseDocuments)&&(identical(other.notifyVendorWhenPaid, _this.notifyVendorWhenPaid) || other.notifyVendorWhenPaid == _this.notifyVendorWhenPaid)&&(identical(other.enableApplyingPayments, _this.enableApplyingPayments) || other.enableApplyingPayments == _this.enableApplyingPayments)&&(identical(other.convertPaymentCurrency, _this.convertPaymentCurrency) || other.convertPaymentCurrency == _this.convertPaymentCurrency)&&(identical(other.convertExpenseCurrency, _this.convertExpenseCurrency) || other.convertExpenseCurrency == _this.convertExpenseCurrency)&&(identical(other.hasEInvoiceCertificate, _this.hasEInvoiceCertificate) || other.hasEInvoiceCertificate == _this.hasEInvoiceCertificate)&&(identical(other.hasEInvoiceCertificatePassphrase, _this.hasEInvoiceCertificatePassphrase) || other.hasEInvoiceCertificatePassphrase == _this.hasEInvoiceCertificatePassphrase));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CompanyEnvelopeApi;
  return Object.hashAll([runtimeType,_this.id,_this.displayName,_this.name,_this.companyKey,_this.updatedAt,_this.subdomain,_this.portalDomain,_this.portalMode,_this.clientCanRegister,const DeepCollectionEquality().hash(_this.clientRegistrationFields),const DeepCollectionEquality().hash(_this.customFields),const DeepCollectionEquality().hash(_this.documents),_this.sizeId,_this.industryId,_this.firstMonthOfYear,_this.firstDayOfWeek,_this.useCommaAsDecimalPlace,_this.legalEntityId,_this.enabledModules,const DeepCollectionEquality().hash(_this.settings),const DeepCollectionEquality().hash(_this.users),const DeepCollectionEquality().hash(_this.taskStatuses),const DeepCollectionEquality().hash(_this.companyGateways),const DeepCollectionEquality().hash(_this.paymentTerms),const DeepCollectionEquality().hash(_this.taxRates),const DeepCollectionEquality().hash(_this.expenseCategories),const DeepCollectionEquality().hash(_this.groups),const DeepCollectionEquality().hash(_this.bankTransactionRules),const DeepCollectionEquality().hash(_this.bankIntegrations),const DeepCollectionEquality().hash(_this.webhooks),const DeepCollectionEquality().hash(_this.tokensHashed),const DeepCollectionEquality().hash(_this.taskSchedulers),const DeepCollectionEquality().hash(_this.subscriptions),const DeepCollectionEquality().hash(_this.designs),const DeepCollectionEquality().hash(_this.clients),const DeepCollectionEquality().hash(_this.products),const DeepCollectionEquality().hash(_this.invoices),const DeepCollectionEquality().hash(_this.recurringInvoices),const DeepCollectionEquality().hash(_this.quotes),const DeepCollectionEquality().hash(_this.credits),const DeepCollectionEquality().hash(_this.payments),const DeepCollectionEquality().hash(_this.tasks),const DeepCollectionEquality().hash(_this.projects),const DeepCollectionEquality().hash(_this.expenses),const DeepCollectionEquality().hash(_this.recurringExpenses),const DeepCollectionEquality().hash(_this.vendors),const DeepCollectionEquality().hash(_this.purchaseOrders),const DeepCollectionEquality().hash(_this.bankTransactions),_this.enabledTaxRates,_this.enabledItemTaxRates,_this.enabledExpenseTaxRates,_this.calculateTaxes,_this.taxData,const DeepCollectionEquality().hash(_this.eInvoice),_this.customSurchargeTaxes1,_this.customSurchargeTaxes2,_this.customSurchargeTaxes3,_this.customSurchargeTaxes4,_this.trackInventory,_this.stockNotification,_this.inventoryNotificationThreshold,_this.enableProductDiscount,_this.enableProductCost,_this.enableProductQuantity,_this.defaultQuantity,_this.showProductDetails,_this.fillProducts,_this.updateProducts,_this.convertProducts,_this.convertRateToClient,_this.stopOnUnpaidRecurring,_this.useQuoteTermsOnConversion,_this.googleAnalyticsKey,_this.matomoId,_this.matomoUrl,_this.sessionTimeout,_this.defaultPasswordTimeout,_this.oauthPasswordRequired,_this.isDisabled,_this.markdownEnabled,_this.markdownEmailEnabled,_this.reportIncludeDrafts,_this.reportIncludeDeleted,const DeepCollectionEquality().hash(_this.quickbooks),_this.smtpHost,_this.smtpPort,_this.smtpEncryption,_this.smtpUsername,_this.smtpPassword,_this.smtpLocalDomain,_this.smtpVerifyPeer,_this.expenseMailbox,_this.expenseMailboxActive,_this.inboundMailboxAllowCompanyUsers,_this.inboundMailboxAllowVendors,_this.inboundMailboxAllowClients,_this.inboundMailboxAllowUnknown,_this.inboundMailboxWhitelist,_this.inboundMailboxBlacklist,_this.expenseInclusiveTaxes,_this.calculateExpenseTaxByAmount,_this.autoStartTasks,_this.showTaskEndDate,_this.showTasksTable,_this.invoiceTaskDatelog,_this.invoiceTaskTimelog,_this.invoiceTaskHours,_this.invoiceTaskItemDescription,_this.invoiceTaskProject,_this.invoiceTaskProjectHeader,_this.invoiceTaskLock,_this.invoiceTaskDocuments,_this.markExpensesInvoiceable,_this.markExpensesPaid,_this.invoiceExpenseDocuments,_this.notifyVendorWhenPaid,_this.enableApplyingPayments,_this.convertPaymentCurrency,_this.convertExpenseCurrency,_this.hasEInvoiceCertificate,_this.hasEInvoiceCertificatePassphrase]);
}

@override
String toString() {
  final _this = this as CompanyEnvelopeApi;
  return 'CompanyEnvelopeApi(id: ${_this.id}, displayName: ${_this.displayName}, name: ${_this.name}, companyKey: ${_this.companyKey}, updatedAt: ${_this.updatedAt}, subdomain: ${_this.subdomain}, portalDomain: ${_this.portalDomain}, portalMode: ${_this.portalMode}, clientCanRegister: ${_this.clientCanRegister}, clientRegistrationFields: ${_this.clientRegistrationFields}, customFields: ${_this.customFields}, documents: ${_this.documents}, sizeId: ${_this.sizeId}, industryId: ${_this.industryId}, firstMonthOfYear: ${_this.firstMonthOfYear}, firstDayOfWeek: ${_this.firstDayOfWeek}, useCommaAsDecimalPlace: ${_this.useCommaAsDecimalPlace}, legalEntityId: ${_this.legalEntityId}, enabledModules: ${_this.enabledModules}, settings: ${_this.settings}, users: ${_this.users}, taskStatuses: ${_this.taskStatuses}, companyGateways: ${_this.companyGateways}, paymentTerms: ${_this.paymentTerms}, taxRates: ${_this.taxRates}, expenseCategories: ${_this.expenseCategories}, groups: ${_this.groups}, bankTransactionRules: ${_this.bankTransactionRules}, bankIntegrations: ${_this.bankIntegrations}, webhooks: ${_this.webhooks}, tokensHashed: ${_this.tokensHashed}, taskSchedulers: ${_this.taskSchedulers}, subscriptions: ${_this.subscriptions}, designs: ${_this.designs}, clients: ${_this.clients}, products: ${_this.products}, invoices: ${_this.invoices}, recurringInvoices: ${_this.recurringInvoices}, quotes: ${_this.quotes}, credits: ${_this.credits}, payments: ${_this.payments}, tasks: ${_this.tasks}, projects: ${_this.projects}, expenses: ${_this.expenses}, recurringExpenses: ${_this.recurringExpenses}, vendors: ${_this.vendors}, purchaseOrders: ${_this.purchaseOrders}, bankTransactions: ${_this.bankTransactions}, enabledTaxRates: ${_this.enabledTaxRates}, enabledItemTaxRates: ${_this.enabledItemTaxRates}, enabledExpenseTaxRates: ${_this.enabledExpenseTaxRates}, calculateTaxes: ${_this.calculateTaxes}, taxData: ${_this.taxData}, eInvoice: ${_this.eInvoice}, customSurchargeTaxes1: ${_this.customSurchargeTaxes1}, customSurchargeTaxes2: ${_this.customSurchargeTaxes2}, customSurchargeTaxes3: ${_this.customSurchargeTaxes3}, customSurchargeTaxes4: ${_this.customSurchargeTaxes4}, trackInventory: ${_this.trackInventory}, stockNotification: ${_this.stockNotification}, inventoryNotificationThreshold: ${_this.inventoryNotificationThreshold}, enableProductDiscount: ${_this.enableProductDiscount}, enableProductCost: ${_this.enableProductCost}, enableProductQuantity: ${_this.enableProductQuantity}, defaultQuantity: ${_this.defaultQuantity}, showProductDetails: ${_this.showProductDetails}, fillProducts: ${_this.fillProducts}, updateProducts: ${_this.updateProducts}, convertProducts: ${_this.convertProducts}, convertRateToClient: ${_this.convertRateToClient}, stopOnUnpaidRecurring: ${_this.stopOnUnpaidRecurring}, useQuoteTermsOnConversion: ${_this.useQuoteTermsOnConversion}, googleAnalyticsKey: ${_this.googleAnalyticsKey}, matomoId: ${_this.matomoId}, matomoUrl: ${_this.matomoUrl}, sessionTimeout: ${_this.sessionTimeout}, defaultPasswordTimeout: ${_this.defaultPasswordTimeout}, oauthPasswordRequired: ${_this.oauthPasswordRequired}, isDisabled: ${_this.isDisabled}, markdownEnabled: ${_this.markdownEnabled}, markdownEmailEnabled: ${_this.markdownEmailEnabled}, reportIncludeDrafts: ${_this.reportIncludeDrafts}, reportIncludeDeleted: ${_this.reportIncludeDeleted}, quickbooks: ${_this.quickbooks}, smtpHost: ${_this.smtpHost}, smtpPort: ${_this.smtpPort}, smtpEncryption: ${_this.smtpEncryption}, smtpUsername: ${_this.smtpUsername}, smtpPassword: ${_this.smtpPassword}, smtpLocalDomain: ${_this.smtpLocalDomain}, smtpVerifyPeer: ${_this.smtpVerifyPeer}, expenseMailbox: ${_this.expenseMailbox}, expenseMailboxActive: ${_this.expenseMailboxActive}, inboundMailboxAllowCompanyUsers: ${_this.inboundMailboxAllowCompanyUsers}, inboundMailboxAllowVendors: ${_this.inboundMailboxAllowVendors}, inboundMailboxAllowClients: ${_this.inboundMailboxAllowClients}, inboundMailboxAllowUnknown: ${_this.inboundMailboxAllowUnknown}, inboundMailboxWhitelist: ${_this.inboundMailboxWhitelist}, inboundMailboxBlacklist: ${_this.inboundMailboxBlacklist}, expenseInclusiveTaxes: ${_this.expenseInclusiveTaxes}, calculateExpenseTaxByAmount: ${_this.calculateExpenseTaxByAmount}, autoStartTasks: ${_this.autoStartTasks}, showTaskEndDate: ${_this.showTaskEndDate}, showTasksTable: ${_this.showTasksTable}, invoiceTaskDatelog: ${_this.invoiceTaskDatelog}, invoiceTaskTimelog: ${_this.invoiceTaskTimelog}, invoiceTaskHours: ${_this.invoiceTaskHours}, invoiceTaskItemDescription: ${_this.invoiceTaskItemDescription}, invoiceTaskProject: ${_this.invoiceTaskProject}, invoiceTaskProjectHeader: ${_this.invoiceTaskProjectHeader}, invoiceTaskLock: ${_this.invoiceTaskLock}, invoiceTaskDocuments: ${_this.invoiceTaskDocuments}, markExpensesInvoiceable: ${_this.markExpensesInvoiceable}, markExpensesPaid: ${_this.markExpensesPaid}, invoiceExpenseDocuments: ${_this.invoiceExpenseDocuments}, notifyVendorWhenPaid: ${_this.notifyVendorWhenPaid}, enableApplyingPayments: ${_this.enableApplyingPayments}, convertPaymentCurrency: ${_this.convertPaymentCurrency}, convertExpenseCurrency: ${_this.convertExpenseCurrency}, hasEInvoiceCertificate: ${_this.hasEInvoiceCertificate}, hasEInvoiceCertificatePassphrase: ${_this.hasEInvoiceCertificatePassphrase})';
}


}

/// @nodoc
abstract mixin class $CompanyEnvelopeApiCopyWith<$Res>  {
  factory $CompanyEnvelopeApiCopyWith(CompanyEnvelopeApi value, $Res Function(CompanyEnvelopeApi) _then) = _$CompanyEnvelopeApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'display_name') String displayName, String name,@JsonKey(name: 'company_key') String companyKey,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'subdomain') String subdomain,@JsonKey(name: 'portal_domain') String portalDomain,@JsonKey(name: 'portal_mode') String portalMode,@JsonKey(name: 'client_can_register') bool clientCanRegister,@JsonKey(name: 'client_registration_fields', fromJson: _clientRegistrationFieldListData) List<ClientRegistrationFieldApi> clientRegistrationFields,@JsonKey(name: 'custom_fields') Map<String, String> customFields,@JsonKey(name: 'documents', fromJson: _companyDocumentListData) List<DocumentApi> documents,@JsonKey(name: 'size_id') String sizeId,@JsonKey(name: 'industry_id') String industryId,@JsonKey(name: 'first_month_of_year') String firstMonthOfYear,@JsonKey(name: 'first_day_of_week') String firstDayOfWeek,@JsonKey(name: 'use_comma_as_decimal_place') bool useCommaAsDecimalPlace,@JsonKey(name: 'legal_entity_id') int legalEntityId,@JsonKey(name: 'enabled_modules') int enabledModules, Map<String, dynamic> settings,@JsonKey(name: 'users', fromJson: _bundledUserListData) List<UserApi> users,@JsonKey(name: 'task_statuses', fromJson: _taskStatusListData) List<TaskStatusApi> taskStatuses,@JsonKey(name: 'company_gateways', fromJson: _companyGatewayListData) List<CompanyGatewayApi> companyGateways,@JsonKey(name: 'payment_terms', fromJson: _paymentTermListData) List<PaymentTermApi> paymentTerms,@JsonKey(name: 'tax_rates', fromJson: _taxRateListData) List<TaxRateApi> taxRates,@JsonKey(name: 'expense_categories', fromJson: _expenseCategoryListData) List<ExpenseCategoryApi> expenseCategories,@JsonKey(name: 'groups', fromJson: _groupSettingListData) List<GroupSettingApi> groups,@JsonKey(name: 'bank_transaction_rules', fromJson: _transactionRuleListData) List<TransactionRuleApi> bankTransactionRules,@JsonKey(name: 'bank_integrations', fromJson: _bankIntegrationListData) List<BankAccountApi> bankIntegrations,@JsonKey(name: 'webhooks', fromJson: _webhookListData) List<WebhookApi> webhooks,@JsonKey(name: 'tokens_hashed', fromJson: _tokenListData) List<TokenApi> tokensHashed,@JsonKey(name: 'task_schedulers', fromJson: _taskSchedulerListData) List<ScheduleApi> taskSchedulers,@JsonKey(name: 'subscriptions', fromJson: _subscriptionListData) List<SubscriptionApi> subscriptions,@JsonKey(name: 'designs', fromJson: _designListData) List<DesignApi> designs,@JsonKey(name: 'clients', fromJson: _clientDeltaListData) List<ClientApi> clients,@JsonKey(name: 'products', fromJson: _productDeltaListData) List<ProductApi> products,@JsonKey(name: 'invoices', fromJson: _invoiceDeltaListData) List<InvoiceApi> invoices,@JsonKey(name: 'recurring_invoices', fromJson: _recurringInvoiceDeltaListData) List<RecurringInvoiceApi> recurringInvoices,@JsonKey(name: 'quotes', fromJson: _quoteDeltaListData) List<QuoteApi> quotes,@JsonKey(name: 'credits', fromJson: _creditDeltaListData) List<CreditApi> credits,@JsonKey(name: 'payments', fromJson: _paymentDeltaListData) List<PaymentApi> payments,@JsonKey(name: 'tasks', fromJson: _taskDeltaListData) List<TaskApi> tasks,@JsonKey(name: 'projects', fromJson: _projectDeltaListData) List<ProjectApi> projects,@JsonKey(name: 'expenses', fromJson: _expenseDeltaListData) List<ExpenseApi> expenses,@JsonKey(name: 'recurring_expenses', fromJson: _recurringExpenseDeltaListData) List<RecurringExpenseApi> recurringExpenses,@JsonKey(name: 'vendors', fromJson: _vendorDeltaListData) List<VendorApi> vendors,@JsonKey(name: 'purchase_orders', fromJson: _purchaseOrderDeltaListData) List<PurchaseOrderApi> purchaseOrders,@JsonKey(name: 'bank_transactions', fromJson: _bankTransactionDeltaListData) List<BankTransactionApi> bankTransactions,@JsonKey(name: 'enabled_tax_rates') int enabledTaxRates,@JsonKey(name: 'enabled_item_tax_rates') int enabledItemTaxRates,@JsonKey(name: 'enabled_expense_tax_rates') int enabledExpenseTaxRates,@JsonKey(name: 'calculate_taxes') bool calculateTaxes,@JsonKey(name: 'tax_data') TaxConfigApi? taxData,@JsonKey(name: 'e_invoice', includeIfNull: false) Map<String, dynamic>? eInvoice,@JsonKey(name: 'custom_surcharge_taxes1') bool customSurchargeTaxes1,@JsonKey(name: 'custom_surcharge_taxes2') bool customSurchargeTaxes2,@JsonKey(name: 'custom_surcharge_taxes3') bool customSurchargeTaxes3,@JsonKey(name: 'custom_surcharge_taxes4') bool customSurchargeTaxes4,@JsonKey(name: 'track_inventory') bool trackInventory,@JsonKey(name: 'stock_notification') bool stockNotification,@JsonKey(name: 'inventory_notification_threshold') int inventoryNotificationThreshold,@JsonKey(name: 'enable_product_discount') bool enableProductDiscount,@JsonKey(name: 'enable_product_cost') bool enableProductCost,@JsonKey(name: 'enable_product_quantity') bool enableProductQuantity,@JsonKey(name: 'default_quantity') bool defaultQuantity,@JsonKey(name: 'show_product_details') bool showProductDetails,@JsonKey(name: 'fill_products') bool fillProducts,@JsonKey(name: 'update_products') bool updateProducts,@JsonKey(name: 'convert_products') bool convertProducts,@JsonKey(name: 'convert_rate_to_client') bool convertRateToClient,@JsonKey(name: 'stop_on_unpaid_recurring') bool stopOnUnpaidRecurring,@JsonKey(name: 'use_quote_terms_on_conversion') bool useQuoteTermsOnConversion,@JsonKey(name: 'google_analytics_key') String googleAnalyticsKey,@JsonKey(name: 'matomo_id') String matomoId,@JsonKey(name: 'matomo_url') String matomoUrl,@JsonKey(name: 'session_timeout') int sessionTimeout,@JsonKey(name: 'default_password_timeout') int defaultPasswordTimeout,@JsonKey(name: 'oauth_password_required') bool oauthPasswordRequired,@JsonKey(name: 'is_disabled') bool isDisabled,@JsonKey(name: 'markdown_enabled') bool markdownEnabled,@JsonKey(name: 'markdown_email_enabled') bool markdownEmailEnabled,@JsonKey(name: 'report_include_drafts') bool reportIncludeDrafts,@JsonKey(name: 'report_include_deleted') bool reportIncludeDeleted,@JsonKey(name: 'quickbooks') Map<String, dynamic>? quickbooks,@JsonKey(name: 'smtp_host') String smtpHost,@JsonKey(name: 'smtp_port') int smtpPort,@JsonKey(name: 'smtp_encryption') String smtpEncryption,@JsonKey(name: 'smtp_username') String smtpUsername,@JsonKey(name: 'smtp_password') String smtpPassword,@JsonKey(name: 'smtp_local_domain') String smtpLocalDomain,@JsonKey(name: 'smtp_verify_peer') bool smtpVerifyPeer,@JsonKey(name: 'expense_mailbox') String expenseMailbox,@JsonKey(name: 'expense_mailbox_active') bool expenseMailboxActive,@JsonKey(name: 'inbound_mailbox_allow_company_users') bool inboundMailboxAllowCompanyUsers,@JsonKey(name: 'inbound_mailbox_allow_vendors') bool inboundMailboxAllowVendors,@JsonKey(name: 'inbound_mailbox_allow_clients') bool inboundMailboxAllowClients,@JsonKey(name: 'inbound_mailbox_allow_unknown') bool inboundMailboxAllowUnknown,@JsonKey(name: 'inbound_mailbox_whitelist') String inboundMailboxWhitelist,@JsonKey(name: 'inbound_mailbox_blacklist') String inboundMailboxBlacklist,@JsonKey(name: 'expense_inclusive_taxes') bool expenseInclusiveTaxes,@JsonKey(name: 'calculate_expense_tax_by_amount') bool calculateExpenseTaxByAmount,@JsonKey(name: 'auto_start_tasks') bool autoStartTasks,@JsonKey(name: 'show_task_end_date') bool showTaskEndDate,@JsonKey(name: 'show_tasks_table') bool showTasksTable,@JsonKey(name: 'invoice_task_datelog') bool invoiceTaskDatelog,@JsonKey(name: 'invoice_task_timelog') bool invoiceTaskTimelog,@JsonKey(name: 'invoice_task_hours') bool invoiceTaskHours,@JsonKey(name: 'invoice_task_item_description') bool invoiceTaskItemDescription,@JsonKey(name: 'invoice_task_project') bool invoiceTaskProject,@JsonKey(name: 'invoice_task_project_header') bool invoiceTaskProjectHeader,@JsonKey(name: 'invoice_task_lock') bool invoiceTaskLock,@JsonKey(name: 'invoice_task_documents') bool invoiceTaskDocuments,@JsonKey(name: 'mark_expenses_invoiceable') bool markExpensesInvoiceable,@JsonKey(name: 'mark_expenses_paid') bool markExpensesPaid,@JsonKey(name: 'invoice_expense_documents') bool invoiceExpenseDocuments,@JsonKey(name: 'notify_vendor_when_paid') bool notifyVendorWhenPaid,@JsonKey(name: 'enable_applying_payments') bool enableApplyingPayments,@JsonKey(name: 'convert_payment_currency') bool convertPaymentCurrency,@JsonKey(name: 'convert_expense_currency') bool convertExpenseCurrency,@JsonKey(name: 'has_e_invoice_certificate') bool hasEInvoiceCertificate,@JsonKey(name: 'has_e_invoice_certificate_passphrase') bool hasEInvoiceCertificatePassphrase
});


$TaxConfigApiCopyWith<$Res>? get taxData;

}
/// @nodoc
class _$CompanyEnvelopeApiCopyWithImpl<$Res>
    implements $CompanyEnvelopeApiCopyWith<$Res> {
  _$CompanyEnvelopeApiCopyWithImpl(this._self, this._then);

  final CompanyEnvelopeApi _self;
  final $Res Function(CompanyEnvelopeApi) _then;

/// Create a copy of CompanyEnvelopeApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? name = null,Object? companyKey = null,Object? updatedAt = null,Object? subdomain = null,Object? portalDomain = null,Object? portalMode = null,Object? clientCanRegister = null,Object? clientRegistrationFields = null,Object? customFields = null,Object? documents = null,Object? sizeId = null,Object? industryId = null,Object? firstMonthOfYear = null,Object? firstDayOfWeek = null,Object? useCommaAsDecimalPlace = null,Object? legalEntityId = null,Object? enabledModules = null,Object? settings = null,Object? users = null,Object? taskStatuses = null,Object? companyGateways = null,Object? paymentTerms = null,Object? taxRates = null,Object? expenseCategories = null,Object? groups = null,Object? bankTransactionRules = null,Object? bankIntegrations = null,Object? webhooks = null,Object? tokensHashed = null,Object? taskSchedulers = null,Object? subscriptions = null,Object? designs = null,Object? clients = null,Object? products = null,Object? invoices = null,Object? recurringInvoices = null,Object? quotes = null,Object? credits = null,Object? payments = null,Object? tasks = null,Object? projects = null,Object? expenses = null,Object? recurringExpenses = null,Object? vendors = null,Object? purchaseOrders = null,Object? bankTransactions = null,Object? enabledTaxRates = null,Object? enabledItemTaxRates = null,Object? enabledExpenseTaxRates = null,Object? calculateTaxes = null,Object? taxData = freezed,Object? eInvoice = freezed,Object? customSurchargeTaxes1 = null,Object? customSurchargeTaxes2 = null,Object? customSurchargeTaxes3 = null,Object? customSurchargeTaxes4 = null,Object? trackInventory = null,Object? stockNotification = null,Object? inventoryNotificationThreshold = null,Object? enableProductDiscount = null,Object? enableProductCost = null,Object? enableProductQuantity = null,Object? defaultQuantity = null,Object? showProductDetails = null,Object? fillProducts = null,Object? updateProducts = null,Object? convertProducts = null,Object? convertRateToClient = null,Object? stopOnUnpaidRecurring = null,Object? useQuoteTermsOnConversion = null,Object? googleAnalyticsKey = null,Object? matomoId = null,Object? matomoUrl = null,Object? sessionTimeout = null,Object? defaultPasswordTimeout = null,Object? oauthPasswordRequired = null,Object? isDisabled = null,Object? markdownEnabled = null,Object? markdownEmailEnabled = null,Object? reportIncludeDrafts = null,Object? reportIncludeDeleted = null,Object? quickbooks = freezed,Object? smtpHost = null,Object? smtpPort = null,Object? smtpEncryption = null,Object? smtpUsername = null,Object? smtpPassword = null,Object? smtpLocalDomain = null,Object? smtpVerifyPeer = null,Object? expenseMailbox = null,Object? expenseMailboxActive = null,Object? inboundMailboxAllowCompanyUsers = null,Object? inboundMailboxAllowVendors = null,Object? inboundMailboxAllowClients = null,Object? inboundMailboxAllowUnknown = null,Object? inboundMailboxWhitelist = null,Object? inboundMailboxBlacklist = null,Object? expenseInclusiveTaxes = null,Object? calculateExpenseTaxByAmount = null,Object? autoStartTasks = null,Object? showTaskEndDate = null,Object? showTasksTable = null,Object? invoiceTaskDatelog = null,Object? invoiceTaskTimelog = null,Object? invoiceTaskHours = null,Object? invoiceTaskItemDescription = null,Object? invoiceTaskProject = null,Object? invoiceTaskProjectHeader = null,Object? invoiceTaskLock = null,Object? invoiceTaskDocuments = null,Object? markExpensesInvoiceable = null,Object? markExpensesPaid = null,Object? invoiceExpenseDocuments = null,Object? notifyVendorWhenPaid = null,Object? enableApplyingPayments = null,Object? convertPaymentCurrency = null,Object? convertExpenseCurrency = null,Object? hasEInvoiceCertificate = null,Object? hasEInvoiceCertificatePassphrase = null,}) {
  return _then(CompanyEnvelopeApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,companyKey: null == companyKey ? _self.companyKey : companyKey // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,subdomain: null == subdomain ? _self.subdomain : subdomain // ignore: cast_nullable_to_non_nullable
as String,portalDomain: null == portalDomain ? _self.portalDomain : portalDomain // ignore: cast_nullable_to_non_nullable
as String,portalMode: null == portalMode ? _self.portalMode : portalMode // ignore: cast_nullable_to_non_nullable
as String,clientCanRegister: null == clientCanRegister ? _self.clientCanRegister : clientCanRegister // ignore: cast_nullable_to_non_nullable
as bool,clientRegistrationFields: null == clientRegistrationFields ? _self.clientRegistrationFields : clientRegistrationFields // ignore: cast_nullable_to_non_nullable
as List<ClientRegistrationFieldApi>,customFields: null == customFields ? _self.customFields : customFields // ignore: cast_nullable_to_non_nullable
as Map<String, String>,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>,sizeId: null == sizeId ? _self.sizeId : sizeId // ignore: cast_nullable_to_non_nullable
as String,industryId: null == industryId ? _self.industryId : industryId // ignore: cast_nullable_to_non_nullable
as String,firstMonthOfYear: null == firstMonthOfYear ? _self.firstMonthOfYear : firstMonthOfYear // ignore: cast_nullable_to_non_nullable
as String,firstDayOfWeek: null == firstDayOfWeek ? _self.firstDayOfWeek : firstDayOfWeek // ignore: cast_nullable_to_non_nullable
as String,useCommaAsDecimalPlace: null == useCommaAsDecimalPlace ? _self.useCommaAsDecimalPlace : useCommaAsDecimalPlace // ignore: cast_nullable_to_non_nullable
as bool,legalEntityId: null == legalEntityId ? _self.legalEntityId : legalEntityId // ignore: cast_nullable_to_non_nullable
as int,enabledModules: null == enabledModules ? _self.enabledModules : enabledModules // ignore: cast_nullable_to_non_nullable
as int,settings: null == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as List<UserApi>,taskStatuses: null == taskStatuses ? _self.taskStatuses : taskStatuses // ignore: cast_nullable_to_non_nullable
as List<TaskStatusApi>,companyGateways: null == companyGateways ? _self.companyGateways : companyGateways // ignore: cast_nullable_to_non_nullable
as List<CompanyGatewayApi>,paymentTerms: null == paymentTerms ? _self.paymentTerms : paymentTerms // ignore: cast_nullable_to_non_nullable
as List<PaymentTermApi>,taxRates: null == taxRates ? _self.taxRates : taxRates // ignore: cast_nullable_to_non_nullable
as List<TaxRateApi>,expenseCategories: null == expenseCategories ? _self.expenseCategories : expenseCategories // ignore: cast_nullable_to_non_nullable
as List<ExpenseCategoryApi>,groups: null == groups ? _self.groups : groups // ignore: cast_nullable_to_non_nullable
as List<GroupSettingApi>,bankTransactionRules: null == bankTransactionRules ? _self.bankTransactionRules : bankTransactionRules // ignore: cast_nullable_to_non_nullable
as List<TransactionRuleApi>,bankIntegrations: null == bankIntegrations ? _self.bankIntegrations : bankIntegrations // ignore: cast_nullable_to_non_nullable
as List<BankAccountApi>,webhooks: null == webhooks ? _self.webhooks : webhooks // ignore: cast_nullable_to_non_nullable
as List<WebhookApi>,tokensHashed: null == tokensHashed ? _self.tokensHashed : tokensHashed // ignore: cast_nullable_to_non_nullable
as List<TokenApi>,taskSchedulers: null == taskSchedulers ? _self.taskSchedulers : taskSchedulers // ignore: cast_nullable_to_non_nullable
as List<ScheduleApi>,subscriptions: null == subscriptions ? _self.subscriptions : subscriptions // ignore: cast_nullable_to_non_nullable
as List<SubscriptionApi>,designs: null == designs ? _self.designs : designs // ignore: cast_nullable_to_non_nullable
as List<DesignApi>,clients: null == clients ? _self.clients : clients // ignore: cast_nullable_to_non_nullable
as List<ClientApi>,products: null == products ? _self.products : products // ignore: cast_nullable_to_non_nullable
as List<ProductApi>,invoices: null == invoices ? _self.invoices : invoices // ignore: cast_nullable_to_non_nullable
as List<InvoiceApi>,recurringInvoices: null == recurringInvoices ? _self.recurringInvoices : recurringInvoices // ignore: cast_nullable_to_non_nullable
as List<RecurringInvoiceApi>,quotes: null == quotes ? _self.quotes : quotes // ignore: cast_nullable_to_non_nullable
as List<QuoteApi>,credits: null == credits ? _self.credits : credits // ignore: cast_nullable_to_non_nullable
as List<CreditApi>,payments: null == payments ? _self.payments : payments // ignore: cast_nullable_to_non_nullable
as List<PaymentApi>,tasks: null == tasks ? _self.tasks : tasks // ignore: cast_nullable_to_non_nullable
as List<TaskApi>,projects: null == projects ? _self.projects : projects // ignore: cast_nullable_to_non_nullable
as List<ProjectApi>,expenses: null == expenses ? _self.expenses : expenses // ignore: cast_nullable_to_non_nullable
as List<ExpenseApi>,recurringExpenses: null == recurringExpenses ? _self.recurringExpenses : recurringExpenses // ignore: cast_nullable_to_non_nullable
as List<RecurringExpenseApi>,vendors: null == vendors ? _self.vendors : vendors // ignore: cast_nullable_to_non_nullable
as List<VendorApi>,purchaseOrders: null == purchaseOrders ? _self.purchaseOrders : purchaseOrders // ignore: cast_nullable_to_non_nullable
as List<PurchaseOrderApi>,bankTransactions: null == bankTransactions ? _self.bankTransactions : bankTransactions // ignore: cast_nullable_to_non_nullable
as List<BankTransactionApi>,enabledTaxRates: null == enabledTaxRates ? _self.enabledTaxRates : enabledTaxRates // ignore: cast_nullable_to_non_nullable
as int,enabledItemTaxRates: null == enabledItemTaxRates ? _self.enabledItemTaxRates : enabledItemTaxRates // ignore: cast_nullable_to_non_nullable
as int,enabledExpenseTaxRates: null == enabledExpenseTaxRates ? _self.enabledExpenseTaxRates : enabledExpenseTaxRates // ignore: cast_nullable_to_non_nullable
as int,calculateTaxes: null == calculateTaxes ? _self.calculateTaxes : calculateTaxes // ignore: cast_nullable_to_non_nullable
as bool,taxData: freezed == taxData ? _self.taxData : taxData // ignore: cast_nullable_to_non_nullable
as TaxConfigApi?,eInvoice: freezed == eInvoice ? _self.eInvoice : eInvoice // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,customSurchargeTaxes1: null == customSurchargeTaxes1 ? _self.customSurchargeTaxes1 : customSurchargeTaxes1 // ignore: cast_nullable_to_non_nullable
as bool,customSurchargeTaxes2: null == customSurchargeTaxes2 ? _self.customSurchargeTaxes2 : customSurchargeTaxes2 // ignore: cast_nullable_to_non_nullable
as bool,customSurchargeTaxes3: null == customSurchargeTaxes3 ? _self.customSurchargeTaxes3 : customSurchargeTaxes3 // ignore: cast_nullable_to_non_nullable
as bool,customSurchargeTaxes4: null == customSurchargeTaxes4 ? _self.customSurchargeTaxes4 : customSurchargeTaxes4 // ignore: cast_nullable_to_non_nullable
as bool,trackInventory: null == trackInventory ? _self.trackInventory : trackInventory // ignore: cast_nullable_to_non_nullable
as bool,stockNotification: null == stockNotification ? _self.stockNotification : stockNotification // ignore: cast_nullable_to_non_nullable
as bool,inventoryNotificationThreshold: null == inventoryNotificationThreshold ? _self.inventoryNotificationThreshold : inventoryNotificationThreshold // ignore: cast_nullable_to_non_nullable
as int,enableProductDiscount: null == enableProductDiscount ? _self.enableProductDiscount : enableProductDiscount // ignore: cast_nullable_to_non_nullable
as bool,enableProductCost: null == enableProductCost ? _self.enableProductCost : enableProductCost // ignore: cast_nullable_to_non_nullable
as bool,enableProductQuantity: null == enableProductQuantity ? _self.enableProductQuantity : enableProductQuantity // ignore: cast_nullable_to_non_nullable
as bool,defaultQuantity: null == defaultQuantity ? _self.defaultQuantity : defaultQuantity // ignore: cast_nullable_to_non_nullable
as bool,showProductDetails: null == showProductDetails ? _self.showProductDetails : showProductDetails // ignore: cast_nullable_to_non_nullable
as bool,fillProducts: null == fillProducts ? _self.fillProducts : fillProducts // ignore: cast_nullable_to_non_nullable
as bool,updateProducts: null == updateProducts ? _self.updateProducts : updateProducts // ignore: cast_nullable_to_non_nullable
as bool,convertProducts: null == convertProducts ? _self.convertProducts : convertProducts // ignore: cast_nullable_to_non_nullable
as bool,convertRateToClient: null == convertRateToClient ? _self.convertRateToClient : convertRateToClient // ignore: cast_nullable_to_non_nullable
as bool,stopOnUnpaidRecurring: null == stopOnUnpaidRecurring ? _self.stopOnUnpaidRecurring : stopOnUnpaidRecurring // ignore: cast_nullable_to_non_nullable
as bool,useQuoteTermsOnConversion: null == useQuoteTermsOnConversion ? _self.useQuoteTermsOnConversion : useQuoteTermsOnConversion // ignore: cast_nullable_to_non_nullable
as bool,googleAnalyticsKey: null == googleAnalyticsKey ? _self.googleAnalyticsKey : googleAnalyticsKey // ignore: cast_nullable_to_non_nullable
as String,matomoId: null == matomoId ? _self.matomoId : matomoId // ignore: cast_nullable_to_non_nullable
as String,matomoUrl: null == matomoUrl ? _self.matomoUrl : matomoUrl // ignore: cast_nullable_to_non_nullable
as String,sessionTimeout: null == sessionTimeout ? _self.sessionTimeout : sessionTimeout // ignore: cast_nullable_to_non_nullable
as int,defaultPasswordTimeout: null == defaultPasswordTimeout ? _self.defaultPasswordTimeout : defaultPasswordTimeout // ignore: cast_nullable_to_non_nullable
as int,oauthPasswordRequired: null == oauthPasswordRequired ? _self.oauthPasswordRequired : oauthPasswordRequired // ignore: cast_nullable_to_non_nullable
as bool,isDisabled: null == isDisabled ? _self.isDisabled : isDisabled // ignore: cast_nullable_to_non_nullable
as bool,markdownEnabled: null == markdownEnabled ? _self.markdownEnabled : markdownEnabled // ignore: cast_nullable_to_non_nullable
as bool,markdownEmailEnabled: null == markdownEmailEnabled ? _self.markdownEmailEnabled : markdownEmailEnabled // ignore: cast_nullable_to_non_nullable
as bool,reportIncludeDrafts: null == reportIncludeDrafts ? _self.reportIncludeDrafts : reportIncludeDrafts // ignore: cast_nullable_to_non_nullable
as bool,reportIncludeDeleted: null == reportIncludeDeleted ? _self.reportIncludeDeleted : reportIncludeDeleted // ignore: cast_nullable_to_non_nullable
as bool,quickbooks: freezed == quickbooks ? _self.quickbooks : quickbooks // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,smtpHost: null == smtpHost ? _self.smtpHost : smtpHost // ignore: cast_nullable_to_non_nullable
as String,smtpPort: null == smtpPort ? _self.smtpPort : smtpPort // ignore: cast_nullable_to_non_nullable
as int,smtpEncryption: null == smtpEncryption ? _self.smtpEncryption : smtpEncryption // ignore: cast_nullable_to_non_nullable
as String,smtpUsername: null == smtpUsername ? _self.smtpUsername : smtpUsername // ignore: cast_nullable_to_non_nullable
as String,smtpPassword: null == smtpPassword ? _self.smtpPassword : smtpPassword // ignore: cast_nullable_to_non_nullable
as String,smtpLocalDomain: null == smtpLocalDomain ? _self.smtpLocalDomain : smtpLocalDomain // ignore: cast_nullable_to_non_nullable
as String,smtpVerifyPeer: null == smtpVerifyPeer ? _self.smtpVerifyPeer : smtpVerifyPeer // ignore: cast_nullable_to_non_nullable
as bool,expenseMailbox: null == expenseMailbox ? _self.expenseMailbox : expenseMailbox // ignore: cast_nullable_to_non_nullable
as String,expenseMailboxActive: null == expenseMailboxActive ? _self.expenseMailboxActive : expenseMailboxActive // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxAllowCompanyUsers: null == inboundMailboxAllowCompanyUsers ? _self.inboundMailboxAllowCompanyUsers : inboundMailboxAllowCompanyUsers // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxAllowVendors: null == inboundMailboxAllowVendors ? _self.inboundMailboxAllowVendors : inboundMailboxAllowVendors // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxAllowClients: null == inboundMailboxAllowClients ? _self.inboundMailboxAllowClients : inboundMailboxAllowClients // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxAllowUnknown: null == inboundMailboxAllowUnknown ? _self.inboundMailboxAllowUnknown : inboundMailboxAllowUnknown // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxWhitelist: null == inboundMailboxWhitelist ? _self.inboundMailboxWhitelist : inboundMailboxWhitelist // ignore: cast_nullable_to_non_nullable
as String,inboundMailboxBlacklist: null == inboundMailboxBlacklist ? _self.inboundMailboxBlacklist : inboundMailboxBlacklist // ignore: cast_nullable_to_non_nullable
as String,expenseInclusiveTaxes: null == expenseInclusiveTaxes ? _self.expenseInclusiveTaxes : expenseInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,calculateExpenseTaxByAmount: null == calculateExpenseTaxByAmount ? _self.calculateExpenseTaxByAmount : calculateExpenseTaxByAmount // ignore: cast_nullable_to_non_nullable
as bool,autoStartTasks: null == autoStartTasks ? _self.autoStartTasks : autoStartTasks // ignore: cast_nullable_to_non_nullable
as bool,showTaskEndDate: null == showTaskEndDate ? _self.showTaskEndDate : showTaskEndDate // ignore: cast_nullable_to_non_nullable
as bool,showTasksTable: null == showTasksTable ? _self.showTasksTable : showTasksTable // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskDatelog: null == invoiceTaskDatelog ? _self.invoiceTaskDatelog : invoiceTaskDatelog // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskTimelog: null == invoiceTaskTimelog ? _self.invoiceTaskTimelog : invoiceTaskTimelog // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskHours: null == invoiceTaskHours ? _self.invoiceTaskHours : invoiceTaskHours // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskItemDescription: null == invoiceTaskItemDescription ? _self.invoiceTaskItemDescription : invoiceTaskItemDescription // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskProject: null == invoiceTaskProject ? _self.invoiceTaskProject : invoiceTaskProject // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskProjectHeader: null == invoiceTaskProjectHeader ? _self.invoiceTaskProjectHeader : invoiceTaskProjectHeader // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskLock: null == invoiceTaskLock ? _self.invoiceTaskLock : invoiceTaskLock // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskDocuments: null == invoiceTaskDocuments ? _self.invoiceTaskDocuments : invoiceTaskDocuments // ignore: cast_nullable_to_non_nullable
as bool,markExpensesInvoiceable: null == markExpensesInvoiceable ? _self.markExpensesInvoiceable : markExpensesInvoiceable // ignore: cast_nullable_to_non_nullable
as bool,markExpensesPaid: null == markExpensesPaid ? _self.markExpensesPaid : markExpensesPaid // ignore: cast_nullable_to_non_nullable
as bool,invoiceExpenseDocuments: null == invoiceExpenseDocuments ? _self.invoiceExpenseDocuments : invoiceExpenseDocuments // ignore: cast_nullable_to_non_nullable
as bool,notifyVendorWhenPaid: null == notifyVendorWhenPaid ? _self.notifyVendorWhenPaid : notifyVendorWhenPaid // ignore: cast_nullable_to_non_nullable
as bool,enableApplyingPayments: null == enableApplyingPayments ? _self.enableApplyingPayments : enableApplyingPayments // ignore: cast_nullable_to_non_nullable
as bool,convertPaymentCurrency: null == convertPaymentCurrency ? _self.convertPaymentCurrency : convertPaymentCurrency // ignore: cast_nullable_to_non_nullable
as bool,convertExpenseCurrency: null == convertExpenseCurrency ? _self.convertExpenseCurrency : convertExpenseCurrency // ignore: cast_nullable_to_non_nullable
as bool,hasEInvoiceCertificate: null == hasEInvoiceCertificate ? _self.hasEInvoiceCertificate : hasEInvoiceCertificate // ignore: cast_nullable_to_non_nullable
as bool,hasEInvoiceCertificatePassphrase: null == hasEInvoiceCertificatePassphrase ? _self.hasEInvoiceCertificatePassphrase : hasEInvoiceCertificatePassphrase // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of CompanyEnvelopeApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaxConfigApiCopyWith<$Res>? get taxData {
    if (_self.taxData == null) {
    return null;
  }

  return $TaxConfigApiCopyWith<$Res>(_self.taxData!, (value) {
    return _then(_self.copyWith(taxData: value));
  });
}
}


/// Adds pattern-matching-related methods to [CompanyEnvelopeApi].
extension CompanyEnvelopeApiPatterns on CompanyEnvelopeApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompanyEnvelopeApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompanyEnvelopeApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompanyEnvelopeApi value)  $default,){
final _that = this;
switch (_that) {
case _CompanyEnvelopeApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompanyEnvelopeApi value)?  $default,){
final _that = this;
switch (_that) {
case _CompanyEnvelopeApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'display_name')  String displayName,  String name, @JsonKey(name: 'company_key')  String companyKey, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'subdomain')  String subdomain, @JsonKey(name: 'portal_domain')  String portalDomain, @JsonKey(name: 'portal_mode')  String portalMode, @JsonKey(name: 'client_can_register')  bool clientCanRegister, @JsonKey(name: 'client_registration_fields', fromJson: _clientRegistrationFieldListData)  List<ClientRegistrationFieldApi> clientRegistrationFields, @JsonKey(name: 'custom_fields')  Map<String, String> customFields, @JsonKey(name: 'documents', fromJson: _companyDocumentListData)  List<DocumentApi> documents, @JsonKey(name: 'size_id')  String sizeId, @JsonKey(name: 'industry_id')  String industryId, @JsonKey(name: 'first_month_of_year')  String firstMonthOfYear, @JsonKey(name: 'first_day_of_week')  String firstDayOfWeek, @JsonKey(name: 'use_comma_as_decimal_place')  bool useCommaAsDecimalPlace, @JsonKey(name: 'legal_entity_id')  int legalEntityId, @JsonKey(name: 'enabled_modules')  int enabledModules,  Map<String, dynamic> settings, @JsonKey(name: 'users', fromJson: _bundledUserListData)  List<UserApi> users, @JsonKey(name: 'task_statuses', fromJson: _taskStatusListData)  List<TaskStatusApi> taskStatuses, @JsonKey(name: 'company_gateways', fromJson: _companyGatewayListData)  List<CompanyGatewayApi> companyGateways, @JsonKey(name: 'payment_terms', fromJson: _paymentTermListData)  List<PaymentTermApi> paymentTerms, @JsonKey(name: 'tax_rates', fromJson: _taxRateListData)  List<TaxRateApi> taxRates, @JsonKey(name: 'expense_categories', fromJson: _expenseCategoryListData)  List<ExpenseCategoryApi> expenseCategories, @JsonKey(name: 'groups', fromJson: _groupSettingListData)  List<GroupSettingApi> groups, @JsonKey(name: 'bank_transaction_rules', fromJson: _transactionRuleListData)  List<TransactionRuleApi> bankTransactionRules, @JsonKey(name: 'bank_integrations', fromJson: _bankIntegrationListData)  List<BankAccountApi> bankIntegrations, @JsonKey(name: 'webhooks', fromJson: _webhookListData)  List<WebhookApi> webhooks, @JsonKey(name: 'tokens_hashed', fromJson: _tokenListData)  List<TokenApi> tokensHashed, @JsonKey(name: 'task_schedulers', fromJson: _taskSchedulerListData)  List<ScheduleApi> taskSchedulers, @JsonKey(name: 'subscriptions', fromJson: _subscriptionListData)  List<SubscriptionApi> subscriptions, @JsonKey(name: 'designs', fromJson: _designListData)  List<DesignApi> designs, @JsonKey(name: 'clients', fromJson: _clientDeltaListData)  List<ClientApi> clients, @JsonKey(name: 'products', fromJson: _productDeltaListData)  List<ProductApi> products, @JsonKey(name: 'invoices', fromJson: _invoiceDeltaListData)  List<InvoiceApi> invoices, @JsonKey(name: 'recurring_invoices', fromJson: _recurringInvoiceDeltaListData)  List<RecurringInvoiceApi> recurringInvoices, @JsonKey(name: 'quotes', fromJson: _quoteDeltaListData)  List<QuoteApi> quotes, @JsonKey(name: 'credits', fromJson: _creditDeltaListData)  List<CreditApi> credits, @JsonKey(name: 'payments', fromJson: _paymentDeltaListData)  List<PaymentApi> payments, @JsonKey(name: 'tasks', fromJson: _taskDeltaListData)  List<TaskApi> tasks, @JsonKey(name: 'projects', fromJson: _projectDeltaListData)  List<ProjectApi> projects, @JsonKey(name: 'expenses', fromJson: _expenseDeltaListData)  List<ExpenseApi> expenses, @JsonKey(name: 'recurring_expenses', fromJson: _recurringExpenseDeltaListData)  List<RecurringExpenseApi> recurringExpenses, @JsonKey(name: 'vendors', fromJson: _vendorDeltaListData)  List<VendorApi> vendors, @JsonKey(name: 'purchase_orders', fromJson: _purchaseOrderDeltaListData)  List<PurchaseOrderApi> purchaseOrders, @JsonKey(name: 'bank_transactions', fromJson: _bankTransactionDeltaListData)  List<BankTransactionApi> bankTransactions, @JsonKey(name: 'enabled_tax_rates')  int enabledTaxRates, @JsonKey(name: 'enabled_item_tax_rates')  int enabledItemTaxRates, @JsonKey(name: 'enabled_expense_tax_rates')  int enabledExpenseTaxRates, @JsonKey(name: 'calculate_taxes')  bool calculateTaxes, @JsonKey(name: 'tax_data')  TaxConfigApi? taxData, @JsonKey(name: 'e_invoice', includeIfNull: false)  Map<String, dynamic>? eInvoice, @JsonKey(name: 'custom_surcharge_taxes1')  bool customSurchargeTaxes1, @JsonKey(name: 'custom_surcharge_taxes2')  bool customSurchargeTaxes2, @JsonKey(name: 'custom_surcharge_taxes3')  bool customSurchargeTaxes3, @JsonKey(name: 'custom_surcharge_taxes4')  bool customSurchargeTaxes4, @JsonKey(name: 'track_inventory')  bool trackInventory, @JsonKey(name: 'stock_notification')  bool stockNotification, @JsonKey(name: 'inventory_notification_threshold')  int inventoryNotificationThreshold, @JsonKey(name: 'enable_product_discount')  bool enableProductDiscount, @JsonKey(name: 'enable_product_cost')  bool enableProductCost, @JsonKey(name: 'enable_product_quantity')  bool enableProductQuantity, @JsonKey(name: 'default_quantity')  bool defaultQuantity, @JsonKey(name: 'show_product_details')  bool showProductDetails, @JsonKey(name: 'fill_products')  bool fillProducts, @JsonKey(name: 'update_products')  bool updateProducts, @JsonKey(name: 'convert_products')  bool convertProducts, @JsonKey(name: 'convert_rate_to_client')  bool convertRateToClient, @JsonKey(name: 'stop_on_unpaid_recurring')  bool stopOnUnpaidRecurring, @JsonKey(name: 'use_quote_terms_on_conversion')  bool useQuoteTermsOnConversion, @JsonKey(name: 'google_analytics_key')  String googleAnalyticsKey, @JsonKey(name: 'matomo_id')  String matomoId, @JsonKey(name: 'matomo_url')  String matomoUrl, @JsonKey(name: 'session_timeout')  int sessionTimeout, @JsonKey(name: 'default_password_timeout')  int defaultPasswordTimeout, @JsonKey(name: 'oauth_password_required')  bool oauthPasswordRequired, @JsonKey(name: 'is_disabled')  bool isDisabled, @JsonKey(name: 'markdown_enabled')  bool markdownEnabled, @JsonKey(name: 'markdown_email_enabled')  bool markdownEmailEnabled, @JsonKey(name: 'report_include_drafts')  bool reportIncludeDrafts, @JsonKey(name: 'report_include_deleted')  bool reportIncludeDeleted, @JsonKey(name: 'quickbooks')  Map<String, dynamic>? quickbooks, @JsonKey(name: 'smtp_host')  String smtpHost, @JsonKey(name: 'smtp_port')  int smtpPort, @JsonKey(name: 'smtp_encryption')  String smtpEncryption, @JsonKey(name: 'smtp_username')  String smtpUsername, @JsonKey(name: 'smtp_password')  String smtpPassword, @JsonKey(name: 'smtp_local_domain')  String smtpLocalDomain, @JsonKey(name: 'smtp_verify_peer')  bool smtpVerifyPeer, @JsonKey(name: 'expense_mailbox')  String expenseMailbox, @JsonKey(name: 'expense_mailbox_active')  bool expenseMailboxActive, @JsonKey(name: 'inbound_mailbox_allow_company_users')  bool inboundMailboxAllowCompanyUsers, @JsonKey(name: 'inbound_mailbox_allow_vendors')  bool inboundMailboxAllowVendors, @JsonKey(name: 'inbound_mailbox_allow_clients')  bool inboundMailboxAllowClients, @JsonKey(name: 'inbound_mailbox_allow_unknown')  bool inboundMailboxAllowUnknown, @JsonKey(name: 'inbound_mailbox_whitelist')  String inboundMailboxWhitelist, @JsonKey(name: 'inbound_mailbox_blacklist')  String inboundMailboxBlacklist, @JsonKey(name: 'expense_inclusive_taxes')  bool expenseInclusiveTaxes, @JsonKey(name: 'calculate_expense_tax_by_amount')  bool calculateExpenseTaxByAmount, @JsonKey(name: 'auto_start_tasks')  bool autoStartTasks, @JsonKey(name: 'show_task_end_date')  bool showTaskEndDate, @JsonKey(name: 'show_tasks_table')  bool showTasksTable, @JsonKey(name: 'invoice_task_datelog')  bool invoiceTaskDatelog, @JsonKey(name: 'invoice_task_timelog')  bool invoiceTaskTimelog, @JsonKey(name: 'invoice_task_hours')  bool invoiceTaskHours, @JsonKey(name: 'invoice_task_item_description')  bool invoiceTaskItemDescription, @JsonKey(name: 'invoice_task_project')  bool invoiceTaskProject, @JsonKey(name: 'invoice_task_project_header')  bool invoiceTaskProjectHeader, @JsonKey(name: 'invoice_task_lock')  bool invoiceTaskLock, @JsonKey(name: 'invoice_task_documents')  bool invoiceTaskDocuments, @JsonKey(name: 'mark_expenses_invoiceable')  bool markExpensesInvoiceable, @JsonKey(name: 'mark_expenses_paid')  bool markExpensesPaid, @JsonKey(name: 'invoice_expense_documents')  bool invoiceExpenseDocuments, @JsonKey(name: 'notify_vendor_when_paid')  bool notifyVendorWhenPaid, @JsonKey(name: 'enable_applying_payments')  bool enableApplyingPayments, @JsonKey(name: 'convert_payment_currency')  bool convertPaymentCurrency, @JsonKey(name: 'convert_expense_currency')  bool convertExpenseCurrency, @JsonKey(name: 'has_e_invoice_certificate')  bool hasEInvoiceCertificate, @JsonKey(name: 'has_e_invoice_certificate_passphrase')  bool hasEInvoiceCertificatePassphrase)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompanyEnvelopeApi() when $default != null:
return $default(_that.id,_that.displayName,_that.name,_that.companyKey,_that.updatedAt,_that.subdomain,_that.portalDomain,_that.portalMode,_that.clientCanRegister,_that.clientRegistrationFields,_that.customFields,_that.documents,_that.sizeId,_that.industryId,_that.firstMonthOfYear,_that.firstDayOfWeek,_that.useCommaAsDecimalPlace,_that.legalEntityId,_that.enabledModules,_that.settings,_that.users,_that.taskStatuses,_that.companyGateways,_that.paymentTerms,_that.taxRates,_that.expenseCategories,_that.groups,_that.bankTransactionRules,_that.bankIntegrations,_that.webhooks,_that.tokensHashed,_that.taskSchedulers,_that.subscriptions,_that.designs,_that.clients,_that.products,_that.invoices,_that.recurringInvoices,_that.quotes,_that.credits,_that.payments,_that.tasks,_that.projects,_that.expenses,_that.recurringExpenses,_that.vendors,_that.purchaseOrders,_that.bankTransactions,_that.enabledTaxRates,_that.enabledItemTaxRates,_that.enabledExpenseTaxRates,_that.calculateTaxes,_that.taxData,_that.eInvoice,_that.customSurchargeTaxes1,_that.customSurchargeTaxes2,_that.customSurchargeTaxes3,_that.customSurchargeTaxes4,_that.trackInventory,_that.stockNotification,_that.inventoryNotificationThreshold,_that.enableProductDiscount,_that.enableProductCost,_that.enableProductQuantity,_that.defaultQuantity,_that.showProductDetails,_that.fillProducts,_that.updateProducts,_that.convertProducts,_that.convertRateToClient,_that.stopOnUnpaidRecurring,_that.useQuoteTermsOnConversion,_that.googleAnalyticsKey,_that.matomoId,_that.matomoUrl,_that.sessionTimeout,_that.defaultPasswordTimeout,_that.oauthPasswordRequired,_that.isDisabled,_that.markdownEnabled,_that.markdownEmailEnabled,_that.reportIncludeDrafts,_that.reportIncludeDeleted,_that.quickbooks,_that.smtpHost,_that.smtpPort,_that.smtpEncryption,_that.smtpUsername,_that.smtpPassword,_that.smtpLocalDomain,_that.smtpVerifyPeer,_that.expenseMailbox,_that.expenseMailboxActive,_that.inboundMailboxAllowCompanyUsers,_that.inboundMailboxAllowVendors,_that.inboundMailboxAllowClients,_that.inboundMailboxAllowUnknown,_that.inboundMailboxWhitelist,_that.inboundMailboxBlacklist,_that.expenseInclusiveTaxes,_that.calculateExpenseTaxByAmount,_that.autoStartTasks,_that.showTaskEndDate,_that.showTasksTable,_that.invoiceTaskDatelog,_that.invoiceTaskTimelog,_that.invoiceTaskHours,_that.invoiceTaskItemDescription,_that.invoiceTaskProject,_that.invoiceTaskProjectHeader,_that.invoiceTaskLock,_that.invoiceTaskDocuments,_that.markExpensesInvoiceable,_that.markExpensesPaid,_that.invoiceExpenseDocuments,_that.notifyVendorWhenPaid,_that.enableApplyingPayments,_that.convertPaymentCurrency,_that.convertExpenseCurrency,_that.hasEInvoiceCertificate,_that.hasEInvoiceCertificatePassphrase);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'display_name')  String displayName,  String name, @JsonKey(name: 'company_key')  String companyKey, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'subdomain')  String subdomain, @JsonKey(name: 'portal_domain')  String portalDomain, @JsonKey(name: 'portal_mode')  String portalMode, @JsonKey(name: 'client_can_register')  bool clientCanRegister, @JsonKey(name: 'client_registration_fields', fromJson: _clientRegistrationFieldListData)  List<ClientRegistrationFieldApi> clientRegistrationFields, @JsonKey(name: 'custom_fields')  Map<String, String> customFields, @JsonKey(name: 'documents', fromJson: _companyDocumentListData)  List<DocumentApi> documents, @JsonKey(name: 'size_id')  String sizeId, @JsonKey(name: 'industry_id')  String industryId, @JsonKey(name: 'first_month_of_year')  String firstMonthOfYear, @JsonKey(name: 'first_day_of_week')  String firstDayOfWeek, @JsonKey(name: 'use_comma_as_decimal_place')  bool useCommaAsDecimalPlace, @JsonKey(name: 'legal_entity_id')  int legalEntityId, @JsonKey(name: 'enabled_modules')  int enabledModules,  Map<String, dynamic> settings, @JsonKey(name: 'users', fromJson: _bundledUserListData)  List<UserApi> users, @JsonKey(name: 'task_statuses', fromJson: _taskStatusListData)  List<TaskStatusApi> taskStatuses, @JsonKey(name: 'company_gateways', fromJson: _companyGatewayListData)  List<CompanyGatewayApi> companyGateways, @JsonKey(name: 'payment_terms', fromJson: _paymentTermListData)  List<PaymentTermApi> paymentTerms, @JsonKey(name: 'tax_rates', fromJson: _taxRateListData)  List<TaxRateApi> taxRates, @JsonKey(name: 'expense_categories', fromJson: _expenseCategoryListData)  List<ExpenseCategoryApi> expenseCategories, @JsonKey(name: 'groups', fromJson: _groupSettingListData)  List<GroupSettingApi> groups, @JsonKey(name: 'bank_transaction_rules', fromJson: _transactionRuleListData)  List<TransactionRuleApi> bankTransactionRules, @JsonKey(name: 'bank_integrations', fromJson: _bankIntegrationListData)  List<BankAccountApi> bankIntegrations, @JsonKey(name: 'webhooks', fromJson: _webhookListData)  List<WebhookApi> webhooks, @JsonKey(name: 'tokens_hashed', fromJson: _tokenListData)  List<TokenApi> tokensHashed, @JsonKey(name: 'task_schedulers', fromJson: _taskSchedulerListData)  List<ScheduleApi> taskSchedulers, @JsonKey(name: 'subscriptions', fromJson: _subscriptionListData)  List<SubscriptionApi> subscriptions, @JsonKey(name: 'designs', fromJson: _designListData)  List<DesignApi> designs, @JsonKey(name: 'clients', fromJson: _clientDeltaListData)  List<ClientApi> clients, @JsonKey(name: 'products', fromJson: _productDeltaListData)  List<ProductApi> products, @JsonKey(name: 'invoices', fromJson: _invoiceDeltaListData)  List<InvoiceApi> invoices, @JsonKey(name: 'recurring_invoices', fromJson: _recurringInvoiceDeltaListData)  List<RecurringInvoiceApi> recurringInvoices, @JsonKey(name: 'quotes', fromJson: _quoteDeltaListData)  List<QuoteApi> quotes, @JsonKey(name: 'credits', fromJson: _creditDeltaListData)  List<CreditApi> credits, @JsonKey(name: 'payments', fromJson: _paymentDeltaListData)  List<PaymentApi> payments, @JsonKey(name: 'tasks', fromJson: _taskDeltaListData)  List<TaskApi> tasks, @JsonKey(name: 'projects', fromJson: _projectDeltaListData)  List<ProjectApi> projects, @JsonKey(name: 'expenses', fromJson: _expenseDeltaListData)  List<ExpenseApi> expenses, @JsonKey(name: 'recurring_expenses', fromJson: _recurringExpenseDeltaListData)  List<RecurringExpenseApi> recurringExpenses, @JsonKey(name: 'vendors', fromJson: _vendorDeltaListData)  List<VendorApi> vendors, @JsonKey(name: 'purchase_orders', fromJson: _purchaseOrderDeltaListData)  List<PurchaseOrderApi> purchaseOrders, @JsonKey(name: 'bank_transactions', fromJson: _bankTransactionDeltaListData)  List<BankTransactionApi> bankTransactions, @JsonKey(name: 'enabled_tax_rates')  int enabledTaxRates, @JsonKey(name: 'enabled_item_tax_rates')  int enabledItemTaxRates, @JsonKey(name: 'enabled_expense_tax_rates')  int enabledExpenseTaxRates, @JsonKey(name: 'calculate_taxes')  bool calculateTaxes, @JsonKey(name: 'tax_data')  TaxConfigApi? taxData, @JsonKey(name: 'e_invoice', includeIfNull: false)  Map<String, dynamic>? eInvoice, @JsonKey(name: 'custom_surcharge_taxes1')  bool customSurchargeTaxes1, @JsonKey(name: 'custom_surcharge_taxes2')  bool customSurchargeTaxes2, @JsonKey(name: 'custom_surcharge_taxes3')  bool customSurchargeTaxes3, @JsonKey(name: 'custom_surcharge_taxes4')  bool customSurchargeTaxes4, @JsonKey(name: 'track_inventory')  bool trackInventory, @JsonKey(name: 'stock_notification')  bool stockNotification, @JsonKey(name: 'inventory_notification_threshold')  int inventoryNotificationThreshold, @JsonKey(name: 'enable_product_discount')  bool enableProductDiscount, @JsonKey(name: 'enable_product_cost')  bool enableProductCost, @JsonKey(name: 'enable_product_quantity')  bool enableProductQuantity, @JsonKey(name: 'default_quantity')  bool defaultQuantity, @JsonKey(name: 'show_product_details')  bool showProductDetails, @JsonKey(name: 'fill_products')  bool fillProducts, @JsonKey(name: 'update_products')  bool updateProducts, @JsonKey(name: 'convert_products')  bool convertProducts, @JsonKey(name: 'convert_rate_to_client')  bool convertRateToClient, @JsonKey(name: 'stop_on_unpaid_recurring')  bool stopOnUnpaidRecurring, @JsonKey(name: 'use_quote_terms_on_conversion')  bool useQuoteTermsOnConversion, @JsonKey(name: 'google_analytics_key')  String googleAnalyticsKey, @JsonKey(name: 'matomo_id')  String matomoId, @JsonKey(name: 'matomo_url')  String matomoUrl, @JsonKey(name: 'session_timeout')  int sessionTimeout, @JsonKey(name: 'default_password_timeout')  int defaultPasswordTimeout, @JsonKey(name: 'oauth_password_required')  bool oauthPasswordRequired, @JsonKey(name: 'is_disabled')  bool isDisabled, @JsonKey(name: 'markdown_enabled')  bool markdownEnabled, @JsonKey(name: 'markdown_email_enabled')  bool markdownEmailEnabled, @JsonKey(name: 'report_include_drafts')  bool reportIncludeDrafts, @JsonKey(name: 'report_include_deleted')  bool reportIncludeDeleted, @JsonKey(name: 'quickbooks')  Map<String, dynamic>? quickbooks, @JsonKey(name: 'smtp_host')  String smtpHost, @JsonKey(name: 'smtp_port')  int smtpPort, @JsonKey(name: 'smtp_encryption')  String smtpEncryption, @JsonKey(name: 'smtp_username')  String smtpUsername, @JsonKey(name: 'smtp_password')  String smtpPassword, @JsonKey(name: 'smtp_local_domain')  String smtpLocalDomain, @JsonKey(name: 'smtp_verify_peer')  bool smtpVerifyPeer, @JsonKey(name: 'expense_mailbox')  String expenseMailbox, @JsonKey(name: 'expense_mailbox_active')  bool expenseMailboxActive, @JsonKey(name: 'inbound_mailbox_allow_company_users')  bool inboundMailboxAllowCompanyUsers, @JsonKey(name: 'inbound_mailbox_allow_vendors')  bool inboundMailboxAllowVendors, @JsonKey(name: 'inbound_mailbox_allow_clients')  bool inboundMailboxAllowClients, @JsonKey(name: 'inbound_mailbox_allow_unknown')  bool inboundMailboxAllowUnknown, @JsonKey(name: 'inbound_mailbox_whitelist')  String inboundMailboxWhitelist, @JsonKey(name: 'inbound_mailbox_blacklist')  String inboundMailboxBlacklist, @JsonKey(name: 'expense_inclusive_taxes')  bool expenseInclusiveTaxes, @JsonKey(name: 'calculate_expense_tax_by_amount')  bool calculateExpenseTaxByAmount, @JsonKey(name: 'auto_start_tasks')  bool autoStartTasks, @JsonKey(name: 'show_task_end_date')  bool showTaskEndDate, @JsonKey(name: 'show_tasks_table')  bool showTasksTable, @JsonKey(name: 'invoice_task_datelog')  bool invoiceTaskDatelog, @JsonKey(name: 'invoice_task_timelog')  bool invoiceTaskTimelog, @JsonKey(name: 'invoice_task_hours')  bool invoiceTaskHours, @JsonKey(name: 'invoice_task_item_description')  bool invoiceTaskItemDescription, @JsonKey(name: 'invoice_task_project')  bool invoiceTaskProject, @JsonKey(name: 'invoice_task_project_header')  bool invoiceTaskProjectHeader, @JsonKey(name: 'invoice_task_lock')  bool invoiceTaskLock, @JsonKey(name: 'invoice_task_documents')  bool invoiceTaskDocuments, @JsonKey(name: 'mark_expenses_invoiceable')  bool markExpensesInvoiceable, @JsonKey(name: 'mark_expenses_paid')  bool markExpensesPaid, @JsonKey(name: 'invoice_expense_documents')  bool invoiceExpenseDocuments, @JsonKey(name: 'notify_vendor_when_paid')  bool notifyVendorWhenPaid, @JsonKey(name: 'enable_applying_payments')  bool enableApplyingPayments, @JsonKey(name: 'convert_payment_currency')  bool convertPaymentCurrency, @JsonKey(name: 'convert_expense_currency')  bool convertExpenseCurrency, @JsonKey(name: 'has_e_invoice_certificate')  bool hasEInvoiceCertificate, @JsonKey(name: 'has_e_invoice_certificate_passphrase')  bool hasEInvoiceCertificatePassphrase)  $default,) {final _that = this;
switch (_that) {
case _CompanyEnvelopeApi():
return $default(_that.id,_that.displayName,_that.name,_that.companyKey,_that.updatedAt,_that.subdomain,_that.portalDomain,_that.portalMode,_that.clientCanRegister,_that.clientRegistrationFields,_that.customFields,_that.documents,_that.sizeId,_that.industryId,_that.firstMonthOfYear,_that.firstDayOfWeek,_that.useCommaAsDecimalPlace,_that.legalEntityId,_that.enabledModules,_that.settings,_that.users,_that.taskStatuses,_that.companyGateways,_that.paymentTerms,_that.taxRates,_that.expenseCategories,_that.groups,_that.bankTransactionRules,_that.bankIntegrations,_that.webhooks,_that.tokensHashed,_that.taskSchedulers,_that.subscriptions,_that.designs,_that.clients,_that.products,_that.invoices,_that.recurringInvoices,_that.quotes,_that.credits,_that.payments,_that.tasks,_that.projects,_that.expenses,_that.recurringExpenses,_that.vendors,_that.purchaseOrders,_that.bankTransactions,_that.enabledTaxRates,_that.enabledItemTaxRates,_that.enabledExpenseTaxRates,_that.calculateTaxes,_that.taxData,_that.eInvoice,_that.customSurchargeTaxes1,_that.customSurchargeTaxes2,_that.customSurchargeTaxes3,_that.customSurchargeTaxes4,_that.trackInventory,_that.stockNotification,_that.inventoryNotificationThreshold,_that.enableProductDiscount,_that.enableProductCost,_that.enableProductQuantity,_that.defaultQuantity,_that.showProductDetails,_that.fillProducts,_that.updateProducts,_that.convertProducts,_that.convertRateToClient,_that.stopOnUnpaidRecurring,_that.useQuoteTermsOnConversion,_that.googleAnalyticsKey,_that.matomoId,_that.matomoUrl,_that.sessionTimeout,_that.defaultPasswordTimeout,_that.oauthPasswordRequired,_that.isDisabled,_that.markdownEnabled,_that.markdownEmailEnabled,_that.reportIncludeDrafts,_that.reportIncludeDeleted,_that.quickbooks,_that.smtpHost,_that.smtpPort,_that.smtpEncryption,_that.smtpUsername,_that.smtpPassword,_that.smtpLocalDomain,_that.smtpVerifyPeer,_that.expenseMailbox,_that.expenseMailboxActive,_that.inboundMailboxAllowCompanyUsers,_that.inboundMailboxAllowVendors,_that.inboundMailboxAllowClients,_that.inboundMailboxAllowUnknown,_that.inboundMailboxWhitelist,_that.inboundMailboxBlacklist,_that.expenseInclusiveTaxes,_that.calculateExpenseTaxByAmount,_that.autoStartTasks,_that.showTaskEndDate,_that.showTasksTable,_that.invoiceTaskDatelog,_that.invoiceTaskTimelog,_that.invoiceTaskHours,_that.invoiceTaskItemDescription,_that.invoiceTaskProject,_that.invoiceTaskProjectHeader,_that.invoiceTaskLock,_that.invoiceTaskDocuments,_that.markExpensesInvoiceable,_that.markExpensesPaid,_that.invoiceExpenseDocuments,_that.notifyVendorWhenPaid,_that.enableApplyingPayments,_that.convertPaymentCurrency,_that.convertExpenseCurrency,_that.hasEInvoiceCertificate,_that.hasEInvoiceCertificatePassphrase);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'display_name')  String displayName,  String name, @JsonKey(name: 'company_key')  String companyKey, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'subdomain')  String subdomain, @JsonKey(name: 'portal_domain')  String portalDomain, @JsonKey(name: 'portal_mode')  String portalMode, @JsonKey(name: 'client_can_register')  bool clientCanRegister, @JsonKey(name: 'client_registration_fields', fromJson: _clientRegistrationFieldListData)  List<ClientRegistrationFieldApi> clientRegistrationFields, @JsonKey(name: 'custom_fields')  Map<String, String> customFields, @JsonKey(name: 'documents', fromJson: _companyDocumentListData)  List<DocumentApi> documents, @JsonKey(name: 'size_id')  String sizeId, @JsonKey(name: 'industry_id')  String industryId, @JsonKey(name: 'first_month_of_year')  String firstMonthOfYear, @JsonKey(name: 'first_day_of_week')  String firstDayOfWeek, @JsonKey(name: 'use_comma_as_decimal_place')  bool useCommaAsDecimalPlace, @JsonKey(name: 'legal_entity_id')  int legalEntityId, @JsonKey(name: 'enabled_modules')  int enabledModules,  Map<String, dynamic> settings, @JsonKey(name: 'users', fromJson: _bundledUserListData)  List<UserApi> users, @JsonKey(name: 'task_statuses', fromJson: _taskStatusListData)  List<TaskStatusApi> taskStatuses, @JsonKey(name: 'company_gateways', fromJson: _companyGatewayListData)  List<CompanyGatewayApi> companyGateways, @JsonKey(name: 'payment_terms', fromJson: _paymentTermListData)  List<PaymentTermApi> paymentTerms, @JsonKey(name: 'tax_rates', fromJson: _taxRateListData)  List<TaxRateApi> taxRates, @JsonKey(name: 'expense_categories', fromJson: _expenseCategoryListData)  List<ExpenseCategoryApi> expenseCategories, @JsonKey(name: 'groups', fromJson: _groupSettingListData)  List<GroupSettingApi> groups, @JsonKey(name: 'bank_transaction_rules', fromJson: _transactionRuleListData)  List<TransactionRuleApi> bankTransactionRules, @JsonKey(name: 'bank_integrations', fromJson: _bankIntegrationListData)  List<BankAccountApi> bankIntegrations, @JsonKey(name: 'webhooks', fromJson: _webhookListData)  List<WebhookApi> webhooks, @JsonKey(name: 'tokens_hashed', fromJson: _tokenListData)  List<TokenApi> tokensHashed, @JsonKey(name: 'task_schedulers', fromJson: _taskSchedulerListData)  List<ScheduleApi> taskSchedulers, @JsonKey(name: 'subscriptions', fromJson: _subscriptionListData)  List<SubscriptionApi> subscriptions, @JsonKey(name: 'designs', fromJson: _designListData)  List<DesignApi> designs, @JsonKey(name: 'clients', fromJson: _clientDeltaListData)  List<ClientApi> clients, @JsonKey(name: 'products', fromJson: _productDeltaListData)  List<ProductApi> products, @JsonKey(name: 'invoices', fromJson: _invoiceDeltaListData)  List<InvoiceApi> invoices, @JsonKey(name: 'recurring_invoices', fromJson: _recurringInvoiceDeltaListData)  List<RecurringInvoiceApi> recurringInvoices, @JsonKey(name: 'quotes', fromJson: _quoteDeltaListData)  List<QuoteApi> quotes, @JsonKey(name: 'credits', fromJson: _creditDeltaListData)  List<CreditApi> credits, @JsonKey(name: 'payments', fromJson: _paymentDeltaListData)  List<PaymentApi> payments, @JsonKey(name: 'tasks', fromJson: _taskDeltaListData)  List<TaskApi> tasks, @JsonKey(name: 'projects', fromJson: _projectDeltaListData)  List<ProjectApi> projects, @JsonKey(name: 'expenses', fromJson: _expenseDeltaListData)  List<ExpenseApi> expenses, @JsonKey(name: 'recurring_expenses', fromJson: _recurringExpenseDeltaListData)  List<RecurringExpenseApi> recurringExpenses, @JsonKey(name: 'vendors', fromJson: _vendorDeltaListData)  List<VendorApi> vendors, @JsonKey(name: 'purchase_orders', fromJson: _purchaseOrderDeltaListData)  List<PurchaseOrderApi> purchaseOrders, @JsonKey(name: 'bank_transactions', fromJson: _bankTransactionDeltaListData)  List<BankTransactionApi> bankTransactions, @JsonKey(name: 'enabled_tax_rates')  int enabledTaxRates, @JsonKey(name: 'enabled_item_tax_rates')  int enabledItemTaxRates, @JsonKey(name: 'enabled_expense_tax_rates')  int enabledExpenseTaxRates, @JsonKey(name: 'calculate_taxes')  bool calculateTaxes, @JsonKey(name: 'tax_data')  TaxConfigApi? taxData, @JsonKey(name: 'e_invoice', includeIfNull: false)  Map<String, dynamic>? eInvoice, @JsonKey(name: 'custom_surcharge_taxes1')  bool customSurchargeTaxes1, @JsonKey(name: 'custom_surcharge_taxes2')  bool customSurchargeTaxes2, @JsonKey(name: 'custom_surcharge_taxes3')  bool customSurchargeTaxes3, @JsonKey(name: 'custom_surcharge_taxes4')  bool customSurchargeTaxes4, @JsonKey(name: 'track_inventory')  bool trackInventory, @JsonKey(name: 'stock_notification')  bool stockNotification, @JsonKey(name: 'inventory_notification_threshold')  int inventoryNotificationThreshold, @JsonKey(name: 'enable_product_discount')  bool enableProductDiscount, @JsonKey(name: 'enable_product_cost')  bool enableProductCost, @JsonKey(name: 'enable_product_quantity')  bool enableProductQuantity, @JsonKey(name: 'default_quantity')  bool defaultQuantity, @JsonKey(name: 'show_product_details')  bool showProductDetails, @JsonKey(name: 'fill_products')  bool fillProducts, @JsonKey(name: 'update_products')  bool updateProducts, @JsonKey(name: 'convert_products')  bool convertProducts, @JsonKey(name: 'convert_rate_to_client')  bool convertRateToClient, @JsonKey(name: 'stop_on_unpaid_recurring')  bool stopOnUnpaidRecurring, @JsonKey(name: 'use_quote_terms_on_conversion')  bool useQuoteTermsOnConversion, @JsonKey(name: 'google_analytics_key')  String googleAnalyticsKey, @JsonKey(name: 'matomo_id')  String matomoId, @JsonKey(name: 'matomo_url')  String matomoUrl, @JsonKey(name: 'session_timeout')  int sessionTimeout, @JsonKey(name: 'default_password_timeout')  int defaultPasswordTimeout, @JsonKey(name: 'oauth_password_required')  bool oauthPasswordRequired, @JsonKey(name: 'is_disabled')  bool isDisabled, @JsonKey(name: 'markdown_enabled')  bool markdownEnabled, @JsonKey(name: 'markdown_email_enabled')  bool markdownEmailEnabled, @JsonKey(name: 'report_include_drafts')  bool reportIncludeDrafts, @JsonKey(name: 'report_include_deleted')  bool reportIncludeDeleted, @JsonKey(name: 'quickbooks')  Map<String, dynamic>? quickbooks, @JsonKey(name: 'smtp_host')  String smtpHost, @JsonKey(name: 'smtp_port')  int smtpPort, @JsonKey(name: 'smtp_encryption')  String smtpEncryption, @JsonKey(name: 'smtp_username')  String smtpUsername, @JsonKey(name: 'smtp_password')  String smtpPassword, @JsonKey(name: 'smtp_local_domain')  String smtpLocalDomain, @JsonKey(name: 'smtp_verify_peer')  bool smtpVerifyPeer, @JsonKey(name: 'expense_mailbox')  String expenseMailbox, @JsonKey(name: 'expense_mailbox_active')  bool expenseMailboxActive, @JsonKey(name: 'inbound_mailbox_allow_company_users')  bool inboundMailboxAllowCompanyUsers, @JsonKey(name: 'inbound_mailbox_allow_vendors')  bool inboundMailboxAllowVendors, @JsonKey(name: 'inbound_mailbox_allow_clients')  bool inboundMailboxAllowClients, @JsonKey(name: 'inbound_mailbox_allow_unknown')  bool inboundMailboxAllowUnknown, @JsonKey(name: 'inbound_mailbox_whitelist')  String inboundMailboxWhitelist, @JsonKey(name: 'inbound_mailbox_blacklist')  String inboundMailboxBlacklist, @JsonKey(name: 'expense_inclusive_taxes')  bool expenseInclusiveTaxes, @JsonKey(name: 'calculate_expense_tax_by_amount')  bool calculateExpenseTaxByAmount, @JsonKey(name: 'auto_start_tasks')  bool autoStartTasks, @JsonKey(name: 'show_task_end_date')  bool showTaskEndDate, @JsonKey(name: 'show_tasks_table')  bool showTasksTable, @JsonKey(name: 'invoice_task_datelog')  bool invoiceTaskDatelog, @JsonKey(name: 'invoice_task_timelog')  bool invoiceTaskTimelog, @JsonKey(name: 'invoice_task_hours')  bool invoiceTaskHours, @JsonKey(name: 'invoice_task_item_description')  bool invoiceTaskItemDescription, @JsonKey(name: 'invoice_task_project')  bool invoiceTaskProject, @JsonKey(name: 'invoice_task_project_header')  bool invoiceTaskProjectHeader, @JsonKey(name: 'invoice_task_lock')  bool invoiceTaskLock, @JsonKey(name: 'invoice_task_documents')  bool invoiceTaskDocuments, @JsonKey(name: 'mark_expenses_invoiceable')  bool markExpensesInvoiceable, @JsonKey(name: 'mark_expenses_paid')  bool markExpensesPaid, @JsonKey(name: 'invoice_expense_documents')  bool invoiceExpenseDocuments, @JsonKey(name: 'notify_vendor_when_paid')  bool notifyVendorWhenPaid, @JsonKey(name: 'enable_applying_payments')  bool enableApplyingPayments, @JsonKey(name: 'convert_payment_currency')  bool convertPaymentCurrency, @JsonKey(name: 'convert_expense_currency')  bool convertExpenseCurrency, @JsonKey(name: 'has_e_invoice_certificate')  bool hasEInvoiceCertificate, @JsonKey(name: 'has_e_invoice_certificate_passphrase')  bool hasEInvoiceCertificatePassphrase)?  $default,) {final _that = this;
switch (_that) {
case _CompanyEnvelopeApi() when $default != null:
return $default(_that.id,_that.displayName,_that.name,_that.companyKey,_that.updatedAt,_that.subdomain,_that.portalDomain,_that.portalMode,_that.clientCanRegister,_that.clientRegistrationFields,_that.customFields,_that.documents,_that.sizeId,_that.industryId,_that.firstMonthOfYear,_that.firstDayOfWeek,_that.useCommaAsDecimalPlace,_that.legalEntityId,_that.enabledModules,_that.settings,_that.users,_that.taskStatuses,_that.companyGateways,_that.paymentTerms,_that.taxRates,_that.expenseCategories,_that.groups,_that.bankTransactionRules,_that.bankIntegrations,_that.webhooks,_that.tokensHashed,_that.taskSchedulers,_that.subscriptions,_that.designs,_that.clients,_that.products,_that.invoices,_that.recurringInvoices,_that.quotes,_that.credits,_that.payments,_that.tasks,_that.projects,_that.expenses,_that.recurringExpenses,_that.vendors,_that.purchaseOrders,_that.bankTransactions,_that.enabledTaxRates,_that.enabledItemTaxRates,_that.enabledExpenseTaxRates,_that.calculateTaxes,_that.taxData,_that.eInvoice,_that.customSurchargeTaxes1,_that.customSurchargeTaxes2,_that.customSurchargeTaxes3,_that.customSurchargeTaxes4,_that.trackInventory,_that.stockNotification,_that.inventoryNotificationThreshold,_that.enableProductDiscount,_that.enableProductCost,_that.enableProductQuantity,_that.defaultQuantity,_that.showProductDetails,_that.fillProducts,_that.updateProducts,_that.convertProducts,_that.convertRateToClient,_that.stopOnUnpaidRecurring,_that.useQuoteTermsOnConversion,_that.googleAnalyticsKey,_that.matomoId,_that.matomoUrl,_that.sessionTimeout,_that.defaultPasswordTimeout,_that.oauthPasswordRequired,_that.isDisabled,_that.markdownEnabled,_that.markdownEmailEnabled,_that.reportIncludeDrafts,_that.reportIncludeDeleted,_that.quickbooks,_that.smtpHost,_that.smtpPort,_that.smtpEncryption,_that.smtpUsername,_that.smtpPassword,_that.smtpLocalDomain,_that.smtpVerifyPeer,_that.expenseMailbox,_that.expenseMailboxActive,_that.inboundMailboxAllowCompanyUsers,_that.inboundMailboxAllowVendors,_that.inboundMailboxAllowClients,_that.inboundMailboxAllowUnknown,_that.inboundMailboxWhitelist,_that.inboundMailboxBlacklist,_that.expenseInclusiveTaxes,_that.calculateExpenseTaxByAmount,_that.autoStartTasks,_that.showTaskEndDate,_that.showTasksTable,_that.invoiceTaskDatelog,_that.invoiceTaskTimelog,_that.invoiceTaskHours,_that.invoiceTaskItemDescription,_that.invoiceTaskProject,_that.invoiceTaskProjectHeader,_that.invoiceTaskLock,_that.invoiceTaskDocuments,_that.markExpensesInvoiceable,_that.markExpensesPaid,_that.invoiceExpenseDocuments,_that.notifyVendorWhenPaid,_that.enableApplyingPayments,_that.convertPaymentCurrency,_that.convertExpenseCurrency,_that.hasEInvoiceCertificate,_that.hasEInvoiceCertificatePassphrase);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CompanyEnvelopeApi implements CompanyEnvelopeApi {
  const _CompanyEnvelopeApi({this.id = '', @JsonKey(name: 'display_name') this.displayName = '', this.name = '', @JsonKey(name: 'company_key') this.companyKey = '', @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'subdomain') this.subdomain = '', @JsonKey(name: 'portal_domain') this.portalDomain = '', @JsonKey(name: 'portal_mode') this.portalMode = '', @JsonKey(name: 'client_can_register') this.clientCanRegister = false, @JsonKey(name: 'client_registration_fields', fromJson: _clientRegistrationFieldListData)  List<ClientRegistrationFieldApi> clientRegistrationFields = const <ClientRegistrationFieldApi>[], @JsonKey(name: 'custom_fields')  Map<String, String> customFields = const <String, String>{}, @JsonKey(name: 'documents', fromJson: _companyDocumentListData)  List<DocumentApi> documents = const <DocumentApi>[], @JsonKey(name: 'size_id') this.sizeId = '', @JsonKey(name: 'industry_id') this.industryId = '', @JsonKey(name: 'first_month_of_year') this.firstMonthOfYear = '', @JsonKey(name: 'first_day_of_week') this.firstDayOfWeek = '', @JsonKey(name: 'use_comma_as_decimal_place') this.useCommaAsDecimalPlace = false, @JsonKey(name: 'legal_entity_id') this.legalEntityId = 0, @JsonKey(name: 'enabled_modules') this.enabledModules = 0,  Map<String, dynamic> settings = const <String, dynamic>{}, @JsonKey(name: 'users', fromJson: _bundledUserListData)  List<UserApi> users = const <UserApi>[], @JsonKey(name: 'task_statuses', fromJson: _taskStatusListData)  List<TaskStatusApi> taskStatuses = const <TaskStatusApi>[], @JsonKey(name: 'company_gateways', fromJson: _companyGatewayListData)  List<CompanyGatewayApi> companyGateways = const <CompanyGatewayApi>[], @JsonKey(name: 'payment_terms', fromJson: _paymentTermListData)  List<PaymentTermApi> paymentTerms = const <PaymentTermApi>[], @JsonKey(name: 'tax_rates', fromJson: _taxRateListData)  List<TaxRateApi> taxRates = const <TaxRateApi>[], @JsonKey(name: 'expense_categories', fromJson: _expenseCategoryListData)  List<ExpenseCategoryApi> expenseCategories = const <ExpenseCategoryApi>[], @JsonKey(name: 'groups', fromJson: _groupSettingListData)  List<GroupSettingApi> groups = const <GroupSettingApi>[], @JsonKey(name: 'bank_transaction_rules', fromJson: _transactionRuleListData)  List<TransactionRuleApi> bankTransactionRules = const <TransactionRuleApi>[], @JsonKey(name: 'bank_integrations', fromJson: _bankIntegrationListData)  List<BankAccountApi> bankIntegrations = const <BankAccountApi>[], @JsonKey(name: 'webhooks', fromJson: _webhookListData)  List<WebhookApi> webhooks = const <WebhookApi>[], @JsonKey(name: 'tokens_hashed', fromJson: _tokenListData)  List<TokenApi> tokensHashed = const <TokenApi>[], @JsonKey(name: 'task_schedulers', fromJson: _taskSchedulerListData)  List<ScheduleApi> taskSchedulers = const <ScheduleApi>[], @JsonKey(name: 'subscriptions', fromJson: _subscriptionListData)  List<SubscriptionApi> subscriptions = const <SubscriptionApi>[], @JsonKey(name: 'designs', fromJson: _designListData)  List<DesignApi> designs = const <DesignApi>[], @JsonKey(name: 'clients', fromJson: _clientDeltaListData)  List<ClientApi> clients = const <ClientApi>[], @JsonKey(name: 'products', fromJson: _productDeltaListData)  List<ProductApi> products = const <ProductApi>[], @JsonKey(name: 'invoices', fromJson: _invoiceDeltaListData)  List<InvoiceApi> invoices = const <InvoiceApi>[], @JsonKey(name: 'recurring_invoices', fromJson: _recurringInvoiceDeltaListData)  List<RecurringInvoiceApi> recurringInvoices = const <RecurringInvoiceApi>[], @JsonKey(name: 'quotes', fromJson: _quoteDeltaListData)  List<QuoteApi> quotes = const <QuoteApi>[], @JsonKey(name: 'credits', fromJson: _creditDeltaListData)  List<CreditApi> credits = const <CreditApi>[], @JsonKey(name: 'payments', fromJson: _paymentDeltaListData)  List<PaymentApi> payments = const <PaymentApi>[], @JsonKey(name: 'tasks', fromJson: _taskDeltaListData)  List<TaskApi> tasks = const <TaskApi>[], @JsonKey(name: 'projects', fromJson: _projectDeltaListData)  List<ProjectApi> projects = const <ProjectApi>[], @JsonKey(name: 'expenses', fromJson: _expenseDeltaListData)  List<ExpenseApi> expenses = const <ExpenseApi>[], @JsonKey(name: 'recurring_expenses', fromJson: _recurringExpenseDeltaListData)  List<RecurringExpenseApi> recurringExpenses = const <RecurringExpenseApi>[], @JsonKey(name: 'vendors', fromJson: _vendorDeltaListData)  List<VendorApi> vendors = const <VendorApi>[], @JsonKey(name: 'purchase_orders', fromJson: _purchaseOrderDeltaListData)  List<PurchaseOrderApi> purchaseOrders = const <PurchaseOrderApi>[], @JsonKey(name: 'bank_transactions', fromJson: _bankTransactionDeltaListData)  List<BankTransactionApi> bankTransactions = const <BankTransactionApi>[], @JsonKey(name: 'enabled_tax_rates') this.enabledTaxRates = 0, @JsonKey(name: 'enabled_item_tax_rates') this.enabledItemTaxRates = 0, @JsonKey(name: 'enabled_expense_tax_rates') this.enabledExpenseTaxRates = 0, @JsonKey(name: 'calculate_taxes') this.calculateTaxes = false, @JsonKey(name: 'tax_data') this.taxData, @JsonKey(name: 'e_invoice', includeIfNull: false)  Map<String, dynamic>? eInvoice, @JsonKey(name: 'custom_surcharge_taxes1') this.customSurchargeTaxes1 = false, @JsonKey(name: 'custom_surcharge_taxes2') this.customSurchargeTaxes2 = false, @JsonKey(name: 'custom_surcharge_taxes3') this.customSurchargeTaxes3 = false, @JsonKey(name: 'custom_surcharge_taxes4') this.customSurchargeTaxes4 = false, @JsonKey(name: 'track_inventory') this.trackInventory = false, @JsonKey(name: 'stock_notification') this.stockNotification = false, @JsonKey(name: 'inventory_notification_threshold') this.inventoryNotificationThreshold = 0, @JsonKey(name: 'enable_product_discount') this.enableProductDiscount = false, @JsonKey(name: 'enable_product_cost') this.enableProductCost = false, @JsonKey(name: 'enable_product_quantity') this.enableProductQuantity = false, @JsonKey(name: 'default_quantity') this.defaultQuantity = false, @JsonKey(name: 'show_product_details') this.showProductDetails = false, @JsonKey(name: 'fill_products') this.fillProducts = false, @JsonKey(name: 'update_products') this.updateProducts = false, @JsonKey(name: 'convert_products') this.convertProducts = false, @JsonKey(name: 'convert_rate_to_client') this.convertRateToClient = false, @JsonKey(name: 'stop_on_unpaid_recurring') this.stopOnUnpaidRecurring = false, @JsonKey(name: 'use_quote_terms_on_conversion') this.useQuoteTermsOnConversion = false, @JsonKey(name: 'google_analytics_key') this.googleAnalyticsKey = '', @JsonKey(name: 'matomo_id') this.matomoId = '', @JsonKey(name: 'matomo_url') this.matomoUrl = '', @JsonKey(name: 'session_timeout') this.sessionTimeout = 0, @JsonKey(name: 'default_password_timeout') this.defaultPasswordTimeout = 0, @JsonKey(name: 'oauth_password_required') this.oauthPasswordRequired = false, @JsonKey(name: 'is_disabled') this.isDisabled = false, @JsonKey(name: 'markdown_enabled') this.markdownEnabled = false, @JsonKey(name: 'markdown_email_enabled') this.markdownEmailEnabled = false, @JsonKey(name: 'report_include_drafts') this.reportIncludeDrafts = false, @JsonKey(name: 'report_include_deleted') this.reportIncludeDeleted = false, @JsonKey(name: 'quickbooks')  Map<String, dynamic>? quickbooks, @JsonKey(name: 'smtp_host') this.smtpHost = '', @JsonKey(name: 'smtp_port') this.smtpPort = 0, @JsonKey(name: 'smtp_encryption') this.smtpEncryption = 'TLS', @JsonKey(name: 'smtp_username') this.smtpUsername = '', @JsonKey(name: 'smtp_password') this.smtpPassword = '', @JsonKey(name: 'smtp_local_domain') this.smtpLocalDomain = '', @JsonKey(name: 'smtp_verify_peer') this.smtpVerifyPeer = true, @JsonKey(name: 'expense_mailbox') this.expenseMailbox = '', @JsonKey(name: 'expense_mailbox_active') this.expenseMailboxActive = false, @JsonKey(name: 'inbound_mailbox_allow_company_users') this.inboundMailboxAllowCompanyUsers = false, @JsonKey(name: 'inbound_mailbox_allow_vendors') this.inboundMailboxAllowVendors = false, @JsonKey(name: 'inbound_mailbox_allow_clients') this.inboundMailboxAllowClients = false, @JsonKey(name: 'inbound_mailbox_allow_unknown') this.inboundMailboxAllowUnknown = false, @JsonKey(name: 'inbound_mailbox_whitelist') this.inboundMailboxWhitelist = '', @JsonKey(name: 'inbound_mailbox_blacklist') this.inboundMailboxBlacklist = '', @JsonKey(name: 'expense_inclusive_taxes') this.expenseInclusiveTaxes = false, @JsonKey(name: 'calculate_expense_tax_by_amount') this.calculateExpenseTaxByAmount = false, @JsonKey(name: 'auto_start_tasks') this.autoStartTasks = false, @JsonKey(name: 'show_task_end_date') this.showTaskEndDate = false, @JsonKey(name: 'show_tasks_table') this.showTasksTable = false, @JsonKey(name: 'invoice_task_datelog') this.invoiceTaskDatelog = false, @JsonKey(name: 'invoice_task_timelog') this.invoiceTaskTimelog = false, @JsonKey(name: 'invoice_task_hours') this.invoiceTaskHours = false, @JsonKey(name: 'invoice_task_item_description') this.invoiceTaskItemDescription = false, @JsonKey(name: 'invoice_task_project') this.invoiceTaskProject = false, @JsonKey(name: 'invoice_task_project_header') this.invoiceTaskProjectHeader = false, @JsonKey(name: 'invoice_task_lock') this.invoiceTaskLock = false, @JsonKey(name: 'invoice_task_documents') this.invoiceTaskDocuments = false, @JsonKey(name: 'mark_expenses_invoiceable') this.markExpensesInvoiceable = false, @JsonKey(name: 'mark_expenses_paid') this.markExpensesPaid = false, @JsonKey(name: 'invoice_expense_documents') this.invoiceExpenseDocuments = false, @JsonKey(name: 'notify_vendor_when_paid') this.notifyVendorWhenPaid = false, @JsonKey(name: 'enable_applying_payments') this.enableApplyingPayments = false, @JsonKey(name: 'convert_payment_currency') this.convertPaymentCurrency = false, @JsonKey(name: 'convert_expense_currency') this.convertExpenseCurrency = false, @JsonKey(name: 'has_e_invoice_certificate') this.hasEInvoiceCertificate = false, @JsonKey(name: 'has_e_invoice_certificate_passphrase') this.hasEInvoiceCertificatePassphrase = false}): _clientRegistrationFields = clientRegistrationFields,_customFields = customFields,_documents = documents,_settings = settings,_users = users,_taskStatuses = taskStatuses,_companyGateways = companyGateways,_paymentTerms = paymentTerms,_taxRates = taxRates,_expenseCategories = expenseCategories,_groups = groups,_bankTransactionRules = bankTransactionRules,_bankIntegrations = bankIntegrations,_webhooks = webhooks,_tokensHashed = tokensHashed,_taskSchedulers = taskSchedulers,_subscriptions = subscriptions,_designs = designs,_clients = clients,_products = products,_invoices = invoices,_recurringInvoices = recurringInvoices,_quotes = quotes,_credits = credits,_payments = payments,_tasks = tasks,_projects = projects,_expenses = expenses,_recurringExpenses = recurringExpenses,_vendors = vendors,_purchaseOrders = purchaseOrders,_bankTransactions = bankTransactions,_eInvoice = eInvoice,_quickbooks = quickbooks;
  factory _CompanyEnvelopeApi.fromJson(Map<String, dynamic> json) => _$CompanyEnvelopeApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'display_name') final  String displayName;
@override@JsonKey() final  String name;
@override@JsonKey(name: 'company_key') final  String companyKey;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'subdomain') final  String subdomain;
@override@JsonKey(name: 'portal_domain') final  String portalDomain;
@override@JsonKey(name: 'portal_mode') final  String portalMode;
@override@JsonKey(name: 'client_can_register') final  bool clientCanRegister;
 final  List<ClientRegistrationFieldApi> _clientRegistrationFields;
@override@JsonKey(name: 'client_registration_fields', fromJson: _clientRegistrationFieldListData) List<ClientRegistrationFieldApi> get clientRegistrationFields {
  if (_clientRegistrationFields is EqualUnmodifiableListView) return _clientRegistrationFields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_clientRegistrationFields);
}

 final  Map<String, String> _customFields;
@override@JsonKey(name: 'custom_fields') Map<String, String> get customFields {
  if (_customFields is EqualUnmodifiableMapView) return _customFields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_customFields);
}

 final  List<DocumentApi> _documents;
@override@JsonKey(name: 'documents', fromJson: _companyDocumentListData) List<DocumentApi> get documents {
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_documents);
}

@override@JsonKey(name: 'size_id') final  String sizeId;
@override@JsonKey(name: 'industry_id') final  String industryId;
@override@JsonKey(name: 'first_month_of_year') final  String firstMonthOfYear;
@override@JsonKey(name: 'first_day_of_week') final  String firstDayOfWeek;
@override@JsonKey(name: 'use_comma_as_decimal_place') final  bool useCommaAsDecimalPlace;
@override@JsonKey(name: 'legal_entity_id') final  int legalEntityId;
@override@JsonKey(name: 'enabled_modules') final  int enabledModules;
 final  Map<String, dynamic> _settings;
@override@JsonKey() Map<String, dynamic> get settings {
  if (_settings is EqualUnmodifiableMapView) return _settings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_settings);
}

 final  List<UserApi> _users;
@override@JsonKey(name: 'users', fromJson: _bundledUserListData) List<UserApi> get users {
  if (_users is EqualUnmodifiableListView) return _users;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_users);
}

 final  List<TaskStatusApi> _taskStatuses;
@override@JsonKey(name: 'task_statuses', fromJson: _taskStatusListData) List<TaskStatusApi> get taskStatuses {
  if (_taskStatuses is EqualUnmodifiableListView) return _taskStatuses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_taskStatuses);
}

 final  List<CompanyGatewayApi> _companyGateways;
@override@JsonKey(name: 'company_gateways', fromJson: _companyGatewayListData) List<CompanyGatewayApi> get companyGateways {
  if (_companyGateways is EqualUnmodifiableListView) return _companyGateways;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_companyGateways);
}

 final  List<PaymentTermApi> _paymentTerms;
@override@JsonKey(name: 'payment_terms', fromJson: _paymentTermListData) List<PaymentTermApi> get paymentTerms {
  if (_paymentTerms is EqualUnmodifiableListView) return _paymentTerms;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_paymentTerms);
}

 final  List<TaxRateApi> _taxRates;
@override@JsonKey(name: 'tax_rates', fromJson: _taxRateListData) List<TaxRateApi> get taxRates {
  if (_taxRates is EqualUnmodifiableListView) return _taxRates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_taxRates);
}

 final  List<ExpenseCategoryApi> _expenseCategories;
@override@JsonKey(name: 'expense_categories', fromJson: _expenseCategoryListData) List<ExpenseCategoryApi> get expenseCategories {
  if (_expenseCategories is EqualUnmodifiableListView) return _expenseCategories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_expenseCategories);
}

 final  List<GroupSettingApi> _groups;
@override@JsonKey(name: 'groups', fromJson: _groupSettingListData) List<GroupSettingApi> get groups {
  if (_groups is EqualUnmodifiableListView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_groups);
}

 final  List<TransactionRuleApi> _bankTransactionRules;
@override@JsonKey(name: 'bank_transaction_rules', fromJson: _transactionRuleListData) List<TransactionRuleApi> get bankTransactionRules {
  if (_bankTransactionRules is EqualUnmodifiableListView) return _bankTransactionRules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bankTransactionRules);
}

 final  List<BankAccountApi> _bankIntegrations;
@override@JsonKey(name: 'bank_integrations', fromJson: _bankIntegrationListData) List<BankAccountApi> get bankIntegrations {
  if (_bankIntegrations is EqualUnmodifiableListView) return _bankIntegrations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bankIntegrations);
}

 final  List<WebhookApi> _webhooks;
@override@JsonKey(name: 'webhooks', fromJson: _webhookListData) List<WebhookApi> get webhooks {
  if (_webhooks is EqualUnmodifiableListView) return _webhooks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_webhooks);
}

 final  List<TokenApi> _tokensHashed;
@override@JsonKey(name: 'tokens_hashed', fromJson: _tokenListData) List<TokenApi> get tokensHashed {
  if (_tokensHashed is EqualUnmodifiableListView) return _tokensHashed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tokensHashed);
}

 final  List<ScheduleApi> _taskSchedulers;
@override@JsonKey(name: 'task_schedulers', fromJson: _taskSchedulerListData) List<ScheduleApi> get taskSchedulers {
  if (_taskSchedulers is EqualUnmodifiableListView) return _taskSchedulers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_taskSchedulers);
}

 final  List<SubscriptionApi> _subscriptions;
@override@JsonKey(name: 'subscriptions', fromJson: _subscriptionListData) List<SubscriptionApi> get subscriptions {
  if (_subscriptions is EqualUnmodifiableListView) return _subscriptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_subscriptions);
}

 final  List<DesignApi> _designs;
@override@JsonKey(name: 'designs', fromJson: _designListData) List<DesignApi> get designs {
  if (_designs is EqualUnmodifiableListView) return _designs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_designs);
}

 final  List<ClientApi> _clients;
@override@JsonKey(name: 'clients', fromJson: _clientDeltaListData) List<ClientApi> get clients {
  if (_clients is EqualUnmodifiableListView) return _clients;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_clients);
}

 final  List<ProductApi> _products;
@override@JsonKey(name: 'products', fromJson: _productDeltaListData) List<ProductApi> get products {
  if (_products is EqualUnmodifiableListView) return _products;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_products);
}

 final  List<InvoiceApi> _invoices;
@override@JsonKey(name: 'invoices', fromJson: _invoiceDeltaListData) List<InvoiceApi> get invoices {
  if (_invoices is EqualUnmodifiableListView) return _invoices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_invoices);
}

 final  List<RecurringInvoiceApi> _recurringInvoices;
@override@JsonKey(name: 'recurring_invoices', fromJson: _recurringInvoiceDeltaListData) List<RecurringInvoiceApi> get recurringInvoices {
  if (_recurringInvoices is EqualUnmodifiableListView) return _recurringInvoices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recurringInvoices);
}

 final  List<QuoteApi> _quotes;
@override@JsonKey(name: 'quotes', fromJson: _quoteDeltaListData) List<QuoteApi> get quotes {
  if (_quotes is EqualUnmodifiableListView) return _quotes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_quotes);
}

 final  List<CreditApi> _credits;
@override@JsonKey(name: 'credits', fromJson: _creditDeltaListData) List<CreditApi> get credits {
  if (_credits is EqualUnmodifiableListView) return _credits;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_credits);
}

 final  List<PaymentApi> _payments;
@override@JsonKey(name: 'payments', fromJson: _paymentDeltaListData) List<PaymentApi> get payments {
  if (_payments is EqualUnmodifiableListView) return _payments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_payments);
}

 final  List<TaskApi> _tasks;
@override@JsonKey(name: 'tasks', fromJson: _taskDeltaListData) List<TaskApi> get tasks {
  if (_tasks is EqualUnmodifiableListView) return _tasks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tasks);
}

 final  List<ProjectApi> _projects;
@override@JsonKey(name: 'projects', fromJson: _projectDeltaListData) List<ProjectApi> get projects {
  if (_projects is EqualUnmodifiableListView) return _projects;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_projects);
}

 final  List<ExpenseApi> _expenses;
@override@JsonKey(name: 'expenses', fromJson: _expenseDeltaListData) List<ExpenseApi> get expenses {
  if (_expenses is EqualUnmodifiableListView) return _expenses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_expenses);
}

 final  List<RecurringExpenseApi> _recurringExpenses;
@override@JsonKey(name: 'recurring_expenses', fromJson: _recurringExpenseDeltaListData) List<RecurringExpenseApi> get recurringExpenses {
  if (_recurringExpenses is EqualUnmodifiableListView) return _recurringExpenses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recurringExpenses);
}

 final  List<VendorApi> _vendors;
@override@JsonKey(name: 'vendors', fromJson: _vendorDeltaListData) List<VendorApi> get vendors {
  if (_vendors is EqualUnmodifiableListView) return _vendors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_vendors);
}

 final  List<PurchaseOrderApi> _purchaseOrders;
@override@JsonKey(name: 'purchase_orders', fromJson: _purchaseOrderDeltaListData) List<PurchaseOrderApi> get purchaseOrders {
  if (_purchaseOrders is EqualUnmodifiableListView) return _purchaseOrders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_purchaseOrders);
}

 final  List<BankTransactionApi> _bankTransactions;
@override@JsonKey(name: 'bank_transactions', fromJson: _bankTransactionDeltaListData) List<BankTransactionApi> get bankTransactions {
  if (_bankTransactions is EqualUnmodifiableListView) return _bankTransactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bankTransactions);
}

@override@JsonKey(name: 'enabled_tax_rates') final  int enabledTaxRates;
@override@JsonKey(name: 'enabled_item_tax_rates') final  int enabledItemTaxRates;
@override@JsonKey(name: 'enabled_expense_tax_rates') final  int enabledExpenseTaxRates;
@override@JsonKey(name: 'calculate_taxes') final  bool calculateTaxes;
@override@JsonKey(name: 'tax_data') final  TaxConfigApi? taxData;
 final  Map<String, dynamic>? _eInvoice;
@override@JsonKey(name: 'e_invoice', includeIfNull: false) Map<String, dynamic>? get eInvoice {
  final value = _eInvoice;
  if (value == null) return null;
  if (_eInvoice is EqualUnmodifiableMapView) return _eInvoice;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'custom_surcharge_taxes1') final  bool customSurchargeTaxes1;
@override@JsonKey(name: 'custom_surcharge_taxes2') final  bool customSurchargeTaxes2;
@override@JsonKey(name: 'custom_surcharge_taxes3') final  bool customSurchargeTaxes3;
@override@JsonKey(name: 'custom_surcharge_taxes4') final  bool customSurchargeTaxes4;
@override@JsonKey(name: 'track_inventory') final  bool trackInventory;
@override@JsonKey(name: 'stock_notification') final  bool stockNotification;
@override@JsonKey(name: 'inventory_notification_threshold') final  int inventoryNotificationThreshold;
@override@JsonKey(name: 'enable_product_discount') final  bool enableProductDiscount;
@override@JsonKey(name: 'enable_product_cost') final  bool enableProductCost;
@override@JsonKey(name: 'enable_product_quantity') final  bool enableProductQuantity;
@override@JsonKey(name: 'default_quantity') final  bool defaultQuantity;
@override@JsonKey(name: 'show_product_details') final  bool showProductDetails;
@override@JsonKey(name: 'fill_products') final  bool fillProducts;
@override@JsonKey(name: 'update_products') final  bool updateProducts;
@override@JsonKey(name: 'convert_products') final  bool convertProducts;
@override@JsonKey(name: 'convert_rate_to_client') final  bool convertRateToClient;
@override@JsonKey(name: 'stop_on_unpaid_recurring') final  bool stopOnUnpaidRecurring;
@override@JsonKey(name: 'use_quote_terms_on_conversion') final  bool useQuoteTermsOnConversion;
@override@JsonKey(name: 'google_analytics_key') final  String googleAnalyticsKey;
@override@JsonKey(name: 'matomo_id') final  String matomoId;
@override@JsonKey(name: 'matomo_url') final  String matomoUrl;
@override@JsonKey(name: 'session_timeout') final  int sessionTimeout;
@override@JsonKey(name: 'default_password_timeout') final  int defaultPasswordTimeout;
@override@JsonKey(name: 'oauth_password_required') final  bool oauthPasswordRequired;
@override@JsonKey(name: 'is_disabled') final  bool isDisabled;
@override@JsonKey(name: 'markdown_enabled') final  bool markdownEnabled;
@override@JsonKey(name: 'markdown_email_enabled') final  bool markdownEmailEnabled;
@override@JsonKey(name: 'report_include_drafts') final  bool reportIncludeDrafts;
@override@JsonKey(name: 'report_include_deleted') final  bool reportIncludeDeleted;
 final  Map<String, dynamic>? _quickbooks;
@override@JsonKey(name: 'quickbooks') Map<String, dynamic>? get quickbooks {
  final value = _quickbooks;
  if (value == null) return null;
  if (_quickbooks is EqualUnmodifiableMapView) return _quickbooks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'smtp_host') final  String smtpHost;
@override@JsonKey(name: 'smtp_port') final  int smtpPort;
@override@JsonKey(name: 'smtp_encryption') final  String smtpEncryption;
@override@JsonKey(name: 'smtp_username') final  String smtpUsername;
@override@JsonKey(name: 'smtp_password') final  String smtpPassword;
@override@JsonKey(name: 'smtp_local_domain') final  String smtpLocalDomain;
@override@JsonKey(name: 'smtp_verify_peer') final  bool smtpVerifyPeer;
@override@JsonKey(name: 'expense_mailbox') final  String expenseMailbox;
@override@JsonKey(name: 'expense_mailbox_active') final  bool expenseMailboxActive;
@override@JsonKey(name: 'inbound_mailbox_allow_company_users') final  bool inboundMailboxAllowCompanyUsers;
@override@JsonKey(name: 'inbound_mailbox_allow_vendors') final  bool inboundMailboxAllowVendors;
@override@JsonKey(name: 'inbound_mailbox_allow_clients') final  bool inboundMailboxAllowClients;
@override@JsonKey(name: 'inbound_mailbox_allow_unknown') final  bool inboundMailboxAllowUnknown;
@override@JsonKey(name: 'inbound_mailbox_whitelist') final  String inboundMailboxWhitelist;
@override@JsonKey(name: 'inbound_mailbox_blacklist') final  String inboundMailboxBlacklist;
@override@JsonKey(name: 'expense_inclusive_taxes') final  bool expenseInclusiveTaxes;
@override@JsonKey(name: 'calculate_expense_tax_by_amount') final  bool calculateExpenseTaxByAmount;
@override@JsonKey(name: 'auto_start_tasks') final  bool autoStartTasks;
@override@JsonKey(name: 'show_task_end_date') final  bool showTaskEndDate;
@override@JsonKey(name: 'show_tasks_table') final  bool showTasksTable;
@override@JsonKey(name: 'invoice_task_datelog') final  bool invoiceTaskDatelog;
@override@JsonKey(name: 'invoice_task_timelog') final  bool invoiceTaskTimelog;
@override@JsonKey(name: 'invoice_task_hours') final  bool invoiceTaskHours;
@override@JsonKey(name: 'invoice_task_item_description') final  bool invoiceTaskItemDescription;
@override@JsonKey(name: 'invoice_task_project') final  bool invoiceTaskProject;
@override@JsonKey(name: 'invoice_task_project_header') final  bool invoiceTaskProjectHeader;
@override@JsonKey(name: 'invoice_task_lock') final  bool invoiceTaskLock;
@override@JsonKey(name: 'invoice_task_documents') final  bool invoiceTaskDocuments;
@override@JsonKey(name: 'mark_expenses_invoiceable') final  bool markExpensesInvoiceable;
@override@JsonKey(name: 'mark_expenses_paid') final  bool markExpensesPaid;
@override@JsonKey(name: 'invoice_expense_documents') final  bool invoiceExpenseDocuments;
@override@JsonKey(name: 'notify_vendor_when_paid') final  bool notifyVendorWhenPaid;
@override@JsonKey(name: 'enable_applying_payments') final  bool enableApplyingPayments;
@override@JsonKey(name: 'convert_payment_currency') final  bool convertPaymentCurrency;
@override@JsonKey(name: 'convert_expense_currency') final  bool convertExpenseCurrency;
@override@JsonKey(name: 'has_e_invoice_certificate') final  bool hasEInvoiceCertificate;
@override@JsonKey(name: 'has_e_invoice_certificate_passphrase') final  bool hasEInvoiceCertificatePassphrase;

/// Create a copy of CompanyEnvelopeApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyEnvelopeApiCopyWith<_CompanyEnvelopeApi> get copyWith => __$CompanyEnvelopeApiCopyWithImpl<_CompanyEnvelopeApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanyEnvelopeApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompanyEnvelopeApi&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.name, name) || other.name == name)&&(identical(other.companyKey, companyKey) || other.companyKey == companyKey)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.subdomain, subdomain) || other.subdomain == subdomain)&&(identical(other.portalDomain, portalDomain) || other.portalDomain == portalDomain)&&(identical(other.portalMode, portalMode) || other.portalMode == portalMode)&&(identical(other.clientCanRegister, clientCanRegister) || other.clientCanRegister == clientCanRegister)&&const DeepCollectionEquality().equals(other.clientRegistrationFields, _clientRegistrationFields)&&const DeepCollectionEquality().equals(other.customFields, _customFields)&&const DeepCollectionEquality().equals(other.documents, _documents)&&(identical(other.sizeId, sizeId) || other.sizeId == sizeId)&&(identical(other.industryId, industryId) || other.industryId == industryId)&&(identical(other.firstMonthOfYear, firstMonthOfYear) || other.firstMonthOfYear == firstMonthOfYear)&&(identical(other.firstDayOfWeek, firstDayOfWeek) || other.firstDayOfWeek == firstDayOfWeek)&&(identical(other.useCommaAsDecimalPlace, useCommaAsDecimalPlace) || other.useCommaAsDecimalPlace == useCommaAsDecimalPlace)&&(identical(other.legalEntityId, legalEntityId) || other.legalEntityId == legalEntityId)&&(identical(other.enabledModules, enabledModules) || other.enabledModules == enabledModules)&&const DeepCollectionEquality().equals(other.settings, _settings)&&const DeepCollectionEquality().equals(other.users, _users)&&const DeepCollectionEquality().equals(other.taskStatuses, _taskStatuses)&&const DeepCollectionEquality().equals(other.companyGateways, _companyGateways)&&const DeepCollectionEquality().equals(other.paymentTerms, _paymentTerms)&&const DeepCollectionEquality().equals(other.taxRates, _taxRates)&&const DeepCollectionEquality().equals(other.expenseCategories, _expenseCategories)&&const DeepCollectionEquality().equals(other.groups, _groups)&&const DeepCollectionEquality().equals(other.bankTransactionRules, _bankTransactionRules)&&const DeepCollectionEquality().equals(other.bankIntegrations, _bankIntegrations)&&const DeepCollectionEquality().equals(other.webhooks, _webhooks)&&const DeepCollectionEquality().equals(other.tokensHashed, _tokensHashed)&&const DeepCollectionEquality().equals(other.taskSchedulers, _taskSchedulers)&&const DeepCollectionEquality().equals(other.subscriptions, _subscriptions)&&const DeepCollectionEquality().equals(other.designs, _designs)&&const DeepCollectionEquality().equals(other.clients, _clients)&&const DeepCollectionEquality().equals(other.products, _products)&&const DeepCollectionEquality().equals(other.invoices, _invoices)&&const DeepCollectionEquality().equals(other.recurringInvoices, _recurringInvoices)&&const DeepCollectionEquality().equals(other.quotes, _quotes)&&const DeepCollectionEquality().equals(other.credits, _credits)&&const DeepCollectionEquality().equals(other.payments, _payments)&&const DeepCollectionEquality().equals(other.tasks, _tasks)&&const DeepCollectionEquality().equals(other.projects, _projects)&&const DeepCollectionEquality().equals(other.expenses, _expenses)&&const DeepCollectionEquality().equals(other.recurringExpenses, _recurringExpenses)&&const DeepCollectionEquality().equals(other.vendors, _vendors)&&const DeepCollectionEquality().equals(other.purchaseOrders, _purchaseOrders)&&const DeepCollectionEquality().equals(other.bankTransactions, _bankTransactions)&&(identical(other.enabledTaxRates, enabledTaxRates) || other.enabledTaxRates == enabledTaxRates)&&(identical(other.enabledItemTaxRates, enabledItemTaxRates) || other.enabledItemTaxRates == enabledItemTaxRates)&&(identical(other.enabledExpenseTaxRates, enabledExpenseTaxRates) || other.enabledExpenseTaxRates == enabledExpenseTaxRates)&&(identical(other.calculateTaxes, calculateTaxes) || other.calculateTaxes == calculateTaxes)&&(identical(other.taxData, taxData) || other.taxData == taxData)&&const DeepCollectionEquality().equals(other.eInvoice, _eInvoice)&&(identical(other.customSurchargeTaxes1, customSurchargeTaxes1) || other.customSurchargeTaxes1 == customSurchargeTaxes1)&&(identical(other.customSurchargeTaxes2, customSurchargeTaxes2) || other.customSurchargeTaxes2 == customSurchargeTaxes2)&&(identical(other.customSurchargeTaxes3, customSurchargeTaxes3) || other.customSurchargeTaxes3 == customSurchargeTaxes3)&&(identical(other.customSurchargeTaxes4, customSurchargeTaxes4) || other.customSurchargeTaxes4 == customSurchargeTaxes4)&&(identical(other.trackInventory, trackInventory) || other.trackInventory == trackInventory)&&(identical(other.stockNotification, stockNotification) || other.stockNotification == stockNotification)&&(identical(other.inventoryNotificationThreshold, inventoryNotificationThreshold) || other.inventoryNotificationThreshold == inventoryNotificationThreshold)&&(identical(other.enableProductDiscount, enableProductDiscount) || other.enableProductDiscount == enableProductDiscount)&&(identical(other.enableProductCost, enableProductCost) || other.enableProductCost == enableProductCost)&&(identical(other.enableProductQuantity, enableProductQuantity) || other.enableProductQuantity == enableProductQuantity)&&(identical(other.defaultQuantity, defaultQuantity) || other.defaultQuantity == defaultQuantity)&&(identical(other.showProductDetails, showProductDetails) || other.showProductDetails == showProductDetails)&&(identical(other.fillProducts, fillProducts) || other.fillProducts == fillProducts)&&(identical(other.updateProducts, updateProducts) || other.updateProducts == updateProducts)&&(identical(other.convertProducts, convertProducts) || other.convertProducts == convertProducts)&&(identical(other.convertRateToClient, convertRateToClient) || other.convertRateToClient == convertRateToClient)&&(identical(other.stopOnUnpaidRecurring, stopOnUnpaidRecurring) || other.stopOnUnpaidRecurring == stopOnUnpaidRecurring)&&(identical(other.useQuoteTermsOnConversion, useQuoteTermsOnConversion) || other.useQuoteTermsOnConversion == useQuoteTermsOnConversion)&&(identical(other.googleAnalyticsKey, googleAnalyticsKey) || other.googleAnalyticsKey == googleAnalyticsKey)&&(identical(other.matomoId, matomoId) || other.matomoId == matomoId)&&(identical(other.matomoUrl, matomoUrl) || other.matomoUrl == matomoUrl)&&(identical(other.sessionTimeout, sessionTimeout) || other.sessionTimeout == sessionTimeout)&&(identical(other.defaultPasswordTimeout, defaultPasswordTimeout) || other.defaultPasswordTimeout == defaultPasswordTimeout)&&(identical(other.oauthPasswordRequired, oauthPasswordRequired) || other.oauthPasswordRequired == oauthPasswordRequired)&&(identical(other.isDisabled, isDisabled) || other.isDisabled == isDisabled)&&(identical(other.markdownEnabled, markdownEnabled) || other.markdownEnabled == markdownEnabled)&&(identical(other.markdownEmailEnabled, markdownEmailEnabled) || other.markdownEmailEnabled == markdownEmailEnabled)&&(identical(other.reportIncludeDrafts, reportIncludeDrafts) || other.reportIncludeDrafts == reportIncludeDrafts)&&(identical(other.reportIncludeDeleted, reportIncludeDeleted) || other.reportIncludeDeleted == reportIncludeDeleted)&&const DeepCollectionEquality().equals(other.quickbooks, _quickbooks)&&(identical(other.smtpHost, smtpHost) || other.smtpHost == smtpHost)&&(identical(other.smtpPort, smtpPort) || other.smtpPort == smtpPort)&&(identical(other.smtpEncryption, smtpEncryption) || other.smtpEncryption == smtpEncryption)&&(identical(other.smtpUsername, smtpUsername) || other.smtpUsername == smtpUsername)&&(identical(other.smtpPassword, smtpPassword) || other.smtpPassword == smtpPassword)&&(identical(other.smtpLocalDomain, smtpLocalDomain) || other.smtpLocalDomain == smtpLocalDomain)&&(identical(other.smtpVerifyPeer, smtpVerifyPeer) || other.smtpVerifyPeer == smtpVerifyPeer)&&(identical(other.expenseMailbox, expenseMailbox) || other.expenseMailbox == expenseMailbox)&&(identical(other.expenseMailboxActive, expenseMailboxActive) || other.expenseMailboxActive == expenseMailboxActive)&&(identical(other.inboundMailboxAllowCompanyUsers, inboundMailboxAllowCompanyUsers) || other.inboundMailboxAllowCompanyUsers == inboundMailboxAllowCompanyUsers)&&(identical(other.inboundMailboxAllowVendors, inboundMailboxAllowVendors) || other.inboundMailboxAllowVendors == inboundMailboxAllowVendors)&&(identical(other.inboundMailboxAllowClients, inboundMailboxAllowClients) || other.inboundMailboxAllowClients == inboundMailboxAllowClients)&&(identical(other.inboundMailboxAllowUnknown, inboundMailboxAllowUnknown) || other.inboundMailboxAllowUnknown == inboundMailboxAllowUnknown)&&(identical(other.inboundMailboxWhitelist, inboundMailboxWhitelist) || other.inboundMailboxWhitelist == inboundMailboxWhitelist)&&(identical(other.inboundMailboxBlacklist, inboundMailboxBlacklist) || other.inboundMailboxBlacklist == inboundMailboxBlacklist)&&(identical(other.expenseInclusiveTaxes, expenseInclusiveTaxes) || other.expenseInclusiveTaxes == expenseInclusiveTaxes)&&(identical(other.calculateExpenseTaxByAmount, calculateExpenseTaxByAmount) || other.calculateExpenseTaxByAmount == calculateExpenseTaxByAmount)&&(identical(other.autoStartTasks, autoStartTasks) || other.autoStartTasks == autoStartTasks)&&(identical(other.showTaskEndDate, showTaskEndDate) || other.showTaskEndDate == showTaskEndDate)&&(identical(other.showTasksTable, showTasksTable) || other.showTasksTable == showTasksTable)&&(identical(other.invoiceTaskDatelog, invoiceTaskDatelog) || other.invoiceTaskDatelog == invoiceTaskDatelog)&&(identical(other.invoiceTaskTimelog, invoiceTaskTimelog) || other.invoiceTaskTimelog == invoiceTaskTimelog)&&(identical(other.invoiceTaskHours, invoiceTaskHours) || other.invoiceTaskHours == invoiceTaskHours)&&(identical(other.invoiceTaskItemDescription, invoiceTaskItemDescription) || other.invoiceTaskItemDescription == invoiceTaskItemDescription)&&(identical(other.invoiceTaskProject, invoiceTaskProject) || other.invoiceTaskProject == invoiceTaskProject)&&(identical(other.invoiceTaskProjectHeader, invoiceTaskProjectHeader) || other.invoiceTaskProjectHeader == invoiceTaskProjectHeader)&&(identical(other.invoiceTaskLock, invoiceTaskLock) || other.invoiceTaskLock == invoiceTaskLock)&&(identical(other.invoiceTaskDocuments, invoiceTaskDocuments) || other.invoiceTaskDocuments == invoiceTaskDocuments)&&(identical(other.markExpensesInvoiceable, markExpensesInvoiceable) || other.markExpensesInvoiceable == markExpensesInvoiceable)&&(identical(other.markExpensesPaid, markExpensesPaid) || other.markExpensesPaid == markExpensesPaid)&&(identical(other.invoiceExpenseDocuments, invoiceExpenseDocuments) || other.invoiceExpenseDocuments == invoiceExpenseDocuments)&&(identical(other.notifyVendorWhenPaid, notifyVendorWhenPaid) || other.notifyVendorWhenPaid == notifyVendorWhenPaid)&&(identical(other.enableApplyingPayments, enableApplyingPayments) || other.enableApplyingPayments == enableApplyingPayments)&&(identical(other.convertPaymentCurrency, convertPaymentCurrency) || other.convertPaymentCurrency == convertPaymentCurrency)&&(identical(other.convertExpenseCurrency, convertExpenseCurrency) || other.convertExpenseCurrency == convertExpenseCurrency)&&(identical(other.hasEInvoiceCertificate, hasEInvoiceCertificate) || other.hasEInvoiceCertificate == hasEInvoiceCertificate)&&(identical(other.hasEInvoiceCertificatePassphrase, hasEInvoiceCertificatePassphrase) || other.hasEInvoiceCertificatePassphrase == hasEInvoiceCertificatePassphrase));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,displayName,name,companyKey,updatedAt,subdomain,portalDomain,portalMode,clientCanRegister,const DeepCollectionEquality().hash(_clientRegistrationFields),const DeepCollectionEquality().hash(_customFields),const DeepCollectionEquality().hash(_documents),sizeId,industryId,firstMonthOfYear,firstDayOfWeek,useCommaAsDecimalPlace,legalEntityId,enabledModules,const DeepCollectionEquality().hash(_settings),const DeepCollectionEquality().hash(_users),const DeepCollectionEquality().hash(_taskStatuses),const DeepCollectionEquality().hash(_companyGateways),const DeepCollectionEquality().hash(_paymentTerms),const DeepCollectionEquality().hash(_taxRates),const DeepCollectionEquality().hash(_expenseCategories),const DeepCollectionEquality().hash(_groups),const DeepCollectionEquality().hash(_bankTransactionRules),const DeepCollectionEquality().hash(_bankIntegrations),const DeepCollectionEquality().hash(_webhooks),const DeepCollectionEquality().hash(_tokensHashed),const DeepCollectionEquality().hash(_taskSchedulers),const DeepCollectionEquality().hash(_subscriptions),const DeepCollectionEquality().hash(_designs),const DeepCollectionEquality().hash(_clients),const DeepCollectionEquality().hash(_products),const DeepCollectionEquality().hash(_invoices),const DeepCollectionEquality().hash(_recurringInvoices),const DeepCollectionEquality().hash(_quotes),const DeepCollectionEquality().hash(_credits),const DeepCollectionEquality().hash(_payments),const DeepCollectionEquality().hash(_tasks),const DeepCollectionEquality().hash(_projects),const DeepCollectionEquality().hash(_expenses),const DeepCollectionEquality().hash(_recurringExpenses),const DeepCollectionEquality().hash(_vendors),const DeepCollectionEquality().hash(_purchaseOrders),const DeepCollectionEquality().hash(_bankTransactions),enabledTaxRates,enabledItemTaxRates,enabledExpenseTaxRates,calculateTaxes,taxData,const DeepCollectionEquality().hash(_eInvoice),customSurchargeTaxes1,customSurchargeTaxes2,customSurchargeTaxes3,customSurchargeTaxes4,trackInventory,stockNotification,inventoryNotificationThreshold,enableProductDiscount,enableProductCost,enableProductQuantity,defaultQuantity,showProductDetails,fillProducts,updateProducts,convertProducts,convertRateToClient,stopOnUnpaidRecurring,useQuoteTermsOnConversion,googleAnalyticsKey,matomoId,matomoUrl,sessionTimeout,defaultPasswordTimeout,oauthPasswordRequired,isDisabled,markdownEnabled,markdownEmailEnabled,reportIncludeDrafts,reportIncludeDeleted,const DeepCollectionEquality().hash(_quickbooks),smtpHost,smtpPort,smtpEncryption,smtpUsername,smtpPassword,smtpLocalDomain,smtpVerifyPeer,expenseMailbox,expenseMailboxActive,inboundMailboxAllowCompanyUsers,inboundMailboxAllowVendors,inboundMailboxAllowClients,inboundMailboxAllowUnknown,inboundMailboxWhitelist,inboundMailboxBlacklist,expenseInclusiveTaxes,calculateExpenseTaxByAmount,autoStartTasks,showTaskEndDate,showTasksTable,invoiceTaskDatelog,invoiceTaskTimelog,invoiceTaskHours,invoiceTaskItemDescription,invoiceTaskProject,invoiceTaskProjectHeader,invoiceTaskLock,invoiceTaskDocuments,markExpensesInvoiceable,markExpensesPaid,invoiceExpenseDocuments,notifyVendorWhenPaid,enableApplyingPayments,convertPaymentCurrency,convertExpenseCurrency,hasEInvoiceCertificate,hasEInvoiceCertificatePassphrase]);
}

@override
String toString() {
    return 'CompanyEnvelopeApi(id: $id, displayName: $displayName, name: $name, companyKey: $companyKey, updatedAt: $updatedAt, subdomain: $subdomain, portalDomain: $portalDomain, portalMode: $portalMode, clientCanRegister: $clientCanRegister, clientRegistrationFields: $clientRegistrationFields, customFields: $customFields, documents: $documents, sizeId: $sizeId, industryId: $industryId, firstMonthOfYear: $firstMonthOfYear, firstDayOfWeek: $firstDayOfWeek, useCommaAsDecimalPlace: $useCommaAsDecimalPlace, legalEntityId: $legalEntityId, enabledModules: $enabledModules, settings: $settings, users: $users, taskStatuses: $taskStatuses, companyGateways: $companyGateways, paymentTerms: $paymentTerms, taxRates: $taxRates, expenseCategories: $expenseCategories, groups: $groups, bankTransactionRules: $bankTransactionRules, bankIntegrations: $bankIntegrations, webhooks: $webhooks, tokensHashed: $tokensHashed, taskSchedulers: $taskSchedulers, subscriptions: $subscriptions, designs: $designs, clients: $clients, products: $products, invoices: $invoices, recurringInvoices: $recurringInvoices, quotes: $quotes, credits: $credits, payments: $payments, tasks: $tasks, projects: $projects, expenses: $expenses, recurringExpenses: $recurringExpenses, vendors: $vendors, purchaseOrders: $purchaseOrders, bankTransactions: $bankTransactions, enabledTaxRates: $enabledTaxRates, enabledItemTaxRates: $enabledItemTaxRates, enabledExpenseTaxRates: $enabledExpenseTaxRates, calculateTaxes: $calculateTaxes, taxData: $taxData, eInvoice: $eInvoice, customSurchargeTaxes1: $customSurchargeTaxes1, customSurchargeTaxes2: $customSurchargeTaxes2, customSurchargeTaxes3: $customSurchargeTaxes3, customSurchargeTaxes4: $customSurchargeTaxes4, trackInventory: $trackInventory, stockNotification: $stockNotification, inventoryNotificationThreshold: $inventoryNotificationThreshold, enableProductDiscount: $enableProductDiscount, enableProductCost: $enableProductCost, enableProductQuantity: $enableProductQuantity, defaultQuantity: $defaultQuantity, showProductDetails: $showProductDetails, fillProducts: $fillProducts, updateProducts: $updateProducts, convertProducts: $convertProducts, convertRateToClient: $convertRateToClient, stopOnUnpaidRecurring: $stopOnUnpaidRecurring, useQuoteTermsOnConversion: $useQuoteTermsOnConversion, googleAnalyticsKey: $googleAnalyticsKey, matomoId: $matomoId, matomoUrl: $matomoUrl, sessionTimeout: $sessionTimeout, defaultPasswordTimeout: $defaultPasswordTimeout, oauthPasswordRequired: $oauthPasswordRequired, isDisabled: $isDisabled, markdownEnabled: $markdownEnabled, markdownEmailEnabled: $markdownEmailEnabled, reportIncludeDrafts: $reportIncludeDrafts, reportIncludeDeleted: $reportIncludeDeleted, quickbooks: $quickbooks, smtpHost: $smtpHost, smtpPort: $smtpPort, smtpEncryption: $smtpEncryption, smtpUsername: $smtpUsername, smtpPassword: $smtpPassword, smtpLocalDomain: $smtpLocalDomain, smtpVerifyPeer: $smtpVerifyPeer, expenseMailbox: $expenseMailbox, expenseMailboxActive: $expenseMailboxActive, inboundMailboxAllowCompanyUsers: $inboundMailboxAllowCompanyUsers, inboundMailboxAllowVendors: $inboundMailboxAllowVendors, inboundMailboxAllowClients: $inboundMailboxAllowClients, inboundMailboxAllowUnknown: $inboundMailboxAllowUnknown, inboundMailboxWhitelist: $inboundMailboxWhitelist, inboundMailboxBlacklist: $inboundMailboxBlacklist, expenseInclusiveTaxes: $expenseInclusiveTaxes, calculateExpenseTaxByAmount: $calculateExpenseTaxByAmount, autoStartTasks: $autoStartTasks, showTaskEndDate: $showTaskEndDate, showTasksTable: $showTasksTable, invoiceTaskDatelog: $invoiceTaskDatelog, invoiceTaskTimelog: $invoiceTaskTimelog, invoiceTaskHours: $invoiceTaskHours, invoiceTaskItemDescription: $invoiceTaskItemDescription, invoiceTaskProject: $invoiceTaskProject, invoiceTaskProjectHeader: $invoiceTaskProjectHeader, invoiceTaskLock: $invoiceTaskLock, invoiceTaskDocuments: $invoiceTaskDocuments, markExpensesInvoiceable: $markExpensesInvoiceable, markExpensesPaid: $markExpensesPaid, invoiceExpenseDocuments: $invoiceExpenseDocuments, notifyVendorWhenPaid: $notifyVendorWhenPaid, enableApplyingPayments: $enableApplyingPayments, convertPaymentCurrency: $convertPaymentCurrency, convertExpenseCurrency: $convertExpenseCurrency, hasEInvoiceCertificate: $hasEInvoiceCertificate, hasEInvoiceCertificatePassphrase: $hasEInvoiceCertificatePassphrase)';
}


}

/// @nodoc
abstract mixin class _$CompanyEnvelopeApiCopyWith<$Res> implements $CompanyEnvelopeApiCopyWith<$Res> {
  factory _$CompanyEnvelopeApiCopyWith(_CompanyEnvelopeApi value, $Res Function(_CompanyEnvelopeApi) _then) = __$CompanyEnvelopeApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'display_name') String displayName, String name,@JsonKey(name: 'company_key') String companyKey,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'subdomain') String subdomain,@JsonKey(name: 'portal_domain') String portalDomain,@JsonKey(name: 'portal_mode') String portalMode,@JsonKey(name: 'client_can_register') bool clientCanRegister,@JsonKey(name: 'client_registration_fields', fromJson: _clientRegistrationFieldListData) List<ClientRegistrationFieldApi> clientRegistrationFields,@JsonKey(name: 'custom_fields') Map<String, String> customFields,@JsonKey(name: 'documents', fromJson: _companyDocumentListData) List<DocumentApi> documents,@JsonKey(name: 'size_id') String sizeId,@JsonKey(name: 'industry_id') String industryId,@JsonKey(name: 'first_month_of_year') String firstMonthOfYear,@JsonKey(name: 'first_day_of_week') String firstDayOfWeek,@JsonKey(name: 'use_comma_as_decimal_place') bool useCommaAsDecimalPlace,@JsonKey(name: 'legal_entity_id') int legalEntityId,@JsonKey(name: 'enabled_modules') int enabledModules, Map<String, dynamic> settings,@JsonKey(name: 'users', fromJson: _bundledUserListData) List<UserApi> users,@JsonKey(name: 'task_statuses', fromJson: _taskStatusListData) List<TaskStatusApi> taskStatuses,@JsonKey(name: 'company_gateways', fromJson: _companyGatewayListData) List<CompanyGatewayApi> companyGateways,@JsonKey(name: 'payment_terms', fromJson: _paymentTermListData) List<PaymentTermApi> paymentTerms,@JsonKey(name: 'tax_rates', fromJson: _taxRateListData) List<TaxRateApi> taxRates,@JsonKey(name: 'expense_categories', fromJson: _expenseCategoryListData) List<ExpenseCategoryApi> expenseCategories,@JsonKey(name: 'groups', fromJson: _groupSettingListData) List<GroupSettingApi> groups,@JsonKey(name: 'bank_transaction_rules', fromJson: _transactionRuleListData) List<TransactionRuleApi> bankTransactionRules,@JsonKey(name: 'bank_integrations', fromJson: _bankIntegrationListData) List<BankAccountApi> bankIntegrations,@JsonKey(name: 'webhooks', fromJson: _webhookListData) List<WebhookApi> webhooks,@JsonKey(name: 'tokens_hashed', fromJson: _tokenListData) List<TokenApi> tokensHashed,@JsonKey(name: 'task_schedulers', fromJson: _taskSchedulerListData) List<ScheduleApi> taskSchedulers,@JsonKey(name: 'subscriptions', fromJson: _subscriptionListData) List<SubscriptionApi> subscriptions,@JsonKey(name: 'designs', fromJson: _designListData) List<DesignApi> designs,@JsonKey(name: 'clients', fromJson: _clientDeltaListData) List<ClientApi> clients,@JsonKey(name: 'products', fromJson: _productDeltaListData) List<ProductApi> products,@JsonKey(name: 'invoices', fromJson: _invoiceDeltaListData) List<InvoiceApi> invoices,@JsonKey(name: 'recurring_invoices', fromJson: _recurringInvoiceDeltaListData) List<RecurringInvoiceApi> recurringInvoices,@JsonKey(name: 'quotes', fromJson: _quoteDeltaListData) List<QuoteApi> quotes,@JsonKey(name: 'credits', fromJson: _creditDeltaListData) List<CreditApi> credits,@JsonKey(name: 'payments', fromJson: _paymentDeltaListData) List<PaymentApi> payments,@JsonKey(name: 'tasks', fromJson: _taskDeltaListData) List<TaskApi> tasks,@JsonKey(name: 'projects', fromJson: _projectDeltaListData) List<ProjectApi> projects,@JsonKey(name: 'expenses', fromJson: _expenseDeltaListData) List<ExpenseApi> expenses,@JsonKey(name: 'recurring_expenses', fromJson: _recurringExpenseDeltaListData) List<RecurringExpenseApi> recurringExpenses,@JsonKey(name: 'vendors', fromJson: _vendorDeltaListData) List<VendorApi> vendors,@JsonKey(name: 'purchase_orders', fromJson: _purchaseOrderDeltaListData) List<PurchaseOrderApi> purchaseOrders,@JsonKey(name: 'bank_transactions', fromJson: _bankTransactionDeltaListData) List<BankTransactionApi> bankTransactions,@JsonKey(name: 'enabled_tax_rates') int enabledTaxRates,@JsonKey(name: 'enabled_item_tax_rates') int enabledItemTaxRates,@JsonKey(name: 'enabled_expense_tax_rates') int enabledExpenseTaxRates,@JsonKey(name: 'calculate_taxes') bool calculateTaxes,@JsonKey(name: 'tax_data') TaxConfigApi? taxData,@JsonKey(name: 'e_invoice', includeIfNull: false) Map<String, dynamic>? eInvoice,@JsonKey(name: 'custom_surcharge_taxes1') bool customSurchargeTaxes1,@JsonKey(name: 'custom_surcharge_taxes2') bool customSurchargeTaxes2,@JsonKey(name: 'custom_surcharge_taxes3') bool customSurchargeTaxes3,@JsonKey(name: 'custom_surcharge_taxes4') bool customSurchargeTaxes4,@JsonKey(name: 'track_inventory') bool trackInventory,@JsonKey(name: 'stock_notification') bool stockNotification,@JsonKey(name: 'inventory_notification_threshold') int inventoryNotificationThreshold,@JsonKey(name: 'enable_product_discount') bool enableProductDiscount,@JsonKey(name: 'enable_product_cost') bool enableProductCost,@JsonKey(name: 'enable_product_quantity') bool enableProductQuantity,@JsonKey(name: 'default_quantity') bool defaultQuantity,@JsonKey(name: 'show_product_details') bool showProductDetails,@JsonKey(name: 'fill_products') bool fillProducts,@JsonKey(name: 'update_products') bool updateProducts,@JsonKey(name: 'convert_products') bool convertProducts,@JsonKey(name: 'convert_rate_to_client') bool convertRateToClient,@JsonKey(name: 'stop_on_unpaid_recurring') bool stopOnUnpaidRecurring,@JsonKey(name: 'use_quote_terms_on_conversion') bool useQuoteTermsOnConversion,@JsonKey(name: 'google_analytics_key') String googleAnalyticsKey,@JsonKey(name: 'matomo_id') String matomoId,@JsonKey(name: 'matomo_url') String matomoUrl,@JsonKey(name: 'session_timeout') int sessionTimeout,@JsonKey(name: 'default_password_timeout') int defaultPasswordTimeout,@JsonKey(name: 'oauth_password_required') bool oauthPasswordRequired,@JsonKey(name: 'is_disabled') bool isDisabled,@JsonKey(name: 'markdown_enabled') bool markdownEnabled,@JsonKey(name: 'markdown_email_enabled') bool markdownEmailEnabled,@JsonKey(name: 'report_include_drafts') bool reportIncludeDrafts,@JsonKey(name: 'report_include_deleted') bool reportIncludeDeleted,@JsonKey(name: 'quickbooks') Map<String, dynamic>? quickbooks,@JsonKey(name: 'smtp_host') String smtpHost,@JsonKey(name: 'smtp_port') int smtpPort,@JsonKey(name: 'smtp_encryption') String smtpEncryption,@JsonKey(name: 'smtp_username') String smtpUsername,@JsonKey(name: 'smtp_password') String smtpPassword,@JsonKey(name: 'smtp_local_domain') String smtpLocalDomain,@JsonKey(name: 'smtp_verify_peer') bool smtpVerifyPeer,@JsonKey(name: 'expense_mailbox') String expenseMailbox,@JsonKey(name: 'expense_mailbox_active') bool expenseMailboxActive,@JsonKey(name: 'inbound_mailbox_allow_company_users') bool inboundMailboxAllowCompanyUsers,@JsonKey(name: 'inbound_mailbox_allow_vendors') bool inboundMailboxAllowVendors,@JsonKey(name: 'inbound_mailbox_allow_clients') bool inboundMailboxAllowClients,@JsonKey(name: 'inbound_mailbox_allow_unknown') bool inboundMailboxAllowUnknown,@JsonKey(name: 'inbound_mailbox_whitelist') String inboundMailboxWhitelist,@JsonKey(name: 'inbound_mailbox_blacklist') String inboundMailboxBlacklist,@JsonKey(name: 'expense_inclusive_taxes') bool expenseInclusiveTaxes,@JsonKey(name: 'calculate_expense_tax_by_amount') bool calculateExpenseTaxByAmount,@JsonKey(name: 'auto_start_tasks') bool autoStartTasks,@JsonKey(name: 'show_task_end_date') bool showTaskEndDate,@JsonKey(name: 'show_tasks_table') bool showTasksTable,@JsonKey(name: 'invoice_task_datelog') bool invoiceTaskDatelog,@JsonKey(name: 'invoice_task_timelog') bool invoiceTaskTimelog,@JsonKey(name: 'invoice_task_hours') bool invoiceTaskHours,@JsonKey(name: 'invoice_task_item_description') bool invoiceTaskItemDescription,@JsonKey(name: 'invoice_task_project') bool invoiceTaskProject,@JsonKey(name: 'invoice_task_project_header') bool invoiceTaskProjectHeader,@JsonKey(name: 'invoice_task_lock') bool invoiceTaskLock,@JsonKey(name: 'invoice_task_documents') bool invoiceTaskDocuments,@JsonKey(name: 'mark_expenses_invoiceable') bool markExpensesInvoiceable,@JsonKey(name: 'mark_expenses_paid') bool markExpensesPaid,@JsonKey(name: 'invoice_expense_documents') bool invoiceExpenseDocuments,@JsonKey(name: 'notify_vendor_when_paid') bool notifyVendorWhenPaid,@JsonKey(name: 'enable_applying_payments') bool enableApplyingPayments,@JsonKey(name: 'convert_payment_currency') bool convertPaymentCurrency,@JsonKey(name: 'convert_expense_currency') bool convertExpenseCurrency,@JsonKey(name: 'has_e_invoice_certificate') bool hasEInvoiceCertificate,@JsonKey(name: 'has_e_invoice_certificate_passphrase') bool hasEInvoiceCertificatePassphrase
});


@override $TaxConfigApiCopyWith<$Res>? get taxData;

}
/// @nodoc
class __$CompanyEnvelopeApiCopyWithImpl<$Res>
    implements _$CompanyEnvelopeApiCopyWith<$Res> {
  __$CompanyEnvelopeApiCopyWithImpl(this._self, this._then);

  final _CompanyEnvelopeApi _self;
  final $Res Function(_CompanyEnvelopeApi) _then;

/// Create a copy of CompanyEnvelopeApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? name = null,Object? companyKey = null,Object? updatedAt = null,Object? subdomain = null,Object? portalDomain = null,Object? portalMode = null,Object? clientCanRegister = null,Object? clientRegistrationFields = null,Object? customFields = null,Object? documents = null,Object? sizeId = null,Object? industryId = null,Object? firstMonthOfYear = null,Object? firstDayOfWeek = null,Object? useCommaAsDecimalPlace = null,Object? legalEntityId = null,Object? enabledModules = null,Object? settings = null,Object? users = null,Object? taskStatuses = null,Object? companyGateways = null,Object? paymentTerms = null,Object? taxRates = null,Object? expenseCategories = null,Object? groups = null,Object? bankTransactionRules = null,Object? bankIntegrations = null,Object? webhooks = null,Object? tokensHashed = null,Object? taskSchedulers = null,Object? subscriptions = null,Object? designs = null,Object? clients = null,Object? products = null,Object? invoices = null,Object? recurringInvoices = null,Object? quotes = null,Object? credits = null,Object? payments = null,Object? tasks = null,Object? projects = null,Object? expenses = null,Object? recurringExpenses = null,Object? vendors = null,Object? purchaseOrders = null,Object? bankTransactions = null,Object? enabledTaxRates = null,Object? enabledItemTaxRates = null,Object? enabledExpenseTaxRates = null,Object? calculateTaxes = null,Object? taxData = freezed,Object? eInvoice = freezed,Object? customSurchargeTaxes1 = null,Object? customSurchargeTaxes2 = null,Object? customSurchargeTaxes3 = null,Object? customSurchargeTaxes4 = null,Object? trackInventory = null,Object? stockNotification = null,Object? inventoryNotificationThreshold = null,Object? enableProductDiscount = null,Object? enableProductCost = null,Object? enableProductQuantity = null,Object? defaultQuantity = null,Object? showProductDetails = null,Object? fillProducts = null,Object? updateProducts = null,Object? convertProducts = null,Object? convertRateToClient = null,Object? stopOnUnpaidRecurring = null,Object? useQuoteTermsOnConversion = null,Object? googleAnalyticsKey = null,Object? matomoId = null,Object? matomoUrl = null,Object? sessionTimeout = null,Object? defaultPasswordTimeout = null,Object? oauthPasswordRequired = null,Object? isDisabled = null,Object? markdownEnabled = null,Object? markdownEmailEnabled = null,Object? reportIncludeDrafts = null,Object? reportIncludeDeleted = null,Object? quickbooks = freezed,Object? smtpHost = null,Object? smtpPort = null,Object? smtpEncryption = null,Object? smtpUsername = null,Object? smtpPassword = null,Object? smtpLocalDomain = null,Object? smtpVerifyPeer = null,Object? expenseMailbox = null,Object? expenseMailboxActive = null,Object? inboundMailboxAllowCompanyUsers = null,Object? inboundMailboxAllowVendors = null,Object? inboundMailboxAllowClients = null,Object? inboundMailboxAllowUnknown = null,Object? inboundMailboxWhitelist = null,Object? inboundMailboxBlacklist = null,Object? expenseInclusiveTaxes = null,Object? calculateExpenseTaxByAmount = null,Object? autoStartTasks = null,Object? showTaskEndDate = null,Object? showTasksTable = null,Object? invoiceTaskDatelog = null,Object? invoiceTaskTimelog = null,Object? invoiceTaskHours = null,Object? invoiceTaskItemDescription = null,Object? invoiceTaskProject = null,Object? invoiceTaskProjectHeader = null,Object? invoiceTaskLock = null,Object? invoiceTaskDocuments = null,Object? markExpensesInvoiceable = null,Object? markExpensesPaid = null,Object? invoiceExpenseDocuments = null,Object? notifyVendorWhenPaid = null,Object? enableApplyingPayments = null,Object? convertPaymentCurrency = null,Object? convertExpenseCurrency = null,Object? hasEInvoiceCertificate = null,Object? hasEInvoiceCertificatePassphrase = null,}) {
  return _then(_CompanyEnvelopeApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,companyKey: null == companyKey ? _self.companyKey : companyKey // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,subdomain: null == subdomain ? _self.subdomain : subdomain // ignore: cast_nullable_to_non_nullable
as String,portalDomain: null == portalDomain ? _self.portalDomain : portalDomain // ignore: cast_nullable_to_non_nullable
as String,portalMode: null == portalMode ? _self.portalMode : portalMode // ignore: cast_nullable_to_non_nullable
as String,clientCanRegister: null == clientCanRegister ? _self.clientCanRegister : clientCanRegister // ignore: cast_nullable_to_non_nullable
as bool,clientRegistrationFields: null == clientRegistrationFields ? _self._clientRegistrationFields : clientRegistrationFields // ignore: cast_nullable_to_non_nullable
as List<ClientRegistrationFieldApi>,customFields: null == customFields ? _self._customFields : customFields // ignore: cast_nullable_to_non_nullable
as Map<String, String>,documents: null == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>,sizeId: null == sizeId ? _self.sizeId : sizeId // ignore: cast_nullable_to_non_nullable
as String,industryId: null == industryId ? _self.industryId : industryId // ignore: cast_nullable_to_non_nullable
as String,firstMonthOfYear: null == firstMonthOfYear ? _self.firstMonthOfYear : firstMonthOfYear // ignore: cast_nullable_to_non_nullable
as String,firstDayOfWeek: null == firstDayOfWeek ? _self.firstDayOfWeek : firstDayOfWeek // ignore: cast_nullable_to_non_nullable
as String,useCommaAsDecimalPlace: null == useCommaAsDecimalPlace ? _self.useCommaAsDecimalPlace : useCommaAsDecimalPlace // ignore: cast_nullable_to_non_nullable
as bool,legalEntityId: null == legalEntityId ? _self.legalEntityId : legalEntityId // ignore: cast_nullable_to_non_nullable
as int,enabledModules: null == enabledModules ? _self.enabledModules : enabledModules // ignore: cast_nullable_to_non_nullable
as int,settings: null == settings ? _self._settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,users: null == users ? _self._users : users // ignore: cast_nullable_to_non_nullable
as List<UserApi>,taskStatuses: null == taskStatuses ? _self._taskStatuses : taskStatuses // ignore: cast_nullable_to_non_nullable
as List<TaskStatusApi>,companyGateways: null == companyGateways ? _self._companyGateways : companyGateways // ignore: cast_nullable_to_non_nullable
as List<CompanyGatewayApi>,paymentTerms: null == paymentTerms ? _self._paymentTerms : paymentTerms // ignore: cast_nullable_to_non_nullable
as List<PaymentTermApi>,taxRates: null == taxRates ? _self._taxRates : taxRates // ignore: cast_nullable_to_non_nullable
as List<TaxRateApi>,expenseCategories: null == expenseCategories ? _self._expenseCategories : expenseCategories // ignore: cast_nullable_to_non_nullable
as List<ExpenseCategoryApi>,groups: null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as List<GroupSettingApi>,bankTransactionRules: null == bankTransactionRules ? _self._bankTransactionRules : bankTransactionRules // ignore: cast_nullable_to_non_nullable
as List<TransactionRuleApi>,bankIntegrations: null == bankIntegrations ? _self._bankIntegrations : bankIntegrations // ignore: cast_nullable_to_non_nullable
as List<BankAccountApi>,webhooks: null == webhooks ? _self._webhooks : webhooks // ignore: cast_nullable_to_non_nullable
as List<WebhookApi>,tokensHashed: null == tokensHashed ? _self._tokensHashed : tokensHashed // ignore: cast_nullable_to_non_nullable
as List<TokenApi>,taskSchedulers: null == taskSchedulers ? _self._taskSchedulers : taskSchedulers // ignore: cast_nullable_to_non_nullable
as List<ScheduleApi>,subscriptions: null == subscriptions ? _self._subscriptions : subscriptions // ignore: cast_nullable_to_non_nullable
as List<SubscriptionApi>,designs: null == designs ? _self._designs : designs // ignore: cast_nullable_to_non_nullable
as List<DesignApi>,clients: null == clients ? _self._clients : clients // ignore: cast_nullable_to_non_nullable
as List<ClientApi>,products: null == products ? _self._products : products // ignore: cast_nullable_to_non_nullable
as List<ProductApi>,invoices: null == invoices ? _self._invoices : invoices // ignore: cast_nullable_to_non_nullable
as List<InvoiceApi>,recurringInvoices: null == recurringInvoices ? _self._recurringInvoices : recurringInvoices // ignore: cast_nullable_to_non_nullable
as List<RecurringInvoiceApi>,quotes: null == quotes ? _self._quotes : quotes // ignore: cast_nullable_to_non_nullable
as List<QuoteApi>,credits: null == credits ? _self._credits : credits // ignore: cast_nullable_to_non_nullable
as List<CreditApi>,payments: null == payments ? _self._payments : payments // ignore: cast_nullable_to_non_nullable
as List<PaymentApi>,tasks: null == tasks ? _self._tasks : tasks // ignore: cast_nullable_to_non_nullable
as List<TaskApi>,projects: null == projects ? _self._projects : projects // ignore: cast_nullable_to_non_nullable
as List<ProjectApi>,expenses: null == expenses ? _self._expenses : expenses // ignore: cast_nullable_to_non_nullable
as List<ExpenseApi>,recurringExpenses: null == recurringExpenses ? _self._recurringExpenses : recurringExpenses // ignore: cast_nullable_to_non_nullable
as List<RecurringExpenseApi>,vendors: null == vendors ? _self._vendors : vendors // ignore: cast_nullable_to_non_nullable
as List<VendorApi>,purchaseOrders: null == purchaseOrders ? _self._purchaseOrders : purchaseOrders // ignore: cast_nullable_to_non_nullable
as List<PurchaseOrderApi>,bankTransactions: null == bankTransactions ? _self._bankTransactions : bankTransactions // ignore: cast_nullable_to_non_nullable
as List<BankTransactionApi>,enabledTaxRates: null == enabledTaxRates ? _self.enabledTaxRates : enabledTaxRates // ignore: cast_nullable_to_non_nullable
as int,enabledItemTaxRates: null == enabledItemTaxRates ? _self.enabledItemTaxRates : enabledItemTaxRates // ignore: cast_nullable_to_non_nullable
as int,enabledExpenseTaxRates: null == enabledExpenseTaxRates ? _self.enabledExpenseTaxRates : enabledExpenseTaxRates // ignore: cast_nullable_to_non_nullable
as int,calculateTaxes: null == calculateTaxes ? _self.calculateTaxes : calculateTaxes // ignore: cast_nullable_to_non_nullable
as bool,taxData: freezed == taxData ? _self.taxData : taxData // ignore: cast_nullable_to_non_nullable
as TaxConfigApi?,eInvoice: freezed == eInvoice ? _self._eInvoice : eInvoice // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,customSurchargeTaxes1: null == customSurchargeTaxes1 ? _self.customSurchargeTaxes1 : customSurchargeTaxes1 // ignore: cast_nullable_to_non_nullable
as bool,customSurchargeTaxes2: null == customSurchargeTaxes2 ? _self.customSurchargeTaxes2 : customSurchargeTaxes2 // ignore: cast_nullable_to_non_nullable
as bool,customSurchargeTaxes3: null == customSurchargeTaxes3 ? _self.customSurchargeTaxes3 : customSurchargeTaxes3 // ignore: cast_nullable_to_non_nullable
as bool,customSurchargeTaxes4: null == customSurchargeTaxes4 ? _self.customSurchargeTaxes4 : customSurchargeTaxes4 // ignore: cast_nullable_to_non_nullable
as bool,trackInventory: null == trackInventory ? _self.trackInventory : trackInventory // ignore: cast_nullable_to_non_nullable
as bool,stockNotification: null == stockNotification ? _self.stockNotification : stockNotification // ignore: cast_nullable_to_non_nullable
as bool,inventoryNotificationThreshold: null == inventoryNotificationThreshold ? _self.inventoryNotificationThreshold : inventoryNotificationThreshold // ignore: cast_nullable_to_non_nullable
as int,enableProductDiscount: null == enableProductDiscount ? _self.enableProductDiscount : enableProductDiscount // ignore: cast_nullable_to_non_nullable
as bool,enableProductCost: null == enableProductCost ? _self.enableProductCost : enableProductCost // ignore: cast_nullable_to_non_nullable
as bool,enableProductQuantity: null == enableProductQuantity ? _self.enableProductQuantity : enableProductQuantity // ignore: cast_nullable_to_non_nullable
as bool,defaultQuantity: null == defaultQuantity ? _self.defaultQuantity : defaultQuantity // ignore: cast_nullable_to_non_nullable
as bool,showProductDetails: null == showProductDetails ? _self.showProductDetails : showProductDetails // ignore: cast_nullable_to_non_nullable
as bool,fillProducts: null == fillProducts ? _self.fillProducts : fillProducts // ignore: cast_nullable_to_non_nullable
as bool,updateProducts: null == updateProducts ? _self.updateProducts : updateProducts // ignore: cast_nullable_to_non_nullable
as bool,convertProducts: null == convertProducts ? _self.convertProducts : convertProducts // ignore: cast_nullable_to_non_nullable
as bool,convertRateToClient: null == convertRateToClient ? _self.convertRateToClient : convertRateToClient // ignore: cast_nullable_to_non_nullable
as bool,stopOnUnpaidRecurring: null == stopOnUnpaidRecurring ? _self.stopOnUnpaidRecurring : stopOnUnpaidRecurring // ignore: cast_nullable_to_non_nullable
as bool,useQuoteTermsOnConversion: null == useQuoteTermsOnConversion ? _self.useQuoteTermsOnConversion : useQuoteTermsOnConversion // ignore: cast_nullable_to_non_nullable
as bool,googleAnalyticsKey: null == googleAnalyticsKey ? _self.googleAnalyticsKey : googleAnalyticsKey // ignore: cast_nullable_to_non_nullable
as String,matomoId: null == matomoId ? _self.matomoId : matomoId // ignore: cast_nullable_to_non_nullable
as String,matomoUrl: null == matomoUrl ? _self.matomoUrl : matomoUrl // ignore: cast_nullable_to_non_nullable
as String,sessionTimeout: null == sessionTimeout ? _self.sessionTimeout : sessionTimeout // ignore: cast_nullable_to_non_nullable
as int,defaultPasswordTimeout: null == defaultPasswordTimeout ? _self.defaultPasswordTimeout : defaultPasswordTimeout // ignore: cast_nullable_to_non_nullable
as int,oauthPasswordRequired: null == oauthPasswordRequired ? _self.oauthPasswordRequired : oauthPasswordRequired // ignore: cast_nullable_to_non_nullable
as bool,isDisabled: null == isDisabled ? _self.isDisabled : isDisabled // ignore: cast_nullable_to_non_nullable
as bool,markdownEnabled: null == markdownEnabled ? _self.markdownEnabled : markdownEnabled // ignore: cast_nullable_to_non_nullable
as bool,markdownEmailEnabled: null == markdownEmailEnabled ? _self.markdownEmailEnabled : markdownEmailEnabled // ignore: cast_nullable_to_non_nullable
as bool,reportIncludeDrafts: null == reportIncludeDrafts ? _self.reportIncludeDrafts : reportIncludeDrafts // ignore: cast_nullable_to_non_nullable
as bool,reportIncludeDeleted: null == reportIncludeDeleted ? _self.reportIncludeDeleted : reportIncludeDeleted // ignore: cast_nullable_to_non_nullable
as bool,quickbooks: freezed == quickbooks ? _self._quickbooks : quickbooks // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,smtpHost: null == smtpHost ? _self.smtpHost : smtpHost // ignore: cast_nullable_to_non_nullable
as String,smtpPort: null == smtpPort ? _self.smtpPort : smtpPort // ignore: cast_nullable_to_non_nullable
as int,smtpEncryption: null == smtpEncryption ? _self.smtpEncryption : smtpEncryption // ignore: cast_nullable_to_non_nullable
as String,smtpUsername: null == smtpUsername ? _self.smtpUsername : smtpUsername // ignore: cast_nullable_to_non_nullable
as String,smtpPassword: null == smtpPassword ? _self.smtpPassword : smtpPassword // ignore: cast_nullable_to_non_nullable
as String,smtpLocalDomain: null == smtpLocalDomain ? _self.smtpLocalDomain : smtpLocalDomain // ignore: cast_nullable_to_non_nullable
as String,smtpVerifyPeer: null == smtpVerifyPeer ? _self.smtpVerifyPeer : smtpVerifyPeer // ignore: cast_nullable_to_non_nullable
as bool,expenseMailbox: null == expenseMailbox ? _self.expenseMailbox : expenseMailbox // ignore: cast_nullable_to_non_nullable
as String,expenseMailboxActive: null == expenseMailboxActive ? _self.expenseMailboxActive : expenseMailboxActive // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxAllowCompanyUsers: null == inboundMailboxAllowCompanyUsers ? _self.inboundMailboxAllowCompanyUsers : inboundMailboxAllowCompanyUsers // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxAllowVendors: null == inboundMailboxAllowVendors ? _self.inboundMailboxAllowVendors : inboundMailboxAllowVendors // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxAllowClients: null == inboundMailboxAllowClients ? _self.inboundMailboxAllowClients : inboundMailboxAllowClients // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxAllowUnknown: null == inboundMailboxAllowUnknown ? _self.inboundMailboxAllowUnknown : inboundMailboxAllowUnknown // ignore: cast_nullable_to_non_nullable
as bool,inboundMailboxWhitelist: null == inboundMailboxWhitelist ? _self.inboundMailboxWhitelist : inboundMailboxWhitelist // ignore: cast_nullable_to_non_nullable
as String,inboundMailboxBlacklist: null == inboundMailboxBlacklist ? _self.inboundMailboxBlacklist : inboundMailboxBlacklist // ignore: cast_nullable_to_non_nullable
as String,expenseInclusiveTaxes: null == expenseInclusiveTaxes ? _self.expenseInclusiveTaxes : expenseInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,calculateExpenseTaxByAmount: null == calculateExpenseTaxByAmount ? _self.calculateExpenseTaxByAmount : calculateExpenseTaxByAmount // ignore: cast_nullable_to_non_nullable
as bool,autoStartTasks: null == autoStartTasks ? _self.autoStartTasks : autoStartTasks // ignore: cast_nullable_to_non_nullable
as bool,showTaskEndDate: null == showTaskEndDate ? _self.showTaskEndDate : showTaskEndDate // ignore: cast_nullable_to_non_nullable
as bool,showTasksTable: null == showTasksTable ? _self.showTasksTable : showTasksTable // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskDatelog: null == invoiceTaskDatelog ? _self.invoiceTaskDatelog : invoiceTaskDatelog // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskTimelog: null == invoiceTaskTimelog ? _self.invoiceTaskTimelog : invoiceTaskTimelog // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskHours: null == invoiceTaskHours ? _self.invoiceTaskHours : invoiceTaskHours // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskItemDescription: null == invoiceTaskItemDescription ? _self.invoiceTaskItemDescription : invoiceTaskItemDescription // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskProject: null == invoiceTaskProject ? _self.invoiceTaskProject : invoiceTaskProject // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskProjectHeader: null == invoiceTaskProjectHeader ? _self.invoiceTaskProjectHeader : invoiceTaskProjectHeader // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskLock: null == invoiceTaskLock ? _self.invoiceTaskLock : invoiceTaskLock // ignore: cast_nullable_to_non_nullable
as bool,invoiceTaskDocuments: null == invoiceTaskDocuments ? _self.invoiceTaskDocuments : invoiceTaskDocuments // ignore: cast_nullable_to_non_nullable
as bool,markExpensesInvoiceable: null == markExpensesInvoiceable ? _self.markExpensesInvoiceable : markExpensesInvoiceable // ignore: cast_nullable_to_non_nullable
as bool,markExpensesPaid: null == markExpensesPaid ? _self.markExpensesPaid : markExpensesPaid // ignore: cast_nullable_to_non_nullable
as bool,invoiceExpenseDocuments: null == invoiceExpenseDocuments ? _self.invoiceExpenseDocuments : invoiceExpenseDocuments // ignore: cast_nullable_to_non_nullable
as bool,notifyVendorWhenPaid: null == notifyVendorWhenPaid ? _self.notifyVendorWhenPaid : notifyVendorWhenPaid // ignore: cast_nullable_to_non_nullable
as bool,enableApplyingPayments: null == enableApplyingPayments ? _self.enableApplyingPayments : enableApplyingPayments // ignore: cast_nullable_to_non_nullable
as bool,convertPaymentCurrency: null == convertPaymentCurrency ? _self.convertPaymentCurrency : convertPaymentCurrency // ignore: cast_nullable_to_non_nullable
as bool,convertExpenseCurrency: null == convertExpenseCurrency ? _self.convertExpenseCurrency : convertExpenseCurrency // ignore: cast_nullable_to_non_nullable
as bool,hasEInvoiceCertificate: null == hasEInvoiceCertificate ? _self.hasEInvoiceCertificate : hasEInvoiceCertificate // ignore: cast_nullable_to_non_nullable
as bool,hasEInvoiceCertificatePassphrase: null == hasEInvoiceCertificatePassphrase ? _self.hasEInvoiceCertificatePassphrase : hasEInvoiceCertificatePassphrase // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of CompanyEnvelopeApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaxConfigApiCopyWith<$Res>? get taxData {
    if (_self.taxData == null) {
    return null;
  }

  return $TaxConfigApiCopyWith<$Res>(_self.taxData!, (value) {
    return _then(_self.copyWith(taxData: value));
  });
}
}


/// @nodoc
mixin _$SessionTokenApi {

 String get token; String get name;
/// Create a copy of SessionTokenApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionTokenApiCopyWith<SessionTokenApi> get copyWith => _$SessionTokenApiCopyWithImpl<SessionTokenApi>(this as SessionTokenApi, _$identity);

  /// Serializes this SessionTokenApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionTokenApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionTokenApi&&(identical(other.token, _this.token) || other.token == _this.token)&&(identical(other.name, _this.name) || other.name == _this.name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionTokenApi;
  return Object.hash(runtimeType,_this.token,_this.name);
}

@override
String toString() {
  final _this = this as SessionTokenApi;
  return 'SessionTokenApi(token: ${_this.token}, name: ${_this.name})';
}


}

/// @nodoc
abstract mixin class $SessionTokenApiCopyWith<$Res>  {
  factory $SessionTokenApiCopyWith(SessionTokenApi value, $Res Function(SessionTokenApi) _then) = _$SessionTokenApiCopyWithImpl;
@useResult
$Res call({
 String token, String name
});




}
/// @nodoc
class _$SessionTokenApiCopyWithImpl<$Res>
    implements $SessionTokenApiCopyWith<$Res> {
  _$SessionTokenApiCopyWithImpl(this._self, this._then);

  final SessionTokenApi _self;
  final $Res Function(SessionTokenApi) _then;

/// Create a copy of SessionTokenApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? name = null,}) {
  return _then(SessionTokenApi(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionTokenApi].
extension SessionTokenApiPatterns on SessionTokenApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionTokenApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionTokenApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionTokenApi value)  $default,){
final _that = this;
switch (_that) {
case _SessionTokenApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionTokenApi value)?  $default,){
final _that = this;
switch (_that) {
case _SessionTokenApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String token,  String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionTokenApi() when $default != null:
return $default(_that.token,_that.name);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String token,  String name)  $default,) {final _that = this;
switch (_that) {
case _SessionTokenApi():
return $default(_that.token,_that.name);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String token,  String name)?  $default,) {final _that = this;
switch (_that) {
case _SessionTokenApi() when $default != null:
return $default(_that.token,_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionTokenApi implements SessionTokenApi {
  const _SessionTokenApi({this.token = '', this.name = ''});
  factory _SessionTokenApi.fromJson(Map<String, dynamic> json) => _$SessionTokenApiFromJson(json);

@override@JsonKey() final  String token;
@override@JsonKey() final  String name;

/// Create a copy of SessionTokenApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionTokenApiCopyWith<_SessionTokenApi> get copyWith => __$SessionTokenApiCopyWithImpl<_SessionTokenApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionTokenApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionTokenApi&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,token,name);
}

@override
String toString() {
    return 'SessionTokenApi(token: $token, name: $name)';
}


}

/// @nodoc
abstract mixin class _$SessionTokenApiCopyWith<$Res> implements $SessionTokenApiCopyWith<$Res> {
  factory _$SessionTokenApiCopyWith(_SessionTokenApi value, $Res Function(_SessionTokenApi) _then) = __$SessionTokenApiCopyWithImpl;
@override @useResult
$Res call({
 String token, String name
});




}
/// @nodoc
class __$SessionTokenApiCopyWithImpl<$Res>
    implements _$SessionTokenApiCopyWith<$Res> {
  __$SessionTokenApiCopyWithImpl(this._self, this._then);

  final _SessionTokenApi _self;
  final $Res Function(_SessionTokenApi) _then;

/// Create a copy of SessionTokenApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? name = null,}) {
  return _then(_SessionTokenApi(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AccountEnvelopeApi {

 String get id;@JsonKey(name: 'default_company_id') String get defaultCompanyId; String get plan;@JsonKey(name: 'plan_expires') String get planExpires;@JsonKey(name: 'trial_started') String get trialStarted;@JsonKey(name: 'trial_plan') String get trialPlan;@JsonKey(name: 'num_trial_days') int get numTrialDays;@JsonKey(name: 'trial_days_left') int get trialDaysLeft;@JsonKey(name: 'has_iap_plan') bool get hasIapPlan;@JsonKey(name: 'hosted_client_count') int get hostedClientCount;@JsonKey(name: 'hosted_company_count') int get hostedCompanyCount;@JsonKey(name: 'e_invoicing_token') String get eInvoicingToken;@JsonKey(name: 'report_errors') bool get reportErrors;@JsonKey(name: 'is_premium') bool get isPremium; String get key;
/// Create a copy of AccountEnvelopeApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountEnvelopeApiCopyWith<AccountEnvelopeApi> get copyWith => _$AccountEnvelopeApiCopyWithImpl<AccountEnvelopeApi>(this as AccountEnvelopeApi, _$identity);

  /// Serializes this AccountEnvelopeApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AccountEnvelopeApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountEnvelopeApi&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.defaultCompanyId, _this.defaultCompanyId) || other.defaultCompanyId == _this.defaultCompanyId)&&(identical(other.plan, _this.plan) || other.plan == _this.plan)&&(identical(other.planExpires, _this.planExpires) || other.planExpires == _this.planExpires)&&(identical(other.trialStarted, _this.trialStarted) || other.trialStarted == _this.trialStarted)&&(identical(other.trialPlan, _this.trialPlan) || other.trialPlan == _this.trialPlan)&&(identical(other.numTrialDays, _this.numTrialDays) || other.numTrialDays == _this.numTrialDays)&&(identical(other.trialDaysLeft, _this.trialDaysLeft) || other.trialDaysLeft == _this.trialDaysLeft)&&(identical(other.hasIapPlan, _this.hasIapPlan) || other.hasIapPlan == _this.hasIapPlan)&&(identical(other.hostedClientCount, _this.hostedClientCount) || other.hostedClientCount == _this.hostedClientCount)&&(identical(other.hostedCompanyCount, _this.hostedCompanyCount) || other.hostedCompanyCount == _this.hostedCompanyCount)&&(identical(other.eInvoicingToken, _this.eInvoicingToken) || other.eInvoicingToken == _this.eInvoicingToken)&&(identical(other.reportErrors, _this.reportErrors) || other.reportErrors == _this.reportErrors)&&(identical(other.isPremium, _this.isPremium) || other.isPremium == _this.isPremium)&&(identical(other.key, _this.key) || other.key == _this.key));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AccountEnvelopeApi;
  return Object.hash(runtimeType,_this.id,_this.defaultCompanyId,_this.plan,_this.planExpires,_this.trialStarted,_this.trialPlan,_this.numTrialDays,_this.trialDaysLeft,_this.hasIapPlan,_this.hostedClientCount,_this.hostedCompanyCount,_this.eInvoicingToken,_this.reportErrors,_this.isPremium,_this.key);
}

@override
String toString() {
  final _this = this as AccountEnvelopeApi;
  return 'AccountEnvelopeApi(id: ${_this.id}, defaultCompanyId: ${_this.defaultCompanyId}, plan: ${_this.plan}, planExpires: ${_this.planExpires}, trialStarted: ${_this.trialStarted}, trialPlan: ${_this.trialPlan}, numTrialDays: ${_this.numTrialDays}, trialDaysLeft: ${_this.trialDaysLeft}, hasIapPlan: ${_this.hasIapPlan}, hostedClientCount: ${_this.hostedClientCount}, hostedCompanyCount: ${_this.hostedCompanyCount}, eInvoicingToken: ${_this.eInvoicingToken}, reportErrors: ${_this.reportErrors}, isPremium: ${_this.isPremium}, key: ${_this.key})';
}


}

/// @nodoc
abstract mixin class $AccountEnvelopeApiCopyWith<$Res>  {
  factory $AccountEnvelopeApiCopyWith(AccountEnvelopeApi value, $Res Function(AccountEnvelopeApi) _then) = _$AccountEnvelopeApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'default_company_id') String defaultCompanyId, String plan,@JsonKey(name: 'plan_expires') String planExpires,@JsonKey(name: 'trial_started') String trialStarted,@JsonKey(name: 'trial_plan') String trialPlan,@JsonKey(name: 'num_trial_days') int numTrialDays,@JsonKey(name: 'trial_days_left') int trialDaysLeft,@JsonKey(name: 'has_iap_plan') bool hasIapPlan,@JsonKey(name: 'hosted_client_count') int hostedClientCount,@JsonKey(name: 'hosted_company_count') int hostedCompanyCount,@JsonKey(name: 'e_invoicing_token') String eInvoicingToken,@JsonKey(name: 'report_errors') bool reportErrors,@JsonKey(name: 'is_premium') bool isPremium, String key
});




}
/// @nodoc
class _$AccountEnvelopeApiCopyWithImpl<$Res>
    implements $AccountEnvelopeApiCopyWith<$Res> {
  _$AccountEnvelopeApiCopyWithImpl(this._self, this._then);

  final AccountEnvelopeApi _self;
  final $Res Function(AccountEnvelopeApi) _then;

/// Create a copy of AccountEnvelopeApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? defaultCompanyId = null,Object? plan = null,Object? planExpires = null,Object? trialStarted = null,Object? trialPlan = null,Object? numTrialDays = null,Object? trialDaysLeft = null,Object? hasIapPlan = null,Object? hostedClientCount = null,Object? hostedCompanyCount = null,Object? eInvoicingToken = null,Object? reportErrors = null,Object? isPremium = null,Object? key = null,}) {
  return _then(AccountEnvelopeApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,defaultCompanyId: null == defaultCompanyId ? _self.defaultCompanyId : defaultCompanyId // ignore: cast_nullable_to_non_nullable
as String,plan: null == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as String,planExpires: null == planExpires ? _self.planExpires : planExpires // ignore: cast_nullable_to_non_nullable
as String,trialStarted: null == trialStarted ? _self.trialStarted : trialStarted // ignore: cast_nullable_to_non_nullable
as String,trialPlan: null == trialPlan ? _self.trialPlan : trialPlan // ignore: cast_nullable_to_non_nullable
as String,numTrialDays: null == numTrialDays ? _self.numTrialDays : numTrialDays // ignore: cast_nullable_to_non_nullable
as int,trialDaysLeft: null == trialDaysLeft ? _self.trialDaysLeft : trialDaysLeft // ignore: cast_nullable_to_non_nullable
as int,hasIapPlan: null == hasIapPlan ? _self.hasIapPlan : hasIapPlan // ignore: cast_nullable_to_non_nullable
as bool,hostedClientCount: null == hostedClientCount ? _self.hostedClientCount : hostedClientCount // ignore: cast_nullable_to_non_nullable
as int,hostedCompanyCount: null == hostedCompanyCount ? _self.hostedCompanyCount : hostedCompanyCount // ignore: cast_nullable_to_non_nullable
as int,eInvoicingToken: null == eInvoicingToken ? _self.eInvoicingToken : eInvoicingToken // ignore: cast_nullable_to_non_nullable
as String,reportErrors: null == reportErrors ? _self.reportErrors : reportErrors // ignore: cast_nullable_to_non_nullable
as bool,isPremium: null == isPremium ? _self.isPremium : isPremium // ignore: cast_nullable_to_non_nullable
as bool,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountEnvelopeApi].
extension AccountEnvelopeApiPatterns on AccountEnvelopeApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountEnvelopeApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountEnvelopeApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountEnvelopeApi value)  $default,){
final _that = this;
switch (_that) {
case _AccountEnvelopeApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountEnvelopeApi value)?  $default,){
final _that = this;
switch (_that) {
case _AccountEnvelopeApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'default_company_id')  String defaultCompanyId,  String plan, @JsonKey(name: 'plan_expires')  String planExpires, @JsonKey(name: 'trial_started')  String trialStarted, @JsonKey(name: 'trial_plan')  String trialPlan, @JsonKey(name: 'num_trial_days')  int numTrialDays, @JsonKey(name: 'trial_days_left')  int trialDaysLeft, @JsonKey(name: 'has_iap_plan')  bool hasIapPlan, @JsonKey(name: 'hosted_client_count')  int hostedClientCount, @JsonKey(name: 'hosted_company_count')  int hostedCompanyCount, @JsonKey(name: 'e_invoicing_token')  String eInvoicingToken, @JsonKey(name: 'report_errors')  bool reportErrors, @JsonKey(name: 'is_premium')  bool isPremium,  String key)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountEnvelopeApi() when $default != null:
return $default(_that.id,_that.defaultCompanyId,_that.plan,_that.planExpires,_that.trialStarted,_that.trialPlan,_that.numTrialDays,_that.trialDaysLeft,_that.hasIapPlan,_that.hostedClientCount,_that.hostedCompanyCount,_that.eInvoicingToken,_that.reportErrors,_that.isPremium,_that.key);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'default_company_id')  String defaultCompanyId,  String plan, @JsonKey(name: 'plan_expires')  String planExpires, @JsonKey(name: 'trial_started')  String trialStarted, @JsonKey(name: 'trial_plan')  String trialPlan, @JsonKey(name: 'num_trial_days')  int numTrialDays, @JsonKey(name: 'trial_days_left')  int trialDaysLeft, @JsonKey(name: 'has_iap_plan')  bool hasIapPlan, @JsonKey(name: 'hosted_client_count')  int hostedClientCount, @JsonKey(name: 'hosted_company_count')  int hostedCompanyCount, @JsonKey(name: 'e_invoicing_token')  String eInvoicingToken, @JsonKey(name: 'report_errors')  bool reportErrors, @JsonKey(name: 'is_premium')  bool isPremium,  String key)  $default,) {final _that = this;
switch (_that) {
case _AccountEnvelopeApi():
return $default(_that.id,_that.defaultCompanyId,_that.plan,_that.planExpires,_that.trialStarted,_that.trialPlan,_that.numTrialDays,_that.trialDaysLeft,_that.hasIapPlan,_that.hostedClientCount,_that.hostedCompanyCount,_that.eInvoicingToken,_that.reportErrors,_that.isPremium,_that.key);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'default_company_id')  String defaultCompanyId,  String plan, @JsonKey(name: 'plan_expires')  String planExpires, @JsonKey(name: 'trial_started')  String trialStarted, @JsonKey(name: 'trial_plan')  String trialPlan, @JsonKey(name: 'num_trial_days')  int numTrialDays, @JsonKey(name: 'trial_days_left')  int trialDaysLeft, @JsonKey(name: 'has_iap_plan')  bool hasIapPlan, @JsonKey(name: 'hosted_client_count')  int hostedClientCount, @JsonKey(name: 'hosted_company_count')  int hostedCompanyCount, @JsonKey(name: 'e_invoicing_token')  String eInvoicingToken, @JsonKey(name: 'report_errors')  bool reportErrors, @JsonKey(name: 'is_premium')  bool isPremium,  String key)?  $default,) {final _that = this;
switch (_that) {
case _AccountEnvelopeApi() when $default != null:
return $default(_that.id,_that.defaultCompanyId,_that.plan,_that.planExpires,_that.trialStarted,_that.trialPlan,_that.numTrialDays,_that.trialDaysLeft,_that.hasIapPlan,_that.hostedClientCount,_that.hostedCompanyCount,_that.eInvoicingToken,_that.reportErrors,_that.isPremium,_that.key);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountEnvelopeApi implements AccountEnvelopeApi {
  const _AccountEnvelopeApi({this.id = '', @JsonKey(name: 'default_company_id') this.defaultCompanyId = '', this.plan = '', @JsonKey(name: 'plan_expires') this.planExpires = '', @JsonKey(name: 'trial_started') this.trialStarted = '', @JsonKey(name: 'trial_plan') this.trialPlan = '', @JsonKey(name: 'num_trial_days') this.numTrialDays = 0, @JsonKey(name: 'trial_days_left') this.trialDaysLeft = -1, @JsonKey(name: 'has_iap_plan') this.hasIapPlan = false, @JsonKey(name: 'hosted_client_count') this.hostedClientCount = 0, @JsonKey(name: 'hosted_company_count') this.hostedCompanyCount = 0, @JsonKey(name: 'e_invoicing_token') this.eInvoicingToken = '', @JsonKey(name: 'report_errors') this.reportErrors = false, @JsonKey(name: 'is_premium') this.isPremium = false, this.key = ''});
  factory _AccountEnvelopeApi.fromJson(Map<String, dynamic> json) => _$AccountEnvelopeApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'default_company_id') final  String defaultCompanyId;
@override@JsonKey() final  String plan;
@override@JsonKey(name: 'plan_expires') final  String planExpires;
@override@JsonKey(name: 'trial_started') final  String trialStarted;
@override@JsonKey(name: 'trial_plan') final  String trialPlan;
@override@JsonKey(name: 'num_trial_days') final  int numTrialDays;
@override@JsonKey(name: 'trial_days_left') final  int trialDaysLeft;
@override@JsonKey(name: 'has_iap_plan') final  bool hasIapPlan;
@override@JsonKey(name: 'hosted_client_count') final  int hostedClientCount;
@override@JsonKey(name: 'hosted_company_count') final  int hostedCompanyCount;
@override@JsonKey(name: 'e_invoicing_token') final  String eInvoicingToken;
@override@JsonKey(name: 'report_errors') final  bool reportErrors;
@override@JsonKey(name: 'is_premium') final  bool isPremium;
@override@JsonKey() final  String key;

/// Create a copy of AccountEnvelopeApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountEnvelopeApiCopyWith<_AccountEnvelopeApi> get copyWith => __$AccountEnvelopeApiCopyWithImpl<_AccountEnvelopeApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountEnvelopeApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountEnvelopeApi&&(identical(other.id, id) || other.id == id)&&(identical(other.defaultCompanyId, defaultCompanyId) || other.defaultCompanyId == defaultCompanyId)&&(identical(other.plan, plan) || other.plan == plan)&&(identical(other.planExpires, planExpires) || other.planExpires == planExpires)&&(identical(other.trialStarted, trialStarted) || other.trialStarted == trialStarted)&&(identical(other.trialPlan, trialPlan) || other.trialPlan == trialPlan)&&(identical(other.numTrialDays, numTrialDays) || other.numTrialDays == numTrialDays)&&(identical(other.trialDaysLeft, trialDaysLeft) || other.trialDaysLeft == trialDaysLeft)&&(identical(other.hasIapPlan, hasIapPlan) || other.hasIapPlan == hasIapPlan)&&(identical(other.hostedClientCount, hostedClientCount) || other.hostedClientCount == hostedClientCount)&&(identical(other.hostedCompanyCount, hostedCompanyCount) || other.hostedCompanyCount == hostedCompanyCount)&&(identical(other.eInvoicingToken, eInvoicingToken) || other.eInvoicingToken == eInvoicingToken)&&(identical(other.reportErrors, reportErrors) || other.reportErrors == reportErrors)&&(identical(other.isPremium, isPremium) || other.isPremium == isPremium)&&(identical(other.key, key) || other.key == key));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,defaultCompanyId,plan,planExpires,trialStarted,trialPlan,numTrialDays,trialDaysLeft,hasIapPlan,hostedClientCount,hostedCompanyCount,eInvoicingToken,reportErrors,isPremium,key);
}

@override
String toString() {
    return 'AccountEnvelopeApi(id: $id, defaultCompanyId: $defaultCompanyId, plan: $plan, planExpires: $planExpires, trialStarted: $trialStarted, trialPlan: $trialPlan, numTrialDays: $numTrialDays, trialDaysLeft: $trialDaysLeft, hasIapPlan: $hasIapPlan, hostedClientCount: $hostedClientCount, hostedCompanyCount: $hostedCompanyCount, eInvoicingToken: $eInvoicingToken, reportErrors: $reportErrors, isPremium: $isPremium, key: $key)';
}


}

/// @nodoc
abstract mixin class _$AccountEnvelopeApiCopyWith<$Res> implements $AccountEnvelopeApiCopyWith<$Res> {
  factory _$AccountEnvelopeApiCopyWith(_AccountEnvelopeApi value, $Res Function(_AccountEnvelopeApi) _then) = __$AccountEnvelopeApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'default_company_id') String defaultCompanyId, String plan,@JsonKey(name: 'plan_expires') String planExpires,@JsonKey(name: 'trial_started') String trialStarted,@JsonKey(name: 'trial_plan') String trialPlan,@JsonKey(name: 'num_trial_days') int numTrialDays,@JsonKey(name: 'trial_days_left') int trialDaysLeft,@JsonKey(name: 'has_iap_plan') bool hasIapPlan,@JsonKey(name: 'hosted_client_count') int hostedClientCount,@JsonKey(name: 'hosted_company_count') int hostedCompanyCount,@JsonKey(name: 'e_invoicing_token') String eInvoicingToken,@JsonKey(name: 'report_errors') bool reportErrors,@JsonKey(name: 'is_premium') bool isPremium, String key
});




}
/// @nodoc
class __$AccountEnvelopeApiCopyWithImpl<$Res>
    implements _$AccountEnvelopeApiCopyWith<$Res> {
  __$AccountEnvelopeApiCopyWithImpl(this._self, this._then);

  final _AccountEnvelopeApi _self;
  final $Res Function(_AccountEnvelopeApi) _then;

/// Create a copy of AccountEnvelopeApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? defaultCompanyId = null,Object? plan = null,Object? planExpires = null,Object? trialStarted = null,Object? trialPlan = null,Object? numTrialDays = null,Object? trialDaysLeft = null,Object? hasIapPlan = null,Object? hostedClientCount = null,Object? hostedCompanyCount = null,Object? eInvoicingToken = null,Object? reportErrors = null,Object? isPremium = null,Object? key = null,}) {
  return _then(_AccountEnvelopeApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,defaultCompanyId: null == defaultCompanyId ? _self.defaultCompanyId : defaultCompanyId // ignore: cast_nullable_to_non_nullable
as String,plan: null == plan ? _self.plan : plan // ignore: cast_nullable_to_non_nullable
as String,planExpires: null == planExpires ? _self.planExpires : planExpires // ignore: cast_nullable_to_non_nullable
as String,trialStarted: null == trialStarted ? _self.trialStarted : trialStarted // ignore: cast_nullable_to_non_nullable
as String,trialPlan: null == trialPlan ? _self.trialPlan : trialPlan // ignore: cast_nullable_to_non_nullable
as String,numTrialDays: null == numTrialDays ? _self.numTrialDays : numTrialDays // ignore: cast_nullable_to_non_nullable
as int,trialDaysLeft: null == trialDaysLeft ? _self.trialDaysLeft : trialDaysLeft // ignore: cast_nullable_to_non_nullable
as int,hasIapPlan: null == hasIapPlan ? _self.hasIapPlan : hasIapPlan // ignore: cast_nullable_to_non_nullable
as bool,hostedClientCount: null == hostedClientCount ? _self.hostedClientCount : hostedClientCount // ignore: cast_nullable_to_non_nullable
as int,hostedCompanyCount: null == hostedCompanyCount ? _self.hostedCompanyCount : hostedCompanyCount // ignore: cast_nullable_to_non_nullable
as int,eInvoicingToken: null == eInvoicingToken ? _self.eInvoicingToken : eInvoicingToken // ignore: cast_nullable_to_non_nullable
as String,reportErrors: null == reportErrors ? _self.reportErrors : reportErrors // ignore: cast_nullable_to_non_nullable
as bool,isPremium: null == isPremium ? _self.isPremium : isPremium // ignore: cast_nullable_to_non_nullable
as bool,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
