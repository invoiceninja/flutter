import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_cards_grid.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_details_card.dart';

import '../../../_responsive_helper.dart';

/// `ClientDetailCardsGrid` keeps a wholly-empty Details card in the wide
/// 3-column grid (so the columns stay aligned — no gap) but drops it from the
/// stacked single-column layout (mobile / master-detail sidebar preview).

Client _client({String phone = ''}) => Client.fromApi(
  ClientApi(id: 'c1', name: 'Acme', phone: phone, updatedAt: 1),
);

// `phoneActions: true` — the Details card's phone row is a tap-to-call link
// now, and `PhoneActionsScope` reads `Provider<Services>`.
Future<void> _pump(WidgetTester tester, Client client, double width) => pumpAt(
  tester,
  width,
  ClientDetailCardsGrid(client: client, formatter: null),
  phoneActions: true,
);

void main() {
  group('ClientDetailCardsGrid', () {
    testWidgets('empty Details card is dropped in the stacked layout', (
      tester,
    ) async {
      await _pump(tester, _client(), 500);
      expect(find.byType(ClientDetailDetailsCard), findsNothing);
    });

    testWidgets('empty Details card is kept in the wide grid (no gap)', (
      tester,
    ) async {
      await _pump(tester, _client(), 1200);
      expect(find.byType(ClientDetailDetailsCard), findsOneWidget);
    });

    testWidgets('Details card with a value is shown in the stacked layout', (
      tester,
    ) async {
      await _pump(tester, _client(phone: '555-1234'), 500);
      expect(find.byType(ClientDetailDetailsCard), findsOneWidget);
    });

    testWidgets(
      'stacked layout omits blank standard rows (label hidden), keeps the '
      'populated one',
      (tester) async {
        await _pump(tester, _client(phone: '555-1234'), 500);
        expect(find.text('Phone'), findsOneWidget);
        expect(find.text('555-1234'), findsOneWidget);
        // Website / VAT Number / ID Number are blank → no label, no dash.
        expect(find.text('Website'), findsNothing);
        expect(find.text('VAT Number'), findsNothing);
        expect(find.text('ID Number'), findsNothing);
        expect(find.text('—'), findsNothing);
      },
    );

    testWidgets('wide grid also hides blank standard rows (no dash)', (
      tester,
    ) async {
      await _pump(tester, _client(phone: '555-1234'), 1200);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('555-1234'), findsOneWidget);
      // Website / VAT Number / ID Number are blank → no label, no dash, even in
      // the wide multi-column layout (previously a dimmed `—` filled each).
      expect(find.text('Website'), findsNothing);
      expect(find.text('VAT Number'), findsNothing);
      expect(find.text('ID Number'), findsNothing);
      expect(find.text('—'), findsNothing);
    });

    testWidgets(
      'two-column grid engages at 1050px (below the old 1100 breakpoint)',
      (tester) async {
        // Regression lock for Breakpoints.entityFormMultiColumn (1000): a
        // full-width pane on a ~1280px window (~1048px content) must render
        // the wide grid — keeping the empty Details card — not the stretched
        // single column. Under the old 1100 threshold this width stacked and
        // dropped the empty card.
        await _pump(tester, _client(), 1050);
        expect(find.byType(ClientDetailDetailsCard), findsOneWidget);
      },
    );
  });
}
