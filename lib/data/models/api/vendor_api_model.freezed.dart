// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vendor_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VendorApi {

 String get id; String get name; String get number;@JsonKey(name: 'id_number') String get idNumber;@JsonKey(name: 'vat_number') String get vatNumber; String get website; String get phone; String get address1; String get address2; String get city; String get state;@JsonKey(name: 'postal_code') String get postalCode;@JsonKey(name: 'country_id') String get countryId;@JsonKey(name: 'currency_id') String get currencyId;@JsonKey(name: 'language_id') String get languageId; String get classification;@JsonKey(name: 'is_tax_exempt') bool get isTaxExempt;@JsonKey(name: 'routing_id') String get routingId;@JsonKey(name: 'private_notes') String get privateNotes;@JsonKey(name: 'public_notes') String get publicNotes;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;@JsonKey(name: 'assigned_user_id') String get assignedUserId;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'last_login') int get lastLogin;@JsonKey(name: 'is_deleted') bool get isDeleted; List<VendorContactApi> get contacts;// Nullable on purpose: the IN list endpoint omits `documents` unless
// `?include=documents` is requested. Distinguishing "key missing"
// (→ null) from "key present, array empty" (→ `const []`) lets
// `_apiToCompanion` preserve local docs on responses that didn't
// include them while still propagating server-side deletes on
// responses that did. See `VendorRepository._apiToCompanion`.
 List<DocumentApi>? get documents;@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags;
/// Create a copy of VendorApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VendorApiCopyWith<VendorApi> get copyWith => _$VendorApiCopyWithImpl<VendorApi>(this as VendorApi, _$identity);

  /// Serializes this VendorApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VendorApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.number, number) || other.number == number)&&(identical(other.idNumber, idNumber) || other.idNumber == idNumber)&&(identical(other.vatNumber, vatNumber) || other.vatNumber == vatNumber)&&(identical(other.website, website) || other.website == website)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.address1, address1) || other.address1 == address1)&&(identical(other.address2, address2) || other.address2 == address2)&&(identical(other.city, city) || other.city == city)&&(identical(other.state, state) || other.state == state)&&(identical(other.postalCode, postalCode) || other.postalCode == postalCode)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.classification, classification) || other.classification == classification)&&(identical(other.isTaxExempt, isTaxExempt) || other.isTaxExempt == isTaxExempt)&&(identical(other.routingId, routingId) || other.routingId == routingId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other.contacts, contacts)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.tags, tags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,number,idNumber,vatNumber,website,phone,address1,address2,city,state,postalCode,countryId,currencyId,languageId,classification,isTaxExempt,routingId,privateNotes,publicNotes,customValue1,customValue2,customValue3,customValue4,assignedUserId,userId,createdAt,updatedAt,archivedAt,lastLogin,isDeleted,const DeepCollectionEquality().hash(contacts),const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(tags)]);

@override
String toString() {
  return 'VendorApi(id: $id, name: $name, number: $number, idNumber: $idNumber, vatNumber: $vatNumber, website: $website, phone: $phone, address1: $address1, address2: $address2, city: $city, state: $state, postalCode: $postalCode, countryId: $countryId, currencyId: $currencyId, languageId: $languageId, classification: $classification, isTaxExempt: $isTaxExempt, routingId: $routingId, privateNotes: $privateNotes, publicNotes: $publicNotes, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, assignedUserId: $assignedUserId, userId: $userId, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, lastLogin: $lastLogin, isDeleted: $isDeleted, contacts: $contacts, documents: $documents, tags: $tags)';
}


}

