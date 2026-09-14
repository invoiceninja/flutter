// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$User {

 String get id; String get firstName; String get lastName; String get email; String get phone; String get signature; String get languageId; String get oauthProviderId; String get oauthUserToken; String get oauthUserRefreshToken; bool get googleTwoFactorEnabled; bool get verifiedPhoneNumber; bool get hasPassword; bool get userLoggedInNotification; String get customValue1; String get customValue2; String get customValue3; String get customValue4; int get lastLogin; int get emailVerifiedAt;/// The address held before this user's last email change, or `''`. See
/// [looksNeverOnboarded] and `UserApi.lastConfirmedEmailAddress`.
 String get lastConfirmedEmailAddress; int get createdAt; int get updatedAt; int get archivedAt; bool get isDeleted; bool get isDirty; CompanyUser get companyUser; Map<String, dynamic> get rawCompanyUserSettings; CompanyUserSettings get companyUserSettings; List<String> get notificationsEmail; Map<String, dynamic> get rawNotifications;
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserCopyWith<User> get copyWith => _$UserCopyWithImpl<User>(this as User, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is User&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.oauthProviderId, oauthProviderId) || other.oauthProviderId == oauthProviderId)&&(identical(other.oauthUserToken, oauthUserToken) || other.oauthUserToken == oauthUserToken)&&(identical(other.oauthUserRefreshToken, oauthUserRefreshToken) || other.oauthUserRefreshToken == oauthUserRefreshToken)&&(identical(other.googleTwoFactorEnabled, googleTwoFactorEnabled) || other.googleTwoFactorEnabled == googleTwoFactorEnabled)&&(identical(other.verifiedPhoneNumber, verifiedPhoneNumber) || other.verifiedPhoneNumber == verifiedPhoneNumber)&&(identical(other.hasPassword, hasPassword) || other.hasPassword == hasPassword)&&(identical(other.userLoggedInNotification, userLoggedInNotification) || other.userLoggedInNotification == userLoggedInNotification)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&(identical(other.emailVerifiedAt, emailVerifiedAt) || other.emailVerifiedAt == emailVerifiedAt)&&(identical(other.lastConfirmedEmailAddress, lastConfirmedEmailAddress) || other.lastConfirmedEmailAddress == lastConfirmedEmailAddress)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty)&&(identical(other.companyUser, companyUser) || other.companyUser == companyUser)&&const DeepCollectionEquality().equals(other.rawCompanyUserSettings, rawCompanyUserSettings)&&(identical(other.companyUserSettings, companyUserSettings) || other.companyUserSettings == companyUserSettings)&&const DeepCollectionEquality().equals(other.notificationsEmail, notificationsEmail)&&const DeepCollectionEquality().equals(other.rawNotifications, rawNotifications));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,firstName,lastName,email,phone,signature,languageId,oauthProviderId,oauthUserToken,oauthUserRefreshToken,googleTwoFactorEnabled,verifiedPhoneNumber,hasPassword,userLoggedInNotification,customValue1,customValue2,customValue3,customValue4,lastLogin,emailVerifiedAt,lastConfirmedEmailAddress,createdAt,updatedAt,archivedAt,isDeleted,isDirty,companyUser,const DeepCollectionEquality().hash(rawCompanyUserSettings),companyUserSettings,const DeepCollectionEquality().hash(notificationsEmail),const DeepCollectionEquality().hash(rawNotifications)]);

@override
String toString() {
  return 'User(id: $id, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, signature: $signature, languageId: $languageId, oauthProviderId: $oauthProviderId, oauthUserToken: $oauthUserToken, oauthUserRefreshToken: $oauthUserRefreshToken, googleTwoFactorEnabled: $googleTwoFactorEnabled, verifiedPhoneNumber: $verifiedPhoneNumber, hasPassword: $hasPassword, userLoggedInNotification: $userLoggedInNotification, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, lastLogin: $lastLogin, emailVerifiedAt: $emailVerifiedAt, lastConfirmedEmailAddress: $lastConfirmedEmailAddress, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, isDirty: $isDirty, companyUser: $companyUser, rawCompanyUserSettings: $rawCompanyUserSettings, companyUserSettings: $companyUserSettings, notificationsEmail: $notificationsEmail, rawNotifications: $rawNotifications)';
}


}

