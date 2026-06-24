// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'expense_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExpenseApi {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'assigned_user_id') String get assignedUserId;@JsonKey(name: 'vendor_id') String get vendorId;@JsonKey(name: 'invoice_id') String get invoiceId;@JsonKey(name: 'client_id') String get clientId;@JsonKey(name: 'bank_id') String get bankId;@JsonKey(name: 'invoice_currency_id') String get invoiceCurrencyId;@JsonKey(name: 'expense_currency_id') String get expenseCurrencyId;@JsonKey(name: 'currency_id') String get currencyId;@JsonKey(name: 'category_id') String get categoryId;@JsonKey(name: 'payment_type_id') String get paymentTypeId;@JsonKey(name: 'recurring_expense_id') String get recurringExpenseId;@JsonKey(name: 'private_notes') String get privateNotes;@JsonKey(name: 'public_notes') String get publicNotes;@JsonKey(name: 'transaction_reference') String get transactionReference;@JsonKey(name: 'transaction_id') String get transactionId; String get date; String get number;@JsonKey(name: 'payment_date') String get paymentDate;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;@JsonKey(name: 'tax_name1') String get taxName1;@JsonKey(name: 'tax_name2') String get taxName2;@JsonKey(name: 'tax_name3') String get taxName3;@JsonKey(name: 'project_id') String get projectId;@JsonKey(name: 'entity_type') String get entityType;// Money — Object so number / string are both decoded; parsed via
// parseMoney in the domain factory.
 Object get amount;@JsonKey(name: 'foreign_amount') Object get foreignAmount;@JsonKey(name: 'exchange_rate') Object get exchangeRate;@JsonKey(name: 'tax_amount1') Object get taxAmount1;@JsonKey(name: 'tax_amount2') Object get taxAmount2;@JsonKey(name: 'tax_amount3') Object get taxAmount3;@JsonKey(name: 'tax_rate1') Object get taxRate1;@JsonKey(name: 'tax_rate2') Object get taxRate2;@JsonKey(name: 'tax_rate3') Object get taxRate3;// Bools
@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'should_be_invoiced') bool get shouldBeInvoiced;@JsonKey(name: 'invoice_documents') bool get invoiceDocuments;@JsonKey(name: 'uses_inclusive_taxes') bool get usesInclusiveTaxes;@JsonKey(name: 'calculate_tax_by_amount') bool get calculateTaxByAmount;// Timestamps
@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;// Nullable so JSON-omitted (→ null) is distinguishable from
// JSON-present-and-empty (→ const []). Same convention as `ProjectApi`.
 List<DocumentApi>? get documents;
/// Create a copy of ExpenseApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseApiCopyWith<ExpenseApi> get copyWith => _$ExpenseApiCopyWithImpl<ExpenseApi>(this as ExpenseApi, _$identity);

  /// Serializes this ExpenseApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpenseApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.invoiceCurrencyId, invoiceCurrencyId) || other.invoiceCurrencyId == invoiceCurrencyId)&&(identical(other.expenseCurrencyId, expenseCurrencyId) || other.expenseCurrencyId == expenseCurrencyId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.paymentTypeId, paymentTypeId) || other.paymentTypeId == paymentTypeId)&&(identical(other.recurringExpenseId, recurringExpenseId) || other.recurringExpenseId == recurringExpenseId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.transactionReference, transactionReference) || other.transactionReference == transactionReference)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.date, date) || other.date == date)&&(identical(other.number, number) || other.number == number)&&(identical(other.paymentDate, paymentDate) || other.paymentDate == paymentDate)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.entityType, entityType) || other.entityType == entityType)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.foreignAmount, foreignAmount)&&const DeepCollectionEquality().equals(other.exchangeRate, exchangeRate)&&const DeepCollectionEquality().equals(other.taxAmount1, taxAmount1)&&const DeepCollectionEquality().equals(other.taxAmount2, taxAmount2)&&const DeepCollectionEquality().equals(other.taxAmount3, taxAmount3)&&const DeepCollectionEquality().equals(other.taxRate1, taxRate1)&&const DeepCollectionEquality().equals(other.taxRate2, taxRate2)&&const DeepCollectionEquality().equals(other.taxRate3, taxRate3)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.shouldBeInvoiced, shouldBeInvoiced) || other.shouldBeInvoiced == shouldBeInvoiced)&&(identical(other.invoiceDocuments, invoiceDocuments) || other.invoiceDocuments == invoiceDocuments)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&(identical(other.calculateTaxByAmount, calculateTaxByAmount) || other.calculateTaxByAmount == calculateTaxByAmount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other.documents, documents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,vendorId,invoiceId,clientId,bankId,invoiceCurrencyId,expenseCurrencyId,currencyId,categoryId,paymentTypeId,recurringExpenseId,privateNotes,publicNotes,transactionReference,transactionId,date,number,paymentDate,customValue1,customValue2,customValue3,customValue4,taxName1,taxName2,taxName3,projectId,entityType,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(foreignAmount),const DeepCollectionEquality().hash(exchangeRate),const DeepCollectionEquality().hash(taxAmount1),const DeepCollectionEquality().hash(taxAmount2),const DeepCollectionEquality().hash(taxAmount3),const DeepCollectionEquality().hash(taxRate1),const DeepCollectionEquality().hash(taxRate2),const DeepCollectionEquality().hash(taxRate3),isDeleted,shouldBeInvoiced,invoiceDocuments,usesInclusiveTaxes,calculateTaxByAmount,createdAt,updatedAt,archivedAt,const DeepCollectionEquality().hash(documents)]);

