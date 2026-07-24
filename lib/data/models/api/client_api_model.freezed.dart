// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClientApi {

 String get id; String get name;@JsonKey(name: 'display_name') String get displayName; String get number;@JsonKey(name: 'id_number') String get idNumber;@JsonKey(name: 'vat_number') String get vatNumber;// Server-assigned, read-only. Used to build the client-portal silent
// auto-login URL (`?silent=true&client_hash=…`). Always present on
// client GET/list responses.
@JsonKey(name: 'client_hash') String get clientHash; String get website;@JsonKey(name: 'phone') String get phone; String get address1; String get address2; String get city; String get state;@JsonKey(name: 'postal_code') String get postalCode;@JsonKey(name: 'country_id') String get countryId;@JsonKey(name: 'shipping_address1') String get shippingAddress1;@JsonKey(name: 'shipping_address2') String get shippingAddress2;@JsonKey(name: 'shipping_city') String get shippingCity;@JsonKey(name: 'shipping_state') String get shippingState;@JsonKey(name: 'shipping_postal_code') String get shippingPostalCode;@JsonKey(name: 'shipping_country_id') String get shippingCountryId;@JsonKey(name: 'balance') Object get balance;@JsonKey(name: 'paid_to_date') Object get paidToDate;@JsonKey(name: 'credit_balance') Object get creditBalance;@JsonKey(name: 'payment_balance') Object get paymentBalance;@JsonKey(name: 'currency_id') String get currencyId;@JsonKey(name: 'language_id') String get languageId;@JsonKey(name: 'payment_terms') String get paymentTerms;@JsonKey(name: 'private_notes') String get privateNotes;@JsonKey(name: 'public_notes') String get publicNotes;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;@JsonKey(name: 'group_settings_id') String get groupSettingsId;@JsonKey(name: 'assigned_user_id') String get assignedUserId;@JsonKey(name: 'industry_id') String get industryId;@JsonKey(name: 'size_id') String get sizeId;@JsonKey(name: 'classification') String get classification;@JsonKey(name: 'is_tax_exempt') bool get isTaxExempt;@JsonKey(name: 'has_valid_vat_number') bool get hasValidVatNumber;@JsonKey(name: 'routing_id') String get routingId;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'last_login') int get lastLogin;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted; List<ContactApi> get contacts;// Non-nullable (unlike `documents`) on purpose: the IN server embeds
// `locations` on every client GET/list response *unconditionally* —
// it is NOT `?include=`-gated the way `documents` is (probed against
// demo.invoiceninja.com, 2026-05: the `locations` key is always present,
// `[]` when empty). So the authoritative array always round-trips
// through the Drift `payload` JSON and no preserve-on-missing guard /
// dedicated column is needed. The client_repository round-trip test
// locks this contract — if the server ever makes it include-gated that
// test fails loudly instead of silently wiping locations.
 List<LocationApi> get locations;// Saved payment methods (cards / bank accounts) stored at the gateway.
// Present on client GET/list responses (probe-verified: top-level key,
// `[]` when none). Read-only — surfaced in the "Payment Methods" detail
// card and never written back as part of the client save payload.
@JsonKey(name: 'gateway_tokens') List<GatewayTokenApi> get gatewayTokens;@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags;// Nullable on purpose: the IN list endpoint omits the `documents` field
// unless `?include=documents` is requested. Distinguishing "key missing
// from JSON" (→ null) from "key present, array empty" (→ `const []`)
// lets `_apiToCompanion` preserve local docs on responses that didn't
// include them while still propagating server-side deletes on responses
// that did. See `ClientRepository._apiToCompanion` for the guard.
 List<DocumentApi>? get documents;// Sparse per-client settings overrides. Each key is a wire field name
// on the company `settings` blob (mirrors `CompanySettingsApi` shape).
// Absent keys mean "inherit from the company-level cascade." Stored
// raw as a JSON map because the wire shape is open-ended and the
// typed `CompanySettings` view is reconstructed in the VM.
@JsonKey(name: 'settings', includeIfNull: false) Map<String, dynamic>? get settings;
/// Create a copy of ClientApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClientApiCopyWith<ClientApi> get copyWith => _$ClientApiCopyWithImpl<ClientApi>(this as ClientApi, _$identity);

  /// Serializes this ClientApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClientApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.number, number) || other.number == number)&&(identical(other.idNumber, idNumber) || other.idNumber == idNumber)&&(identical(other.vatNumber, vatNumber) || other.vatNumber == vatNumber)&&(identical(other.clientHash, clientHash) || other.clientHash == clientHash)&&(identical(other.website, website) || other.website == website)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.address1, address1) || other.address1 == address1)&&(identical(other.address2, address2) || other.address2 == address2)&&(identical(other.city, city) || other.city == city)&&(identical(other.state, state) || other.state == state)&&(identical(other.postalCode, postalCode) || other.postalCode == postalCode)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.shippingAddress1, shippingAddress1) || other.shippingAddress1 == shippingAddress1)&&(identical(other.shippingAddress2, shippingAddress2) || other.shippingAddress2 == shippingAddress2)&&(identical(other.shippingCity, shippingCity) || other.shippingCity == shippingCity)&&(identical(other.shippingState, shippingState) || other.shippingState == shippingState)&&(identical(other.shippingPostalCode, shippingPostalCode) || other.shippingPostalCode == shippingPostalCode)&&(identical(other.shippingCountryId, shippingCountryId) || other.shippingCountryId == shippingCountryId)&&const DeepCollectionEquality().equals(other.balance, balance)&&const DeepCollectionEquality().equals(other.paidToDate, paidToDate)&&const DeepCollectionEquality().equals(other.creditBalance, creditBalance)&&const DeepCollectionEquality().equals(other.paymentBalance, paymentBalance)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.paymentTerms, paymentTerms) || other.paymentTerms == paymentTerms)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.groupSettingsId, groupSettingsId) || other.groupSettingsId == groupSettingsId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.industryId, industryId) || other.industryId == industryId)&&(identical(other.sizeId, sizeId) || other.sizeId == sizeId)&&(identical(other.classification, classification) || other.classification == classification)&&(identical(other.isTaxExempt, isTaxExempt) || other.isTaxExempt == isTaxExempt)&&(identical(other.hasValidVatNumber, hasValidVatNumber) || other.hasValidVatNumber == hasValidVatNumber)&&(identical(other.routingId, routingId) || other.routingId == routingId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other.contacts, contacts)&&const DeepCollectionEquality().equals(other.locations, locations)&&const DeepCollectionEquality().equals(other.gatewayTokens, gatewayTokens)&&const DeepCollectionEquality().equals(other.tags, tags)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.settings, settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,displayName,number,idNumber,vatNumber,clientHash,website,phone,address1,address2,city,state,postalCode,countryId,shippingAddress1,shippingAddress2,shippingCity,shippingState,shippingPostalCode,shippingCountryId,const DeepCollectionEquality().hash(balance),const DeepCollectionEquality().hash(paidToDate),const DeepCollectionEquality().hash(creditBalance),const DeepCollectionEquality().hash(paymentBalance),currencyId,languageId,paymentTerms,privateNotes,publicNotes,customValue1,customValue2,customValue3,customValue4,groupSettingsId,assignedUserId,industryId,sizeId,classification,isTaxExempt,hasValidVatNumber,routingId,userId,lastLogin,createdAt,updatedAt,archivedAt,isDeleted,const DeepCollectionEquality().hash(contacts),const DeepCollectionEquality().hash(locations),const DeepCollectionEquality().hash(gatewayTokens),const DeepCollectionEquality().hash(tags),const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(settings)]);