/// @nodoc
abstract mixin class $UserCopyWith<$Res>  {
  factory $UserCopyWith(User value, $Res Function(User) _then) = _$UserCopyWithImpl;
@useResult
$Res call({
 String id, String firstName, String lastName, String email, String phone, String signature, String languageId, String oauthProviderId, String oauthUserToken, String oauthUserRefreshToken, bool googleTwoFactorEnabled, bool verifiedPhoneNumber, bool hasPassword, bool userLoggedInNotification, String customValue1, String customValue2, String customValue3, String customValue4, int lastLogin, int emailVerifiedAt, String lastConfirmedEmailAddress, int createdAt, int updatedAt, int archivedAt, bool isDeleted, bool isDirty, CompanyUser companyUser, Map<String, dynamic> rawCompanyUserSettings, CompanyUserSettings companyUserSettings, List<String> notificationsEmail, Map<String, dynamic> rawNotifications
});


$CompanyUserCopyWith<$Res> get companyUser;$CompanyUserSettingsCopyWith<$Res> get companyUserSettings;

}
/// @nodoc
class _$UserCopyWithImpl<$Res>
    implements $UserCopyWith<$Res> {
  _$UserCopyWithImpl(this._self, this._then);

  final User _self;
  final $Res Function(User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? signature = null,Object? languageId = null,Object? oauthProviderId = null,Object? oauthUserToken = null,Object? oauthUserRefreshToken = null,Object? googleTwoFactorEnabled = null,Object? verifiedPhoneNumber = null,Object? hasPassword = null,Object? userLoggedInNotification = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? lastLogin = null,Object? emailVerifiedAt = null,Object? lastConfirmedEmailAddress = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? isDirty = null,Object? companyUser = null,Object? rawCompanyUserSettings = null,Object? companyUserSettings = null,Object? notificationsEmail = null,Object? rawNotifications = null,}) {
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
as String,googleTwoFactorEnabled: null == googleTwoFactorEnabled ? _self.googleTwoFactorEnabled : googleTwoFactorEnabled // ignore: cast_nullable_to_non_nullable
as bool,verifiedPhoneNumber: null == verifiedPhoneNumber ? _self.verifiedPhoneNumber : verifiedPhoneNumber // ignore: cast_nullable_to_non_nullable
as bool,hasPassword: null == hasPassword ? _self.hasPassword : hasPassword // ignore: cast_nullable_to_non_nullable
as bool,userLoggedInNotification: null == userLoggedInNotification ? _self.userLoggedInNotification : userLoggedInNotification // ignore: cast_nullable_to_non_nullable
as bool,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,lastLogin: null == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as int,emailVerifiedAt: null == emailVerifiedAt ? _self.emailVerifiedAt : emailVerifiedAt // ignore: cast_nullable_to_non_nullable
as int,lastConfirmedEmailAddress: null == lastConfirmedEmailAddress ? _self.lastConfirmedEmailAddress : lastConfirmedEmailAddress // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,companyUser: null == companyUser ? _self.companyUser : companyUser // ignore: cast_nullable_to_non_nullable
as CompanyUser,rawCompanyUserSettings: null == rawCompanyUserSettings ? _self.rawCompanyUserSettings : rawCompanyUserSettings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,companyUserSettings: null == companyUserSettings ? _self.companyUserSettings : companyUserSettings // ignore: cast_nullable_to_non_nullable
as CompanyUserSettings,notificationsEmail: null == notificationsEmail ? _self.notificationsEmail : notificationsEmail // ignore: cast_nullable_to_non_nullable
as List<String>,rawNotifications: null == rawNotifications ? _self.rawNotifications : rawNotifications // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}
/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanyUserCopyWith<$Res> get companyUser {
  
  return $CompanyUserCopyWith<$Res>(_self.companyUser, (value) {
    return _then(_self.copyWith(companyUser: value));
  });
}/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanyUserSettingsCopyWith<$Res> get companyUserSettings {
  
  return $CompanyUserSettingsCopyWith<$Res>(_self.companyUserSettings, (value) {
    return _then(_self.copyWith(companyUserSettings: value));
  });
}
}


