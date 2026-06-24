// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaymentApi _$PaymentApiFromJson(Map<String, dynamic> json) => _PaymentApi(
  id: json['id'] as String? ?? '',
  userId: json['user_id'] as String? ?? '',
  createdUserId: json['created_user_id'] as String? ?? '',
  assignedUserId: json['assigned_user_id'] as String? ?? '',
  number: json['number'] as String? ?? '',
  statusId: json['status_id'] as String? ?? '',
  typeId: json['type_id'] as String? ?? '',
  clientId: json['client_id'] as String? ?? '',
  clientContactId: json['client_contact_id'] as String? ?? '',
  companyGatewayId: json['company_gateway_id'] as String? ?? '',
  gatewayTypeId: json['gateway_type_id'] as String? ?? '',
  projectId: json['project_id'] as String? ?? '',
  vendorId: json['vendor_id'] as String? ?? '',
  invitationId: json['invitation_id'] as String? ?? '',
  currencyId: json['currency_id'] as String? ?? '',
  exchangeCurrencyId: json['exchange_currency_id'] as String? ?? '',
  transactionReference: json['transaction_reference'] as String? ?? '',
  transactionId: json['transaction_id'] as String? ?? '',
  privateNotes: json['private_notes'] as String? ?? '',
  customValue1: json['custom_value1'] as String? ?? '',
  customValue2: json['custom_value2'] as String? ?? '',
  customValue3: json['custom_value3'] as String? ?? '',
  customValue4: json['custom_value4'] as String? ?? '',
  date: json['date'] as String? ?? '',
  amount: json['amount'] as Object? ?? '0',
  applied: json['applied'] as Object? ?? '0',
  refunded: json['refunded'] as Object? ?? '0',
  exchangeRate: json['exchange_rate'] as Object? ?? '1',
  isManual: json['is_manual'] as bool? ?? false,
  isDeleted: json['is_deleted'] as bool? ?? false,
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
  paymentables: (json['paymentables'] as List<dynamic>?)
      ?.map((e) => PaymentableApi.fromJson(e as Map<String, dynamic>))
      .toList(),
  invoices: (json['invoices'] as List<dynamic>?)
      ?.map((e) => PaymentInvoiceRefApi.fromJson(e as Map<String, dynamic>))
      .toList(),
  credits: (json['credits'] as List<dynamic>?)
      ?.map((e) => PaymentCreditRefApi.fromJson(e as Map<String, dynamic>))
      .toList(),
  documents: (json['documents'] as List<dynamic>?)
      ?.map((e) => DocumentApi.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PaymentApiToJson(_PaymentApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'created_user_id': instance.createdUserId,
      'assigned_user_id': instance.assignedUserId,
      'number': instance.number,
      'status_id': instance.statusId,
      'type_id': instance.typeId,
      'client_id': instance.clientId,
      'client_contact_id': instance.clientContactId,
      'company_gateway_id': instance.companyGatewayId,
      'gateway_type_id': instance.gatewayTypeId,
      'project_id': instance.projectId,
      'vendor_id': instance.vendorId,
      'invitation_id': instance.invitationId,
      'currency_id': instance.currencyId,
      'exchange_currency_id': instance.exchangeCurrencyId,
      'transaction_reference': instance.transactionReference,
      'transaction_id': instance.transactionId,
      'private_notes': instance.privateNotes,
      'custom_value1': instance.customValue1,
      'custom_value2': instance.customValue2,
      'custom_value3': instance.customValue3,
      'custom_value4': instance.customValue4,
      'date': instance.date,
      'amount': instance.amount,
      'applied': instance.applied,
      'refunded': instance.refunded,
      'exchange_rate': instance.exchangeRate,
      'is_manual': instance.isManual,
      'is_deleted': instance.isDeleted,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'paymentables': instance.paymentables,
      'invoices': instance.invoices,
      'credits': instance.credits,
      'documents': instance.documents,
    };

_PaymentableApi _$PaymentableApiFromJson(Map<String, dynamic> json) =>
    _PaymentableApi(
      id: json['id'] as String? ?? '',
      invoiceId: json['invoice_id'] as String? ?? '',
      creditId: json['credit_id'] as String? ?? '',
      amount: json['amount'] as Object? ?? '0',
      refunded: json['refunded'] as Object? ?? '0',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PaymentableApiToJson(_PaymentableApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'invoice_id': instance.invoiceId,
      'credit_id': instance.creditId,
      'amount': instance.amount,
      'refunded': instance.refunded,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
    };

_PaymentInvoiceRefApi _$PaymentInvoiceRefApiFromJson(
  Map<String, dynamic> json,
) => _PaymentInvoiceRefApi(
  id: json['id'] as String? ?? '',
  number: json['number'] as String? ?? '',
  amount: json['amount'] as Object? ?? '0',
  balance: json['balance'] as Object? ?? '0',
  paidToDate: json['paid_to_date'] as Object? ?? '0',
);

Map<String, dynamic> _$PaymentInvoiceRefApiToJson(
  _PaymentInvoiceRefApi instance,
) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'amount': instance.amount,
  'balance': instance.balance,
  'paid_to_date': instance.paidToDate,
};

_PaymentCreditRefApi _$PaymentCreditRefApiFromJson(Map<String, dynamic> json) =>
    _PaymentCreditRefApi(
      id: json['id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      amount: json['amount'] as Object? ?? '0',
      balance: json['balance'] as Object? ?? '0',
    );

Map<String, dynamic> _$PaymentCreditRefApiToJson(
  _PaymentCreditRefApi instance,
) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'amount': instance.amount,
  'balance': instance.balance,
};

_PaymentListApi _$PaymentListApiFromJson(Map<String, dynamic> json) =>
    _PaymentListApi(
      data: json['data'] == null ? const [] : _paymentListData(json['data']),
    );

Map<String, dynamic> _$PaymentListApiToJson(_PaymentListApi instance) =>
    <String, dynamic>{'data': instance.data};

_PaymentItemApi _$PaymentItemApiFromJson(Map<String, dynamic> json) =>
    _PaymentItemApi(
      data: PaymentApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PaymentItemApiToJson(_PaymentItemApi instance) =>
    <String, dynamic>{'data': instance.data};
