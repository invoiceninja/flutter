import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/tasks/view_models/task_filters_mixin.dart';
import 'package:admin/ui/features/tasks/widgets/task_filter_bar.dart';

/// Opens the task filter surface — a centered dialog on a wide window, a
/// bottom sheet on a narrow one — holding the same three pickers
/// [TaskFilterBar] renders inline when there is room for them
/// (invoiceninja/flutter#136). The same split `openActivityFilters` and
/// `openManageDashboardCards` use, so the three read as one family.
///
/// Mutations apply live against [filters]; there is no Apply gate.
///
/// **The presentation gate is a *window* read while `inline` is a *pane* read,
/// and the disagreement is correct** — don't "fix" it to one number. At a
/// 700 px window the 232 px rail leaves a ~468 px pane, so the pickers are
/// collapsed behind the AppBar icon, yet the window hosts the 720-capped
/// dialog perfectly well. A dialog needs window width; a row of three
/// searchable pickers needs pane width.
///
/// [filters] arrives as an argument, never from a provider: `Scaffold.appBar`
/// is built outside the body's `ChangeNotifierProvider`, and
/// `showModalBottomSheet` / `showDialog` capture only `InheritedTheme`s, so a
/// `context.watch<KanbanViewModel>()` inside this route would throw.
/// `Provider<Services>` sits above `MaterialApp.router`, so the pickers still
/// find *it*.
///
/// Both branches keep `useRootNavigator` at its default, and the two defaults
/// **differ**: `showDialog` is root, `showModalBottomSheet` is the nearest
/// navigator — i.e. the shell branch. That is left alone (every other dialog in
/// the app is on the root navigator) but it is worth knowing which is which,
/// because it decides what can dismiss the surface: the sheet goes when the
/// branch navigates, the dialog does not. Either way they are real
/// `ModalRoute`s, so Android back closes them through `SystemBackGate`, and an
/// open picker popover's own `ChildBackButtonDispatcher` closes first.
Future<void> openTaskFilters(
  BuildContext context, {
  required TaskFiltersMixin filters,
  required String companyId,
}) {
  final body = _TaskFilterBody(filters: filters, companyId: companyId);
  if (MediaQuery.sizeOf(context).width >= Breakpoints.wide) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        // A cap, not a target: three fields make a ~340 px dialog.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: body,
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      // Keyboard-aware in both directions, the arithmetic
      // `line_item_picker_sheet.dart` worked out for flutter#86: lifting the
      // sheet by the inset keeps it visible, and subtracting the inset from the
      // cap as well stops the ceiling being measured against a screen height
      // the keyboard has already taken half of.
      final insets = MediaQuery.viewInsetsOf(ctx).bottom;
      final maxHeight = (MediaQuery.sizeOf(ctx).height - insets) * 0.85;
      return Padding(
        padding: EdgeInsets.only(bottom: insets),
        // Capped rather than a fixed fraction, unlike Activity's 0.92 sheet —
        // that body holds a big scrollable multi-select and needs the height.
        // Three fields under a 92 % sheet would cover the board and hide the
        // very thing this surface changes, so the sheet sizes to its content
        // and the day list or board stays visible above it, which is also what
        // makes the Apply-less live filtering observable.
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: body,
        ),
      );
    },
  );
}

class _TaskFilterBody extends StatelessWidget {
  const _TaskFilterBody({required this.filters, required this.companyId});

  final TaskFiltersMixin filters;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // `showModalBottomSheet` is not given `useSafeArea` (that pays the *top*
    // inset, which a short sheet never needs) — this is what keeps the Clear
    // row out of the Android gesture strip.
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        // Load-bearing, not decoration: `EntityPickerField.selectedId` is a
        // constructor argument and the field re-seeds its controller only from
        // `didUpdateWidget`, so without this "Clear filters" would empty the
        // view model — the board updating behind the sheet — while all three
        // fields kept showing their old values.
        child: ListenableBuilder(
          listenable: filters,
          builder: (context, _) {
            final pickers = taskFilterPickers(
              context,
              filters: filters,
              companyId: companyId,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('filters'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      tooltip: context.tr('close'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SizedBox(height: InSpacing.md(context)),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < pickers.length; i++) ...[
                          if (i > 0) SizedBox(height: InSpacing.lg(context)),
                          pickers[i],
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: InSpacing.md(context)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: filters.filtersActive
                        ? filters.clearFilters
                        : null,
                    icon: const Icon(Icons.restart_alt, size: 16),
                    label: Text(context.tr('clear_filters')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