@override
String toString() {
  return 'ExpenseApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, vendorId: $vendorId, invoiceId: $invoiceId, clientId: $clientId, bankId: $bankId, invoiceCurrencyId: $invoiceCurrencyId, expenseCurrencyId: $expenseCurrencyId, currencyId: $currencyId, categoryId: $categoryId, paymentTypeId: $paymentTypeId, recurringExpenseId: $recurringExpenseId, privateNotes: $privateNotes, publicNotes: $publicNotes, transactionReference: $transactionReference, transactionId: $transactionId, date: $date, number: $number, paymentDate: $paymentDate, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, projectId: $projectId, entityType: $entityType, amount: $amount, foreignAmount: $foreignAmount, exchangeRate: $exchangeRate, taxAmount1: $taxAmount1, taxAmount2: $taxAmount2, taxAmount3: $taxAmount3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, isDeleted: $isDeleted, shouldBeInvoiced: $shouldBeInvoiced, invoiceDocuments: $invoiceDocuments, usesInclusiveTaxes: $usesInclusiveTaxes, calculateTaxByAmount: $calculateTaxByAmount, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, documents: $documents)';
}


}

/// @nodoc
abstract mixin class $ExpenseApiCopyWith<$Res>  {
  factory $ExpenseApiCopyWith(ExpenseApi value, $Res Function(ExpenseApi) _then) = _$ExpenseApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'invoice_id') String invoiceId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'bank_id') String bankId,@JsonKey(name: 'invoice_currency_id') String invoiceCurrencyId,@JsonKey(name: 'expense_currency_id') String expenseCurrencyId,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'category_id') String categoryId,@JsonKey(name: 'payment_type_id') String paymentTypeId,@JsonKey(name: 'recurring_expense_id') String recurringExpenseId,@JsonKey(name: 'private_notes') String privateNotes,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'transaction_reference') String transactionReference,@JsonKey(name: 'transaction_id') String transactionId, String date, String number,@JsonKey(name: 'payment_date') String paymentDate,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'tax_name1') String taxName1,@JsonKey(name: 'tax_name2') String taxName2,@JsonKey(name: 'tax_name3') String taxName3,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'entity_type') String entityType, Object amount,@JsonKey(name: 'foreign_amount') Object foreignAmount,@JsonKey(name: 'exchange_rate') Object exchangeRate,@JsonKey(name: 'tax_amount1') Object taxAmount1,@JsonKey(name: 'tax_amount2') Object taxAmount2,@JsonKey(name: 'tax_amount3') Object taxAmount3,@JsonKey(name: 'tax_rate1') Object taxRate1,@JsonKey(name: 'tax_rate2') Object taxRate2,@JsonKey(name: 'tax_rate3') Object taxRate3,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'should_be_invoiced') bool shouldBeInvoiced,@JsonKey(name: 'invoice_documents') bool invoiceDocuments,@JsonKey(name: 'uses_inclusive_taxes') bool usesInclusiveTaxes,@JsonKey(name: 'calculate_tax_by_amount') bool calculateTaxByAmount,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt, List<DocumentApi>? documents
});




}
/// @nodoc
class _$ExpenseApiCopyWithImpl<$Res>
    implements $ExpenseApiCopyWith<$Res> {
  _$ExpenseApiCopyWithImpl(this._self, this._then);

  final ExpenseApi _self;
  final $Res Function(ExpenseApi) _then;

/// Create a copy of ExpenseApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? vendorId = null,Object? invoiceId = null,Object? clientId = null,Object? bankId = null,Object? invoiceCurrencyId = null,Object? expenseCurrencyId = null,Object? currencyId = null,Object? categoryId = null,Object? paymentTypeId = null,Object? recurringExpenseId = null,Object? privateNotes = null,Object? publicNotes = null,Object? transactionReference = null,Object? transactionId = null,Object? date = null,Object? number = null,Object? paymentDate = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? projectId = null,Object? entityType = null,Object? amount = null,Object? foreignAmount = null,Object? exchangeRate = null,Object? taxAmount1 = null,Object? taxAmount2 = null,Object? taxAmount3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? isDeleted = null,Object? shouldBeInvoiced = null,Object? invoiceDocuments = null,Object? usesInclusiveTaxes = null,Object? calculateTaxByAmount = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? documents = freezed,}) {
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
as String,amount: null == amount ? _self.amount : amount ,foreignAmount: null == foreignAmount ? _self.foreignAmount : foreignAmount ,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate ,taxAmount1: null == taxAmount1 ? _self.taxAmount1 : taxAmount1 ,taxAmount2: null == taxAmount2 ? _self.taxAmount2 : taxAmount2 ,taxAmount3: null == taxAmount3 ? _self.taxAmount3 : taxAmount3 ,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 ,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 ,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 ,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,shouldBeInvoiced: null == shouldBeInvoiced ? _self.shouldBeInvoiced : shouldBeInvoiced // ignore: cast_nullable_to_non_nullable
as bool,invoiceDocuments: null == invoiceDocuments ? _self.invoiceDocuments : invoiceDocuments // ignore: cast_nullable_to_non_nullable
as bool,usesInclusiveTaxes: null == usesInclusiveTaxes ? _self.usesInclusiveTaxes : usesInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,calculateTaxByAmount: null == calculateTaxByAmount ? _self.calculateTaxByAmount : calculateTaxByAmount // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,documents: freezed == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,
  ));
}

}


