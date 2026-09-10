import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/entity_picker_field.dart';
import 'package:admin/ui/features/tasks/view_models/task_filters_mixin.dart';

typedef _Named = ({String id, String name});

/// Rows offered for an empty query, matching `ClientFilterKey`'s own suggestion
/// cap rather than `SearchableDropdownField`'s edit-form default of 20. A
/// filter's list is the user's whole working set; an edit form's is one value.
const int _kFilterIdleResults = 50;

/// Projects a repository's `watch(id)` emission into the `(id, name)` record the
/// list stream deals in, preserving null. Shared by the two record-typed
/// pickers so they cannot drift on the null handling; the assignee picker is
/// `EntityPickerField<User>` and passes `services.user.watch` straight through.
///
/// Note it constrains only the null case — the name fallback lives in each
/// picker's `displayString`, which covers the spliced-in resolved record too.
_Named? Function(T?) _namedOrNull<T extends Object>(_Named Function(T) of) =>
    (value) => value == null ? null : of(value);

/// Client-side task filter bar: Project / Client / Assignee pickers + Clear.
/// Shared by every task view (kanban, calendar, daily, weekly) — bound to any
/// view-model that mixes in [TaskFiltersMixin]. Each picker clears to "no
/// filter" (null → ''). Rebuilds when the filter state changes via
/// [ListenableBuilder] on [filters].
///
/// All three pickers are [EntityPickerField], not a `StreamBuilder` +
/// `SearchableDropdownField` pair, and that is load-bearing in three ways this
/// file learned the hard way (the invoiceninja/flutter#134 follow-up).
///
/// **The selection is resolved by id, not by scanning the visible list.** The
/// old shape (`items.where((c) => c.id == filters.clientId).firstOrNull`) is
/// verbatim the anti-pattern [EntityPickerField]'s class doc exists to kill.
/// The client and project streams are active-only, and the roster is filtered
/// to active below, so archiving — or deleting — the
/// selected record dropped it from `items`, `initialValue` went null, and
/// `SearchableDropdownField.didUpdateWidget` reset the field **without firing
/// `onChanged`**. The mixin kept the id, `matchesFilters` kept excluding, and
/// the user was left with a blank field (no ✕ either — `canClear` reads the
/// controller text) over a list filtered by an invisible criterion, with only
/// the Clear button to hint at it. Nothing re-syncs it: this bar is the mixin's
/// sole mutator and no host view model watches a client / project / user stream.
///
/// **The lists are whole-table name queries, matching the Tasks list's own
/// filter.** `ClientFilterKey.watchValueSuggestions` reads
/// `clients.watchActiveNames`; this used `watchPage(loadedPages: 100)`, a
/// 5000-row window with a full `jsonDecode` + `ClientApi.fromJson` per row that
/// never came close to binding — the real ceiling is that login prefetches
/// **page 1 only**, so the picker offered the alphabetically-first 20 of the 50
/// most recently created clients. Assignees go through `watchAllForPicker`,
/// whose dartdoc says "for the assignee filter picker"; four other assignee
/// surfaces already used it and this one did not.
///
/// **The streams are no longer rebuilt per notify.** [EntityPickerField] routes
/// them through `WatchBuilder` keyed on [EntityPickerField.cacheKey], where the old inline
/// `stream:` expressions sat inside the [ListenableBuilder] and so re-queried
/// Drift three times on every filter change.
class TaskFilterBar extends StatelessWidget {
  const TaskFilterBar({
    required this.filters,
    required this.companyId,
    super.key,
  });

  final TaskFiltersMixin filters;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final tokens = context.inTheme;

