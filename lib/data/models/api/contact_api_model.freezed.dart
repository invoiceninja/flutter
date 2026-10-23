// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'contact_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ContactApi {

 String get id;@JsonKey(name: 'first_name') String get firstName;@JsonKey(name: 'last_name') String get lastName; String get email; String get phone;@JsonKey(name: 'is_primary') bool get isPrimary;@JsonKey(name: 'send_email') bool get sendEmail;@JsonKey(name: 'cc_only') bool get ccOnly;@JsonKey(name: 'is_locked') bool get isLocked;@JsonKey(name: 'can_sign') bool get canSign; String get password;@JsonKey(name: 'contact_key') String get contactKey; String get link;@JsonKey(name: 'last_login') int get lastLogin;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;
/// Create a copy of ContactApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContactApiCopyWith<ContactApi> get copyWith => _$ContactApiCopyWithImpl<ContactApi>(this as ContactApi, _$identity);

  /// Serializes this ContactApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ContactApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ContactApi&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.firstName, _this.firstName) || other.firstName == _this.firstName)&&(identical(other.lastName, _this.lastName) || other.lastName == _this.lastName)&&(identical(other.email, _this.email) || other.email == _this.email)&&(identical(other.phone, _this.phone) || other.phone == _this.phone)&&(identical(other.isPrimary, _this.isPrimary) || other.isPrimary == _this.isPrimary)&&(identical(other.sendEmail, _this.sendEmail) || other.sendEmail == _this.sendEmail)&&(identical(other.ccOnly, _this.ccOnly) || other.ccOnly == _this.ccOnly)&&(identical(other.isLocked, _this.isLocked) || other.isLocked == _this.isLocked)&&(identical(other.canSign, _this.canSign) || other.canSign == _this.canSign)&&(identical(other.password, _this.password) || other.password == _this.password)&&(identical(other.contactKey, _this.contactKey) || other.contactKey == _this.contactKey)&&(identical(other.link, _this.link) || other.link == _this.link)&&(identical(other.lastLogin, _this.lastLogin) || other.lastLogin == _this.lastLogin)&&(identical(other.customValue1, _this.customValue1) || other.customValue1 == _this.customValue1)&&(identical(other.customValue2, _this.customValue2) || other.customValue2 == _this.customValue2)&&(identical(other.customValue3, _this.customValue3) || other.customValue3 == _this.customValue3)&&(identical(other.customValue4, _this.customValue4) || other.customValue4 == _this.customValue4)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.archivedAt, _this.archivedAt) || other.archivedAt == _this.archivedAt)&&(identical(other.isDeleted, _this.isDeleted) || other.isDeleted == _this.isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ContactApi;
  return Object.hashAll([runtimeType,_this.id,_this.firstName,_this.lastName,_this.email,_this.phone,_this.isPrimary,_this.sendEmail,_this.ccOnly,_this.isLocked,_this.canSign,_this.password,_this.contactKey,_this.link,_this.lastLogin,_this.customValue1,_this.customValue2,_this.customValue3,_this.customValue4,_this.createdAt,_this.updatedAt,_this.archivedAt,_this.isDeleted]);
}

@override
String toString() {
  final _this = this as ContactApi;
  return 'ContactApi(id: ${_this.id}, firstName: ${_this.firstName}, lastName: ${_this.lastName}, email: ${_this.email}, phone: ${_this.phone}, isPrimary: ${_this.isPrimary}, sendEmail: ${_this.sendEmail}, ccOnly: ${_this.ccOnly}, isLocked: ${_this.isLocked}, canSign: ${_this.canSign}, password: ${_this.password}, contactKey: ${_this.contactKey}, link: ${_this.link}, lastLogin: ${_this.lastLogin}, customValue1: ${_this.customValue1}, customValue2: ${_this.customValue2}, customValue3: ${_this.customValue3}, customValue4: ${_this.customValue4}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, archivedAt: ${_this.archivedAt}, isDeleted: ${_this.isDeleted})';
}


}