/// Adds pattern-matching-related methods to [ExpenseApi].
extension ExpenseApiPatterns on ExpenseApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpenseApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpenseApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpenseApi value)  $default,){
final _that = this;
switch (_that) {
case _ExpenseApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpenseApi value)?  $default,){
final _that = this;
switch (_that) {
case _ExpenseApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'invoice_id')  String invoiceId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'bank_id')  String bankId, @JsonKey(name: 'invoice_currency_id')  String invoiceCurrencyId, @JsonKey(name: 'expense_currency_id')  String expenseCurrencyId, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'category_id')  String categoryId, @JsonKey(name: 'payment_type_id')  String paymentTypeId, @JsonKey(name: 'recurring_expense_id')  String recurringExpenseId, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'transaction_reference')  String transactionReference, @JsonKey(name: 'transaction_id')  String transactionId,  String date,  String number, @JsonKey(name: 'payment_date')  String paymentDate, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'entity_type')  String entityType,  Object amount, @JsonKey(name: 'foreign_amount')  Object foreignAmount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_amount1')  Object taxAmount1, @JsonKey(name: 'tax_amount2')  Object taxAmount2, @JsonKey(name: 'tax_amount3')  Object taxAmount3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'should_be_invoiced')  bool shouldBeInvoiced, @JsonKey(name: 'invoice_documents')  bool invoiceDocuments, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'calculate_tax_by_amount')  bool calculateTaxByAmount, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt,  List<DocumentApi>? documents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpenseApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.vendorId,_that.invoiceId,_that.clientId,_that.bankId,_that.invoiceCurrencyId,_that.expenseCurrencyId,_that.currencyId,_that.categoryId,_that.paymentTypeId,_that.recurringExpenseId,_that.privateNotes,_that.publicNotes,_that.transactionReference,_that.transactionId,_that.date,_that.number,_that.paymentDate,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.taxName1,_that.taxName2,_that.taxName3,_that.projectId,_that.entityType,_that.amount,_that.foreignAmount,_that.exchangeRate,_that.taxAmount1,_that.taxAmount2,_that.taxAmount3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.isDeleted,_that.shouldBeInvoiced,_that.invoiceDocuments,_that.usesInclusiveTaxes,_that.calculateTaxByAmount,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.documents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'invoice_id')  String invoiceId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'bank_id')  String bankId, @JsonKey(name: 'invoice_currency_id')  String invoiceCurrencyId, @JsonKey(name: 'expense_currency_id')  String expenseCurrencyId, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'category_id')  String categoryId, @JsonKey(name: 'payment_type_id')  String paymentTypeId, @JsonKey(name: 'recurring_expense_id')  String recurringExpenseId, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'transaction_reference')  String transactionReference, @JsonKey(name: 'transaction_id')  String transactionId,  String date,  String number, @JsonKey(name: 'payment_date')  String paymentDate, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'entity_type')  String entityType,  Object amount, @JsonKey(name: 'foreign_amount')  Object foreignAmount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_amount1')  Object taxAmount1, @JsonKey(name: 'tax_amount2')  Object taxAmount2, @JsonKey(name: 'tax_amount3')  Object taxAmount3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'should_be_invoiced')  bool shouldBeInvoiced, @JsonKey(name: 'invoice_documents')  bool invoiceDocuments, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'calculate_tax_by_amount')  bool calculateTaxByAmount, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt,  List<DocumentApi>? documents)  $default,) {final _that = this;
switch (_that) {
case _ExpenseApi():
return $default(_that.id,_that.userId,_that.assignedUserId,_that.vendorId,_that.invoiceId,_that.clientId,_that.bankId,_that.invoiceCurrencyId,_that.expenseCurrencyId,_that.currencyId,_that.categoryId,_that.paymentTypeId,_that.recurringExpenseId,_that.privateNotes,_that.publicNotes,_that.transactionReference,_that.transactionId,_that.date,_that.number,_that.paymentDate,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.taxName1,_that.taxName2,_that.taxName3,_that.projectId,_that.entityType,_that.amount,_that.foreignAmount,_that.exchangeRate,_that.taxAmount1,_that.taxAmount2,_that.taxAmount3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.isDeleted,_that.shouldBeInvoiced,_that.invoiceDocuments,_that.usesInclusiveTaxes,_that.calculateTaxByAmount,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.documents);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'invoice_id')  String invoiceId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'bank_id')  String bankId, @JsonKey(name: 'invoice_currency_id')  String invoiceCurrencyId, @JsonKey(name: 'expense_currency_id')  String expenseCurrencyId, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'category_id')  String categoryId, @JsonKey(name: 'payment_type_id')  String paymentTypeId, @JsonKey(name: 'recurring_expense_id')  String recurringExpenseId, @JsonKey(name: 'private_notes')  String privateNotes, @JsonKey(name: 'public_notes')  String publicNotes, @JsonKey(name: 'transaction_reference')  String transactionReference, @JsonKey(name: 'transaction_id')  String transactionId,  String date,  String number, @JsonKey(name: 'payment_date')  String paymentDate, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'tax_name1')  String taxName1, @JsonKey(name: 'tax_name2')  String taxName2, @JsonKey(name: 'tax_name3')  String taxName3, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'entity_type')  String entityType,  Object amount, @JsonKey(name: 'foreign_amount')  Object foreignAmount, @JsonKey(name: 'exchange_rate')  Object exchangeRate, @JsonKey(name: 'tax_amount1')  Object taxAmount1, @JsonKey(name: 'tax_amount2')  Object taxAmount2, @JsonKey(name: 'tax_amount3')  Object taxAmount3, @JsonKey(name: 'tax_rate1')  Object taxRate1, @JsonKey(name: 'tax_rate2')  Object taxRate2, @JsonKey(name: 'tax_rate3')  Object taxRate3, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'should_be_invoiced')  bool shouldBeInvoiced, @JsonKey(name: 'invoice_documents')  bool invoiceDocuments, @JsonKey(name: 'uses_inclusive_taxes')  bool usesInclusiveTaxes, @JsonKey(name: 'calculate_tax_by_amount')  bool calculateTaxByAmount, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt,  List<DocumentApi>? documents)?  $default,) {final _that = this;
switch (_that) {
case _ExpenseApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.vendorId,_that.invoiceId,_that.clientId,_that.bankId,_that.invoiceCurrencyId,_that.expenseCurrencyId,_that.currencyId,_that.categoryId,_that.paymentTypeId,_that.recurringExpenseId,_that.privateNotes,_that.publicNotes,_that.transactionReference,_that.transactionId,_that.date,_that.number,_that.paymentDate,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.taxName1,_that.taxName2,_that.taxName3,_that.projectId,_that.entityType,_that.amount,_that.foreignAmount,_that.exchangeRate,_that.taxAmount1,_that.taxAmount2,_that.taxAmount3,_that.taxRate1,_that.taxRate2,_that.taxRate3,_that.isDeleted,_that.shouldBeInvoiced,_that.invoiceDocuments,_that.usesInclusiveTaxes,_that.calculateTaxByAmount,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.documents);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpenseApi implements ExpenseApi {
  const _ExpenseApi({this.id = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', @JsonKey(name: 'vendor_id') this.vendorId = '', @JsonKey(name: 'invoice_id') this.invoiceId = '', @JsonKey(name: 'client_id') this.clientId = '', @JsonKey(name: 'bank_id') this.bankId = '', @JsonKey(name: 'invoice_currency_id') this.invoiceCurrencyId = '', @JsonKey(name: 'expense_currency_id') this.expenseCurrencyId = '', @JsonKey(name: 'currency_id') this.currencyId = '', @JsonKey(name: 'category_id') this.categoryId = '', @JsonKey(name: 'payment_type_id') this.paymentTypeId = '', @JsonKey(name: 'recurring_expense_id') this.recurringExpenseId = '', @JsonKey(name: 'private_notes') this.privateNotes = '', @JsonKey(name: 'public_notes') this.publicNotes = '', @JsonKey(name: 'transaction_reference') this.transactionReference = '', @JsonKey(name: 'transaction_id') this.transactionId = '', this.date = '', this.number = '', @JsonKey(name: 'payment_date') this.paymentDate = '', @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'tax_name1') this.taxName1 = '', @JsonKey(name: 'tax_name2') this.taxName2 = '', @JsonKey(name: 'tax_name3') this.taxName3 = '', @JsonKey(name: 'project_id') this.projectId = '', @JsonKey(name: 'entity_type') this.entityType = '', this.amount = '0', @JsonKey(name: 'foreign_amount') this.foreignAmount = '0', @JsonKey(name: 'exchange_rate') this.exchangeRate = '1', @JsonKey(name: 'tax_amount1') this.taxAmount1 = '0', @JsonKey(name: 'tax_amount2') this.taxAmount2 = '0', @JsonKey(name: 'tax_amount3') this.taxAmount3 = '0', @JsonKey(name: 'tax_rate1') this.taxRate1 = '0', @JsonKey(name: 'tax_rate2') this.taxRate2 = '0', @JsonKey(name: 'tax_rate3') this.taxRate3 = '0', @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'should_be_invoiced') this.shouldBeInvoiced = false, @JsonKey(name: 'invoice_documents') this.invoiceDocuments = false, @JsonKey(name: 'uses_inclusive_taxes') this.usesInclusiveTaxes = false, @JsonKey(name: 'calculate_tax_by_amount') this.calculateTaxByAmount = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, final  List<DocumentApi>? documents}): _documents = documents;
  factory _ExpenseApi.fromJson(Map<String, dynamic> json) => _$ExpenseApiFromJson(json);

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
// Money — Object so number / string are both decoded; parsed via
// parseMoney in the domain factory.
@override@JsonKey() final  Object amount;
@override@JsonKey(name: 'foreign_amount') final  Object foreignAmount;
@override@JsonKey(name: 'exchange_rate') final  Object exchangeRate;
@override@JsonKey(name: 'tax_amount1') final  Object taxAmount1;
@override@JsonKey(name: 'tax_amount2') final  Object taxAmount2;
@override@JsonKey(name: 'tax_amount3') final  Object taxAmount3;
@override@JsonKey(name: 'tax_rate1') final  Object taxRate1;
@override@JsonKey(name: 'tax_rate2') final  Object taxRate2;
@override@JsonKey(name: 'tax_rate3') final  Object taxRate3;
// Bools
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'should_be_invoiced') final  bool shouldBeInvoiced;
@override@JsonKey(name: 'invoice_documents') final  bool invoiceDocuments;
@override@JsonKey(name: 'uses_inclusive_taxes') final  bool usesInclusiveTaxes;
@override@JsonKey(name: 'calculate_tax_by_amount') final  bool calculateTaxByAmount;
// Timestamps
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
// Nullable so JSON-omitted (→ null) is distinguishable from
// JSON-present-and-empty (→ const []). Same convention as `ProjectApi`.
 final  List<DocumentApi>? _documents;
// Nullable so JSON-omitted (→ null) is distinguishable from
// JSON-present-and-empty (→ const []). Same convention as `ProjectApi`.
@override List<DocumentApi>? get documents {
  final value = _documents;
  if (value == null) return null;
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of ExpenseApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseApiCopyWith<_ExpenseApi> get copyWith => __$ExpenseApiCopyWithImpl<_ExpenseApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpenseApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.invoiceCurrencyId, invoiceCurrencyId) || other.invoiceCurrencyId == invoiceCurrencyId)&&(identical(other.expenseCurrencyId, expenseCurrencyId) || other.expenseCurrencyId == expenseCurrencyId)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.paymentTypeId, paymentTypeId) || other.paymentTypeId == paymentTypeId)&&(identical(other.recurringExpenseId, recurringExpenseId) || other.recurringExpenseId == recurringExpenseId)&&(identical(other.privateNotes, privateNotes) || other.privateNotes == privateNotes)&&(identical(other.publicNotes, publicNotes) || other.publicNotes == publicNotes)&&(identical(other.transactionReference, transactionReference) || other.transactionReference == transactionReference)&&(identical(other.transactionId, transactionId) || other.transactionId == transactionId)&&(identical(other.date, date) || other.date == date)&&(identical(other.number, number) || other.number == number)&&(identical(other.paymentDate, paymentDate) || other.paymentDate == paymentDate)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.taxName1, taxName1) || other.taxName1 == taxName1)&&(identical(other.taxName2, taxName2) || other.taxName2 == taxName2)&&(identical(other.taxName3, taxName3) || other.taxName3 == taxName3)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.entityType, entityType) || other.entityType == entityType)&&const DeepCollectionEquality().equals(other.amount, amount)&&const DeepCollectionEquality().equals(other.foreignAmount, foreignAmount)&&const DeepCollectionEquality().equals(other.exchangeRate, exchangeRate)&&const DeepCollectionEquality().equals(other.taxAmount1, taxAmount1)&&const DeepCollectionEquality().equals(other.taxAmount2, taxAmount2)&&const DeepCollectionEquality().equals(other.taxAmount3, taxAmount3)&&const DeepCollectionEquality().equals(other.taxRate1, taxRate1)&&const DeepCollectionEquality().equals(other.taxRate2, taxRate2)&&const DeepCollectionEquality().equals(other.taxRate3, taxRate3)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.shouldBeInvoiced, shouldBeInvoiced) || other.shouldBeInvoiced == shouldBeInvoiced)&&(identical(other.invoiceDocuments, invoiceDocuments) || other.invoiceDocuments == invoiceDocuments)&&(identical(other.usesInclusiveTaxes, usesInclusiveTaxes) || other.usesInclusiveTaxes == usesInclusiveTaxes)&&(identical(other.calculateTaxByAmount, calculateTaxByAmount) || other.calculateTaxByAmount == calculateTaxByAmount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other._documents, _documents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,vendorId,invoiceId,clientId,bankId,invoiceCurrencyId,expenseCurrencyId,currencyId,categoryId,paymentTypeId,recurringExpenseId,privateNotes,publicNotes,transactionReference,transactionId,date,number,paymentDate,customValue1,customValue2,customValue3,customValue4,taxName1,taxName2,taxName3,projectId,entityType,const DeepCollectionEquality().hash(amount),const DeepCollectionEquality().hash(foreignAmount),const DeepCollectionEquality().hash(exchangeRate),const DeepCollectionEquality().hash(taxAmount1),const DeepCollectionEquality().hash(taxAmount2),const DeepCollectionEquality().hash(taxAmount3),const DeepCollectionEquality().hash(taxRate1),const DeepCollectionEquality().hash(taxRate2),const DeepCollectionEquality().hash(taxRate3),isDeleted,shouldBeInvoiced,invoiceDocuments,usesInclusiveTaxes,calculateTaxByAmount,createdAt,updatedAt,archivedAt,const DeepCollectionEquality().hash(_documents)]);

