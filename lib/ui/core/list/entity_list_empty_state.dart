import 'package:flutter/material.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';

/// The four empty states every entity list can reach: nothing yet, nothing
/// archived, nothing deleted, and nothing matching the active filters.
///
/// Ten entity tiles carried a byte-identical copy of this, differing only in
/// one [IconData] and the localization keys. The `onlyArchived` / `onlyDeleted`
/// predicate reads solely from [GenericListViewModel], so nothing here is
/// entity-specific.
///
/// **The keys are parameters, not derived from a wire name.** They look
/// perfectly regular — `no_quotes_yet`, `no_archived_quotes` — until Vendors,
/// which uses `no_vendors` because `no_vendors_yet` does not exist in the
/// bundle at all. Deriving would have rendered the raw key to the user there,
/// and `no_unsubstituted_placeholders_test` cannot see a key reached through a
/// variable (see CLAUDE.md § Localization), so nothing would have caught it.
/// Passing them keeps every `tr` argument a literal at the call site.
class EntityListEmptyState extends StatelessWidget {
  const EntityListEmptyState({
    required this.vm,
    required this.archivedTitle,
    required this.deletedTitle,
    required this.noMatchTitle,
    this.icon,
    this.emptyTitle,
    this.emptySubtitle,
    this.emptyAction,
    this.emptyOverride,
    this.extraNarrowing = false,
    super.key,
  }) : assert(
         emptyOverride != null || (icon != null && emptyTitle != null),
         'the unfiltered branch needs either an override or an icon + title',
       );

  final GenericListViewModel<dynamic> vm;

  final String archivedTitle;
  final String deletedTitle;
  final String noMatchTitle;

  /// The entity's own glyph, shown only in the "nothing yet" state.
  final IconData? icon;
  final String? emptyTitle;

  /// Optional — Payments has no first-run subtitle.
  final String? emptySubtitle;

  /// Optional call to action on the "nothing yet" state, e.g. gateways'
  /// "Add gateway".
  final Widget? emptyAction;

  /// A narrowing input the base [GenericListViewModel] cannot see, so that the
  /// archived / deleted branches don't claim "nothing archived" when something
  /// else is filtering. Payments' unapplied-funds toggle is the only one: it
  /// reaches the Drift query but lives as a bare bool on its VM rather than in
  /// `extraFilters`. Its VM also folds the flag into `hasActiveFilters` and
  /// `clearAllFilters`, which covers the first-run branch and the Clear button;
  /// this covers the two lifecycle branches.
  final bool extraNarrowing;

  /// Replaces the "nothing yet" branch outright. Transactions needs this: its
  /// unfiltered copy depends on whether the company has a *linked* bank
  /// account, which it resolves from its own Drift stream. Only that branch
  /// varies — the archived / deleted / no-match ones are shared.
  final Widget? emptyOverride;

  /// Whether the only active narrowing is the lifecycle state itself — i.e.
  /// the user is looking at the Archived (or Deleted) tab with no search,
  /// chips or extra filters on top.
  bool _onlyState(EntityState state) =>
      !extraNarrowing &&
      vm.states.length == 1 &&
      vm.states.contains(state) &&
      vm.customFilters.isEmpty &&
      vm.extraFilters.isEmpty &&
      vm.search.isEmpty;

  @override
  Widget build(BuildContext context) {
    if (!vm.hasActiveFilters) {
      return emptyOverride ??
          EmptyState(
            icon: icon!,
            title: emptyTitle!,
            subtitle: emptySubtitle,
            action: emptyAction,
          );
    }
    if (_onlyState(EntityState.archived)) {
      return EmptyState(icon: Icons.archive_outlined, title: archivedTitle);
    }
    if (_onlyState(EntityState.deleted)) {
      return EmptyState(icon: Icons.delete_outline, title: deletedTitle);
    }
    return EmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: noMatchTitle,
      action: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
        onPressed: vm.clearAllFilters,
        icon: const Icon(Icons.close),
        label: Text(context.tr('clear_filters')),
      ),
    );
  }
}
