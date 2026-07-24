// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ExpenseApi _$ExpenseApiFromJson(Map<String, dynamic> json) => _ExpenseApi(
  id: json['id'] as String? ?? '',
  userId: json['user_id'] as String? ?? '',
  assignedUserId: json['assigned_user_id'] as String? ?? '',
  vendorId: json['vendor_id'] as String? ?? '',
  invoiceId: json['invoice_id'] as String? ?? '',
  clientId: json['client_id'] as String? ?? '',
  bankId: json['bank_id'] as String? ?? '',
  invoiceCurrencyId: json['invoice_currency_id'] as String? ?? '',
  expenseCurrencyId: json['expense_currency_id'] as String? ?? '',
  currencyId: json['currency_id'] as String? ?? '',
  categoryId: json['category_id'] as String? ?? '',
  paymentTypeId: json['payment_type_id'] as String? ?? '',
  recurringExpenseId: json['recurring_expense_id'] as String? ?? '',
  privateNotes: json['private_notes'] as String? ?? '',
  publicNotes: json['public_notes'] as String? ?? '',
  transactionReference: json['transaction_reference'] as String? ?? '',
  transactionId: json['transaction_id'] as String? ?? '',
  date: json['date'] as String? ?? '',
  number: json['number'] as String? ?? '',
  paymentDate: json['payment_date'] as String? ?? '',
  customValue1: json['custom_value1'] as String? ?? '',
  customValue2: json['custom_value2'] as String? ?? '',
  customValue3: json['custom_value3'] as String? ?? '',
  customValue4: json['custom_value4'] as String? ?? '',
  taxName1: json['tax_name1'] as String? ?? '',
  taxName2: json['tax_name2'] as String? ?? '',
  taxName3: json['tax_name3'] as String? ?? '',
  projectId: json['project_id'] as String? ?? '',
  entityType: json['entity_type'] as String? ?? '',
  amount: json['amount'] as Object? ?? '0',
  foreignAmount: json['foreign_amount'] as Object? ?? '0',
  exchangeRate: json['exchange_rate'] as Object? ?? '1',
  taxAmount1: json['tax_amount1'] as Object? ?? '0',
  taxAmount2: json['tax_amount2'] as Object? ?? '0',
  taxAmount3: json['tax_amount3'] as Object? ?? '0',
  taxRate1: json['tax_rate1'] as Object? ?? '0',
  taxRate2: json['tax_rate2'] as Object? ?? '0',
  taxRate3: json['tax_rate3'] as Object? ?? '0',
  isDeleted: json['is_deleted'] as bool? ?? false,
  shouldBeInvoiced: json['should_be_invoiced'] as bool? ?? false,
  invoiceDocuments: json['invoice_documents'] as bool? ?? false,
  usesInclusiveTaxes: json['uses_inclusive_taxes'] as bool? ?? false,
  calculateTaxByAmount: json['calculate_tax_by_amount'] as bool? ?? false,
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
  documents: (json['documents'] as List<dynamic>?)
      ?.map((e) => DocumentApi.fromJson(e as Map<String, dynamic>))
      .toList(),
  tags: json['tags'] == null
      ? const <TagRefApi>[]
      : const EmbeddedTagsConverter().fromJson(json['tags']),
);

Map<String, dynamic> _$ExpenseApiToJson(_ExpenseApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'assigned_user_id': instance.assignedUserId,
      'vendor_id': instance.vendorId,
      'invoice_id': instance.invoiceId,
      'client_id': instance.clientId,
      'bank_id': instance.bankId,
      'invoice_currency_id': instance.invoiceCurrencyId,
      'expense_currency_id': instance.expenseCurrencyId,
      'currency_id': instance.currencyId,
      'category_id': instance.categoryId,
      'payment_type_id': instance.paymentTypeId,
      'recurring_expense_id': instance.recurringExpenseId,
      'private_notes': instance.privateNotes,
      'public_notes': instance.publicNotes,
      'transaction_reference': instance.transactionReference,
      'transaction_id': instance.transactionId,
      'date': instance.date,
      'number': instance.number,
      'payment_date': instance.paymentDate,
      'custom_value1': instance.customValue1,
      'custom_value2': instance.customValue2,
      'custom_value3': instance.customValue3,
      'custom_value4': instance.customValue4,
      'tax_name1': instance.taxName1,
      'tax_name2': instance.taxName2,
      'tax_name3': instance.taxName3,
      'project_id': instance.projectId,
      'entity_type': instance.entityType,
      'amount': instance.amount,
      'foreign_amount': instance.foreignAmount,
      'exchange_rate': instance.exchangeRate,
      'tax_amount1': instance.taxAmount1,
      'tax_amount2': instance.taxAmount2,
      'tax_amount3': instance.taxAmount3,
      'tax_rate1': instance.taxRate1,
      'tax_rate2': instance.taxRate2,
      'tax_rate3': instance.taxRate3,
      'is_deleted': instance.isDeleted,
      'should_be_invoiced': instance.shouldBeInvoiced,
      'invoice_documents': instance.invoiceDocuments,
      'uses_inclusive_taxes': instance.usesInclusiveTaxes,
      'calculate_tax_by_amount': instance.calculateTaxByAmount,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'documents': instance.documents,
      'tags': const EmbeddedTagsConverter().toJson(instance.tags),
    };

_ExpenseListApi _$ExpenseListApiFromJson(Map<String, dynamic> json) =>
    _ExpenseListApi(
      data: json['data'] == null ? const [] : _expenseListData(json['data']),
    );

Map<String, dynamic> _$ExpenseListApiToJson(_ExpenseListApi instance) =>
    <String, dynamic>{'data': instance.data};

_ExpenseItemApi _$ExpenseItemApiFromJson(Map<String, dynamic> json) =>
    _ExpenseItemApi(
      data: ExpenseApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ExpenseItemApiToJson(_ExpenseItemApi instance) =>
    <String, dynamic>{'data': instance.data};