@override
String toString() {
  return 'ExpenseApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, vendorId: $vendorId, invoiceId: $invoiceId, clientId: $clientId, bankId: $bankId, invoiceCurrencyId: $invoiceCurrencyId, expenseCurrencyId: $expenseCurrencyId, currencyId: $currencyId, categoryId: $categoryId, paymentTypeId: $paymentTypeId, recurringExpenseId: $recurringExpenseId, privateNotes: $privateNotes, publicNotes: $publicNotes, transactionReference: $transactionReference, transactionId: $transactionId, date: $date, number: $number, paymentDate: $paymentDate, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, taxName1: $taxName1, taxName2: $taxName2, taxName3: $taxName3, projectId: $projectId, entityType: $entityType, amount: $amount, foreignAmount: $foreignAmount, exchangeRate: $exchangeRate, taxAmount1: $taxAmount1, taxAmount2: $taxAmount2, taxAmount3: $taxAmount3, taxRate1: $taxRate1, taxRate2: $taxRate2, taxRate3: $taxRate3, isDeleted: $isDeleted, shouldBeInvoiced: $shouldBeInvoiced, invoiceDocuments: $invoiceDocuments, usesInclusiveTaxes: $usesInclusiveTaxes, calculateTaxByAmount: $calculateTaxByAmount, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, documents: $documents)';
}


}

