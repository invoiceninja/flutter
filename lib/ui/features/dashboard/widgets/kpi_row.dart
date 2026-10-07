import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/helpers/needs_attention.dart';
import 'package:admin/ui/features/dashboard/helpers/totals_math.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_figures.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';
import 'package:admin/utils/formatting.dart';

/// Content width from which Outstanding and the period card share one row.
/// Measured on the row's own width, not the window: a 1280 px window leaves
/// ~1000 px of content beside the sidebar, and a threshold of 1024 put four
/// figures on two rows there.
const double kFiguresOneRowWidth = 880;

/// The dashboard's figures: **Outstanding** — what is unpaid today — beside
/// **Invoices · Payments · Expenses** for the selected period.
///
/// Two different kinds of number, drawn as two cards so they are not read as
/// one series. Outstanding is a balance as of now and ignores the date range;
/// the other three are flows inside it, each with its change against the
/// compared period the row above names.
///
/// It replaces three tiles of which the third, a count of unpaid invoices,
/// repeated the first and led to the same list — while Invoiced and Expenses,
/// which the same totals call returns, were shown nowhere.
///
/// Every figure draws a skeleton until its section has answered, and a dash
/// with a retry when it could not: the old row formatted `amount ?? zero`, so
/// "not loaded" and "failed" both read as `$0.00`.
class KpiRow extends StatelessWidget {
  const KpiRow({
    super.key,
    required this.vm,
    required this.formatter,
    this.pastDueCount,
    this.showExpenses = true,
    this.onOutstandingTap,
    this.onInvoicesTap,
    this.onPaidTap,
  });

  final DashboardViewModel vm;
  final Formatter formatter;

  /// How many invoices are past due — the band's count, so the two agree.
  /// Null when it is not known (the list has not loaded) or not offered.
  final AttentionCount? pastDueCount;

  /// Whether the Expenses figure is drawn (the expenses module is on).
  final bool showExpenses;

  final VoidCallback? onOutstandingTap;
  final VoidCallback? onInvoicesTap;
  final VoidCallback? onPaidTap;

  @override
  Widget build(BuildContext context) {
    final outstanding = buildOutstandingCard(
      context,
      vm: vm,
      formatter: formatter,
      pastDueCount: pastDueCount,
      onTap: onOutstandingTap,
    );
    final period = buildPeriodCard(
      context,
      vm: vm,
      formatter: formatter,
      showExpenses: showExpenses,
      onInvoicesTap: onInvoicesTap,
      onPaidTap: onPaidTap,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kFiguresOneRowWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              outstanding,
              SizedBox(height: InSpacing.lg(context)),
              period,
            ],
          );
        }
        // Stretched so the two cards end on one line whatever their captions.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 10, child: outstanding),
              SizedBox(width: InSpacing.lg(context)),
              Expanded(flex: showExpenses ? 30 : 20, child: period),
            ],
          ),
        );
      },
    );
  }
}

/// The Outstanding card for [vm]. A function rather than a widget so the wide
/// row and the phone's hero build the very same card from the same rules.
OutstandingFigureCard buildOutstandingCard(
  BuildContext context, {
  required DashboardViewModel vm,
  required Formatter formatter,
  required AttentionCount? pastDueCount,
  required VoidCallback? onTap,
  double valueFontSize = 26,
}) {
  final currencyKey = selectedCurrencyKey(vm.filter.currencyId);
  final bucket = selectCurrencyTotals(vm.outstanding.data, currencyKey);
  final unpaid = bucket?.outstandingCount ?? 0;
  final late = pastDueCount;
  final caption = [
    context.tr('unpaid_count_label', {'count': '$unpaid'}),
    if (late != null && late.value > 0)
      context.tr('past_due_count_label', {'count': '$late'}),
  ].join(' · ');
  return OutstandingFigureCard(
    state: vm.outstanding.valueState,
    value: formatter.money(
      figureAmount(bucket?.outstandingAmount),
      currencyId: currencyKey,
    ),
    caption: caption,
    onTap: onTap,
    onRetry: () => vm.retry(DashboardKind.totalsOutstanding),
    valueFontSize: valueFontSize,
  );
}

/// The period card for [vm] — see [buildOutstandingCard].
PeriodFiguresCard buildPeriodCard(
  BuildContext context, {
  required DashboardViewModel vm,
  required Formatter formatter,
  required bool showExpenses,
  required VoidCallback? onInvoicesTap,
  required VoidCallback? onPaidTap,
  double valueFontSize = 22,
}) {
  final currencyKey = selectedCurrencyKey(vm.filter.currencyId);
  final DashboardCurrencyTotals? current = selectCurrencyTotals(
    vm.totals.data,
    currencyKey,
  );
  final DashboardCurrencyTotals? previous = selectCurrencyTotals(
    vm.totalsPrevious.data,
    currencyKey,
  );
  String money(DashboardCurrencyTotals? t, _Pick pick) =>
      formatter.money(figureAmount(pick(t)), currencyId: currencyKey);
  double? delta(_Pick pick) => percentDelta(pick(current), pick(previous));

  return PeriodFiguresCard(
    state: vm.totals.valueState,
    onRetry: () => vm.retry(DashboardKind.totalsCurrent),
    valueFontSize: valueFontSize,
    figures: [
      PeriodFigure(
        label: context.tr('invoices'),
        value: money(current, (t) => t?.invoicedAmount),
        deltaPercent: delta((t) => t?.invoicedAmount),
        goodDirection: GoodDirection.up,
        onTap: onInvoicesTap,
      ),
      PeriodFigure(
        label: context.tr('payments'),
        value: money(current, (t) => t?.revenuePaidToDate),
        deltaPercent: delta((t) => t?.revenuePaidToDate),
        goodDirection: GoodDirection.up,
        onTap: onPaidTap,
      ),
      if (showExpenses)
        PeriodFigure(
          label: context.tr('expenses'),
          value: money(current, (t) => t?.expensesAmount),
          deltaPercent: delta((t) => t?.expensesAmount),
          // Spending less is the good direction.
          goodDirection: GoodDirection.down,
          // No link: the expenses list has no date filter it can show, and a
          // figure that opens an unfiltered list promises rows it does not
          // deliver.
        ),
    ],
  );
}

typedef _Pick = Decimal? Function(DashboardCurrencyTotals? totals);