/// @nodoc
abstract mixin class $ContactApiCopyWith<$Res>  {
  factory $ContactApiCopyWith(ContactApi value, $Res Function(ContactApi) _then) = _$ContactApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'first_name') String firstName,@JsonKey(name: 'last_name') String lastName, String email, String phone,@JsonKey(name: 'is_primary') bool isPrimary,@JsonKey(name: 'send_email') bool sendEmail,@JsonKey(name: 'cc_only') bool ccOnly,@JsonKey(name: 'is_locked') bool isLocked,@JsonKey(name: 'can_sign') bool canSign, String password,@JsonKey(name: 'contact_key') String contactKey, String link,@JsonKey(name: 'last_login') int lastLogin,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class _$ContactApiCopyWithImpl<$Res>
    implements $ContactApiCopyWith<$Res> {
  _$ContactApiCopyWithImpl(this._self, this._then);

  final ContactApi _self;
  final $Res Function(ContactApi) _then;

/// Create a copy of ContactApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? isPrimary = null,Object? sendEmail = null,Object? ccOnly = null,Object? isLocked = null,Object? canSign = null,Object? password = null,Object? contactKey = null,Object? link = null,Object? lastLogin = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(ContactApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,sendEmail: null == sendEmail ? _self.sendEmail : sendEmail // ignore: cast_nullable_to_non_nullable
as bool,ccOnly: null == ccOnly ? _self.ccOnly : ccOnly // ignore: cast_nullable_to_non_nullable
as bool,isLocked: null == isLocked ? _self.isLocked : isLocked // ignore: cast_nullable_to_non_nullable
as bool,canSign: null == canSign ? _self.canSign : canSign // ignore: cast_nullable_to_non_nullable
as bool,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,contactKey: null == contactKey ? _self.contactKey : contactKey // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,lastLogin: null == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as int,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ContactApi].
extension ContactApiPatterns on ContactApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ContactApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ContactApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ContactApi value)  $default,){
final _that = this;
switch (_that) {
case _ContactApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ContactApi value)?  $default,){
final _that = this;
switch (_that) {
case _ContactApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'first_name')  String firstName, @JsonKey(name: 'last_name')  String lastName,  String email,  String phone, @JsonKey(name: 'is_primary')  bool isPrimary, @JsonKey(name: 'send_email')  bool sendEmail, @JsonKey(name: 'cc_only')  bool ccOnly, @JsonKey(name: 'is_locked')  bool isLocked, @JsonKey(name: 'can_sign')  bool canSign,  String password, @JsonKey(name: 'contact_key')  String contactKey,  String link, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ContactApi() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.isPrimary,_that.sendEmail,_that.ccOnly,_that.isLocked,_that.canSign,_that.password,_that.contactKey,_that.link,_that.lastLogin,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'first_name')  String firstName, @JsonKey(name: 'last_name')  String lastName,  String email,  String phone, @JsonKey(name: 'is_primary')  bool isPrimary, @JsonKey(name: 'send_email')  bool sendEmail, @JsonKey(name: 'cc_only')  bool ccOnly, @JsonKey(name: 'is_locked')  bool isLocked, @JsonKey(name: 'can_sign')  bool canSign,  String password, @JsonKey(name: 'contact_key')  String contactKey,  String link, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _ContactApi():
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.isPrimary,_that.sendEmail,_that.ccOnly,_that.isLocked,_that.canSign,_that.password,_that.contactKey,_that.link,_that.lastLogin,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'first_name')  String firstName, @JsonKey(name: 'last_name')  String lastName,  String email,  String phone, @JsonKey(name: 'is_primary')  bool isPrimary, @JsonKey(name: 'send_email')  bool sendEmail, @JsonKey(name: 'cc_only')  bool ccOnly, @JsonKey(name: 'is_locked')  bool isLocked, @JsonKey(name: 'can_sign')  bool canSign,  String password, @JsonKey(name: 'contact_key')  String contactKey,  String link, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _ContactApi() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.isPrimary,_that.sendEmail,_that.ccOnly,_that.isLocked,_that.canSign,_that.password,_that.contactKey,_that.link,_that.lastLogin,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ContactApi implements ContactApi {
  const _ContactApi({this.id = '', @JsonKey(name: 'first_name') this.firstName = '', @JsonKey(name: 'last_name') this.lastName = '', this.email = '', this.phone = '', @JsonKey(name: 'is_primary') this.isPrimary = false, @JsonKey(name: 'send_email') this.sendEmail = true, @JsonKey(name: 'cc_only') this.ccOnly = false, @JsonKey(name: 'is_locked') this.isLocked = false, @JsonKey(name: 'can_sign') this.canSign = false, this.password = '', @JsonKey(name: 'contact_key') this.contactKey = '', this.link = '', @JsonKey(name: 'last_login') this.lastLogin = 0, @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false});
  factory _ContactApi.fromJson(Map<String, dynamic> json) => _$ContactApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'first_name') final  String firstName;
