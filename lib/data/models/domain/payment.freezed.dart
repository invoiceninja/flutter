// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Payment {

 String get id; String get number; String get statusId; String get typeId; String get clientId; String get clientContactId; String get companyGatewayId; String get gatewayTypeId; String get projectId; String get vendorId; String get invitationId; String get currencyId; String get exchangeCurrencyId; String get transactionReference; String get transactionId; String get privateNotes; String get customValue1; String get customValue2; String get customValue3; String get customValue4; String get userId; String get createdUserId; String get assignedUserId; Date? get date; Decimal get amount; Decimal get applied; Decimal get refunded; Decimal get exchangeRate; bool get isManual; bool get isDeleted; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; List<Paymentable> get paymentables; List<PaymentInvoiceRef> get invoices; List<PaymentCreditRef> get credits; List<Document> get documents; List<String> get tagIds; bool get isDirty;
/// Create a copy of Payment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentCopyWith<Payment> get copyWith => _$PaymentCopyWithImpl<Payment>(this as Payment, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Payment&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.clientContactId, clientContactId) || other.clientContactId == clientContactId)&&(identical(other.companyGatewayId, companyGatewayId) || other.companyGatewayId == companyGatewayId)&&(identical(other.gatewayTypeId, gatewayTypeId) || other.gatewayTypeId == gatewayTypeId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.invitationId, invitationId) || other.invitationId == invitationId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.exchangeCurrencyId, exchangeCurrencyId) || other.exchangeCurrencyId == exchangeCurrencyId)&&(identical(other.transactionReference, transactionReference) || other.transactionReference == transactionReference)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.createdUserId, createdUserId) || other.createdUserId == createdUserId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.date, date) || other.date == date)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.applied, applied) || other.applied == applied)&&(identical(other.refunded, refunded) || other.refunded == refunded)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.isManual, isManual) || other.isManual == isManual)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other.paymentables, paymentables)&&const DeepCollectionEquality().equals(other.invoices, invoices)&&const DeepCollectionEquality().equals(other.credits, credits)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.tagIds, tagIds)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,number,statusId,typeId,clientId,clientContactId,companyGatewayId,gatewayTypeId,projectId,vendorId,invitationId,currencyId,exchangeCurrencyId,transactionReference,transactionId,privateNotes,customValue1,customValue2,customValue3,customValue4,userId,createdUserId,assignedUserId,date,amount,applied,refunded,exchangeRate,isManual,isDeleted,updatedAt,createdAt,archivedAt,const DeepCollectionEquality().hash(paymentables),const DeepCollectionEquality().hash(invoices),const DeepCollectionEquality().hash(credits),const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(tagIds),isDirty]);

