// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invitation_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InvitationApi _$InvitationApiFromJson(Map<String, dynamic> json) =>
    _InvitationApi(
      id: json['id'] as String? ?? '',
      key: json['key'] as String? ?? '',
      link: json['link'] as String? ?? '',
      clientContactId: json['client_contact_id'] as String? ?? '',
      vendorContactId: json['vendor_contact_id'] as String? ?? '',
      sentDate: json['sent_date'] as String? ?? '',
      viewedDate: json['viewed_date'] as String? ?? '',
      openedDate: json['opened_date'] as String? ?? '',
      emailStatus: json['email_status'] as String? ?? '',
      emailError: json['email_error'] as String? ?? '',
      messageId: json['message_id'] as String? ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      canSign: jsonScalarToBoolOrNull(json['can_sign']),
    );

Map<String, dynamic> _$InvitationApiToJson(_InvitationApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'key': instance.key,
      'link': instance.link,
      'client_contact_id': instance.clientContactId,
      'vendor_contact_id': instance.vendorContactId,
      'sent_date': instance.sentDate,
      'viewed_date': instance.viewedDate,
      'opened_date': instance.openedDate,
      'email_status': instance.emailStatus,
      'email_error': instance.emailError,
      'message_id': instance.messageId,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'can_sign': ?instance.canSign,
    };
