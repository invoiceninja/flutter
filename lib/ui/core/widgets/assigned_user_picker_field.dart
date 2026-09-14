import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/entity_picker_field.dart';

/// The company roster as an "Assigned User" picker.
///
/// One home for a query that was written out in five places in two
/// incompatible shapes — four hand-rolling a linear scan of a `watchPage`
/// window for the selection, and `task_filter_bar.dart` getting it right. Two
/// of those call sites are on this leaf today; the filter bar keeps a copy that
/// is byte-identical to the body below until `task_filter_bar_wiring_test.dart`
/// is rewritten to point here, and the four scans are still owed the migration
/// (they are listed in CLAUDE.md § Forms — Searchable pickers). It reads
/// [Services] directly rather than taking
/// streams, which is the trade `UserNameLabel` and `UserAvatar` in this same
/// directory already make: the leaf property [EntityPickerField] guards is
/// worth one line at a call site only while the projections differ per entity,
/// and for the roster they never do.
///
/// Four invariants, none of which is visible at a call site:
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
  });

  final String companyId;

  /// The id the host form holds. Empty means unassigned — [EntityPickerField]
  /// short-circuits on it, so that costs no subscription.
  final String selectedId;

  /// Receives the picked user's id, or `''` when the field is cleared.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return EntityPickerField<User>(
      label: context.tr('assigned_user'),
      cacheKey: companyId,
      selectedId: selectedId,
      itemsStream: () => services.user
          .watchAllForPicker(companyId: companyId)
          .map(
            (users) =>
                users.where((u) => u.archivedAt == 0 && !u.isDeleted).toList()
                  ..sort((a, b) {
                    final byName = a.displayName.toLowerCase().compareTo(
                      b.displayName.toLowerCase(),
                    );
                    return byName != 0 ? byName : a.id.compareTo(b.id);
                  }),
          ),
      watchById: (id) => services.user.watch(companyId: companyId, id: id),
      // Falls back to the record id, never `(no name)`: a repeated `(no name)`
      // cannot tell two nameless rows apart in a list you must pick from. Note
      // the sort above keys on `displayName`, so a row that falls back here
      // sorts as '' (top) while rendering as an id — reachable only for a user
      // with no name AND no email, since `displayName` already falls back to
      // the address. Left as-is so this stays byte-identical to the filter
      // bar's copy.
      displayString: (u) => u.displayName.trim().isEmpty ? u.id : u.displayName,
      idOf: (u) => u.id,
      onChanged: (u) => onChanged(u?.id ?? ''),
    );
  }
}
