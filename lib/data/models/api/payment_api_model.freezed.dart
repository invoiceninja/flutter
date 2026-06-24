// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaymentApi {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'created_user_id') String get createdUserId;@JsonKey(name: 'assigned_user_id') String get assignedUserId; String get number;@JsonKey(name: 'status_id') String get statusId;@JsonKey(name: 'type_id') String get typeId;@JsonKey(name: 'client_id') String get clientId;@JsonKey(name: 'client_contact_id') String get clientContactId;@JsonKey(name: 'company_gateway_id') String get companyGatewayId;@JsonKey(name: 'gateway_type_id') String get gatewayTypeId;@JsonKey(name: 'project_id') String get projectId;@JsonKey(name: 'vendor_id') String get vendorId;@JsonKey(name: 'invitation_id') String get invitationId;@JsonKey(name: 'currency_id') String get currencyId;@JsonKey(name: 'exchange_currency_id') String get exchangeCurrencyId;@JsonKey(name: 'transaction_reference') String get transactionReference;@JsonKey(name: 'transaction_id') String get transactionId;@JsonKey(name: 'private_notes') String get privateNotes;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4; String get date;// Money — Object so number / string both decode; parsed via parseMoney.
 Object get amount; Object get applied; Object get refunded;@JsonKey(name: 'exchange_rate') Object get exchangeRate;@JsonKey(name: 'is_manual') bool get isManual;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;// Nested allocations + server-include refs. Nullable so JSON-omitted
// (→ null) is distinguishable from JSON-present-and-empty (→ const []).
 List<PaymentableApi>? get paymentables; List<PaymentInvoiceRefApi>? get invoices; List<PaymentCreditRefApi>? get credits; List<DocumentApi>? get documents;
/// Create a copy of PaymentApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentApiCopyWith<PaymentApi> get copyWith => _$PaymentApiCopyWithImpl<PaymentApi>(this as PaymentApi, _$identity);

  /// Serializes this PaymentApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.createdUserId, createdUserId) || other.createdUserId == createdUserId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.number, number) || other.number == number)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.clientContactId, clientContactId) || other.clientContactId == clientContactId)&&(identical(other.companyGatewayId, companyGatewayId) || other.companyGatewayId == companyGatewayId)&&(identical(other.gatewayTypeId, gatewayTypeId) || other.gatewayTypeId == gatewayTypeId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.invitationId, invitationId) || other.invitationId == invitationId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.exchangeCurrencyId, exchangeCurrencyId) || other.exchangeCurrencyId == exchangeCurrencyId)&&(identical(other.transactionReference, transactionReference) || other.transactionReference == transactionReference)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.applied, applied)&&const DeepCollectionEquality().equals(other.refunded, refunded)&&const DeepCollectionEquality().equals(other.exchangeRate, exchangeRate)&&(identical(other.isManual, isManual) || other.isManual == isManual)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other.paymentables, paymentables)&&const DeepCollectionEquality().equals(other.invoices, invoices)&&const DeepCollectionEquality().equals(other.credits, credits)&&const DeepCollectionEquality().equals(other.documents, documents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,createdUserId,assignedUserId,number,statusId,typeId,clientId,clientContactId,companyGatewayId,gatewayTypeId,projectId,vendorId,invitationId,currencyId,exchangeCurrencyId,transactionReference,transactionId,privateNotes,customValue1,customValue2,customValue3,customValue4,date,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(applied),const DeepCollectionEquality().hash(refunded),const DeepCollectionEquality().hash(exchangeRate),isManual,isDeleted,createdAt,updatedAt,archivedAt,const DeepCollectionEquality().hash(paymentables),const DeepCollectionEquality().hash(invoices),const DeepCollectionEquality().hash(credits),const DeepCollectionEquality().hash(documents)]);

@override
String toString() {
  return 'PaymentApi(id: $id, userId: $userId, createdUserId: $createdUserId, assignedUserId: $assignedUserId, number: $number, statusId: $statusId, typeId: $typeId, clientId: $clientId, clientContactId: $clientContactId, companyGatewayId: $companyGatewayId, gatewayTypeId: $gatewayTypeId, projectId: $projectId, vendorId: $vendorId, invitationId: $invitationId, currencyId: $currencyId, exchangeCurrencyId: $exchangeCurrencyId, transactionReference: $transactionReference, transactionId: $transactionId, privateNotes: $privateNotes, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, date: $date, amount: $amount, applied: $applied, refunded: $refunded, exchangeRate: $exchangeRate, isManual: $isManual, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, paymentables: $paymentables, invoices: $invoices, credits: $credits, documents: $documents)';
}


}