@override
String toString() {
  return 'ClientApi(id: $id, name: $name, displayName: $displayName, number: $number, idNumber: $idNumber, vatNumber: $vatNumber, clientHash: $clientHash, website: $website, phone: $phone, address1: $address1, address2: $address2, city: $city, state: $state, postalCode: $postalCode, countryId: $countryId, shippingAddress1: $shippingAddress1, shippingAddress2: $shippingAddress2, shippingCity: $shippingCity, shippingState: $shippingState, shippingPostalCode: $shippingPostalCode, shippingCountryId: $shippingCountryId, balance: $balance, paidToDate: $paidToDate, creditBalance: $creditBalance, paymentBalance: $paymentBalance, currencyId: $currencyId, languageId: $languageId, paymentTerms: $paymentTerms, privateNotes: $privateNotes, publicNotes: $publicNotes, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, groupSettingsId: $groupSettingsId, assignedUserId: $assignedUserId, industryId: $industryId, sizeId: $sizeId, classification: $classification, isTaxExempt: $isTaxExempt, hasValidVatNumber: $hasValidVatNumber, routingId: $routingId, userId: $userId, lastLogin: $lastLogin, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, contacts: $contacts, locations: $locations, gatewayTokens: $gatewayTokens, tags: $tags, documents: $documents, settings: $settings)';
}


}

