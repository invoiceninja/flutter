// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vendor.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Vendor {

 String get id; String get name; String get number; String get idNumber; String get vatNumber; String get website; String get phone; String get address1; String get address2; String get city; String get state; String get postalCode; String get countryId; String get currencyId; String get languageId; String get classification; bool get isTaxExempt; String get routingId; String get privateNotes; String get publicNotes; String get userId; String get assignedUserId; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; bool get isDeleted; String get customValue1; String get customValue2; String get customValue3; String get customValue4; List<VendorContact> get contacts;// Last portal login (read-only, display-only); null when never signed in.
 DateTime? get lastLogin; List<Document> get documents; List<String> get tagIds;// Local-only — never sent to the server. Populated by the repository
// from the Drift row's `is_dirty` column so the UI can render an
// "Unsynced" chip on the detail screen.
 bool get isDirty;
/// Create a copy of Vendor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VendorCopyWith<Vendor> get copyWith => _$VendorCopyWithImpl<Vendor>(this as Vendor, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Vendor&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.number, number) || other.number == number)&&(identical(other.idNumber, idNumber) || other.idNumber == idNumber)&&(identical(other.vatNumber, vatNumber) || other.vatNumber == vatNumber)&&(identical(other.website, website) || other.website == website)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.address1, address1) || other.address1 == address1)&&(identical(other.address2, address2) || other.address2 == address2)&&(identical(other.city, city) || other.city == city)&&(identical(other.state, state) || other.state == state)&&(identical(other.postalCode, postalCode) || other.postalCode == postalCode)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.classification, classification) || other.classification == classification)&&(identical(other.isTaxExempt, isTaxExempt) || other.isTaxExempt == isTaxExempt)&&(identical(other.routingId, routingId) || other.routingId == routingId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&const DeepCollectionEquality().equals(other.contacts, contacts)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.tagIds, tagIds)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,number,idNumber,vatNumber,website,phone,address1,address2,city,state,postalCode,countryId,currencyId,languageId,classification,isTaxExempt,routingId,privateNotes,publicNotes,userId,assignedUserId,updatedAt,createdAt,archivedAt,isDeleted,customValue1,customValue2,customValue3,customValue4,const DeepCollectionEquality().hash(contacts),lastLogin,const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(tagIds),isDirty]);