/// Adds pattern-matching-related methods to [User].
extension UserPatterns on User {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _User value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _User value)  $default,){
final _that = this;
switch (_that) {
case _User():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _User value)?  $default,){
final _that = this;
switch (_that) {
case _User() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String firstName,  String lastName,  String email,  String phone,  String signature,  String languageId,  String oauthProviderId,  String oauthUserToken,  String oauthUserRefreshToken,  bool googleTwoFactorEnabled,  bool verifiedPhoneNumber,  bool hasPassword,  bool userLoggedInNotification,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  int lastLogin,  int emailVerifiedAt,  String lastConfirmedEmailAddress,  int createdAt,  int updatedAt,  int archivedAt,  bool isDeleted,  bool isDirty,  CompanyUser companyUser,  Map<String, dynamic> rawCompanyUserSettings,  CompanyUserSettings companyUserSettings,  List<String> notificationsEmail,  Map<String, dynamic> rawNotifications)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.signature,_that.languageId,_that.oauthProviderId,_that.oauthUserToken,_that.oauthUserRefreshToken,_that.googleTwoFactorEnabled,_that.verifiedPhoneNumber,_that.hasPassword,_that.userLoggedInNotification,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.lastLogin,_that.emailVerifiedAt,_that.lastConfirmedEmailAddress,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.isDirty,_that.companyUser,_that.rawCompanyUserSettings,_that.companyUserSettings,_that.notificationsEmail,_that.rawNotifications);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String firstName,  String lastName,  String email,  String phone,  String signature,  String languageId,  String oauthProviderId,  String oauthUserToken,  String oauthUserRefreshToken,  bool googleTwoFactorEnabled,  bool verifiedPhoneNumber,  bool hasPassword,  bool userLoggedInNotification,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  int lastLogin,  int emailVerifiedAt,  String lastConfirmedEmailAddress,  int createdAt,  int updatedAt,  int archivedAt,  bool isDeleted,  bool isDirty,  CompanyUser companyUser,  Map<String, dynamic> rawCompanyUserSettings,  CompanyUserSettings companyUserSettings,  List<String> notificationsEmail,  Map<String, dynamic> rawNotifications)  $default,) {final _that = this;
switch (_that) {
case _User():
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.signature,_that.languageId,_that.oauthProviderId,_that.oauthUserToken,_that.oauthUserRefreshToken,_that.googleTwoFactorEnabled,_that.verifiedPhoneNumber,_that.hasPassword,_that.userLoggedInNotification,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.lastLogin,_that.emailVerifiedAt,_that.lastConfirmedEmailAddress,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.isDirty,_that.companyUser,_that.rawCompanyUserSettings,_that.companyUserSettings,_that.notificationsEmail,_that.rawNotifications);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String firstName,  String lastName,  String email,  String phone,  String signature,  String languageId,  String oauthProviderId,  String oauthUserToken,  String oauthUserRefreshToken,  bool googleTwoFactorEnabled,  bool verifiedPhoneNumber,  bool hasPassword,  bool userLoggedInNotification,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  int lastLogin,  int emailVerifiedAt,  String lastConfirmedEmailAddress,  int createdAt,  int updatedAt,  int archivedAt,  bool isDeleted,  bool isDirty,  CompanyUser companyUser,  Map<String, dynamic> rawCompanyUserSettings,  CompanyUserSettings companyUserSettings,  List<String> notificationsEmail,  Map<String, dynamic> rawNotifications)?  $default,) {final _that = this;
switch (_that) {
case _User() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.signature,_that.languageId,_that.oauthProviderId,_that.oauthUserToken,_that.oauthUserRefreshToken,_that.googleTwoFactorEnabled,_that.verifiedPhoneNumber,_that.hasPassword,_that.userLoggedInNotification,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.lastLogin,_that.emailVerifiedAt,_that.lastConfirmedEmailAddress,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.isDirty,_that.companyUser,_that.rawCompanyUserSettings,_that.companyUserSettings,_that.notificationsEmail,_that.rawNotifications);case _:
  return null;

}
}

}

