import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_list_tile.dart';

import '../../shell/_shell_test_helpers.dart';

/// invoiceninja/flutter#128 — tapping the client name on a narrow invoice row
/// opened the **client** instead of the invoice.
///
/// The client name was a `ClientNameLabel(link: true)`, i.e. a `LinkText` whose
/// `GestureDetector` is `HitTestBehavior.opaque` sitting *inside* the row's own
/// `InkWell`. The innermost recognizer wins the arena, so the row's
/// "open this record" tap never fired — and on touch there was no hover
/// underline to warn anyone, so the name looked like ordinary muted subtitle
/// text. Testers read it as an intermittent bug; one never managed to open an
/// invoice at all.
///
/// This asserts the composition, not the tile's internals: a tap that lands on
/// the rendered client name must reach the row's `onTap`. Pre-fix it reaches
/// `goEntityFullDetail` instead (and, with no `GoRouter` above this tree,
/// throws) — so the test genuinely fails against the old source.
void main() {
  testWidgets('tapping the client name opens the invoice, not the client', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await fixture.services.clients.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: const ClientApi(id: 'c1', name: 'Acme Corp'),
    );

    var rowTaps = 0;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        InvoiceListTile(
          invoice: emptyInvoice().copyWith(
            id: 'inv1',
            number: '0012',
            clientId: 'c1',
          ),
          columns: const [],
          wide: false,
          onTap: () => rowTaps++,
        ),
      ),
    );
    // A single pump, never `pumpAndSettle` — the fixture keeps timers pending.
    await tester.pump();

    expect(
      find.text('Acme Corp'),
      findsOneWidget,
      reason: 'the name must still render; only the link is gone',
    );
    expect(
      find.byType(LinkText),
      findsNothing,
      reason: 'a nested LinkText would steal the row tap',
    );

    await tester.tap(find.text('Acme Corp'));
    await tester.pump();
    expect(rowTaps, 1, reason: 'the tap must reach the row, not the client');

    // And the rest of the row still behaves, so the fix did not simply make
    // the identity block inert.
    await tester.tap(find.text('#0012'));
    await tester.pump();
    expect(rowTaps, 2);
  });
}
