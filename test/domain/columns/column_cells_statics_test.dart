import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/payment_type.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/domain/columns/column_cells.dart';

import '../../_localization_helper.dart';

class _FakeStatics implements StaticsRepository {
  _FakeStatics({required this.currencies, required this.paymentTypes});
  @override
  final Map<String, Currency> currencies;
  @override
  final Map<String, PaymentType> paymentTypes;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices(this.statics);
  @override
  final StaticsRepository statics;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _FakeServices services;

  setUp(() {
    services = _FakeServices(
      _FakeStatics(
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
        paymentTypes: const {'1': PaymentType(id: '1', name: 'Credit Card')},
      ),
    );
  });

  Future<void> pumpCell(
    WidgetTester tester,
    Widget Function(BuildContext) build,
  ) async {
    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: Builder(builder: (ctx) => Center(child: build(ctx))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cellCurrency resolves a currency id to its ISO code', (
    tester,
  ) async {
    await pumpCell(tester, (ctx) => cellCurrency(ctx, '1'));
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('cellCurrency falls back to the raw id when unknown', (
    tester,
  ) async {
    await pumpCell(tester, (ctx) => cellCurrency(ctx, '999'));
    expect(find.text('999'), findsOneWidget);
  });

  testWidgets('cellPaymentType resolves a type id to its name', (tester) async {
    await pumpCell(tester, (ctx) => cellPaymentType(ctx, '1'));
    expect(find.text('Credit Card'), findsOneWidget);
  });

  testWidgets('cellPaymentType falls back to the raw id when unknown', (
    tester,
  ) async {
    await pumpCell(tester, (ctx) => cellPaymentType(ctx, '999'));
    expect(find.text('999'), findsOneWidget);
  });
}
