import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/widgets/widget_preview_support.dart';

/// One toggle inside a [LabeledSwitchGroup]: a resolved label string and the
/// switch's value + change handler. A `null` [onChanged] renders the row
/// disabled (greyed label, inert switch) — used for mutually-exclusive
/// toggles (e.g. "Add to Invoices" is disabled while "CC Only" is on).
class LabeledSwitchItem {
  const LabeledSwitchItem({
    required this.label,
    required this.value,
    this.onChanged,
  });

  /// Resolved display string — callers pass `context.tr('...')` so the static
  /// search-catalog regex still finds the key at the call site.
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
}

/// A group of boolean toggles laid out as `label … switch`, with the switches
/// aligned in a vertical column.
///
/// Replaces bare `SwitchListTile`s whose short label floats far from a
/// far-right switch. The label stays first (reading order); the switch sits
/// just to its right; the empty space lands to the *right* of the aligned
/// switch column rather than between each label and its switch.
///
/// Alignment without fixed widths: [IntrinsicWidth] sizes the block to the
/// widest row (longest label + gap + switch); `CrossAxisAlignment.stretch`
/// makes every row that same width; each label's [Expanded] absorbs the slack
/// so all switches land at the same offset. The outer [Align] keeps the block
/// hugging its content at the left even inside a stretched parent column —
/// without it the group would re-expand to full width and the switches would
/// jump back to the far edge.
class LabeledSwitchGroup extends StatelessWidget {
  const LabeledSwitchGroup({super.key, required this.items});

  final List<LabeledSwitchItem> items;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [for (final item in items) _row(context, item)],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, LabeledSwitchItem item) {
    final disabled = item.onChanged == null;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: disabled ? null : () => item.onChanged!(!item.value),
              child: Text(
                item.label,
                style: disabled
                    ? TextStyle(color: Theme.of(context).disabledColor)
                    : null,
              ),
            ),
          ),
          SizedBox(width: InSpacing.lg(context)),
          Switch(
            value: item.value,
            onChanged: item.onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

@Preview(
  name: 'Aligned group',
  group: 'LabeledSwitchGroup',
  theme: appPreviewTheme,
)
Widget previewLabeledSwitchGroup() {
  // A fixed-width box so the trailing empty space (to the right of the aligned
  // switches) is visible.
  return Padding(
    padding: const EdgeInsets.all(16),
    child: SizedBox(
      width: 360,
      child: LabeledSwitchGroup(
        items: [
          LabeledSwitchItem(
            label: 'Add to Invoices',
            value: true,
            onChanged: (_) {},
          ),
          LabeledSwitchItem(label: 'CC Only', value: false, onChanged: (_) {}),
        ],
      ),
    ),
  );
}

@Preview(
  name: 'With disabled row',
  group: 'LabeledSwitchGroup',
  theme: appPreviewTheme,
)
Widget previewLabeledSwitchGroupDisabled() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: SizedBox(
      width: 360,
      child: LabeledSwitchGroup(
        items: [
          const LabeledSwitchItem(label: 'Add to Invoices', value: false),
          LabeledSwitchItem(label: 'CC Only', value: true, onChanged: (_) {}),
        ],
      ),
    ),
  );
}