/// @nodoc


class _User extends User {
  const _User({this.id = '', this.firstName = '', this.lastName = '', this.email = '', this.phone = '', this.signature = '', this.languageId = '', this.oauthProviderId = '', this.oauthUserToken = '', this.oauthUserRefreshToken = '', this.googleTwoFactorEnabled = false, this.verifiedPhoneNumber = false, this.hasPassword = false, this.userLoggedInNotification = false, this.customValue1 = '', this.customValue2 = '', this.customValue3 = '', this.customValue4 = '', this.lastLogin = 0, this.emailVerifiedAt = 0, this.lastConfirmedEmailAddress = '', this.createdAt = 0, this.updatedAt = 0, this.archivedAt = 0, this.isDeleted = false, this.isDirty = false, this.companyUser = const CompanyUser(), final  Map<String, dynamic> rawCompanyUserSettings = const <String, dynamic>{}, this.companyUserSettings = const CompanyUserSettings(), final  List<String> notificationsEmail = const <String>[], final  Map<String, dynamic> rawNotifications = const <String, dynamic>{}}): _rawCompanyUserSettings = rawCompanyUserSettings,_notificationsEmail = notificationsEmail,_rawNotifications = rawNotifications,super._();
  

@override@JsonKey() final  String id;
@override@JsonKey() final  String firstName;
@override@JsonKey() final  String lastName;
@override@JsonKey() final  String email;
@override@JsonKey() final  String phone;
@override@JsonKey() final  String signature;
@override@JsonKey() final  String languageId;
@override@JsonKey() final  String oauthProviderId;
@override@JsonKey() final  String oauthUserToken;
@override@JsonKey() final  String oauthUserRefreshToken;
@override@JsonKey() final  bool googleTwoFactorEnabled;
@override@JsonKey() final  bool verifiedPhoneNumber;
@override@JsonKey() final  bool hasPassword;
@override@JsonKey() final  bool userLoggedInNotification;
@override@JsonKey() final  String customValue1;
@override@JsonKey() final  String customValue2;
@override@JsonKey() final  String customValue3;
@override@JsonKey() final  String customValue4;
@override@JsonKey() final  int lastLogin;
@override@JsonKey() final  int emailVerifiedAt;
/// The address held before this user's last email change, or `''`. See
/// [looksNeverOnboarded] and `UserApi.lastConfirmedEmailAddress`.
@override@JsonKey() final  String lastConfirmedEmailAddress;
@override@JsonKey() final  int createdAt;
@override@JsonKey() final  int updatedAt;
@override@JsonKey() final  int archivedAt;
@override@JsonKey() final  bool isDeleted;
@override@JsonKey() final  bool isDirty;
@override@JsonKey() final  CompanyUser companyUser;
 final  Map<String, dynamic> _rawCompanyUserSettings;
@override@JsonKey() Map<String, dynamic> get rawCompanyUserSettings {
  if (_rawCompanyUserSettings is EqualUnmodifiableMapView) return _rawCompanyUserSettings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_rawCompanyUserSettings);
}

@override@JsonKey() final  CompanyUserSettings companyUserSettings;
 final  List<String> _notificationsEmail;
@override@JsonKey() List<String> get notificationsEmail {
  if (_notificationsEmail is EqualUnmodifiableListView) return _notificationsEmail;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_notificationsEmail);
}

 final  Map<String, dynamic> _rawNotifications;
@override@JsonKey() Map<String, dynamic> get rawNotifications {
  if (_rawNotifications is EqualUnmodifiableMapView) return _rawNotifications;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_rawNotifications);
}


