import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/widgets/widget_preview_support.dart';

/// Small status badge — colored dot + label on a tinted-soft background,
/// wrapped in a rounded rectangle (never a stadium pill — see CLAUDE.md
/// "rounded rectangles, never pills").
///
/// The v2 system uses this shape everywhere an entity needs a state cue
/// (deleted / archived / unsynced on the clients list; paid / overdue /
/// draft / sent on invoices; user-defined task statuses on the task list).
///
/// Colors are passed in by the caller so this widget stays neutral. Pick
/// `(fgColor, bgColor)` pairs from `InTheme` (e.g. `paid` + `paidSoft`).
/// When the caller doesn't have a paired soft token (e.g. task statuses
/// store a per-company hex color), pass `bgColor: null` and the widget
/// derives the soft tone as `fgColor` at 15 % alpha.
///
/// **[fgColor] tints the dot, not the label.** Status colors are chosen to
/// read as *colors* against a pale tint of themselves, which makes them poor
/// text: `paid` on `paidSoft` measures 3.77:1 in light and 2.88:1 in dark
/// Espresso, against the 4.5:1 WCAG AA floor for an 11 px label — 20 of the
/// 36 theme x status combinations failed. The label uses `ink` instead
/// (worst case 11.35:1). Every per-entity wrapper — invoice, quote, credit,
/// payment, expense, recurring invoice, recurring expense — had already
/// arrived at `color: tokens.ink` independently; this just makes the
/// default agree with them, so the un-wrapped call sites (list tiles,
/// detail headers, system-log rows) stop being the exception.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.fgColor,
    this.bgColor,
    this.tooltip,
    this.dotSize = 5,
    this.textStyle,
  });

  final String label;
  final Color fgColor;
  final Color? bgColor;
  final String? tooltip;
  final double dotSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final bg = bgColor ?? fgColor.withValues(alpha: 0.15);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: fgColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  textStyle ??
                  TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                    letterSpacing: 0.2,
                  ),
            ),
          ),
        ],
      ),
    );
    if (tooltip == null) return pill;
    return Tooltip(message: tooltip!, child: pill);
  }
}

@Preview(name: 'All statuses', group: 'StatusPill', theme: appPreviewTheme)
Widget previewStatusPillAll() {
  return Builder(
    builder: (context) {
      final t = context.inTheme;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(label: 'Paid', fgColor: t.paid, bgColor: t.paidSoft),
            StatusPill(
              label: 'Overdue',
              fgColor: t.overdue,
              bgColor: t.overdueSoft,
            ),
            StatusPill(label: 'Sent', fgColor: t.sent, bgColor: t.sentSoft),
            StatusPill(label: 'Draft', fgColor: t.draft, bgColor: t.draftSoft),
            StatusPill(
              label: 'Partial',
              fgColor: t.partial,
              bgColor: t.partialSoft,
            ),
            // Auto-derived background (caller has no paired soft token).
            const StatusPill(label: 'Custom', fgColor: Color(0xFF8E44AD)),
          ],
        ),
      );
    },
  );
}
