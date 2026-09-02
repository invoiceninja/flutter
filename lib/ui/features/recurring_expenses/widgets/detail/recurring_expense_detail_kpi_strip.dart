import 'package:flutter/material.dart';

import 'package:admin/ui/core/detail/kpi_strip_layout.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// KPI strip at the top of the recurring-expense Overview tab. Cells differ
/// from a one-shot expense — instead of `gross_amount` and `date` we surface
/// the schedule-specific facts (next send date, frequency) that explain
/// "when does this fire and how often".
class RecurringExpenseDetailKpiStrip extends StatelessWidget {
  const RecurringExpenseDetailKpiStrip({
    super.key,
    required this.recurringExpense,
    required this.formatter,
  });

  final RecurringExpense recurringExpense;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final e = recurringExpense;
    final f = formatter;

    final amountText = f == null
        ? e.amount.toString()
        : f.money(e.amount, clientCurrencyId: e.currencyId);
    final nextSendText = e.nextSendDate == null
        ? '—'
        : (f == null
              ? e.nextSendDate!.toIso()
              : f.date(e.nextSendDate!.toIso()));
    final freqKey = kRecurringFrequencyLabelKey[e.frequencyId];
    final freqLabel = freqKey == null
        ? (e.frequencyId.isEmpty ? '—' : e.frequencyId)
        : context.tr(freqKey);

    final cells = <Widget>[
      _KpiCell(
        label: context.tr('amount'),
        value: Text(
          amountText,
          style: theme.textTheme.titleLarge?.merge(
            moneyTextStyle(color: tokens.ink, fontWeight: FontWeight.w600),
          ),
        ),
        tokens: tokens,
      ),
      _KpiCell(
        label: context.tr('next_send_date'),
        value: Text(
          nextSendText,
          style: theme.textTheme.titleLarge?.copyWith(
            color: nextSendText == '—' ? tokens.ink3 : tokens.ink,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        tokens: tokens,
      ),
      _KpiCell(
        label: context.tr('frequency'),
        value: Text(
          freqLabel,
          style: theme.textTheme.titleLarge?.copyWith(
            color: freqLabel == '—' ? tokens.ink3 : tokens.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        tokens: tokens,
      ),
      _KpiCell(
        label: context.tr('status'),
        value: RecurringExpenseStatusPill(
          statusId: e.calculatedStatusId,
          textStyle: theme.textTheme.titleMedium?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
          ),
          dotSize: 10,
        ),
        tokens: tokens,
      ),
    ];

    return DashboardCardShell(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.lg(context),
      ),
      child: KpiStripLayout(cells: cells),
    );
  }
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({
    required this.label,
    required this.value,
    required this.tokens,
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