/// @nodoc
abstract mixin class $VendorApiCopyWith<$Res>  {
  factory $VendorApiCopyWith(VendorApi value, $Res Function(VendorApi) _then) = _$VendorApiCopyWithImpl;
@useResult
$Res call({
 String id, String name, String number,@JsonKey(name: 'id_number') String idNumber,@JsonKey(name: 'vat_number') String vatNumber, String website, String phone, String address1, String address2, String city, String state,@JsonKey(name: 'postal_code') String postalCode,@JsonKey(name: 'country_id') String countryId,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'language_id') String languageId, String classification,@JsonKey(name: 'is_tax_exempt') bool isTaxExempt,@JsonKey(name: 'routing_id') String routingId,@JsonKey(name: 'private_notes') String privateNotes,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'last_login') int lastLogin,@JsonKey(name: 'is_deleted') bool isDeleted, List<VendorContactApi> contacts, List<DocumentApi>? documents,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags
});




}
/// @nodoc
class _$VendorApiCopyWithImpl<$Res>
    implements $VendorApiCopyWith<$Res> {
  _$VendorApiCopyWithImpl(this._self, this._then);

  final VendorApi _self;
  final $Res Function(VendorApi) _then;

/// Create a copy of VendorApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? number = null,Object? idNumber = null,Object? vatNumber = null,Object? website = null,Object? phone = null,Object? address1 = null,Object? address2 = null,Object? city = null,Object? state = null,Object? postalCode = null,Object? countryId = null,Object? currencyId = null,Object? languageId = null,Object? classification = null,Object? isTaxExempt = null,Object? routingId = null,Object? privateNotes = null,Object? publicNotes = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? assignedUserId = null,Object? userId = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? lastLogin = null,Object? isDeleted = null,Object? contacts = null,Object? documents = freezed,Object? tags = null,}) {
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
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,lastLogin: null == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,contacts: null == contacts ? _self.contacts : contacts // ignore: cast_nullable_to_non_nullable
as List<VendorContactApi>,documents: freezed == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [VendorApi].
extension VendorApiPatterns on VendorApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VendorApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VendorApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VendorApi value)  $default,){
final _that = this;
switch (_that) {
case _VendorApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VendorApi value)?  $default,){
final _that = this;
switch (_that) {
case _VendorApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String number, @JsonKey(name: 'id_number')  String idNumber, @JsonKey(name: 'vat_number')  String vatNumber,  String website,  String phone,  String address1,  String address2,  String city,  String state, @JsonKey(name: 'postal_code')  String postalCode, @JsonKey(name: 'country_id')  String countryId, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'language_id')  String languageId,  String classification, @JsonKey(name: 'is_tax_exempt')  bool isTaxExempt, @JsonKey(name: 'routing_id')  String routingId, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'is_deleted')  bool isDeleted,  List<VendorContactApi> contacts,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VendorApi() when $default != null:
return $default(_that.id,_that.name,_that.number,_that.idNumber,_that.vatNumber,_that.website,_that.phone,_that.address1,_that.address2,_that.city,_that.state,_that.postalCode,_that.countryId,_that.currencyId,_that.languageId,_that.classification,_that.isTaxExempt,_that.routingId,_that.privateNotes,_that.publicNotes,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.assignedUserId,_that.userId,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.lastLogin,_that.isDeleted,_that.contacts,_that.documents,_that.tags);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String number, @JsonKey(name: 'id_number')  String idNumber, @JsonKey(name: 'vat_number')  String vatNumber,  String website,  String phone,  String address1,  String address2,  String city,  String state, @JsonKey(name: 'postal_code')  String postalCode, @JsonKey(name: 'country_id')  String countryId, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'language_id')  String languageId,  String classification, @JsonKey(name: 'is_tax_exempt')  bool isTaxExempt, @JsonKey(name: 'routing_id')  String routingId, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'is_deleted')  bool isDeleted,  List<VendorContactApi> contacts,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags)  $default,) {final _that = this;
switch (_that) {
case _VendorApi():
return $default(_that.id,_that.name,_that.number,_that.idNumber,_that.vatNumber,_that.website,_that.phone,_that.address1,_that.address2,_that.city,_that.state,_that.postalCode,_that.countryId,_that.currencyId,_that.languageId,_that.classification,_that.isTaxExempt,_that.routingId,_that.privateNotes,_that.publicNotes,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.assignedUserId,_that.userId,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.lastLogin,_that.isDeleted,_that.contacts,_that.documents,_that.tags);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String number, @JsonKey(name: 'id_number')  String idNumber, @JsonKey(name: 'vat_number')  String vatNumber,  String website,  String phone,  String address1,  String address2,  String city,  String state, @JsonKey(name: 'postal_code')  String postalCode, @JsonKey(name: 'country_id')  String countryId, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'language_id')  String languageId,  String classification, @JsonKey(name: 'is_tax_exempt')  bool isTaxExempt, @JsonKey(name: 'routing_id')  String routingId, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'is_deleted')  bool isDeleted,  List<VendorContactApi> contacts,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags)?  $default,) {final _that = this;
switch (_that) {
case _VendorApi() when $default != null:
return $default(_that.id,_that.name,_that.number,_that.idNumber,_that.vatNumber,_that.website,_that.phone,_that.address1,_that.address2,_that.city,_that.state,_that.postalCode,_that.countryId,_that.currencyId,_that.languageId,_that.classification,_that.isTaxExempt,_that.routingId,_that.privateNotes,_that.publicNotes,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.assignedUserId,_that.userId,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.lastLogin,_that.isDeleted,_that.contacts,_that.documents,_that.tags);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VendorApi implements VendorApi {
  const _VendorApi({this.id = '', this.name = '', this.number = '', @JsonKey(name: 'id_number') this.idNumber = '', @JsonKey(name: 'vat_number') this.vatNumber = '', this.website = '', this.phone = '', this.address1 = '', this.address2 = '', this.city = '', this.state = '', @JsonKey(name: 'postal_code') this.postalCode = '', @JsonKey(name: 'country_id') this.countryId = '', @JsonKey(name: 'currency_id') this.currencyId = '', @JsonKey(name: 'language_id') this.languageId = '', this.classification = '', @JsonKey(name: 'is_tax_exempt') this.isTaxExempt = false, @JsonKey(name: 'routing_id') this.routingId = '', @JsonKey(name: 'private_notes') this.privateNotes = '', @JsonKey(name: 'public_notes') this.publicNotes = '', @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'last_login') this.lastLogin = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false, final  List<VendorContactApi> contacts = const <VendorContactApi>[], final  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter() final  List<TagRefApi> tags = const <TagRefApi>[]}): _contacts = contacts,_documents = documents,_tags = tags;
  factory _VendorApi.fromJson(Map<String, dynamic> json) => _$VendorApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String number;
@override@JsonKey(name: 'id_number') final  String idNumber;
@override@JsonKey(name: 'vat_number') final  String vatNumber;
@override@JsonKey() final  String website;
@override@JsonKey() final  String phone;
@override@JsonKey() final  String address1;
@override@JsonKey() final  String address2;
@override@JsonKey() final  String city;
@override@JsonKey() final  String state;
@override@JsonKey(name: 'postal_code') final  String postalCode;
@override@JsonKey(name: 'country_id') final  String countryId;
@override@JsonKey(name: 'currency_id') final  String currencyId;
@override@JsonKey(name: 'language_id') final  String languageId;
@override@JsonKey() final  String classification;
@override@JsonKey(name: 'is_tax_exempt') final  bool isTaxExempt;
@override@JsonKey(name: 'routing_id') final  String routingId;
@override@JsonKey(name: 'private_notes') final  String privateNotes;
@override@JsonKey(name: 'public_notes') final  String publicNotes;
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
@override@JsonKey(name: 'assigned_user_id') final  String assignedUserId;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'last_login') final  int lastLogin;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
 final  List<VendorContactApi> _contacts;
@override@JsonKey() List<VendorContactApi> get contacts {
  if (_contacts is EqualUnmodifiableListView) return _contacts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_contacts);
}