/// @nodoc
abstract mixin class $PaymentApiCopyWith<$Res>  {
  factory $PaymentApiCopyWith(PaymentApi value, $Res Function(PaymentApi) _then) = _$PaymentApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'created_user_id') String createdUserId,@JsonKey(name: 'assigned_user_id') String assignedUserId, String number,@JsonKey(name: 'status_id') String statusId,@JsonKey(name: 'type_id') String typeId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'client_contact_id') String clientContactId,@JsonKey(name: 'company_gateway_id') String companyGatewayId,@JsonKey(name: 'gateway_type_id') String gatewayTypeId,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'invitation_id') String invitationId,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'exchange_currency_id') String exchangeCurrencyId,@JsonKey(name: 'transaction_reference') String transactionReference,@JsonKey(name: 'transaction_id') String transactionId,@JsonKey(name: 'private_notes') String privateNotes,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4, String date, Object amount, Object applied, Object refunded,@JsonKey(name: 'exchange_rate') Object exchangeRate,@JsonKey(name: 'is_manual') bool isManual,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt, List<PaymentableApi>? paymentables, List<PaymentInvoiceRefApi>? invoices, List<PaymentCreditRefApi>? credits, List<DocumentApi>? documents
});




}
/// @nodoc
class _$PaymentApiCopyWithImpl<$Res>
    implements $PaymentApiCopyWith<$Res> {
  _$PaymentApiCopyWithImpl(this._self, this._then);

  final PaymentApi _self;
  final $Res Function(PaymentApi) _then;

/// Create a copy of PaymentApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? createdUserId = null,Object? assignedUserId = null,Object? number = null,Object? statusId = null,Object? typeId = null,Object? clientId = null,Object? clientContactId = null,Object? companyGatewayId = null,Object? gatewayTypeId = null,Object? projectId = null,Object? vendorId = null,Object? invitationId = null,Object? currencyId = null,Object? exchangeCurrencyId = null,Object? transactionReference = null,Object? transactionId = null,Object? privateNotes = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? date = null,Object? amount = null,Object? applied = null,Object? refunded = null,Object? exchangeRate = null,Object? isManual = null,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? paymentables = freezed,Object? invoices = freezed,Object? credits = freezed,Object? documents = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,createdUserId: null == createdUserId ? _self.createdUserId : createdUserId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,clientContactId: null == clientContactId ? _self.clientContactId : clientContactId // ignore: cast_nullable_to_non_nullable
as String,companyGatewayId: null == companyGatewayId ? _self.companyGatewayId : companyGatewayId // ignore: cast_nullable_to_non_nullable
as String,gatewayTypeId: null == gatewayTypeId ? _self.gatewayTypeId : gatewayTypeId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,invitationId: null == invitationId ? _self.invitationId : invitationId // ignore: cast_nullable_to_non_nullable
as String,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,exchangeCurrencyId: null == exchangeCurrencyId ? _self.exchangeCurrencyId : exchangeCurrencyId // ignore: cast_nullable_to_non_nullable
as String,transactionReference: null == transactionReference ? _self.transactionReference : transactionReference // ignore: cast_nullable_to_non_nullable
as String,transactionId: null == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,applied: null == applied ? _self.applied : applied ,refunded: null == refunded ? _self.refunded : refunded ,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate ,isManual: null == isManual ? _self.isManual : isManual // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,paymentables: freezed == paymentables ? _self.paymentables : paymentables // ignore: cast_nullable_to_non_nullable
as List<PaymentableApi>?,invoices: freezed == invoices ? _self.invoices : invoices // ignore: cast_nullable_to_non_nullable
as List<PaymentInvoiceRefApi>?,credits: freezed == credits ? _self.credits : credits // ignore: cast_nullable_to_non_nullable
as List<PaymentCreditRefApi>?,documents: freezed == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentApi].
extension PaymentApiPatterns on PaymentApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentApi value)  $default,){
final _that = this;
switch (_that) {
case _PaymentApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentApi value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'created_user_id')  String createdUserId, @JsonKey(name: 'assigned_user_id')  String assignedUserId,  String number, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'type_id')  String typeId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'client_contact_id')  String clientContactId, @JsonKey(name: 'company_gateway_id')  String companyGatewayId, @JsonKey(name: 'gateway_type_id')  String gatewayTypeId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'invitation_id')  String invitationId, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'exchange_currency_id')  String exchangeCurrencyId, @JsonKey(name: 'transaction_reference')  String transactionReference, @JsonKey(name: 'transaction_id')  String transactionId, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4,  String date,  Object amount,  Object applied,  Object refunded, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'is_manual')  bool isManual, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt,  List<PaymentableApi>? paymentables,  List<PaymentInvoiceRefApi>? invoices,  List<PaymentCreditRefApi>? credits,  List<DocumentApi>? documents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentApi() when $default != null:
return $default(_that.id,_that.userId,_that.createdUserId,_that.assignedUserId,_that.number,_that.statusId,_that.typeId,_that.clientId,_that.clientContactId,_that.companyGatewayId,_that.gatewayTypeId,_that.projectId,_that.vendorId,_that.invitationId,_that.currencyId,_that.exchangeCurrencyId,_that.transactionReference,_that.transactionId,_that.privateNotes,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.date,_that.amount,_that.applied,_that.refunded,_that.exchangeRate,_that.isManual,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.paymentables,_that.invoices,_that.credits,_that.documents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'created_user_id')  String createdUserId, @JsonKey(name: 'assigned_user_id')  String assignedUserId,  String number, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'type_id')  String typeId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'client_contact_id')  String clientContactId, @JsonKey(name: 'company_gateway_id')  String companyGatewayId, @JsonKey(name: 'gateway_type_id')  String gatewayTypeId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'invitation_id')  String invitationId, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'exchange_currency_id')  String exchangeCurrencyId, @JsonKey(name: 'transaction_reference')  String transactionReference, @JsonKey(name: 'transaction_id')  String transactionId, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4,  String date,  Object amount,  Object applied,  Object refunded, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'is_manual')  bool isManual, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt,  List<PaymentableApi>? paymentables,  List<PaymentInvoiceRefApi>? invoices,  List<PaymentCreditRefApi>? credits,  List<DocumentApi>? documents)  $default,) {final _that = this;
switch (_that) {
case _PaymentApi():
return $default(_that.id,_that.userId,_that.createdUserId,_that.assignedUserId,_that.number,_that.statusId,_that.typeId,_that.clientId,_that.clientContactId,_that.companyGatewayId,_that.gatewayTypeId,_that.projectId,_that.vendorId,_that.invitationId,_that.currencyId,_that.exchangeCurrencyId,_that.transactionReference,_that.transactionId,_that.privateNotes,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.date,_that.amount,_that.applied,_that.refunded,_that.exchangeRate,_that.isManual,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.paymentables,_that.invoices,_that.credits,_that.documents);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'created_user_id')  String createdUserId, @JsonKey(name: 'assigned_user_id')  String assignedUserId,  String number, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'type_id')  String typeId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'client_contact_id')  String clientContactId, @JsonKey(name: 'company_gateway_id')  String companyGatewayId, @JsonKey(name: 'gateway_type_id')  String gatewayTypeId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'invitation_id')  String invitationId, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'exchange_currency_id')  String exchangeCurrencyId, @JsonKey(name: 'transaction_reference')  String transactionReference, @JsonKey(name: 'transaction_id')  String transactionId, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4,  String date,  Object amount,  Object applied,  Object refunded, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'is_manual')  bool isManual, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt,  List<PaymentableApi>? paymentables,  List<PaymentInvoiceRefApi>? invoices,  List<PaymentCreditRefApi>? credits,  List<DocumentApi>? documents)?  $default,) {final _that = this;
switch (_that) {
case _PaymentApi() when $default != null:
return $default(_that.id,_that.userId,_that.createdUserId,_that.assignedUserId,_that.number,_that.statusId,_that.typeId,_that.clientId,_that.clientContactId,_that.companyGatewayId,_that.gatewayTypeId,_that.projectId,_that.vendorId,_that.invitationId,_that.currencyId,_that.exchangeCurrencyId,_that.transactionReference,_that.transactionId,_that.privateNotes,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.date,_that.amount,_that.applied,_that.refunded,_that.exchangeRate,_that.isManual,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.paymentables,_that.invoices,_that.credits,_that.documents);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentApi implements PaymentApi {
  const _PaymentApi({this.id = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'created_user_id') this.createdUserId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', this.number = '', @JsonKey(name: 'status_id') this.statusId = '', @JsonKey(name: 'type_id') this.typeId = '', @JsonKey(name: 'client_id') this.clientId = '', @JsonKey(name: 'client_contact_id') this.clientContactId = '', @JsonKey(name: 'company_gateway_id') this.companyGatewayId = '', @JsonKey(name: 'gateway_type_id') this.gatewayTypeId = '', @JsonKey(name: 'project_id') this.projectId = '', @JsonKey(name: 'vendor_id') this.vendorId = '', @JsonKey(name: 'invitation_id') this.invitationId = '', @JsonKey(name: 'currency_id') this.currencyId = '', @JsonKey(name: 'exchange_currency_id') this.exchangeCurrencyId = '', @JsonKey(name: 'transaction_reference') this.transactionReference = '', @JsonKey(name: 'transaction_id') this.transactionId = '', @JsonKey(name: 'private_notes') this.privateNotes = '', @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', this.date = '', this.amount = '0', this.applied = '0', this.refunded = '0', @JsonKey(name: 'exchange_rate') this.exchangeRate = '1', @JsonKey(name: 'is_manual') this.isManual = false, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, final  List<PaymentableApi>? paymentables, final  List<PaymentInvoiceRefApi>? invoices, final  List<PaymentCreditRefApi>? credits, final  List<DocumentApi>? documents}): _paymentables = paymentables,_invoices = invoices,_credits = credits,_documents = documents;
  factory _PaymentApi.fromJson(Map<String, dynamic> json) => _$PaymentApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'created_user_id') final  String createdUserId;
@override@JsonKey(name: 'assigned_user_id') final  String assignedUserId;
@override@JsonKey() final  String number;
@override@JsonKey(name: 'status_id') final  String statusId;
@override@JsonKey(name: 'type_id') final  String typeId;
@override@JsonKey(name: 'client_id') final  String clientId;
@override@JsonKey(name: 'client_contact_id') final  String clientContactId;
@override@JsonKey(name: 'company_gateway_id') final  String companyGatewayId;
@override@JsonKey(name: 'gateway_type_id') final  String gatewayTypeId;
@override@JsonKey(name: 'project_id') final  String projectId;
@override@JsonKey(name: 'vendor_id') final  String vendorId;
@override@JsonKey(name: 'invitation_id') final  String invitationId;
@override@JsonKey(name: 'currency_id') final  String currencyId;
@override@JsonKey(name: 'exchange_currency_id') final  String exchangeCurrencyId;
@override@JsonKey(name: 'transaction_reference') final  String transactionReference;
@override@JsonKey(name: 'transaction_id') final  String transactionId;
@override@JsonKey(name: 'private_notes') final  String privateNotes;
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
@override@JsonKey() final  String date;
// Money — Object so number / string both decode; parsed via parseMoney.
@override@JsonKey() final  Object amount;
@override@JsonKey() final  Object applied;
@override@JsonKey() final  Object refunded;
@override@JsonKey(name: 'exchange_rate') final  Object exchangeRate;
@override@JsonKey(name: 'is_manual') final  bool isManual;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
// Nested allocations + server-include refs. Nullable so JSON-omitted
// (→ null) is distinguishable from JSON-present-and-empty (→ const []).
 final  List<PaymentableApi>? _paymentables;
// Nested allocations + server-include refs. Nullable so JSON-omitted
// (→ null) is distinguishable from JSON-present-and-empty (→ const []).
@override List<PaymentableApi>? get paymentables {
  final value = _paymentables;
  if (value == null) return null;
  if (_paymentables is EqualUnmodifiableListView) return _paymentables;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<PaymentInvoiceRefApi>? _invoices;
@override List<PaymentInvoiceRefApi>? get invoices {
  final value = _invoices;
  if (value == null) return null;
  if (_invoices is EqualUnmodifiableListView) return _invoices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<PaymentCreditRefApi>? _credits;
@override List<PaymentCreditRefApi>? get credits {
  final value = _credits;
  if (value == null) return null;
  if (_credits is EqualUnmodifiableListView) return _credits;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<DocumentApi>? _documents;
@override List<DocumentApi>? get documents {
  final value = _documents;
  if (value == null) return null;
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of PaymentApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentApiCopyWith<_PaymentApi> get copyWith => __$PaymentApiCopyWithImpl<_PaymentApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.createdUserId, createdUserId) || other.createdUserId == createdUserId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.number, number) || other.number == number)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.clientContactId, clientContactId) || other.clientContactId == clientContactId)&&(identical(other.companyGatewayId, companyGatewayId) || other.companyGatewayId == companyGatewayId)&&(identical(other.gatewayTypeId, gatewayTypeId) || other.gatewayTypeId == gatewayTypeId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.invitationId, invitationId) || other.invitationId == invitationId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.exchangeCurrencyId, exchangeCurrencyId) || other.exchangeCurrencyId == exchangeCurrencyId)&&(identical(other.transactionReference, transactionReference) || other.transactionReference == transactionReference)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.applied, applied)&&const DeepCollectionEquality().equals(other.refunded, refunded)&&const DeepCollectionEquality().equals(other.exchangeRate, exchangeRate)&&(identical(other.isManual, isManual) || other.isManual == isManual)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other._paymentables, _paymentables)&&const DeepCollectionEquality().equals(other._invoices, _invoices)&&const DeepCollectionEquality().equals(other._credits, _credits)&&const DeepCollectionEquality().equals(other._documents, _documents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,createdUserId,assignedUserId,number,statusId,typeId,clientId,clientContactId,companyGatewayId,gatewayTypeId,projectId,vendorId,invitationId,currencyId,exchangeCurrencyId,transactionReference,transactionId,privateNotes,customValue1,customValue2,customValue3,customValue4,date,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(applied),const DeepCollectionEquality().hash(refunded),const DeepCollectionEquality().hash(exchangeRate),isManual,isDeleted,createdAt,updatedAt,archivedAt,const DeepCollectionEquality().hash(_paymentables),const DeepCollectionEquality().hash(_invoices),const DeepCollectionEquality().hash(_credits),const DeepCollectionEquality().hash(_documents)]);

