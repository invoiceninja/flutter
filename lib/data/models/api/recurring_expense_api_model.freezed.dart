// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recurring_expense_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RecurringExpenseApi {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'assigned_user_id') String get assignedUserId;@JsonKey(name: 'vendor_id') String get vendorId;@JsonKey(name: 'invoice_id') String get invoiceId;@JsonKey(name: 'client_id') String get clientId;@JsonKey(name: 'bank_id') String get bankId;@JsonKey(name: 'invoice_currency_id') String get invoiceCurrencyId;@JsonKey(name: 'expense_currency_id') String get expenseCurrencyId;@JsonKey(name: 'currency_id') String get currencyId;@JsonKey(name: 'category_id') String get categoryId;@JsonKey(name: 'payment_type_id') String get paymentTypeId;@JsonKey(name: 'recurring_expense_id') String get recurringExpenseId;@JsonKey(name: 'private_notes') String get privateNotes;@JsonKey(name: 'public_notes') String get publicNotes;@JsonKey(name: 'transaction_reference') String get transactionReference;@JsonKey(name: 'transaction_id') String get transactionId; String get date; String get number;@JsonKey(name: 'payment_date') String get paymentDate;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;@JsonKey(name: 'tax_name1') String get taxName1;@JsonKey(name: 'tax_name2') String get taxName2;@JsonKey(name: 'tax_name3') String get taxName3;@JsonKey(name: 'project_id') String get projectId;@JsonKey(name: 'entity_type') String get entityType;// Recurring schedule deltas.
@JsonKey(name: 'frequency_id') String get frequencyId;@JsonKey(name: 'remaining_cycles') int get remainingCycles;@JsonKey(name: 'next_send_date') String get nextSendDate;@JsonKey(name: 'last_sent_date') String get lastSentDate;@JsonKey(name: 'status_id') String? get statusId;// Only populated when the server replies with `?show_dates=true`.
@JsonKey(name: 'recurring_dates') List<RecurringDateApi>? get recurringDates;// Money — Object so number / string are both decoded.
 Object get amount;@JsonKey(name: 'foreign_amount') Object get foreignAmount;@JsonKey(name: 'exchange_rate') Object get exchangeRate;@JsonKey(name: 'tax_amount1') Object get taxAmount1;@JsonKey(name: 'tax_amount2') Object get taxAmount2;@JsonKey(name: 'tax_amount3') Object get taxAmount3;@JsonKey(name: 'tax_rate1') Object get taxRate1;@JsonKey(name: 'tax_rate2') Object get taxRate2;@JsonKey(name: 'tax_rate3') Object get taxRate3;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'should_be_invoiced') bool get shouldBeInvoiced;@JsonKey(name: 'invoice_documents') bool get invoiceDocuments;@JsonKey(name: 'uses_inclusive_taxes') bool get usesInclusiveTaxes;@JsonKey(name: 'calculate_tax_by_amount') bool get calculateTaxByAmount;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt; List<DocumentApi>? get documents;@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags;
/// Create a copy of RecurringExpenseApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecurringExpenseApiCopyWith<RecurringExpenseApi> get copyWith => _$RecurringExpenseApiCopyWithImpl<RecurringExpenseApi>(this as RecurringExpenseApi, _$identity);

  /// Serializes this RecurringExpenseApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecurringExpenseApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.invoiceCurrencyId, invoiceCurrencyId) || other.invoiceCurrencyId == invoiceCurrencyId)&&(identical(other.expenseCurrencyId, expenseCurrencyId) || other.expenseCurrencyId == expenseCurrencyId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.paymentTypeId, paymentTypeId) || other.paymentTypeId == paymentTypeId)&&(identical(other.recurringExpenseId, recurringExpenseId) || other.recurringExpenseId == recurringExpenseId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.transactionReference, transactionReference) || other.transactionReference == transactionReference)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.date, date) || other.date == date)&&(identical(other.number, number) || other.number == number)&&(identical(other.paymentDate, paymentDate) || other.paymentDate == paymentDate)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.entityType, entityType) || other.entityType == entityType)&&(identical(other.frequencyId, frequencyId) || other.frequencyId == frequencyId)&&(identical(other.remainingCycles, remainingCycles) || other.remainingCycles == remainingCycles)&&(identical(other.nextSendDate, nextSendDate) || other.nextSendDate == nextSendDate)&&(identical(other.lastSentDate, lastSentDate) || other.lastSentDate == lastSentDate)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&const DeepCollectionEquality().equals(other.recurringDates, recurringDates)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.foreignAmount, foreignAmount)&&const DeepCollectionEquality().equals(other.exchangeRate, exchangeRate)&&const DeepCollectionEquality().equals(other.taxAmount1, taxAmount1)&&const DeepCollectionEquality().equals(other.taxAmount2, taxAmount2)&&const DeepCollectionEquality().equals(other.taxAmount3, taxAmount3)&&const DeepCollectionEquality().equals(other.taxRate1, taxRate1)&&const DeepCollectionEquality().equals(other.taxRate2, taxRate2)&&const DeepCollectionEquality().equals(other.taxRate3, taxRate3)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.shouldBeInvoiced, shouldBeInvoiced) || other.shouldBeInvoiced == shouldBeInvoiced)&&(identical(other.invoiceDocuments, invoiceDocuments) || other.invoiceDocuments == invoiceDocuments)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&(identical(other.calculateTaxByAmount, calculateTaxByAmount) || other.calculateTaxByAmount == calculateTaxByAmount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other.documents, documents)&&const DeepCollectionEquality().equals(other.tags, tags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,vendorId,invoiceId,clientId,bankId,invoiceCurrencyId,expenseCurrencyId,currencyId,categoryId,paymentTypeId,recurringExpenseId,privateNotes,publicNotes,transactionReference,transactionId,date,number,paymentDate,customValue1,customValue2,customValue3,customValue4,taxName1,taxName2,taxName3,projectId,entityType,frequencyId,remainingCycles,nextSendDate,lastSentDate,statusId,const DeepCollectionEquality().hash(recurringDates),const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(foreignAmount),const DeepCollectionEquality().hash(exchangeRate),const DeepCollectionEquality().hash(taxAmount1),const DeepCollectionEquality().hash(taxAmount2),const DeepCollectionEquality().hash(taxAmount3),const DeepCollectionEquality().hash(taxRate1),const DeepCollectionEquality().hash(taxRate2),const DeepCollectionEquality().hash(taxRate3),isDeleted,shouldBeInvoiced,invoiceDocuments,usesInclusiveTaxes,calculateTaxByAmount,createdAt,updatedAt,archivedAt,const DeepCollectionEquality().hash(documents),const DeepCollectionEquality().hash(tags)]);

