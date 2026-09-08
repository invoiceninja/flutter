import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_calculated_field.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/dashboard/helpers/converted_hint.dart';
import 'package:admin/ui/features/dashboard/helpers/range_dates.dart';
import 'package:admin/ui/features/dashboard/helpers/totals_math.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';
import 'package:admin/ui/features/dashboard/widgets/kpi_card.dart';
import 'package:admin/ui/features/dashboard/widgets/section_listenable.dart';

/// Localization key for a card's period label (`current` →
/// `current_period`, `previous` → `previous_period`, `total` → `total`).
String _periodKey(CardPeriod p) => switch (p) {
  CardPeriod.current => 'current_period',
  CardPeriod.previous => 'previous_period',
  CardPeriod.total => 'total',
};

String _calcKey(CardCalc c) => switch (c) {
  CardCalc.sum => 'sum',
  CardCalc.avg => 'average',
  CardCalc.count => 'count',
};

/// User-configured metric cards (React's `dashboard_fields`). Renders directly
/// above the fixed KPI row. Empty → a slim "add" link instead of a grid.
class ConfiguredCardsGrid extends StatelessWidget {
  const ConfiguredCardsGrid({
    super.key,
    required this.vm,
    required this.formatter,
    required this.onManage,
    required this.onOpenCard,
  });

  final DashboardViewModel vm;
  final Formatter formatter;
  final VoidCallback onManage;

  /// Open the entity list relevant to a tapped card (deep-link).
  final void Function(DashboardCardConfig) onOpenCard;

  @override
  Widget build(BuildContext context) {
    if (vm.dashboardCards.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: LinkText(
          label: context.tr('add_dashboard_cards'),
          onTap: onManage,
          style: const TextStyle(fontSize: 12.5),
        ),
      );
    }
    // The cells' converted-currency caption reads `vm.totals`, which lands on
    // its own section notifier (`_subscribe` bumps the section and never fires
    // the global VM notify). Both mounts of this grid — wide and mobile — sit
    // under a plain `ListenableBuilder(listenable: vm)`, so without this the
    // caption would only appear on the next cross-cutting notify. One totals
    // emission rebuilding a handful of metric cards is cheap.
    return sectionListenable(
      vm.listenableFor(DashboardKind.totalsCurrent),
      () => LayoutBuilder(
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
              for (final c in vm.dashboardCards)
                sectionListenable(
                  vm.listenableFor(DashboardKind.calc(c.key)),
                  () => _CardCell(
                    vm: vm,
                    formatter: formatter,
                    config: c,
                    onOpenCard: onOpenCard,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CardCell extends StatelessWidget {
  const _CardCell({
    required this.vm,
    required this.formatter,
    required this.config,
    required this.onOpenCard,
  });

  final DashboardViewModel vm;
  final Formatter formatter;
  final DashboardCardConfig config;
  final void Function(DashboardCardConfig) onOpenCard;

  @override
  Widget build(BuildContext context) {
    final section = vm.cardSection(config.key);
    final label = context.tr(fieldLabelKey(config.field));
    final subcaption =
        '${context.tr(_periodKey(config.period))} · '
        '${context.tr(_calcKey(config.calculate))}';

    // A money card under "All currencies" shows a base-currency-converted
    // figure; flag it the same way the KPI row does. The hint takes the single
    // caption slot; when it doesn't apply (single-currency company, or a
    // specific currency picked) a `current`-period card falls back to the
    // resolved date range, same as its non-money siblings.
    final isMoney =
        config.format == CardFormat.money && config.calculate != CardCalc.count;
    String? secondCaption = isMoney
        ? convertedToBaseCaption(
            context,
            selectedCurrencyId: vm.filter.currencyId,
            totals: vm.totals.data,
            formatter: formatter,
          )
        : null;
    if (secondCaption == null && config.period == CardPeriod.current) {
      secondCaption = dashboardRangeDates(
        context,
        vm.filter,
        formatter: formatter,
      );
    }

    final value = _valueText(context, section);

    return KpiCard(
      label: label,
      value: value,
      deltaPercent: null,
      goodDirection: GoodDirection.up,
      showDelta: false,
      subcaption: subcaption,
      secondCaption: secondCaption,
      semanticsLabel: '$label, $value, $subcaption',
      // Error → retry; otherwise tap opens the relevant filtered list.
      onTap: section.hasError
          ? () => vm.retryCard(config.key)
          : () => onOpenCard(config),
    );
  }

  String _valueText(
    BuildContext context,
    AsyncSection<DashboardCalculatedField> section,
  ) {
    if (section.hasError && section.data == null) {
      return context.tr('error');
    }
    final data = section.data;
    if (data == null) return '—'; // idle / loading / no cache yet
    return dashboardCardValueText(
      config: config,
      value: data.value,
      asDecimal: data.asDecimal,
      formatter: formatter,
      currencyId: selectedCurrencyKey(vm.filter.currencyId),
    );
  }
}

/// Renders one configured card's value for [config]'s field class.
///
/// A pure function so the three branches are unit-testable — pumping the grid
/// needs a live `DashboardViewModel` holding Drift watches, and the branch that
/// broke (below) is invisible from outside anyway.
///
/// Three cases, and the guards matter:
///
/// * **Money, not a count** → currency-formatted. Mirrors React
///   DashboardCard.tsx:95-99. `currencyId` should be
///   `selectedCurrencyKey(filter.currencyId)`: `Formatter`'s all-currency
///   sentinel is `-1`, and for the dashboard's `999`=all we want the company
///   base currency, which is exactly what that helper yields.
/// * **Time, not a count** → a duration. The value is **seconds** on the wire
///   (`ChartCalculations` sums `calcDuration()` / `estimated_duration`, both
///   stored in seconds). React prints the bare number and so did we, so a
///   "Logged tasks / time / sum" card read `9000` rather than `2:30`; this
///   deliberately diverges, and is unavoidable for the 2026-08 duration fields
///   whose format the server forces to `time`.
///
///   `compactDays` + no seconds is the app's convention for an *aggregate*
///   duration (task list column, kanban card, detail KPI strip, daily header —
///   see `formatDuration`'s own doc). This is the largest duration in the app,
///   a period-wide sum across every task, so the bare default would give
///   `523:45:12` where the rest of the app says `21d 19h 45m`.
/// * **Anything else** (every count, and an avg-as-number) → the raw value.
///
/// **`calculate != count` guards both formatted branches.** The three original
/// `*_tasks` fields accept any calculation *and* offer a format control, so
/// `paid_tasks / count / time` is reachable from the picker — without the
/// guard a count of 42 tasks renders as the duration `0:00:42`.
String dashboardCardValueText({
  required DashboardCardConfig config,
  required num value,
  required Decimal asDecimal,
  required Formatter formatter,
  required String? currencyId,
}) {
  final isCount = config.calculate == CardCalc.count;
  if (config.format == CardFormat.money && !isCount) {
    return formatter.money(asDecimal, currencyId: currencyId);
  }
  if (config.format == CardFormat.time && !isCount) {
    return formatDuration(
      Duration(seconds: value.round()),
      compactDays: true,
      showSeconds: false,
    );
  }
  return value % 1 == 0 ? value.toInt().toString() : value.toString();
}
