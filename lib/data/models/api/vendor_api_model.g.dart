// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vendor_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VendorApi _$VendorApiFromJson(Map<String, dynamic> json) => _VendorApi(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
  number: json['number'] as String? ?? '',
  idNumber: json['id_number'] as String? ?? '',
  vatNumber: json['vat_number'] as String? ?? '',
  website: json['website'] as String? ?? '',
  phone: json['phone'] as String? ?? '',
  address1: json['address1'] as String? ?? '',
  address2: json['address2'] as String? ?? '',
  city: json['city'] as String? ?? '',
  state: json['state'] as String? ?? '',
  postalCode: json['postal_code'] as String? ?? '',
  countryId: json['country_id'] as String? ?? '',
  currencyId: json['currency_id'] as String? ?? '',
  languageId: json['language_id'] as String? ?? '',
  classification: json['classification'] as String? ?? '',
  isTaxExempt: json['is_tax_exempt'] as bool? ?? false,
  routingId: json['routing_id'] as String? ?? '',
  privateNotes: json['private_notes'] as String? ?? '',
  publicNotes: json['public_notes'] as String? ?? '',
  customValue1: json['custom_value1'] as String? ?? '',
  customValue2: json['custom_value2'] as String? ?? '',
  customValue3: json['custom_value3'] as String? ?? '',
  customValue4: json['custom_value4'] as String? ?? '',
  assignedUserId: json['assigned_user_id'] as String? ?? '',
  userId: json['user_id'] as String? ?? '',
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
  lastLogin: (json['last_login'] as num?)?.toInt() ?? 0,
  isDeleted: json['is_deleted'] as bool? ?? false,
  contacts:
      (json['contacts'] as List<dynamic>?)
          ?.map((e) => VendorContactApi.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <VendorContactApi>[],
  documents: (json['documents'] as List<dynamic>?)
      ?.map((e) => DocumentApi.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$VendorApiToJson(_VendorApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'number': instance.number,
      'id_number': instance.idNumber,
      'vat_number': instance.vatNumber,
      'website': instance.website,
      'phone': instance.phone,
      'address1': instance.address1,
      'address2': instance.address2,
      'city': instance.city,
      'state': instance.state,
      'postal_code': instance.postalCode,
      'country_id': instance.countryId,
      'currency_id': instance.currencyId,
      'language_id': instance.languageId,
      'classification': instance.classification,
      'is_tax_exempt': instance.isTaxExempt,
      'routing_id': instance.routingId,
      'private_notes': instance.privateNotes,
      'public_notes': instance.publicNotes,
      'custom_value1': instance.customValue1,
      'custom_value2': instance.customValue2,
      'custom_value3': instance.customValue3,
      'custom_value4': instance.customValue4,
      'assigned_user_id': instance.assignedUserId,
      'user_id': instance.userId,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'last_login': instance.lastLogin,
      'is_deleted': instance.isDeleted,
      'contacts': instance.contacts,
      'documents': instance.documents,
    };

_VendorContactApi _$VendorContactApiFromJson(Map<String, dynamic> json) =>
    _VendorContactApi(
      id: json['id'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      password: json['password'] as String? ?? '',
      sendEmail: json['send_email'] as bool? ?? true,
      ccOnly: json['cc_only'] as bool? ?? false,
      isPrimary: json['is_primary'] as bool? ?? false,
      canSign: json['can_sign'] as bool? ?? false,
      link: json['link'] as String? ?? '',
      customValue1: json['custom_value1'] as String? ?? '',
      customValue2: json['custom_value2'] as String? ?? '',
      customValue3: json['custom_value3'] as String? ?? '',
      customValue4: json['custom_value4'] as String? ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
      lastLogin: (json['last_login'] as num?)?.toInt() ?? 0,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );

Map<String, dynamic> _$VendorContactApiToJson(_VendorContactApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'first_name': instance.firstName,
      'last_name': instance.lastName,
      'email': instance.email,
      'phone': instance.phone,
      'password': instance.password,
      'send_email': instance.sendEmail,
      'cc_only': instance.ccOnly,
      'is_primary': instance.isPrimary,
      'can_sign': instance.canSign,
      'link': instance.link,
      'custom_value1': instance.customValue1,
      'custom_value2': instance.customValue2,
      'custom_value3': instance.customValue3,
      'custom_value4': instance.customValue4,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'last_login': instance.lastLogin,
      'is_deleted': instance.isDeleted,
    };

_VendorListApi _$VendorListApiFromJson(Map<String, dynamic> json) =>
    _VendorListApi(
      data: json['data'] == null
          ? const <VendorApi>[]
          : _vendorListData(json['data']),
    );

Map<String, dynamic> _$VendorListApiToJson(_VendorListApi instance) =>
    <String, dynamic>{'data': instance.data};

_VendorItemApi _$VendorItemApiFromJson(Map<String, dynamic> json) =>
    _VendorItemApi(
      data: VendorApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$VendorItemApiToJson(_VendorItemApi instance) =>
    <String, dynamic>{'data': instance.data};
