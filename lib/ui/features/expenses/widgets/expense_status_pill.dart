import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/expense_status.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';

/// Compact "● Status name" badge for expenses. Shared between the list tile,
/// the record screen's standing card and the wide-table status column, so
/// color + label stay in sync.
///
/// Maps expense statuses onto the shared design tokens
/// (paid → paid, unpaid → overdue, invoiced → partial, pending → sent,
/// logged → draft) so light/dark palettes resolve automatically.
class ExpenseStatusPill extends StatelessWidget {
  const ExpenseStatusPill({
    super.key,
    required this.statusId,
    this.dotSize = 8,
    this.textStyle,
  });

  final String statusId;
  final double dotSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final colors = _colorsForStatus(tokens, statusId);
    final labelKey = kExpenseStatusLabels[statusId];
    final name = labelKey == null ? statusId : context.tr(labelKey);
    return StatusPill(
      label: name,
      fgColor: colors.fg,
      bgColor: colors.bg,
      dotSize: dotSize,
      textStyle: textStyle ?? TextStyle(fontSize: 13, color: tokens.ink),
    );
  }
}

({Color fg, Color bg}) _colorsForStatus(InTheme tokens, String id) {
  switch (id) {
    case kExpenseStatusPaid:
      return (fg: tokens.paid, bg: tokens.paidSoft);
    case kExpenseStatusUnpaid:
      return (fg: tokens.overdue, bg: tokens.overdueSoft);
    case kExpenseStatusInvoiced:
      return (fg: tokens.partial, bg: tokens.partialSoft);
    case kExpenseStatusPending:
      return (fg: tokens.sent, bg: tokens.sentSoft);
    case kExpenseStatusLogged:
    default:
      return (fg: tokens.draft, bg: tokens.draftSoft);
  }
}