/// @nodoc
abstract mixin class $ClientApiCopyWith<$Res>  {
  factory $ClientApiCopyWith(ClientApi value, $Res Function(ClientApi) _then) = _$ClientApiCopyWithImpl;
@useResult
$Res call({
 String id, String name,@JsonKey(name: 'display_name') String displayName, String number,@JsonKey(name: 'id_number') String idNumber,@JsonKey(name: 'vat_number') String vatNumber,@JsonKey(name: 'client_hash') String clientHash, String website,@JsonKey(name: 'phone') String phone, String address1, String address2, String city, String state,@JsonKey(name: 'postal_code') String postalCode,@JsonKey(name: 'country_id') String countryId,@JsonKey(name: 'shipping_address1') String shippingAddress1,@JsonKey(name: 'shipping_address2') String shippingAddress2,@JsonKey(name: 'shipping_city') String shippingCity,@JsonKey(name: 'shipping_state') String shippingState,@JsonKey(name: 'shipping_postal_code') String shippingPostalCode,@JsonKey(name: 'shipping_country_id') String shippingCountryId,@JsonKey(name: 'balance') Object balance,@JsonKey(name: 'paid_to_date') Object paidToDate,@JsonKey(name: 'credit_balance') Object creditBalance,@JsonKey(name: 'payment_balance') Object paymentBalance,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'language_id') String languageId,@JsonKey(name: 'payment_terms') String paymentTerms,@JsonKey(name: 'private_notes') String privateNotes,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'group_settings_id') String groupSettingsId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'industry_id') String industryId,@JsonKey(name: 'size_id') String sizeId,@JsonKey(name: 'classification') String classification,@JsonKey(name: 'is_tax_exempt') bool isTaxExempt,@JsonKey(name: 'has_valid_vat_number') bool hasValidVatNumber,@JsonKey(name: 'routing_id') String routingId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'last_login') int lastLogin,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted, List<ContactApi> contacts, List<LocationApi> locations,@JsonKey(name: 'gateway_tokens') List<GatewayTokenApi> gatewayTokens,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags, List<DocumentApi>? documents,@JsonKey(name: 'settings', includeIfNull: false) Map<String, dynamic>? settings
});




}
/// @nodoc
class _$ClientApiCopyWithImpl<$Res>
    implements $ClientApiCopyWith<$Res> {
  _$ClientApiCopyWithImpl(this._self, this._then);

  final ClientApi _self;
  final $Res Function(ClientApi) _then;

/// Create a copy of ClientApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? displayName = null,Object? number = null,Object? idNumber = null,Object? vatNumber = null,Object? clientHash = null,Object? website = null,Object? phone = null,Object? address1 = null,Object? address2 = null,Object? city = null,Object? state = null,Object? postalCode = null,Object? countryId = null,Object? shippingAddress1 = null,Object? shippingAddress2 = null,Object? shippingCity = null,Object? shippingState = null,Object? shippingPostalCode = null,Object? shippingCountryId = null,Object? balance = null,Object? paidToDate = null,Object? creditBalance = null,Object? paymentBalance = null,Object? currencyId = null,Object? languageId = null,Object? paymentTerms = null,Object? privateNotes = null,Object? publicNotes = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? groupSettingsId = null,Object? assignedUserId = null,Object? industryId = null,Object? sizeId = null,Object? classification = null,Object? isTaxExempt = null,Object? hasValidVatNumber = null,Object? routingId = null,Object? userId = null,Object? lastLogin = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? contacts = null,Object? locations = null,Object? gatewayTokens = null,Object? tags = null,Object? documents = freezed,Object? settings = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,idNumber: null == idNumber ? _self.idNumber : idNumber // ignore: cast_nullable_to_non_nullable
as String,vatNumber: null == vatNumber ? _self.vatNumber : vatNumber // ignore: cast_nullable_to_non_nullable
as String,clientHash: null == clientHash ? _self.clientHash : clientHash // ignore: cast_nullable_to_non_nullable
as String,website: null == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,address1: null == address1 ? _self.address1 : address1 // ignore: cast_nullable_to_non_nullable
as String,address2: null == address2 ? _self.address2 : address2 // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,postalCode: null == postalCode ? _self.postalCode : postalCode // ignore: cast_nullable_to_non_nullable
as String,countryId: null == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as String,shippingAddress1: null == shippingAddress1 ? _self.shippingAddress1 : shippingAddress1 // ignore: cast_nullable_to_non_nullable
as String,shippingAddress2: null == shippingAddress2 ? _self.shippingAddress2 : shippingAddress2 // ignore: cast_nullable_to_non_nullable
as String,shippingCity: null == shippingCity ? _self.shippingCity : shippingCity // ignore: cast_nullable_to_non_nullable
as String,shippingState: null == shippingState ? _self.shippingState : shippingState // ignore: cast_nullable_to_non_nullable
as String,shippingPostalCode: null == shippingPostalCode ? _self.shippingPostalCode : shippingPostalCode // ignore: cast_nullable_to_non_nullable
as String,shippingCountryId: null == shippingCountryId ? _self.shippingCountryId : shippingCountryId // ignore: cast_nullable_to_non_nullable
as String,balance: null == balance ? _self.balance : balance ,paidToDate: null == paidToDate ? _self.paidToDate : paidToDate ,creditBalance: null == creditBalance ? _self.creditBalance : creditBalance ,paymentBalance: null == paymentBalance ? _self.paymentBalance : paymentBalance ,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,languageId: null == languageId ? _self.languageId : languageId // ignore: cast_nullable_to_non_nullable
as String,paymentTerms: null == paymentTerms ? _self.paymentTerms : paymentTerms // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,groupSettingsId: null == groupSettingsId ? _self.groupSettingsId : groupSettingsId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,industryId: null == industryId ? _self.industryId : industryId // ignore: cast_nullable_to_non_nullable
as String,sizeId: null == sizeId ? _self.sizeId : sizeId // ignore: cast_nullable_to_non_nullable
as String,classification: null == classification ? _self.classification : classification // ignore: cast_nullable_to_non_nullable
as String,isTaxExempt: null == isTaxExempt ? _self.isTaxExempt : isTaxExempt // ignore: cast_nullable_to_non_nullable
as bool,hasValidVatNumber: null == hasValidVatNumber ? _self.hasValidVatNumber : hasValidVatNumber // ignore: cast_nullable_to_non_nullable
as bool,routingId: null == routingId ? _self.routingId : routingId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,lastLogin: null == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,contacts: null == contacts ? _self.contacts : contacts // ignore: cast_nullable_to_non_nullable
as List<ContactApi>,locations: null == locations ? _self.locations : locations // ignore: cast_nullable_to_non_nullable
as List<LocationApi>,gatewayTokens: null == gatewayTokens ? _self.gatewayTokens : gatewayTokens // ignore: cast_nullable_to_non_nullable
as List<GatewayTokenApi>,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,documents: freezed == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,settings: freezed == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [ClientApi].
extension ClientApiPatterns on ClientApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClientApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClientApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClientApi value)  $default,){
final _that = this;
switch (_that) {
case _ClientApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClientApi value)?  $default,){
final _that = this;
switch (_that) {
case _ClientApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'display_name')  String displayName,  String number, @JsonKey(name: 'id_number')  String idNumber, @JsonKey(name: 'vat_number')  String vatNumber, @JsonKey(name: 'client_hash')  String clientHash,  String website, @JsonKey(name: 'phone')  String phone,  String address1,  String address2,  String city,  String state, @JsonKey(name: 'postal_code')  String postalCode, @JsonKey(name: 'country_id')  String countryId, @JsonKey(name: 'shipping_address1')  String shippingAddress1, @JsonKey(name: 'shipping_address2')  String shippingAddress2, @JsonKey(name: 'shipping_city')  String shippingCity, @JsonKey(name: 'shipping_state')  String shippingState, @JsonKey(name: 'shipping_postal_code')  String shippingPostalCode, @JsonKey(name: 'shipping_country_id')  String shippingCountryId, @JsonKey(name: 'balance')  Object balance, @JsonKey(name: 'paid_to_date')  Object paidToDate, @JsonKey(name: 'credit_balance')  Object creditBalance, @JsonKey(name: 'payment_balance')  Object paymentBalance, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'language_id')  String languageId, @JsonKey(name: 'payment_terms')  String paymentTerms, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'group_settings_id')  String groupSettingsId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'industry_id')  String industryId, @JsonKey(name: 'size_id')  String sizeId, @JsonKey(name: 'classification')  String classification, @JsonKey(name: 'is_tax_exempt')  bool isTaxExempt, @JsonKey(name: 'has_valid_vat_number')  bool hasValidVatNumber, @JsonKey(name: 'routing_id')  String routingId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted,  List<ContactApi> contacts,  List<LocationApi> locations, @JsonKey(name: 'gateway_tokens')  List<GatewayTokenApi> gatewayTokens, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags,  List<DocumentApi>? documents, @JsonKey(name: 'settings', includeIfNull: false)  Map<String, dynamic>? settings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClientApi() when $default != null:
return $default(_that.id,_that.name,_that.displayName,_that.number,_that.idNumber,_that.vatNumber,_that.clientHash,_that.website,_that.phone,_that.address1,_that.address2,_that.city,_that.state,_that.postalCode,_that.countryId,_that.shippingAddress1,_that.shippingAddress2,_that.shippingCity,_that.shippingState,_that.shippingPostalCode,_that.shippingCountryId,_that.balance,_that.paidToDate,_that.creditBalance,_that.paymentBalance,_that.currencyId,_that.languageId,_that.paymentTerms,_that.privateNotes,_that.publicNotes,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.groupSettingsId,_that.assignedUserId,_that.industryId,_that.sizeId,_that.classification,_that.isTaxExempt,_that.hasValidVatNumber,_that.routingId,_that.userId,_that.lastLogin,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.contacts,_that.locations,_that.gatewayTokens,_that.tags,_that.documents,_that.settings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'display_name')  String displayName,  String number, @JsonKey(name: 'id_number')  String idNumber, @JsonKey(name: 'vat_number')  String vatNumber, @JsonKey(name: 'client_hash')  String clientHash,  String website, @JsonKey(name: 'phone')  String phone,  String address1,  String address2,  String city,  String state, @JsonKey(name: 'postal_code')  String postalCode, @JsonKey(name: 'country_id')  String countryId, @JsonKey(name: 'shipping_address1')  String shippingAddress1, @JsonKey(name: 'shipping_address2')  String shippingAddress2, @JsonKey(name: 'shipping_city')  String shippingCity, @JsonKey(name: 'shipping_state')  String shippingState, @JsonKey(name: 'shipping_postal_code')  String shippingPostalCode, @JsonKey(name: 'shipping_country_id')  String shippingCountryId, @JsonKey(name: 'balance')  Object balance, @JsonKey(name: 'paid_to_date')  Object paidToDate, @JsonKey(name: 'credit_balance')  Object creditBalance, @JsonKey(name: 'payment_balance')  Object paymentBalance, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'language_id')  String languageId, @JsonKey(name: 'payment_terms')  String paymentTerms, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'group_settings_id')  String groupSettingsId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'industry_id')  String industryId, @JsonKey(name: 'size_id')  String sizeId, @JsonKey(name: 'classification')  String classification, @JsonKey(name: 'is_tax_exempt')  bool isTaxExempt, @JsonKey(name: 'has_valid_vat_number')  bool hasValidVatNumber, @JsonKey(name: 'routing_id')  String routingId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted,  List<ContactApi> contacts,  List<LocationApi> locations, @JsonKey(name: 'gateway_tokens')  List<GatewayTokenApi> gatewayTokens, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags,  List<DocumentApi>? documents, @JsonKey(name: 'settings', includeIfNull: false)  Map<String, dynamic>? settings)  $default,) {final _that = this;
switch (_that) {
case _ClientApi():
return $default(_that.id,_that.name,_that.displayName,_that.number,_that.idNumber,_that.vatNumber,_that.clientHash,_that.website,_that.phone,_that.address1,_that.address2,_that.city,_that.state,_that.postalCode,_that.countryId,_that.shippingAddress1,_that.shippingAddress2,_that.shippingCity,_that.shippingState,_that.shippingPostalCode,_that.shippingCountryId,_that.balance,_that.paidToDate,_that.creditBalance,_that.paymentBalance,_that.currencyId,_that.languageId,_that.paymentTerms,_that.privateNotes,_that.publicNotes,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.groupSettingsId,_that.assignedUserId,_that.industryId,_that.sizeId,_that.classification,_that.isTaxExempt,_that.hasValidVatNumber,_that.routingId,_that.userId,_that.lastLogin,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.contacts,_that.locations,_that.gatewayTokens,_that.tags,_that.documents,_that.settings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name, @JsonKey(name: 'display_name')  String displayName,  String number, @JsonKey(name: 'id_number')  String idNumber, @JsonKey(name: 'vat_number')  String vatNumber, @JsonKey(name: 'client_hash')  String clientHash,  String website, @JsonKey(name: 'phone')  String phone,  String address1,  String address2,  String city,  String state, @JsonKey(name: 'postal_code')  String postalCode, @JsonKey(name: 'country_id')  String countryId, @JsonKey(name: 'shipping_address1')  String shippingAddress1, @JsonKey(name: 'shipping_address2')  String shippingAddress2, @JsonKey(name: 'shipping_city')  String shippingCity, @JsonKey(name: 'shipping_state')  String shippingState, @JsonKey(name: 'shipping_postal_code')  String shippingPostalCode, @JsonKey(name: 'shipping_country_id')  String shippingCountryId, @JsonKey(name: 'balance')  Object balance, @JsonKey(name: 'paid_to_date')  Object paidToDate, @JsonKey(name: 'credit_balance')  Object creditBalance, @JsonKey(name: 'payment_balance')  Object paymentBalance, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'language_id')  String languageId, @JsonKey(name: 'payment_terms')  String paymentTerms, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'group_settings_id')  String groupSettingsId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'industry_id')  String industryId, @JsonKey(name: 'size_id')  String sizeId, @JsonKey(name: 'classification')  String classification, @JsonKey(name: 'is_tax_exempt')  bool isTaxExempt, @JsonKey(name: 'has_valid_vat_number')  bool hasValidVatNumber, @JsonKey(name: 'routing_id')  String routingId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'last_login')  int lastLogin, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted,  List<ContactApi> contacts,  List<LocationApi> locations, @JsonKey(name: 'gateway_tokens')  List<GatewayTokenApi> gatewayTokens, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags,  List<DocumentApi>? documents, @JsonKey(name: 'settings', includeIfNull: false)  Map<String, dynamic>? settings)?  $default,) {final _that = this;
switch (_that) {
case _ClientApi() when $default != null:
return $default(_that.id,_that.name,_that.displayName,_that.number,_that.idNumber,_that.vatNumber,_that.clientHash,_that.website,_that.phone,_that.address1,_that.address2,_that.city,_that.state,_that.postalCode,_that.countryId,_that.shippingAddress1,_that.shippingAddress2,_that.shippingCity,_that.shippingState,_that.shippingPostalCode,_that.shippingCountryId,_that.balance,_that.paidToDate,_that.creditBalance,_that.paymentBalance,_that.currencyId,_that.languageId,_that.paymentTerms,_that.privateNotes,_that.publicNotes,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.groupSettingsId,_that.assignedUserId,_that.industryId,_that.sizeId,_that.classification,_that.isTaxExempt,_that.hasValidVatNumber,_that.routingId,_that.userId,_that.lastLogin,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.contacts,_that.locations,_that.gatewayTokens,_that.tags,_that.documents,_that.settings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClientApi implements ClientApi {
  const _ClientApi({this.id = '', this.name = '', @JsonKey(name: 'display_name') this.displayName = '', this.number = '', @JsonKey(name: 'id_number') this.idNumber = '', @JsonKey(name: 'vat_number') this.vatNumber = '', @JsonKey(name: 'client_hash') this.clientHash = '', this.website = '', @JsonKey(name: 'phone') this.phone = '', this.address1 = '', this.address2 = '', this.city = '', this.state = '', @JsonKey(name: 'postal_code') this.postalCode = '', @JsonKey(name: 'country_id') this.countryId = '', @JsonKey(name: 'shipping_address1') this.shippingAddress1 = '', @JsonKey(name: 'shipping_address2') this.shippingAddress2 = '', @JsonKey(name: 'shipping_city') this.shippingCity = '', @JsonKey(name: 'shipping_state') this.shippingState = '', @JsonKey(name: 'shipping_postal_code') this.shippingPostalCode = '', @JsonKey(name: 'shipping_country_id') this.shippingCountryId = '', @JsonKey(name: 'balance') this.balance = '0', @JsonKey(name: 'paid_to_date') this.paidToDate = '0', @JsonKey(name: 'credit_balance') this.creditBalance = '0', @JsonKey(name: 'payment_balance') this.paymentBalance = '0', @JsonKey(name: 'currency_id') this.currencyId = '', @JsonKey(name: 'language_id') this.languageId = '', @JsonKey(name: 'payment_terms') this.paymentTerms = '', @JsonKey(name: 'private_notes') this.privateNotes = '', @JsonKey(name: 'public_notes') this.publicNotes = '', @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'group_settings_id') this.groupSettingsId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', @JsonKey(name: 'industry_id') this.industryId = '', @JsonKey(name: 'size_id') this.sizeId = '', @JsonKey(name: 'classification') this.classification = '', @JsonKey(name: 'is_tax_exempt') this.isTaxExempt = false, @JsonKey(name: 'has_valid_vat_number') this.hasValidVatNumber = false, @JsonKey(name: 'routing_id') this.routingId = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'last_login') this.lastLogin = 0, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false, final  List<ContactApi> contacts = const <ContactApi>[], final  List<LocationApi> locations = const <LocationApi>[], @JsonKey(name: 'gateway_tokens') final  List<GatewayTokenApi> gatewayTokens = const <GatewayTokenApi>[], @JsonKey(name: 'tags')@EmbeddedTagsConverter() final  List<TagRefApi> tags = const <TagRefApi>[], final  List<DocumentApi>? documents, @JsonKey(name: 'settings', includeIfNull: false) final  Map<String, dynamic>? settings}): _contacts = contacts,_locations = locations,_gatewayTokens = gatewayTokens,_tags = tags,_documents = documents,_settings = settings;
  factory _ClientApi.fromJson(Map<String, dynamic> json) => _$ClientApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String name;
@override@JsonKey(name: 'display_name') final  String displayName;
@override@JsonKey() final  String number;
@override@JsonKey(name: 'id_number') final  String idNumber;
@override@JsonKey(name: 'vat_number') final  String vatNumber;
// Server-assigned, read-only. Used to build the client-portal silent
// auto-login URL (`?silent=true&client_hash=…`). Always present on
// client GET/list responses.
@override@JsonKey(name: 'client_hash') final  String clientHash;
@override@JsonKey() final  String website;
@override@JsonKey(name: 'phone') final  String phone;
@override@JsonKey() final  String address1;
@override@JsonKey() final  String address2;
@override@JsonKey() final  String city;
@override@JsonKey() final  String state;
@override@JsonKey(name: 'postal_code') final  String postalCode;
@override@JsonKey(name: 'country_id') final  String countryId;
@override@JsonKey(name: 'shipping_address1') final  String shippingAddress1;
@override@JsonKey(name: 'shipping_address2') final  String shippingAddress2;
@override@JsonKey(name: 'shipping_city') final  String shippingCity;
@override@JsonKey(name: 'shipping_state') final  String shippingState;
@override@JsonKey(name: 'shipping_postal_code') final  String shippingPostalCode;
@override@JsonKey(name: 'shipping_country_id') final  String shippingCountryId;
@override@JsonKey(name: 'balance') final  Object balance;
@override@JsonKey(name: 'paid_to_date') final  Object paidToDate;
@override@JsonKey(name: 'credit_balance') final  Object creditBalance;
@override@JsonKey(name: 'payment_balance') final  Object paymentBalance;
@override@JsonKey(name: 'currency_id') final  String currencyId;
@override@JsonKey(name: 'language_id') final  String languageId;
@override@JsonKey(name: 'payment_terms') final  String paymentTerms;
@override@JsonKey(name: 'private_notes') final  String privateNotes;
@override@JsonKey(name: 'public_notes') final  String publicNotes;
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
@override@JsonKey(name: 'group_settings_id') final  String groupSettingsId;
@override@JsonKey(name: 'assigned_user_id') final  String assignedUserId;
@override@JsonKey(name: 'industry_id') final  String industryId;
@override@JsonKey(name: 'size_id') final  String sizeId;
@override@JsonKey(name: 'classification') final  String classification;
@override@JsonKey(name: 'is_tax_exempt') final  bool isTaxExempt;
@override@JsonKey(name: 'has_valid_vat_number') final  bool hasValidVatNumber;
@override@JsonKey(name: 'routing_id') final  String routingId;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'last_login') final  int lastLogin;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
 final  List<ContactApi> _contacts;
@override@JsonKey() List<ContactApi> get contacts {
  if (_contacts is EqualUnmodifiableListView) return _contacts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_contacts);
}

// Non-nullable (unlike `documents`) on purpose: the IN server embeds
// `locations` on every client GET/list response *unconditionally* —
// it is NOT `?include=`-gated the way `documents` is (probed against
// demo.invoiceninja.com, 2026-05: the `locations` key is always present,
// `[]` when empty). So the authoritative array always round-trips
// through the Drift `payload` JSON and no preserve-on-missing guard /
// dedicated column is needed. The client_repository round-trip test
// locks this contract — if the server ever makes it include-gated that
// test fails loudly instead of silently wiping locations.
 final  List<LocationApi> _locations;
// Non-nullable (unlike `documents`) on purpose: the IN server embeds
// `locations` on every client GET/list response *unconditionally* —
// it is NOT `?include=`-gated the way `documents` is (probed against
// demo.invoiceninja.com, 2026-05: the `locations` key is always present,
// `[]` when empty). So the authoritative array always round-trips
// through the Drift `payload` JSON and no preserve-on-missing guard /
// dedicated column is needed. The client_repository round-trip test
// locks this contract — if the server ever makes it include-gated that
// test fails loudly instead of silently wiping locations.
@override@JsonKey() List<LocationApi> get locations {
  if (_locations is EqualUnmodifiableListView) return _locations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_locations);
}

// Saved payment methods (cards / bank accounts) stored at the gateway.
// Present on client GET/list responses (probe-verified: top-level key,
// `[]` when none). Read-only — surfaced in the "Payment Methods" detail
// card and never written back as part of the client save payload.
 final  List<GatewayTokenApi> _gatewayTokens;
// Saved payment methods (cards / bank accounts) stored at the gateway.
// Present on client GET/list responses (probe-verified: top-level key,
// `[]` when none). Read-only — surfaced in the "Payment Methods" detail
// card and never written back as part of the client save payload.
@override@JsonKey(name: 'gateway_tokens') List<GatewayTokenApi> get gatewayTokens {
  if (_gatewayTokens is EqualUnmodifiableListView) return _gatewayTokens;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_gatewayTokens);
}

 final  List<TagRefApi> _tags;
@override@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

// Nullable on purpose: the IN list endpoint omits the `documents` field
// unless `?include=documents` is requested. Distinguishing "key missing
// from JSON" (→ null) from "key present, array empty" (→ `const []`)
// lets `_apiToCompanion` preserve local docs on responses that didn't
// include them while still propagating server-side deletes on responses
// that did. See `ClientRepository._apiToCompanion` for the guard.
 final  List<DocumentApi>? _documents;
// Nullable on purpose: the IN list endpoint omits the `documents` field
// unless `?include=documents` is requested. Distinguishing "key missing
// from JSON" (→ null) from "key present, array empty" (→ `const []`)
// lets `_apiToCompanion` preserve local docs on responses that didn't
// include them while still propagating server-side deletes on responses
// that did. See `ClientRepository._apiToCompanion` for the guard.
@override List<DocumentApi>? get documents {
  final value = _documents;
  if (value == null) return null;
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Sparse per-client settings overrides. Each key is a wire field name
// on the company `settings` blob (mirrors `CompanySettingsApi` shape).
// Absent keys mean "inherit from the company-level cascade." Stored
// raw as a JSON map because the wire shape is open-ended and the
// typed `CompanySettings` view is reconstructed in the VM.
 final  Map<String, dynamic>? _settings;
// Sparse per-client settings overrides. Each key is a wire field name
// on the company `settings` blob (mirrors `CompanySettingsApi` shape).
// Absent keys mean "inherit from the company-level cascade." Stored
// raw as a JSON map because the wire shape is open-ended and the
// typed `CompanySettings` view is reconstructed in the VM.
@override@JsonKey(name: 'settings', includeIfNull: false) Map<String, dynamic>? get settings {
  final value = _settings;
  if (value == null) return null;
  if (_settings is EqualUnmodifiableMapView) return _settings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of ClientApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClientApiCopyWith<_ClientApi> get copyWith => __$ClientApiCopyWithImpl<_ClientApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClientApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClientApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.number, number) || other.number == number)&&(identical(other.idNumber, idNumber) || other.idNumber == idNumber)&&(identical(other.vatNumber, vatNumber) || other.vatNumber == vatNumber)&&(identical(other.clientHash, clientHash) || other.clientHash == clientHash)&&(identical(other.website, website) || other.website == website)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.address1, address1) || other.address1 == address1)&&(identical(other.address2, address2) || other.address2 == address2)&&(identical(other.city, city) || other.city == city)&&(identical(other.state, state) || other.state == state)&&(identical(other.postalCode, postalCode) || other.postalCode == postalCode)&&(identical(other.countryId, countryId) || other.countryId == countryId)&&(identical(other.shippingAddress1, shippingAddress1) || other.shippingAddress1 == shippingAddress1)&&(identical(other.shippingAddress2, shippingAddress2) || other.shippingAddress2 == shippingAddress2)&&(identical(other.shippingCity, shippingCity) || other.shippingCity == shippingCity)&&(identical(other.shippingState, shippingState) || other.shippingState == shippingState)&&(identical(other.shippingPostalCode, shippingPostalCode) || other.shippingPostalCode == shippingPostalCode)&&(identical(other.shippingCountryId, shippingCountryId) || other.shippingCountryId == shippingCountryId)&&const DeepCollectionEquality().equals(other.balance, balance)&&const DeepCollectionEquality().equals(other.paidToDate, paidToDate)&&const DeepCollectionEquality().equals(other.creditBalance, creditBalance)&&const DeepCollectionEquality().equals(other.paymentBalance, paymentBalance)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.languageId, languageId) || other.languageId == languageId)&&(identical(other.paymentTerms, paymentTerms) || other.paymentTerms == paymentTerms)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.groupSettingsId, groupSettingsId) || other.groupSettingsId == groupSettingsId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.industryId, industryId) || other.industryId == industryId)&&(identical(other.sizeId, sizeId) || other.sizeId == sizeId)&&(identical(other.classification, classification) || other.classification == classification)&&(identical(other.isTaxExempt, isTaxExempt) || other.isTaxExempt == isTaxExempt)&&(identical(other.hasValidVatNumber, hasValidVatNumber) || other.hasValidVatNumber == hasValidVatNumber)&&(identical(other.routingId, routingId) || other.routingId == routingId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.lastLogin, lastLogin) || other.lastLogin == lastLogin)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other._contacts, _contacts)&&const DeepCollectionEquality().equals(other._locations, _locations)&&const DeepCollectionEquality().equals(other._gatewayTokens, _gatewayTokens)&&const DeepCollectionEquality().equals(other._tags, _tags)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._settings, _settings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,displayName,number,idNumber,vatNumber,clientHash,website,phone,address1,address2,city,state,postalCode,countryId,shippingAddress1,shippingAddress2,shippingCity,shippingState,shippingPostalCode,shippingCountryId,const DeepCollectionEquality().hash(balance),const DeepCollectionEquality().hash(paidToDate),const DeepCollectionEquality().hash(creditBalance),const DeepCollectionEquality().hash(paymentBalance),currencyId,languageId,paymentTerms,privateNotes,publicNotes,customValue1,customValue2,customValue3,customValue4,groupSettingsId,assignedUserId,industryId,sizeId,classification,isTaxExempt,hasValidVatNumber,routingId,userId,lastLogin,createdAt,updatedAt,archivedAt,isDeleted,const DeepCollectionEquality().hash(_contacts),const DeepCollectionEquality().hash(_locations),const DeepCollectionEquality().hash(_gatewayTokens),const DeepCollectionEquality().hash(_tags),const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_settings)]);

