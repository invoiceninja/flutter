// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_invoice_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RecurringInvoiceApi _$RecurringInvoiceApiFromJson(Map<String, dynamic> json) =>
    _RecurringInvoiceApi(
      id: json['id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      poNumber: json['po_number'] as String? ?? '',
      date: json['date'] as String? ?? '',
      dueDate: json['due_date'] as String? ?? '',
      partialDueDate: json['partial_due_date'] as String? ?? '',
      statusId: json['status_id'] as String? ?? '1',
      clientId: json['client_id'] as String? ?? '',
      vendorId: json['vendor_id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      designId: json['design_id'] as String? ?? '',
      assignedUserId: json['assigned_user_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      locationId: json['location_id'] as String? ?? '',
      subscriptionId: json['subscription_id'] as String? ?? '',
      amount: json['amount'] as Object? ?? '0',
      balance: json['balance'] as Object? ?? '0',
      totalTaxes: json['total_taxes'] as Object? ?? '0',
      discount: json['discount'] as Object? ?? '0',
      partial: json['partial'] as Object? ?? '0',
      isAmountDiscount: json['is_amount_discount'] as bool? ?? false,
      exchangeRate: json['exchange_rate'] as Object? ?? '1',
      taxName1: json['tax_name1'] as String? ?? '',
      taxName2: json['tax_name2'] as String? ?? '',
      taxName3: json['tax_name3'] as String? ?? '',
      taxRate1: json['tax_rate1'] as Object? ?? '0',
      taxRate2: json['tax_rate2'] as Object? ?? '0',
      taxRate3: json['tax_rate3'] as Object? ?? '0',
      usesInclusiveTaxes: json['uses_inclusive_taxes'] as bool? ?? false,
      customSurcharge1: json['custom_surcharge1'] as Object? ?? '0',
      customSurcharge2: json['custom_surcharge2'] as Object? ?? '0',
      customSurcharge3: json['custom_surcharge3'] as Object? ?? '0',
      customSurcharge4: json['custom_surcharge4'] as Object? ?? '0',
      customTaxes1: json['custom_surcharge_tax1'] as bool? ?? false,
      customTaxes2: json['custom_surcharge_tax2'] as bool? ?? false,
      customTaxes3: json['custom_surcharge_tax3'] as bool? ?? false,
      customTaxes4: json['custom_surcharge_tax4'] as bool? ?? false,
      publicNotes: json['public_notes'] as String? ?? '',
      privateNotes: json['private_notes'] as String? ?? '',
      terms: json['terms'] as String? ?? '',
      footer: json['footer'] as String? ?? '',
      customValue1: json['custom_value1'] as String? ?? '',
      customValue2: json['custom_value2'] as String? ?? '',
      customValue3: json['custom_value3'] as String? ?? '',
      customValue4: json['custom_value4'] as String? ?? '',
      lineItems:
          (json['line_items'] as List<dynamic>?)
              ?.map((e) => LineItemApi.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <LineItemApi>[],
      invitations:
          (json['invitations'] as List<dynamic>?)
              ?.map((e) => InvitationApi.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <InvitationApi>[],
      documents: (json['documents'] as List<dynamic>?)
          ?.map((e) => DocumentApi.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: json['tags'] == null
          ? const <TagRefApi>[]
          : const EmbeddedTagsConverter().fromJson(json['tags']),
      frequencyId: json['frequency_id'] as String? ?? '',
      nextSendDate: json['next_send_date'] as String? ?? '',
      nextSendDatetime: json['next_send_datetime'] as String? ?? '',
      lastSentDate: json['last_sent_date'] as String? ?? '',
      remainingCycles: (json['remaining_cycles'] as num?)?.toInt() ?? 0,
      dueDateDays: json['due_date_days'] as String? ?? '',
      autoBill: json['auto_bill'] as String? ?? '',
      autoBillEnabled: json['auto_bill_enabled'] as bool? ?? false,
      eInvoice: json['e_invoice'] as Map<String, dynamic>?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$RecurringInvoiceApiToJson(
  _RecurringInvoiceApi instance,
) => <String, dynamic>{
  'id': instance.id,
  'number': instance.number,
  'po_number': instance.poNumber,
  'date': instance.date,
  'due_date': instance.dueDate,
  'partial_due_date': instance.partialDueDate,
  'status_id': instance.statusId,
  'client_id': instance.clientId,
  'vendor_id': instance.vendorId,
  'project_id': instance.projectId,
  'design_id': instance.designId,
  'assigned_user_id': instance.assignedUserId,
  'user_id': instance.userId,
  'location_id': instance.locationId,
  'subscription_id': instance.subscriptionId,
  'amount': instance.amount,
  'balance': instance.balance,
  'total_taxes': instance.totalTaxes,
  'discount': instance.discount,
  'partial': instance.partial,
  'is_amount_discount': instance.isAmountDiscount,
  'exchange_rate': instance.exchangeRate,
  'tax_name1': instance.taxName1,
  'tax_name2': instance.taxName2,
  'tax_name3': instance.taxName3,
  'tax_rate1': instance.taxRate1,
  'tax_rate2': instance.taxRate2,
  'tax_rate3': instance.taxRate3,
  'uses_inclusive_taxes': instance.usesInclusiveTaxes,
  'custom_surcharge1': instance.customSurcharge1,
  'custom_surcharge2': instance.customSurcharge2,
  'custom_surcharge3': instance.customSurcharge3,
  'custom_surcharge4': instance.customSurcharge4,
  'custom_surcharge_tax1': instance.customTaxes1,
  'custom_surcharge_tax2': instance.customTaxes2,
  'custom_surcharge_tax3': instance.customTaxes3,
  'custom_surcharge_tax4': instance.customTaxes4,
  'public_notes': instance.publicNotes,
  'private_notes': instance.privateNotes,
  'terms': instance.terms,
  'footer': instance.footer,
  'custom_value1': instance.customValue1,
  'custom_value2': instance.customValue2,
  'custom_value3': instance.customValue3,
  'custom_value4': instance.customValue4,
  'line_items': instance.lineItems,
  'invitations': instance.invitations,
  'documents': instance.documents,
  'tags': const EmbeddedTagsConverter().toJson(instance.tags),
  'frequency_id': instance.frequencyId,
  'next_send_date': instance.nextSendDate,
  'next_send_datetime': instance.nextSendDatetime,
  'last_sent_date': instance.lastSentDate,
  'remaining_cycles': instance.remainingCycles,
  'due_date_days': instance.dueDateDays,
  'auto_bill': instance.autoBill,
  'auto_bill_enabled': instance.autoBillEnabled,
  'e_invoice': instance.eInvoice,
  'is_deleted': instance.isDeleted,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'archived_at': instance.archivedAt,
};

_RecurringInvoiceListApi _$RecurringInvoiceListApiFromJson(
  Map<String, dynamic> json,
) => _RecurringInvoiceListApi(
  data: json['data'] == null
      ? const <RecurringInvoiceApi>[]
      : _recurringInvoiceListData(json['data']),
);

Map<String, dynamic> _$RecurringInvoiceListApiToJson(
  _RecurringInvoiceListApi instance,
) => <String, dynamic>{'data': instance.data};

_RecurringInvoiceItemApi _$RecurringInvoiceItemApiFromJson(
  Map<String, dynamic> json,
) => _RecurringInvoiceItemApi(
  data: RecurringInvoiceApi.fromJson(json['data'] as Map<String, dynamic>),
);

Map<String, dynamic> _$RecurringInvoiceItemApiToJson(
  _RecurringInvoiceItemApi instance,
) => <String, dynamic>{'data': instance.data};
