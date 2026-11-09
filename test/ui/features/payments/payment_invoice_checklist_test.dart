import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_allocations_section.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_invoice_checklist.dart';
import '../../../_localization_helper.dart';

// Beta feedback: an agency billed one invoice per end client and paid them in
// a batch; adding each through its own picker row was the slow part, and
// React's create screen had a ticked table for it.

AllocationTarget _target(String id, num balance, {num partial = 0}) =>
    AllocationTarget(
      id: id,
      number: id.toUpperCase(),
      balance: Decimal.parse('$balance'),
      partial: Decimal.parse('$partial'),
    );

Paymentable _inv(String id, num amount) => Paymentable(
  invoiceId: id,
  amount: Decimal.parse('$amount'),
  refunded: Decimal.zero,
);

Paymentable _cre(String id, num amount) => Paymentable(
  creditId: id,
  amount: Decimal.parse('$amount'),
  refunded: Decimal.zero,
);

class _FakeAuth implements AuthRepository {
  @override
  String? get currentCompanyId => 'co';
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeInvoices implements InvoiceRepository {
  _FakeInvoices(this.open);
  final List<(String, int)> open;

  @override
  Stream<List<Invoice>> watchForClient({
    required String companyId,
    required String clientId,
  }) => Stream.value([
    for (final (id, balance) in open)
      Invoice.fromApi(
        InvoiceApi(
          id: id,
          number: id.toUpperCase(),
          clientId: 'c1',
          statusId: '2',
          amount: balance.toDouble(),
          balance: balance.toDouble(),
        ),
      ),
  ]);
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices([
    List<(String, int)> open = const [('i1', 100), ('i2', 250), ('i3', 40)],
  ]) : invoices = _FakeInvoices(open);
  @override
  final AuthRepository auth = _FakeAuth();
  @override
  final InvoiceRepository invoices;
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _app(Widget home) => MaterialApp(
  theme: buildInTheme(InTheme.light),
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: kTestSupportedLocales,
  home: Scaffold(body: home),
);

void main() {
  group('applyInvoiceSelection', () {
    final targets = [_target('i1', 100), _target('i2', 250), _target('i3', 40)];

    test('appends the ticked invoices in full while the amount is open', () {
      final next = applyInvoiceSelection(
        paymentables: const [],
        targets: targets,
        selected: {'i1', 'i3'},
        paymentAmount: Decimal.zero,
      );
      expect(next.map((p) => (p.invoiceId, p.amount.toString())), [
        ('i1', '100'),
        ('i3', '40'),
      ]);
    });

    test('a kept row keeps its amount and place; an unticked one goes', () {
      final next = applyInvoiceSelection(
        paymentables: [_inv('i2', 60), _inv('i1', 100)],
        targets: targets,
        selected: {'i2', 'i3'},
        paymentAmount: Decimal.zero,
      );
      expect(next.map((p) => (p.invoiceId, p.amount.toString())), [
        ('i2', '60'),
        ('i3', '40'),
      ]);
    });

    test('credits, and invoices the list does not offer, are untouched', () {
      final next = applyInvoiceSelection(
        paymentables: [_cre('c1', 20), _inv('paid_off', 75), _inv('i1', 100)],
        targets: targets,
        selected: const {},
        paymentAmount: Decimal.zero,
      );
      expect(next.map((p) => p.creditId.isEmpty ? p.invoiceId : p.creditId), [
        'c1',
        'paid_off',
      ]);
    });

    test('a fixed amount caps the new rows like the row picker does', () {
      final next = applyInvoiceSelection(
        paymentables: const [],
        targets: targets,
        selected: {'i1', 'i2', 'i3'},
        paymentAmount: Decimal.parse('300'),
      );
      // i3 would get nothing, and the server refuses a zero allocation on a
      // sent invoice ("Amount cannot be less than or equal to zero").
      expect(next.map((p) => (p.invoiceId, p.amount.toString())), [
        ('i1', '100'),
        ('i2', '200'),
      ]);
    });

    test('new rows go in the order they were ticked', () {
      final next = applyInvoiceSelection(
        paymentables: const [],
        targets: targets,
        selected: {'i3', 'i1'},
        paymentAmount: Decimal.parse('120'),
      );
      // i3 was ticked first, so it is paid in full and i1 takes the rest.
      expect(next.map((p) => (p.invoiceId, p.amount.toString())), [
        ('i3', '40'),
        ('i1', '80'),
      ]);
    });

    test('a partial is what a new row starts at', () {
      final next = applyInvoiceSelection(
        paymentables: const [],
        targets: [_target('i1', 100, partial: 30)],
        selected: {'i1'},
        paymentAmount: Decimal.zero,
      );
      expect(next.single.amount, Decimal.parse('30'));
    });
  });

  group('the dialog', () {
    /// Opens the dialog; [_Result.value] holds what it returned once closed.
    Future<_Result> open(
      WidgetTester tester, {
      List<AllocationTarget>? targets,
      Set<String> selected = const {},
      Map<String, Decimal> existing = const {},
      num paymentAmount = 0,
      num otherAllocated = 0,
    }) async {
      final result = _Result();
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result.value = await showInvoiceChecklistDialog(
                  context,
                  targets: targets ?? [_target('i1', 100), _target('i2', 250)],
                  selected: selected,
                  existingAmounts: existing,
                  paymentAmount: Decimal.parse('$paymentAmount'),
                  otherAllocated: Decimal.parse('$otherAllocated'),
                );
                result.closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('lists each invoice with its amount, ticked as allocated', (
      tester,
    ) async {
      await open(tester, selected: {'i2'});

      expect(find.text('#I1'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('250'), findsWidgets);
      final i1 = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('invoice_checklist_i1')),
      );
      final i2 = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('invoice_checklist_i2')),
      );
      expect(i1.value, isFalse);
      expect(i2.value, isTrue);
      // Select All is mixed while some, not all, are ticked.
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .value,
        isNull,
      );
    });

    testWidgets('Select All ticks every row, then clears them', (tester) async {
      await open(tester);
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('Total  350'), findsOneWidget);

      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
    });

