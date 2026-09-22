import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/quote_status.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/status_bounce_overlay.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';

/// Compact status badge for the quotes list + detail screens. Mirrors the
/// invoice status pill shape; color mapping is quote-specific ("approved"
/// → green and "expired" → overdue).
class QuoteStatusPill extends StatelessWidget {
  const QuoteStatusPill({
    super.key,
    required this.statusId,
    this.dotSize = 8,
    this.textStyle,
    this.hasBounce = false,
    this.onTap,
    this.tooltip,
    this.semanticsLabel,
    this.semanticsHint,
  });

  final String statusId;
  final double dotSize;
  final TextStyle? textStyle;

  /// Overlays a red alert badge when an invitation bounced/errored
  /// (`quote.hasBouncedInvitation`).
  final bool hasBounce;

  /// Makes the pill a control — see [StatusPill.onTap], which carries the
  /// rules. Left null everywhere but a detail header: a list row and a table
  /// cell each already have exactly one destination.
  final VoidCallback? onTap;

  /// Hover text; on touch there is no hover and this never renders, which is
  /// why the caller must not make it the only home for anything.
  final String? tooltip;

  /// Announced instead of the status name when [onTap] is set, and the hint
  /// that names where the tap goes.
  final String? semanticsLabel;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final colors = _colorsForStatus(tokens, statusId);
    final name = context.tr(quoteStatusLabelKey(statusId));
    return StatusBounceOverlay(
      hasBounce: hasBounce,
      child: StatusPill(
        label: name,
        fgColor: colors.fg,
        bgColor: colors.bg,
        dotSize: dotSize,
        textStyle: textStyle ?? TextStyle(fontSize: 13, color: tokens.ink),
        onTap: onTap,
        tooltip: tooltip,
        semanticsLabel: semanticsLabel,
        semanticsHint: semanticsHint,
      ),
    );
  }
}

({Color fg, Color bg}) _colorsForStatus(InTheme tokens, String id) {
  switch (id) {
    case '3': // approved
      return (fg: tokens.paid, bg: tokens.paidSoft);
    case '4': // converted
    case '2': // sent
    case '-2': // viewed (computed)
      return (fg: tokens.sent, bg: tokens.sentSoft);
    case '-1': // expired (computed)
    case '5': // rejected — negative terminal state, shares the overdue red
      return (fg: tokens.overdue, bg: tokens.overdueSoft);
    case '6': // cancelled — inert, not urgent: no red (matches the invoice
      // pill's cancelled/reversed and the server's own `badge-secondary`).
      return (fg: tokens.ink3, bg: tokens.draftSoft);
    case '1': // draft
    default:
      return (fg: tokens.draft, bg: tokens.draftSoft);
  }
}
