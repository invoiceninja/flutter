// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vendor_contact.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VendorContact {

 String get id; String get firstName; String get lastName; String get email; String get phone; String get password; String get portalPlaceholderEmail; bool get sendEmail; bool get ccOnly; bool get isPrimary; bool get canSign; String get link; String get customValue1; String get customValue2; String get customValue3; String get customValue4; DateTime get updatedAt; bool get isDeleted; DateTime? get lastLogin;
/// Create a copy of VendorContact
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VendorContactCopyWith<VendorContact> get copyWith => _$VendorContactCopyWithImpl<VendorContact>(this as VendorContact, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VendorContact;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VendorContact&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.firstName, _this.firstName) || other.firstName == _this.firstName)&&(identical(other.lastName, _this.lastName) || other.lastName == _this.lastName)&&(identical(other.email, _this.email) || other.email == _this.email)&&(identical(other.phone, _this.phone) || other.phone == _this.phone)&&(identical(other.password, _this.password) || other.password == _this.password)&&(identical(other.portalPlaceholderEmail, _this.portalPlaceholderEmail) || other.portalPlaceholderEmail == _this.portalPlaceholderEmail)&&(identical(other.sendEmail, _this.sendEmail) || other.sendEmail == _this.sendEmail)&&(identical(other.ccOnly, _this.ccOnly) || other.ccOnly == _this.ccOnly)&&(identical(other.isPrimary, _this.isPrimary) || other.isPrimary == _this.isPrimary)&&(identical(other.canSign, _this.canSign) || other.canSign == _this.canSign)&&(identical(other.link, _this.link) || other.link == _this.link)&&(identical(other.customValue1, _this.customValue1) || other.customValue1 == _this.customValue1)&&(identical(other.customValue2, _this.customValue2) || other.customValue2 == _this.customValue2)&&(identical(other.customValue3, _this.customValue3) || other.customValue3 == _this.customValue3)&&(identical(other.customValue4, _this.customValue4) || other.customValue4 == _this.customValue4)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.isDeleted, _this.isDeleted) || other.isDeleted == _this.isDeleted)&&(identical(other.lastLogin, _this.lastLogin) || other.lastLogin == _this.lastLogin));
}


@override
int get hashCode {
  final _this = this as VendorContact;
  return Object.hashAll([runtimeType,_this.id,_this.firstName,_this.lastName,_this.email,_this.phone,_this.password,_this.portalPlaceholderEmail,_this.sendEmail,_this.ccOnly,_this.isPrimary,_this.canSign,_this.link,_this.customValue1,_this.customValue2,_this.customValue3,_this.customValue4,_this.updatedAt,_this.isDeleted,_this.lastLogin]);
}

@override
String toString() {
  final _this = this as VendorContact;
  return 'VendorContact(id: ${_this.id}, firstName: ${_this.firstName}, lastName: ${_this.lastName}, email: ${_this.email}, phone: ${_this.phone}, password: ${_this.password}, portalPlaceholderEmail: ${_this.portalPlaceholderEmail}, sendEmail: ${_this.sendEmail}, ccOnly: ${_this.ccOnly}, isPrimary: ${_this.isPrimary}, canSign: ${_this.canSign}, link: ${_this.link}, customValue1: ${_this.customValue1}, customValue2: ${_this.customValue2}, customValue3: ${_this.customValue3}, customValue4: ${_this.customValue4}, updatedAt: ${_this.updatedAt}, isDeleted: ${_this.isDeleted}, lastLogin: ${_this.lastLogin})';
}


}

/// @nodoc
abstract mixin class $VendorContactCopyWith<$Res>  {
  factory $VendorContactCopyWith(VendorContact value, $Res Function(VendorContact) _then) = _$VendorContactCopyWithImpl;
@useResult
$Res call({
 String id, String firstName, String lastName, String email, String phone, String password, String portalPlaceholderEmail, bool sendEmail, bool ccOnly, bool isPrimary, bool canSign, String link, String customValue1, String customValue2, String customValue3, String customValue4, DateTime updatedAt, bool isDeleted, DateTime? lastLogin
});




}
/// @nodoc
class _$VendorContactCopyWithImpl<$Res>
    implements $VendorContactCopyWith<$Res> {
  _$VendorContactCopyWithImpl(this._self, this._then);

  final VendorContact _self;
  final $Res Function(VendorContact) _then;

/// Create a copy of VendorContact
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? password = null,Object? portalPlaceholderEmail = null,Object? sendEmail = null,Object? ccOnly = null,Object? isPrimary = null,Object? canSign = null,Object? link = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? updatedAt = null,Object? isDeleted = null,Object? lastLogin = freezed,}) {
  return _then(VendorContact(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,portalPlaceholderEmail: null == portalPlaceholderEmail ? _self.portalPlaceholderEmail : portalPlaceholderEmail // ignore: cast_nullable_to_non_nullable
as String,sendEmail: null == sendEmail ? _self.sendEmail : sendEmail // ignore: cast_nullable_to_non_nullable
as bool,ccOnly: null == ccOnly ? _self.ccOnly : ccOnly // ignore: cast_nullable_to_non_nullable
as bool,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,canSign: null == canSign ? _self.canSign : canSign // ignore: cast_nullable_to_non_nullable
as bool,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,lastLogin: freezed == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [VendorContact].
extension VendorContactPatterns on VendorContact {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VendorContact value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VendorContact() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VendorContact value)  $default,){
final _that = this;
switch (_that) {
case _VendorContact():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VendorContact value)?  $default,){
final _that = this;
switch (_that) {
case _VendorContact() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String firstName,  String lastName,  String email,  String phone,  String password,  String portalPlaceholderEmail,  bool sendEmail,  bool ccOnly,  bool isPrimary,  bool canSign,  String link,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  DateTime updatedAt,  bool isDeleted,  DateTime? lastLogin)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VendorContact() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.password,_that.portalPlaceholderEmail,_that.sendEmail,_that.ccOnly,_that.isPrimary,_that.canSign,_that.link,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.updatedAt,_that.isDeleted,_that.lastLogin);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String firstName,  String lastName,  String email,  String phone,  String password,  String portalPlaceholderEmail,  bool sendEmail,  bool ccOnly,  bool isPrimary,  bool canSign,  String link,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  DateTime updatedAt,  bool isDeleted,  DateTime? lastLogin)  $default,) {final _that = this;
switch (_that) {
case _VendorContact():
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.password,_that.portalPlaceholderEmail,_that.sendEmail,_that.ccOnly,_that.isPrimary,_that.canSign,_that.link,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.updatedAt,_that.isDeleted,_that.lastLogin);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String firstName,  String lastName,  String email,  String phone,  String password,  String portalPlaceholderEmail,  bool sendEmail,  bool ccOnly,  bool isPrimary,  bool canSign,  String link,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  DateTime updatedAt,  bool isDeleted,  DateTime? lastLogin)?  $default,) {final _that = this;
switch (_that) {
case _VendorContact() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.password,_that.portalPlaceholderEmail,_that.sendEmail,_that.ccOnly,_that.isPrimary,_that.canSign,_that.link,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.updatedAt,_that.isDeleted,_that.lastLogin);case _:
  return null;

}
}

}

