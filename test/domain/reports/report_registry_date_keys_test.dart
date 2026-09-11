import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_group_label.dart';
import 'package:admin/domain/reports/report_registry.dart';

import '../../_localization_helper.dart';

/// `ReportDefinition.dateRangeKey` mirrors each export's own
/// `public string $date_key` (`app/Export/CSV/*.php`,
/// `app/Services/Report/*.php`). It exists so the Date Range control can say
/// *which* date it filters on — invoiceninja/flutter#138's first ask turned
/// out to already work, it just never said so.
void main() {
  group('report date range keys', () {
    test('every declared key resolves to a label', () {
      // A key with no label renders nothing at all, which is indistinguishable
      // on screen from a report that genuinely has no date filter — so the
      // one report it broke would be silent.
      for (final def in kReportDefinitions) {
        final key = def.dateRangeKey;
        if (key == null) continue;
        expect(
          reportDateKeyLabelKey(key),
          isNotNull,
          reason:
              '${def.identifier} declares dateRangeKey "$key" with no label',
        );
      }
    });

    test('the reports with no server-side date filter declare none', () {
      // `ProjectReport::getPdf()` and `ARSummaryReport` both document
      // `date_range` / `start_date` / `end_date` in their input contracts and
      // never call `addDateRange`, so their ranges are inert — naming a
      // column there would assert a filter the server does not apply. Profit
      // & loss and the tax period report own their own date semantics.
      for (final id in [
        'project',
        'aged_receivable_summary_report',
        'profitloss',
        'tax_period_report',
      ]) {
        expect(reportDefinitionFor(id).dateRangeKey, isNull, reason: id);
      }
    });

    test('every other report declares one', () {
      const noKey = {
        'project',
        'aged_receivable_summary_report',
        'profitloss',
        'tax_period_report',
      };
      for (final def in kReportDefinitions) {
        if (noKey.contains(def.identifier)) continue;
        expect(def.dateRangeKey, isNotNull, reason: def.identifier);
      }
    });

    test('agrees with the date_key the registry already declared', () {
      // Six reports carried a `date_key` in `defaultFilterValues` long before
      // `dateRangeKey` existed. They were verified against the server source
      // and must not drift apart.
      for (final def in kReportDefinitions) {
        final legacy = def.defaultFilterValues['date_key'];
        if (legacy == null) continue;
        expect(def.dateRangeKey, legacy, reason: def.identifier);
      }
    });

    // Both of these reach `context.tr` through a **variable**, which
    // `no_unsubstituted_placeholders_test` cannot see — CLAUDE.md § Localization
    // asks for the invariant in the owning structure's own test. Asserting the
    // mapping returns non-null is not enough: a typo like `'date_created'`
    // would pass that and render the raw key on screen.
    test('every date-key label resolves in the bundle', () {
      final l10n = bundledLocalization();
      for (final def in kReportDefinitions) {
        final key = reportDateKeyLabelKey(def.dateRangeKey);
        if (key == null) continue;
        final rendered = l10n.lookup(key);
        expect(rendered, isNotEmpty, reason: '$key (${def.identifier})');
        expect(rendered, isNot(key), reason: '$key (${def.identifier})');
      }
    });

    test('every subgroup label resolves in the bundle', () {
      final l10n = bundledLocalization();
      for (final sub in ReportSubgroup.values) {
        final rendered = l10n.lookup(sub.labelKey);
        expect(rendered, isNotEmpty, reason: sub.labelKey);
        expect(rendered, isNot(sub.labelKey), reason: sub.labelKey);
      }
    });

    test('only the clients report can ask for its date column', () {
      // Every other report's date column is already in the server's default
      // set, so there is nothing to offer; `client_report_keys` alone omits
      // `created_at`.
      final offered = [
        for (final def in kReportDefinitions)
          if (def.optionalDateColumnId != null) def.identifier,
      ];
      expect(offered, ['client']);
      expect(
        reportDefinitionFor('client').optionalDateColumnId,
        'client.created_at',
      );
    });
  });
}
