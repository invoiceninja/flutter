/// Who an "Assigned User" field may offer, and the one rule behind the
/// device-local "Hide unverified users" preference (invoiceninja/flutter#150).
///
/// A leaf on purpose — `User` in, `User` out — so the whole policy is unit
/// testable and so the two surfaces that render it ([isHiddenFromAssignment] is
/// called by the picker *and* by the User Management roster badge) cannot
/// drift apart.
///
/// **This is not a re-run of the owner exclusion invoiceninja/flutter#46
/// removed.** `test/lint/no_user_list_owner_filter_test.dart` fails the build
/// on any attempt to send the server's `hideOwnerUsers` / `without=` params,
/// because doing so made the account owner unassignable app-wide for everyone,
/// always, with no way back. The rule here is the opposite shape: opt-in,
/// off by default, device-local, and it *never* hides an owner — see
/// [isHiddenFromAssignment].
library;

import 'package:admin/data/models/domain/user.dart';

/// `true` when [u] should be kept out of Assigned User fields while the
/// preference is on.
///
/// [User.looksNeverOnboarded] carries the record-level half (no confirmed
/// email, no password, no linked OAuth provider, no previously-confirmed
/// address). The two exemptions below are *policy* and so live here:
///
///  * **the account owner** — `is_owner` is an indexed Drift column, and the
///    two owner-shaped § F4 cases (a hosted owner who never clicked verify, a
///    pre-2021 self-hosted one) both land here. Belt as well as braces: their
///    passwords already exempt them, and this makes #46's guarantee structural
///    rather than incidental.
///  * **the signed-in user** — `AuthRepository._persistAndActivate` hand-builds
///    your own row's payload without `email_verified_at`, `has_password` or
///    `last_confirmed_email_address`, so after any delta `/refresh` you look
///    un-onboarded to yourself. It is also what keeps the roster non-empty,
///    which is why `AssignedUserPickerField` can still go without an
///    `emptyHintKey`.
///
/// An empty [signedInUserId] (the session is momentarily null during logout)
/// matches no real id, so it exempts nobody rather than everybody.
bool isHiddenFromAssignment(User u, {required String signedInUserId}) {
  if (u.id == signedInUserId) return false;
  if (u.companyUser.isOwner) return false;
  return u.looksNeverOnboarded;
}

/// Rows an Assigned User field can offer at all, before the preference has any
/// say. Shared by [assignableUsers] and [hiddenFromAssignmentCount] because the
/// two must agree by construction: one decides what the pickers show, the other
/// is the number Device Settings renders as *that filter's* effect, and a
/// divergence would make the card and the User Management badges contradict
/// each other on the same roster.
///
/// `archivedAt` is an int epoch (0 = not archived) and is **never null**, so an
/// `== null` test analyzes as dead code and filters the roster to nothing.
bool _isActive(User u) => u.archivedAt == 0 && !u.isDeleted;

/// The company roster as an Assigned User field should offer it.
///
/// Three steps, and the first and last are not optional however incidental
/// they look — `UserDao.watchAllForCompany` is a bare
/// `select(users)..where(companyId)` with no `ORDER BY` and no state
/// predicate, so both have to be re-applied on top:
///
///  1. drop archived / soft-deleted rows ([_isActive], shared with
///     [hiddenFromAssignmentCount] so the pickers and the Device Settings count
///     cannot disagree).
///  2. when [hideUnverified], drop [isHiddenFromAssignment] rows.
///  3. sort by display name, tie-breaking on id — `List.sort` is not stable in
///     Dart, so without the tiebreak two users sharing a display name swap
///     places between Drift emissions and reorder the list under the user's
///     finger.
///
/// With `hideUnverified: false` the result is exactly what shipped before
/// #150: step 2 is the only difference.
List<User> assignableUsers(
  List<User> users, {
  required bool hideUnverified,
  required String signedInUserId,
}) {
  final out = users
      .where(_isActive)
      .where(
        (u) =>
            !hideUnverified ||
            !isHiddenFromAssignment(u, signedInUserId: signedInUserId),
      )
      .toList();
  out.sort((a, b) {
    final byName = a.displayName.toLowerCase().compareTo(
      b.displayName.toLowerCase(),
    );
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });
  return out;
}

/// How many of [users] the preference would hide right now — the number the
/// Device Settings card renders so the toggle can show its own effect.
///
/// Counted over the *active* roster, because archived and soft-deleted rows
/// are already absent from every picker whatever this preference says.
int hiddenFromAssignmentCount(
  List<User> users, {
  required String signedInUserId,
}) => users
    .where(_isActive)
    .where((u) => isHiddenFromAssignment(u, signedInUserId: signedInUserId))
    .length;