// Nullable on purpose: the IN list endpoint omits `documents` unless
// `?include=documents` is requested. Distinguishing "key missing"
// (→ null) from "key present, array empty" (→ `const []`) lets
// `_apiToCompanion` preserve local docs on responses that didn't
// include them while still propagating server-side deletes on
// responses that did. See `VendorRepository._apiToCompanion`.
 final  List<DocumentApi>? _documents;
// Nullable on purpose: the IN list endpoint omits `documents` unless
// `?include=documents` is requested. Distinguishing "key missing"
// (→ null) from "key present, array empty" (→ `const []`) lets
// `_apiToCompanion` preserve local docs on responses that didn't
// include them while still propagating server-side deletes on
// responses that did. See `VendorRepository._apiToCompanion`.
@override List<DocumentApi>? get documents {
  final value = _documents;
  if (value == null) return null;
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<TagRefApi> _tags;
@override@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}


/// Create a copy of VendorApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VendorApiCopyWith<_VendorApi> get copyWith => __$VendorApiCopyWithImpl<_VendorApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VendorApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VendorApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.number, number) || other.number == number)&&(identical(other.idNumber, idNumber) || other.idNumber == idNumber)&&(identical(other.vatNumber, vatNumber) || other.vatNumber == vatNumber)&&(identical(other.website, website) || other.website == website)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.address1, address1) || other.address1 == address1)&&(identical(other.address2, address2) || other.address2 == address2)&&(identical(other.city, city) || other.city == city)&&(identical(other.state, state) || other.state == state)&&(identical(other.postalCode, postalCode) || other.postalCode == postalCode)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.classification, classification) || other.classification == classification)&&(identical(other.isTaxExempt, isTaxExempt) || other.isTaxExempt == isTaxExempt)&&(identical(other.routingId, routingId) || other.routingId == routingId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other._contacts, _contacts)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._tags, _tags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,number,idNumber,vatNumber,website,phone,address1,address2,city,state,postalCode,countryId,currencyId,languageId,classification,isTaxExempt,routingId,privateNotes,publicNotes,customValue1,customValue2,customValue3,customValue4,assignedUserId,userId,createdAt,updatedAt,archivedAt,lastLogin,isDeleted,const DeepCollectionEquality().hash(_contacts),const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_tags)]);