@override
String toString() {
  return 'ClientApi(id: $id, name: $name, displayName: $displayName, number: $number, idNumber: $idNumber, vatNumber: $vatNumber, clientHash: $clientHash, website: $website, phone: $phone, address1: $address1, address2: $address2, city: $city, state: $state, postalCode: $postalCode, countryId: $countryId, shippingAddress1: $shippingAddress1, shippingAddress2: $shippingAddress2, shippingCity: $shippingCity, shippingState: $shippingState, shippingPostalCode: $shippingPostalCode, shippingCountryId: $shippingCountryId, balance: $balance, paidToDate: $paidToDate, creditBalance: $creditBalance, paymentBalance: $paymentBalance, currencyId: $currencyId, languageId: $languageId, paymentTerms: $paymentTerms, privateNotes: $privateNotes, publicNotes: $publicNotes, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, groupSettingsId: $groupSettingsId, assignedUserId: $assignedUserId, industryId: $industryId, sizeId: $sizeId, classification: $classification, isTaxExempt: $isTaxExempt, hasValidVatNumber: $hasValidVatNumber, routingId: $routingId, userId: $userId, lastLogin: $lastLogin, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, contacts: $contacts, locations: $locations, gatewayTokens: $gatewayTokens, tags: $tags, documents: $documents, settings: $settings)';
}


}

