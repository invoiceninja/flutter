import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/status_bounce_overlay.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';

/// Compact "● Status name" badge — colored dot + status name on a tinted
/// rounded-rect background. Used inside the invoices list tile, the
/// detail header, the wide-table status column, and anywhere else a raw
/// status id would otherwise leak into the UI.
///
/// Color tokens come from the design system (`paid` + `paidSoft`,
/// `partial` + `partialSoft`, `overdue` + `overdueSoft`, `sent` +
/// `sentSoft`, `draft` + `draftSoft`) so light/dark modes pick the right
/// palette automatically. Labels resolve via [invoiceStatusLabelKey] +
/// the active locale's translations.
class InvoiceStatusPill extends StatelessWidget {
  const InvoiceStatusPill({
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

  /// One of [InvoiceStatus.wireId] or [InvoiceStatusComputed] (`'-1'`,
  /// `'-2'`, `'-3'`) — pass the value of `invoice.calculatedStatusId`.
  final String statusId;
  final double dotSize;
  final TextStyle? textStyle;

  /// When true, overlays a small red alert badge on the pill — set from
  /// `invoice.hasBouncedInvitation` so a bounced send is visible in the
  /// list without opening the doc (mirrors admin-portal's status overlay).
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
    final name = context.tr(invoiceStatusLabelKey(statusId));
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
    case '4': // paid
      return (fg: tokens.paid, bg: tokens.paidSoft);
    case '3': // partial
      return (fg: tokens.partial, bg: tokens.partialSoft);
    case '2': // sent
      return (fg: tokens.sent, bg: tokens.sentSoft);
    case '5': // cancelled
    case '6': // reversed
      return (fg: tokens.ink3, bg: tokens.draftSoft);
    case '-1': // past due
    case '-2': // unpaid
      return (fg: tokens.overdue, bg: tokens.overdueSoft);
    case '-3': // viewed
      return (fg: tokens.sent, bg: tokens.sentSoft);
    case '1': // draft
    default:
      return (fg: tokens.draft, bg: tokens.draftSoft);
  }
}