@override
String toString() {
  return 'VendorApi(id: $id, name: $name, number: $number, idNumber: $idNumber, vatNumber: $vatNumber, website: $website, phone: $phone, address1: $address1, address2: $address2, city: $city, state: $state, postalCode: $postalCode, countryId: $countryId, currencyId: $currencyId, languageId: $languageId, classification: $classification, isTaxExempt: $isTaxExempt, routingId: $routingId, privateNotes: $privateNotes, publicNotes: $publicNotes, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, assignedUserId: $assignedUserId, userId: $userId, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, lastLogin: $lastLogin, isDeleted: $isDeleted, contacts: $contacts, documents: $documents, tags: $tags)';
}


}

/// @nodoc
abstract mixin class _$VendorApiCopyWith<$Res> implements $VendorApiCopyWith<$Res> {
  factory _$VendorApiCopyWith(_VendorApi value, $Res Function(_VendorApi) _then) = __$VendorApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String number,@JsonKey(name: 'id_number') String idNumber,@JsonKey(name: 'vat_number') String vatNumber, String website, String phone, String address1, String address2, String city, String state,@JsonKey(name: 'postal_code') String postalCode,@JsonKey(name: 'country_id') String countryId,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'language_id') String languageId, String classification,@JsonKey(name: 'is_tax_exempt') bool isTaxExempt,@JsonKey(name: 'routing_id') String routingId,@JsonKey(name: 'private_notes') String privateNotes,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'last_login') int lastLogin,@JsonKey(name: 'is_deleted') bool isDeleted, List<VendorContactApi> contacts, List<DocumentApi>? documents,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags
});




}
/// @nodoc
class __$VendorApiCopyWithImpl<$Res>
    implements _$VendorApiCopyWith<$Res> {
  __$VendorApiCopyWithImpl(this._self, this._then);

  final _VendorApi _self;
  final $Res Function(_VendorApi) _then;

/// Create a copy of VendorApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? number = null,Object? idNumber = null,Object? vatNumber = null,Object? website = null,Object? phone = null,Object? address1 = null,Object? address2 = null,Object? city = null,Object? state = null,Object? postalCode = null,Object? countryId = null,Object? currencyId = null,Object? languageId = null,Object? classification = null,Object? isTaxExempt = null,Object? routingId = null,Object? privateNotes = null,Object? publicNotes = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? assignedUserId = null,Object? userId = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? lastLogin = null,Object? isDeleted = null,Object? contacts = null,Object? documents = freezed,Object? tags = null,}) {
  return _then(_VendorApi(
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
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,lastLogin: null == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,contacts: null == contacts ? _self._contacts : contacts // ignore: cast_nullable_to_non_nullable
as List<VendorContactApi>,documents: freezed == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,
  ));
}


}


