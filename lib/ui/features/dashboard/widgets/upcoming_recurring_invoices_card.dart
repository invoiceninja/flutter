import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_record_row.dart';
import 'package:admin/ui/features/dashboard/widgets/list_card.dart';
import 'package:admin/utils/formatting.dart';

/// Active recurring invoices, next to send first. Each row says when it next
/// goes out.
class UpcomingRecurringInvoicesCard extends StatelessWidget {
  const UpcomingRecurringInvoicesCard({
    super.key,
    required this.section,
    required this.formatter,
    required this.compact,
    required this.onRecurringTap,
    required this.onViewAll,
    required this.onRetry,
    this.preview = 5,
  });

  final AsyncSection<List<DashboardRecurringInvoiceRow>> section;
  final Formatter formatter;

  /// The stacked row form — passed by the host; see [DashboardRecordRow].
  final bool compact;
  final void Function(DashboardRecurringInvoiceRow) onRecurringTap;
  final VoidCallback onViewAll;
  final VoidCallback onRetry;
  final int preview;

  @override
  Widget build(BuildContext context) {
    return DashboardListCard<DashboardRecurringInvoiceRow>(
      title: context.tr('upcoming_recurring_invoices'),
      section: section,
      onViewAll: onViewAll,
      onRetry: onRetry,
      emptyTitle: context.tr('no_upcoming_recurring_invoices'),
      preview: preview,
      bodyBuilder: (context, rows) => DashboardRecordRows(
        rows: [
          for (final r in rows)
            DashboardRecordRow(
              key: ValueKey('recurring:${r.id}'),
              number: r.number,
              client: r.clientName,
              lead: r.nextSendDate == null
                  ? ''
                  : formatter.date(r.nextSendDate!.toIso()),
              amount: formatter.money(
                r.amount,
                clientCurrencyId: r.currencyId.isEmpty ? null : r.currencyId,
              ),
              onTap: () => onRecurringTap(r),
              compact: compact,
            ),
        ],
      ),
    );
  }
}