@override
String toString() {
  return 'RecurringExpenseApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, vendorId: $vendorId, invoiceId: $invoiceId, clientId: $clientId, bankId: $bankId, invoiceCurrencyId: $invoiceCurrencyId, expenseCurrencyId: $expenseCurrencyId, currencyId: $currencyId, categoryId: $categoryId, paymentTypeId: $paymentTypeId, recurringExpenseId: $recurringExpenseId, privateNotes: $privateNotes, publicNotes: $publicNotes, transactionReference: $transactionReference, transactionId: $transactionId, date: $date, number: $number, paymentDate: $paymentDate, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, projectId: $projectId, entityType: $entityType, frequencyId: $frequencyId, remainingCycles: $remainingCycles, nextSendDate: $nextSendDate, lastSentDate: $lastSentDate, statusId: $statusId, recurringDates: $recurringDates, amount: $amount, foreignAmount: $foreignAmount, exchangeRate: $exchangeRate, taxAmount1: $taxAmount1, taxAmount2: $taxAmount2, taxAmount3: $taxAmount3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, isDeleted: $isDeleted, shouldBeInvoiced: $shouldBeInvoiced, invoiceDocuments: $invoiceDocuments, usesInclusiveTaxes: $usesInclusiveTaxes, calculateTaxByAmount: $calculateTaxByAmount, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, documents: $documents, tags: $tags)';
}


}