    return ListenableBuilder(
      listenable: filters,
      builder: (context, _) {
        final projectPicker = EntityPickerField<_Named>(
          label: context.tr('project'),
          cacheKey: companyId,
          selectedId: filters.projectId,
          itemsStream: () =>
              services.projects.watchActiveNames(companyId: companyId),
          watchById: (id) => services.projects
              .watch(companyId: companyId, id: id)
              .map(_namedOrNull((p) => (id: p.id, name: p.name))),
          // The list rows are already safe — `ProjectRepository
          // .watchActiveNames` falls back to the id, like its Client and Vendor
          // twins. This covers the OTHER path: `watchById` above goes through
          // `BaseEntityRepository.watch`, which the repo-level fallback never
          // sees, and that record is what `EntityPickerField` splices in for a
          // selection outside the list. So it is not redundant with the repo.
          // `.trim()`, matching the repo, or a whitespace-only name still
          // renders blank.
          displayString: (p) => p.name.trim().isEmpty ? p.id : p.name,
          idOf: (p) => p.id,
          // A company with no projects is an ordinary configuration, and its
          // stream settles on `[]` for good — so this really is "you have
          // none", not "still loading". Without the key the disabled
          // placeholder reads "Loading" for ever.
          emptyHintKey: 'no_records_found',
          idleResults: _kFilterIdleResults,
          onChanged: (p) => filters.setProjectFilter(p?.id ?? ''),
        );

        final clientPicker = EntityPickerField<_Named>(
          label: context.tr('client'),
          cacheKey: companyId,
          selectedId: filters.clientId,
          itemsStream: () =>
              services.clients.watchActiveNames(companyId: companyId),
          // `watchActiveNames` prefers `display_name` then `name`; the `?? id`
          // tail lives in `displayString` below so it covers this projection
          // too. It has to: `BaseEntityDao.watchById` has no archived/deleted
          // predicate, so an archived client stays *resolvable* while dropping
          // out of the list — `EntityPickerField` then splices it back in, and
          // a nameless one would render as a blank field over an active
          // filter, which is the defect this whole widget exists to remove.
          watchById: (id) => services.clients
              .watch(companyId: companyId, id: id)
              .map(
                _namedOrNull(
                  (c) => (
                    id: c.id,
                    name: c.displayName.isNotEmpty ? c.displayName : c.name,
                  ),
                ),
              ),
          displayString: (c) => c.name.trim().isEmpty ? c.id : c.name,
          idOf: (c) => c.id,
          emptyHintKey: 'no_records_found',
          idleResults: _kFilterIdleResults,
          onChanged: (c) => filters.setClientFilter(c?.id ?? ''),
        );

        final assigneePicker = EntityPickerField<User>(
          label: context.tr('assigned_user'),
          cacheKey: companyId,
          selectedId: filters.assignedUserId,
          // `watchAllForPicker` is the whole-roster accessor, but unlike the
          // `watchPage` this replaced it is a bare `select(users)..where(
          // companyId)` — **no `orderBy` and no state filter**. Restore both
          // here, or the dropdown falls back to rowid order and starts offering
          // archived and soft-deleted users as filter values.
          //
          // At the call site rather than in the repository on purpose:
          // `watchAllForPicker`'s three other callers include
          // `client_edit_settings_section.dart`, which resolves its selection
          // by scanning the window — narrowing the stream there would blank a
          // client assigned to a since-archived user. Safe here because
          // `EntityPickerField` splices the resolved selection back in.
          // `activity_filter_sheet.dart` sorts at its call site for the same
          // reason.
          itemsStream: () => services.user
              .watchAllForPicker(companyId: companyId)
              .map(
                (users) =>
                    users
                        // `archivedAt` is an int epoch, 0 = not archived —
                        // never null. `== null` analyzes as dead code and
                        // would have filtered the roster to nothing.
                        .where((u) => u.archivedAt == 0 && !u.isDeleted)
                        .toList()
                      ..sort((a, b) {
                        final byName = a.displayName.toLowerCase().compareTo(
                          b.displayName.toLowerCase(),
                        );
                        // Tiebreak on id: `List.sort` is NOT stable in Dart, so
                        // two users sharing a display name would otherwise swap
                        // places between Drift emissions and reorder the list
                        // under the user's finger. `UserDao` had a secondary
                        // `OrderingTerm(u.id)` for the same reason.
                        return byName != 0 ? byName : a.id.compareTo(b.id);
                      }),
              ),
          watchById: (id) => services.user.watch(companyId: companyId, id: id),
          displayString: (u) =>
              u.displayName.trim().isEmpty ? u.id : u.displayName,
          idOf: (u) => u.id,
          // Deliberately NO `emptyHintKey`, unlike its two siblings: the roster
          // arrives bundled on `/refresh` and always holds at least the
          // signed-in user, so an empty list here really is a loading state.
          idleResults: _kFilterIdleResults,
          onChanged: (u) => filters.setAssigneeFilter(u?.id ?? ''),
        );

        final clearButton = filters.filtersActive
            ? TextButton.icon(
                onPressed: filters.clearFilters,
                icon: const Icon(Icons.clear, size: 16),
                label: Text(context.tr('clear')),
              )
            : null;

        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: InSpacing.sm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Three side-by-side searchable pickers need ~180px each; below
              // the wide breakpoint they'd collapse to unusable widths, so
              // stack them full-width instead.
              if (Breakpoints.isWide(constraints)) {
                return Row(
                  children: [
                    Expanded(child: projectPicker),
                    SizedBox(width: InSpacing.md(context)),
                    Expanded(child: clientPicker),
                    SizedBox(width: InSpacing.md(context)),
                    Expanded(child: assigneePicker),
                    if (clearButton != null) ...[
                      SizedBox(width: InSpacing.md(context)),
                      clearButton,
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  projectPicker,
                  const SizedBox(height: InSpacing.sm),
                  clientPicker,
                  const SizedBox(height: InSpacing.sm),
                  assigneePicker,
                  if (clearButton != null)
                    Align(alignment: Alignment.centerRight, child: clearButton),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