/// @nodoc
mixin _$VendorContactApi {

 String get id;@JsonKey(name: 'first_name') String get firstName;@JsonKey(name: 'last_name') String get lastName; String get email; String get phone; String get password;@JsonKey(name: 'send_email') bool get sendEmail;@JsonKey(name: 'cc_only') bool get ccOnly;@JsonKey(name: 'is_primary') bool get isPrimary;@JsonKey(name: 'can_sign') bool get canSign; String get link;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'last_login') int get lastLogin;@JsonKey(name: 'is_deleted') bool get isDeleted;
/// Create a copy of VendorContactApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VendorContactApiCopyWith<VendorContactApi> get copyWith => _$VendorContactApiCopyWithImpl<VendorContactApi>(this as VendorContactApi, _$identity);

  /// Serializes this VendorContactApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VendorContactApi&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.password, password) || other.password == password)&&(identical(other.sendEmail, sendEmail) || other.sendEmail == sendEmail)&&(identical(other.ccOnly, ccOnly) || other.ccOnly == ccOnly)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&(identical(other.canSign, canSign) || other.canSign == canSign)&&(identical(other.link, link) || other.link == link)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,firstName,lastName,email,phone,password,sendEmail,ccOnly,isPrimary,canSign,link,customValue1,customValue2,customValue3,customValue4,createdAt,updatedAt,archivedAt,lastLogin,isDeleted]);

