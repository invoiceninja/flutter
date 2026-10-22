import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/list_status_tabs.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';

/// The way out of a filtered list that shows nothing: each narrowing the list
/// can undo on its own, then Clear filters.
///
/// "Clear filters" alone threw away the typed search with everything else, so
/// someone who searched `acme` on the Overdue tab, or for a client archived
/// last year, had to type it again on a wider list. The two narrowings a
/// search most often runs into get their own button, each widening only its
/// own dimension:
///
/// * **All statuses** drops the status tab (`badge_mode`) and keeps the
///   search. Hidden when the tab is the only narrowing — Clear filters does
///   exactly the same then.
/// * **Show archived** adds archived to the State filter, through the same
///   `setStates` the `is:` key's picker uses, so it lands as a chip that can
///   be removed. Every list on `EntityListScreenScaffold` declares that key
///   except Documents, which has no lifecycle (`hasEntityStates` is false)
///   and so is never offered it.
/// * **Include deleted** takes Show archived's place once archived is
///   already in the State filter and the list is still empty: the search
///   widens one lifecycle step at a time, archived first because that is
///   where an old record usually is, deleted only if it is not there either.
///   One button, not two side by side: the record is rarely deleted, and a
///   third outlined button pushed the row to two lines on a phone.
///
/// A `Wrap`, not a `Row`: three German labels do not fit at 360 px.
class NoMatchActions extends StatelessWidget {
  const NoMatchActions({
    required this.vm,
    this.extraNarrowing = false,
    super.key,
  });

  final GenericListViewModel<dynamic> vm;

  /// A narrowing the base VM cannot see (payments' unapplied-funds toggle) —
  /// see `EntityListEmptyState.extraNarrowing`.
  final bool extraNarrowing;

  /// Whether anything other than the status tab narrows the list.
  bool get _narrowedBeyondTab =>
      extraNarrowing ||
      vm.search.isNotEmpty ||
      !setEquals(vm.states, kDefaultListStates) ||
      vm.customFilters.values.any((v) => v.isNotEmpty) ||
      vm.extraFilters.entries.any(
        (e) => e.key != kBadgeModeFilterKey && e.value.isNotEmpty,
      );

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(minimumSize: const Size(64, 40));
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: InSpacing.md(context),
      runSpacing: InSpacing.sm,
      children: [
        if (vm.activeBadgeModeId != null && _narrowedBeyondTab)
          OutlinedButton.icon(
            style: style,
            onPressed: () => vm.setBadgeMode(null),
            icon: const Icon(Icons.filter_list_off),
            label: Text(context.tr('all_statuses')),
          ),
        if (vm.hasEntityStates && !vm.states.contains(EntityState.archived))
          OutlinedButton.icon(
            style: style,
            onPressed: () => vm.setStates({...vm.states, EntityState.archived}),
            icon: const Icon(Icons.archive_outlined),
            label: Text(context.tr('show_archived')),
          )
        else if (vm.hasEntityStates && !vm.states.contains(EntityState.deleted))
          OutlinedButton.icon(
            style: style,
            onPressed: () => vm.setStates({...vm.states, EntityState.deleted}),
            icon: const Icon(Icons.delete_outline),
            label: Text(context.tr('include_deleted')),
          ),
        OutlinedButton.icon(
          style: style,
          onPressed: vm.clearAllFilters,
          icon: const Icon(Icons.close),
          label: Text(context.tr('clear_filters')),
        ),
      ],
    );
  }
}
