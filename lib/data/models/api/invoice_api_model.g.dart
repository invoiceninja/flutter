// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InvoiceApi _$InvoiceApiFromJson(Map<String, dynamic> json) => _InvoiceApi(
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
  parentInvoiceId: json['invoice_id'] as String? ?? '',
  recurringId: json['recurring_id'] as String? ?? '',
  amount: json['amount'] as Object? ?? '0',
  balance: json['balance'] as Object? ?? '0',
  paidToDate: json['paid_to_date'] as Object? ?? '0',
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
  reminder1Sent: json['reminder1_sent'] as String? ?? '',
  reminder2Sent: json['reminder2_sent'] as String? ?? '',
  reminder3Sent: json['reminder3_sent'] as String? ?? '',
  reminderLastSent: json['reminder_last_sent'] as String? ?? '',
  reminderSchedule: json['reminder_schedule'] as String? ?? '',
  frequencyId: json['frequency_id'] as String? ?? '',
  nextSendDate: json['next_send_date'] as String? ?? '',
  nextSendDatetime: json['next_send_datetime'] as String? ?? '',
  lastSentDate: json['last_sent_date'] as String? ?? '',
  remainingCycles: (json['remaining_cycles'] as num?)?.toInt() ?? 0,
  dueDateDays: json['due_date_days'] as String? ?? '',
  autoBill: json['auto_bill'] as String? ?? '',
  autoBillEnabled: json['auto_bill_enabled'] as bool? ?? false,
  eInvoice: json['e_invoice'] as Map<String, dynamic>?,
  backup: json['backup'] as Map<String, dynamic>?,
  taxInfo: json['tax_info'] as Map<String, dynamic>?,
  modifiedInvoiceId: json['modified_invoice_id'] as String?,
  reason: json['reason'] as String?,
  schedule: (json['schedule'] as List<dynamic>?)
      ?.map((e) => ScheduleItemApi.fromJson(e as Map<String, dynamic>))
      .toList(),
  isLocked: json['is_locked'] as bool? ?? false,
  isDeleted: json['is_deleted'] as bool? ?? false,
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$InvoiceApiToJson(_InvoiceApi instance) =>
    <String, dynamic>{
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
      'invoice_id': instance.parentInvoiceId,
      'recurring_id': instance.recurringId,
      'amount': instance.amount,
      'balance': instance.balance,
      'paid_to_date': instance.paidToDate,
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
      'reminder1_sent': instance.reminder1Sent,
      'reminder2_sent': instance.reminder2Sent,
      'reminder3_sent': instance.reminder3Sent,
      'reminder_last_sent': instance.reminderLastSent,
      'reminder_schedule': instance.reminderSchedule,
      'frequency_id': instance.frequencyId,
      'next_send_date': instance.nextSendDate,
      'next_send_datetime': instance.nextSendDatetime,
      'last_sent_date': instance.lastSentDate,
      'remaining_cycles': instance.remainingCycles,
      'due_date_days': instance.dueDateDays,
      'auto_bill': instance.autoBill,
      'auto_bill_enabled': instance.autoBillEnabled,
      'e_invoice': instance.eInvoice,
      'backup': instance.backup,
      'tax_info': instance.taxInfo,
      'modified_invoice_id': instance.modifiedInvoiceId,
      'reason': instance.reason,
      'schedule': instance.schedule,
      'is_locked': instance.isLocked,
      'is_deleted': instance.isDeleted,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
    };

_InvoiceListApi _$InvoiceListApiFromJson(Map<String, dynamic> json) =>
    _InvoiceListApi(
      data: json['data'] == null
          ? const <InvoiceApi>[]
          : _invoiceListData(json['data']),
    );

Map<String, dynamic> _$InvoiceListApiToJson(_InvoiceListApi instance) =>
    <String, dynamic>{'data': instance.data};

_InvoiceItemApi _$InvoiceItemApiFromJson(Map<String, dynamic> json) =>
    _InvoiceItemApi(
      data: InvoiceApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$InvoiceItemApiToJson(_InvoiceItemApi instance) =>
    <String, dynamic>{'data': instance.data};
