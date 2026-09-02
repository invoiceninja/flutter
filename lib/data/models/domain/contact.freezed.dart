// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'contact.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Contact {

 String get id; String get firstName; String get lastName; String get email; String get phone; bool get isPrimary; bool get sendEmail; bool get ccOnly; bool get isLocked;// "Authorized to sign" — portal e-signature permission. Editable when the
// company has the relevant module enabled (React parity).
 bool get canSign; String get password;// The address the **server** minted for a contact that had none (see
// [isPortalPlaceholderEmail]) — stripped out of [email] on the way in so
// nothing renders it, kept here so [ContactCopy.toApiJson] can put it back.
// Clearing it instead would be a write the user never asked for, on an
// unrelated save, to the field the portal guard authenticates this contact
// by — and it would never settle, since the next portal visit mints a
// different address. Empty for every contact whose address is real, which
// is what keeps a genuine "user cleared their email" edit going out as ''.
//
// Deliberately not a Drift column: it is re-derived by [Contact.fromApi] on
// every read, because a local save's stored payload *is* `toApiJson`'s
// output and that re-emits the raw value. Omitting the key there instead
// would look equivalent on the wire but round-trip to '' through
// `_domainToCompanion` → `_fromRow`, so the second offline save would clear
// the server's value after all.
 String get portalPlaceholderEmail; DateTime get updatedAt; bool get isDeleted; String get link;// Server-assigned stable identifier for the contact. Read-only; echoed
// back on save so the server can match existing portal credentials.
 String get contactKey;// Last portal login (read-only); null when the contact has never signed
// in. Display-only — not written back.
 DateTime? get lastLogin; String get customValue1; String get customValue2; String get customValue3; String get customValue4;
/// Create a copy of Contact
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ContactCopyWith<Contact> get copyWith => _$ContactCopyWithImpl<Contact>(this as Contact, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Contact&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&(identical(other.sendEmail, sendEmail) || other.sendEmail == sendEmail)&&(identical(other.ccOnly, ccOnly) || other.ccOnly == ccOnly)&&(identical(other.isLocked, isLocked) || other.isLocked == isLocked)&&(identical(other.canSign, canSign) || other.canSign == canSign)&&(identical(other.password, password) || other.password == password)&&(identical(other.portalPlaceholderEmail, portalPlaceholderEmail) || other.portalPlaceholderEmail == portalPlaceholderEmail)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.link, link) || other.link == link)&&(identical(other.contactKey, contactKey) || other.contactKey == contactKey)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,firstName,lastName,email,phone,isPrimary,sendEmail,ccOnly,isLocked,canSign,password,portalPlaceholderEmail,updatedAt,isDeleted,link,contactKey,lastLogin,customValue1,customValue2,customValue3,customValue4]);

@override
String toString() {
  return 'Contact(id: $id, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, isPrimary: $isPrimary, sendEmail: $sendEmail, ccOnly: $ccOnly, isLocked: $isLocked, canSign: $canSign, password: $password, portalPlaceholderEmail: $portalPlaceholderEmail, updatedAt: $updatedAt, isDeleted: $isDeleted, link: $link, contactKey: $contactKey, lastLogin: $lastLogin, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4)';
}


}