    testWidgets('with a fixed amount, shows what the ticks leave unapplied', (
      tester,
    ) async {
      await open(tester, paymentAmount: 300);
      expect(find.text('Amount received'), findsOneWidget);
      // Received and unapplied, while nothing is ticked.
      expect(find.text('300'), findsNWidgets(2));

      await tester.tap(find.text('#I1'));
      await tester.pumpAndSettle();
      expect(find.text('200'), findsOneWidget); // unapplied

      await tester.tap(find.text('#I2'));
      await tester.pumpAndSettle();
      // Used up — i2 will be part-paid, never over-applied.
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('a kept row counts at its allocated amount', (tester) async {
      await open(
        tester,
        selected: {'i2'},
        existing: {'i2': Decimal.parse('60')},
      );
      expect(find.text('Total  60'), findsOneWidget);
    });

    testWidgets('once the amount received is used up, no more can be ticked', (
      tester,
    ) async {
      await open(
        tester,
        targets: [_target('i1', 100), _target('i2', 250), _target('i3', 40)],
        paymentAmount: 300,
      );
      await tester.tap(find.text('#I1'));
      await tester.tap(find.text('#I2'));
      await tester.pumpAndSettle();

      CheckboxListTile row(String id) => tester.widget<CheckboxListTile>(
        find.byKey(ValueKey('invoice_checklist_$id')),
      );
      // i2 is part-paid; nothing is left for i3.
      expect(row('i3').enabled, isFalse);
      expect(row('i2').enabled, isTrue); // a ticked row can still be unticked

      await tester.tap(find.text('#I2'));
      await tester.pumpAndSettle();
      expect(row('i3').enabled, isTrue);
    });

    // Review finding: an allocation the list doesn't offer (an invoice paid
    // off since, on an existing payment) still uses up the amount received —
    // Apply counts it — so the room left and Unapplied must count it too.
    testWidgets('allocations the list doesn\'t show use up the amount too', (
      tester,
    ) async {
      await open(
        tester,
        targets: [_target('i1', 100), _target('i2', 250)],
        paymentAmount: 300,
        otherAllocated: 250,
      );
      expect(find.text('50'), findsOneWidget); // unapplied: 300 - 250

      await tester.tap(find.text('#I1'));
      await tester.pumpAndSettle();
      final i2 = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('invoice_checklist_i2')),
      );
      expect(i2.enabled, isFalse);
    });