/// @nodoc
abstract mixin class _$ExpenseApiCopyWith<$Res> implements $ExpenseApiCopyWith<$Res> {
  factory _$ExpenseApiCopyWith(_ExpenseApi value, $Res Function(_ExpenseApi) _then) = __$ExpenseApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'invoice_id') String invoiceId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'bank_id') String bankId,@JsonKey(name: 'invoice_currency_id') String invoiceCurrencyId,@JsonKey(name: 'expense_currency_id') String expenseCurrencyId,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'category_id') String categoryId,@JsonKey(name: 'payment_type_id') String paymentTypeId,@JsonKey(name: 'recurring_expense_id') String recurringExpenseId,@JsonKey(name: 'private_notes') String privateNotes,@JsonKey(name: 'public_notes') String publicNotes,@JsonKey(name: 'transaction_reference') String transactionReference,@JsonKey(name: 'transaction_id') String transactionId, String date, String number,@JsonKey(name: 'payment_date') String paymentDate,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'tax_name1') String taxName1,@JsonKey(name: 'tax_name2') String taxName2,@JsonKey(name: 'tax_name3') String taxName3,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'entity_type') String entityType, Object amount,@JsonKey(name: 'foreign_amount') Object foreignAmount,@JsonKey(name: 'exchange_rate') Object exchangeRate,@JsonKey(name: 'tax_amount1') Object taxAmount1,@JsonKey(name: 'tax_amount2') Object taxAmount2,@JsonKey(name: 'tax_amount3') Object taxAmount3,@JsonKey(name: 'tax_rate1') Object taxRate1,@JsonKey(name: 'tax_rate2') Object taxRate2,@JsonKey(name: 'tax_rate3') Object taxRate3,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'should_be_invoiced') bool shouldBeInvoiced,@JsonKey(name: 'invoice_documents') bool invoiceDocuments,@JsonKey(name: 'uses_inclusive_taxes') bool usesInclusiveTaxes,@JsonKey(name: 'calculate_tax_by_amount') bool calculateTaxByAmount,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt, List<DocumentApi>? documents
});




}
/// @nodoc
class __$ExpenseApiCopyWithImpl<$Res>
    implements _$ExpenseApiCopyWith<$Res> {
  __$ExpenseApiCopyWithImpl(this._self, this._then);

  final _ExpenseApi _self;
  final $Res Function(_ExpenseApi) _then;

/// Create a copy of ExpenseApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? vendorId = null,Object? invoiceId = null,Object? clientId = null,Object? bankId = null,Object? invoiceCurrencyId = null,Object? expenseCurrencyId = null,Object? currencyId = null,Object? categoryId = null,Object? paymentTypeId = null,Object? recurringExpenseId = null,Object? privateNotes = null,Object? publicNotes = null,Object? transactionReference = null,Object? transactionId = null,Object? date = null,Object? number = null,Object? paymentDate = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? taxName1 = null,Object? taxName2 = null,Object? taxName3 = null,Object? projectId = null,Object? entityType = null,Object? amount = null,Object? foreignAmount = null,Object? exchangeRate = null,Object? taxAmount1 = null,Object? taxAmount2 = null,Object? taxAmount3 = null,Object? taxRate1 = null,Object? taxRate2 = null,Object? taxRate3 = null,Object? isDeleted = null,Object? shouldBeInvoiced = null,Object? invoiceDocuments = null,Object? usesInclusiveTaxes = null,Object? calculateTaxByAmount = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? documents = freezed,}) {
  return _then(_ExpenseApi(
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
as String,amount: null == amount ? _self.amount : amount ,foreignAmount: null == foreignAmount ? _self.foreignAmount : foreignAmount ,exchangeRate: null == exchangeRate ? _self.exchangeRate : exchangeRate ,taxAmount1: null == taxAmount1 ? _self.taxAmount1 : taxAmount1 ,taxAmount2: null == taxAmount2 ? _self.taxAmount2 : taxAmount2 ,taxAmount3: null == taxAmount3 ? _self.taxAmount3 : taxAmount3 ,taxRate1: null == taxRate1 ? _self.taxRate1 : taxRate1 ,taxRate2: null == taxRate2 ? _self.taxRate2 : taxRate2 ,taxRate3: null == taxRate3 ? _self.taxRate3 : taxRate3 ,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,shouldBeInvoiced: null == shouldBeInvoiced ? _self.shouldBeInvoiced : shouldBeInvoiced // ignore: cast_nullable_to_non_nullable
as bool,invoiceDocuments: null == invoiceDocuments ? _self.invoiceDocuments : invoiceDocuments // ignore: cast_nullable_to_non_nullable
as bool,usesInclusiveTaxes: null == usesInclusiveTaxes ? _self.usesInclusiveTaxes : usesInclusiveTaxes // ignore: cast_nullable_to_non_nullable
as bool,calculateTaxByAmount: null == calculateTaxByAmount ? _self.calculateTaxByAmount : calculateTaxByAmount // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,documents: freezed == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,
  ));
}


}


