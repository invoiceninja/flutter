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

/// Horizontal padding of the bar and of every sibling header band —
/// `TaskDailyHeader`, `_WeeklyHeader`, `TaskCalendarHeader` and
/// `KanbanBoard`'s own gutter all use the same 24, so the whole chrome stack
/// shares one left edge.
const double kTaskFilterBarGutter = 24;

/// Whether the three pickers render side by side in the body, or collapse
/// behind the AppBar's filter action (invoiceninja/flutter#136).
///
/// A pure function, and both of its terms are load-bearing:
///
/// * **[paneWidth] minus the gutters, not the raw pane.** The gate this
///   replaced lived in a `LayoutBuilder` *inside* the bar's own
///   `Container(padding: horizontal: 24)`, so it really tested
///   `pane - 48 >= 600` — i.e. pane >= 648. Measuring the raw pane would newly
///   put the row in a 552 px content box: ~168 px per picker, of which touch
///   spends 96 on the ✕ + ▾ suffix, leaving ~50 px of visible text in a field
///   that *scrolls rather than ellipsises*, so a long name would clip silently.
/// * **[isPhone].** A handset in landscape is a ~890 px window, so the rail
///   comes up and the ~658 px pane reads as "desktop" on a viewport only
///   ~412 px tall — flutter#51, and CLAUDE.md's "A landscape phone is not a
///   small desktop", which asks for this gate to be wired in per screen
///   deliberately. `Breakpoints.isPhone` is orientation-independent, so a phone
///   collapses either way up while a tablet still gets the width answer.
///
/// Both failures are invisible on screen, which is why this is a testable
/// function rather than an expression repeated at four call sites.
bool taskFiltersInline({required double paneWidth, required bool isPhone}) =>
    !isPhone && paneWidth - 2 * kTaskFilterBarGutter >= Breakpoints.wide;

/// Projects a repository's `watch(id)` emission into the `(id, name)` record the
/// list stream deals in, preserving null. Shared by the two record-typed
/// pickers so they cannot drift on the null handling; the assignee picker is
/// `EntityPickerField<User>` and passes `services.user.watch` straight through.
///
/// Note it constrains only the null case — the name fallback lives in each
/// picker's `displayString`, which covers the spliced-in resolved record too.
_Named? Function(T?) _namedOrNull<T extends Object>(_Named Function(T) of) =>
    (value) => value == null ? null : of(value);

