// The hide rule behind Settings → Device Settings → Users → "Hide unverified
// users" (invoiceninja/flutter#150).
//
// `email_verified_at == null` means four different things (BACKEND.md § F4),
// and three of them are active, working users — badging all four "Pending
// invite" is what invoiceninja/flutter#47 was reported as, and *hiding* all
// four would be the same mistake somewhere worse. So there is one case per
// conjunct here, each named after the real person it protects, and only the
// never-accepted invite is actually hidden.

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/user.dart';
import 'package:admin/domain/assignable_users.dart';

/// Defaults describe a fully-onboarded colleague, so each case below sets only
/// the one field it is about.
User _user(
  String id, {
  String first = '',
  String last = '',
  int emailVerifiedAt = 1700000000,
  bool hasPassword = true,
  String oauthProviderId = '',
  String lastConfirmedEmailAddress = '',
  bool isOwner = false,
  int archivedAt = 0,
  bool isDeleted = false,
}) => const User().copyWith(
  id: id,
  firstName: first,
  lastName: last,
  emailVerifiedAt: emailVerifiedAt,
  hasPassword: hasPassword,
  oauthProviderId: oauthProviderId,
  lastConfirmedEmailAddress: lastConfirmedEmailAddress,
  companyUser: CompanyUser(isOwner: isOwner),
  archivedAt: archivedAt,
  isDeleted: isDeleted,
);

/// § F4 case 1 — invited, never accepted. `UserFactory::create` sets no
/// password and nothing sets `email_verified_at` until the invite is taken up.
User _invitee(String id, {String first = '', String last = ''}) =>
    _user(id, first: first, last: last, emailVerifiedAt: 0, hasPassword: false);

List<String> _ids(List<User> users, {bool hide = true, String me = 'nobody'}) =>
    assignableUsers(
      users,
      hideUnverified: hide,
      signedInUserId: me,
    ).map((u) => u.id).toList();

void main() {
  group('isHiddenFromAssignment', () {
    test('hides an invited user who never accepted', () {
      expect(
        isHiddenFromAssignment(_invitee('u1'), signedInUserId: 'me'),
        isTrue,
      );
    });

    test('keeps an ordinary verified colleague', () {
      expect(
        isHiddenFromAssignment(_user('u1'), signedInUserId: 'me'),
        isFalse,
      );
    });

    // § F4 case 2 / 4 — a hosted owner who never clicked verify, and a
    // self-hosted one created before the 2021-03 auto-verify. Both have a
    // password, so `!hasPassword` alone already saves them; the owner check is
    // what makes invoiceninja/flutter#46's guarantee structural.
    test('keeps an unverified account owner (password)', () {
      final u = _user('u1', emailVerifiedAt: 0, isOwner: true);
      expect(isHiddenFromAssignment(u, signedInUserId: 'me'), isFalse);
    });

    test('keeps an owner with no password either — an OAuth signup', () {
      // `LoginController` creates these with `'password' => ''` and leaves
      // `email_verified_at` null (its `= now()` line is commented out), so
      // every conjunct but `is_owner` points at hiding them.
      final u = _user(
        'u1',
        emailVerifiedAt: 0,
        hasPassword: false,
        isOwner: true,
      );
      expect(isHiddenFromAssignment(u, signedInUserId: 'me'), isFalse);
    });

    test('keeps a non-owner who signed in with OAuth', () {
      final u = _user(
        'u1',
        emailVerifiedAt: 0,
        hasPassword: false,
        oauthProviderId: 'google',
      );
      expect(isHiddenFromAssignment(u, signedInUserId: 'me'), isFalse);
    });

    // § F4 case 3 — `UserController::update` nulls `email_verified_at` on every
    // email change. With a password that is already covered; the case this
    // field exists for is an OAuth user changing their address, because the
    // same update nulls all four `oauth_*` columns at the same time.
    test('keeps someone who merely changed their email address', () {
      final u = _user(
        'u1',
        emailVerifiedAt: 0,
        lastConfirmedEmailAddress: 'old@example.com',
      );
      expect(isHiddenFromAssignment(u, signedInUserId: 'me'), isFalse);
    });

    test('keeps an OAuth user who changed their email address', () {
      final u = _user(
        'u1',
        emailVerifiedAt: 0,
        hasPassword: false,
        oauthProviderId: '',
        lastConfirmedEmailAddress: 'old@example.com',
      );
      expect(isHiddenFromAssignment(u, signedInUserId: 'me'), isFalse);
    });

    test('never hides the signed-in user', () {
      // `_persistAndActivate` hand-builds your own row without
      // `email_verified_at` or `has_password`, so after a delta `/refresh` you
      // look exactly like a never-accepted invite to yourself.
      expect(
        isHiddenFromAssignment(_invitee('me'), signedInUserId: 'me'),
        isFalse,
      );
    });

    test('an empty signed-in id exempts nobody rather than everybody', () {
      expect(
        isHiddenFromAssignment(_invitee('u1'), signedInUserId: ''),
        isTrue,
      );
    });
  });

  group('assignableUsers', () {
    test('drops archived and soft-deleted rows whatever the flag', () {
      final roster = [
        _user('u1', first: 'Ada'),
        _user('u2', first: 'Bob', archivedAt: 1700000000),
        _user('u3', first: 'Cleo', isDeleted: true),
      ];
      expect(_ids(roster, hide: false), ['u1']);
      expect(_ids(roster), ['u1']);
    });

    test('hideUnverified: false changes nothing but the hide step', () {
      final roster = [_user('u1', first: 'Ada'), _invitee('u2', first: 'Bob')];
      expect(_ids(roster, hide: false), ['u1', 'u2']);
      expect(_ids(roster), ['u1']);
    });

    test('sorts by display name, case-insensitively', () {
      final roster = [
        _user('u1', first: 'zoe'),
        _user('u2', first: 'Ada'),
        _user('u3', first: 'Mike'),
      ];
      expect(_ids(roster), ['u2', 'u3', 'u1']);
    });

    test('breaks a display-name tie on the id', () {
      // `List.sort` is not stable in Dart, so without the tiebreak two users
      // sharing a name swap places between Drift emissions and reorder the
      // list under the user's finger.
      final roster = [
        _user('u9', first: 'Sam', last: 'Smith'),
        _user('u2', first: 'Sam', last: 'Smith'),
      ];
      expect(_ids(roster), ['u2', 'u9']);
    });
  });

  group('hiddenFromAssignmentCount', () {
    test('counts only what the rule would actually hide', () {
      final roster = [
        _user('u1', first: 'Ada'),
        _invitee('u2', first: 'Bob'),
        _invitee('u3', first: 'Cleo'),
        _user('u4', first: 'Olive', emailVerifiedAt: 0, isOwner: true),
        _invitee('me', first: 'Me'),
      ];
      expect(hiddenFromAssignmentCount(roster, signedInUserId: 'me'), 2);
    });

    test('ignores archived and soft-deleted rows', () {
      // They are absent from every picker regardless, so counting them would
      // report an effect the preference does not have.
      final roster = [
        _invitee('u1'),
        _user('u2', emailVerifiedAt: 0, hasPassword: false, archivedAt: 1),
        _user('u3', emailVerifiedAt: 0, hasPassword: false, isDeleted: true),
      ];
      expect(hiddenFromAssignmentCount(roster, signedInUserId: 'me'), 1);
    });

    test('is zero for an all-verified roster', () {
      expect(
        hiddenFromAssignmentCount([
          _user('u1'),
          _user('u2'),
        ], signedInUserId: 'me'),
        0,
      );
    });
  });
}
