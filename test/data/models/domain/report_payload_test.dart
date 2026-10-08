import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/value/date.dart';

void main() {
  group('ReportPayload.toJson', () {
    test('emits date_range wire key and drops empty optionals', () {
      final json = const ReportPayload(
        datePreset: ReportDatePreset.thisYear,
      ).toJson(reportIdentifier: 'clients');
      expect(json['date_range'], 'this_year');
      expect(json.containsKey('start_date'), isFalse);
      expect(json.containsKey('clients'), isFalse);
    });

    test('date_range tokens match the server BaseExport switch', () {
      // Verified against invoiceninja `app/Export/CSV/BaseExport.php`: the
      // 365-day window is `last365_days` (NOT `last365`) and there is no
      // `last90` case (an unknown token silently widens to all-time). Other
      // tokens are short-form (`all`/`last7`/`last30`). Regression guard.
      String wireFor(ReportDatePreset p) =>
          const ReportPayload()
                  .copyWith(datePreset: p)
                  .toJson(reportIdentifier: 'clients')['date_range']
              as String;

      expect(wireFor(ReportDatePreset.allTime), 'all');
      expect(wireFor(ReportDatePreset.last7), 'last7');
      expect(wireFor(ReportDatePreset.last30), 'last30');
      expect(wireFor(ReportDatePreset.last365), 'last365_days');
      expect(wireFor(ReportDatePreset.thisMonth), 'this_month');
      expect(wireFor(ReportDatePreset.lastQuarter), 'last_quarter');
      expect(wireFor(ReportDatePreset.thisYear), 'this_year');
    });

    test('template id serializes as template_id (server wire key)', () {
      // The server + React expect `template_id`; sending `template` silently
      // drops the design-template filter. Regression guard.
      final json = const ReportPayload(
        templateId: 'design-123',
      ).toJson(reportIdentifier: 'invoice');
      expect(json['template_id'], 'design-123');
      expect(json.containsKey('template'), isFalse);
    });

    test('default payload date_range is all-time (short form)', () {
      final json = const ReportPayload().toJson(reportIdentifier: 'clients');
      expect(json['date_range'], 'all');
    });

    test('serializes start/end as ISO date strings when set', () {
      final json = ReportPayload(
        datePreset: ReportDatePreset.custom,
        startDate: Date(2026, 1, 1),
        endDate: Date(2026, 12, 31),
      ).toJson(reportIdentifier: 'clients');
      expect(json['date_range'], 'custom');
      expect(json['start_date'], '2026-01-01');
      expect(json['end_date'], '2026-12-31');
    });

    test('CSV multi-select fields pass through as strings', () {
      final json = const ReportPayload(
        clients: 'abc,def,ghi',
        vendors: 'jkl,mno',
      ).toJson(reportIdentifier: 'expense');
      expect(json['clients'], 'abc,def,ghi');
      expect(json['vendors'], 'jkl,mno');
    });

    test('product_sales coerces empty client_id to literal null', () {
      final json = const ReportPayload(
        clientId: null,
      ).toJson(reportIdentifier: 'product_sales');
      expect(json.containsKey('client_id'), isTrue);
      expect(json['client_id'], isNull);
    });

    test('product_sales preserves a non-empty client_id verbatim', () {
      final json = const ReportPayload(
        clientId: 'abc',
      ).toJson(reportIdentifier: 'product_sales');
      expect(json['client_id'], 'abc');
    });

    test('other reports drop an empty client_id entirely', () {
      final json = const ReportPayload(
        clientId: null,
      ).toJson(reportIdentifier: 'clients');
      expect(json.containsKey('client_id'), isFalse);
    });

    test('an optional flag only appears when true', () {
      final flagged = const ReportPayload(
        includeDeleted: true,
      ).toJson(reportIdentifier: 'invoice');
      expect(flagged['include_deleted'], true);
      final empty = const ReportPayload().toJson(reportIdentifier: 'invoice');
      expect(empty.containsKey('include_deleted'), isFalse);
      // Reports that neither require nor read these never see them.
      expect(empty.containsKey('is_income_billed'), isFalse);
      expect(empty.containsKey('include_tax'), isFalse);
    });

    test('profit and loss always carries the two flags it requires', () {
      // `ProfitLossRequest` declares both `required|bool`. Left off when
      // false, the report answered 422 in three of its four switch states
      // (probed live: "The is income billed field is required.").
      final off = const ReportPayload().toJson(reportIdentifier: 'profitloss');
      expect(off['is_income_billed'], false);
      expect(off['include_tax'], false);

      final on = const ReportPayload(
        isIncomeBilled: true,
      ).toJson(reportIdentifier: 'profitloss');
      expect(on['is_income_billed'], true);
      expect(on['include_tax'], false);
    });

    test('tax period always carries is_income_billed', () {
      // `TaxPeriodReport::setAccountingType` reads the key unguarded.
      final off = const ReportPayload().toJson(
        reportIdentifier: 'tax_period_report',
      );
      expect(off['is_income_billed'], false);
      expect(off.containsKey('include_tax'), isFalse);
    });

    test('is_expense_billed is never sent', () {
      // The server stores it and never reads it again.
      final json = const ReportPayload(
        isExpenseBilled: true,
      ).toJson(reportIdentifier: 'profitloss');
      expect(json.containsKey('is_expense_billed'), isFalse);
    });

    test('report_keys + group_by passed through when set', () {
      final json = const ReportPayload().toJson(
        reportIdentifier: 'clients',
        reportKeys: ['client.name', 'client.balance'],
        groupBy: 'client.country',
      );
      expect(json['report_keys'], ['client.name', 'client.balance']);
      expect(json['group_by'], 'client.country');
    });

    test('send_email is stated on every request, false included', () {
      final json = const ReportPayload(
        sendEmail: true,
      ).toJson(reportIdentifier: 'clients');
      expect(json['send_email'], true);
      // Left out, the server takes it for true (`GenericReportRequest::
      // prepareForValidation`) and emails the report instead of answering —
      // which made opening a file-only report send it to the user's inbox.
      final off = const ReportPayload().toJson(reportIdentifier: 'clients');
      expect(off.containsKey('send_email'), isTrue);
      expect(off['send_email'], false);
    });
  });

  group('ReportPayload equality', () {
    test('two equal-shape payloads compare equal (for isParamDirty)', () {
      const a = ReportPayload(
        datePreset: ReportDatePreset.thisMonth,
        clients: 'x,y',
        includeDeleted: true,
      );
      const b = ReportPayload(
        datePreset: ReportDatePreset.thisMonth,
        clients: 'x,y',
        includeDeleted: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    // H2: a tag-only change must register as a diff, otherwise setPayload's
    // `if (payload == _payload) return;` swallows the tag filter on the
    // Tasks/Projects reports and the report runs unfiltered.
    test('tags participate in equality + hashCode', () {
      expect(
        const ReportPayload(tags: 'a,b'),
        isNot(equals(const ReportPayload(tags: 'c,d'))),
      );
      expect(
        const ReportPayload(tags: 'a,b'),
        isNot(equals(const ReportPayload())),
      );
      expect(
        const ReportPayload(tags: 'a,b').hashCode ==
            const ReportPayload().hashCode,
        isFalse,
      );
    });
  });
}
