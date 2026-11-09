import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// The table's lifecycle states, React's DataTable order.
const kDocuNinjaStateFilters = <String>['active', 'archived', 'deleted'];

/// React's status filter (`useDocumentFilters.ts`), in its order.
const kDocuNinjaStatusFilters = <String>[
  'draft',
  'sent',
  'pending_approval',
  'completed',
  'approved',
  'voided',
  'expired',
  'rejected',
];

/// What a filter pick returns: the lifecycle states and the statuses.
typedef DnFilterPick = ({Set<String> states, Set<String> statuses});

/// Opens the list filter ([DnFilterDialog]): a bottom sheet on a phone
/// ([Breakpoints.isPhone]), with its Cancel and Apply pinned under the
/// choices, and the dialog everywhere else. Null when dismissed.
Future<DnFilterPick?> showDnFilterPicker(
  BuildContext context, {
  required Set<String> states,
  Set<String> statuses = const {},
  List<String> statusOptions = const [],
}) {
  if (Breakpoints.isPhone(context)) {
    return showModalBottomSheet<DnFilterPick>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DnFilterDialog(
        states: states,
        statuses: statuses,
        statusOptions: statusOptions,
        sheet: true,
      ),
    );
  }
  return showDialog<DnFilterPick>(
    context: context,
    builder: (_) => DnFilterDialog(
      states: states,
      statuses: statuses,
      statusOptions: statusOptions,
    ),
  );
}

/// React's list filter: the lifecycle states, and (documents only) the
/// workflow statuses. Returns the picked sets; Clear returns the defaults.
/// A dialog, or the body of a bottom sheet when [sheet]
/// ([showDnFilterPicker] picks).
class DnFilterDialog extends StatefulWidget {
  const DnFilterDialog({
    super.key,
    required this.states,
    this.statuses = const {},
    this.statusOptions = const [],
    this.sheet = false,
  });

  final Set<String> states;
  final Set<String> statuses;

  /// The statuses offered; none for a list without them (templates,
  /// users).
  final List<String> statusOptions;

  /// Laid out as a bottom sheet's body rather than an [AlertDialog].
  final bool sheet;

  @override
  State<DnFilterDialog> createState() => _DnFilterDialogState();
}

class _DnFilterDialogState extends State<DnFilterDialog> {
  late final Set<String> _states = {...widget.states};
  late final Set<String> _statuses = {...widget.statuses};

  /// One start edge for the sheet's title, the group headings and the
  /// boxes: the sheet's gutter on a phone, the dialog's 24 elsewhere.
  double get _gutter => widget.sheet ? InSpacing.lg(context) : 24;

  Widget _box(Set<String> set, String key) => CheckboxListTile(
    value: set.contains(key),
    // The checkbox draws its box inset in its own tap area; this lines the
    // box's edge up with the headings above it.
    contentPadding: EdgeInsetsDirectional.only(
      start: _gutter - 11,
      end: _gutter,
    ),
    title: Text(context.tr(key)),
    controlAffinity: ListTileControlAffinity.leading,
    onChanged: (v) =>
        setState(() => v == true ? set.add(key) : set.remove(key)),
  );

  void _clear() => Navigator.of(
    context,
  ).pop((states: const {'active'}, statuses: const <String>{}));

  void _apply() =>
      Navigator.of(context).pop((states: _states, statuses: _statuses));

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.labelLarge;
    Widget title(String key) => Padding(
      padding: EdgeInsetsDirectional.fromSTEB(_gutter, 12, _gutter, 4),
      child: Semantics(
        header: true,
        headingLevel: 2,
        child: Text(context.tr(key), style: heading),
      ),
    );
    final choices = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The wide toolbar's name for the same filter.
        title('lifecycle'),
        for (final s in kDocuNinjaStateFilters) _box(_states, s),
        if (widget.statusOptions.isNotEmpty) ...[
          title('status'),
          for (final s in widget.statusOptions) _box(_statuses, s),
        ],
      ],
    );
    if (widget.sheet) return _sheet(context, choices);
    return AlertDialog(
      title: Text(context.tr('filter')),
      contentPadding: const EdgeInsets.symmetric(vertical: InSpacing.sm),
      content: SingleChildScrollView(child: choices),
      actions: [
        TextButton(onPressed: _clear, child: Text(context.tr('clear'))),
        PrimaryDialogAction(label: context.tr('apply'), onPressed: _apply),
      ],
    );
  }

  /// The phone's sheet: the title with Clear, the choices scrolling, and
  /// Cancel beside Apply pinned under them, in reach of the thumb.
  Widget _sheet(BuildContext context, Widget choices) {
    final tokens = context.inTheme;
    final gutter = InSpacing.lg(context);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter / 2, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    headingLevel: 1,
                    child: Text(
                      context.tr('filter'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                TextButton(onPressed: _clear, child: Text(context.tr('clear'))),
              ],
            ),
          ),
          Flexible(child: SingleChildScrollView(child: choices)),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(gutter),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 44),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('cancel')),
                  ),
                ),
                SizedBox(width: InSpacing.md(context)),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 44),
                    ),
                    onPressed: _apply,
                    child: Text(context.tr('apply')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