@override
String toString() {
  return 'Payment(id: $id, number: $number, statusId: $statusId, typeId: $typeId, clientId: $clientId, clientContactId: $clientContactId, companyGatewayId: $companyGatewayId, gatewayTypeId: $gatewayTypeId, projectId: $projectId, vendorId: $vendorId, invitationId: $invitationId, currencyId: $currencyId, exchangeCurrencyId: $exchangeCurrencyId, transactionReference: $transactionReference, transactionId: $transactionId, privateNotes: $privateNotes, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, userId: $userId, createdUserId: $createdUserId, assignedUserId: $assignedUserId, date: $date, amount: $amount, applied: $applied, refunded: $refunded, exchangeRate: $exchangeRate, isManual: $isManual, isDeleted: $isDeleted, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, paymentables: $paymentables, invoices: $invoices, credits: $credits, documents: $documents, tagIds: $tagIds, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class $PaymentCopyWith<$Res>  {
  factory $PaymentCopyWith(Payment value, $Res Function(Payment) _then) = _$PaymentCopyWithImpl;
@useResult
$Res call({
 String id, String number, String statusId, String typeId, String clientId, String clientContactId, String companyGatewayId, String gatewayTypeId, String projectId, String vendorId, String invitationId, String currencyId, String exchangeCurrencyId, String transactionReference, String transactionId, String privateNotes, String customValue1, String customValue2, String customValue3, String customValue4, String userId, String createdUserId, String assignedUserId, Date? date, Decimal amount, Decimal applied, Decimal refunded, Decimal exchangeRate, bool isManual, bool isDeleted, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, List<Paymentable> paymentables, List<PaymentInvoiceRef> invoices, List<PaymentCreditRef> credits, List<Document> documents, List<String> tagIds, bool isDirty
});




}
/// @nodoc
class _$PaymentCopyWithImpl<$Res>
    implements $PaymentCopyWith<$Res> {
  _$PaymentCopyWithImpl(this._self, this._then);

  final Payment _self;
  final $Res Function(Payment) _then;

/// Create a copy of Payment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? statusId = null,Object? typeId = null,Object? clientId = null,Object? clientContactId = null,Object? companyGatewayId = null,Object? gatewayTypeId = null,Object? projectId = null,Object? vendorId = null,Object? invitationId = null,Object? currencyId = null,Object? exchangeCurrencyId = null,Object? transactionReference = null,Object? transactionId = null,Object? privateNotes = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? userId = null,Object? createdUserId = null,Object? assignedUserId = null,Object? date = freezed,Object? amount = null,Object? applied = null,Object? refunded = null,Object? exchangeRate = null,Object? isManual = null,Object? isDeleted = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? paymentables = null,Object? invoices = null,Object? credits = null,Object? documents = null,Object? tagIds = null,Object? isDirty = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
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
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,createdUserId: null == createdUserId ? _self.createdUserId : createdUserId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as Date?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,applied: null == applied ? _self.applied : applied // ignore: cast_nullable_to_non_nullable
as Decimal,refunded: null == refunded ? _self.refunded : refunded // ignore: cast_nullable_to_non_nullable
as Decimal,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as Decimal,isManual: null == isManual ? _self.isManual : isManual // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,paymentables: null == paymentables ? _self.paymentables : paymentables // ignore: cast_nullable_to_non_nullable
as List<Paymentable>,invoices: null == invoices ? _self.invoices : invoices // ignore: cast_nullable_to_non_nullable
as List<PaymentInvoiceRef>,credits: null == credits ? _self.credits : credits // ignore: cast_nullable_to_non_nullable
as List<PaymentCreditRef>,documents: null == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self.tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Payment].
extension PaymentPatterns on Payment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Payment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Payment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Payment value)  $default,){
final _that = this;
switch (_that) {
case _Payment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Payment value)?  $default,){
final _that = this;
switch (_that) {
case _Payment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number,  String statusId,  String typeId,  String clientId,  String clientContactId,  String companyGatewayId,  String gatewayTypeId,  String projectId,  String vendorId,  String invitationId,  String currencyId,  String exchangeCurrencyId,  String transactionReference,  String transactionId,  String privateNotes,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  String userId,  String createdUserId,  String assignedUserId,  Date? date,  Decimal amount,  Decimal applied,  Decimal refunded,  Decimal exchangeRate,  bool isManual,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  List<Paymentable> paymentables,  List<PaymentInvoiceRef> invoices,  List<PaymentCreditRef> credits,  List<Document> documents,  List<String> tagIds,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Payment() when $default != null:
return $default(_that.id,_that.number,_that.statusId,_that.typeId,_that.clientId,_that.clientContactId,_that.companyGatewayId,_that.gatewayTypeId,_that.projectId,_that.vendorId,_that.invitationId,_that.currencyId,_that.exchangeCurrencyId,_that.transactionReference,_that.transactionId,_that.privateNotes,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.userId,_that.createdUserId,_that.assignedUserId,_that.date,_that.amount,_that.applied,_that.refunded,_that.exchangeRate,_that.isManual,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.paymentables,_that.invoices,_that.credits,_that.documents,_that.tagIds,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number,  String statusId,  String typeId,  String clientId,  String clientContactId,  String companyGatewayId,  String gatewayTypeId,  String projectId,  String vendorId,  String invitationId,  String currencyId,  String exchangeCurrencyId,  String transactionReference,  String transactionId,  String privateNotes,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  String userId,  String createdUserId,  String assignedUserId,  Date? date,  Decimal amount,  Decimal applied,  Decimal refunded,  Decimal exchangeRate,  bool isManual,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  List<Paymentable> paymentables,  List<PaymentInvoiceRef> invoices,  List<PaymentCreditRef> credits,  List<Document> documents,  List<String> tagIds,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _Payment():
return $default(_that.id,_that.number,_that.statusId,_that.typeId,_that.clientId,_that.clientContactId,_that.companyGatewayId,_that.gatewayTypeId,_that.projectId,_that.vendorId,_that.invitationId,_that.currencyId,_that.exchangeCurrencyId,_that.transactionReference,_that.transactionId,_that.privateNotes,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.userId,_that.createdUserId,_that.assignedUserId,_that.date,_that.amount,_that.applied,_that.refunded,_that.exchangeRate,_that.isManual,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.paymentables,_that.invoices,_that.credits,_that.documents,_that.tagIds,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number,  String statusId,  String typeId,  String clientId,  String clientContactId,  String companyGatewayId,  String gatewayTypeId,  String projectId,  String vendorId,  String invitationId,  String currencyId,  String exchangeCurrencyId,  String transactionReference,  String transactionId,  String privateNotes,  String customValue1,  String customValue2,  String customValue3,  String customValue4,  String userId,  String createdUserId,  String assignedUserId,  Date? date,  Decimal amount,  Decimal applied,  Decimal refunded,  Decimal exchangeRate,  bool isManual,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  List<Paymentable> paymentables,  List<PaymentInvoiceRef> invoices,  List<PaymentCreditRef> credits,  List<Document> documents,  List<String> tagIds,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _Payment() when $default != null:
return $default(_that.id,_that.number,_that.statusId,_that.typeId,_that.clientId,_that.clientContactId,_that.companyGatewayId,_that.gatewayTypeId,_that.projectId,_that.vendorId,_that.invitationId,_that.currencyId,_that.exchangeCurrencyId,_that.transactionReference,_that.transactionId,_that.privateNotes,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.userId,_that.createdUserId,_that.assignedUserId,_that.date,_that.amount,_that.applied,_that.refunded,_that.exchangeRate,_that.isManual,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.paymentables,_that.invoices,_that.credits,_that.documents,_that.tagIds,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _Payment implements Payment {
  const _Payment({required this.id, required this.number, required this.statusId, required this.typeId, required this.clientId, required this.clientContactId, required this.companyGatewayId, required this.gatewayTypeId, required this.projectId, required this.vendorId, required this.invitationId, required this.currencyId, required this.exchangeCurrencyId, required this.transactionReference, required this.transactionId, required this.privateNotes, required this.customValue1, required this.customValue2, required this.customValue3, required this.customValue4, required this.userId, required this.createdUserId, required this.assignedUserId, required this.date, required this.amount, required this.applied, required this.refunded, required this.exchangeRate, required this.isManual, required this.isDeleted, required this.updatedAt, required this.createdAt, required this.archivedAt, final  List<Paymentable> paymentables = const <Paymentable>[], final  List<PaymentInvoiceRef> invoices = const <PaymentInvoiceRef>[], final  List<PaymentCreditRef> credits = const <PaymentCreditRef>[], final  List<Document> documents = const <Document>[], final  List<String> tagIds = const <String>[], this.isDirty = false}): _paymentables = paymentables,_invoices = invoices,_credits = credits,_documents = documents,_tagIds = tagIds;
  

@override final  String id;
@override final  String number;
@override final  String statusId;
@override final  String typeId;
@override final  String clientId;
@override final  String clientContactId;
@override final  String companyGatewayId;
@override final  String gatewayTypeId;
@override final  String projectId;
@override final  String vendorId;
@override final  String invitationId;
@override final  String currencyId;
@override final  String exchangeCurrencyId;
@override final  String transactionReference;
@override final  String transactionId;
@override final  String privateNotes;
@override final  String customValue1;
@override final  String customValue2;
@override final  String customValue3;
@override final  String customValue4;
@override final  String userId;
@override final  String createdUserId;
@override final  String assignedUserId;
@override final  Date? date;
@override final  Decimal amount;
@override final  Decimal applied;
@override final  Decimal refunded;
@override final  Decimal exchangeRate;
@override final  bool isManual;
@override final  bool isDeleted;
@override final  DateTime updatedAt;
@override final  DateTime createdAt;
@override final  DateTime? archivedAt;
 final  List<Paymentable> _paymentables;
@override@JsonKey() List<Paymentable> get paymentables {
  if (_paymentables is EqualUnmodifiableListView) return _paymentables;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_paymentables);
}

 final  List<PaymentInvoiceRef> _invoices;
@override@JsonKey() List<PaymentInvoiceRef> get invoices {
  if (_invoices is EqualUnmodifiableListView) return _invoices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_invoices);
}

 final  List<PaymentCreditRef> _credits;
@override@JsonKey() List<PaymentCreditRef> get credits {
  if (_credits is EqualUnmodifiableListView) return _credits;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_credits);
}

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

@override@JsonKey() final  bool isDirty;

/// Create a copy of Payment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentCopyWith<_Payment> get copyWith => __$PaymentCopyWithImpl<_Payment>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Payment&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.clientContactId, clientContactId) || other.clientContactId == clientContactId)&&(identical(other.companyGatewayId, companyGatewayId) || other.companyGatewayId == companyGatewayId)&&(identical(other.gatewayTypeId, gatewayTypeId) || other.gatewayTypeId == gatewayTypeId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.invitationId, invitationId) || other.invitationId == invitationId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.exchangeCurrencyId, exchangeCurrencyId) || other.exchangeCurrencyId == exchangeCurrencyId)&&(identical(other.transactionReference, transactionReference) || other.transactionReference == transactionReference)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.createdUserId, createdUserId) || other.createdUserId == createdUserId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.date, date) || other.date == date)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.applied, applied) || other.applied == applied)&&(identical(other.refunded, refunded) || other.refunded == refunded)&&(identical(other.exchangeRate, exchangeRate) || other.exchangeRate == exchangeRate)&&(identical(other.isManual, isManual) || other.isManual == isManual)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other._paymentables, _paymentables)&&const DeepCollectionEquality().equals(other._invoices, _invoices)&&const DeepCollectionEquality().equals(other._credits, _credits)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._tagIds, _tagIds)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,number,statusId,typeId,clientId,clientContactId,companyGatewayId,gatewayTypeId,projectId,vendorId,invitationId,currencyId,exchangeCurrencyId,transactionReference,transactionId,privateNotes,customValue1,customValue2,customValue3,customValue4,userId,createdUserId,assignedUserId,date,amount,applied,refunded,exchangeRate,isManual,isDeleted,updatedAt,createdAt,archivedAt,const DeepCollectionEquality().hash(_paymentables),const DeepCollectionEquality().hash(_invoices),const DeepCollectionEquality().hash(_credits),const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_tagIds),isDirty]);

@override
String toString() {
  return 'Payment(id: $id, number: $number, statusId: $statusId, typeId: $typeId, clientId: $clientId, clientContactId: $clientContactId, companyGatewayId: $companyGatewayId, gatewayTypeId: $gatewayTypeId, projectId: $projectId, vendorId: $vendorId, invitationId: $invitationId, currencyId: $currencyId, exchangeCurrencyId: $exchangeCurrencyId, transactionReference: $transactionReference, transactionId: $transactionId, privateNotes: $privateNotes, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, userId: $userId, createdUserId: $createdUserId, assignedUserId: $assignedUserId, date: $date, amount: $amount, applied: $applied, refunded: $refunded, exchangeRate: $exchangeRate, isManual: $isManual, isDeleted: $isDeleted, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, paymentables: $paymentables, invoices: $invoices, credits: $credits, documents: $documents, tagIds: $tagIds, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$PaymentCopyWith<$Res> implements $PaymentCopyWith<$Res> {
  factory _$PaymentCopyWith(_Payment value, $Res Function(_Payment) _then) = __$PaymentCopyWithImpl;
@override @useResult
$Res call({
 String id, String number, String statusId, String typeId, String clientId, String clientContactId, String companyGatewayId, String gatewayTypeId, String projectId, String vendorId, String invitationId, String currencyId, String exchangeCurrencyId, String transactionReference, String transactionId, String privateNotes, String customValue1, String customValue2, String customValue3, String customValue4, String userId, String createdUserId, String assignedUserId, Date? date, Decimal amount, Decimal applied, Decimal refunded, Decimal exchangeRate, bool isManual, bool isDeleted, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, List<Paymentable> paymentables, List<PaymentInvoiceRef> invoices, List<PaymentCreditRef> credits, List<Document> documents, List<String> tagIds, bool isDirty
});




}
/// @nodoc
class __$PaymentCopyWithImpl<$Res>
    implements _$PaymentCopyWith<$Res> {
  __$PaymentCopyWithImpl(this._self, this._then);

  final _Payment _self;
  final $Res Function(_Payment) _then;

/// Create a copy of Payment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? statusId = null,Object? typeId = null,Object? clientId = null,Object? clientContactId = null,Object? companyGatewayId = null,Object? gatewayTypeId = null,Object? projectId = null,Object? vendorId = null,Object? invitationId = null,Object? currencyId = null,Object? exchangeCurrencyId = null,Object? transactionReference = null,Object? transactionId = null,Object? privateNotes = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? userId = null,Object? createdUserId = null,Object? assignedUserId = null,Object? date = freezed,Object? amount = null,Object? applied = null,Object? refunded = null,Object? exchangeRate = null,Object? isManual = null,Object? isDeleted = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? paymentables = null,Object? invoices = null,Object? credits = null,Object? documents = null,Object? tagIds = null,Object? isDirty = null,}) {
  return _then(_Payment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
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
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,createdUserId: null == createdUserId ? _self.createdUserId : createdUserId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as Date?,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,applied: null == applied ? _self.applied : applied // ignore: cast_nullable_to_non_nullable
as Decimal,refunded: null == refunded ? _self.refunded : refunded // ignore: cast_nullable_to_non_nullable
as Decimal,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate // ignore: cast_nullable_to_non_nullable
as Decimal,isManual: null == isManual ? _self.isManual : isManual // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,paymentables: null == paymentables ? _self._paymentables : paymentables // ignore: cast_nullable_to_non_nullable
as List<Paymentable>,invoices: null == invoices ? _self._invoices : invoices // ignore: cast_nullable_to_non_nullable
as List<PaymentInvoiceRef>,credits: null == credits ? _self._credits : credits // ignore: cast_nullable_to_non_nullable
as List<PaymentCreditRef>,documents: null == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<Document>,tagIds: null == tagIds ? _self._tagIds : tagIds // ignore: cast_nullable_to_non_nullable
as List<String>,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$Paymentable {

 String get id; String get invoiceId; String get creditId; Decimal get amount; Decimal get refunded; int get createdAt; int get updatedAt; int get archivedAt;
/// Create a copy of Paymentable
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentableCopyWith<Paymentable> get copyWith => _$PaymentableCopyWithImpl<Paymentable>(this as Paymentable, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Paymentable&&(identical(other.id, id) || other.id == id)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.creditId, creditId) || other.creditId == creditId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.refunded, refunded) || other.refunded == refunded)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,invoiceId,creditId,amount,refunded,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'Paymentable(id: $id, invoiceId: $invoiceId, creditId: $creditId, amount: $amount, refunded: $refunded, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class $PaymentableCopyWith<$Res>  {
  factory $PaymentableCopyWith(Paymentable value, $Res Function(Paymentable) _then) = _$PaymentableCopyWithImpl;
@useResult
$Res call({
 String id, String invoiceId, String creditId, Decimal amount, Decimal refunded, int createdAt, int updatedAt, int archivedAt
});




}
/// @nodoc
class _$PaymentableCopyWithImpl<$Res>
    implements $PaymentableCopyWith<$Res> {
  _$PaymentableCopyWithImpl(this._self, this._then);

  final Paymentable _self;
  final $Res Function(Paymentable) _then;

/// Create a copy of Paymentable
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? invoiceId = null,Object? creditId = null,Object? amount = null,Object? refunded = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,creditId: null == creditId ? _self.creditId : creditId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,refunded: null == refunded ? _self.refunded : refunded // ignore: cast_nullable_to_non_nullable
as Decimal,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Paymentable].
extension PaymentablePatterns on Paymentable {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Paymentable value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Paymentable() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Paymentable value)  $default,){
final _that = this;
switch (_that) {
case _Paymentable():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Paymentable value)?  $default,){
final _that = this;
switch (_that) {
case _Paymentable() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String invoiceId,  String creditId,  Decimal amount,  Decimal refunded,  int createdAt,  int updatedAt,  int archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Paymentable() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String invoiceId,  String creditId,  Decimal amount,  Decimal refunded,  int createdAt,  int updatedAt,  int archivedAt)  $default,) {final _that = this;
switch (_that) {
case _Paymentable():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String invoiceId,  String creditId,  Decimal amount,  Decimal refunded,  int createdAt,  int updatedAt,  int archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _Paymentable() when $default != null:
return $default(_that.id,_that.invoiceId,_that.creditId,_that.amount,_that.refunded,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Paymentable implements Paymentable {
  const _Paymentable({this.id = '', this.invoiceId = '', this.creditId = '', required this.amount, required this.refunded, this.createdAt = 0, this.updatedAt = 0, this.archivedAt = 0});
  

@override@JsonKey() final  String id;
@override@JsonKey() final  String invoiceId;
@override@JsonKey() final  String creditId;
@override final  Decimal amount;
@override final  Decimal refunded;
@override@JsonKey() final  int createdAt;
@override@JsonKey() final  int updatedAt;
@override@JsonKey() final  int archivedAt;

/// Create a copy of Paymentable
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentableCopyWith<_Paymentable> get copyWith => __$PaymentableCopyWithImpl<_Paymentable>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Paymentable&&(identical(other.id, id) || other.id == id)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.creditId, creditId) || other.creditId == creditId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.refunded, refunded) || other.refunded == refunded)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,invoiceId,creditId,amount,refunded,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'Paymentable(id: $id, invoiceId: $invoiceId, creditId: $creditId, amount: $amount, refunded: $refunded, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$PaymentableCopyWith<$Res> implements $PaymentableCopyWith<$Res> {
  factory _$PaymentableCopyWith(_Paymentable value, $Res Function(_Paymentable) _then) = __$PaymentableCopyWithImpl;
@override @useResult
$Res call({
 String id, String invoiceId, String creditId, Decimal amount, Decimal refunded, int createdAt, int updatedAt, int archivedAt
});




}
/// @nodoc
class __$PaymentableCopyWithImpl<$Res>
    implements _$PaymentableCopyWith<$Res> {
  __$PaymentableCopyWithImpl(this._self, this._then);

  final _Paymentable _self;
  final $Res Function(_Paymentable) _then;

/// Create a copy of Paymentable
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? invoiceId = null,Object? creditId = null,Object? amount = null,Object? refunded = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_Paymentable(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,creditId: null == creditId ? _self.creditId : creditId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,refunded: null == refunded ? _self.refunded : refunded // ignore: cast_nullable_to_non_nullable
as Decimal,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$PaymentInvoiceRef {

 String get id; String get number; Decimal get amount; Decimal get balance; Decimal get paidToDate;
/// Create a copy of PaymentInvoiceRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentInvoiceRefCopyWith<PaymentInvoiceRef> get copyWith => _$PaymentInvoiceRefCopyWithImpl<PaymentInvoiceRef>(this as PaymentInvoiceRef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentInvoiceRef&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.paidToDate, paidToDate) || other.paidToDate == paidToDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,number,amount,balance,paidToDate);

@override
String toString() {
  return 'PaymentInvoiceRef(id: $id, number: $number, amount: $amount, balance: $balance, paidToDate: $paidToDate)';
}


}

/// @nodoc
abstract mixin class $PaymentInvoiceRefCopyWith<$Res>  {
  factory $PaymentInvoiceRefCopyWith(PaymentInvoiceRef value, $Res Function(PaymentInvoiceRef) _then) = _$PaymentInvoiceRefCopyWithImpl;
@useResult
$Res call({
 String id, String number, Decimal amount, Decimal balance, Decimal paidToDate
});




}
/// @nodoc
class _$PaymentInvoiceRefCopyWithImpl<$Res>
    implements $PaymentInvoiceRefCopyWith<$Res> {
  _$PaymentInvoiceRefCopyWithImpl(this._self, this._then);

  final PaymentInvoiceRef _self;
  final $Res Function(PaymentInvoiceRef) _then;

/// Create a copy of PaymentInvoiceRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? amount = null,Object? balance = null,Object? paidToDate = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as Decimal,paidToDate: null == paidToDate ? _self.paidToDate : paidToDate // ignore: cast_nullable_to_non_nullable
as Decimal,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentInvoiceRef].
extension PaymentInvoiceRefPatterns on PaymentInvoiceRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentInvoiceRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentInvoiceRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentInvoiceRef value)  $default,){
final _that = this;
switch (_that) {
case _PaymentInvoiceRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentInvoiceRef value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentInvoiceRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number,  Decimal amount,  Decimal balance,  Decimal paidToDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentInvoiceRef() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number,  Decimal amount,  Decimal balance,  Decimal paidToDate)  $default,) {final _that = this;
switch (_that) {
case _PaymentInvoiceRef():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number,  Decimal amount,  Decimal balance,  Decimal paidToDate)?  $default,) {final _that = this;
switch (_that) {
case _PaymentInvoiceRef() when $default != null:
return $default(_that.id,_that.number,_that.amount,_that.balance,_that.paidToDate);case _:
  return null;

}
}

}

/// @nodoc


class _PaymentInvoiceRef implements PaymentInvoiceRef {
  const _PaymentInvoiceRef({this.id = '', this.number = '', required this.amount, required this.balance, required this.paidToDate});
  

@override@JsonKey() final  String id;
@override@JsonKey() final  String number;
@override final  Decimal amount;
@override final  Decimal balance;
@override final  Decimal paidToDate;

/// Create a copy of PaymentInvoiceRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentInvoiceRefCopyWith<_PaymentInvoiceRef> get copyWith => __$PaymentInvoiceRefCopyWithImpl<_PaymentInvoiceRef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentInvoiceRef&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.paidToDate, paidToDate) || other.paidToDate == paidToDate));
}


@override
int get hashCode => Object.hash(runtimeType,id,number,amount,balance,paidToDate);

@override
String toString() {
  return 'PaymentInvoiceRef(id: $id, number: $number, amount: $amount, balance: $balance, paidToDate: $paidToDate)';
}


}