@override
String toString() {
  return 'PaymentApi(id: $id, userId: $userId, createdUserId: $createdUserId, assignedUserId: $assignedUserId, number: $number, statusId: $statusId, typeId: $typeId, clientId: $clientId, clientContactId: $clientContactId, companyGatewayId: $companyGatewayId, gatewayTypeId: $gatewayTypeId, projectId: $projectId, vendorId: $vendorId, invitationId: $invitationId, currencyId: $currencyId, exchangeCurrencyId: $exchangeCurrencyId, transactionReference: $transactionReference, transactionId: $transactionId, privateNotes: $privateNotes, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, date: $date, amount: $amount, applied: $applied, refunded: $refunded, exchangeRate: $exchangeRate, isManual: $isManual, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, paymentables: $paymentables, invoices: $invoices, credits: $credits, documents: $documents)';
}


}

/// @nodoc
abstract mixin class _$PaymentApiCopyWith<$Res> implements $PaymentApiCopyWith<$Res> {
  factory _$PaymentApiCopyWith(_PaymentApi value, $Res Function(_PaymentApi) _then) = __$PaymentApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'created_user_id') String createdUserId,@JsonKey(name: 'assigned_user_id') String assignedUserId, String number,@JsonKey(name: 'status_id') String statusId,@JsonKey(name: 'type_id') String typeId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'client_contact_id') String clientContactId,@JsonKey(name: 'company_gateway_id') String companyGatewayId,@JsonKey(name: 'gateway_type_id') String gatewayTypeId,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'invitation_id') String invitationId,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'exchange_currency_id') String exchangeCurrencyId,@JsonKey(name: 'transaction_reference') String transactionReference,@JsonKey(name: 'transaction_id') String transactionId,@JsonKey(name: 'private_notes') String privateNotes,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4, String date, Object amount, Object applied, Object refunded,@JsonKey(name: 'exchange_rate') Object exchangeRate,@JsonKey(name: 'is_manual') bool isManual,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt, List<PaymentableApi>? paymentables, List<PaymentInvoiceRefApi>? invoices, List<PaymentCreditRefApi>? credits, List<DocumentApi>? documents
});




}
/// @nodoc
class __$PaymentApiCopyWithImpl<$Res>
    implements _$PaymentApiCopyWith<$Res> {
  __$PaymentApiCopyWithImpl(this._self, this._then);

  final _PaymentApi _self;
  final $Res Function(_PaymentApi) _then;

/// Create a copy of PaymentApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? createdUserId = null,Object? assignedUserId = null,Object? number = null,Object? statusId = null,Object? typeId = null,Object? clientId = null,Object? clientContactId = null,Object? companyGatewayId = null,Object? gatewayTypeId = null,Object? projectId = null,Object? vendorId = null,Object? invitationId = null,Object? currencyId = null,Object? exchangeCurrencyId = null,Object? transactionReference = null,Object? transactionId = null,Object? privateNotes = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? date = null,Object? amount = null,Object? applied = null,Object? refunded = null,Object? exchangeRate = null,Object? isManual = null,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? paymentables = freezed,Object? invoices = freezed,Object? credits = freezed,Object? documents = freezed,}) {
  return _then(_PaymentApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,createdUserId: null == createdUserId ? _self.createdUserId : createdUserId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,clientContactId: null == clientContactId ? _self.clientContactId : clientContactId // ignore: cast_nullable_to_non_nullable
as String,companyGatewayId: null == companyGatewayId ? _self.companyGatewayId : companyGatewayId // ignore: cast_nullable_to_non_nullable
as String,gatewayTypeId: null == gatewayTypeId ? _self.gatewayTypeId : gatewayTypeId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,invitationId: null == invitationId ? _self.invitationId : invitationId // ignore: cast_nullable_to_non_nullable
as String,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,exchangeCurrencyId: null == exchangeCurrencyId ? _self.exchangeCurrencyId : exchangeCurrencyId // ignore: cast_nullable_to_non_nullable
as String,transactionReference: null == transactionReference ? _self.transactionReference : transactionReference // ignore: cast_nullable_to_non_nullable
as String,transactionId: null == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,applied: null == applied ? _self.applied : applied ,refunded: null == refunded ? _self.refunded : refunded ,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate ,isManual: null == isManual ? _self.isManual : isManual // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,paymentables: freezed == paymentables ? _self._paymentables : paymentables // ignore: cast_nullable_to_non_nullable
as List<PaymentableApi>?,invoices: freezed == invoices ? _self._invoices : invoices // ignore: cast_nullable_to_non_nullable
as List<PaymentInvoiceRefApi>?,credits: freezed == credits ? _self._credits : credits // ignore: cast_nullable_to_non_nullable
as List<PaymentCreditRefApi>?,documents: freezed == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,
  ));
}


}


