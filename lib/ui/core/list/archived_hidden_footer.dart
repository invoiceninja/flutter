import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';

/// The line under the last row of a searched or filtered list that says
/// archived records were left out, with the one click that brings them in.
///
/// v1 put Active / Archived / Deleted in a dropdown beside the search box; v2
/// moved it into the search box as the State key, and its default renders no
/// chip (#126), so nothing on screen said archived records were hidden. The
/// no-match empty state already offered Show archived, but a search that
/// matches *some* active rows never reaches it — the beta report was a client
/// search that found four drafts while the archived invoices it was looking
/// for went unmentioned.
///
/// The action is the same `setStates` the `is:` key's picker and
/// `NoMatchActions` use, so it lands as a State chip in the search box — which
/// is also how the user finds where the control lives now.
class ArchivedHiddenFooter extends StatelessWidget {
  const ArchivedHiddenFooter({required this.vm, super.key});

  final GenericListViewModel<dynamic> vm;

  /// Whether the list's footer slot should show this line.
  ///
  /// Only at the true end of the list — while more can load, the archived
  /// rows' absence says nothing yet — and only when the user has narrowed the
  /// list: an un-narrowed short list would otherwise carry the line forever.
  /// An empty list is `NoMatchActions`' job, and a list with no lifecycle
  /// (Documents) has nothing to show.
  static bool shows(GenericListViewModel<dynamic> vm) =>
      vm.hasEntityStates &&
      vm.items.isNotEmpty &&
      !vm.isLoadingPage &&
      !vm.canLoadMore &&
      !vm.states.contains(EntityState.archived) &&
      (vm.search.isNotEmpty || vm.hasActiveFilters);

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Start-aligned, never centred: in the wide layout the list sits inside
    // the table's horizontal scroller at the table's full width, so a centred
    // line drifts off-screen once the columns outgrow the pane. The 16 px
    // gutter is the rows' own, so the text lines up with the first cell.
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        InSpacing.lg(context),
        16,
        InSpacing.lg(context),
      ),
      // A `Wrap`: the German copy and button don't fit one line at 360 px.
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: InSpacing.md(context),
        runSpacing: InSpacing.sm,
        children: [
          Text(
            context.tr('archived_records_hidden'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.ink3),
          ),
          // Styled exactly like NoMatchActions' Show archived: one action,
          // one look, wherever the list offers it.
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => vm.setStates({...vm.states, EntityState.archived}),
            icon: const Icon(Icons.archive_outlined),
            label: Text(context.tr('show_archived')),
          ),
        ],
      ),
    );
  }
}