/// @nodoc
abstract mixin class $RecurringExpenseApiCopyWith<$Res>  {
  factory $RecurringExpenseApiCopyWith(RecurringExpenseApi value, $Res Function(RecurringExpenseApi) _then) = _$RecurringExpenseApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'invoice_id') String invoiceId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'bank_id') String bankId,@JsonKey(name: 'invoice_currency_id') String invoiceCurrencyId,@JsonKey(name: 'expense_currency_id') String expenseCurrencyId,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'category_id') String categoryId,@JsonKey(name: 'payment_type_id') String paymentTypeId,@JsonKey(name: 'recurring_expense_id') String recurringExpenseId,@JsonKey(name: 'private_notes') String privateNotes,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'transaction_reference') String transactionReference,@JsonKey(name: 'transaction_id') String transactionId, String date, String number,@JsonKey(name: 'payment_date') String paymentDate,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'tax_name1') String taxName1,@JsonKey(name: 'tax_name2') String taxName2,@JsonKey(name: 'tax_name3') String taxName3,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'entity_type') String entityType,@JsonKey(name: 'frequency_id') String frequencyId,@JsonKey(name: 'remaining_cycles') int remainingCycles,@JsonKey(name: 'next_send_date') String nextSendDate,@JsonKey(name: 'last_sent_date') String lastSentDate,@JsonKey(name: 'status_id') String? statusId,@JsonKey(name: 'recurring_dates') List<RecurringDateApi>? recurringDates, Object amount,@JsonKey(name: 'foreign_amount') Object foreignAmount,@JsonKey(name: 'exchange_rate') Object exchangeRate,@JsonKey(name: 'tax_amount1') Object taxAmount1,@JsonKey(name: 'tax_amount2') Object taxAmount2,@JsonKey(name: 'tax_amount3') Object taxAmount3,@JsonKey(name: 'tax_rate1') Object taxRate1,@JsonKey(name: 'tax_rate2') Object taxRate2,@JsonKey(name: 'tax_rate3') Object taxRate3,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'should_be_invoiced') bool shouldBeInvoiced,@JsonKey(name: 'invoice_documents') bool invoiceDocuments,@JsonKey(name: 'uses_inclusive_taxes') bool usesInclusiveTaxes,@JsonKey(name: 'calculate_tax_by_amount') bool calculateTaxByAmount,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt, List<DocumentApi>? documents,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags
});




}
/// @nodoc
class _$RecurringExpenseApiCopyWithImpl<$Res>
    implements $RecurringExpenseApiCopyWith<$Res> {
  _$RecurringExpenseApiCopyWithImpl(this._self, this._then);

  final RecurringExpenseApi _self;
  final $Res Function(RecurringExpenseApi) _then;

/// Create a copy of RecurringExpenseApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? vendorId = null,Object? invoiceId = null,Object? clientId = null,Object? bankId = null,Object? invoiceCurrencyId = null,Object? expenseCurrencyId = null,Object? currencyId = null,Object? categoryId = null,Object? paymentTypeId = null,Object? recurringExpenseId = null,Object? privateNotes = null,Object? publicNotes = null,Object? transactionReference = null,Object? transactionId = null,Object? date = null,Object? number = null,Object? paymentDate = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? projectId = null,Object? entityType = null,Object? frequencyId = null,Object? remainingCycles = null,Object? nextSendDate = null,Object? lastSentDate = null,Object? statusId = freezed,Object? recurringDates = freezed,Object? amount = null,Object? foreignAmount = null,Object? exchangeRate = null,Object? taxAmount1 = null,Object? taxAmount2 = null,Object? taxAmount3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? isDeleted = null,Object? shouldBeInvoiced = null,Object? invoiceDocuments = null,Object? usesInclusiveTaxes = null,Object? calculateTaxByAmount = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? documents = freezed,Object? tags = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,bankId: null == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as String,invoiceCurrencyId: null == invoiceCurrencyId ? _self.invoiceCurrencyId : invoiceCurrencyId // ignore: cast_nullable_to_non_nullable
as String,expenseCurrencyId: null == expenseCurrencyId ? _self.expenseCurrencyId : expenseCurrencyId // ignore: cast_nullable_to_non_nullable
as String,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,paymentTypeId: null == paymentTypeId ? _self.paymentTypeId : paymentTypeId // ignore: cast_nullable_to_non_nullable
as String,recurringExpenseId: null == recurringExpenseId ? _self.recurringExpenseId : recurringExpenseId // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,transactionReference: null == transactionReference ? _self.transactionReference : transactionReference // ignore: cast_nullable_to_non_nullable
as String,transactionId: null == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,paymentDate: null == paymentDate ? _self.paymentDate : paymentDate // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,entityType: null == entityType ? _self.entityType : entityType // ignore: cast_nullable_to_non_nullable
as String,frequencyId: null == frequencyId ? _self.frequencyId : frequencyId // ignore: cast_nullable_to_non_nullable
as String,remainingCycles: null == remainingCycles ? _self.remainingCycles : remainingCycles // ignore: cast_nullable_to_non_nullable
as int,nextSendDate: null == nextSendDate ? _self.nextSendDate : nextSendDate // ignore: cast_nullable_to_non_nullable
as String,lastSentDate: null == lastSentDate ? _self.lastSentDate : lastSentDate // ignore: cast_nullable_to_non_nullable
as String,statusId: freezed == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String?,recurringDates: freezed == recurringDates ? _self.recurringDates : recurringDates // ignore: cast_nullable_to_non_nullable
as List<RecurringDateApi>?,amount: null == amount ? _self.amount : amount ,foreignAmount: null == foreignAmount ? _self.foreignAmount : foreignAmount ,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate ,taxAmount1: null == taxAmount1 ? _self.taxAmount1 : taxAmount1 ,taxAmount2: null == taxAmount2 ? _self.taxAmount2 : taxAmount2 ,taxAmount3: null == taxAmount3 ? _self.taxAmount3 : taxAmount3 ,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 ,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 ,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 ,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,shouldBeInvoiced: null == shouldBeInvoiced ? _self.shouldBeInvoiced : shouldBeInvoiced // ignore: cast_nullable_to_non_nullable
as bool,invoiceDocuments: null == invoiceDocuments ? _self.invoiceDocuments : invoiceDocuments // ignore: cast_nullable_to_non_nullable
as bool,usesInclusiveTaxes: null == usesInclusiveTaxes ? _self.usesInclusiveTaxes : usesInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,calculateTaxByAmount: null == calculateTaxByAmount ? _self.calculateTaxByAmount : calculateTaxByAmount // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,documents: freezed == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [RecurringExpenseApi].
extension RecurringExpenseApiPatterns on RecurringExpenseApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecurringExpenseApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecurringExpenseApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecurringExpenseApi value)  $default,){
final _that = this;
switch (_that) {
case _RecurringExpenseApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecurringExpenseApi value)?  $default,){
final _that = this;
switch (_that) {
case _RecurringExpenseApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'invoice_id')  String invoiceId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'bank_id')  String bankId, @JsonKey(name: 'invoice_currency_id')  String invoiceCurrencyId, @JsonKey(name: 'expense_currency_id')  String expenseCurrencyId, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'category_id')  String categoryId, @JsonKey(name: 'payment_type_id')  String paymentTypeId, @JsonKey(name: 'recurring_expense_id')  String recurringExpenseId, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'transaction_reference')  String transactionReference, @JsonKey(name: 'transaction_id')  String transactionId,  String date,  String number, @JsonKey(name: 'payment_date')  String paymentDate, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'entity_type')  String entityType, @JsonKey(name: 'frequency_id')  String frequencyId, @JsonKey(name: 'remaining_cycles')  int remainingCycles, @JsonKey(name: 'next_send_date')  String nextSendDate, @JsonKey(name: 'last_sent_date')  String lastSentDate, @JsonKey(name: 'status_id')  String? statusId, @JsonKey(name: 'recurring_dates')  List<RecurringDateApi>? recurringDates,  Object amount, @JsonKey(name: 'foreign_amount')  Object foreignAmount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_amount1')  Object taxAmount1, @JsonKey(name: 'tax_amount2')  Object taxAmount2, @JsonKey(name: 'tax_amount3')  Object taxAmount3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'should_be_invoiced')  bool shouldBeInvoiced, @JsonKey(name: 'invoice_documents')  bool invoiceDocuments, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'calculate_tax_by_amount')  bool calculateTaxByAmount, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecurringExpenseApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.vendorId,_that.invoiceId,_that.clientId,_that.bankId,_that.invoiceCurrencyId,_that.expenseCurrencyId,_that.currencyId,_that.categoryId,_that.paymentTypeId,_that.recurringExpenseId,_that.privateNotes,_that.publicNotes,_that.transactionReference,_that.transactionId,_that.date,_that.number,_that.paymentDate,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.taxName1,_that.taxName2,_that.taxName3,_that.projectId,_that.entityType,_that.frequencyId,_that.remainingCycles,_that.nextSendDate,_that.lastSentDate,_that.statusId,_that.recurringDates,_that.amount,_that.foreignAmount,_that.exchangeRate,_that.taxAmount1,_that.taxAmount2,_that.taxAmount3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.isDeleted,_that.shouldBeInvoiced,_that.invoiceDocuments,_that.usesInclusiveTaxes,_that.calculateTaxByAmount,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.documents,_that.tags);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'invoice_id')  String invoiceId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'bank_id')  String bankId, @JsonKey(name: 'invoice_currency_id')  String invoiceCurrencyId, @JsonKey(name: 'expense_currency_id')  String expenseCurrencyId, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'category_id')  String categoryId, @JsonKey(name: 'payment_type_id')  String paymentTypeId, @JsonKey(name: 'recurring_expense_id')  String recurringExpenseId, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'transaction_reference')  String transactionReference, @JsonKey(name: 'transaction_id')  String transactionId,  String date,  String number, @JsonKey(name: 'payment_date')  String paymentDate, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'entity_type')  String entityType, @JsonKey(name: 'frequency_id')  String frequencyId, @JsonKey(name: 'remaining_cycles')  int remainingCycles, @JsonKey(name: 'next_send_date')  String nextSendDate, @JsonKey(name: 'last_sent_date')  String lastSentDate, @JsonKey(name: 'status_id')  String? statusId, @JsonKey(name: 'recurring_dates')  List<RecurringDateApi>? recurringDates,  Object amount, @JsonKey(name: 'foreign_amount')  Object foreignAmount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_amount1')  Object taxAmount1, @JsonKey(name: 'tax_amount2')  Object taxAmount2, @JsonKey(name: 'tax_amount3')  Object taxAmount3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'should_be_invoiced')  bool shouldBeInvoiced, @JsonKey(name: 'invoice_documents')  bool invoiceDocuments, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'calculate_tax_by_amount')  bool calculateTaxByAmount, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags)  $default,) {final _that = this;
switch (_that) {
case _RecurringExpenseApi():
return $default(_that.id,_that.userId,_that.assignedUserId,_that.vendorId,_that.invoiceId,_that.clientId,_that.bankId,_that.invoiceCurrencyId,_that.expenseCurrencyId,_that.currencyId,_that.categoryId,_that.paymentTypeId,_that.recurringExpenseId,_that.privateNotes,_that.publicNotes,_that.transactionReference,_that.transactionId,_that.date,_that.number,_that.paymentDate,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.taxName1,_that.taxName2,_that.taxName3,_that.projectId,_that.entityType,_that.frequencyId,_that.remainingCycles,_that.nextSendDate,_that.lastSentDate,_that.statusId,_that.recurringDates,_that.amount,_that.foreignAmount,_that.exchangeRate,_that.taxAmount1,_that.taxAmount2,_that.taxAmount3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.isDeleted,_that.shouldBeInvoiced,_that.invoiceDocuments,_that.usesInclusiveTaxes,_that.calculateTaxByAmount,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.documents,_that.tags);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'invoice_id')  String invoiceId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'bank_id')  String bankId, @JsonKey(name: 'invoice_currency_id')  String invoiceCurrencyId, @JsonKey(name: 'expense_currency_id')  String expenseCurrencyId, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'category_id')  String categoryId, @JsonKey(name: 'payment_type_id')  String paymentTypeId, @JsonKey(name: 'recurring_expense_id')  String recurringExpenseId, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'transaction_reference')  String transactionReference, @JsonKey(name: 'transaction_id')  String transactionId,  String date,  String number, @JsonKey(name: 'payment_date')  String paymentDate, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'entity_type')  String entityType, @JsonKey(name: 'frequency_id')  String frequencyId, @JsonKey(name: 'remaining_cycles')  int remainingCycles, @JsonKey(name: 'next_send_date')  String nextSendDate, @JsonKey(name: 'last_sent_date')  String lastSentDate, @JsonKey(name: 'status_id')  String? statusId, @JsonKey(name: 'recurring_dates')  List<RecurringDateApi>? recurringDates,  Object amount, @JsonKey(name: 'foreign_amount')  Object foreignAmount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_amount1')  Object taxAmount1, @JsonKey(name: 'tax_amount2')  Object taxAmount2, @JsonKey(name: 'tax_amount3')  Object taxAmount3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'should_be_invoiced')  bool shouldBeInvoiced, @JsonKey(name: 'invoice_documents')  bool invoiceDocuments, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'calculate_tax_by_amount')  bool calculateTaxByAmount, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags)?  $default,) {final _that = this;
switch (_that) {
case _RecurringExpenseApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.vendorId,_that.invoiceId,_that.clientId,_that.bankId,_that.invoiceCurrencyId,_that.expenseCurrencyId,_that.currencyId,_that.categoryId,_that.paymentTypeId,_that.recurringExpenseId,_that.privateNotes,_that.publicNotes,_that.transactionReference,_that.transactionId,_that.date,_that.number,_that.paymentDate,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.taxName1,_that.taxName2,_that.taxName3,_that.projectId,_that.entityType,_that.frequencyId,_that.remainingCycles,_that.nextSendDate,_that.lastSentDate,_that.statusId,_that.recurringDates,_that.amount,_that.foreignAmount,_that.exchangeRate,_that.taxAmount1,_that.taxAmount2,_that.taxAmount3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.isDeleted,_that.shouldBeInvoiced,_that.invoiceDocuments,_that.usesInclusiveTaxes,_that.calculateTaxByAmount,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.documents,_that.tags);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RecurringExpenseApi implements RecurringExpenseApi {
  const _RecurringExpenseApi({this.id = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', @JsonKey(name: 'vendor_id') this.vendorId = '', @JsonKey(name: 'invoice_id') this.invoiceId = '', @JsonKey(name: 'client_id') this.clientId = '', @JsonKey(name: 'bank_id') this.bankId = '', @JsonKey(name: 'invoice_currency_id') this.invoiceCurrencyId = '', @JsonKey(name: 'expense_currency_id') this.expenseCurrencyId = '', @JsonKey(name: 'currency_id') this.currencyId = '', @JsonKey(name: 'category_id') this.categoryId = '', @JsonKey(name: 'payment_type_id') this.paymentTypeId = '', @JsonKey(name: 'recurring_expense_id') this.recurringExpenseId = '', @JsonKey(name: 'private_notes') this.privateNotes = '', @JsonKey(name: 'public_notes') this.publicNotes = '', @JsonKey(name: 'transaction_reference') this.transactionReference = '', @JsonKey(name: 'transaction_id') this.transactionId = '', this.date = '', this.number = '', @JsonKey(name: 'payment_date') this.paymentDate = '', @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'tax_name1') this.taxName1 = '', @JsonKey(name: 'tax_name2') this.taxName2 = '', @JsonKey(name: 'tax_name3') this.taxName3 = '', @JsonKey(name: 'project_id') this.projectId = '', @JsonKey(name: 'entity_type') this.entityType = '', @JsonKey(name: 'frequency_id') this.frequencyId = '5', @JsonKey(name: 'remaining_cycles') this.remainingCycles = -1, @JsonKey(name: 'next_send_date') this.nextSendDate = '', @JsonKey(name: 'last_sent_date') this.lastSentDate = '', @JsonKey(name: 'status_id') this.statusId, @JsonKey(name: 'recurring_dates') final  List<RecurringDateApi>? recurringDates, this.amount = '0', @JsonKey(name: 'foreign_amount') this.foreignAmount = '0', @JsonKey(name: 'exchange_rate') this.exchangeRate = '1', @JsonKey(name: 'tax_amount1') this.taxAmount1 = '0', @JsonKey(name: 'tax_amount2') this.taxAmount2 = '0', @JsonKey(name: 'tax_amount3') this.taxAmount3 = '0', @JsonKey(name: 'tax_rate1') this.taxRate1 = '0', @JsonKey(name: 'tax_rate2') this.taxRate2 = '0', @JsonKey(name: 'tax_rate3') this.taxRate3 = '0', @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'should_be_invoiced') this.shouldBeInvoiced = false, @JsonKey(name: 'invoice_documents') this.invoiceDocuments = false, @JsonKey(name: 'uses_inclusive_taxes') this.usesInclusiveTaxes = false, @JsonKey(name: 'calculate_tax_by_amount') this.calculateTaxByAmount = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, final  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter() final  List<TagRefApi> tags = const <TagRefApi>[]}): _recurringDates = recurringDates,_documents = documents,_tags = tags;
  factory _RecurringExpenseApi.fromJson(Map<String, dynamic> json) => _$RecurringExpenseApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'assigned_user_id') final  String assignedUserId;
@override@JsonKey(name: 'vendor_id') final  String vendorId;
@override@JsonKey(name: 'invoice_id') final  String invoiceId;
@override@JsonKey(name: 'client_id') final  String clientId;
@override@JsonKey(name: 'bank_id') final  String bankId;
@override@JsonKey(name: 'invoice_currency_id') final  String invoiceCurrencyId;
@override@JsonKey(name: 'expense_currency_id') final  String expenseCurrencyId;
@override@JsonKey(name: 'currency_id') final  String currencyId;
@override@JsonKey(name: 'category_id') final  String categoryId;
@override@JsonKey(name: 'payment_type_id') final  String paymentTypeId;
@override@JsonKey(name: 'recurring_expense_id') final  String recurringExpenseId;
@override@JsonKey(name: 'private_notes') final  String privateNotes;
@override@JsonKey(name: 'public_notes') final  String publicNotes;
@override@JsonKey(name: 'transaction_reference') final  String transactionReference;
@override@JsonKey(name: 'transaction_id') final  String transactionId;
@override@JsonKey() final  String date;
@override@JsonKey() final  String number;
@override@JsonKey(name: 'payment_date') final  String paymentDate;
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
@override@JsonKey(name: 'tax_name1') final  String taxName1;
@override@JsonKey(name: 'tax_name2') final  String taxName2;
@override@JsonKey(name: 'tax_name3') final  String taxName3;
@override@JsonKey(name: 'project_id') final  String projectId;
@override@JsonKey(name: 'entity_type') final  String entityType;
// Recurring schedule deltas.
@override@JsonKey(name: 'frequency_id') final  String frequencyId;
@override@JsonKey(name: 'remaining_cycles') final  int remainingCycles;
@override@JsonKey(name: 'next_send_date') final  String nextSendDate;
@override@JsonKey(name: 'last_sent_date') final  String lastSentDate;
@override@JsonKey(name: 'status_id') final  String? statusId;
// Only populated when the server replies with `?show_dates=true`.
 final  List<RecurringDateApi>? _recurringDates;
// Only populated when the server replies with `?show_dates=true`.
@override@JsonKey(name: 'recurring_dates') List<RecurringDateApi>? get recurringDates {
  final value = _recurringDates;
  if (value == null) return null;
  if (_recurringDates is EqualUnmodifiableListView) return _recurringDates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Money — Object so number / string are both decoded.
@override@JsonKey() final  Object amount;
@override@JsonKey(name: 'foreign_amount') final  Object foreignAmount;
@override@JsonKey(name: 'exchange_rate') final  Object exchangeRate;
@override@JsonKey(name: 'tax_amount1') final  Object taxAmount1;
@override@JsonKey(name: 'tax_amount2') final  Object taxAmount2;
@override@JsonKey(name: 'tax_amount3') final  Object taxAmount3;
@override@JsonKey(name: 'tax_rate1') final  Object taxRate1;
@override@JsonKey(name: 'tax_rate2') final  Object taxRate2;
@override@JsonKey(name: 'tax_rate3') final  Object taxRate3;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'should_be_invoiced') final  bool shouldBeInvoiced;
@override@JsonKey(name: 'invoice_documents') final  bool invoiceDocuments;
@override@JsonKey(name: 'uses_inclusive_taxes') final  bool usesInclusiveTaxes;
@override@JsonKey(name: 'calculate_tax_by_amount') final  bool calculateTaxByAmount;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
 final  List<DocumentApi>? _documents;
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


/// Create a copy of RecurringExpenseApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecurringExpenseApiCopyWith<_RecurringExpenseApi> get copyWith => __$RecurringExpenseApiCopyWithImpl<_RecurringExpenseApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RecurringExpenseApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecurringExpenseApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.invoiceCurrencyId, invoiceCurrencyId) || other.invoiceCurrencyId == invoiceCurrencyId)&&(identical(other.expenseCurrencyId, expenseCurrencyId) || other.expenseCurrencyId == expenseCurrencyId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.paymentTypeId, paymentTypeId) || other.paymentTypeId == paymentTypeId)&&(identical(other.recurringExpenseId, recurringExpenseId) || other.recurringExpenseId == recurringExpenseId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.transactionReference, transactionReference) || other.transactionReference == transactionReference)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.date, date) || other.date == date)&&(identical(other.number, number) || other.number == number)&&(identical(other.paymentDate, paymentDate) || other.paymentDate == paymentDate)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.entityType, entityType) || other.entityType == entityType)&&(identical(other.frequencyId, frequencyId) || other.frequencyId == frequencyId)&&(identical(other.remainingCycles, remainingCycles) || other.remainingCycles == remainingCycles)&&(identical(other.nextSendDate, nextSendDate) || other.nextSendDate == nextSendDate)&&(identical(other.lastSentDate, lastSentDate) || other.lastSentDate == lastSentDate)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&const DeepCollectionEquality().equals(other._recurringDates, _recurringDates)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.foreignAmount, foreignAmount)&&const DeepCollectionEquality().equals(other.exchangeRate, exchangeRate)&&const DeepCollectionEquality().equals(other.taxAmount1, taxAmount1)&&const DeepCollectionEquality().equals(other.taxAmount2, taxAmount2)&&const DeepCollectionEquality().equals(other.taxAmount3, taxAmount3)&&const DeepCollectionEquality().equals(other.taxRate1, taxRate1)&&const DeepCollectionEquality().equals(other.taxRate2, taxRate2)&&const DeepCollectionEquality().equals(other.taxRate3, taxRate3)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.shouldBeInvoiced, shouldBeInvoiced) || other.shouldBeInvoiced == shouldBeInvoiced)&&(identical(other.invoiceDocuments, invoiceDocuments) || other.invoiceDocuments == invoiceDocuments)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&(identical(other.calculateTaxByAmount, calculateTaxByAmount) || other.calculateTaxByAmount == calculateTaxByAmount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other._documents, _documents)&&const DeepCollectionEquality().equals(other._tags, _tags));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,vendorId,invoiceId,clientId,bankId,invoiceCurrencyId,expenseCurrencyId,currencyId,categoryId,paymentTypeId,recurringExpenseId,privateNotes,publicNotes,transactionReference,transactionId,date,number,paymentDate,customValue1,customValue2,customValue3,customValue4,taxName1,taxName2,taxName3,projectId,entityType,frequencyId,remainingCycles,nextSendDate,lastSentDate,statusId,const DeepCollectionEquality().hash(_recurringDates),const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(foreignAmount),const DeepCollectionEquality().hash(exchangeRate),const DeepCollectionEquality().hash(taxAmount1),const DeepCollectionEquality().hash(taxAmount2),const DeepCollectionEquality().hash(taxAmount3),const DeepCollectionEquality().hash(taxRate1),const DeepCollectionEquality().hash(taxRate2),const DeepCollectionEquality().hash(taxRate3),isDeleted,shouldBeInvoiced,invoiceDocuments,usesInclusiveTaxes,calculateTaxByAmount,createdAt,updatedAt,archivedAt,const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_tags)]);

@override
String toString() {
  return 'RecurringExpenseApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, vendorId: $vendorId, invoiceId: $invoiceId, clientId: $clientId, bankId: $bankId, invoiceCurrencyId: $invoiceCurrencyId, expenseCurrencyId: $expenseCurrencyId, currencyId: $currencyId, categoryId: $categoryId, paymentTypeId: $paymentTypeId, recurringExpenseId: $recurringExpenseId, privateNotes: $privateNotes, publicNotes: $publicNotes, transactionReference: $transactionReference, transactionId: $transactionId, date: $date, number: $number, paymentDate: $paymentDate, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, projectId: $projectId, entityType: $entityType, frequencyId: $frequencyId, remainingCycles: $remainingCycles, nextSendDate: $nextSendDate, lastSentDate: $lastSentDate, statusId: $statusId, recurringDates: $recurringDates, amount: $amount, foreignAmount: $foreignAmount, exchangeRate: $exchangeRate, taxAmount1: $taxAmount1, taxAmount2: $taxAmount2, taxAmount3: $taxAmount3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, isDeleted: $isDeleted, shouldBeInvoiced: $shouldBeInvoiced, invoiceDocuments: $invoiceDocuments, usesInclusiveTaxes: $usesInclusiveTaxes, calculateTaxByAmount: $calculateTaxByAmount, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, documents: $documents, tags: $tags)';
}


}

/// @nodoc
abstract mixin class _$RecurringExpenseApiCopyWith<$Res> implements $RecurringExpenseApiCopyWith<$Res> {
  factory _$RecurringExpenseApiCopyWith(_RecurringExpenseApi value, $Res Function(_RecurringExpenseApi) _then) = __$RecurringExpenseApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'invoice_id') String invoiceId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'bank_id') String bankId,@JsonKey(name: 'invoice_currency_id') String invoiceCurrencyId,@JsonKey(name: 'expense_currency_id') String expenseCurrencyId,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'category_id') String categoryId,@JsonKey(name: 'payment_type_id') String paymentTypeId,@JsonKey(name: 'recurring_expense_id') String recurringExpenseId,@JsonKey(name: 'private_notes') String privateNotes,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'transaction_reference') String transactionReference,@JsonKey(name: 'transaction_id') String transactionId, String date, String number,@JsonKey(name: 'payment_date') String paymentDate,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'tax_name1') String taxName1,@JsonKey(name: 'tax_name2') String taxName2,@JsonKey(name: 'tax_name3') String taxName3,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'entity_type') String entityType,@JsonKey(name: 'frequency_id') String frequencyId,@JsonKey(name: 'remaining_cycles') int remainingCycles,@JsonKey(name: 'next_send_date') String nextSendDate,@JsonKey(name: 'last_sent_date') String lastSentDate,@JsonKey(name: 'status_id') String? statusId,@JsonKey(name: 'recurring_dates') List<RecurringDateApi>? recurringDates, Object amount,@JsonKey(name: 'foreign_amount') Object foreignAmount,@JsonKey(name: 'exchange_rate') Object exchangeRate,@JsonKey(name: 'tax_amount1') Object taxAmount1,@JsonKey(name: 'tax_amount2') Object taxAmount2,@JsonKey(name: 'tax_amount3') Object taxAmount3,@JsonKey(name: 'tax_rate1') Object taxRate1,@JsonKey(name: 'tax_rate2') Object taxRate2,@JsonKey(name: 'tax_rate3') Object taxRate3,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'should_be_invoiced') bool shouldBeInvoiced,@JsonKey(name: 'invoice_documents') bool invoiceDocuments,@JsonKey(name: 'uses_inclusive_taxes') bool usesInclusiveTaxes,@JsonKey(name: 'calculate_tax_by_amount') bool calculateTaxByAmount,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt, List<DocumentApi>? documents,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags
});




}
/// @nodoc
class __$RecurringExpenseApiCopyWithImpl<$Res>
    implements _$RecurringExpenseApiCopyWith<$Res> {
  __$RecurringExpenseApiCopyWithImpl(this._self, this._then);

  final _RecurringExpenseApi _self;
  final $Res Function(_RecurringExpenseApi) _then;

/// Create a copy of RecurringExpenseApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? vendorId = null,Object? invoiceId = null,Object? clientId = null,Object? bankId = null,Object? invoiceCurrencyId = null,Object? expenseCurrencyId = null,Object? currencyId = null,Object? categoryId = null,Object? paymentTypeId = null,Object? recurringExpenseId = null,Object? privateNotes = null,Object? publicNotes = null,Object? transactionReference = null,Object? transactionId = null,Object? date = null,Object? number = null,Object? paymentDate = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? projectId = null,Object? entityType = null,Object? frequencyId = null,Object? remainingCycles = null,Object? nextSendDate = null,Object? lastSentDate = null,Object? statusId = freezed,Object? recurringDates = freezed,Object? amount = null,Object? foreignAmount = null,Object? exchangeRate = null,Object? taxAmount1 = null,Object? taxAmount2 = null,Object? taxAmount3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? isDeleted = null,Object? shouldBeInvoiced = null,Object? invoiceDocuments = null,Object? usesInclusiveTaxes = null,Object? calculateTaxByAmount = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? documents = freezed,Object? tags = null,}) {
  return _then(_RecurringExpenseApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,bankId: null == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as String,invoiceCurrencyId: null == invoiceCurrencyId ? _self.invoiceCurrencyId : invoiceCurrencyId // ignore: cast_nullable_to_non_nullable
as String,expenseCurrencyId: null == expenseCurrencyId ? _self.expenseCurrencyId : expenseCurrencyId // ignore: cast_nullable_to_non_nullable
as String,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String,paymentTypeId: null == paymentTypeId ? _self.paymentTypeId : paymentTypeId // ignore: cast_nullable_to_non_nullable
as String,recurringExpenseId: null == recurringExpenseId ? _self.recurringExpenseId : recurringExpenseId // ignore: cast_nullable_to_non_nullable
as String,privateNotes: null == privateNotes ? _self.privateNotes : privateNotes // ignore: cast_nullable_to_non_nullable
as String,publicNotes: null == publicNotes ? _self.publicNotes : publicNotes // ignore: cast_nullable_to_non_nullable
as String,transactionReference: null == transactionReference ? _self.transactionReference : transactionReference // ignore: cast_nullable_to_non_nullable
as String,transactionId: null == transactionId ? _self.transactionId : transactionId // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,paymentDate: null == paymentDate ? _self.paymentDate : paymentDate // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,taxName1: null == taxName1 ? _self.taxName1 : taxName1 // ignore: cast_nullable_to_non_nullable
as String,taxName2: null == taxName2 ? _self.taxName2 : taxName2 // ignore: cast_nullable_to_non_nullable
as String,taxName3: null == taxName3 ? _self.taxName3 : taxName3 // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,entityType: null == entityType ? _self.entityType : entityType // ignore: cast_nullable_to_non_nullable
as String,frequencyId: null == frequencyId ? _self.frequencyId : frequencyId // ignore: cast_nullable_to_non_nullable
as String,remainingCycles: null == remainingCycles ? _self.remainingCycles : remainingCycles // ignore: cast_nullable_to_non_nullable
as int,nextSendDate: null == nextSendDate ? _self.nextSendDate : nextSendDate // ignore: cast_nullable_to_non_nullable
as String,lastSentDate: null == lastSentDate ? _self.lastSentDate : lastSentDate // ignore: cast_nullable_to_non_nullable
as String,statusId: freezed == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String?,recurringDates: freezed == recurringDates ? _self._recurringDates : recurringDates // ignore: cast_nullable_to_non_nullable
as List<RecurringDateApi>?,amount: null == amount ? _self.amount : amount ,foreignAmount: null == foreignAmount ? _self.foreignAmount : foreignAmount ,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate ,taxAmount1: null == taxAmount1 ? _self.taxAmount1 : taxAmount1 ,taxAmount2: null == taxAmount2 ? _self.taxAmount2 : taxAmount2 ,taxAmount3: null == taxAmount3 ? _self.taxAmount3 : taxAmount3 ,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 ,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 ,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 ,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,shouldBeInvoiced: null == shouldBeInvoiced ? _self.shouldBeInvoiced : shouldBeInvoiced // ignore: cast_nullable_to_non_nullable
as bool,invoiceDocuments: null == invoiceDocuments ? _self.invoiceDocuments : invoiceDocuments // ignore: cast_nullable_to_non_nullable
as bool,usesInclusiveTaxes: null == usesInclusiveTaxes ? _self.usesInclusiveTaxes : usesInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,calculateTaxByAmount: null == calculateTaxByAmount ? _self.calculateTaxByAmount : calculateTaxByAmount // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,documents: freezed == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,
  ));
}


}


