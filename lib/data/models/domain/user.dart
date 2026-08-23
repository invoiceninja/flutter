import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/user_api_model.dart';

part 'user.freezed.dart';

/// Domain `User` — the authenticated user as the Settings > User Details
/// screen sees them. Companies the user has access to (and their
/// per-company-user records) carry through `companyUser`.
///
/// Settings live in two parallel maps mirroring the Company pattern:
///  * [companyUserSettings] — typed-ish [CompanyUserSettings] for the fields
///    we edit (accent_color). Notification prefs live elsewhere:
///    `user_logged_in_notification` is a top-level [User] field and the
///    per-event / special codes live in [notificationsEmail].
///  * [rawCompanyUserSettings] — the original server JSON for the per-user
///    settings blob; everything the new app doesn't model round-trips
///    untouched on save.
///
/// **`lastLogin` never means "last login"** — it is parsed and stored but
/// deliberately rendered nowhere. `UserTransformer` sends
/// `Carbon::parse($user->last_login)->timestamp`, and `Carbon::parse(null)` is
/// *now*, so a seeded or migrated row reports the moment you asked
/// (live-confirmed against demo, where the value tracks request time); a row
/// created through `POST /users` reports its creation time instead, because
/// `UserFactory::create()` seeds the column. Don't build a "last seen" row on
/// it, and don't use it to infer that someone has never acted. BACKEND.md § F5.
///
/// (Field-level note lives here rather than beside the parameter because
/// freezed copies *any* comment in the factory's parameter list into the
/// generated getters, which turns a comment edit into a build_runner
/// round-trip and a CI generated-code diff.)
@freezed
abstract class User with _$User {
  const User._();

  const factory User({
    @Default('') String id,
    @Default('') String firstName,
    @Default('') String lastName,
    @Default('') String email,
    @Default('') String phone,
    @Default('') String signature,
    @Default('') String languageId,
    @Default('') String oauthProviderId,
    @Default('') String oauthUserToken,
    @Default('') String oauthUserRefreshToken,
    @Default(false) bool googleTwoFactorEnabled,
    @Default(false) bool verifiedPhoneNumber,
    @Default(false) bool hasPassword,
    @Default(false) bool userLoggedInNotification,
    @Default('') String customValue1,
    @Default('') String customValue2,
    @Default('') String customValue3,
    @Default('') String customValue4,
    @Default(0) int lastLogin,
    @Default(0) int emailVerifiedAt,
    @Default(0) int createdAt,
    @Default(0) int updatedAt,
    @Default(0) int archivedAt,
    @Default(false) bool isDeleted,
    @Default(false) bool isDirty,
    @Default(CompanyUser()) CompanyUser companyUser,
    @Default(<String, dynamic>{}) Map<String, dynamic> rawCompanyUserSettings,
    @Default(CompanyUserSettings()) CompanyUserSettings companyUserSettings,
    @Default(<String>[]) List<String> notificationsEmail,
    @Default(<String, dynamic>{}) Map<String, dynamic> rawNotifications,
  }) = _User;

  factory User.fromApi(UserApi api) {
    final cu = api.companyUser ?? const CompanyUserApi();
    return User(
      id: api.id,
      firstName: api.firstName,
      lastName: api.lastName,
      email: api.email,
      phone: api.phone,
      signature: api.signature,
      languageId: api.languageId,
      oauthProviderId: api.oauthProviderId,
      oauthUserToken: api.oauthUserToken,
      oauthUserRefreshToken: api.oauthUserRefreshToken,
      googleTwoFactorEnabled: api.google2faSecret,
      verifiedPhoneNumber: api.verifiedPhoneNumber,
      hasPassword: api.hasPassword,
      userLoggedInNotification: api.userLoggedInNotification,
      customValue1: api.customValue1,
      customValue2: api.customValue2,
      customValue3: api.customValue3,
      customValue4: api.customValue4,
      lastLogin: api.lastLogin,
      emailVerifiedAt: api.emailVerifiedAt,
      createdAt: api.createdAt,
      updatedAt: api.updatedAt,
      archivedAt: api.archivedAt,
      isDeleted: api.isDeleted,
      companyUser: CompanyUser(
        permissions: cu.permissions,
        isOwner: cu.isOwner,
        isAdmin: cu.isAdmin,
        isLocked: cu.isLocked,
      ),
      rawCompanyUserSettings: cu.settings,
      companyUserSettings: CompanyUserSettings.fromJson(cu.settings),
      notificationsEmail: _emailNotifications(cu.notifications),
      rawNotifications: cu.notifications,
    );
  }