/// @nodoc
abstract mixin class _$ClientApiCopyWith<$Res> implements $ClientApiCopyWith<$Res> {
  factory _$ClientApiCopyWith(_ClientApi value, $Res Function(_ClientApi) _then) = __$ClientApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String name,@JsonKey(name: 'display_name') String displayName, String number,@JsonKey(name: 'id_number') String idNumber,@JsonKey(name: 'vat_number') String vatNumber,@JsonKey(name: 'client_hash') String clientHash, String website,@JsonKey(name: 'phone') String phone, String address1, String address2, String city, String state,@JsonKey(name: 'postal_code') String postalCode,@JsonKey(name: 'country_id') String countryId,@JsonKey(name: 'shipping_address1') String shippingAddress1,@JsonKey(name: 'shipping_address2') String shippingAddress2,@JsonKey(name: 'shipping_city') String shippingCity,@JsonKey(name: 'shipping_state') String shippingState,@JsonKey(name: 'shipping_postal_code') String shippingPostalCode,@JsonKey(name: 'shipping_country_id') String shippingCountryId,@JsonKey(name: 'balance') Object balance,@JsonKey(name: 'paid_to_date') Object paidToDate,@JsonKey(name: 'credit_balance') Object creditBalance,@JsonKey(name: 'payment_balance') Object paymentBalance,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'language_id') String languageId,@JsonKey(name: 'payment_terms') String paymentTerms,@JsonKey(name: 'private_notes') String privateNotes,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'group_settings_id') String groupSettingsId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'industry_id') String industryId,@JsonKey(name: 'size_id') String sizeId,@JsonKey(name: 'classification') String classification,@JsonKey(name: 'is_tax_exempt') bool isTaxExempt,@JsonKey(name: 'has_valid_vat_number') bool hasValidVatNumber,@JsonKey(name: 'routing_id') String routingId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'last_login') int lastLogin,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted, List<ContactApi> contacts, List<LocationApi> locations,@JsonKey(name: 'gateway_tokens') List<GatewayTokenApi> gatewayTokens,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags, List<DocumentApi>? documents,@JsonKey(name: 'settings', includeIfNull: false) Map<String, dynamic>? settings
});




}
/// @nodoc
class __$ClientApiCopyWithImpl<$Res>
    implements _$ClientApiCopyWith<$Res> {
  __$ClientApiCopyWithImpl(this._self, this._then);

  final _ClientApi _self;
  final $Res Function(_ClientApi) _then;

/// Create a copy of ClientApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? displayName = null,Object? number = null,Object? idNumber = null,Object? vatNumber = null,Object? clientHash = null,Object? website = null,Object? phone = null,Object? address1 = null,Object? address2 = null,Object? city = null,Object? state = null,Object? postalCode = null,Object? countryId = null,Object? shippingAddress1 = null,Object? shippingAddress2 = null,Object? shippingCity = null,Object? shippingState = null,Object? shippingPostalCode = null,Object? shippingCountryId = null,Object? balance = null,Object? paidToDate = null,Object? creditBalance = null,Object? paymentBalance = null,Object? currencyId = null,Object? languageId = null,Object? paymentTerms = null,Object? privateNotes = null,Object? publicNotes = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? groupSettingsId = null,Object? assignedUserId = null,Object? industryId = null,Object? sizeId = null,Object? classification = null,Object? isTaxExempt = null,Object? hasValidVatNumber = null,Object? routingId = null,Object? userId = null,Object? lastLogin = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? contacts = null,Object? locations = null,Object? gatewayTokens = null,Object? tags = null,Object? documents = freezed,Object? settings = freezed,}) {
  return _then(_ClientApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,idNumber: null == idNumber ? _self.idNumber : idNumber // ignore: cast_nullable_to_non_nullable
as String,vatNumber: null == vatNumber ? _self.vatNumber : vatNumber // ignore: cast_nullable_to_non_nullable
as String,clientHash: null == clientHash ? _self.clientHash : clientHash // ignore: cast_nullable_to_non_nullable
as String,website: null == website ? _self.website : website // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,address1: null == address1 ? _self.address1 : address1 // ignore: cast_nullable_to_non_nullable
as String,address2: null == address2 ? _self.address2 : address2 // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,postalCode: null == postalCode ? _self.postalCode : postalCode // ignore: cast_nullable_to_non_nullable
as String,countryId: null == countryId ? _self.countryId : countryId // ignore: cast_nullable_to_non_nullable
as String,shippingAddress1: null == shippingAddress1 ? _self.shippingAddress1 : shippingAddress1 // ignore: cast_nullable_to_non_nullable
as String,shippingAddress2: null == shippingAddress2 ? _self.shippingAddress2 : shippingAddress2 // ignore: cast_nullable_to_non_nullable
as String,shippingCity: null == shippingCity ? _self.shippingCity : shippingCity // ignore: cast_nullable_to_non_nullable
as String,shippingState: null == shippingState ? _self.shippingState : shippingState // ignore: cast_nullable_to_non_nullable
as String,shippingPostalCode: null == shippingPostalCode ? _self.shippingPostalCode : shippingPostalCode // ignore: cast_nullable_to_non_nullable
as String,shippingCountryId: null == shippingCountryId ? _self.shippingCountryId : shippingCountryId // ignore: cast_nullable_to_non_nullable
as String,balance: null == balance ? _self.balance : balance ,paidToDate: null == paidToDate ? _self.paidToDate : paidToDate ,creditBalance: null == creditBalance ? _self.creditBalance : creditBalance ,paymentBalance: null == paymentBalance ? _self.paymentBalance : paymentBalance ,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,languageId: null == languageId ? _self.languageId : languageId // ignore: cast_nullable_to_non_nullable
as String,paymentTerms: null == paymentTerms ? _self.paymentTerms : paymentTerms // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,groupSettingsId: null == groupSettingsId ? _self.groupSettingsId : groupSettingsId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,industryId: null == industryId ? _self.industryId : industryId // ignore: cast_nullable_to_non_nullable
as String,sizeId: null == sizeId ? _self.sizeId : sizeId // ignore: cast_nullable_to_non_nullable
as String,classification: null == classification ? _self.classification : classification // ignore: cast_nullable_to_non_nullable
as String,isTaxExempt: null == isTaxExempt ? _self.isTaxExempt : isTaxExempt // ignore: cast_nullable_to_non_nullable
as bool,hasValidVatNumber: null == hasValidVatNumber ? _self.hasValidVatNumber : hasValidVatNumber // ignore: cast_nullable_to_non_nullable
as bool,routingId: null == routingId ? _self.routingId : routingId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,lastLogin: null == lastLogin ? _self.lastLogin : lastLogin // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,contacts: null == contacts ? _self._contacts : contacts // ignore: cast_nullable_to_non_nullable
as List<ContactApi>,locations: null == locations ? _self._locations : locations // ignore: cast_nullable_to_non_nullable
as List<LocationApi>,gatewayTokens: null == gatewayTokens ? _self._gatewayTokens : gatewayTokens // ignore: cast_nullable_to_non_nullable
as List<GatewayTokenApi>,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,documents: freezed == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,settings: freezed == settings ? _self._settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}


/// @nodoc
mixin _$ClientListApi {

@JsonKey(fromJson: _clientListData) List<ClientApi> get data;
/// Create a copy of ClientListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClientListApiCopyWith<ClientListApi> get copyWith => _$ClientListApiCopyWithImpl<ClientListApi>(this as ClientListApi, _$identity);

  /// Serializes this ClientListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClientListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'ClientListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $ClientListApiCopyWith<$Res>  {
  factory $ClientListApiCopyWith(ClientListApi value, $Res Function(ClientListApi) _then) = _$ClientListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _clientListData) List<ClientApi> data
});




}
/// @nodoc
class _$ClientListApiCopyWithImpl<$Res>
    implements $ClientListApiCopyWith<$Res> {
  _$ClientListApiCopyWithImpl(this._self, this._then);

  final ClientListApi _self;
  final $Res Function(ClientListApi) _then;

/// Create a copy of ClientListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<ClientApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [ClientListApi].
extension ClientListApiPatterns on ClientListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClientListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClientListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClientListApi value)  $default,){
final _that = this;
switch (_that) {
case _ClientListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClientListApi value)?  $default,){
final _that = this;
switch (_that) {
case _ClientListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _clientListData)  List<ClientApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClientListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _clientListData)  List<ClientApi> data)  $default,) {final _that = this;
switch (_that) {
case _ClientListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _clientListData)  List<ClientApi> data)?  $default,) {final _that = this;
switch (_that) {
case _ClientListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClientListApi implements ClientListApi {
  const _ClientListApi({@JsonKey(fromJson: _clientListData) final  List<ClientApi> data = const <ClientApi>[]}): _data = data;
  factory _ClientListApi.fromJson(Map<String, dynamic> json) => _$ClientListApiFromJson(json);

 final  List<ClientApi> _data;
@override@JsonKey(fromJson: _clientListData) List<ClientApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of ClientListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClientListApiCopyWith<_ClientListApi> get copyWith => __$ClientListApiCopyWithImpl<_ClientListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClientListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClientListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'ClientListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ClientListApiCopyWith<$Res> implements $ClientListApiCopyWith<$Res> {
  factory _$ClientListApiCopyWith(_ClientListApi value, $Res Function(_ClientListApi) _then) = __$ClientListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _clientListData) List<ClientApi> data
});




}
/// @nodoc
class __$ClientListApiCopyWithImpl<$Res>
    implements _$ClientListApiCopyWith<$Res> {
  __$ClientListApiCopyWithImpl(this._self, this._then);

  final _ClientListApi _self;
  final $Res Function(_ClientListApi) _then;

/// Create a copy of ClientListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_ClientListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<ClientApi>,
  ));
}


}


