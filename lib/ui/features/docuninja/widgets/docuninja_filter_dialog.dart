import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
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

/// React's list filter: the lifecycle states, and (documents only) the
/// workflow statuses. Returns the picked sets; Clear returns the defaults.
class DnFilterDialog extends StatefulWidget {
  const DnFilterDialog({
    super.key,
    required this.states,
    this.statuses = const {},
    this.statusOptions = const [],
  });

  final Set<String> states;
  final Set<String> statuses;

  /// The statuses offered; none for a list without them (templates,
  /// users).
  final List<String> statusOptions;

  @override
  State<DnFilterDialog> createState() => _DnFilterDialogState();
}

class _DnFilterDialogState extends State<DnFilterDialog> {
  late final Set<String> _states = {...widget.states};
  late final Set<String> _statuses = {...widget.statuses};

  Widget _box(Set<String> set, String key) => CheckboxListTile(
    value: set.contains(key),
    title: Text(context.tr(key)),
    controlAffinity: ListTileControlAffinity.leading,
    onChanged: (v) =>
        setState(() => v == true ? set.add(key) : set.remove(key)),
  );

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.labelLarge;
    Widget title(String key) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 4),
      child: Semantics(
        header: true,
        headingLevel: 2,
        child: Text(context.tr(key), style: heading),
      ),
    );
    return AlertDialog(
      title: Text(context.tr('filter')),
      contentPadding: const EdgeInsets.symmetric(vertical: InSpacing.sm),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title('entity_state'),
            for (final s in kDocuNinjaStateFilters) _box(_states, s),
            if (widget.statusOptions.isNotEmpty) ...[
              title('status'),
              for (final s in widget.statusOptions) _box(_statuses, s),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop((states: const {'active'}, statuses: const <String>{})),
          child: Text(context.tr('clear')),
        ),
        PrimaryDialogAction(
          label: context.tr('apply'),
          onPressed: () =>
              Navigator.of(context).pop((states: _states, statuses: _statuses)),
        ),
      ],
    );
  }
}