@override@JsonKey(name: 'last_name') final  String lastName;
@override@JsonKey() final  String email;
@override@JsonKey() final  String phone;
@override@JsonKey(name: 'is_primary') final  bool isPrimary;
@override@JsonKey(name: 'send_email') final  bool sendEmail;
@override@JsonKey(name: 'cc_only') final  bool ccOnly;
@override@JsonKey(name: 'is_locked') final  bool isLocked;
@override@JsonKey(name: 'can_sign') final  bool canSign;
@override@JsonKey() final  String password;
@override@JsonKey(name: 'contact_key') final  String contactKey;
@override@JsonKey() final  String link;
@override@JsonKey(name: 'last_login') final  int lastLogin;
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;

/// Create a copy of ContactApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContactApiCopyWith<_ContactApi> get copyWith => __$ContactApiCopyWithImpl<_ContactApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ContactApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ContactApi&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&(identical(other.sendEmail, sendEmail) || other.sendEmail == sendEmail)&&(identical(other.ccOnly, ccOnly) || other.ccOnly == ccOnly)&&(identical(other.isLocked, isLocked) || other.isLocked == isLocked)&&(identical(other.canSign, canSign) || other.canSign == canSign)&&(identical(other.password, password) || other.password == password)&&(identical(other.contactKey, contactKey) || other.contactKey == contactKey)&&(identical(other.link, link) || other.link == link)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,firstName,lastName,email,phone,isPrimary,sendEmail,ccOnly,isLocked,canSign,password,contactKey,link,lastLogin,customValue1,customValue2,customValue3,customValue4,createdAt,updatedAt,archivedAt,isDeleted]);
}

@override
String toString() {
    return 'ContactApi(id: $id, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, isPrimary: $isPrimary, sendEmail: $sendEmail, ccOnly: $ccOnly, isLocked: $isLocked, canSign: $canSign, password: $password, contactKey: $contactKey, link: $link, lastLogin: $lastLogin, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$ContactApiCopyWith<$Res> implements $ContactApiCopyWith<$Res> {
  factory _$ContactApiCopyWith(_ContactApi value, $Res Function(_ContactApi) _then) = __$ContactApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'first_name') String firstName,@JsonKey(name: 'last_name') String lastName, String email, String phone,@JsonKey(name: 'is_primary') bool isPrimary,@JsonKey(name: 'send_email') bool sendEmail,@JsonKey(name: 'cc_only') bool ccOnly,@JsonKey(name: 'is_locked') bool isLocked,@JsonKey(name: 'can_sign') bool canSign, String password,@JsonKey(name: 'contact_key') String contactKey, String link,@JsonKey(name: 'last_login') int lastLogin,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class __$ContactApiCopyWithImpl<$Res>
    implements _$ContactApiCopyWith<$Res> {
  __$ContactApiCopyWithImpl(this._self, this._then);

  final _ContactApi _self;
  final $Res Function(_ContactApi) _then;

/// Create a copy of ContactApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? isPrimary = null,Object? sendEmail = null,Object? ccOnly = null,Object? isLocked = null,Object? canSign = null,Object? password = null,Object? contactKey = null,Object? link = null,Object? lastLogin = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_ContactApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,sendEmail: null == sendEmail ? _self.sendEmail : sendEmail // ignore: cast_nullable_to_non_nullable
as bool,ccOnly: null == ccOnly ? _self.ccOnly : ccOnly // ignore: cast_nullable_to_non_nullable
as bool,isLocked: null == isLocked ? _self.isLocked : isLocked // ignore: cast_nullable_to_non_nullable
as bool,canSign: null == canSign ? _self.canSign : canSign // ignore: cast_nullable_to_non_nullable
as bool,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,contactKey: null == contactKey ? _self.contactKey : contactKey // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,lastLogin: null == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as int,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