/// @nodoc
abstract mixin class _$PaymentInvoiceRefCopyWith<$Res> implements $PaymentInvoiceRefCopyWith<$Res> {
  factory _$PaymentInvoiceRefCopyWith(_PaymentInvoiceRef value, $Res Function(_PaymentInvoiceRef) _then) = __$PaymentInvoiceRefCopyWithImpl;
@override @useResult
$Res call({
 String id, String number, Decimal amount, Decimal balance, Decimal paidToDate
});




}
/// @nodoc
class __$PaymentInvoiceRefCopyWithImpl<$Res>
    implements _$PaymentInvoiceRefCopyWith<$Res> {
  __$PaymentInvoiceRefCopyWithImpl(this._self, this._then);

  final _PaymentInvoiceRef _self;
  final $Res Function(_PaymentInvoiceRef) _then;

/// Create a copy of PaymentInvoiceRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? amount = null,Object? balance = null,Object? paidToDate = null,}) {
  return _then(_PaymentInvoiceRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as Decimal,paidToDate: null == paidToDate ? _self.paidToDate : paidToDate // ignore: cast_nullable_to_non_nullable
as Decimal,
  ));
}


}

/// @nodoc
mixin _$PaymentCreditRef {

 String get id; String get number; Decimal get amount; Decimal get balance;
/// Create a copy of PaymentCreditRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentCreditRefCopyWith<PaymentCreditRef> get copyWith => _$PaymentCreditRefCopyWithImpl<PaymentCreditRef>(this as PaymentCreditRef, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentCreditRef&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.balance, balance) || other.balance == balance));
}