/// @nodoc
mixin _$RecurringDateApi {

@JsonKey(name: 'send_date') String get sendDate;
/// Create a copy of RecurringDateApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecurringDateApiCopyWith<RecurringDateApi> get copyWith => _$RecurringDateApiCopyWithImpl<RecurringDateApi>(this as RecurringDateApi, _$identity);

  /// Serializes this RecurringDateApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecurringDateApi&&(identical(other.sendDate, sendDate) || other.sendDate == sendDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sendDate);

@override
String toString() {
  return 'RecurringDateApi(sendDate: $sendDate)';
}


}

/// @nodoc
abstract mixin class $RecurringDateApiCopyWith<$Res>  {
  factory $RecurringDateApiCopyWith(RecurringDateApi value, $Res Function(RecurringDateApi) _then) = _$RecurringDateApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'send_date') String sendDate
});




}
/// @nodoc
class _$RecurringDateApiCopyWithImpl<$Res>
    implements $RecurringDateApiCopyWith<$Res> {
  _$RecurringDateApiCopyWithImpl(this._self, this._then);

  final RecurringDateApi _self;
  final $Res Function(RecurringDateApi) _then;

/// Create a copy of RecurringDateApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sendDate = null,}) {
  return _then(_self.copyWith(
sendDate: null == sendDate ? _self.sendDate : sendDate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RecurringDateApi].
extension RecurringDateApiPatterns on RecurringDateApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecurringDateApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecurringDateApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecurringDateApi value)  $default,){
final _that = this;
switch (_that) {
case _RecurringDateApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecurringDateApi value)?  $default,){
final _that = this;
switch (_that) {
case _RecurringDateApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'send_date')  String sendDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecurringDateApi() when $default != null:
return $default(_that.sendDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'send_date')  String sendDate)  $default,) {final _that = this;
switch (_that) {
case _RecurringDateApi():
return $default(_that.sendDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'send_date')  String sendDate)?  $default,) {final _that = this;
switch (_that) {
case _RecurringDateApi() when $default != null:
return $default(_that.sendDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RecurringDateApi implements RecurringDateApi {
  const _RecurringDateApi({@JsonKey(name: 'send_date') this.sendDate = ''});
  factory _RecurringDateApi.fromJson(Map<String, dynamic> json) => _$RecurringDateApiFromJson(json);

@override@JsonKey(name: 'send_date') final  String sendDate;

/// Create a copy of RecurringDateApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecurringDateApiCopyWith<_RecurringDateApi> get copyWith => __$RecurringDateApiCopyWithImpl<_RecurringDateApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RecurringDateApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecurringDateApi&&(identical(other.sendDate, sendDate) || other.sendDate == sendDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sendDate);

@override
String toString() {
  return 'RecurringDateApi(sendDate: $sendDate)';
}


}

/// @nodoc
abstract mixin class _$RecurringDateApiCopyWith<$Res> implements $RecurringDateApiCopyWith<$Res> {
  factory _$RecurringDateApiCopyWith(_RecurringDateApi value, $Res Function(_RecurringDateApi) _then) = __$RecurringDateApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'send_date') String sendDate
});




}
/// @nodoc
class __$RecurringDateApiCopyWithImpl<$Res>
    implements _$RecurringDateApiCopyWith<$Res> {
  __$RecurringDateApiCopyWithImpl(this._self, this._then);

  final _RecurringDateApi _self;
  final $Res Function(_RecurringDateApi) _then;

/// Create a copy of RecurringDateApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sendDate = null,}) {
  return _then(_RecurringDateApi(
sendDate: null == sendDate ? _self.sendDate : sendDate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$RecurringExpenseListApi {

@JsonKey(fromJson: _recurringExpenseListData) List<RecurringExpenseApi> get data;
/// Create a copy of RecurringExpenseListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecurringExpenseListApiCopyWith<RecurringExpenseListApi> get copyWith => _$RecurringExpenseListApiCopyWithImpl<RecurringExpenseListApi>(this as RecurringExpenseListApi, _$identity);

  /// Serializes this RecurringExpenseListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecurringExpenseListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'RecurringExpenseListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $RecurringExpenseListApiCopyWith<$Res>  {
  factory $RecurringExpenseListApiCopyWith(RecurringExpenseListApi value, $Res Function(RecurringExpenseListApi) _then) = _$RecurringExpenseListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _recurringExpenseListData) List<RecurringExpenseApi> data
});




}
/// @nodoc
class _$RecurringExpenseListApiCopyWithImpl<$Res>
    implements $RecurringExpenseListApiCopyWith<$Res> {
  _$RecurringExpenseListApiCopyWithImpl(this._self, this._then);

  final RecurringExpenseListApi _self;
  final $Res Function(RecurringExpenseListApi) _then;

/// Create a copy of RecurringExpenseListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<RecurringExpenseApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [RecurringExpenseListApi].
extension RecurringExpenseListApiPatterns on RecurringExpenseListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecurringExpenseListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecurringExpenseListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecurringExpenseListApi value)  $default,){
final _that = this;
switch (_that) {
case _RecurringExpenseListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecurringExpenseListApi value)?  $default,){
final _that = this;
switch (_that) {
case _RecurringExpenseListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _recurringExpenseListData)  List<RecurringExpenseApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecurringExpenseListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _recurringExpenseListData)  List<RecurringExpenseApi> data)  $default,) {final _that = this;
switch (_that) {
case _RecurringExpenseListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _recurringExpenseListData)  List<RecurringExpenseApi> data)?  $default,) {final _that = this;
switch (_that) {
case _RecurringExpenseListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RecurringExpenseListApi implements RecurringExpenseListApi {
  const _RecurringExpenseListApi({@JsonKey(fromJson: _recurringExpenseListData) final  List<RecurringExpenseApi> data = const []}): _data = data;
  factory _RecurringExpenseListApi.fromJson(Map<String, dynamic> json) => _$RecurringExpenseListApiFromJson(json);

 final  List<RecurringExpenseApi> _data;
@override@JsonKey(fromJson: _recurringExpenseListData) List<RecurringExpenseApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of RecurringExpenseListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecurringExpenseListApiCopyWith<_RecurringExpenseListApi> get copyWith => __$RecurringExpenseListApiCopyWithImpl<_RecurringExpenseListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RecurringExpenseListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecurringExpenseListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'RecurringExpenseListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$RecurringExpenseListApiCopyWith<$Res> implements $RecurringExpenseListApiCopyWith<$Res> {
  factory _$RecurringExpenseListApiCopyWith(_RecurringExpenseListApi value, $Res Function(_RecurringExpenseListApi) _then) = __$RecurringExpenseListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _recurringExpenseListData) List<RecurringExpenseApi> data
});




}
/// @nodoc
class __$RecurringExpenseListApiCopyWithImpl<$Res>
    implements _$RecurringExpenseListApiCopyWith<$Res> {
  __$RecurringExpenseListApiCopyWithImpl(this._self, this._then);

  final _RecurringExpenseListApi _self;
  final $Res Function(_RecurringExpenseListApi) _then;

/// Create a copy of RecurringExpenseListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_RecurringExpenseListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<RecurringExpenseApi>,
  ));
}


}


