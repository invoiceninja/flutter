import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/ui/core/detail/kpi_strip_layout.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/detail/kpi_cell.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/expenses/widgets/expense_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// Full-width KPI strip at the top of the expense Overview tab — the page's
/// most important facts (amount, gross, date, status) pulled up to where the
/// eye lands. Mirrors [ClientDetailKpiStrip].
///
/// - ≥1100 px: a single row of four cells separated by 1 px vertical dividers.
/// - <1100 px: a 2×2 grid.
class ExpenseDetailKpiStrip extends StatelessWidget {
  const ExpenseDetailKpiStrip({
    super.key,
    required this.expense,
    required this.formatter,
  });

  final Expense expense;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final e = expense;
    final f = formatter;

    final amountText = f == null
        ? e.amount.toString()
        : f.money(e.amount, clientCurrencyId: e.currencyId);
    final grossText = e.taxAmountSum == Decimal.zero
        ? '—'
        : (f == null
              ? e.grossAmount.toString()
              : f.money(e.grossAmount, clientCurrencyId: e.currencyId));
    final dateText = e.date == null
        ? '—'
        : (f == null ? e.date!.toIso() : f.date(e.date!.toIso()));

    final cells = <Widget>[
      KpiCell(
        label: context.tr('amount'),
        value: Text(
          amountText,
          style: theme.textTheme.titleLarge
              ?.copyWith(color: tokens.ink, fontWeight: FontWeight.w600)
              .merge(moneyTextStyle()),
        ),
        tokens: tokens,
      ),
      KpiCell(
        label: context.tr('gross_amount'),
        value: Text(
          grossText,
          style: theme.textTheme.titleLarge
              ?.copyWith(
                color: grossText == '—' ? tokens.ink3 : tokens.ink,
                fontWeight: FontWeight.w600,
              )
              .merge(moneyTextStyle()),
        ),
        tokens: tokens,
      ),
      KpiCell(
        label: context.tr('date'),
        value: Text(
          dateText,
          style: theme.textTheme.titleLarge?.copyWith(
            color: dateText == '—' ? tokens.ink3 : tokens.ink,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        tokens: tokens,
      ),
      KpiCell(
        label: context.tr('status'),
        value: ExpenseStatusPill(
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