@override
int get hashCode => Object.hash(runtimeType,id,number,amount,balance);

@override
String toString() {
  return 'PaymentCreditRef(id: $id, number: $number, amount: $amount, balance: $balance)';
}


}

/// @nodoc
abstract mixin class $PaymentCreditRefCopyWith<$Res>  {
  factory $PaymentCreditRefCopyWith(PaymentCreditRef value, $Res Function(PaymentCreditRef) _then) = _$PaymentCreditRefCopyWithImpl;
@useResult
$Res call({
 String id, String number, Decimal amount, Decimal balance
});




}
/// @nodoc
class _$PaymentCreditRefCopyWithImpl<$Res>
    implements $PaymentCreditRefCopyWith<$Res> {
  _$PaymentCreditRefCopyWithImpl(this._self, this._then);

  final PaymentCreditRef _self;
  final $Res Function(PaymentCreditRef) _then;

/// Create a copy of PaymentCreditRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? number = null,Object? amount = null,Object? balance = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as Decimal,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentCreditRef].
extension PaymentCreditRefPatterns on PaymentCreditRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentCreditRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentCreditRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentCreditRef value)  $default,){
final _that = this;
switch (_that) {
case _PaymentCreditRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentCreditRef value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentCreditRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String number,  Decimal amount,  Decimal balance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentCreditRef() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String number,  Decimal amount,  Decimal balance)  $default,) {final _that = this;
switch (_that) {
case _PaymentCreditRef():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String number,  Decimal amount,  Decimal balance)?  $default,) {final _that = this;
switch (_that) {
case _PaymentCreditRef() when $default != null:
return $default(_that.id,_that.number,_that.amount,_that.balance);case _:
  return null;

}
}

}