/// @nodoc
mixin _$RecurringExpenseItemApi {

 RecurringExpenseApi get data;
/// Create a copy of RecurringExpenseItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecurringExpenseItemApiCopyWith<RecurringExpenseItemApi> get copyWith => _$RecurringExpenseItemApiCopyWithImpl<RecurringExpenseItemApi>(this as RecurringExpenseItemApi, _$identity);

  /// Serializes this RecurringExpenseItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecurringExpenseItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'RecurringExpenseItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $RecurringExpenseItemApiCopyWith<$Res>  {
  factory $RecurringExpenseItemApiCopyWith(RecurringExpenseItemApi value, $Res Function(RecurringExpenseItemApi) _then) = _$RecurringExpenseItemApiCopyWithImpl;
@useResult
$Res call({
 RecurringExpenseApi data
});


$RecurringExpenseApiCopyWith<$Res> get data;

}
/// @nodoc
class _$RecurringExpenseItemApiCopyWithImpl<$Res>
    implements $RecurringExpenseItemApiCopyWith<$Res> {
  _$RecurringExpenseItemApiCopyWithImpl(this._self, this._then);

  final RecurringExpenseItemApi _self;
  final $Res Function(RecurringExpenseItemApi) _then;

/// Create a copy of RecurringExpenseItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as RecurringExpenseApi,
  ));
}
/// Create a copy of RecurringExpenseItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RecurringExpenseApiCopyWith<$Res> get data {
  
  return $RecurringExpenseApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [RecurringExpenseItemApi].
