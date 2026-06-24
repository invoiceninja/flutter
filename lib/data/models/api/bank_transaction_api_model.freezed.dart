// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bank_transaction_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BankTransactionApi {

 String get id; Object get amount;@JsonKey(name: 'currency_id') String get currencyId;@JsonKey(name: 'category_type') String get categoryType;@JsonKey(name: 'base_type') String get baseType; String get date;@JsonKey(name: 'bank_integration_id') String get bankIntegrationId; String get description;@JsonKey(name: 'status_id') String get statusId;@JsonKey(name: 'ninja_category_id') String get ninjaCategoryId;@JsonKey(name: 'invoice_ids') String get invoiceIds;@JsonKey(name: 'payment_id') String get paymentId;@JsonKey(name: 'expense_id') String get expenseId;@JsonKey(name: 'vendor_id') String get vendorId;// Provider transaction id — int on the wire, kept as Object so we
// can accept either number or string.
@JsonKey(name: 'transaction_id') Object get transactionId;@JsonKey(name: 'bank_transaction_rule_id') String get bankTransactionRuleId;@JsonKey(name: 'participant_name') String get participantName; String get participant;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;
/// Create a copy of BankTransactionApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BankTransactionApiCopyWith<BankTransactionApi> get copyWith => _$BankTransactionApiCopyWithImpl<BankTransactionApi>(this as BankTransactionApi, _$identity);

  /// Serializes this BankTransactionApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BankTransactionApi&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.amount, amount)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.categoryType, categoryType) || other.categoryType == categoryType)&&(identical(other.baseType, baseType) || other.baseType == baseType)&&(identical(other.date, date) || other.date == date)&&(identical(other.bankIntegrationId, bankIntegrationId) || other.bankIntegrationId == bankIntegrationId)&&(identical(other.description, description) || other.description == description)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.ninjaCategoryId, ninjaCategoryId) || other.ninjaCategoryId == ninjaCategoryId)&&(identical(other.invoiceIds, invoiceIds) || other.invoiceIds == invoiceIds)&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.expenseId, expenseId) || other.expenseId == expenseId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&const DeepCollectionEquality().equals(other.transactionId, transactionId)&&(identical(other.bankTransactionRuleId, bankTransactionRuleId) || other.bankTransactionRuleId == bankTransactionRuleId)&&(identical(other.participantName, participantName) || other.participantName == participantName)&&(identical(other.participant, participant) || other.participant == participant)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,const DeepCollectionEquality().hash(amount),currencyId,categoryType,baseType,date,bankIntegrationId,description,statusId,ninjaCategoryId,invoiceIds,paymentId,expenseId,vendorId,const DeepCollectionEquality().hash(transactionId),bankTransactionRuleId,participantName,participant,isDeleted,createdAt,updatedAt,archivedAt]);

