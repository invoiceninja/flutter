import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// One labelled figure in a detail KPI strip: a small upper-case caption over
/// a caller-built value widget.
///
/// The companion to `KpiStripLayout`, which owns the responsive arrangement of
/// these. Six detail strips carried a byte-identical private copy — five named
/// `_KpiCell` and one `_Cell`, the odd one out threading `Theme.of(context)`
/// down as a parameter instead of reading it here.
///
/// **This is the pre-built-`Widget` variant only.** CLAUDE.md § KPI-strip
/// documents three: Client passes a `Decimal` plus a `Formatter`, and Projects
/// a `String` with a `'—'` sentinel. Those genuinely differ and must not be
/// folded in here — which is also why `KpiStripLayout` shares the layout and
/// leaves each caller its own cell.
class KpiCell extends StatelessWidget {
  const KpiCell({
    required this.label,
    required this.value,
    required this.tokens,
    super.key,
  });

  final String label;
  final Widget value;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: tokens.ink3,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        value,
      ],
    );
  }
}