/// @nodoc
mixin _$PaymentableApi {

 String get id;@JsonKey(name: 'invoice_id') String get invoiceId;@JsonKey(name: 'credit_id') String get creditId; Object get amount; Object get refunded;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;
/// Create a copy of PaymentableApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentableApiCopyWith<PaymentableApi> get copyWith => _$PaymentableApiCopyWithImpl<PaymentableApi>(this as PaymentableApi, _$identity);

  /// Serializes this PaymentableApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentableApi&&(identical(other.id, id) || other.id == id)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.creditId, creditId) || other.creditId == creditId)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.refunded, refunded)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,invoiceId,creditId,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(refunded),createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'PaymentableApi(id: $id, invoiceId: $invoiceId, creditId: $creditId, amount: $amount, refunded: $refunded, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class $PaymentableApiCopyWith<$Res>  {
  factory $PaymentableApiCopyWith(PaymentableApi value, $Res Function(PaymentableApi) _then) = _$PaymentableApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'invoice_id') String invoiceId,@JsonKey(name: 'credit_id') String creditId, Object amount, Object refunded,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class _$PaymentableApiCopyWithImpl<$Res>
    implements $PaymentableApiCopyWith<$Res> {
  _$PaymentableApiCopyWithImpl(this._self, this._then);

  final PaymentableApi _self;
  final $Res Function(PaymentableApi) _then;

/// Create a copy of PaymentableApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? invoiceId = null,Object? creditId = null,Object? amount = null,Object? refunded = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,creditId: null == creditId ? _self.creditId : creditId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,refunded: null == refunded ? _self.refunded : refunded ,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentableApi].
extension PaymentableApiPatterns on PaymentableApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentableApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentableApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentableApi value)  $default,){
final _that = this;
switch (_that) {
case _PaymentableApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentableApi value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentableApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'invoice_id')  String invoiceId, @JsonKey(name: 'credit_id')  String creditId,  Object amount,  Object refunded, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentableApi() when $default != null:
return $default(_that.id,_that.invoiceId,_that.creditId,_that.amount,_that.refunded,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'invoice_id')  String invoiceId, @JsonKey(name: 'credit_id')  String creditId,  Object amount,  Object refunded, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)  $default,) {final _that = this;
switch (_that) {
case _PaymentableApi():
return $default(_that.id,_that.invoiceId,_that.creditId,_that.amount,_that.refunded,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'invoice_id')  String invoiceId, @JsonKey(name: 'credit_id')  String creditId,  Object amount,  Object refunded, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _PaymentableApi() when $default != null:
return $default(_that.id,_that.invoiceId,_that.creditId,_that.amount,_that.refunded,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentableApi implements PaymentableApi {
  const _PaymentableApi({this.id = '', @JsonKey(name: 'invoice_id') this.invoiceId = '', @JsonKey(name: 'credit_id') this.creditId = '', this.amount = '0', this.refunded = '0', @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0});
  factory _PaymentableApi.fromJson(Map<String, dynamic> json) => _$PaymentableApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'invoice_id') final  String invoiceId;
@override@JsonKey(name: 'credit_id') final  String creditId;
@override@JsonKey() final  Object amount;
@override@JsonKey() final  Object refunded;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;

/// Create a copy of PaymentableApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentableApiCopyWith<_PaymentableApi> get copyWith => __$PaymentableApiCopyWithImpl<_PaymentableApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentableApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentableApi&&(identical(other.id, id) || other.id == id)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.creditId, creditId) || other.creditId == creditId)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.refunded, refunded)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,invoiceId,creditId,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(refunded),createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'PaymentableApi(id: $id, invoiceId: $invoiceId, creditId: $creditId, amount: $amount, refunded: $refunded, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$PaymentableApiCopyWith<$Res> implements $PaymentableApiCopyWith<$Res> {
  factory _$PaymentableApiCopyWith(_PaymentableApi value, $Res Function(_PaymentableApi) _then) = __$PaymentableApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'invoice_id') String invoiceId,@JsonKey(name: 'credit_id') String creditId, Object amount, Object refunded,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class __$PaymentableApiCopyWithImpl<$Res>
    implements _$PaymentableApiCopyWith<$Res> {
  __$PaymentableApiCopyWithImpl(this._self, this._then);

  final _PaymentableApi _self;
  final $Res Function(_PaymentableApi) _then;

/// Create a copy of PaymentableApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? invoiceId = null,Object? creditId = null,Object? amount = null,Object? refunded = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_PaymentableApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,creditId: null == creditId ? _self.creditId : creditId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,refunded: null == refunded ? _self.refunded : refunded ,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$PaymentInvoiceRefApi {

 String get id; String get number; Object get amount; Object get balance;@JsonKey(name: 'paid_to_date') Object get paidToDate;
/// Create a copy of PaymentInvoiceRefApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentInvoiceRefApiCopyWith<PaymentInvoiceRefApi> get copyWith => _$PaymentInvoiceRefApiCopyWithImpl<PaymentInvoiceRefApi>(this as PaymentInvoiceRefApi, _$identity);

  /// Serializes this PaymentInvoiceRefApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentInvoiceRefApi&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.balance, balance)&&const DeepCollectionEquality().equals(other.paidToDate, paidToDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,number,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(balance),const DeepCollectionEquality().hash(paidToDate));

@override
String toString() {
  return 'PaymentInvoiceRefApi(id: $id, number: $number, amount: $amount, balance: $balance, paidToDate: $paidToDate)';
}


}

/// @nodoc
abstract mixin class $PaymentInvoiceRefApiCopyWith<$Res>  {
  factory $PaymentInvoiceRefApiCopyWith(PaymentInvoiceRefApi value, $Res Function(PaymentInvoiceRefApi) _then) = _$PaymentInvoiceRefApiCopyWithImpl;
@useResult
$Res call({
 String id, String number, Object amount, Object balance,@JsonKey(name: 'paid_to_date') Object paidToDate
});




}
/// @nodoc
class _$PaymentInvoiceRefApiCopyWithImpl<$Res>
    implements $PaymentInvoiceRefApiCopyWith<$Res> {
  _$PaymentInvoiceRefApiCopyWithImpl(this._self, this._then);

  final PaymentInvoiceRefApi _self;
  final $Res Function(PaymentInvoiceRefApi) _then;

/// Create a copy of PaymentInvoiceRefApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? amount = null,Object? balance = null,Object? paidToDate = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,balance: null == balance ? _self.balance : balance ,paidToDate: null == paidToDate ? _self.paidToDate : paidToDate ,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentInvoiceRefApi].
extension PaymentInvoiceRefApiPatterns on PaymentInvoiceRefApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentInvoiceRefApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentInvoiceRefApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentInvoiceRefApi value)  $default,){
final _that = this;
switch (_that) {
case _PaymentInvoiceRefApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentInvoiceRefApi value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentInvoiceRefApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number,  Object amount,  Object balance, @JsonKey(name: 'paid_to_date')  Object paidToDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentInvoiceRefApi() when $default != null:
return $default(_that.id,_that.number,_that.amount,_that.balance,_that.paidToDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number,  Object amount,  Object balance, @JsonKey(name: 'paid_to_date')  Object paidToDate)  $default,) {final _that = this;
switch (_that) {
case _PaymentInvoiceRefApi():
return $default(_that.id,_that.number,_that.amount,_that.balance,_that.paidToDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number,  Object amount,  Object balance, @JsonKey(name: 'paid_to_date')  Object paidToDate)?  $default,) {final _that = this;
switch (_that) {
case _PaymentInvoiceRefApi() when $default != null:
return $default(_that.id,_that.number,_that.amount,_that.balance,_that.paidToDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentInvoiceRefApi implements PaymentInvoiceRefApi {
  const _PaymentInvoiceRefApi({this.id = '', this.number = '', this.amount = '0', this.balance = '0', @JsonKey(name: 'paid_to_date') this.paidToDate = '0'});
  factory _PaymentInvoiceRefApi.fromJson(Map<String, dynamic> json) => _$PaymentInvoiceRefApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String number;
@override@JsonKey() final  Object amount;
@override@JsonKey() final  Object balance;
@override@JsonKey(name: 'paid_to_date') final  Object paidToDate;

/// Create a copy of PaymentInvoiceRefApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentInvoiceRefApiCopyWith<_PaymentInvoiceRefApi> get copyWith => __$PaymentInvoiceRefApiCopyWithImpl<_PaymentInvoiceRefApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentInvoiceRefApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentInvoiceRefApi&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.balance, balance)&&const DeepCollectionEquality().equals(other.paidToDate, paidToDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,number,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(balance),const DeepCollectionEquality().hash(paidToDate));

@override
String toString() {
  return 'PaymentInvoiceRefApi(id: $id, number: $number, amount: $amount, balance: $balance, paidToDate: $paidToDate)';
}


}

/// @nodoc
abstract mixin class _$PaymentInvoiceRefApiCopyWith<$Res> implements $PaymentInvoiceRefApiCopyWith<$Res> {
  factory _$PaymentInvoiceRefApiCopyWith(_PaymentInvoiceRefApi value, $Res Function(_PaymentInvoiceRefApi) _then) = __$PaymentInvoiceRefApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String number, Object amount, Object balance,@JsonKey(name: 'paid_to_date') Object paidToDate
});




}
/// @nodoc
class __$PaymentInvoiceRefApiCopyWithImpl<$Res>
    implements _$PaymentInvoiceRefApiCopyWith<$Res> {
  __$PaymentInvoiceRefApiCopyWithImpl(this._self, this._then);

  final _PaymentInvoiceRefApi _self;
  final $Res Function(_PaymentInvoiceRefApi) _then;

/// Create a copy of PaymentInvoiceRefApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? amount = null,Object? balance = null,Object? paidToDate = null,}) {
  return _then(_PaymentInvoiceRefApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,balance: null == balance ? _self.balance : balance ,paidToDate: null == paidToDate ? _self.paidToDate : paidToDate ,
  ));
}


}


/// @nodoc
mixin _$PaymentCreditRefApi {

 String get id; String get number; Object get amount; Object get balance;
/// Create a copy of PaymentCreditRefApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentCreditRefApiCopyWith<PaymentCreditRefApi> get copyWith => _$PaymentCreditRefApiCopyWithImpl<PaymentCreditRefApi>(this as PaymentCreditRefApi, _$identity);

  /// Serializes this PaymentCreditRefApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentCreditRefApi&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.balance, balance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,number,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(balance));

@override
String toString() {
  return 'PaymentCreditRefApi(id: $id, number: $number, amount: $amount, balance: $balance)';
}


}

/// @nodoc
abstract mixin class $PaymentCreditRefApiCopyWith<$Res>  {
  factory $PaymentCreditRefApiCopyWith(PaymentCreditRefApi value, $Res Function(PaymentCreditRefApi) _then) = _$PaymentCreditRefApiCopyWithImpl;
@useResult
$Res call({
 String id, String number, Object amount, Object balance
});




}
/// @nodoc
class _$PaymentCreditRefApiCopyWithImpl<$Res>
    implements $PaymentCreditRefApiCopyWith<$Res> {
  _$PaymentCreditRefApiCopyWithImpl(this._self, this._then);

  final PaymentCreditRefApi _self;
  final $Res Function(PaymentCreditRefApi) _then;

/// Create a copy of PaymentCreditRefApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? amount = null,Object? balance = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,balance: null == balance ? _self.balance : balance ,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentCreditRefApi].
extension PaymentCreditRefApiPatterns on PaymentCreditRefApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentCreditRefApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentCreditRefApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentCreditRefApi value)  $default,){
final _that = this;
switch (_that) {
case _PaymentCreditRefApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentCreditRefApi value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentCreditRefApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number,  Object amount,  Object balance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentCreditRefApi() when $default != null:
return $default(_that.id,_that.number,_that.amount,_that.balance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number,  Object amount,  Object balance)  $default,) {final _that = this;
switch (_that) {
case _PaymentCreditRefApi():
return $default(_that.id,_that.number,_that.amount,_that.balance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number,  Object amount,  Object balance)?  $default,) {final _that = this;
switch (_that) {
case _PaymentCreditRefApi() when $default != null:
return $default(_that.id,_that.number,_that.amount,_that.balance);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentCreditRefApi implements PaymentCreditRefApi {
  const _PaymentCreditRefApi({this.id = '', this.number = '', this.amount = '0', this.balance = '0'});
  factory _PaymentCreditRefApi.fromJson(Map<String, dynamic> json) => _$PaymentCreditRefApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String number;
@override@JsonKey() final  Object amount;
@override@JsonKey() final  Object balance;

/// Create a copy of PaymentCreditRefApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentCreditRefApiCopyWith<_PaymentCreditRefApi> get copyWith => __$PaymentCreditRefApiCopyWithImpl<_PaymentCreditRefApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentCreditRefApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentCreditRefApi&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.balance, balance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,number,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(balance));

@override
String toString() {
  return 'PaymentCreditRefApi(id: $id, number: $number, amount: $amount, balance: $balance)';
}


}

/// @nodoc
abstract mixin class _$PaymentCreditRefApiCopyWith<$Res> implements $PaymentCreditRefApiCopyWith<$Res> {
  factory _$PaymentCreditRefApiCopyWith(_PaymentCreditRefApi value, $Res Function(_PaymentCreditRefApi) _then) = __$PaymentCreditRefApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String number, Object amount, Object balance
});




}
/// @nodoc
class __$PaymentCreditRefApiCopyWithImpl<$Res>
    implements _$PaymentCreditRefApiCopyWith<$Res> {
  __$PaymentCreditRefApiCopyWithImpl(this._self, this._then);

  final _PaymentCreditRefApi _self;
  final $Res Function(_PaymentCreditRefApi) _then;

/// Create a copy of PaymentCreditRefApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? amount = null,Object? balance = null,}) {
  return _then(_PaymentCreditRefApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,balance: null == balance ? _self.balance : balance ,
  ));
}


}


/// @nodoc
mixin _$PaymentListApi {

@JsonKey(fromJson: _paymentListData) List<PaymentApi> get data;
/// Create a copy of PaymentListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentListApiCopyWith<PaymentListApi> get copyWith => _$PaymentListApiCopyWithImpl<PaymentListApi>(this as PaymentListApi, _$identity);

  /// Serializes this PaymentListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'PaymentListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $PaymentListApiCopyWith<$Res>  {
  factory $PaymentListApiCopyWith(PaymentListApi value, $Res Function(PaymentListApi) _then) = _$PaymentListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _paymentListData) List<PaymentApi> data
});




}
/// @nodoc
class _$PaymentListApiCopyWithImpl<$Res>
    implements $PaymentListApiCopyWith<$Res> {
  _$PaymentListApiCopyWithImpl(this._self, this._then);

  final PaymentListApi _self;
  final $Res Function(PaymentListApi) _then;

/// Create a copy of PaymentListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<PaymentApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentListApi].
extension PaymentListApiPatterns on PaymentListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentListApi value)  $default,){
final _that = this;
switch (_that) {
case _PaymentListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentListApi value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _paymentListData)  List<PaymentApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _paymentListData)  List<PaymentApi> data)  $default,) {final _that = this;
switch (_that) {
case _PaymentListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _paymentListData)  List<PaymentApi> data)?  $default,) {final _that = this;
switch (_that) {
case _PaymentListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentListApi implements PaymentListApi {
  const _PaymentListApi({@JsonKey(fromJson: _paymentListData) final  List<PaymentApi> data = const []}): _data = data;
  factory _PaymentListApi.fromJson(Map<String, dynamic> json) => _$PaymentListApiFromJson(json);

 final  List<PaymentApi> _data;
@override@JsonKey(fromJson: _paymentListData) List<PaymentApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of PaymentListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentListApiCopyWith<_PaymentListApi> get copyWith => __$PaymentListApiCopyWithImpl<_PaymentListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'PaymentListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$PaymentListApiCopyWith<$Res> implements $PaymentListApiCopyWith<$Res> {
  factory _$PaymentListApiCopyWith(_PaymentListApi value, $Res Function(_PaymentListApi) _then) = __$PaymentListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _paymentListData) List<PaymentApi> data
});




}
/// @nodoc
class __$PaymentListApiCopyWithImpl<$Res>
    implements _$PaymentListApiCopyWith<$Res> {
  __$PaymentListApiCopyWithImpl(this._self, this._then);

  final _PaymentListApi _self;
  final $Res Function(_PaymentListApi) _then;

/// Create a copy of PaymentListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_PaymentListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<PaymentApi>,
  ));
}


}


