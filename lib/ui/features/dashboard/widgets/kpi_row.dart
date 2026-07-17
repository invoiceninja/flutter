import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/dashboard/helpers/totals_math.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';
import 'package:admin/ui/features/dashboard/widgets/kpi_card.dart';

/// Builds the four-KPI row. Picks the current-currency totals out of the
/// `totals.byCurrency` map. When `All currencies` is selected the figures come
/// from the server's exchange-rate-converted base-currency bucket; a subtle
/// "converted to base currency" caption flags that.
class KpiRow extends StatelessWidget {
  const KpiRow({
    super.key,
    required this.vm,
    required this.formatter,
    this.onOutstandingTap,
    this.onPaidThisMonthTap,
  });

  final DashboardViewModel vm;
  final Formatter formatter;
  final VoidCallback? onOutstandingTap;
  final VoidCallback? onPaidThisMonthTap;

  @override
  Widget build(BuildContext context) {
    final isAll = vm.filter.currencyId == kDashboardCurrencyAll;
    final currencyKey = isAll ? null : vm.filter.currencyId.toString();
    final current = selectCurrencyTotals(vm.totals.data, currencyKey);
    final previous = selectCurrencyTotals(vm.totalsPrevious.data, currencyKey);
    final baseCode =
        formatter.currencies[formatter.settings.currencyId]?.code ?? '';
    final convertedHint = isAll && baseCode.isNotEmpty
        ? context.tr('converted_to_currency', {'currency': baseCode})
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width >= 1024 ? 3 : (width >= 600 ? 2 : 1);
        return GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: InSpacing.lg(context),
            mainAxisSpacing: InSpacing.lg(context),
            mainAxisExtent: 140,
          ),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: [
            _outstandingCard(context, current, previous, convertedHint),
            _unpaidCard(context, current, previous),
            _paidThisMonthCard(context, current, previous, convertedHint),
          ],
        );
      },
    );
  }

  String _kpiSemantics(
    BuildContext context, {
    required String label,
    required String value,
    required double? delta,
  }) {
    if (delta == null) {
      return context.tr('kpi_no_delta_semantic', {
        'label': label,
        'value': value,
      });
    }
    return context.tr('kpi_with_delta_semantic', {
      'label': label,
      'value': value,
      'direction': context.tr(delta > 0 ? 'delta_up' : 'delta_down'),
      'percent': delta.abs().toStringAsFixed(1),
    });
  }

  KpiCard _outstandingCard(
    BuildContext context,
    DashboardCurrencyTotals? current,
    DashboardCurrencyTotals? previous,
    String? convertedHint,
  ) {
    final value = formatter.money(current?.outstandingAmount ?? Decimal.zero);
    final delta = percentDelta(
      current?.outstandingAmount,
      previous?.outstandingAmount,
    );
    final label = context.tr('outstanding');
    return KpiCard(
      label: label,
      value: value,
      deltaPercent: delta,
      goodDirection: GoodDirection.down,
      subcaption: convertedHint,
      semanticsLabel: _kpiSemantics(
        context,
        label: label,
        value: value,
        delta: delta,
      ),
      onTap: onOutstandingTap,
    );
  }

  // Count of unpaid (sent + partial) invoices in the period. The server totals
  // endpoint exposes only `outstanding_count` — there is NO overdue count — so
  // this tile is labeled "Unpaid" (not "Overdue"), sits next to the sibling
  // "Outstanding" *amount* tile, and drills through to the same windowed-unpaid
  // list. Relabeled from a mislabeled "Overdue" whose number (outstanding
  // count) and drill-through (genuinely overdue) disagreed (U7).
  KpiCard _unpaidCard(
    BuildContext context,
    DashboardCurrencyTotals? current,
    DashboardCurrencyTotals? previous,
  ) {
    final count = current?.outstandingCount ?? 0;
    final value = '$count';
    final label = context.tr('unpaid');
    return KpiCard(
      label: label,
      value: value,
      deltaPercent: null,
      goodDirection: GoodDirection.down,
      semanticsLabel: _kpiSemantics(
        context,
        label: label,
        value: value,
        delta: null,
      ),
      onTap: onOutstandingTap,
    );
  }

  KpiCard _paidThisMonthCard(
    BuildContext context,
    DashboardCurrencyTotals? current,
    DashboardCurrencyTotals? previous,
    String? convertedHint,
  ) {
    final value = formatter.money(current?.revenuePaidToDate ?? Decimal.zero);
    final delta = percentDelta(
      current?.revenuePaidToDate,
      previous?.revenuePaidToDate,
    );
    final label = context.tr('paid_this_month');
    return KpiCard(
      label: label,
      value: value,
      deltaPercent: delta,
      goodDirection: GoodDirection.up,
      subcaption: convertedHint,
      semanticsLabel: _kpiSemantics(
        context,
        label: label,
        value: value,
        delta: delta,
      ),
      onTap: onPaidThisMonthTap,
    );
  }
}
