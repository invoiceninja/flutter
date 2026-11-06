import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_preview.dart';

import '_report_screen_harness.dart';

ReportPreview _payments() => ReportPreview(
  columns: [
    reportTestColumn('client.name', 'Client Name'),
    reportTestColumn('payment.number', 'Payment Number'),
    reportTestColumn('payment.amount', 'Payment Amount'),
  ],
  rows: [
    for (var i = 0; i < 3; i++)
      ReportRow(
        cells: [
          ReportStringCell(value: 'Client $i', displayValue: 'Client $i'),
          ReportStringCell(value: '000$i', displayValue: '000$i'),
          ReportNumberCell(value: Decimal.fromInt(10 * (i + 1)), isMoney: true),
        ],
      ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadReportTestFonts);

  testWidgets('the column picker adds a client field to the payment report', (
    tester,
  ) async {
    final h = await pumpReports(
      tester,
      preview: _payments(),
      location: '/reports/payment',
    );
    await tester.tap(find.byKey(const Key('report-columns')));
    await tester.pumpAndSettle();

    expect(find.text('More Fields'), findsOneWidget);
    final city = find.byKey(const ValueKey('add:client.city'));
    await tester.ensureVisible(city);
    await tester.pumpAndSettle();
    await tester.tap(city);
    await tester.pump();
    await tester.tap(find.text('Done'));
    await settleReports(tester);

    expect(h.vm.addedColumnIds, ['client.city']);
    expect(
      h.repo.requests.last,
      containsAllInOrder([
        'client.name',
        'payment.number',
        'payment.amount',
        'client.city',
      ]),
    );
  }, variant: kDesktop);

  testWidgets('search reaches the related fields too', (tester) async {
    await pumpReports(
      tester,
      preview: _payments(),
      location: '/reports/payment',
    );
    await tester.tap(find.byKey(const Key('report-columns')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      'vat',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('add:client.vat_number')), findsOneWidget);
    expect(find.byKey(const ValueKey('add:client.city')), findsNothing);
  }, variant: kDesktop);
}