/// @nodoc
abstract mixin class $ContactCopyWith<$Res>  {
  factory $ContactCopyWith(Contact value, $Res Function(Contact) _then) = _$ContactCopyWithImpl;
@useResult
$Res call({
 String id, String firstName, String lastName, String email, String phone, bool isPrimary, bool sendEmail, bool ccOnly, bool isLocked, bool canSign, String password, String portalPlaceholderEmail, DateTime updatedAt, bool isDeleted, String link, String contactKey, DateTime? lastLogin, String customValue1, String customValue2, String customValue3, String customValue4
});




}
/// @nodoc
class _$ContactCopyWithImpl<$Res>
    implements $ContactCopyWith<$Res> {
  _$ContactCopyWithImpl(this._self, this._then);

  final Contact _self;
  final $Res Function(Contact) _then;

/// Create a copy of Contact
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? isPrimary = null,Object? sendEmail = null,Object? ccOnly = null,Object? isLocked = null,Object? canSign = null,Object? password = null,Object? portalPlaceholderEmail = null,Object? updatedAt = null,Object? isDeleted = null,Object? link = null,Object? contactKey = null,Object? lastLogin = freezed,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,}) {
  return _then(_self.copyWith(
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
as String,portalPlaceholderEmail: null == portalPlaceholderEmail ? _self.portalPlaceholderEmail : portalPlaceholderEmail // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,contactKey: null == contactKey ? _self.contactKey : contactKey // ignore: cast_nullable_to_non_nullable
as String,lastLogin: freezed == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as DateTime?,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Contact].
extension ContactPatterns on Contact {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Contact value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Contact() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Contact value)  $default,){
final _that = this;
switch (_that) {
case _Contact():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Contact value)?  $default,){
final _that = this;
switch (_that) {
case _Contact() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String firstName,  String lastName,  String email,  String phone,  bool isPrimary,  bool sendEmail,  bool ccOnly,  bool isLocked,  bool canSign,  String password,  String portalPlaceholderEmail,  DateTime updatedAt,  bool isDeleted,  String link,  String contactKey,  DateTime? lastLogin,  String customValue1,  String customValue2,  String customValue3,  String customValue4)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Contact() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.isPrimary,_that.sendEmail,_that.ccOnly,_that.isLocked,_that.canSign,_that.password,_that.portalPlaceholderEmail,_that.updatedAt,_that.isDeleted,_that.link,_that.contactKey,_that.lastLogin,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String firstName,  String lastName,  String email,  String phone,  bool isPrimary,  bool sendEmail,  bool ccOnly,  bool isLocked,  bool canSign,  String password,  String portalPlaceholderEmail,  DateTime updatedAt,  bool isDeleted,  String link,  String contactKey,  DateTime? lastLogin,  String customValue1,  String customValue2,  String customValue3,  String customValue4)  $default,) {final _that = this;
switch (_that) {
case _Contact():
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.isPrimary,_that.sendEmail,_that.ccOnly,_that.isLocked,_that.canSign,_that.password,_that.portalPlaceholderEmail,_that.updatedAt,_that.isDeleted,_that.link,_that.contactKey,_that.lastLogin,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String firstName,  String lastName,  String email,  String phone,  bool isPrimary,  bool sendEmail,  bool ccOnly,  bool isLocked,  bool canSign,  String password,  String portalPlaceholderEmail,  DateTime updatedAt,  bool isDeleted,  String link,  String contactKey,  DateTime? lastLogin,  String customValue1,  String customValue2,  String customValue3,  String customValue4)?  $default,) {final _that = this;
switch (_that) {
case _Contact() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.isPrimary,_that.sendEmail,_that.ccOnly,_that.isLocked,_that.canSign,_that.password,_that.portalPlaceholderEmail,_that.updatedAt,_that.isDeleted,_that.link,_that.contactKey,_that.lastLogin,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4);case _:
  return null;

}
}

}

/// @nodoc


