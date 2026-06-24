// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserItemApi _$UserItemApiFromJson(Map<String, dynamic> json) =>
    _UserItemApi(data: UserApi.fromJson(json['data'] as Map<String, dynamic>));

Map<String, dynamic> _$UserItemApiToJson(_UserItemApi instance) =>
    <String, dynamic>{'data': instance.data};

_UserListApi _$UserListApiFromJson(Map<String, dynamic> json) => _UserListApi(
  data: json['data'] == null ? const <UserApi>[] : _userListData(json['data']),
);

Map<String, dynamic> _$UserListApiToJson(_UserListApi instance) =>
    <String, dynamic>{'data': instance.data};

_UserApi _$UserApiFromJson(Map<String, dynamic> json) => _UserApi(
  id: json['id'] as String? ?? '',
  firstName: json['first_name'] as String? ?? '',
  lastName: json['last_name'] as String? ?? '',
  email: json['email'] as String? ?? '',
  phone: json['phone'] as String? ?? '',
  signature: json['signature'] as String? ?? '',
  languageId: json['language_id'] as String? ?? '',
  oauthProviderId: json['oauth_provider_id'] as String? ?? '',
  oauthUserToken: json['oauth_user_token'] as String? ?? '',
  oauthUserRefreshToken: json['oauth_user_refresh_token'] as String? ?? '',
  google2faSecret: json['google_2fa_secret'] == null
      ? false
      : _boolFromJson(json['google_2fa_secret']),
  verifiedPhoneNumber: json['verified_phone_number'] == null
      ? false
      : _boolFromJson(json['verified_phone_number']),
  hasPassword: json['has_password'] as bool? ?? false,
  lastLogin: (json['last_login'] as num?)?.toInt() ?? 0,
  emailVerifiedAt: (json['email_verified_at'] as num?)?.toInt() ?? 0,
  userLoggedInNotification: json['user_logged_in_notification'] == null
      ? false
      : _boolFromJson(json['user_logged_in_notification']),
  createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
  isDeleted: json['is_deleted'] as bool? ?? false,
  customValue1: json['custom_value1'] as String? ?? '',
  customValue2: json['custom_value2'] as String? ?? '',
  customValue3: json['custom_value3'] as String? ?? '',
  customValue4: json['custom_value4'] as String? ?? '',
  companyUser: json['company_user'] == null
      ? null
      : CompanyUserApi.fromJson(json['company_user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$UserApiToJson(_UserApi instance) => <String, dynamic>{
  'id': instance.id,
  'first_name': instance.firstName,
  'last_name': instance.lastName,
  'email': instance.email,
  'phone': instance.phone,
  'signature': instance.signature,
  'language_id': instance.languageId,
  'oauth_provider_id': instance.oauthProviderId,
  'oauth_user_token': instance.oauthUserToken,
  'oauth_user_refresh_token': instance.oauthUserRefreshToken,
  'google_2fa_secret': instance.google2faSecret,
  'verified_phone_number': instance.verifiedPhoneNumber,
  'has_password': instance.hasPassword,
  'last_login': instance.lastLogin,
  'email_verified_at': instance.emailVerifiedAt,
  'user_logged_in_notification': instance.userLoggedInNotification,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'archived_at': instance.archivedAt,
  'is_deleted': instance.isDeleted,
  'custom_value1': instance.customValue1,
  'custom_value2': instance.customValue2,
  'custom_value3': instance.customValue3,
  'custom_value4': instance.customValue4,
  'company_user': instance.companyUser,
};

_CompanyUserApi _$CompanyUserApiFromJson(Map<String, dynamic> json) =>
    _CompanyUserApi(
      permissions: json['permissions'] as String? ?? '',
      isOwner: json['is_owner'] as bool? ?? false,
      isAdmin: json['is_admin'] as bool? ?? false,
      isLocked: json['is_locked'] as bool? ?? false,
      notifications:
          json['notifications'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
      settings:
          json['settings'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
    );

Map<String, dynamic> _$CompanyUserApiToJson(_CompanyUserApi instance) =>
    <String, dynamic>{
      'permissions': instance.permissions,
      'is_owner': instance.isOwner,
      'is_admin': instance.isAdmin,
      'is_locked': instance.isLocked,
      'notifications': instance.notifications,
      'settings': instance.settings,
    };