/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserCopyWith<_User> get copyWith => __$UserCopyWithImpl<_User>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _User&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.signature, signature) || other.signature == signature)&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.oauthProviderId, oauthProviderId) || other.oauthProviderId == oauthProviderId)&&(identical(other.oauthUserToken, oauthUserToken) || other.oauthUserToken == oauthUserToken)&&(identical(other.oauthUserRefreshToken, oauthUserRefreshToken) || other.oauthUserRefreshToken == oauthUserRefreshToken)&&(identical(other.googleTwoFactorEnabled, googleTwoFactorEnabled) || other.googleTwoFactorEnabled == googleTwoFactorEnabled)&&(identical(other.verifiedPhoneNumber, verifiedPhoneNumber) || other.verifiedPhoneNumber == verifiedPhoneNumber)&&(identical(other.hasPassword, hasPassword) || other.hasPassword == hasPassword)&&(identical(other.userLoggedInNotification, userLoggedInNotification) || other.userLoggedInNotification == userLoggedInNotification)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&(identical(other.emailVerifiedAt, emailVerifiedAt) || other.emailVerifiedAt == emailVerifiedAt)&&(identical(other.lastConfirmedEmailAddress, lastConfirmedEmailAddress) || other.lastConfirmedEmailAddress == lastConfirmedEmailAddress)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty)&&(identical(other.companyUser, companyUser) || other.companyUser == companyUser)&&const DeepCollectionEquality().equals(other._rawCompanyUserSettings, _rawCompanyUserSettings)&&(identical(other.companyUserSettings, companyUserSettings) || other.companyUserSettings == companyUserSettings)&&const DeepCollectionEquality().equals(other._notificationsEmail, _notificationsEmail)&&const DeepCollectionEquality().equals(other._rawNotifications, _rawNotifications));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,firstName,lastName,email,phone,signature,languageId,oauthProviderId,oauthUserToken,oauthUserRefreshToken,googleTwoFactorEnabled,verifiedPhoneNumber,hasPassword,userLoggedInNotification,customValue1,customValue2,customValue3,customValue4,lastLogin,emailVerifiedAt,lastConfirmedEmailAddress,createdAt,updatedAt,archivedAt,isDeleted,isDirty,companyUser,const DeepCollectionEquality().hash(_rawCompanyUserSettings),companyUserSettings,const DeepCollectionEquality().hash(_notificationsEmail),const DeepCollectionEquality().hash(_rawNotifications)]);

@override
String toString() {
  return 'User(id: $id, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, signature: $signature, languageId: $languageId, oauthProviderId: $oauthProviderId, oauthUserToken: $oauthUserToken, oauthUserRefreshToken: $oauthUserRefreshToken, googleTwoFactorEnabled: $googleTwoFactorEnabled, verifiedPhoneNumber: $verifiedPhoneNumber, hasPassword: $hasPassword, userLoggedInNotification: $userLoggedInNotification, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, lastLogin: $lastLogin, emailVerifiedAt: $emailVerifiedAt, lastConfirmedEmailAddress: $lastConfirmedEmailAddress, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, isDirty: $isDirty, companyUser: $companyUser, rawCompanyUserSettings: $rawCompanyUserSettings, companyUserSettings: $companyUserSettings, notificationsEmail: $notificationsEmail, rawNotifications: $rawNotifications)';
}


}