/// @nodoc
mixin _$ExpenseListApi {

@JsonKey(fromJson: _expenseListData) List<ExpenseApi> get data;
/// Create a copy of ExpenseListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseListApiCopyWith<ExpenseListApi> get copyWith => _$ExpenseListApiCopyWithImpl<ExpenseListApi>(this as ExpenseListApi, _$identity);

  /// Serializes this ExpenseListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpenseListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'ExpenseListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $ExpenseListApiCopyWith<$Res>  {
  factory $ExpenseListApiCopyWith(ExpenseListApi value, $Res Function(ExpenseListApi) _then) = _$ExpenseListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _expenseListData) List<ExpenseApi> data
});




}
/// @nodoc
class _$ExpenseListApiCopyWithImpl<$Res>
    implements $ExpenseListApiCopyWith<$Res> {
  _$ExpenseListApiCopyWithImpl(this._self, this._then);

  final ExpenseListApi _self;
  final $Res Function(ExpenseListApi) _then;

/// Create a copy of ExpenseListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<ExpenseApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [ExpenseListApi].
extension ExpenseListApiPatterns on ExpenseListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpenseListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpenseListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpenseListApi value)  $default,){
final _that = this;
switch (_that) {
case _ExpenseListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpenseListApi value)?  $default,){
final _that = this;
switch (_that) {
case _ExpenseListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _expenseListData)  List<ExpenseApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpenseListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _expenseListData)  List<ExpenseApi> data)  $default,) {final _that = this;
switch (_that) {
case _ExpenseListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _expenseListData)  List<ExpenseApi> data)?  $default,) {final _that = this;
switch (_that) {
case _ExpenseListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpenseListApi implements ExpenseListApi {
  const _ExpenseListApi({@JsonKey(fromJson: _expenseListData) final  List<ExpenseApi> data = const []}): _data = data;
  factory _ExpenseListApi.fromJson(Map<String, dynamic> json) => _$ExpenseListApiFromJson(json);

 final  List<ExpenseApi> _data;
@override@JsonKey(fromJson: _expenseListData) List<ExpenseApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of ExpenseListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseListApiCopyWith<_ExpenseListApi> get copyWith => __$ExpenseListApiCopyWithImpl<_ExpenseListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpenseListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'ExpenseListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ExpenseListApiCopyWith<$Res> implements $ExpenseListApiCopyWith<$Res> {
  factory _$ExpenseListApiCopyWith(_ExpenseListApi value, $Res Function(_ExpenseListApi) _then) = __$ExpenseListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _expenseListData) List<ExpenseApi> data
});




}
/// @nodoc
class __$ExpenseListApiCopyWithImpl<$Res>
    implements _$ExpenseListApiCopyWith<$Res> {
  __$ExpenseListApiCopyWithImpl(this._self, this._then);

  final _ExpenseListApi _self;
  final $Res Function(_ExpenseListApi) _then;

/// Create a copy of ExpenseListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_ExpenseListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<ExpenseApi>,
  ));
}


}