/// @nodoc
mixin _$PaymentItemApi {

 PaymentApi get data;
/// Create a copy of PaymentItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentItemApiCopyWith<PaymentItemApi> get copyWith => _$PaymentItemApiCopyWithImpl<PaymentItemApi>(this as PaymentItemApi, _$identity);

  /// Serializes this PaymentItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'PaymentItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $PaymentItemApiCopyWith<$Res>  {
  factory $PaymentItemApiCopyWith(PaymentItemApi value, $Res Function(PaymentItemApi) _then) = _$PaymentItemApiCopyWithImpl;
@useResult
$Res call({
 PaymentApi data
});


$PaymentApiCopyWith<$Res> get data;

}
/// @nodoc
class _$PaymentItemApiCopyWithImpl<$Res>
    implements $PaymentItemApiCopyWith<$Res> {
  _$PaymentItemApiCopyWithImpl(this._self, this._then);

  final PaymentItemApi _self;
  final $Res Function(PaymentItemApi) _then;

/// Create a copy of PaymentItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as PaymentApi,
  ));
}
/// Create a copy of PaymentItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentApiCopyWith<$Res> get data {
  
  return $PaymentApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [PaymentItemApi].
extension PaymentItemApiPatterns on PaymentItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentItemApi value)  $default,){
final _that = this;
switch (_that) {
case _PaymentItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PaymentApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PaymentApi data)  $default,) {final _that = this;
switch (_that) {
case _PaymentItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PaymentApi data)?  $default,) {final _that = this;
switch (_that) {
case _PaymentItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentItemApi implements PaymentItemApi {
  const _PaymentItemApi({required this.data});
  factory _PaymentItemApi.fromJson(Map<String, dynamic> json) => _$PaymentItemApiFromJson(json);

@override final  PaymentApi data;

/// Create a copy of PaymentItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentItemApiCopyWith<_PaymentItemApi> get copyWith => __$PaymentItemApiCopyWithImpl<_PaymentItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'PaymentItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$PaymentItemApiCopyWith<$Res> implements $PaymentItemApiCopyWith<$Res> {
  factory _$PaymentItemApiCopyWith(_PaymentItemApi value, $Res Function(_PaymentItemApi) _then) = __$PaymentItemApiCopyWithImpl;
@override @useResult
$Res call({
 PaymentApi data
});


@override $PaymentApiCopyWith<$Res> get data;

}
/// @nodoc
class __$PaymentItemApiCopyWithImpl<$Res>
    implements _$PaymentItemApiCopyWith<$Res> {
  __$PaymentItemApiCopyWithImpl(this._self, this._then);

  final _PaymentItemApi _self;
  final $Res Function(_PaymentItemApi) _then;

/// Create a copy of PaymentItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_PaymentItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as PaymentApi,
  ));
}

/// Create a copy of PaymentItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentApiCopyWith<$Res> get data {
  
  return $PaymentApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
