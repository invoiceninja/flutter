import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/assignable_users.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/entity_picker_field.dart';

/// The company roster as an "Assigned User" picker.
///
/// One home for a query that was written out in six places in two incompatible
/// shapes — five hand-rolling a linear scan of a window for the selection, and
/// `task_filter_bar.dart` getting it right. All six assignment call sites are
/// on this leaf now. It reads [Services] directly rather than taking streams,
/// which is the trade `UserNameLabel` and `UserAvatar` in this same directory
/// already make: the leaf property [EntityPickerField] guards is worth one line
/// at a call site only while the projections differ per entity, and for the
/// roster they never do. (A consequence for tests: a `noSuchMethod`
/// `implements Services` fake under a widget that mounts this must answer
/// `user`, `auth` **and** `hideUnverifiedUsers`.)
///
/// `task_filter_bar.dart` keeps its own copy, and since
/// invoiceninja/flutter#150 that copy is **no longer byte-identical and must
/// not be "restored to parity"**: a *filter* has to offer every user the data
/// might reference, or work already assigned to a hidden person becomes
/// unfindable. Only the fields that *write* an `assigned_user_id` filter.
///
/// Five invariants, none of which is visible at a call site:
///
///  * **`watchAllForPicker`, not `watchPage`.** A paged entity read offers only
///    what page 1 of the login prefetch left in Drift and pays a full
///    `jsonDecode` per row for the privilege. The roster is small, local-only
///    and arrives bundled on `/refresh`, so it is fetched whole.
///  * **The active filter and the sort are re-applied here.**
///    `UserDao.watchAllForCompany` is a bare `select(users)..where(companyId)` —
///    no `ORDER BY`, no state predicate — so without the `where` the dropdown
///    offers archived and soft-deleted users and without the sort it is in
///    rowid order. `archivedAt` is an int epoch (0 = not archived), **never
///    null**: an `== null` test analyzes as dead code and filters the roster to
///    nothing. The id tiebreak is load-bearing too — `List.sort` is not stable
///    in Dart, so two users sharing a display name would swap places between
///    Drift emissions and reorder the list under the user's finger.
///  * **The selection resolves through `watch(id)`, never by scanning the
///    list.** The stream above is active-only, so archiving the assigned user
///    would otherwise drop them from `items`,
///    `SearchableDropdownField.didUpdateWidget` would blank the field *without*
///    firing `onChanged`, and the form would silently lose an assignment it
///    still holds. [EntityPickerField] splices the resolved record back in and
///    is sticky, so a stream hiccup can't blank a populated field either.
///  * **The hide rule is applied here and nowhere else.** With
///    `services.hideUnverifiedUsers` on, `assignableUsers` drops users the
///    payload shows no evidence have ever signed in — never the account owner
///    (invoiceninja/flutter#46), never the signed-in user, and never the
///    currently-selected one, which [EntityPickerField] splices back in. The
///    flag rides in the `cacheKey`, because `WatchBuilder` re-creates the
///    stream only when that changes.
///  * **Deliberately no `emptyHintKey`.** The roster always holds at least the
///    signed-in user (`CompanyTransformer::includeUsers` is not admin-gated),
///    so an empty list really is a loading state and `'loading'` — the default
///    placeholder — is the truthful copy. Its Project and Client siblings pass
///    `'no_records_found'` because a company can genuinely have none.
///
/// Safe inside a form that rebuilds per keystroke: [EntityPickerField] routes
/// [EntityPickerField.itemsStream] through `WatchBuilder`, which re-creates the
/// stream only when [companyId] changes.
class AssignedUserPickerField extends StatelessWidget {
  const AssignedUserPickerField({
    super.key,
    required this.companyId,
    required this.selectedId,
    required this.onChanged,
    this.labelKey = 'assigned_user',
  });

  final String companyId;

  /// Localization key for the field label. Defaults to the majority spelling;
  /// `billing_doc_settings_tab.dart` passes `'user'`, which is what its field
  /// has always been called on the five billing edit screens.
  final String labelKey;

  /// The id the host form holds. Empty means unassigned — [EntityPickerField]
  /// short-circuits on it, so that costs no subscription.
  final String selectedId;

  /// Receives the picked user's id, or `''` when the field is cleared.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    // Listened, never read once: an edit or detail screen stays mounted behind
    // the `/settings/**` route while the switch is flipped, so a build-time
    // read with no listener keeps offering the old list until some unrelated
    // rebuild happens to come along.
    return ValueListenableBuilder<bool>(
      valueListenable: services.hideUnverifiedUsers,
      builder: (context, hideUnverified, _) =>
          // The session is listened to as well, and for the same reason the
          // preference is: `signedInUserId` is the other input to the
          // projection, and `AuthRepository.restore()` can hand us a session
          // whose `userId` is still `''` (it starts empty and stays that way
          // when the restored company's `user_settings` row is missing or its
          // lookup throws). An empty id exempts nobody — and because
          // `_persistAndActivate` writes your own row without
          // `email_verified_at`, `has_password` or
          // `last_confirmed_email_address`, *you* then satisfy every conjunct
          // and vanish from your own field. The background refresh that
          // repopulates `userId` cannot heal a mounted picker without this.
          ValueListenableBuilder<AuthSession?>(
            valueListenable: services.auth.session,
            builder: (context, session, _) =>
                _build(context, services, hideUnverified, session),
          ),
    );
  }

  Widget _build(
    BuildContext context,
    Services services,
    bool hideUnverified,
    AuthSession? session,
  ) {
    final meId = session?.userId ?? '';
    return EntityPickerField<User>(
      label: context.tr(labelKey),
      // The flag and the signed-in id are both inputs to the projection below,
      // and `WatchBuilder` re-creates `itemsStream` only when `cacheKey`
      // changes — records compare by value, so the tuple is what makes a flip
      // of the switch actually re-filter. It costs no visible blink:
      // `StreamBuilder.afterDisconnected` preserves the previous snapshot
      // across the swap.
      cacheKey: (companyId, hideUnverified, meId),
      selectedId: selectedId,
      itemsStream: () => services.user
          .watchAllForPicker(companyId: companyId)
          .map(
            (users) => assignableUsers(
              users,
              hideUnverified: hideUnverified,
              signedInUserId: meId,
            ),
          ),
      watchById: (id) => services.user.watch(companyId: companyId, id: id),
      // Falls back to the record id, never `(no name)`: a repeated `(no name)`
      // cannot tell two nameless rows apart in a list you must pick from. Note
      // `assignableUsers` sorts on `displayName`, so a row that falls back here
      // sorts as '' (top) while rendering as an id — reachable only for a user
      // with no name AND no email, since `displayName` already falls back to
      // the address.
      displayString: (u) => u.displayName.trim().isEmpty ? u.id : u.displayName,
      idOf: (u) => u.id,
      onChanged: (u) => onChanged(u?.id ?? ''),
    );
  }
}