@override
String toString() {
  return 'Vendor(id: $id, name: $name, number: $number, idNumber: $idNumber, vatNumber: $vatNumber, website: $website, phone: $phone, address1: $address1, address2: $address2, city: $city, state: $state, postalCode: $postalCode, countryId: $countryId, currencyId: $currencyId, languageId: $languageId, classification: $classification, isTaxExempt: $isTaxExempt, routingId: $routingId, privateNotes: $privateNotes, publicNotes: $publicNotes, userId: $userId, assignedUserId: $assignedUserId, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDeleted: $isDeleted, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, contacts: $contacts, lastLogin: $lastLogin, documents: $documents, tagIds: $tagIds, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class $VendorCopyWith<$Res>  {
  factory $VendorCopyWith(Vendor value, $Res Function(Vendor) _then) = _$VendorCopyWithImpl;
@useResult
$Res call({
 String id, String name, String number, String idNumber, String vatNumber, String website, String phone, String address1, String address2, String city, String state, String postalCode, String countryId, String currencyId, String languageId, String classification, bool isTaxExempt, String routingId, String privateNotes, String publicNotes, String userId, String assignedUserId, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, String customValue1, String customValue2, String customValue3, String customValue4, List<VendorContact> contacts, DateTime? lastLogin, List<Document> documents, List<String> tagIds, bool isDirty
});




}
/// @nodoc
class _$VendorCopyWithImpl<$Res>
    implements $VendorCopyWith<$Res> {
  _$VendorCopyWithImpl(this._self, this._then);

  final Vendor _self;
  final $Res Function(Vendor) _then;

/// Create a copy of Vendor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? number = null,Object? idNumber = null,Object? vatNumber = null,Object? website = null,Object? phone = null,Object? address1 = null,Object? address2 = null,Object? city = null,Object? state = null,Object? postalCode = null,Object? countryId = null,Object? currencyId = null,Object? languageId = null,Object? classification = null,Object? isTaxExempt = null,Object? routingId = null,Object? privateNotes = null,Object? publicNotes = null,Object? userId = null,Object? assignedUserId = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? contacts = null,Object? lastLogin = freezed,Object? documents = null,Object? tagIds = null,Object? isDirty = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,idNumber: null == idNumber ? _self.idNumber : idNumber // ignore: cast_nullable_to_non_nullable
as String,vatNumber: null == vatNumber ? _self.vatNumber : vatNumber // ignore: cast_nullable_to_non_nullable
as String,website: null == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,address1: null == address1 ? _self.address1 : address1 // ignore: cast_nullable_to_non_nullable
as String,address2: null == address2 ? _self.address2 : address2 // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,postalCode: null == postalCode ? _self.postalCode : postalCode // ignore: cast_nullable_to_non_nullable
as String,countryId: null == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as String,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,languageId: null == languageId ? _self.languageId : languageId // ignore: cast_nullable_to_non_nullable
as String,classification: null == classification ? _self.classification : classification // ignore: cast_nullable_to_non_nullable
as String,isTaxExempt: null == isTaxExempt ? _self.isTaxExempt : isTaxExempt // ignore: cast_nullable_to_non_nullable
as bool,routingId: null == routingId ? _self.routingId : routingId // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,contacts: null == contacts ? _self.contacts : contacts // ignore: cast_nullable_to_non_nullable
as List<VendorContact>,lastLogin: freezed == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as DateTime?,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Vendor].
extension VendorPatterns on Vendor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Vendor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Vendor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Vendor value)  $default,){
final _that = this;
switch (_that) {
case _Vendor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Vendor value)?  $default,){
final _that = this;
switch (_that) {
case _Vendor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String number,  String idNumber,  String vatNumber,  String website,  String phone,  String address1,  String address2,  String city,  String state,  String postalCode,  String countryId,  String currencyId,  String languageId,  String classification,  bool isTaxExempt,  String routingId,  String privateNotes,  String publicNotes,  String userId,  String assignedUserId,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  List<VendorContact> contacts,  DateTime? lastLogin,  List<Document> documents,  List<String> tagIds,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Vendor() when $default != null:
return $default(_that.id,_that.name,_that.number,_that.idNumber,_that.vatNumber,_that.website,_that.phone,_that.address1,_that.address2,_that.city,_that.state,_that.postalCode,_that.countryId,_that.currencyId,_that.languageId,_that.classification,_that.isTaxExempt,_that.routingId,_that.privateNotes,_that.publicNotes,_that.userId,_that.assignedUserId,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.contacts,_that.lastLogin,_that.documents,_that.tagIds,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String number,  String idNumber,  String vatNumber,  String website,  String phone,  String address1,  String address2,  String city,  String state,  String postalCode,  String countryId,  String currencyId,  String languageId,  String classification,  bool isTaxExempt,  String routingId,  String privateNotes,  String publicNotes,  String userId,  String assignedUserId,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  List<VendorContact> contacts,  DateTime? lastLogin,  List<Document> documents,  List<String> tagIds,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _Vendor():
return $default(_that.id,_that.name,_that.number,_that.idNumber,_that.vatNumber,_that.website,_that.phone,_that.address1,_that.address2,_that.city,_that.state,_that.postalCode,_that.countryId,_that.currencyId,_that.languageId,_that.classification,_that.isTaxExempt,_that.routingId,_that.privateNotes,_that.publicNotes,_that.userId,_that.assignedUserId,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.contacts,_that.lastLogin,_that.documents,_that.tagIds,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String number,  String idNumber,  String vatNumber,  String website,  String phone,  String address1,  String address2,  String city,  String state,  String postalCode,  String countryId,  String currencyId,  String languageId,  String classification,  bool isTaxExempt,  String routingId,  String privateNotes,  String publicNotes,  String userId,  String assignedUserId,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  List<VendorContact> contacts,  DateTime? lastLogin,  List<Document> documents,  List<String> tagIds,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _Vendor() when $default != null:
return $default(_that.id,_that.name,_that.number,_that.idNumber,_that.vatNumber,_that.website,_that.phone,_that.address1,_that.address2,_that.city,_that.state,_that.postalCode,_that.countryId,_that.currencyId,_that.languageId,_that.classification,_that.isTaxExempt,_that.routingId,_that.privateNotes,_that.publicNotes,_that.userId,_that.assignedUserId,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.contacts,_that.lastLogin,_that.documents,_that.tagIds,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _Vendor implements Vendor {
  const _Vendor({required this.id, required this.name, required this.number, required this.idNumber, required this.vatNumber, required this.website, required this.phone, required this.address1, required this.address2, required this.city, required this.state, required this.postalCode, required this.countryId, required this.currencyId, this.languageId = '', this.classification = '', this.isTaxExempt = false, this.routingId = '', required this.privateNotes, required this.publicNotes, required this.userId, required this.assignedUserId, required this.updatedAt, required this.createdAt, required this.archivedAt, required this.isDeleted, required this.customValue1, required this.customValue2, required this.customValue3, required this.customValue4, required final  List<VendorContact> contacts, this.lastLogin, final  List<Document> documents = const <Document>[], final  List<String> tagIds = const <String>[], this.isDirty = false}): _contacts = contacts,_documents = documents,_tagIds = tagIds;
  

@override final  String id;
@override final  String name;
@override final  String number;
@override final  String idNumber;
@override final  String vatNumber;
@override final  String website;
@override final  String phone;
@override final  String address1;
@override final  String address2;
@override final  String city;
@override final  String state;
@override final  String postalCode;
@override final  String countryId;
@override final  String currencyId;
@override@JsonKey() final  String languageId;
@override@JsonKey() final  String classification;
@override@JsonKey() final  bool isTaxExempt;
@override@JsonKey() final  String routingId;
@override final  String privateNotes;
@override final  String publicNotes;
@override final  String userId;
@override final  String assignedUserId;
@override final  DateTime updatedAt;
@override final  DateTime createdAt;
@override final  DateTime? archivedAt;
@override final  bool isDeleted;
@override final  String customValue1;
@override final  String customValue2;
@override final  String customValue3;
@override final  String customValue4;
 final  List<VendorContact> _contacts;
@override List<VendorContact> get contacts {
  if (_contacts is EqualUnmodifiableListView) return _contacts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_contacts);
}

// Last portal login (read-only, display-only); null when never signed in.
@override final  DateTime? lastLogin;
 final  List<Document> _documents;
@override@JsonKey() List<Document> get documents {
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_documents);
}

 final  List<String> _tagIds;
@override@JsonKey() List<String> get tagIds {
  if (_tagIds is EqualUnmodifiableListView) return _tagIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tagIds);
}

// Local-only — never sent to the server. Populated by the repository
// from the Drift row's `is_dirty` column so the UI can render an
// "Unsynced" chip on the detail screen.
@override@JsonKey() final  bool isDirty;

/// Create a copy of Vendor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VendorCopyWith<_Vendor> get copyWith => __$VendorCopyWithImpl<_Vendor>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Vendor&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.number, number) || other.number == number)&&(identical(other.idNumber, idNumber) || other.idNumber == idNumber)&&(identical(other.vatNumber, vatNumber) || other.vatNumber == vatNumber)&&(identical(other.website, website) || other.website == website)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.address1, address1) || other.address1 == address1)&&(identical(other.address2, address2) || other.address2 == address2)&&(identical(other.city, city) || other.city == city)&&(identical(other.state, state) || other.state == state)&&(identical(other.postalCode, postalCode) || other.postalCode == postalCode)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.classification, classification) || other.classification == classification)&&(identical(other.isTaxExempt, isTaxExempt) || other.isTaxExempt == isTaxExempt)&&(identical(other.routingId, routingId) || other.routingId == routingId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&const DeepCollectionEquality().equals(other._contacts, _contacts)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._tagIds, _tagIds)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,name,number,idNumber,vatNumber,website,phone,address1,address2,city,state,postalCode,countryId,currencyId,languageId,classification,isTaxExempt,routingId,privateNotes,publicNotes,userId,assignedUserId,updatedAt,createdAt,archivedAt,isDeleted,customValue1,customValue2,customValue3,customValue4,const DeepCollectionEquality().hash(_contacts),lastLogin,const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_tagIds),isDirty]);

@override
String toString() {
  return 'Vendor(id: $id, name: $name, number: $number, idNumber: $idNumber, vatNumber: $vatNumber, website: $website, phone: $phone, address1: $address1, address2: $address2, city: $city, state: $state, postalCode: $postalCode, countryId: $countryId, currencyId: $currencyId, languageId: $languageId, classification: $classification, isTaxExempt: $isTaxExempt, routingId: $routingId, privateNotes: $privateNotes, publicNotes: $publicNotes, userId: $userId, assignedUserId: $assignedUserId, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDeleted: $isDeleted, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, contacts: $contacts, lastLogin: $lastLogin, documents: $documents, tagIds: $tagIds, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$VendorCopyWith<$Res> implements $VendorCopyWith<$Res> {
  factory _$VendorCopyWith(_Vendor value, $Res Function(_Vendor) _then) = __$VendorCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String number, String idNumber, String vatNumber, String website, String phone, String address1, String address2, String city, String state, String postalCode, String countryId, String currencyId, String languageId, String classification, bool isTaxExempt, String routingId, String privateNotes, String publicNotes, String userId, String assignedUserId, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, String customValue1, String customValue2, String customValue3, String customValue4, List<VendorContact> contacts, DateTime? lastLogin, List<Document> documents, List<String> tagIds, bool isDirty
});




}
/// @nodoc
class __$VendorCopyWithImpl<$Res>
    implements _$VendorCopyWith<$Res> {
  __$VendorCopyWithImpl(this._self, this._then);

  final _Vendor _self;
  final $Res Function(_Vendor) _then;

/// Create a copy of Vendor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? number = null,Object? idNumber = null,Object? vatNumber = null,Object? website = null,Object? phone = null,Object? address1 = null,Object? address2 = null,Object? city = null,Object? state = null,Object? postalCode = null,Object? countryId = null,Object? currencyId = null,Object? languageId = null,Object? classification = null,Object? isTaxExempt = null,Object? routingId = null,Object? privateNotes = null,Object? publicNotes = null,Object? userId = null,Object? assignedUserId = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? contacts = null,Object? lastLogin = freezed,Object? documents = null,Object? tagIds = null,Object? isDirty = null,}) {
  return _then(_Vendor(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,idNumber: null == idNumber ? _self.idNumber : idNumber // ignore: cast_nullable_to_non_nullable
as String,vatNumber: null == vatNumber ? _self.vatNumber : vatNumber // ignore: cast_nullable_to_non_nullable
as String,website: null == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,address1: null == address1 ? _self.address1 : address1 // ignore: cast_nullable_to_non_nullable
as String,address2: null == address2 ? _self.address2 : address2 // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,postalCode: null == postalCode ? _self.postalCode : postalCode // ignore: cast_nullable_to_non_nullable
as String,countryId: null == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as String,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,languageId: null == languageId ? _self.languageId : languageId // ignore: cast_nullable_to_non_nullable
as String,classification: null == classification ? _self.classification : classification // ignore: cast_nullable_to_non_nullable
as String,isTaxExempt: null == isTaxExempt ? _self.isTaxExempt : isTaxExempt // ignore: cast_nullable_to_non_nullable
as bool,routingId: null == routingId ? _self.routingId : routingId // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,contacts: null == contacts ? _self._contacts : contacts // ignore: cast_nullable_to_non_nullable
as List<VendorContact>,lastLogin: freezed == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as DateTime?,documents: null == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
