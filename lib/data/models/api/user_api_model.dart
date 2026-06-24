import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'user_api_model.freezed.dart';
part 'user_api_model.g.dart';

/// Envelope for `GET /api/v1/users/{id}` and `PUT /api/v1/users/{id}`.
///
/// The PUT body is itself a `UserApi` JSON map; the server echoes the patched
/// record back inside `data`.
@freezed
abstract class UserItemApi with _$UserItemApi {
  const factory UserItemApi({required UserApi data}) = _UserItemApi;

  factory UserItemApi.fromJson(Map<String, dynamic> json) =>
      _$UserItemApiFromJson(json);
}

/// Envelope for `GET /api/v1/users` list responses.
@freezed
abstract class UserListApi with _$UserListApi {
  const factory UserListApi({
    @JsonKey(fromJson: _userListData) @Default(<UserApi>[]) List<UserApi> data,
  }) = _UserListApi;

  factory UserListApi.fromJson(Map<String, dynamic> json) =>
      _$UserListApiFromJson(json);
}

/// Full user record returned by `/api/v1/users/{id}?include=company_user`.
///
/// We model the user-level fields the Settings > User Details screen edits
/// (name / email / phone / signature / language / oauth status) explicitly so
/// dropdowns and validators get typed access. The active company's per-user
/// settings travel under the singular `company_user` field — only the active
/// company is included when the request carries `?include=company_user`,
/// matching the React app's `useUserDetailsQuery` shape.
@freezed
abstract class UserApi with _$UserApi {
  const factory UserApi({
    @Default('') String id,
    @JsonKey(name: 'first_name') @Default('') String firstName,
    @JsonKey(name: 'last_name') @Default('') String lastName,
    @Default('') String email,
    @Default('') String phone,
    @Default('') String signature,
    @JsonKey(name: 'language_id') @Default('') String languageId,

    // -- Connect tab inputs ---------------------------------------------------
    @JsonKey(name: 'oauth_provider_id') @Default('') String oauthProviderId,
    @JsonKey(name: 'oauth_user_token') @Default('') String oauthUserToken,
    @JsonKey(name: 'oauth_user_refresh_token')
    @Default('')
    String oauthUserRefreshToken,

    // -- Two-factor / phone -------------------------------------------------
    @JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson)
    @Default(false)
    bool google2faSecret,
    @JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson)
    @Default(false)
    bool verifiedPhoneNumber,

    // -- Misc ---------------------------------------------------------------
    @JsonKey(name: 'has_password') @Default(false) bool hasPassword,
    @JsonKey(name: 'last_login') @Default(0) int lastLogin,
    @JsonKey(name: 'email_verified_at') @Default(0) int emailVerifiedAt,
    @JsonKey(name: 'user_logged_in_notification', fromJson: _boolFromJson)
    @Default(false)
    bool userLoggedInNotification,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,

    // -- Custom fields (gated on company.custom_fields.user1..4 in the UI) -
    @JsonKey(name: 'custom_value1') @Default('') String customValue1,
    @JsonKey(name: 'custom_value2') @Default('') String customValue2,
    @JsonKey(name: 'custom_value3') @Default('') String customValue3,
    @JsonKey(name: 'custom_value4') @Default('') String customValue4,

    // -- Per-company-user (active company only when ?include=company_user) -
    @JsonKey(name: 'company_user') CompanyUserApi? companyUser,
  }) = _UserApi;

  factory UserApi.fromJson(Map<String, dynamic> json) =>
      _$UserApiFromJson(json);
}

/// Per-(user, company) record. `notifications` and `settings` are kept as loose
/// maps we round-trip verbatim: the User Details screen reads
/// `notifications.email` and `settings.accent_color` but re-emits the whole maps
/// on save, so unmodelled keys (`notifications.slack`, `react_settings`,
/// `settings.*` React preferences, …) survive. This matters because the server's
/// admin branch fills the `company_user` pivot wholesale — a missing/empty
/// sub-key would wipe it. We deliberately don't model `react_settings` /
/// `slack_webhook_url` / `shop_restricted`: not modelling them keeps them off our
/// write body entirely, so the server leaves them untouched.
@freezed
abstract class CompanyUserApi with _$CompanyUserApi {
  const factory CompanyUserApi({
    @Default('') String permissions,
    @JsonKey(name: 'is_owner') @Default(false) bool isOwner,
    @JsonKey(name: 'is_admin') @Default(false) bool isAdmin,
    @JsonKey(name: 'is_locked') @Default(false) bool isLocked,
    @Default(<String, dynamic>{}) Map<String, dynamic> notifications,
    @Default(<String, dynamic>{}) Map<String, dynamic> settings,
  }) = _CompanyUserApi;

  factory CompanyUserApi.fromJson(Map<String, dynamic> json) =>
      _$CompanyUserApiFromJson(json);
}

/// The server emits `0`/`1`, `"true"`/`"false"`, or a real bool depending on
/// the endpoint — see [UserSummaryApi] in `login_response_api_model.dart` for
/// the same workaround in the leaner auth-session view.
bool _boolFromJson(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.toLowerCase();
    return v == 'true' || v == '1';
  }
  return false;
}

List<UserApi> _userListData(Object? raw) =>
    tolerantList(raw, UserApi.fromJson, label: 'user');