/// @nodoc


class _PaymentCreditRef implements PaymentCreditRef {
  const _PaymentCreditRef({this.id = '', this.number = '', required this.amount, required this.balance});
  

@override@JsonKey() final  String id;
@override@JsonKey() final  String number;
@override final  Decimal amount;
@override final  Decimal balance;

/// Create a copy of PaymentCreditRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentCreditRefCopyWith<_PaymentCreditRef> get copyWith => __$PaymentCreditRefCopyWithImpl<_PaymentCreditRef>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentCreditRef&&(identical(other.id, id) || other.id == id)&&(identical(other.number, number) || other.number == number)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.balance, balance) || other.balance == balance));
}


@override
int get hashCode => Object.hash(runtimeType,id,number,amount,balance);

@override
String toString() {
  return 'PaymentCreditRef(id: $id, number: $number, amount: $amount, balance: $balance)';
}


}

/// @nodoc
abstract mixin class _$PaymentCreditRefCopyWith<$Res> implements $PaymentCreditRefCopyWith<$Res> {
  factory _$PaymentCreditRefCopyWith(_PaymentCreditRef value, $Res Function(_PaymentCreditRef) _then) = __$PaymentCreditRefCopyWithImpl;
@override @useResult
$Res call({
 String id, String number, Decimal amount, Decimal balance
});




}
/// @nodoc
class __$PaymentCreditRefCopyWithImpl<$Res>
    implements _$PaymentCreditRefCopyWith<$Res> {
  __$PaymentCreditRefCopyWithImpl(this._self, this._then);

  final _PaymentCreditRef _self;
  final $Res Function(_PaymentCreditRef) _then;

/// Create a copy of PaymentCreditRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? number = null,Object? amount = null,Object? balance = null,}) {
  return _then(_PaymentCreditRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,balance: null == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as Decimal,
  ));
}


}

// dart format on