/// @nodoc
abstract mixin class _$UserCopyWith<$Res> implements $UserCopyWith<$Res> {
  factory _$UserCopyWith(_User value, $Res Function(_User) _then) = __$UserCopyWithImpl;
@override @useResult
$Res call({
 String id, String firstName, String lastName, String email, String phone, String signature, String languageId, String oauthProviderId, String oauthUserToken, String oauthUserRefreshToken, bool googleTwoFactorEnabled, bool verifiedPhoneNumber, bool hasPassword, bool userLoggedInNotification, String customValue1, String customValue2, String customValue3, String customValue4, int lastLogin, int emailVerifiedAt, String lastConfirmedEmailAddress, int createdAt, int updatedAt, int archivedAt, bool isDeleted, bool isDirty, CompanyUser companyUser, Map<String, dynamic> rawCompanyUserSettings, CompanyUserSettings companyUserSettings, List<String> notificationsEmail, Map<String, dynamic> rawNotifications
});


@override $CompanyUserCopyWith<$Res> get companyUser;@override $CompanyUserSettingsCopyWith<$Res> get companyUserSettings;

}
/// @nodoc
class __$UserCopyWithImpl<$Res>
    implements _$UserCopyWith<$Res> {
  __$UserCopyWithImpl(this._self, this._then);

  final _User _self;
  final $Res Function(_User) _then;

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? signature = null,Object? languageId = null,Object? oauthProviderId = null,Object? oauthUserToken = null,Object? oauthUserRefreshToken = null,Object? googleTwoFactorEnabled = null,Object? verifiedPhoneNumber = null,Object? hasPassword = null,Object? userLoggedInNotification = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? lastLogin = null,Object? emailVerifiedAt = null,Object? lastConfirmedEmailAddress = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? isDirty = null,Object? companyUser = null,Object? rawCompanyUserSettings = null,Object? companyUserSettings = null,Object? notificationsEmail = null,Object? rawNotifications = null,}) {
  return _then(_User(
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
as String,googleTwoFactorEnabled: null == googleTwoFactorEnabled ? _self.googleTwoFactorEnabled : googleTwoFactorEnabled // ignore: cast_nullable_to_non_nullable
as bool,verifiedPhoneNumber: null == verifiedPhoneNumber ? _self.verifiedPhoneNumber : verifiedPhoneNumber // ignore: cast_nullable_to_non_nullable
as bool,hasPassword: null == hasPassword ? _self.hasPassword : hasPassword // ignore: cast_nullable_to_non_nullable
as bool,userLoggedInNotification: null == userLoggedInNotification ? _self.userLoggedInNotification : userLoggedInNotification // ignore: cast_nullable_to_non_nullable
as bool,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,lastLogin: null == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as int,emailVerifiedAt: null == emailVerifiedAt ? _self.emailVerifiedAt : emailVerifiedAt // ignore: cast_nullable_to_non_nullable
as int,lastConfirmedEmailAddress: null == lastConfirmedEmailAddress ? _self.lastConfirmedEmailAddress : lastConfirmedEmailAddress // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,companyUser: null == companyUser ? _self.companyUser : companyUser // ignore: cast_nullable_to_non_nullable
as CompanyUser,rawCompanyUserSettings: null == rawCompanyUserSettings ? _self._rawCompanyUserSettings : rawCompanyUserSettings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,companyUserSettings: null == companyUserSettings ? _self.companyUserSettings : companyUserSettings // ignore: cast_nullable_to_non_nullable
as CompanyUserSettings,notificationsEmail: null == notificationsEmail ? _self._notificationsEmail : notificationsEmail // ignore: cast_nullable_to_non_nullable
as List<String>,rawNotifications: null == rawNotifications ? _self._rawNotifications : rawNotifications // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanyUserCopyWith<$Res> get companyUser {
  
  return $CompanyUserCopyWith<$Res>(_self.companyUser, (value) {
    return _then(_self.copyWith(companyUser: value));
  });
}/// Create a copy of User
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanyUserSettingsCopyWith<$Res> get companyUserSettings {
  
  return $CompanyUserSettingsCopyWith<$Res>(_self.companyUserSettings, (value) {
    return _then(_self.copyWith(companyUserSettings: value));
  });
}
}

/// @nodoc
mixin _$CompanyUser {

 String get permissions; bool get isOwner; bool get isAdmin; bool get isLocked;
/// Create a copy of CompanyUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyUserCopyWith<CompanyUser> get copyWith => _$CompanyUserCopyWithImpl<CompanyUser>(this as CompanyUser, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanyUser&&(identical(other.permissions, permissions) || other.permissions == permissions)&&(identical(other.isOwner, isOwner) || other.isOwner == isOwner)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.isLocked, isLocked) || other.isLocked == isLocked));
}


@override
int get hashCode => Object.hash(runtimeType,permissions,isOwner,isAdmin,isLocked);

@override
String toString() {
  return 'CompanyUser(permissions: $permissions, isOwner: $isOwner, isAdmin: $isAdmin, isLocked: $isLocked)';
}


}

