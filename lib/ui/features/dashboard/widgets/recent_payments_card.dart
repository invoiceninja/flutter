import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_record_row.dart';
import 'package:admin/ui/features/dashboard/widgets/list_card.dart';
import 'package:admin/ui/features/dashboard/widgets/status_badge.dart';
import 'package:admin/utils/formatting.dart';

/// The latest payments, newest first.
///
/// A row names its status only when it is something other than Completed —
/// which nearly every payment is, so a "Completed" pill on each row was a
/// column of noise that hid the one Pending or Failed payment worth seeing.
class RecentPaymentsCard extends StatelessWidget {
  const RecentPaymentsCard({
    super.key,
    required this.section,
    required this.formatter,
    required this.compact,
    required this.onPaymentTap,
    required this.onViewAll,
    required this.onRetry,
    this.preview = 5,
  });

  final AsyncSection<List<DashboardPaymentRow>> section;
  final Formatter formatter;

  /// The stacked row form — passed by the host; see [DashboardRecordRow].
  final bool compact;
  final void Function(DashboardPaymentRow) onPaymentTap;
  final VoidCallback onViewAll;
  final VoidCallback onRetry;
  final int preview;

  /// `Payment::STATUS_COMPLETED`.
  static const int _completed = 4;

  @override
  Widget build(BuildContext context) {
    return DashboardListCard<DashboardPaymentRow>(
      title: context.tr('recent_payments'),
      section: section,
      onViewAll: onViewAll,
      onRetry: onRetry,
      emptyTitle: context.tr('no_payments_yet'),
      preview: preview,
      bodyBuilder: (context, rows) => DashboardRecordRows(
        rows: [
          for (final r in rows)
            DashboardRecordRow(
              key: ValueKey('payment:${r.id}'),
              number: r.number,
              client: r.clientName,
              lead: r.date == null ? '' : formatter.date(r.date!.toIso()),
              fact: r.statusId == _completed
                  ? null
                  : StatusBadge.paymentStatus(context, r.statusId).$1,
              amount: formatter.money(
                r.amount,
                currencyId: r.currencyId.isEmpty ? null : r.currencyId,
              ),
              onTap: () => onPaymentTap(r),
              compact: compact,
            ),
        ],
      ),
    );
  }
}