@override
String toString() {
  return 'VendorContactApi(id: $id, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, password: $password, sendEmail: $sendEmail, ccOnly: $ccOnly, isPrimary: $isPrimary, canSign: $canSign, link: $link, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, lastLogin: $lastLogin, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class $VendorContactApiCopyWith<$Res>  {
  factory $VendorContactApiCopyWith(VendorContactApi value, $Res Function(VendorContactApi) _then) = _$VendorContactApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'first_name') String firstName,@JsonKey(name: 'last_name') String lastName, String email, String phone, String password,@JsonKey(name: 'send_email') bool sendEmail,@JsonKey(name: 'cc_only') bool ccOnly,@JsonKey(name: 'is_primary') bool isPrimary,@JsonKey(name: 'can_sign') bool canSign, String link,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'last_login') int lastLogin,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class _$VendorContactApiCopyWithImpl<$Res>
    implements $VendorContactApiCopyWith<$Res> {
  _$VendorContactApiCopyWithImpl(this._self, this._then);

  final VendorContactApi _self;
  final $Res Function(VendorContactApi) _then;

/// Create a copy of VendorContactApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? password = null,Object? sendEmail = null,Object? ccOnly = null,Object? isPrimary = null,Object? canSign = null,Object? link = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? lastLogin = null,Object? isDeleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,sendEmail: null == sendEmail ? _self.sendEmail : sendEmail // ignore: cast_nullable_to_non_nullable
as bool,ccOnly: null == ccOnly ? _self.ccOnly : ccOnly // ignore: cast_nullable_to_non_nullable
as bool,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,canSign: null == canSign ? _self.canSign : canSign // ignore: cast_nullable_to_non_nullable
as bool,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,lastLogin: null == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VendorContactApi].
extension VendorContactApiPatterns on VendorContactApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VendorContactApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VendorContactApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VendorContactApi value)  $default,){
final _that = this;
switch (_that) {
case _VendorContactApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VendorContactApi value)?  $default,){
final _that = this;
switch (_that) {
case _VendorContactApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'first_name')  String firstName, @JsonKey(name: 'last_name')  String lastName,  String email,  String phone,  String password, @JsonKey(name: 'send_email')  bool sendEmail, @JsonKey(name: 'cc_only')  bool ccOnly, @JsonKey(name: 'is_primary')  bool isPrimary, @JsonKey(name: 'can_sign')  bool canSign,  String link, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VendorContactApi() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.password,_that.sendEmail,_that.ccOnly,_that.isPrimary,_that.canSign,_that.link,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.lastLogin,_that.isDeleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'first_name')  String firstName, @JsonKey(name: 'last_name')  String lastName,  String email,  String phone,  String password, @JsonKey(name: 'send_email')  bool sendEmail, @JsonKey(name: 'cc_only')  bool ccOnly, @JsonKey(name: 'is_primary')  bool isPrimary, @JsonKey(name: 'can_sign')  bool canSign,  String link, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'is_deleted')  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _VendorContactApi():
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.password,_that.sendEmail,_that.ccOnly,_that.isPrimary,_that.canSign,_that.link,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.lastLogin,_that.isDeleted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'first_name')  String firstName, @JsonKey(name: 'last_name')  String lastName,  String email,  String phone,  String password, @JsonKey(name: 'send_email')  bool sendEmail, @JsonKey(name: 'cc_only')  bool ccOnly, @JsonKey(name: 'is_primary')  bool isPrimary, @JsonKey(name: 'can_sign')  bool canSign,  String link, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _VendorContactApi() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.email,_that.phone,_that.password,_that.sendEmail,_that.ccOnly,_that.isPrimary,_that.canSign,_that.link,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.lastLogin,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VendorContactApi implements VendorContactApi {
  const _VendorContactApi({this.id = '', @JsonKey(name: 'first_name') this.firstName = '', @JsonKey(name: 'last_name') this.lastName = '', this.email = '', this.phone = '', this.password = '', @JsonKey(name: 'send_email') this.sendEmail = true, @JsonKey(name: 'cc_only') this.ccOnly = false, @JsonKey(name: 'is_primary') this.isPrimary = false, @JsonKey(name: 'can_sign') this.canSign = false, this.link = '', @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'last_login') this.lastLogin = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false});
  factory _VendorContactApi.fromJson(Map<String, dynamic> json) => _$VendorContactApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'first_name') final  String firstName;
@override@JsonKey(name: 'last_name') final  String lastName;
@override@JsonKey() final  String email;
@override@JsonKey() final  String phone;
@override@JsonKey() final  String password;
@override@JsonKey(name: 'send_email') final  bool sendEmail;
@override@JsonKey(name: 'cc_only') final  bool ccOnly;
@override@JsonKey(name: 'is_primary') final  bool isPrimary;
@override@JsonKey(name: 'can_sign') final  bool canSign;
@override@JsonKey() final  String link;
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'last_login') final  int lastLogin;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;

/// Create a copy of VendorContactApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VendorContactApiCopyWith<_VendorContactApi> get copyWith => __$VendorContactApiCopyWithImpl<_VendorContactApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VendorContactApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VendorContactApi&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.password, password) || other.password == password)&&(identical(other.sendEmail, sendEmail) || other.sendEmail == sendEmail)&&(identical(other.ccOnly, ccOnly) || other.ccOnly == ccOnly)&&(identical(other.isPrimary, isPrimary) || other.isPrimary == isPrimary)&&(identical(other.canSign, canSign) || other.canSign == canSign)&&(identical(other.link, link) || other.link == link)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,firstName,lastName,email,phone,password,sendEmail,ccOnly,isPrimary,canSign,link,customValue1,customValue2,customValue3,customValue4,createdAt,updatedAt,archivedAt,lastLogin,isDeleted]);

