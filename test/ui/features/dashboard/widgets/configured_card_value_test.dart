// `dashboardCardValueText` — the three renderings a configured dashboard card
// can have, and the guard that keeps them apart.
//
// Extracted as a pure function precisely so this file can exist: pumping
// `ConfiguredCardsGrid` needs a live `DashboardViewModel` holding Drift watch
// subscriptions, and the branch that broke is invisible from outside anyway.

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/ui/features/dashboard/widgets/configured_cards_grid.dart';
import 'package:admin/utils/formatting.dart';

void main() {
  final formatter = Formatter(
    settings: CompanyFormatSettings.fallback,
    currencies: const {},
    countries: const {},
    dateFormats: const {'5': DatetimeFormat(id: '5', format: 'MMM d, yyyy')},
  );

  String render(String field, CardCalc calc, CardFormat format, num value) =>
      dashboardCardValueText(
        config: DashboardCardConfig(
          field: field,
          period: CardPeriod.current,
          calculate: calc,
          format: format,
        ),
        value: value,
        asDecimal: Decimal.parse(value.toString()),
        formatter: formatter,
        currencyId: null,
      );

  group('dashboardCardValueText', () {
    test('a time card renders seconds as an aggregate duration', () {
      // The wire unit is seconds (`Task::calcDuration()` sums unix deltas;
      // `estimated_duration` is documented as seconds). This read `9000` for
      // the life of the feature.
      expect(
        render('logged_tasks', CardCalc.sum, CardFormat.time, 9000),
        '2:30',
      );
      // `compactDays` is the app's convention for an aggregate duration — the
      // bare default would give `523:45:12` here.
      expect(
        render('logged_tasks', CardCalc.sum, CardFormat.time, 1885512),
        '21d 19h 45m',
      );
    });

    test(
      'a COUNT is never rendered as a duration, even when format is time',
      () {
        // `paid_tasks / count / time` is reachable from the picker: the three
        // original `*_tasks` fields accept any calculation *and* show a format
        // control. Without the `calculate != count` guard, 42 tasks read
        // `0:00:42`.
        expect(render('paid_tasks', CardCalc.count, CardFormat.time, 42), '42');
        expect(render('logged_tasks', CardCalc.count, CardFormat.time, 0), '0');
      },
    );

    test('a COUNT is never currency-formatted either', () {
      // The pre-existing half of the same guard.
      expect(
        render('active_invoices', CardCalc.count, CardFormat.money, 7),
        '7',
      );
    });

    test('the task count fields render as bare integers', () {
      for (final f in kTaskCountCardFields) {
        expect(render(f, CardCalc.count, CardFormat.none, 12), '12', reason: f);
      }
    });

    test('a fractional avg keeps its decimals when unformatted', () {
      expect(render('overdue_tasks', CardCalc.count, CardFormat.none, 3), '3');
      expect(
        render('active_invoices', CardCalc.avg, CardFormat.none, 2.5),
        '2.5',
      );
    });
  });
}