/// @nodoc
abstract mixin class $CompanyUserCopyWith<$Res>  {
  factory $CompanyUserCopyWith(CompanyUser value, $Res Function(CompanyUser) _then) = _$CompanyUserCopyWithImpl;
@useResult
$Res call({
 String permissions, bool isOwner, bool isAdmin, bool isLocked
});




}
/// @nodoc
class _$CompanyUserCopyWithImpl<$Res>
    implements $CompanyUserCopyWith<$Res> {
  _$CompanyUserCopyWithImpl(this._self, this._then);

  final CompanyUser _self;
  final $Res Function(CompanyUser) _then;

/// Create a copy of CompanyUser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? permissions = null,Object? isOwner = null,Object? isAdmin = null,Object? isLocked = null,}) {
  return _then(_self.copyWith(
permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as String,isOwner: null == isOwner ? _self.isOwner : isOwner // ignore: cast_nullable_to_non_nullable
as bool,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,isLocked: null == isLocked ? _self.isLocked : isLocked // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CompanyUser].
extension CompanyUserPatterns on CompanyUser {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompanyUser value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompanyUser() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompanyUser value)  $default,){
final _that = this;
switch (_that) {
case _CompanyUser():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompanyUser value)?  $default,){
final _that = this;
switch (_that) {
case _CompanyUser() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String permissions,  bool isOwner,  bool isAdmin,  bool isLocked)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompanyUser() when $default != null:
return $default(_that.permissions,_that.isOwner,_that.isAdmin,_that.isLocked);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String permissions,  bool isOwner,  bool isAdmin,  bool isLocked)  $default,) {final _that = this;
switch (_that) {
case _CompanyUser():
return $default(_that.permissions,_that.isOwner,_that.isAdmin,_that.isLocked);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String permissions,  bool isOwner,  bool isAdmin,  bool isLocked)?  $default,) {final _that = this;
switch (_that) {
case _CompanyUser() when $default != null:
return $default(_that.permissions,_that.isOwner,_that.isAdmin,_that.isLocked);case _:
  return null;

}
}

}

/// @nodoc


class _CompanyUser implements CompanyUser {
  const _CompanyUser({this.permissions = '', this.isOwner = false, this.isAdmin = false, this.isLocked = false});
  

@override@JsonKey() final  String permissions;
@override@JsonKey() final  bool isOwner;
@override@JsonKey() final  bool isAdmin;
@override@JsonKey() final  bool isLocked;

/// Create a copy of CompanyUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyUserCopyWith<_CompanyUser> get copyWith => __$CompanyUserCopyWithImpl<_CompanyUser>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompanyUser&&(identical(other.permissions, permissions) || other.permissions == permissions)&&(identical(other.isOwner, isOwner) || other.isOwner == isOwner)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.isLocked, isLocked) || other.isLocked == isLocked));
}


@override
int get hashCode => Object.hash(runtimeType,permissions,isOwner,isAdmin,isLocked);

@override
String toString() {
  return 'CompanyUser(permissions: $permissions, isOwner: $isOwner, isAdmin: $isAdmin, isLocked: $isLocked)';
}


}