/// The three task filter pickers — Project, Client, Assigned User, in that
/// order.
///
/// Public because two surfaces lay them out: [TaskFilterBar]'s inline wide row
/// and `openTaskFilters`' sheet. One construction site, so the wiring below
/// cannot drift between them — and so `test/lint/task_filter_bar_wiring_test
/// .dart`, which scans this file only, still sees all three.
///
/// **Call it inside a `ListenableBuilder` on [filters]**: every picker reads
/// `selectedId` eagerly, so without a rebuild the sheet's "Clear filters" would
/// empty the view model while all three fields kept their old values.
///
/// All three are [EntityPickerField], not a `StreamBuilder` + dropdown pair,
/// and that is load-bearing in three ways this file learned the hard way (the
/// invoiceninja/flutter#134 follow-up).
///
/// **The selection is resolved by id, not by scanning the visible list.** The
/// old shape (`items.where((c) => c.id == filters.clientId).firstOrNull`) is
/// verbatim the anti-pattern [EntityPickerField]'s class doc exists to kill.
/// The client and project streams are active-only, and the roster is filtered
/// to active below, so archiving — or deleting — the selected record dropped it
/// from `items`, `initialValue` went null, and the field reset **without firing
/// `onChanged`**. The mixin kept the id, `matchesFilters` kept excluding, and
/// the user was left with a blank field (no ✕ either — `canClear` reads the
/// controller text) over a list filtered by an invisible criterion, with only
/// the Clear button to hint at it. Nothing re-syncs it: this bar is the mixin's
/// sole mutator and no host view model watches a client / project / user stream.
///
/// **The lists are whole-table name queries, matching the Tasks list's own
/// filter.** `ClientFilterKey.watchValueSuggestions` reads
/// `clients.watchActiveNames`; this used a paged read, a 5000-row window with a
/// full `jsonDecode` + `ClientApi.fromJson` per row that never came close to
/// binding — the real ceiling is that login prefetches **page 1 only**, so the
/// picker offered the alphabetically-first 20 of the 50 most recently created
/// clients. Assignees go through `watchAllForPicker`, whose dartdoc says "for
/// the assignee filter picker"; four other assignee surfaces already used it
/// and this one did not.
///
/// **The streams are not rebuilt per notify.** [EntityPickerField] routes them
/// through `WatchBuilder` keyed on [EntityPickerField.cacheKey], where the old
/// inline `stream:` expressions sat inside the `ListenableBuilder` and so
/// re-queried Drift three times on every filter change.
List<Widget> taskFilterPickers(
  BuildContext context, {
  required TaskFiltersMixin filters,
  required String companyId,
}) {
  // Read here rather than in `TaskFilterBar.build`: the collapsed-and-unfiltered
  // branch paints nothing, and keeping it clear of the DI bag is what lets a
  // widget test pump it with no `Provider<Services>` in the tree at all. No
  // production benefit — the provider is always there — so don't hoist it back
  // up "for consistency".
  final services = context.read<Services>();

  return [
    EntityPickerField<_Named>(
      label: context.tr('project'),
      cacheKey: companyId,
      selectedId: filters.projectId,
      itemsStream: () =>
          services.projects.watchActiveNames(companyId: companyId),
      watchById: (id) => services.projects
          .watch(companyId: companyId, id: id)
          .map(_namedOrNull((p) => (id: p.id, name: p.name))),
      // The list rows are already safe — `ProjectRepository.watchActiveNames`
      // falls back to the id, like its Client and Vendor twins. This covers the
      // OTHER path: `watchById` above goes through
      // `BaseEntityRepository.watch`, which the repo-level fallback never sees,
      // and that record is what `EntityPickerField` splices in for a selection
      // outside the list. So it is not redundant with the repo. `.trim()`,
      // matching the repo, or a whitespace-only name still renders blank.
      displayString: (p) => p.name.trim().isEmpty ? p.id : p.name,
      idOf: (p) => p.id,
      // A company with no projects is an ordinary configuration, and its
      // stream settles on `[]` for good — so this really is "you have none",
      // not "still loading". Without the key the disabled placeholder reads
      // "Loading" for ever.
      emptyHintKey: 'no_records_found',
      idleResults: _kFilterIdleResults,
      onChanged: (p) => filters.setProjectFilter(p?.id ?? ''),
    ),
    EntityPickerField<_Named>(
      label: context.tr('client'),
      cacheKey: companyId,
      selectedId: filters.clientId,
      itemsStream: () =>
          services.clients.watchActiveNames(companyId: companyId),
      // `watchActiveNames` prefers `display_name` then `name`; the `?? id` tail
      // lives in `displayString` below so it covers this projection too. It has
      // to: `BaseEntityDao.watchById` has no archived/deleted predicate, so an
      // archived client stays *resolvable* while dropping out of the list —
      // `EntityPickerField` then splices it back in, and a nameless one would
      // render as a blank field over an active filter, which is the defect this
      // whole widget exists to remove.
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
    ),
    EntityPickerField<User>(
      label: context.tr('assigned_user'),
      cacheKey: companyId,
      selectedId: filters.assignedUserId,
      // `watchAllForPicker` is the whole-roster accessor, but unlike the paged
      // read this replaced it is a bare `select(users)..where(companyId)` —
      // **no `orderBy` and no state filter**. Restore both here, or the
      // dropdown falls back to rowid order and starts offering archived and
      // soft-deleted users as filter values.
      //
      // At the call site rather than in the repository on purpose:
      // `watchAllForPicker`'s three other callers include
      // `client_edit_settings_section.dart`, which resolves its selection by
      // scanning the window — narrowing the stream there would blank a client
      // assigned to a since-archived user. Safe here because
      // `EntityPickerField` splices the resolved selection back in.
      // `activity_filter_sheet.dart` sorts at its call site for the same
      // reason.
      itemsStream: () => services.user
          .watchAllForPicker(companyId: companyId)
          .map(
            (users) =>
                users
                    // `archivedAt` is an int epoch, 0 = not archived — never
                    // null. `== null` analyzes as dead code and would have
                    // filtered the roster to nothing.
                    .where((u) => u.archivedAt == 0 && !u.isDeleted)
                    .toList()
                  ..sort((a, b) {
                    final byName = a.displayName.toLowerCase().compareTo(
                      b.displayName.toLowerCase(),
                    );
                    // Tiebreak on id: `List.sort` is NOT stable in Dart, so two
                    // users sharing a display name would otherwise swap places
                    // between Drift emissions and reorder the list under the
                    // user's finger. `UserDao` had a secondary
                    // `OrderingTerm(u.id)` for the same reason.
                    return byName != 0 ? byName : a.id.compareTo(b.id);
                  }),
          ),
      watchById: (id) => services.user.watch(companyId: companyId, id: id),
      displayString: (u) => u.displayName.trim().isEmpty ? u.id : u.displayName,
      idOf: (u) => u.id,
      // Deliberately NO `emptyHintKey`, unlike its two siblings: the roster
      // arrives bundled on `/refresh` and always holds at least the signed-in
      // user, so an empty list here really is a loading state.
      idleResults: _kFilterIdleResults,
      onChanged: (u) => filters.setAssigneeFilter(u?.id ?? ''),
    ),
  ];
}