@override
String toString() {
  return 'BankTransactionApi(id: $id, amount: $amount, currencyId: $currencyId, categoryType: $categoryType, baseType: $baseType, date: $date, bankIntegrationId: $bankIntegrationId, description: $description, statusId: $statusId, ninjaCategoryId: $ninjaCategoryId, invoiceIds: $invoiceIds, paymentId: $paymentId, expenseId: $expenseId, vendorId: $vendorId, transactionId: $transactionId, bankTransactionRuleId: $bankTransactionRuleId, participantName: $participantName, participant: $participant, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class $BankTransactionApiCopyWith<$Res>  {
  factory $BankTransactionApiCopyWith(BankTransactionApi value, $Res Function(BankTransactionApi) _then) = _$BankTransactionApiCopyWithImpl;
@useResult
$Res call({
 String id, Object amount,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'category_type') String categoryType,@JsonKey(name: 'base_type') String baseType, String date,@JsonKey(name: 'bank_integration_id') String bankIntegrationId, String description,@JsonKey(name: 'status_id') String statusId,@JsonKey(name: 'ninja_category_id') String ninjaCategoryId,@JsonKey(name: 'invoice_ids') String invoiceIds,@JsonKey(name: 'payment_id') String paymentId,@JsonKey(name: 'expense_id') String expenseId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'transaction_id') Object transactionId,@JsonKey(name: 'bank_transaction_rule_id') String bankTransactionRuleId,@JsonKey(name: 'participant_name') String participantName, String participant,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class _$BankTransactionApiCopyWithImpl<$Res>
    implements $BankTransactionApiCopyWith<$Res> {
  _$BankTransactionApiCopyWithImpl(this._self, this._then);

  final BankTransactionApi _self;
  final $Res Function(BankTransactionApi) _then;

/// Create a copy of BankTransactionApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? amount = null,Object? currencyId = null,Object? categoryType = null,Object? baseType = null,Object? date = null,Object? bankIntegrationId = null,Object? description = null,Object? statusId = null,Object? ninjaCategoryId = null,Object? invoiceIds = null,Object? paymentId = null,Object? expenseId = null,Object? vendorId = null,Object? transactionId = null,Object? bankTransactionRuleId = null,Object? participantName = null,Object? participant = null,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,categoryType: null == categoryType ? _self.categoryType : categoryType // ignore: cast_nullable_to_non_nullable
as String,baseType: null == baseType ? _self.baseType : baseType // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,bankIntegrationId: null == bankIntegrationId ? _self.bankIntegrationId : bankIntegrationId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,ninjaCategoryId: null == ninjaCategoryId ? _self.ninjaCategoryId : ninjaCategoryId // ignore: cast_nullable_to_non_nullable
as String,invoiceIds: null == invoiceIds ? _self.invoiceIds : invoiceIds // ignore: cast_nullable_to_non_nullable
as String,paymentId: null == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as String,expenseId: null == expenseId ? _self.expenseId : expenseId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,transactionId: null == transactionId ? _self.transactionId : transactionId ,bankTransactionRuleId: null == bankTransactionRuleId ? _self.bankTransactionRuleId : bankTransactionRuleId // ignore: cast_nullable_to_non_nullable
as String,participantName: null == participantName ? _self.participantName : participantName // ignore: cast_nullable_to_non_nullable
as String,participant: null == participant ? _self.participant : participant // ignore: cast_nullable_to_non_nullable
as String,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BankTransactionApi].
extension BankTransactionApiPatterns on BankTransactionApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BankTransactionApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BankTransactionApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BankTransactionApi value)  $default,){
final _that = this;
switch (_that) {
case _BankTransactionApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BankTransactionApi value)?  $default,){
final _that = this;
switch (_that) {
case _BankTransactionApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  Object amount, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'category_type')  String categoryType, @JsonKey(name: 'base_type')  String baseType,  String date, @JsonKey(name: 'bank_integration_id')  String bankIntegrationId,  String description, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'ninja_category_id')  String ninjaCategoryId, @JsonKey(name: 'invoice_ids')  String invoiceIds, @JsonKey(name: 'payment_id')  String paymentId, @JsonKey(name: 'expense_id')  String expenseId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'transaction_id')  Object transactionId, @JsonKey(name: 'bank_transaction_rule_id')  String bankTransactionRuleId, @JsonKey(name: 'participant_name')  String participantName,  String participant, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BankTransactionApi() when $default != null:
return $default(_that.id,_that.amount,_that.currencyId,_that.categoryType,_that.baseType,_that.date,_that.bankIntegrationId,_that.description,_that.statusId,_that.ninjaCategoryId,_that.invoiceIds,_that.paymentId,_that.expenseId,_that.vendorId,_that.transactionId,_that.bankTransactionRuleId,_that.participantName,_that.participant,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  Object amount, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'category_type')  String categoryType, @JsonKey(name: 'base_type')  String baseType,  String date, @JsonKey(name: 'bank_integration_id')  String bankIntegrationId,  String description, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'ninja_category_id')  String ninjaCategoryId, @JsonKey(name: 'invoice_ids')  String invoiceIds, @JsonKey(name: 'payment_id')  String paymentId, @JsonKey(name: 'expense_id')  String expenseId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'transaction_id')  Object transactionId, @JsonKey(name: 'bank_transaction_rule_id')  String bankTransactionRuleId, @JsonKey(name: 'participant_name')  String participantName,  String participant, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)  $default,) {final _that = this;
switch (_that) {
case _BankTransactionApi():
return $default(_that.id,_that.amount,_that.currencyId,_that.categoryType,_that.baseType,_that.date,_that.bankIntegrationId,_that.description,_that.statusId,_that.ninjaCategoryId,_that.invoiceIds,_that.paymentId,_that.expenseId,_that.vendorId,_that.transactionId,_that.bankTransactionRuleId,_that.participantName,_that.participant,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  Object amount, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'category_type')  String categoryType, @JsonKey(name: 'base_type')  String baseType,  String date, @JsonKey(name: 'bank_integration_id')  String bankIntegrationId,  String description, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'ninja_category_id')  String ninjaCategoryId, @JsonKey(name: 'invoice_ids')  String invoiceIds, @JsonKey(name: 'payment_id')  String paymentId, @JsonKey(name: 'expense_id')  String expenseId, @JsonKey(name: 'vendor_id')  String vendorId, @JsonKey(name: 'transaction_id')  Object transactionId, @JsonKey(name: 'bank_transaction_rule_id')  String bankTransactionRuleId, @JsonKey(name: 'participant_name')  String participantName,  String participant, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _BankTransactionApi() when $default != null:
return $default(_that.id,_that.amount,_that.currencyId,_that.categoryType,_that.baseType,_that.date,_that.bankIntegrationId,_that.description,_that.statusId,_that.ninjaCategoryId,_that.invoiceIds,_that.paymentId,_that.expenseId,_that.vendorId,_that.transactionId,_that.bankTransactionRuleId,_that.participantName,_that.participant,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _BankTransactionApi implements BankTransactionApi {
  const _BankTransactionApi({this.id = '', this.amount = '0', @JsonKey(name: 'currency_id') this.currencyId = '', @JsonKey(name: 'category_type') this.categoryType = '', @JsonKey(name: 'base_type') this.baseType = '', this.date = '', @JsonKey(name: 'bank_integration_id') this.bankIntegrationId = '', this.description = '', @JsonKey(name: 'status_id') this.statusId = '1', @JsonKey(name: 'ninja_category_id') this.ninjaCategoryId = '', @JsonKey(name: 'invoice_ids') this.invoiceIds = '', @JsonKey(name: 'payment_id') this.paymentId = '', @JsonKey(name: 'expense_id') this.expenseId = '', @JsonKey(name: 'vendor_id') this.vendorId = '', @JsonKey(name: 'transaction_id') this.transactionId = 0, @JsonKey(name: 'bank_transaction_rule_id') this.bankTransactionRuleId = '', @JsonKey(name: 'participant_name') this.participantName = '', this.participant = '', @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0});
  factory _BankTransactionApi.fromJson(Map<String, dynamic> json) => _$BankTransactionApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  Object amount;
@override@JsonKey(name: 'currency_id') final  String currencyId;
@override@JsonKey(name: 'category_type') final  String categoryType;
@override@JsonKey(name: 'base_type') final  String baseType;
@override@JsonKey() final  String date;
@override@JsonKey(name: 'bank_integration_id') final  String bankIntegrationId;
@override@JsonKey() final  String description;
@override@JsonKey(name: 'status_id') final  String statusId;
@override@JsonKey(name: 'ninja_category_id') final  String ninjaCategoryId;
@override@JsonKey(name: 'invoice_ids') final  String invoiceIds;
@override@JsonKey(name: 'payment_id') final  String paymentId;
@override@JsonKey(name: 'expense_id') final  String expenseId;
@override@JsonKey(name: 'vendor_id') final  String vendorId;
// Provider transaction id — int on the wire, kept as Object so we
// can accept either number or string.
@override@JsonKey(name: 'transaction_id') final  Object transactionId;
@override@JsonKey(name: 'bank_transaction_rule_id') final  String bankTransactionRuleId;
@override@JsonKey(name: 'participant_name') final  String participantName;
@override@JsonKey() final  String participant;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;

/// Create a copy of BankTransactionApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BankTransactionApiCopyWith<_BankTransactionApi> get copyWith => __$BankTransactionApiCopyWithImpl<_BankTransactionApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BankTransactionApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BankTransactionApi&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.amount, amount)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.categoryType, categoryType) || other.categoryType == categoryType)&&(identical(other.baseType, baseType) || other.baseType == baseType)&&(identical(other.date, date) || other.date == date)&&(identical(other.bankIntegrationId, bankIntegrationId) || other.bankIntegrationId == bankIntegrationId)&&(identical(other.description, description) || other.description == description)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.ninjaCategoryId, ninjaCategoryId) || other.ninjaCategoryId == ninjaCategoryId)&&(identical(other.invoiceIds, invoiceIds) || other.invoiceIds == invoiceIds)&&(identical(other.paymentId, paymentId) || other.paymentId == paymentId)&&(identical(other.expenseId, expenseId) || other.expenseId == expenseId)&&(identical(other.vendorId, vendorId) || other.vendorId == vendorId)&&const DeepCollectionEquality().equals(other.transactionId, transactionId)&&(identical(other.bankTransactionRuleId, bankTransactionRuleId) || other.bankTransactionRuleId == bankTransactionRuleId)&&(identical(other.participantName, participantName) || other.participantName == participantName)&&(identical(other.participant, participant) || other.participant == participant)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,const DeepCollectionEquality().hash(amount),currencyId,categoryType,baseType,date,bankIntegrationId,description,statusId,ninjaCategoryId,invoiceIds,paymentId,expenseId,vendorId,const DeepCollectionEquality().hash(transactionId),bankTransactionRuleId,participantName,participant,isDeleted,createdAt,updatedAt,archivedAt]);

@override
String toString() {
  return 'BankTransactionApi(id: $id, amount: $amount, currencyId: $currencyId, categoryType: $categoryType, baseType: $baseType, date: $date, bankIntegrationId: $bankIntegrationId, description: $description, statusId: $statusId, ninjaCategoryId: $ninjaCategoryId, invoiceIds: $invoiceIds, paymentId: $paymentId, expenseId: $expenseId, vendorId: $vendorId, transactionId: $transactionId, bankTransactionRuleId: $bankTransactionRuleId, participantName: $participantName, participant: $participant, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$BankTransactionApiCopyWith<$Res> implements $BankTransactionApiCopyWith<$Res> {
  factory _$BankTransactionApiCopyWith(_BankTransactionApi value, $Res Function(_BankTransactionApi) _then) = __$BankTransactionApiCopyWithImpl;
@override @useResult
$Res call({
 String id, Object amount,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'category_type') String categoryType,@JsonKey(name: 'base_type') String baseType, String date,@JsonKey(name: 'bank_integration_id') String bankIntegrationId, String description,@JsonKey(name: 'status_id') String statusId,@JsonKey(name: 'ninja_category_id') String ninjaCategoryId,@JsonKey(name: 'invoice_ids') String invoiceIds,@JsonKey(name: 'payment_id') String paymentId,@JsonKey(name: 'expense_id') String expenseId,@JsonKey(name: 'vendor_id') String vendorId,@JsonKey(name: 'transaction_id') Object transactionId,@JsonKey(name: 'bank_transaction_rule_id') String bankTransactionRuleId,@JsonKey(name: 'participant_name') String participantName, String participant,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class __$BankTransactionApiCopyWithImpl<$Res>
    implements _$BankTransactionApiCopyWith<$Res> {
  __$BankTransactionApiCopyWithImpl(this._self, this._then);

  final _BankTransactionApi _self;
  final $Res Function(_BankTransactionApi) _then;

/// Create a copy of BankTransactionApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? amount = null,Object? currencyId = null,Object? categoryType = null,Object? baseType = null,Object? date = null,Object? bankIntegrationId = null,Object? description = null,Object? statusId = null,Object? ninjaCategoryId = null,Object? invoiceIds = null,Object? paymentId = null,Object? expenseId = null,Object? vendorId = null,Object? transactionId = null,Object? bankTransactionRuleId = null,Object? participantName = null,Object? participant = null,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_BankTransactionApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,categoryType: null == categoryType ? _self.categoryType : categoryType // ignore: cast_nullable_to_non_nullable
as String,baseType: null == baseType ? _self.baseType : baseType // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,bankIntegrationId: null == bankIntegrationId ? _self.bankIntegrationId : bankIntegrationId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,ninjaCategoryId: null == ninjaCategoryId ? _self.ninjaCategoryId : ninjaCategoryId // ignore: cast_nullable_to_non_nullable
as String,invoiceIds: null == invoiceIds ? _self.invoiceIds : invoiceIds // ignore: cast_nullable_to_non_nullable
as String,paymentId: null == paymentId ? _self.paymentId : paymentId // ignore: cast_nullable_to_non_nullable
as String,expenseId: null == expenseId ? _self.expenseId : expenseId // ignore: cast_nullable_to_non_nullable
as String,vendorId: null == vendorId ? _self.vendorId : vendorId // ignore: cast_nullable_to_non_nullable
as String,transactionId: null == transactionId ? _self.transactionId : transactionId ,bankTransactionRuleId: null == bankTransactionRuleId ? _self.bankTransactionRuleId : bankTransactionRuleId // ignore: cast_nullable_to_non_nullable
as String,participantName: null == participantName ? _self.participantName : participantName // ignore: cast_nullable_to_non_nullable
as String,participant: null == participant ? _self.participant : participant // ignore: cast_nullable_to_non_nullable
as String,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$BankTransactionListApi {

@JsonKey(fromJson: _bankTransactionListData) List<BankTransactionApi> get data;
/// Create a copy of BankTransactionListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BankTransactionListApiCopyWith<BankTransactionListApi> get copyWith => _$BankTransactionListApiCopyWithImpl<BankTransactionListApi>(this as BankTransactionListApi, _$identity);

  /// Serializes this BankTransactionListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BankTransactionListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'BankTransactionListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $BankTransactionListApiCopyWith<$Res>  {
  factory $BankTransactionListApiCopyWith(BankTransactionListApi value, $Res Function(BankTransactionListApi) _then) = _$BankTransactionListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _bankTransactionListData) List<BankTransactionApi> data
});




}
/// @nodoc
class _$BankTransactionListApiCopyWithImpl<$Res>
    implements $BankTransactionListApiCopyWith<$Res> {
  _$BankTransactionListApiCopyWithImpl(this._self, this._then);

  final BankTransactionListApi _self;
  final $Res Function(BankTransactionListApi) _then;

/// Create a copy of BankTransactionListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<BankTransactionApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [BankTransactionListApi].
extension BankTransactionListApiPatterns on BankTransactionListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BankTransactionListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BankTransactionListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BankTransactionListApi value)  $default,){
final _that = this;
switch (_that) {
case _BankTransactionListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BankTransactionListApi value)?  $default,){
final _that = this;
switch (_that) {
case _BankTransactionListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _bankTransactionListData)  List<BankTransactionApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BankTransactionListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _bankTransactionListData)  List<BankTransactionApi> data)  $default,) {final _that = this;
switch (_that) {
case _BankTransactionListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _bankTransactionListData)  List<BankTransactionApi> data)?  $default,) {final _that = this;
switch (_that) {
case _BankTransactionListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BankTransactionListApi implements BankTransactionListApi {
  const _BankTransactionListApi({@JsonKey(fromJson: _bankTransactionListData) final  List<BankTransactionApi> data = const []}): _data = data;
  factory _BankTransactionListApi.fromJson(Map<String, dynamic> json) => _$BankTransactionListApiFromJson(json);

 final  List<BankTransactionApi> _data;
@override@JsonKey(fromJson: _bankTransactionListData) List<BankTransactionApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of BankTransactionListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BankTransactionListApiCopyWith<_BankTransactionListApi> get copyWith => __$BankTransactionListApiCopyWithImpl<_BankTransactionListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BankTransactionListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BankTransactionListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'BankTransactionListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$BankTransactionListApiCopyWith<$Res> implements $BankTransactionListApiCopyWith<$Res> {
  factory _$BankTransactionListApiCopyWith(_BankTransactionListApi value, $Res Function(_BankTransactionListApi) _then) = __$BankTransactionListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _bankTransactionListData) List<BankTransactionApi> data
});




}
/// @nodoc
class __$BankTransactionListApiCopyWithImpl<$Res>
    implements _$BankTransactionListApiCopyWith<$Res> {
  __$BankTransactionListApiCopyWithImpl(this._self, this._then);

  final _BankTransactionListApi _self;
  final $Res Function(_BankTransactionListApi) _then;

/// Create a copy of BankTransactionListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_BankTransactionListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<BankTransactionApi>,
  ));
}


}


