import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_kpi_strip.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_overview.dart';
import 'package:admin/ui/features/billing_shared/line_items_readonly_table.dart';
import 'package:admin/ui/core/utils/company_labels.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';

/// Minimal repos so [BillingDocOverview] can watch the active company — it
/// needs it for surcharge labels and for the header's Custom Labels. Anything
/// else throws so the test fails loudly if the widget reaches further.
class _FakeCompanyRepo implements CompanyRepository {
  _FakeCompanyRepo(this._company);
  final Company? _company;

  @override
  Stream<Company?> watchCompany(String companyId) => Stream.value(_company);

  // Cold seed cache: keeps these tests on the async watch path, exactly as
  // before `BaseEntityRepository.peek` existed. The `company is still loading
  // (null)` case below depends on it staying cold.
  @override
  Company? peek({required String companyId, required String id}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeAuth implements AuthRepository {
  @override
  String? get currentCompanyId => 'co-A';

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices(this.company);
  @override
  final CompanyRepository company;
  @override
  final AuthRepository auth = _FakeAuth();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A company whose Custom Labels (`settings.translations`) hold [overrides].
Company _companyWithLabels(Map<String, dynamic> overrides) =>
    Company(settings: CompanySettings(translations: overrides));

/// A USD formatter — exercises the real money/date path so these tests catch
/// the original bug (raw `100` / `2022-02-08`) regressing.
Formatter _usdFormatter() => Formatter(
  settings: CompanyFormatSettings.fallback,
  currencies: {
    '1': Currency(
      id: '1',
      name: 'US Dollar',
      code: 'USD',
      symbol: r'$',
      precision: 2,
      thousandSeparator: ',',
      decimalSeparator: '.',
      swapCurrencySymbol: false,
      exchangeRate: Decimal.one,
    ),
  },
  countries: {
    '840': Country(
      id: '840',
      name: 'United States',
      iso2: 'US',
      iso3: 'USA',
      swapCurrencySymbol: false,
      thousandSeparator: '',
      decimalSeparator: '',
      swapPostalCode: false,
    ),
  },
  dateFormats: {'5': const DatetimeFormat(id: '5', format: 'MMM d, yyyy')},
);

LineItem _item({
  String productKey = 'Widget',
  String notes = 'A nice widget',
  String cost = '50',
  String quantity = '2',
}) => emptyLineItem().copyWith(
  productKey: productKey,
  notes: notes,
  cost: Decimal.parse(cost),
  quantity: Decimal.parse(quantity),
);

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {Company? company}) {
    return tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(_FakeCompanyRepo(company)),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  group('BillingDocKpiStrip', () {
    testWidgets('formats money and renders — for zero', (tester) async {
      await pump(
        tester,
        BillingDocKpiStrip(
          formatter: _usdFormatter(),
          currencyId: '1',
          metrics: [
            BillingMetric(label: 'Amount', amount: Decimal.parse('100')),
            BillingMetric(label: 'Paid', amount: Decimal.zero),
          ],
        ),
      );
      await tester.pump();

      // The original bug rendered the raw decimal "100"; the fix formats it.
      expect(find.text(r'$100.00'), findsOneWidget);
      expect(find.text('100'), findsNothing);
      // Zero collapses to an em dash, matching the KPI-strip convention.
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('BillingDatesCaption', () {
    testWidgets('renders the overdue chip and formats the dates', (
      tester,
    ) async {
      await pump(
        tester,
        BillingDatesCaption(
          formatter: _usdFormatter(),
          issuedLabel: 'Date',
          issued: Date.tryParse('2022-01-07'),
          secondaryLabel: 'Due Date',
          secondary: Date.tryParse('2022-02-08'),
          overduePrefix: 'Overdue',
          overdueDays: 32,
        ),
      );
      await tester.pump();

      expect(find.text('Overdue · 32d'), findsOneWidget);
      // Dates are formatted, never the raw ISO string.
      expect(find.textContaining('2022-02-08'), findsNothing);
      expect(find.textContaining('Feb 8, 2022'), findsOneWidget);
    });
  });

  group('LineItemsReadonlyTable', () {
    testWidgets('renders item, unit cost and gross line total', (tester) async {
      await pump(
        tester,
        LineItemsReadonlyTable(
          items: [_item()],
          formatter: _usdFormatter(),
          currencyId: '1',
        ),
      );
      await tester.pump();

      expect(find.text('Widget'), findsOneWidget);
      expect(find.text(r'$50.00'), findsOneWidget); // unit cost
      expect(find.text(r'$100.00'), findsOneWidget); // gross = 50 × 2
    });

    testWidgets('header uses the shipped labels when the company has none', (
      tester,
    ) async {
      await pump(
        tester,
        LineItemsReadonlyTable(
          items: [_item()],
          formatter: _usdFormatter(),
          currencyId: '1',
        ),
      );
      await tester.pump();

      expect(find.text('Unit Cost'), findsOneWidget);
      expect(find.text('Item'), findsOneWidget);
    });

    testWidgets('header honors the company Custom Labels override', (
      tester,
    ) async {
      await pump(
        tester,
        LineItemsReadonlyTable(
          items: [_item()],
          formatter: _usdFormatter(),
          currencyId: '1',
          labels: CompanyLabels.fromCompany(
            _companyWithLabels(const {'unit_cost': 'Unit Price'}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Unit Price'), findsOneWidget);
      expect(find.text('Unit Cost'), findsNothing);
      // Untouched keys keep the bundled string.
      expect(find.text('Item'), findsOneWidget);
    });

    testWidgets('a blank override falls back to the shipped label', (
      tester,
    ) async {
      // The Custom Labels editor seeds a newly added row with '', and the
      // server coerces nulls to ''. Neither may blank the column header.
      await pump(
        tester,
        LineItemsReadonlyTable(
          items: [_item()],
          formatter: _usdFormatter(),
          currencyId: '1',
          labels: CompanyLabels.fromCompany(
            _companyWithLabels(const {'unit_cost': '', 'item': '   '}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Unit Cost'), findsOneWidget);
      expect(find.text('Item'), findsOneWidget);
    });

    testWidgets('shows an empty placeholder when there are no items', (
      tester,
    ) async {
      await pump(
        tester,
        LineItemsReadonlyTable(
          items: const [],
          formatter: _usdFormatter(),
          currencyId: '1',
        ),
      );
      await tester.pump();

      expect(find.text('No records found'), findsOneWidget);
    });
  });

  group('BillingDocOverview', () {
    testWidgets('renders line items + totals, shows notes, hides empty terms', (
      tester,
    ) async {
      await pump(
        tester,
        SingleChildScrollView(
          child: BillingDocOverview(
            totalsInput: BillingTotalsInput(
              lineItems: [_item()],
              discount: Decimal.zero,
              isAmountDiscount: false,
              usesInclusiveTaxes: false,
            ),
            precision: 2,
            balance: Decimal.parse('100'),
            publicNotes: 'Thanks for your business',
            terms: '',
            formatter: _usdFormatter(),
            currencyId: '1',
            trailing: const [Text('TRAILING_MARKER')],
          ),
        ),
      );
      await tester.pump();

      // Line item + computed total both formatted.
      expect(find.text('Widget'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text(r'$100.00'), findsWidgets);
      // Public notes shown; empty Terms section hidden (not '—').
      expect(find.text('Thanks for your business'), findsOneWidget);
      expect(find.text('Terms'), findsNothing);
      expect(find.text('—'), findsNothing);
      // Trailing (invoice-only reminders/payments slot) renders.
      expect(find.text('TRAILING_MARKER'), findsOneWidget);
    });

    testWidgets('resolves the header Custom Labels off the watched company', (
      tester,
    ) async {
      // The screen-level proof for invoiceninja/flutter#84: the app stored
      // `settings.translations` and never read it back, so a company that had
      // renamed the column still saw "Unit Cost" everywhere but the PDF.
      await pump(
        tester,
        SingleChildScrollView(
          child: BillingDocOverview(
            totalsInput: BillingTotalsInput(
              lineItems: [_item()],
              discount: Decimal.zero,
              isAmountDiscount: false,
              usesInclusiveTaxes: false,
            ),
            precision: 2,
            balance: Decimal.parse('100'),
            publicNotes: '',
            terms: '',
            formatter: _usdFormatter(),
            currencyId: '1',
          ),
        ),
        company: _companyWithLabels(const {'unit_cost': 'Unit Price'}),
      );
      await tester.pump();

      expect(find.text('Unit Price'), findsOneWidget);
      expect(find.text('Unit Cost'), findsNothing);
    });
  });
}
