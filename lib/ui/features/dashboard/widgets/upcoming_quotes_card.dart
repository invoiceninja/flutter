import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/helpers/when_text.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_record_row.dart';
import 'package:admin/ui/features/dashboard/widgets/list_card.dart';
import 'package:admin/utils/formatting.dart';

String _quoteMoney(Formatter formatter, DashboardQuoteRow q) => formatter.money(
  q.amount,
  clientCurrencyId: q.currencyId.isEmpty ? null : q.currencyId,
);

/// Sent quotes still valid, soonest to lapse first (sorted by
/// `DashboardRepository.watchUpcomingQuotes`). Each row says how long the
/// quote has left; one with no valid-until date says nothing there.
class UpcomingQuotesCard extends StatelessWidget {
  const UpcomingQuotesCard({
    super.key,
    required this.section,
    required this.formatter,
    required this.today,
    required this.compact,
    required this.onQuoteTap,
    required this.onViewAll,
    required this.onRetry,
    this.remind,
    this.preview = 5,
  });

  final AsyncSection<List<DashboardQuoteRow>> section;
  final Formatter formatter;
  final Date today;

  /// The stacked row form — passed by the host; see [DashboardRecordRow].
  final bool compact;
  final void Function(DashboardQuoteRow) onQuoteTap;
  final VoidCallback onViewAll;
  final VoidCallback onRetry;

  /// Send a reminder for a row, or null when it is not offered for it.
  final RecordRowCallback? Function(DashboardQuoteRow row)? remind;
  final int preview;

  @override
  Widget build(BuildContext context) {
    return DashboardListCard<DashboardQuoteRow>(
      title: context.tr('upcoming_quotes'),
      section: section,
      onViewAll: onViewAll,
      onRetry: onRetry,
      emptyTitle: context.tr('no_upcoming_quotes'),
      preview: preview,
      bodyBuilder: (context, rows) {
        final remind = this.remind;
        final anyRemind = remind != null && rows.any((q) => remind(q) != null);
        return DashboardRecordRows(
          rows: [
            for (final q in rows)
              DashboardRecordRow(
                key: ValueKey('quote:${q.id}'),
                number: q.number,
                client: q.clientName,
                lead: q.validUntil == null
                    ? ''
                    : expiresText(context, q.validUntil!, today),
                amount: _quoteMoney(formatter, q),
                onTap: () => onQuoteTap(q),
                compact: compact,
                actions: [
                  if (anyRemind)
                    RecordRowAction(
                      icon: Icons.mail_outline,
                      tooltipKey: 'send_reminder_label',
                      onRun: remind(q),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Sent quotes whose valid-until date has passed. Each row says when.
class ExpiredQuotesCard extends StatelessWidget {
  const ExpiredQuotesCard({
    super.key,
    required this.section,
    required this.formatter,
    required this.compact,
    required this.onQuoteTap,
    required this.onViewAll,
    required this.onRetry,
    this.preview = 5,
  });

  final AsyncSection<List<DashboardQuoteRow>> section;
  final Formatter formatter;

  /// The stacked row form — passed by the host; see [DashboardRecordRow].
  final bool compact;
  final void Function(DashboardQuoteRow) onQuoteTap;
  final VoidCallback onViewAll;
  final VoidCallback onRetry;
  final int preview;

  @override
  Widget build(BuildContext context) {
    return DashboardListCard<DashboardQuoteRow>(
      title: context.tr('expired_quotes'),
      section: section,
      onViewAll: onViewAll,
      onRetry: onRetry,
      emptyTitle: context.tr('no_expired_quotes'),
      preview: preview,
      bodyBuilder: (context, rows) => DashboardRecordRows(
        rows: [
          for (final q in rows)
            DashboardRecordRow(
              key: ValueKey('quote:${q.id}'),
              number: q.number,
              client: q.clientName,
              // "Expired 01/Oct/2026" — the date the server calls `due_date`.
              // The column that used to show it read `valid_until`, a field
              // that is never sent, and so was a column of dashes.
              lead: q.validUntil == null
                  ? context.tr('expired')
                  : context.tr('expired_on', {
                      'date': formatter.date(q.validUntil!.toIso()),
                    }),
              amount: _quoteMoney(formatter, q),
              onTap: () => onQuoteTap(q),
              compact: compact,
            ),
        ],
      ),
    );
  }
}
