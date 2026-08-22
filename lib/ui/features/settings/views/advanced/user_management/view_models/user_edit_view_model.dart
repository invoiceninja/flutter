import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/domain/notifications.dart';
import 'package:admin/domain/permissions.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the User Management edit + create screen.
///
/// Holds three concerns alongside the generic draft state:
///   * **Permissions draft buffer** — flipping `is_admin` on clears the
///     server-side permission string; React loses the previous selection
///     on toggle-off. This VM keeps the prior permission list in a buffer
///     so flipping admin off in-session restores what was there. Buffer is
///     never sent to the server.
///   * **Notification global state** — a 3-state selector at the top of
///     the Notifications tab (all_records / owned_by_user / custom). When
///     not custom, individual per-event rows mute and the buffer holds the
///     prior custom selection.
///   * **Owner read-only** — when the user being edited is the owner, the
///     Permissions tab renders as a read-only summary and the Save path
///     only writes Details + Notifications.
class UserEditViewModel extends GenericEditViewModel<User> {
  UserEditViewModel({
    required this.repo,
    required this.companyId,
    User? existing,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: existing ?? const User(),
         original: existing,
         companyId: companyId,
       ) {
    final draftPerms = existing?.permissions ?? const <String>[];
    _permissionDraft = List<String>.of(draftPerms);
    final tokens = existing?.notificationsEmail ?? const <String>[];
    _globalNotification = globalFromTokens(tokens);
    // When the server stored a global token (`all_notifications` /
    // `all_user_notifications`), the per-event tokens are absent. Seed the
    // buffer with the implied per-event state so flipping to `custom`
    // doesn't drop the user into a wall of "none" rows.
    final impliedChoice = switch (_globalNotification) {
      NotificationGlobal.allRecords => NotificationChoice.all,
      NotificationGlobal.ownedByUser => NotificationChoice.user,
      NotificationGlobal.custom => null,
    };
    _perEventBuffer = <String, NotificationChoice>{
      for (final event in kNotificationEvents)
        event.id: impliedChoice ?? choiceFromTokens(event.id, tokens),
    };
    // Tokens the tab doesn't model (self-profile toggles, future events) are
    // re-appended on every flush so an admin edit never silently drops them.
    _unknownNotificationTokens = unmodeledNotificationTokens(tokens);
  }

  final UserRepository repo;
  final String companyId;

  // ── Permissions ─────────────────────────────────────────────────────

  late List<String> _permissionDraft;

  /// Currently-active permission list. When `is_admin = true`, this returns
  /// an empty list (server contract: admins have no permission string); the
  /// buffer survives the toggle so flipping off restores the previous grid.
  List<String> get permissions => draft.companyUser.isAdmin
      ? const <String>[]
      : List.unmodifiable(_permissionDraft);

  bool get isAdmin => draft.companyUser.isAdmin;
  bool get isOwner => draft.companyUser.isOwner;
  bool get isLocked => draft.companyUser.isLocked;

  void setAdmin(bool value) {
    // Server contract: admins have an empty permissions string. We DO clear
    // the draft's serialized string on toggle-on so the save matches React.
    // The in-memory `_permissionDraft` buffer survives the toggle, so
    // flipping admin off in-session restores the grid.
    final cu = draft.companyUser.copyWith(
      isAdmin: value,
      permissions: value ? '' : _permissionDraft.join(','),
    );
    updateDraft(draft.copyWith(companyUser: cu));
  }

  void togglePermission(String token) {
    if (isAdmin) return;
    final next = List<String>.of(_permissionDraft);
    if (next.remove(token)) {
      _permissionDraft = next;
    } else {
      next.add(token);
      _permissionDraft = next;
    }
    _flushPermissionsToDraft();
  }

  /// Set the comma-separated permission string directly. Used by the
  /// "All" column auto-promote when 14 entity checks resolve to `<verb>_all`.
  void setPermissions(List<String> next) {
    if (isAdmin) return;
    _permissionDraft = List<String>.of(next);
    _flushPermissionsToDraft();
  }

  /// Returns `true` when [token] is granted — either explicitly, or
  /// inherited from a `*_all` row covering its verb. Admin grants everything
  /// except the [kPermissionNegative] tokens, which take an ability away and
  /// so never apply to an admin.
  bool hasPermission(String token) {
    // Negative tokens invert the admin grant: an admin is never blocked from
    // sending email, so the row must read OFF, not ON.
    if (isAdmin) return !kPermissionNegative.contains(token);
    if (_permissionDraft.contains(token)) return true;
    // Inherit from <verb>_all when this is an entity-verb token.
    for (final verb in kPermissionVerbs) {
      for (final entity in kPermissionEntities) {
        if (token == permissionToken(verb: verb, entity: entity) &&
            _permissionDraft.contains(permissionAllToken(verb))) {
          return true;
        }
      }
    }
    return false;
  }

  /// Whether the `<verb>_all` row is set (and therefore the per-entity rows
  /// in that column render as muted-checked).
  bool isAllSet(String verb) =>
      !isAdmin && _permissionDraft.contains(permissionAllToken(verb));

  void _flushPermissionsToDraft() {
    final next = draft.companyUser.copyWith(
      permissions: _permissionDraft.join(','),
    );
    updateDraft(draft.copyWith(companyUser: next));
  }

  // ── Notifications ───────────────────────────────────────────────────

  NotificationGlobal _globalNotification = NotificationGlobal.custom;
  late Map<String, NotificationChoice> _perEventBuffer;
  late List<String> _unknownNotificationTokens;

  NotificationGlobal get globalNotification => _globalNotification;

  NotificationChoice notificationChoiceFor(String eventId) =>
      _perEventBuffer[eventId] ?? NotificationChoice.none;

  bool get notificationsGlobal =>
      _globalNotification != NotificationGlobal.custom;

  void setNotificationGlobal(NotificationGlobal value) {
    _globalNotification = value;
    _flushNotificationsToDraft();
  }

  void setNotificationChoice(String eventId, NotificationChoice choice) {
    _perEventBuffer = <String, NotificationChoice>{
      ..._perEventBuffer,
      eventId: choice,
    };
    if (_globalNotification != NotificationGlobal.custom) {
      // First per-event edit while a global is engaged drops us into custom mode.
      _globalNotification = NotificationGlobal.custom;
    }
    _flushNotificationsToDraft();
  }

  void _flushNotificationsToDraft() {
    final tokens = tokensFor(
      global: _globalNotification,
      perEvent: _perEventBuffer,
    );
    // Re-append the tokens the tab doesn't model so they survive the save —
    // no overlap with `tokens` (those are globals / known-event tokens only).
    updateDraft(
      draft.copyWith(
        notificationsEmail: [...tokens, ..._unknownNotificationTokens],
      ),
    );
  }

  // ── Details setters ─────────────────────────────────────────────────

  void setFirstName(String v) => setStr((d, n) => d.copyWith(firstName: n), v);
  void setLastName(String v) => setStr((d, n) => d.copyWith(lastName: n), v);
  void setEmail(String v) => setStr((d, n) => d.copyWith(email: n), v);
  void setPhone(String v) => setStr((d, n) => d.copyWith(phone: n), v);
  void setCustomValue1(String v) =>
      setStr((d, n) => d.copyWith(customValue1: n), v);
  void setCustomValue2(String v) =>
      setStr((d, n) => d.copyWith(customValue2: n), v);
  void setCustomValue3(String v) =>
      setStr((d, n) => d.copyWith(customValue3: n), v);
  void setCustomValue4(String v) =>
      setStr((d, n) => d.copyWith(customValue4: n), v);
  void setUserLoggedInNotification(bool v) =>
      setBool((d, n) => d.copyWith(userLoggedInNotification: n), v);

  // ── Persistence ─────────────────────────────────────────────────────

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.firstName.isNotEmpty ||
        d.lastName.isNotEmpty ||
        d.email.isNotEmpty ||
        d.phone.isNotEmpty;
  }

  @override
  Future<SaveResult<User>> performSave() async {
    if (isCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, user: draft);
  }
}
