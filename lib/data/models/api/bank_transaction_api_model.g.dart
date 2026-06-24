// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bank_transaction_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BankTransactionApi _$BankTransactionApiFromJson(Map<String, dynamic> json) =>
    _BankTransactionApi(
      id: json['id'] as String? ?? '',
      amount: json['amount'] as Object? ?? '0',
      currencyId: json['currency_id'] as String? ?? '',
      categoryType: json['category_type'] as String? ?? '',
      baseType: json['base_type'] as String? ?? '',
      date: json['date'] as String? ?? '',
      bankIntegrationId: json['bank_integration_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      statusId: json['status_id'] as String? ?? '1',
      ninjaCategoryId: json['ninja_category_id'] as String? ?? '',
      invoiceIds: json['invoice_ids'] as String? ?? '',
      paymentId: json['payment_id'] as String? ?? '',
      expenseId: json['expense_id'] as String? ?? '',
      vendorId: json['vendor_id'] as String? ?? '',
      transactionId: json['transaction_id'] as Object? ?? 0,
      bankTransactionRuleId: json['bank_transaction_rule_id'] as String? ?? '',
      participantName: json['participant_name'] as String? ?? '',
      participant: json['participant'] as String? ?? '',
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$BankTransactionApiToJson(_BankTransactionApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'amount': instance.amount,
      'currency_id': instance.currencyId,
      'category_type': instance.categoryType,
      'base_type': instance.baseType,
      'date': instance.date,
      'bank_integration_id': instance.bankIntegrationId,
      'description': instance.description,
      'status_id': instance.statusId,
      'ninja_category_id': instance.ninjaCategoryId,
      'invoice_ids': instance.invoiceIds,
      'payment_id': instance.paymentId,
      'expense_id': instance.expenseId,
      'vendor_id': instance.vendorId,
      'transaction_id': instance.transactionId,
      'bank_transaction_rule_id': instance.bankTransactionRuleId,
      'participant_name': instance.participantName,
      'participant': instance.participant,
      'is_deleted': instance.isDeleted,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
    };

_BankTransactionListApi _$BankTransactionListApiFromJson(
  Map<String, dynamic> json,
) => _BankTransactionListApi(
  data: json['data'] == null
      ? const []
      : _bankTransactionListData(json['data']),
);

Map<String, dynamic> _$BankTransactionListApiToJson(
  _BankTransactionListApi instance,
) => <String, dynamic>{'data': instance.data};

_BankTransactionItemApi _$BankTransactionItemApiFromJson(
  Map<String, dynamic> json,
) => _BankTransactionItemApi(
  data: BankTransactionApi.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BankTransactionItemApiToJson(
  _BankTransactionItemApi instance,
) => <String, dynamic>{'data': instance.data};