  /// Display name for the user; falls back to email when no name is set
  /// (matches the legacy admin-portal behaviour).
  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : email;
  }

  /// `true` when this user's email address has not been confirmed.
  ///
  /// **Not** "pending invite", though it was rendered as one until
  /// invoiceninja/flutter#47. Nothing on the wire expresses a pending invite;
  /// `email_verified_at` is null for four different situations:
  ///
  ///  * an invited user who never accepted — the only one the old label fit;
  ///  * an account owner who never clicked the verification email. `CreateUser`
  ///    back-dates the column at signup **only** on self-host, so on hosted an
  ///    owner can work forever with it still null;
  ///  * **anyone who has ever changed their email address** — `UserController`
  ///    nulls it on an email change and mails a fresh confirmation;
  ///  * self-hosted *owners* created before that 2021-03 auto-verify, which
  ///    shipped without a backfill migration.
  ///
  /// So this must never gate anything that assumes the user has done nothing —
  /// in particular the Recent Activity feed, which the users above legitimately
  /// fill. Nor is it worth suppressing per-platform: the invite path
  /// (`POST /users` → `UserFactory::create`) leaves the column null on hosted
  /// *and* self-hosted, so self-hosted is if anything where a null is most
  /// likely to mean a real un-accepted invite. Render it as "verification
  /// pending" — what the flag actually supports — and let the row's Resend
  /// action be the answer either way. See BACKEND.md § F4.
  bool get isEmailUnconfirmed => emailVerifiedAt == 0;

  /// Parsed permission tokens (`view_client`, `edit_invoice`, `create_all`, …).
  /// Empty when `is_admin = true` — administrators implicitly have all perms.
  List<String> get permissions {
    final s = companyUser.permissions.trim();
    if (s.isEmpty) return const <String>[];
    return s
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
  }

  /// Round-trip the domain model back to a [UserApi] for the PUT save body.
  /// The typed [companyUserSettings] is merged on top of
  /// [rawCompanyUserSettings] so unmodelled keys survive the trip.
  UserApi toApi() {
    return UserApi(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      signature: signature,
      languageId: languageId,
      oauthProviderId: oauthProviderId,
      oauthUserToken: oauthUserToken,
      oauthUserRefreshToken: oauthUserRefreshToken,
      google2faSecret: googleTwoFactorEnabled,
      verifiedPhoneNumber: verifiedPhoneNumber,
      hasPassword: hasPassword,
      userLoggedInNotification: userLoggedInNotification,
      customValue1: customValue1,
      customValue2: customValue2,
      customValue3: customValue3,
      customValue4: customValue4,
      lastLogin: lastLogin,
      emailVerifiedAt: emailVerifiedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      archivedAt: archivedAt,
      isDeleted: isDeleted,
      companyUser: CompanyUserApi(
        permissions: companyUser.permissions,
        isOwner: companyUser.isOwner,
        isAdmin: companyUser.isAdmin,
        isLocked: companyUser.isLocked,
        notifications: <String, dynamic>{
          ...rawNotifications,
          'email': notificationsEmail,
        },
        settings: <String, dynamic>{
          ...rawCompanyUserSettings,
          ...companyUserSettings.toJson(),
        },
      ),
    );
  }
}

/// Pull the `email` channel out of the raw `company_user.notifications` map.
/// Other channels (e.g. `slack`, written by the legacy app's advanced
/// notification settings) are preserved via [User.rawNotifications] and
/// re-emitted untouched on save, so editing email prefs doesn't wipe them.
List<String> _emailNotifications(Map<String, dynamic> notifications) {
  final email = notifications['email'];
  if (email is List) {
    return email.map((e) => e.toString()).toList(growable: false);
  }
  return const <String>[];
}

/// Per-(user, company) metadata. The role flags + raw permission string
/// drive feature-gating UI; not editable from User Details (lives under
/// User Management instead).
@freezed
abstract class CompanyUser with _$CompanyUser {
  const factory CompanyUser({
    @Default('') String permissions,
    @Default(false) bool isOwner,
    @Default(false) bool isAdmin,
    @Default(false) bool isLocked,
  }) = _CompanyUser;
}

/// The typed slice of `company_user.settings` the User Details screen edits.
/// Anything not here round-trips through [User.rawCompanyUserSettings].
@freezed
abstract class CompanyUserSettings with _$CompanyUserSettings {
  const CompanyUserSettings._();

  const factory CompanyUserSettings({@Default('') String accentColor}) =
      _CompanyUserSettings;

  factory CompanyUserSettings.fromJson(Map<String, dynamic> json) {
    return CompanyUserSettings(
      accentColor: json['accent_color']?.toString() ?? '',
    );
  }

  /// Serialise the typed fields back into a JSON map. Callers merge this on
  /// top of [User.rawCompanyUserSettings] so unmodelled keys (the React
  /// preferences blob, dashboard prefs, …) survive the round-trip.
  ///
  /// `accent_color` is emitted even when empty: a reset sets it to `''`, and
  /// without the key here the merge would keep the stale value from
  /// [User.rawCompanyUserSettings] and the reset wouldn't persist.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'accent_color': accentColor,
  };
}