/// Client-side task filter chrome, shared by every custom task view (kanban,
/// calendar, daily, weekly) and bound to any view model that mixes in
/// [TaskFiltersMixin].
///
/// Two shapes, chosen by [inline] — which the host screen computes **once**
/// with [taskFiltersInline] and feeds to this bar *and* to
/// `buildTasksViewAppBar`, so the two can never disagree:
///
///  * **[inline] true** — the pickers side by side, plus Clear. Unchanged.
///  * **[inline] false** — `SizedBox.shrink()` while nothing is filtered (the
///    whole point of invoiceninja/flutter#136: three stacked full-width pickers
///    cost ~180 px of a 412×915 phone and ~230 once a filter adds the Clear
///    row, up to 42 % of the viewport once the view
///    header is counted, and the calendar grid never scrolls so it comes
///    straight out of the day cells), and one row of removable chips once
///    something is. The pickers themselves move to `openTaskFilters`, reached
///    from the AppBar's filter icon — the same "a box that only opens another
///    surface should be an icon" answer as invoiceninja/flutter#101.
///
/// The early return sits **above** the `Container`: inside it, the free case
/// still costs a ~17 px bordered slab.
class TaskFilterBar extends StatelessWidget {
  const TaskFilterBar({
    required this.filters,
    required this.companyId,
    required this.inline,
    required this.onEditFilters,
    super.key,
  });

  final TaskFiltersMixin filters;
  final String companyId;

  /// Required, never defaulted: a default turns a missed call site into silent
  /// double chrome — the inline row *and* the AppBar icon — or into neither,
  /// which makes the filters unreachable. As a required parameter it is a
  /// compile error instead.
  final bool inline;

  /// Opens the filter sheet. Passed in rather than called here so this file
  /// need not import `task_filters_sheet.dart`, which imports it back for
  /// [taskFilterPickers].
  final VoidCallback onEditFilters;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;