/// @nodoc


class _VendorContact implements VendorContact {
  const _VendorContact({required this.id, required this.firstName, required this.lastName, required this.email, required this.phone, required this.password, this.portalPlaceholderEmail = '', required this.sendEmail, this.ccOnly = false, required this.isPrimary, this.canSign = false, this.link = '', required this.customValue1, required this.customValue2, required this.customValue3, required this.customValue4, required this.updatedAt, required this.isDeleted, this.lastLogin});
  

@override final  String id;
@override final  String firstName;
@override final  String lastName;
@override final  String email;
@override final  String phone;
@override final  String password;
@override@JsonKey() final  String portalPlaceholderEmail;
@override final  bool sendEmail;
@override@JsonKey() final  bool ccOnly;
@override final  bool isPrimary;
@override@JsonKey() final  bool canSign;
@override@JsonKey() final  String link;
@override final  String customValue1;
@override final  String customValue2;
@override final  String customValue3;
@override final  String customValue4;
@override final  DateTime updatedAt;
@override final  bool isDeleted;
@override final  DateTime? lastLogin;

/// Create a copy of VendorContact
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VendorContactCopyWith<_VendorContact> get copyWith => __$VendorContactCopyWithImpl<_VendorContact>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VendorContact&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.password, password) || other.password == password)&&(identical(other.portalPlaceholderEmail, portalPlaceholderEmail) || other.portalPlaceholderEmail == portalPlaceholderEmail)&&(identical(other.sendEmail, sendEmail) || other.sendEmail == sendEmail)&&(identical(other.ccOnly, ccOnly) || other.ccOnly == ccOnly)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&(identical(other.canSign, canSign) || other.canSign == canSign)&&(identical(other.link, link) || other.link == link)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,id,firstName,lastName,email,phone,password,portalPlaceholderEmail,sendEmail,ccOnly,isPrimary,canSign,link,customValue1,customValue2,customValue3,customValue4,updatedAt,isDeleted,lastLogin]);
}

@override
String toString() {
    return 'VendorContact(id: $id, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, password: $password, portalPlaceholderEmail: $portalPlaceholderEmail, sendEmail: $sendEmail, ccOnly: $ccOnly, isPrimary: $isPrimary, canSign: $canSign, link: $link, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, updatedAt: $updatedAt, isDeleted: $isDeleted, lastLogin: $lastLogin)';
}


}

/// @nodoc
abstract mixin class _$VendorContactCopyWith<$Res> implements $VendorContactCopyWith<$Res> {
  factory _$VendorContactCopyWith(_VendorContact value, $Res Function(_VendorContact) _then) = __$VendorContactCopyWithImpl;
@override @useResult
$Res call({
 String id, String firstName, String lastName, String email, String phone, String password, String portalPlaceholderEmail, bool sendEmail, bool ccOnly, bool isPrimary, bool canSign, String link, String customValue1, String customValue2, String customValue3, String customValue4, DateTime updatedAt, bool isDeleted, DateTime? lastLogin
});




}
/// @nodoc
class __$VendorContactCopyWithImpl<$Res>
    implements _$VendorContactCopyWith<$Res> {
  __$VendorContactCopyWithImpl(this._self, this._then);

  final _VendorContact _self;
  final $Res Function(_VendorContact) _then;

/// Create a copy of VendorContact
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? password = null,Object? portalPlaceholderEmail = null,Object? sendEmail = null,Object? ccOnly = null,Object? isPrimary = null,Object? canSign = null,Object? link = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? updatedAt = null,Object? isDeleted = null,Object? lastLogin = freezed,}) {
  return _then(_VendorContact(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,portalPlaceholderEmail: null == portalPlaceholderEmail ? _self.portalPlaceholderEmail : portalPlaceholderEmail // ignore: cast_nullable_to_non_nullable
as String,sendEmail: null == sendEmail ? _self.sendEmail : sendEmail // ignore: cast_nullable_to_non_nullable
as bool,ccOnly: null == ccOnly ? _self.ccOnly : ccOnly // ignore: cast_nullable_to_non_nullable
as bool,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,canSign: null == canSign ? _self.canSign : canSign // ignore: cast_nullable_to_non_nullable
as bool,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,lastLogin: freezed == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