class _Contact implements Contact {
  const _Contact({required this.id, required this.firstName, required this.lastName, required this.email, required this.phone, required this.isPrimary, required this.sendEmail, this.ccOnly = false, this.isLocked = false, this.canSign = false, this.password = '', this.portalPlaceholderEmail = '', required this.updatedAt, required this.isDeleted, this.link = '', this.contactKey = '', this.lastLogin, this.customValue1 = '', this.customValue2 = '', this.customValue3 = '', this.customValue4 = ''});
  

@override final  String id;
@override final  String firstName;
@override final  String lastName;
@override final  String email;
@override final  String phone;
@override final  bool isPrimary;
@override final  bool sendEmail;
@override@JsonKey() final  bool ccOnly;
@override@JsonKey() final  bool isLocked;
// "Authorized to sign" — portal e-signature permission. Editable when the
// company has the relevant module enabled (React parity).
@override@JsonKey() final  bool canSign;
@override@JsonKey() final  String password;
// The address the **server** minted for a contact that had none (see
// [isPortalPlaceholderEmail]) — stripped out of [email] on the way in so
// nothing renders it, kept here so [ContactCopy.toApiJson] can put it back.
// Clearing it instead would be a write the user never asked for, on an
// unrelated save, to the field the portal guard authenticates this contact
// by — and it would never settle, since the next portal visit mints a
// different address. Empty for every contact whose address is real, which
// is what keeps a genuine "user cleared their email" edit going out as ''.
//
// Deliberately not a Drift column: it is re-derived by [Contact.fromApi] on
// every read, because a local save's stored payload *is* `toApiJson`'s
// output and that re-emits the raw value. Omitting the key there instead
// would look equivalent on the wire but round-trip to '' through
// `_domainToCompanion` → `_fromRow`, so the second offline save would clear
// the server's value after all.
@override@JsonKey() final  String portalPlaceholderEmail;
@override final  DateTime updatedAt;
@override final  bool isDeleted;
@override@JsonKey() final  String link;
// Server-assigned stable identifier for the contact. Read-only; echoed
// back on save so the server can match existing portal credentials.
@override@JsonKey() final  String contactKey;
// Last portal login (read-only); null when the contact has never signed
// in. Display-only — not written back.
@override final  DateTime? lastLogin;
@override@JsonKey() final  String customValue1;
@override@JsonKey() final  String customValue2;
@override@JsonKey() final  String customValue3;
@override@JsonKey() final  String customValue4;

/// Create a copy of Contact
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ContactCopyWith<_Contact> get copyWith => __$ContactCopyWithImpl<_Contact>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Contact&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&(identical(other.sendEmail, sendEmail) || other.sendEmail == sendEmail)&&(identical(other.ccOnly, ccOnly) || other.ccOnly == ccOnly)&&(identical(other.isLocked, isLocked) || other.isLocked == isLocked)&&(identical(other.canSign, canSign) || other.canSign == canSign)&&(identical(other.password, password) || other.password == password)&&(identical(other.portalPlaceholderEmail, portalPlaceholderEmail) || other.portalPlaceholderEmail == portalPlaceholderEmail)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.link, link) || other.link == link)&&(identical(other.contactKey, contactKey) || other.contactKey == contactKey)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,firstName,lastName,email,phone,isPrimary,sendEmail,ccOnly,isLocked,canSign,password,portalPlaceholderEmail,updatedAt,isDeleted,link,contactKey,lastLogin,customValue1,customValue2,customValue3,customValue4]);

@override
String toString() {
  return 'Contact(id: $id, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, isPrimary: $isPrimary, sendEmail: $sendEmail, ccOnly: $ccOnly, isLocked: $isLocked, canSign: $canSign, password: $password, portalPlaceholderEmail: $portalPlaceholderEmail, updatedAt: $updatedAt, isDeleted: $isDeleted, link: $link, contactKey: $contactKey, lastLogin: $lastLogin, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4)';
}


}

/// @nodoc
abstract mixin class _$ContactCopyWith<$Res> implements $ContactCopyWith<$Res> {
  factory _$ContactCopyWith(_Contact value, $Res Function(_Contact) _then) = __$ContactCopyWithImpl;
@override @useResult
$Res call({
 String id, String firstName, String lastName, String email, String phone, bool isPrimary, bool sendEmail, bool ccOnly, bool isLocked, bool canSign, String password, String portalPlaceholderEmail, DateTime updatedAt, bool isDeleted, String link, String contactKey, DateTime? lastLogin, String customValue1, String customValue2, String customValue3, String customValue4
});




}
/// @nodoc
class __$ContactCopyWithImpl<$Res>
    implements _$ContactCopyWith<$Res> {
  __$ContactCopyWithImpl(this._self, this._then);

  final _Contact _self;
  final $Res Function(_Contact) _then;

/// Create a copy of Contact
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? isPrimary = null,Object? sendEmail = null,Object? ccOnly = null,Object? isLocked = null,Object? canSign = null,Object? password = null,Object? portalPlaceholderEmail = null,Object? updatedAt = null,Object? isDeleted = null,Object? link = null,Object? contactKey = null,Object? lastLogin = freezed,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,}) {
  return _then(_Contact(
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
as String,portalPlaceholderEmail: null == portalPlaceholderEmail ? _self.portalPlaceholderEmail : portalPlaceholderEmail // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,contactKey: null == contactKey ? _self.contactKey : contactKey // ignore: cast_nullable_to_non_nullable
as String,lastLogin: freezed == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as DateTime?,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