extension RecurringExpenseItemApiPatterns on RecurringExpenseItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecurringExpenseItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecurringExpenseItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecurringExpenseItemApi value)  $default,){
final _that = this;
switch (_that) {
case _RecurringExpenseItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecurringExpenseItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _RecurringExpenseItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( RecurringExpenseApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecurringExpenseItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( RecurringExpenseApi data)  $default,) {final _that = this;
switch (_that) {
case _RecurringExpenseItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( RecurringExpenseApi data)?  $default,) {final _that = this;
switch (_that) {
case _RecurringExpenseItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RecurringExpenseItemApi implements RecurringExpenseItemApi {
  const _RecurringExpenseItemApi({required this.data});
  factory _RecurringExpenseItemApi.fromJson(Map<String, dynamic> json) => _$RecurringExpenseItemApiFromJson(json);

@override final  RecurringExpenseApi data;

/// Create a copy of RecurringExpenseItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecurringExpenseItemApiCopyWith<_RecurringExpenseItemApi> get copyWith => __$RecurringExpenseItemApiCopyWithImpl<_RecurringExpenseItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RecurringExpenseItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecurringExpenseItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'RecurringExpenseItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$RecurringExpenseItemApiCopyWith<$Res> implements $RecurringExpenseItemApiCopyWith<$Res> {
  factory _$RecurringExpenseItemApiCopyWith(_RecurringExpenseItemApi value, $Res Function(_RecurringExpenseItemApi) _then) = __$RecurringExpenseItemApiCopyWithImpl;
@override @useResult
$Res call({
 RecurringExpenseApi data
});


@override $RecurringExpenseApiCopyWith<$Res> get data;

}
/// @nodoc
class __$RecurringExpenseItemApiCopyWithImpl<$Res>
    implements _$RecurringExpenseItemApiCopyWith<$Res> {
  __$RecurringExpenseItemApiCopyWithImpl(this._self, this._then);

  final _RecurringExpenseItemApi _self;
  final $Res Function(_RecurringExpenseItemApi) _then;

/// Create a copy of RecurringExpenseItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_RecurringExpenseItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as RecurringExpenseApi,
  ));
}

/// Create a copy of RecurringExpenseItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RecurringExpenseApiCopyWith<$Res> get data {
  
  return $RecurringExpenseApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
