// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ActivityLabelApi _$ActivityLabelApiFromJson(Map<String, dynamic> json) =>
    _ActivityLabelApi(
      label: json['label'] as String? ?? '',
      hashedId: json['hashed_id'] as String? ?? '',
      contactEntity: json['contact_entity'] as String? ?? '',
    );

Map<String, dynamic> _$ActivityLabelApiToJson(_ActivityLabelApi instance) =>
    <String, dynamic>{
      'label': instance.label,
      'hashed_id': instance.hashedId,
      'contact_entity': instance.contactEntity,
    };

_ActivityApi _$ActivityApiFromJson(Map<String, dynamic> json) => _ActivityApi(
  id: json['hashed_id'] as String? ?? '',
  activityTypeId: (json['activity_type_id'] as num?)?.toInt() ?? 0,
  notes: json['notes'] as String? ?? '',
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  ip: json['ip'] as String? ?? '',
  user: json['user'] == null
      ? null
      : ActivityLabelApi.fromJson(json['user'] as Map<String, dynamic>),
  client: json['client'] == null
      ? null
      : ActivityLabelApi.fromJson(json['client'] as Map<String, dynamic>),
  invoice: json['invoice'] == null
      ? null
      : ActivityLabelApi.fromJson(json['invoice'] as Map<String, dynamic>),
  contact: json['contact'] == null
      ? null
      : ActivityLabelApi.fromJson(json['contact'] as Map<String, dynamic>),
  quote: json['quote'] == null
      ? null
      : ActivityLabelApi.fromJson(json['quote'] as Map<String, dynamic>),
  payment: json['payment'] == null
      ? null
      : ActivityLabelApi.fromJson(json['payment'] as Map<String, dynamic>),
  paymentAmount: json['payment_amount'] == null
      ? null
      : ActivityLabelApi.fromJson(
          json['payment_amount'] as Map<String, dynamic>,
        ),
  expense: json['expense'] == null
      ? null
      : ActivityLabelApi.fromJson(json['expense'] as Map<String, dynamic>),
  credit: json['credit'] == null
      ? null
      : ActivityLabelApi.fromJson(json['credit'] as Map<String, dynamic>),
  task: json['task'] == null
      ? null
      : ActivityLabelApi.fromJson(json['task'] as Map<String, dynamic>),
  vendor: json['vendor'] == null
      ? null
      : ActivityLabelApi.fromJson(json['vendor'] as Map<String, dynamic>),
  recurringInvoice: json['recurring_invoice'] == null
      ? null
      : ActivityLabelApi.fromJson(
          json['recurring_invoice'] as Map<String, dynamic>,
        ),
  recurringExpense: json['recurring_expense'] == null
      ? null
      : ActivityLabelApi.fromJson(
          json['recurring_expense'] as Map<String, dynamic>,
        ),
  purchaseOrder: json['purchase_order'] == null
      ? null
      : ActivityLabelApi.fromJson(
          json['purchase_order'] as Map<String, dynamic>,
        ),
  subscription: json['subscription'] == null
      ? null
      : ActivityLabelApi.fromJson(json['subscription'] as Map<String, dynamic>),
  adjustment: json['adjustment'] == null
      ? null
      : ActivityLabelApi.fromJson(json['adjustment'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ActivityApiToJson(_ActivityApi instance) =>
    <String, dynamic>{
      'hashed_id': instance.id,
      'activity_type_id': instance.activityTypeId,
      'notes': instance.notes,
      'created_at': instance.createdAt,
      'ip': instance.ip,
      'user': instance.user,
      'client': instance.client,
      'invoice': instance.invoice,
      'contact': instance.contact,
      'quote': instance.quote,
      'payment': instance.payment,
      'payment_amount': instance.paymentAmount,
      'expense': instance.expense,
      'credit': instance.credit,
      'task': instance.task,
      'vendor': instance.vendor,
      'recurring_invoice': instance.recurringInvoice,
      'recurring_expense': instance.recurringExpense,
      'purchase_order': instance.purchaseOrder,
      'subscription': instance.subscription,
      'adjustment': instance.adjustment,
    };

_ActivityListApi _$ActivityListApiFromJson(Map<String, dynamic> json) =>
    _ActivityListApi(
      data: json['data'] == null ? const [] : _activityListData(json['data']),
    );

Map<String, dynamic> _$ActivityListApiToJson(_ActivityListApi instance) =>
    <String, dynamic>{'data': instance.data};
