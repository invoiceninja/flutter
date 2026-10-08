import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/document_source.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';

import '../../../../../_localization_helper.dart';

Invoice _invoice(String id, String number, {String client = 'c1'}) =>
    Invoice.fromApi(
      InvoiceApi.fromJson({
        'id': id,
        'client_id': client,
        'number': number,
        'amount': '10.00',
        'date': '2026-03-04',
        'updated_at': 1,
        'created_at': 1,
      }),
    );

Client _client(String id, String name) => Client.fromApi(
  ClientApi(id: id, name: name, displayName: name, updatedAt: 1),
);

void main() {
  DesignerDocumentController controller({
    List<Invoice>? invoices,
    Future<Client?> Function(String id)? loadClient,
    Object? failWith,
  }) {
    final c = DesignerDocumentController(
      loadRecent: () async {
        if (failWith != null) throw failWith;
        return invoices ??
            [_invoice('b', '0002', client: 'c2'), _invoice('a', '0001')];
      },
      loadClient:
          loadClient ?? (id) async => _client(id, id == 'c1' ? 'One' : 'Two'),
    );
    addTearDown(c.dispose);
    return c;
  }

  group('DesignerDocumentController', () {
    test('starts on the newest invoice, with its client', () async {
      final c = controller();
      expect(c.invoice, isNull, reason: 'the sample until it has loaded');
      await c.load();
      expect(c.invoice!.number, '0002');
      expect(c.client!.name, 'Two');
      expect(c.recent, hasLength(2));
    });

    test('an invoice the server has never seen is not on offer', () async {
      // The preview would ask for an id that is a 400.
      final c = controller(
        invoices: [_invoice('tmp_9', ''), _invoice('a', '0001')],
      );
      await c.load();
      expect([for (final i in c.recent) i.id], ['a']);
      expect(c.invoice!.id, 'a');
    });

    test('no invoices, or a failed load, leaves the sample', () async {
      final empty = controller(invoices: const []);
      await empty.load();
      expect(empty.invoice, isNull);
      final failed = controller(failWith: StateError('db closed'));
      await failed.load();
      expect(failed.invoice, isNull);
      expect(failed.recent, isEmpty);
    });

    test('choosing the sample, and an invoice again', () async {
      final c = controller();
      await c.load();
      var notified = 0;
      c.addListener(() => notified++);
      await c.showInvoice(null);
      expect(c.invoice, isNull);
      expect(c.client, isNull);
      await c.showInvoice('a');
      expect(c.invoice!.number, '0001');
      expect(c.client!.name, 'One');
      expect(notified, 2);
    });

    test('a later choice wins over a client that was slow to load', () async {
      final slow = Completer<Client?>();
      final c = controller(
        loadClient: (id) =>
            id == 'c2' ? slow.future : Future.value(_client(id, 'One')),
      );
      final first = c.load(); // newest → c2, slow
      await Future<void>.delayed(Duration.zero);
      await c.showInvoice('a');
      slow.complete(_client('c2', 'Two'));
      await first;
      expect(c.invoice!.id, 'a');
      expect(c.client!.name, 'One');
    });

    test('a client that cannot be loaded still shows the invoice', () async {
      final c = controller(loadClient: (_) async => throw StateError('gone'));
      await c.load();
      expect(c.invoice!.number, '0002');
      expect(c.client, isNull);
    });

    test('the page\'s document: the sample, or the invoice over it', () async {
      final c = controller();
      final base = DesignerSampleData.fallback;
      expect(identical(c.documentOver(base), base), isTrue);
      await c.load();
      final real = c.documentOver(base);
      expect(real.invoice.number, '0002');
      expect(real.client.name, 'Two');
      expect(identical(real.company, base.company), isTrue);
    });
  });

  group('DesignerDocumentButton', () {
    Future<void> pump(WidgetTester tester, DesignerDocumentController c) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          locale: const Locale('en'),
          theme: buildInTheme(InTheme.light),
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox()),
                DesignerDocumentBar(controller: c),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('with no invoices there is nothing to choose, so no bar', (
      tester,
    ) async {
      final c = controller(invoices: const []);
      await c.load();
      await pump(tester, c);
      expect(find.text('Showing'), findsNothing);
      expect(tester.getSize(find.byType(DesignerDocumentBar)).height, 0);
    });

    testWidgets('names the invoice shown; the menu changes it', (tester) async {
      final c = controller();
      await c.load();
      await pump(tester, c);
      expect(find.text('Showing'), findsOneWidget);
      expect(find.text('Invoice 0002'), findsOneWidget);

      await tester.tap(find.text('Invoice 0002'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invoice 0001'));
      await tester.pumpAndSettle();
      expect(c.invoice!.id, 'a');
      expect(find.text('Invoice 0001'), findsOneWidget);

      await tester.tap(find.text('Invoice 0001'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sample document'));
      await tester.pumpAndSettle();
      expect(c.invoice, isNull);
      // Still there: it is the way back to a real one.
      expect(find.text('Sample document'), findsOneWidget);
    });

    testWidgets('dismissing the menu changes nothing', (tester) async {
      final c = controller();
      await c.load();
      await pump(tester, c);
      await tester.tap(find.text('Invoice 0002'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(700, 20));
      await tester.pumpAndSettle();
      expect(c.invoice!.id, 'b');
    });
  });
}