/// @nodoc
mixin _$BankTransactionItemApi {

 BankTransactionApi get data;
/// Create a copy of BankTransactionItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BankTransactionItemApiCopyWith<BankTransactionItemApi> get copyWith => _$BankTransactionItemApiCopyWithImpl<BankTransactionItemApi>(this as BankTransactionItemApi, _$identity);

  /// Serializes this BankTransactionItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BankTransactionItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'BankTransactionItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $BankTransactionItemApiCopyWith<$Res>  {
  factory $BankTransactionItemApiCopyWith(BankTransactionItemApi value, $Res Function(BankTransactionItemApi) _then) = _$BankTransactionItemApiCopyWithImpl;
@useResult
$Res call({
 BankTransactionApi data
});


$BankTransactionApiCopyWith<$Res> get data;

}
/// @nodoc
class _$BankTransactionItemApiCopyWithImpl<$Res>
    implements $BankTransactionItemApiCopyWith<$Res> {
  _$BankTransactionItemApiCopyWithImpl(this._self, this._then);

  final BankTransactionItemApi _self;
  final $Res Function(BankTransactionItemApi) _then;

/// Create a copy of BankTransactionItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as BankTransactionApi,
  ));
}
/// Create a copy of BankTransactionItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BankTransactionApiCopyWith<$Res> get data {
  
  return $BankTransactionApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [BankTransactionItemApi].
