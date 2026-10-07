import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/helpers/needs_attention.dart';
import 'package:admin/ui/features/dashboard/helpers/when_text.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_record_row.dart';
import 'package:admin/ui/features/dashboard/widgets/list_card.dart';
import 'package:admin/utils/formatting.dart';

/// Unpaid invoices with a due date still ahead, soonest first.
///
/// The rows arrive sorted (`DashboardRepository.watchUpcomingInvoices`) — the
/// server sends them newest-created first, so the five shown used not to be
/// the five due next. An invoice with no due date comes last and says so in
/// words rather than with a date it does not have.
class UpcomingInvoicesCard extends StatelessWidget {
  const UpcomingInvoicesCard({
    super.key,
    required this.section,
    required this.formatter,
    required this.today,
    required this.compact,
    required this.onInvoiceTap,
    required this.onViewAll,
    required this.onRetry,
    this.enterPayment,
    this.preview = 5,
  });

  final AsyncSection<List<DashboardInvoiceRow>> section;
  final Formatter formatter;
  final Date today;

  /// The stacked row form — passed by the host; see [DashboardRecordRow].
  final bool compact;
  final void Function(DashboardInvoiceRow) onInvoiceTap;
  final VoidCallback onViewAll;
  final VoidCallback onRetry;

  /// Enter Payment for a row, or null when it is not offered for it.
  final RecordRowCallback? Function(DashboardInvoiceRow row)? enterPayment;
  final int preview;

  @override
  Widget build(BuildContext context) {
    return DashboardListCard<DashboardInvoiceRow>(
      title: context.tr('upcoming_invoices'),
      section: section,
      onViewAll: onViewAll,
      onRetry: onRetry,
      emptyTitle: context.tr('no_invoices_due_soon'),
      preview: preview,
      bodyBuilder: (context, rows) {
        final pay = enterPayment;
        final anyPay = pay != null && rows.any((r) => pay(r) != null);
        return DashboardRecordRows(
          rows: [
            for (final r in rows)
              DashboardRecordRow(
                key: ValueKey('invoice:${r.id}'),
                number: r.number,
                client: r.clientName,
                lead: switch (nextDueDate(r, today)) {
                  final Date due => dueText(context, due, today),
                  // On the server "upcoming" includes a sent invoice with no
                  // due date at all, and saying so is the useful thing: it is
                  // owed with nothing chasing it.
                  null => context.tr('no_due_date'),
                },
                amount: formatter.money(
                  r.balance,
                  clientCurrencyId: r.currencyId.isEmpty ? null : r.currencyId,
                ),
                onTap: () => onInvoiceTap(r),
                compact: compact,
                actions: [
                  if (anyPay)
                    RecordRowAction(
                      icon: Icons.payments_outlined,
                      tooltipKey: 'enter_payment',
                      onRun: pay(r),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