@override
String toString() {
  return 'VendorContactApi(id: $id, firstName: $firstName, lastName: $lastName, email: $email, phone: $phone, password: $password, sendEmail: $sendEmail, ccOnly: $ccOnly, isPrimary: $isPrimary, canSign: $canSign, link: $link, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, lastLogin: $lastLogin, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$VendorContactApiCopyWith<$Res> implements $VendorContactApiCopyWith<$Res> {
  factory _$VendorContactApiCopyWith(_VendorContactApi value, $Res Function(_VendorContactApi) _then) = __$VendorContactApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'first_name') String firstName,@JsonKey(name: 'last_name') String lastName, String email, String phone, String password,@JsonKey(name: 'send_email') bool sendEmail,@JsonKey(name: 'cc_only') bool ccOnly,@JsonKey(name: 'is_primary') bool isPrimary,@JsonKey(name: 'can_sign') bool canSign, String link,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'last_login') int lastLogin,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class __$VendorContactApiCopyWithImpl<$Res>
    implements _$VendorContactApiCopyWith<$Res> {
  __$VendorContactApiCopyWithImpl(this._self, this._then);

  final _VendorContactApi _self;
  final $Res Function(_VendorContactApi) _then;

/// Create a copy of VendorContactApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? firstName = null,Object? lastName = null,Object? email = null,Object? phone = null,Object? password = null,Object? sendEmail = null,Object? ccOnly = null,Object? isPrimary = null,Object? canSign = null,Object? link = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? lastLogin = null,Object? isDeleted = null,}) {
  return _then(_VendorContactApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: null == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,password: null == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String,sendEmail: null == sendEmail ? _self.sendEmail : sendEmail // ignore: cast_nullable_to_non_nullable
as bool,ccOnly: null == ccOnly ? _self.ccOnly : ccOnly // ignore: cast_nullable_to_non_nullable
as bool,isPrimary: null == isPrimary ? _self.isPrimary : isPrimary // ignore: cast_nullable_to_non_nullable
as bool,canSign: null == canSign ? _self.canSign : canSign // ignore: cast_nullable_to_non_nullable
as bool,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,lastLogin: null == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$VendorListApi {

@JsonKey(fromJson: _vendorListData) List<VendorApi> get data;
/// Create a copy of VendorListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VendorListApiCopyWith<VendorListApi> get copyWith => _$VendorListApiCopyWithImpl<VendorListApi>(this as VendorListApi, _$identity);

  /// Serializes this VendorListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VendorListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'VendorListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $VendorListApiCopyWith<$Res>  {
  factory $VendorListApiCopyWith(VendorListApi value, $Res Function(VendorListApi) _then) = _$VendorListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _vendorListData) List<VendorApi> data
});




}
/// @nodoc
class _$VendorListApiCopyWithImpl<$Res>
    implements $VendorListApiCopyWith<$Res> {
  _$VendorListApiCopyWithImpl(this._self, this._then);

  final VendorListApi _self;
  final $Res Function(VendorListApi) _then;

/// Create a copy of VendorListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<VendorApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [VendorListApi].
extension VendorListApiPatterns on VendorListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VendorListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VendorListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VendorListApi value)  $default,){
final _that = this;
switch (_that) {
case _VendorListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VendorListApi value)?  $default,){
final _that = this;
switch (_that) {
case _VendorListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _vendorListData)  List<VendorApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VendorListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _vendorListData)  List<VendorApi> data)  $default,) {final _that = this;
switch (_that) {
case _VendorListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _vendorListData)  List<VendorApi> data)?  $default,) {final _that = this;
switch (_that) {
case _VendorListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VendorListApi implements VendorListApi {
  const _VendorListApi({@JsonKey(fromJson: _vendorListData) final  List<VendorApi> data = const <VendorApi>[]}): _data = data;
  factory _VendorListApi.fromJson(Map<String, dynamic> json) => _$VendorListApiFromJson(json);

 final  List<VendorApi> _data;
@override@JsonKey(fromJson: _vendorListData) List<VendorApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of VendorListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VendorListApiCopyWith<_VendorListApi> get copyWith => __$VendorListApiCopyWithImpl<_VendorListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VendorListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VendorListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'VendorListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$VendorListApiCopyWith<$Res> implements $VendorListApiCopyWith<$Res> {
  factory _$VendorListApiCopyWith(_VendorListApi value, $Res Function(_VendorListApi) _then) = __$VendorListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _vendorListData) List<VendorApi> data
});




}
/// @nodoc
class __$VendorListApiCopyWithImpl<$Res>
    implements _$VendorListApiCopyWith<$Res> {
  __$VendorListApiCopyWithImpl(this._self, this._then);

  final _VendorListApi _self;
  final $Res Function(_VendorListApi) _then;

/// Create a copy of VendorListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_VendorListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<VendorApi>,
  ));
}


}


