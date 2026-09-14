import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/purchase_order_status.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/status_bounce_overlay.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';

/// Compact status badge for the purchase order list + detail screens.
/// Mirrors the invoice / quote / credit status pill shape; color mapping
/// reflects the PO lifecycle: draft → sent → accepted (green) →
/// received (green) → cancelled (red).
class PurchaseOrderStatusPill extends StatelessWidget {
  const PurchaseOrderStatusPill({
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
  /// (`purchaseOrder.hasBouncedInvitation`).
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
    final name = context.tr(purchaseOrderStatusLabelKey(statusId));
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
    case '4': // received
    case '3': // accepted
      return (fg: tokens.paid, bg: tokens.paidSoft);
    case '5': // cancelled
      return (fg: tokens.overdue, bg: tokens.overdueSoft);
    case '2': // sent
    case '-1': // viewed (computed)
      return (fg: tokens.sent, bg: tokens.sentSoft);
    case '1': // draft
    default:
      return (fg: tokens.draft, bg: tokens.draftSoft);
  }
}
