import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/services.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_actions.dart';

import '../../shell/_shell_test_helpers.dart';

/// `InvoiceActions.cardPaymentsSettled` — the check every way of recording a
/// payment by hand goes through (Mark Paid, Enter Payment, bulk Mark Paid, a
/// new payment's Save) while a card payment this device took on the invoice
/// is still unanswered (docs/in-person-payments.md).
void main() {
  /// Pumps a button that runs the check for [invoiceIds]; returns a getter
  /// for its answer (null until it has one).
  Future<bool? Function()> pumpCheck(
    WidgetTester tester,
    Services services,
    List<String> invoiceIds,
  ) async {
    bool? answer;
    await tester.pumpWidget(
      wrapWithShell(
        services,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              answer = await InvoiceActions.cardPaymentsSettled(
                context,
                services,
                'co1',
                invoiceIds,
              );
            },
            child: const Text('check'),
          ),
        ),
      ),
    );
    return () => answer;
  }

  testWidgets('nothing pending: no question', (tester) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    final answer = await pumpCheck(tester, fixture.services, ['inv1']);
    await tester.tap(find.text('check'));
    await tester.pumpAndSettle();
    expect(answer(), isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('an unanswered charge warns once, then lets the user go on', (
    tester,
  ) async {
    // The fixture's client fails fast: the server can't be asked.
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    final terminal = fixture.services.terminal;
    await terminal.notePending(
      companyId: 'co1',
      invoiceId: 'inv1',
      paymentIntentId: 'pi_1',
    );
    final answer = await pumpCheck(tester, fixture.services, ['inv1', 'inv2']);

    await tester.tap(find.text('check'));
    await tester.pumpAndSettle();
    // The title, and the confirm button restating it.
    expect(find.text('A card payment is still being checked'), findsWidgets);
    await tester.tap(find.byType(PrimaryDialogAction));
    await tester.pumpAndSettle();
    expect(answer(), isTrue);
    expect(terminal.pendingFor('co1', 'inv1'), 'pi_1');

    // The same charge, asked again (Enter Payment, then its Save): no
    // second warning.
    await tester.tap(find.text('check'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(answer(), isTrue);
  });

  testWidgets('a charge that turns out to have been recorded stops the '
      'action and says so', (tester) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Co')],
      online: true,
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/terminal/payment_intents/pi_1/complete')) {
          return http.Response(
            jsonEncode({
              'status': 'recorded',
              'payment_id': '',
              'applied': 100,
              'unapplied': 0,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        throw http.ClientException('offline (test)');
      }),
    );
    addTearDown(fixture.dispose);
    final terminal = fixture.services.terminal;
    await terminal.notePending(
      companyId: 'co1',
      invoiceId: 'inv1',
      paymentIntentId: 'pi_1',
    );
    final answer = await pumpCheck(tester, fixture.services, ['inv1']);

    await tester.runAsync(() async {
      await tester.tap(find.text('check'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('The card payment went through'), findsOneWidget);
    await tester.tap(find.byType(PrimaryDialogAction));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(answer(), isFalse);
    expect(terminal.pendingFor('co1', 'inv1'), isNull);
  });
}