extension BankTransactionItemApiPatterns on BankTransactionItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BankTransactionItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BankTransactionItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BankTransactionItemApi value)  $default,){
final _that = this;
switch (_that) {
case _BankTransactionItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BankTransactionItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _BankTransactionItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BankTransactionApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BankTransactionItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BankTransactionApi data)  $default,) {final _that = this;
switch (_that) {
case _BankTransactionItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BankTransactionApi data)?  $default,) {final _that = this;
switch (_that) {
case _BankTransactionItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BankTransactionItemApi implements BankTransactionItemApi {
  const _BankTransactionItemApi({required this.data});
  factory _BankTransactionItemApi.fromJson(Map<String, dynamic> json) => _$BankTransactionItemApiFromJson(json);

@override final  BankTransactionApi data;

/// Create a copy of BankTransactionItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BankTransactionItemApiCopyWith<_BankTransactionItemApi> get copyWith => __$BankTransactionItemApiCopyWithImpl<_BankTransactionItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BankTransactionItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BankTransactionItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'BankTransactionItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$BankTransactionItemApiCopyWith<$Res> implements $BankTransactionItemApiCopyWith<$Res> {
  factory _$BankTransactionItemApiCopyWith(_BankTransactionItemApi value, $Res Function(_BankTransactionItemApi) _then) = __$BankTransactionItemApiCopyWithImpl;
@override @useResult
$Res call({
 BankTransactionApi data
});


@override $BankTransactionApiCopyWith<$Res> get data;

}
/// @nodoc
class __$BankTransactionItemApiCopyWithImpl<$Res>
    implements _$BankTransactionItemApiCopyWith<$Res> {
  __$BankTransactionItemApiCopyWithImpl(this._self, this._then);

  final _BankTransactionItemApi _self;
  final $Res Function(_BankTransactionItemApi) _then;

/// Create a copy of BankTransactionItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_BankTransactionItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as BankTransactionApi,
  ));
}

/// Create a copy of BankTransactionItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BankTransactionApiCopyWith<$Res> get data {
  
  return $BankTransactionApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