/// @nodoc
abstract mixin class _$CompanyUserCopyWith<$Res> implements $CompanyUserCopyWith<$Res> {
  factory _$CompanyUserCopyWith(_CompanyUser value, $Res Function(_CompanyUser) _then) = __$CompanyUserCopyWithImpl;
@override @useResult
$Res call({
 String permissions, bool isOwner, bool isAdmin, bool isLocked
});




}
/// @nodoc
class __$CompanyUserCopyWithImpl<$Res>
    implements _$CompanyUserCopyWith<$Res> {
  __$CompanyUserCopyWithImpl(this._self, this._then);

  final _CompanyUser _self;
  final $Res Function(_CompanyUser) _then;

/// Create a copy of CompanyUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? permissions = null,Object? isOwner = null,Object? isAdmin = null,Object? isLocked = null,}) {
  return _then(_CompanyUser(
permissions: null == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as String,isOwner: null == isOwner ? _self.isOwner : isOwner // ignore: cast_nullable_to_non_nullable
as bool,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,isLocked: null == isLocked ? _self.isLocked : isLocked // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$CompanyUserSettings {

 String get accentColor;
/// Create a copy of CompanyUserSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyUserSettingsCopyWith<CompanyUserSettings> get copyWith => _$CompanyUserSettingsCopyWithImpl<CompanyUserSettings>(this as CompanyUserSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanyUserSettings&&(identical(other.accentColor, accentColor) || other.accentColor == accentColor));
}


@override
int get hashCode => Object.hash(runtimeType,accentColor);

@override
String toString() {
  return 'CompanyUserSettings(accentColor: $accentColor)';
}


}

/// @nodoc
abstract mixin class $CompanyUserSettingsCopyWith<$Res>  {
  factory $CompanyUserSettingsCopyWith(CompanyUserSettings value, $Res Function(CompanyUserSettings) _then) = _$CompanyUserSettingsCopyWithImpl;
@useResult
$Res call({
 String accentColor
});




}
/// @nodoc
class _$CompanyUserSettingsCopyWithImpl<$Res>
    implements $CompanyUserSettingsCopyWith<$Res> {
  _$CompanyUserSettingsCopyWithImpl(this._self, this._then);

  final CompanyUserSettings _self;
  final $Res Function(CompanyUserSettings) _then;

/// Create a copy of CompanyUserSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accentColor = null,}) {
  return _then(_self.copyWith(
accentColor: null == accentColor ? _self.accentColor : accentColor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CompanyUserSettings].
extension CompanyUserSettingsPatterns on CompanyUserSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompanyUserSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompanyUserSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompanyUserSettings value)  $default,){
final _that = this;
switch (_that) {
case _CompanyUserSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompanyUserSettings value)?  $default,){
final _that = this;
switch (_that) {
case _CompanyUserSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accentColor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompanyUserSettings() when $default != null:
return $default(_that.accentColor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accentColor)  $default,) {final _that = this;
switch (_that) {
case _CompanyUserSettings():
return $default(_that.accentColor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accentColor)?  $default,) {final _that = this;
switch (_that) {
case _CompanyUserSettings() when $default != null:
return $default(_that.accentColor);case _:
  return null;

}
}

}

/// @nodoc


class _CompanyUserSettings extends CompanyUserSettings {
  const _CompanyUserSettings({this.accentColor = ''}): super._();
  

@override@JsonKey() final  String accentColor;

/// Create a copy of CompanyUserSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyUserSettingsCopyWith<_CompanyUserSettings> get copyWith => __$CompanyUserSettingsCopyWithImpl<_CompanyUserSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompanyUserSettings&&(identical(other.accentColor, accentColor) || other.accentColor == accentColor));
}


@override
int get hashCode => Object.hash(runtimeType,accentColor);

@override
String toString() {
  return 'CompanyUserSettings(accentColor: $accentColor)';
}


}

/// @nodoc
abstract mixin class _$CompanyUserSettingsCopyWith<$Res> implements $CompanyUserSettingsCopyWith<$Res> {
  factory _$CompanyUserSettingsCopyWith(_CompanyUserSettings value, $Res Function(_CompanyUserSettings) _then) = __$CompanyUserSettingsCopyWithImpl;
@override @useResult
$Res call({
 String accentColor
});




}
/// @nodoc
class __$CompanyUserSettingsCopyWithImpl<$Res>
    implements _$CompanyUserSettingsCopyWith<$Res> {
  __$CompanyUserSettingsCopyWithImpl(this._self, this._then);

  final _CompanyUserSettings _self;
  final $Res Function(_CompanyUserSettings) _then;

/// Create a copy of CompanyUserSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accentColor = null,}) {
  return _then(_CompanyUserSettings(
accentColor: null == accentColor ? _self.accentColor : accentColor // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
