import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/payments_api.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_edit_layout.dart';
import '../../../_localization_helper.dart';

class _FakePaymentsApi implements PaymentsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeStatics implements StaticsRepository {
  @override
  Map<String, Currency> get currencies => {
    '2': Currency(
      id: '2',
      name: 'British Pound',
      code: 'GBP',
      symbol: '£',
      precision: 2,
      thousandSeparator: ',',
      decimalSeparator: '.',
      swapCurrencySymbol: false,
      exchangeRate: Decimal.parse('0.8'),
    ),
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeCompanyRepo implements CompanyRepository {
  _FakeCompanyRepo(this.company);
  final Company company;

  @override
  Stream<Company?> watchCompany(String companyId) => Stream.value(company);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices(this.company);
  @override
  final CompanyRepository company;
  @override
  final StaticsRepository statics = _FakeStatics();
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<PaymentEditViewModel> pump(
    WidgetTester tester, {
    Payment? existing,
    bool convertPaymentCurrency = false,
  }) async {
    final vm = PaymentEditViewModel(
      repo: PaymentRepository(db: db, api: _FakePaymentsApi()),
      companyId: 'co',
      existing: existing,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(
          _FakeCompanyRepo(
            Company(id: 'co', convertPaymentCurrency: convertPaymentCurrency),
          ),
        ),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: vm,
                builder: (context, _) =>
                    PaymentCurrencyConversionSection(vm: vm, formatter: null),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return vm;
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  String textOf(WidgetTester tester, String label) =>
      tester.widget<TextFormField>(field(label)).controller!.text;

  Future<void> turnOn(WidgetTester tester) async {
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
  }

  // Beta feedback: the converted amount was read-only, so the bank's settled
  // figure had to be turned into a rate by hand. React and v1 both take it.
  testWidgets('typing the converted amount sets the rate', (tester) async {
    final vm = await pump(tester);
    vm.setAmount('300');
    await turnOn(tester);

    await tester.enterText(field('Converted Amount'), '265.50');
    await tester.pump();

    expect(vm.draft.exchangeRate, Decimal.parse('0.885'));
    expect(textOf(tester, 'Exchange Rate'), '0.885');
    // What was typed stays put while the field has focus.
    expect(textOf(tester, 'Converted Amount'), '265.50');
  });

  testWidgets('typing the rate updates the converted amount', (tester) async {
    final vm = await pump(tester);
    vm.setAmount('200');
    await turnOn(tester);

    await tester.enterText(field('Exchange Rate'), '1.25');
    await tester.pump();

    expect(textOf(tester, 'Converted Amount'), '250');
  });

  testWidgets('nothing converted yet reads blank, not the plain amount', (
    tester,
  ) async {
    final vm = await pump(tester);
    vm.setAmount('265.50');
    await turnOn(tester);

    expect(textOf(tester, 'Converted Amount'), '');
  });

  testWidgets('the converted amount is closed while the amount is zero', (
    tester,
  ) async {
    await pump(tester);
    await turnOn(tester);

    expect(
      tester.widget<TextFormField>(field('Converted Amount')).enabled,
      isFalse,
    );
  });

  // Settings → Online Payments → Convert currency: "Set an exchange rate when
  // entering a manual payment". v1 opened the section for it; this app had
  // the setting but never read it.
  testWidgets('the company setting opens the section on a new payment', (
    tester,
  ) async {
    await pump(tester, convertPaymentCurrency: true);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(field('Converted Amount'), findsOneWidget);
  });

  testWidgets('off by default, with the setting off', (tester) async {
    await pump(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(field('Converted Amount'), findsNothing);
  });
}