/// @nodoc
mixin _$ClientItemApi {

 ClientApi get data;
/// Create a copy of ClientItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClientItemApiCopyWith<ClientItemApi> get copyWith => _$ClientItemApiCopyWithImpl<ClientItemApi>(this as ClientItemApi, _$identity);

  /// Serializes this ClientItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClientItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'ClientItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $ClientItemApiCopyWith<$Res>  {
  factory $ClientItemApiCopyWith(ClientItemApi value, $Res Function(ClientItemApi) _then) = _$ClientItemApiCopyWithImpl;
@useResult
$Res call({
 ClientApi data
});


$ClientApiCopyWith<$Res> get data;

}
/// @nodoc
class _$ClientItemApiCopyWithImpl<$Res>
    implements $ClientItemApiCopyWith<$Res> {
  _$ClientItemApiCopyWithImpl(this._self, this._then);

  final ClientItemApi _self;
  final $Res Function(ClientItemApi) _then;

/// Create a copy of ClientItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ClientApi,
  ));
}
/// Create a copy of ClientItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClientApiCopyWith<$Res> get data {
  
  return $ClientApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [ClientItemApi].
extension ClientItemApiPatterns on ClientItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClientItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClientItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClientItemApi value)  $default,){
final _that = this;
switch (_that) {
case _ClientItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClientItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _ClientItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ClientApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClientItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ClientApi data)  $default,) {final _that = this;
switch (_that) {
case _ClientItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ClientApi data)?  $default,) {final _that = this;
switch (_that) {
case _ClientItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClientItemApi implements ClientItemApi {
  const _ClientItemApi({required this.data});
  factory _ClientItemApi.fromJson(Map<String, dynamic> json) => _$ClientItemApiFromJson(json);

@override final  ClientApi data;

/// Create a copy of ClientItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClientItemApiCopyWith<_ClientItemApi> get copyWith => __$ClientItemApiCopyWithImpl<_ClientItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClientItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClientItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'ClientItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ClientItemApiCopyWith<$Res> implements $ClientItemApiCopyWith<$Res> {
  factory _$ClientItemApiCopyWith(_ClientItemApi value, $Res Function(_ClientItemApi) _then) = __$ClientItemApiCopyWithImpl;
@override @useResult
$Res call({
 ClientApi data
});


@override $ClientApiCopyWith<$Res> get data;

}
/// @nodoc
class __$ClientItemApiCopyWithImpl<$Res>
    implements _$ClientItemApiCopyWith<$Res> {
  __$ClientItemApiCopyWithImpl(this._self, this._then);

  final _ClientItemApi _self;
  final $Res Function(_ClientItemApi) _then;

/// Create a copy of ClientItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_ClientItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ClientApi,
  ));
}

/// Create a copy of ClientItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClientApiCopyWith<$Res> get data {
  
  return $ClientApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