/// @nodoc
mixin _$ExpenseItemApi {

 ExpenseApi get data;
/// Create a copy of ExpenseItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseItemApiCopyWith<ExpenseItemApi> get copyWith => _$ExpenseItemApiCopyWithImpl<ExpenseItemApi>(this as ExpenseItemApi, _$identity);

  /// Serializes this ExpenseItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpenseItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'ExpenseItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $ExpenseItemApiCopyWith<$Res>  {
  factory $ExpenseItemApiCopyWith(ExpenseItemApi value, $Res Function(ExpenseItemApi) _then) = _$ExpenseItemApiCopyWithImpl;
@useResult
$Res call({
 ExpenseApi data
});


$ExpenseApiCopyWith<$Res> get data;

}
/// @nodoc
class _$ExpenseItemApiCopyWithImpl<$Res>
    implements $ExpenseItemApiCopyWith<$Res> {
  _$ExpenseItemApiCopyWithImpl(this._self, this._then);

  final ExpenseItemApi _self;
  final $Res Function(ExpenseItemApi) _then;

/// Create a copy of ExpenseItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ExpenseApi,
  ));
}
/// Create a copy of ExpenseItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExpenseApiCopyWith<$Res> get data {
  
  return $ExpenseApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [ExpenseItemApi].