/// @nodoc
mixin _$VendorItemApi {

 VendorApi get data;
/// Create a copy of VendorItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VendorItemApiCopyWith<VendorItemApi> get copyWith => _$VendorItemApiCopyWithImpl<VendorItemApi>(this as VendorItemApi, _$identity);

  /// Serializes this VendorItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VendorItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'VendorItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $VendorItemApiCopyWith<$Res>  {
  factory $VendorItemApiCopyWith(VendorItemApi value, $Res Function(VendorItemApi) _then) = _$VendorItemApiCopyWithImpl;
@useResult
$Res call({
 VendorApi data
});


$VendorApiCopyWith<$Res> get data;

}
/// @nodoc
class _$VendorItemApiCopyWithImpl<$Res>
    implements $VendorItemApiCopyWith<$Res> {
  _$VendorItemApiCopyWithImpl(this._self, this._then);

  final VendorItemApi _self;
  final $Res Function(VendorItemApi) _then;

/// Create a copy of VendorItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as VendorApi,
  ));
}
/// Create a copy of VendorItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VendorApiCopyWith<$Res> get data {
  
  return $VendorApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [VendorItemApi].
extension VendorItemApiPatterns on VendorItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VendorItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VendorItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VendorItemApi value)  $default,){
final _that = this;
switch (_that) {
case _VendorItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VendorItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _VendorItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VendorApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VendorItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VendorApi data)  $default,) {final _that = this;
switch (_that) {
case _VendorItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VendorApi data)?  $default,) {final _that = this;
switch (_that) {
case _VendorItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VendorItemApi implements VendorItemApi {
  const _VendorItemApi({required this.data});
  factory _VendorItemApi.fromJson(Map<String, dynamic> json) => _$VendorItemApiFromJson(json);

@override final  VendorApi data;

/// Create a copy of VendorItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VendorItemApiCopyWith<_VendorItemApi> get copyWith => __$VendorItemApiCopyWithImpl<_VendorItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VendorItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VendorItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'VendorItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$VendorItemApiCopyWith<$Res> implements $VendorItemApiCopyWith<$Res> {
  factory _$VendorItemApiCopyWith(_VendorItemApi value, $Res Function(_VendorItemApi) _then) = __$VendorItemApiCopyWithImpl;
@override @useResult
$Res call({
 VendorApi data
});


@override $VendorApiCopyWith<$Res> get data;

}
/// @nodoc
class __$VendorItemApiCopyWithImpl<$Res>
    implements _$VendorItemApiCopyWith<$Res> {
  __$VendorItemApiCopyWithImpl(this._self, this._then);

  final _VendorItemApi _self;
  final $Res Function(_VendorItemApi) _then;

/// Create a copy of VendorItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_VendorItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as VendorApi,
  ));
}

/// Create a copy of VendorItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VendorApiCopyWith<$Res> get data {
  
  return $VendorApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