    testWidgets('with an amount fixed, Select All fills it, then clears', (
      tester,
    ) async {
      await open(
        tester,
        targets: [_target('i1', 100), _target('i2', 250), _target('i3', 40)],
        paymentAmount: 300,
      );
      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      // i1 + i2 cover the 300; i3 would get nothing.
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
    });

    testWidgets('Enter on a row applies, rather than toggling it', (
      tester,
    ) async {
      final result = await open(tester);
      await tester.tap(find.text('#I1'));
      await tester.pumpAndSettle();
      // Keyboard focus on the row itself (Tab gets there too), where Enter
      // would otherwise activate — toggle — the tile.
      final rowFocus = Focus.of(tester.element(find.text('#I1')));
      rowFocus.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, rowFocus);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(result.closed, isTrue);
      expect(result.value, {'i1'});
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a long list can be filtered, and Select All follows it', (
      tester,
    ) async {
      await open(
        tester,
        targets: [
          for (var i = 1; i <= kInvoiceChecklistFilterThreshold + 1; i++)
            _target('i$i', i * 10),
        ],
      );
      await tester.enterText(find.byType(TextField), '#I7');
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(2)); // all + one

      await tester.tap(find.text('Select All'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('no filter field for a short list', (tester) async {
      await open(tester);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Apply returns the ticks; Cancel returns nothing', (
      tester,
    ) async {
      var result = await open(tester, selected: {'i2'});
      await tester.tap(find.text('#I1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result.closed, isTrue);
      expect(result.value, {'i1', 'i2'});

      result = await open(tester);
      await tester.tap(find.text('#I1'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result.closed, isTrue);
      expect(result.value, isNull);
    });
  });

  group('in the Invoices section', () {
    Future<List<Paymentable>?> Function() pump(
      WidgetTester tester, {
      required Size size,
      List<Paymentable> paymentables = const [],
    }) {
      return () async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        List<Paymentable>? changed;
        await tester.pumpWidget(
          Provider<Services>.value(
            value: _FakeServices(),
            child: _app(
              SingleChildScrollView(
                child: PaymentAllocationsSection(
                  kind: AllocationKind.invoice,
                  paymentables: paymentables,
                  clientId: 'c1',
                  paymentAmount: Decimal.zero,
                  onChanged: (next) => changed = next,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Select Invoices'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('#I1'));
        await tester.tap(find.text('#I3'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        return changed;
      };
    }

    for (final (name, size) in [
      ('wide', const Size(1400, 900)),
      ('phone', const Size(390, 844)),
    ]) {
      testWidgets('$name: the ticked invoices become allocations', (
        tester,
      ) async {
        final changed = await pump(tester, size: size)();
        expect(changed!.map((p) => (p.invoiceId, p.amount.toString())), [
          ('i1', '100'),
          ('i3', '40'),
        ]);
      });
    }

    testWidgets('one open invoice is just the picker — no checklist', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Provider<Services>.value(
          value: _FakeServices(const [('i1', 100)]),
          child: _app(
            PaymentAllocationsSection(
              kind: AllocationKind.invoice,
              paymentables: const [],
              clientId: 'c1',
              paymentAmount: Decimal.zero,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Select Invoices'), findsNothing);
    });
  });
}

class _Result {
  bool closed = false;
  Set<String>? value;
}