extension ExpenseItemApiPatterns on ExpenseItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpenseItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpenseItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpenseItemApi value)  $default,){
final _that = this;
switch (_that) {
case _ExpenseItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpenseItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _ExpenseItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ExpenseApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpenseItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ExpenseApi data)  $default,) {final _that = this;
switch (_that) {
case _ExpenseItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ExpenseApi data)?  $default,) {final _that = this;
switch (_that) {
case _ExpenseItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpenseItemApi implements ExpenseItemApi {
  const _ExpenseItemApi({required this.data});
  factory _ExpenseItemApi.fromJson(Map<String, dynamic> json) => _$ExpenseItemApiFromJson(json);

@override final  ExpenseApi data;

/// Create a copy of ExpenseItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseItemApiCopyWith<_ExpenseItemApi> get copyWith => __$ExpenseItemApiCopyWithImpl<_ExpenseItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpenseItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'ExpenseItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ExpenseItemApiCopyWith<$Res> implements $ExpenseItemApiCopyWith<$Res> {
  factory _$ExpenseItemApiCopyWith(_ExpenseItemApi value, $Res Function(_ExpenseItemApi) _then) = __$ExpenseItemApiCopyWithImpl;
@override @useResult
$Res call({
 ExpenseApi data
});


@override $ExpenseApiCopyWith<$Res> get data;

}
/// @nodoc
class __$ExpenseItemApiCopyWithImpl<$Res>
    implements _$ExpenseItemApiCopyWith<$Res> {
  __$ExpenseItemApiCopyWithImpl(this._self, this._then);

  final _ExpenseItemApi _self;
  final $Res Function(_ExpenseItemApi) _then;

/// Create a copy of ExpenseItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_ExpenseItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ExpenseApi,
  ));
}

/// Create a copy of ExpenseItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExpenseApiCopyWith<$Res> get data {
  
  return $ExpenseApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