    return ListenableBuilder(
      listenable: filters,
      builder: (context, _) {
        if (!inline && !filters.filtersActive) return const SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            // Byte-identical to the three view headers that render directly
            // below this one, so the bands read as one continuous stack. When
            // this collapses on kanban there is no rule at all, and that is
            // fine: the AppBar paints `colorScheme.surface` over a
            // `scaffoldBackgroundColor` body, so the tonal seam carries it.
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: kTaskFilterBarGutter,
            vertical: InSpacing.sm,
          ),
          child: inline ? _inlineRow(context) : _chipStrip(context),
        );
      },
    );
  }

  Widget _inlineRow(BuildContext context) {
    final pickers = taskFilterPickers(
      context,
      filters: filters,
      companyId: companyId,
    );
    return Row(
      children: [
        for (var i = 0; i < pickers.length; i++) ...[
          if (i > 0) SizedBox(width: InSpacing.md(context)),
          Expanded(child: pickers[i]),
        ],
        // Hidden rather than disabled: a permanently dead button is dead width
        // in a three-picker row. The sheet's own Clear is the opposite (always
        // visible, disabled when inactive) because there it has room.
        if (filters.filtersActive) ...[
          SizedBox(width: InSpacing.md(context)),
          TextButton.icon(
            onPressed: filters.clearFilters,
            icon: const Icon(Icons.clear, size: 16),
            label: Text(context.tr('clear')),
          ),
        ],
      ],
    );
  }

  /// One chip per narrowing dimension, labelled by **dimension** rather than by
  /// the record's name.
  ///
  /// Not a value ("Acme Corp"), for two reasons. A resolved name is several
  /// times a dimension label's width, so three value chips cannot share a run
  /// on a phone — and a strip spending two or three runs gives back most of
  /// what collapsing the pickers saved, in the one state the user actually
  /// works in. And the resolvers it would need each misbehave inside a chip:
  /// `ProjectNameLabel` renders the raw hashid when a project doesn't resolve,
  /// `UserNameLabel` renders an empty label and then an em dash for an id the
  /// roster can't resolve (users have no per-id hydrate path at all), and all
  /// three hardcode a font size over the chip's own label style. An em dash also
  /// belongs in a *labelled* slot, which a chip is not.
  ///
  /// `Wrap`, never a horizontal scroller: a chip pushed off the edge hides an
  /// active filter — verbatim the defect this file exists to remove — and on
  /// kanban it makes the `filtersActive` drag lock inexplicable. Three
  /// dimensions is a hard ceiling, so this cannot degrade unboundedly.
  ///
  /// Measured with the bundled Inter Tight (a widget test's substituted font is
  /// a square per glyph and over-measures by roughly half), all three chips are
  /// **one 65 px run** on a 412 px phone — the reporter's class of device — and
  /// wrap to a second (117) only at the largest text scale or on a 320-360 px
  /// one. That is what makes the clear `assigned_user` label affordable: the
  /// short `user` would hold one run in two more of those combinations, but it
  /// buys nothing in the common case and Activity already uses `tr('user')` for
  /// a different dimension (the actor), so the same word would mean two things
  /// across two filter strips.
  Widget _chipStrip(BuildContext context) => Wrap(
    spacing: InSpacing.sm,
    runSpacing: InSpacing.xs,
    children: [
      if (filters.projectId.isNotEmpty)
        _FilterChip(
          labelKey: 'project',
          onEdit: onEditFilters,
          onRemove: () => filters.setProjectFilter(''),
        ),
      if (filters.clientId.isNotEmpty)
        _FilterChip(
          labelKey: 'client',
          onEdit: onEditFilters,
          onRemove: () => filters.setClientFilter(''),
        ),
      if (filters.assignedUserId.isNotEmpty)
        _FilterChip(
          labelKey: 'assigned_user',
          onEdit: onEditFilters,
          onRemove: () => filters.setAssigneeFilter(''),
        ),
    ],
  );
}

/// One applied-filter chip: tap the body to reopen the sheet, tap the ✕ to drop
/// just this dimension.
///
/// The split is the app's own filter-chip contract (`FilterTokenChip` gives its
/// body an edit tap and keeps remove in its own trailing node), not Activity's
/// `_Chip`, where body and ✕ both remove because that strip has no per-dimension
/// editor to land on. Here the sheet is three fields and the reporter's loop is
/// *switching* project A for project B, so body-as-edit turns four taps into
/// three — and a mis-tap opens a sheet instead of destroying the filter it was
/// aimed at.
///
/// Default density on purpose: `materialTapTargetSize.padded` is what inflates
/// the ✕ to `kMinInteractiveDimension`, and this ✕ is the only way to drop the
/// dimension from the strip. Same note Activity's chip carries.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.labelKey,
    required this.onEdit,
    required this.onRemove,
  });

  final String labelKey;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => InputChip(
    label: Text(context.tr(labelKey)),
    onPressed: onEdit,
    onDeleted: onRemove,
    deleteIcon: const Icon(Icons.close, size: 16),
    // `MaterialLocalizations.deleteButtonTooltip` is "Delete", which on a chip
    // reading "Client" is not merely imprecise — it reads as deleting the
    // client. `FilterTokenChip` labels the same glyph the same way.
    deleteButtonTooltipMessage: context.tr('clear_filter'),
  );
}
