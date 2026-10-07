// The payment-link record screen, assembled — the record layout end to end
// against a real `Services` graph and a real local database, with the network
// played by a `MockClient`. The harness is
// `test/_support/record_screen_harness.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/models/api/subscription_api_model.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/payment_links/views/payment_link_detail_screen.dart';
import 'package:admin/ui/features/payment_links/widgets/detail/payment_link_detail_header.dart';
import 'package:admin/ui/features/payment_links/widgets/payment_link_actions.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

import '../../../_support/record_screen_harness.dart';
import '../shell/_shell_test_helpers.dart';

const _url = 'https://billing.example.com/client/subscriptions/abc/purchase';

/// A $49 monthly plan with a promo code and a two-week trial.
SubscriptionApi _link({
  String id = 's1',
  bool recurring = true,
  String purchasePage = _url,
  bool isDeleted = false,
  int archivedAt = 0,
}) => SubscriptionApi.fromJson({
  'id': id,
  'name': 'Pro plan',
  'price': '49.00',
  'frequency_id': recurring ? '5' : '',
  'auto_bill': recurring ? 'always' : '',
  'remaining_cycles': -1,
  'promo_code': recurring ? 'LAUNCH20' : '',
  'promo_discount': recurring ? '20' : '0',
  'is_amount_discount': false,
  'trial_enabled': recurring,
  'trial_duration': recurring ? 1209600 : 0,
  'purchase_page': purchasePage,
  'is_deleted': isDeleted,
  'archived_at': archivedAt,
  'updated_at': 1710000000,
  'created_at': 1700000000,
});

const _links = '/api/v1/subscriptions';

/// Records every request, and answers the payment-link list with nothing new.
class _Server {
  final List<Uri> requests = [];

  Iterable<Uri> get listAsks => requests.where((u) => u.path == _links);

  http.Client get client => MockClient((request) async {
    requests.add(request.url);
    if (request.method == 'GET' && request.url.path == _links) {
      return jsonOk({'data': <Object>[]});
    }
    throw http.ClientException('offline (test fixture)');
  });
}

/// The payment-link screen over a link seeded into the local database.
void _screenTest(
  String description,
  SubscriptionApi link,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  _Server? server,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
}) => recordScreenTest(
  description,
  seed: (services) => services.paymentLinks.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: link,
  ),
  screen: () => PaymentLinkDetailScreen(id: link.id),
  ready: () => find.byType(StandingCard),
  body: body,
  httpClient: server?.client,
  company: company,
);

Finder _tiles() => find.byType(EntityQuickActions<PaymentLinkAction>);

/// A quick-action tile, by its short label.
Finder _tile(String label) =>
    find.descendant(of: _tiles(), matching: find.text(label));

/// Text on the standing card. Scoped, because the fixed bar's compact title
/// repeats the price (it is in the tree, faded out, until the header scrolls
/// away).
Finder _standing(String text) =>
    find.descendant(of: find.byType(StandingCard), matching: find.text(text));

Finder _header(String text) => find.descendant(
  of: find.byType(PaymentLinkDetailHeader),
  matching: find.text(text),
);

void main() {
  _screenTest(
    'an active link: identity, actions, the price, and the profile',
    _link(),
    (tester, screen) async {
      expect(_header('Pro plan'), findsOneWidget);
      // How often it bills, under the name.
      expect(_header('Monthly'), findsOneWidget);

      expect(_tile('Copy Link'), findsOneWidget);
      expect(_tile('Open'), findsOneWidget);

      expect(_standing('PRICE'), findsOneWidget);
      expect(_standing(r'$49.00'), findsOneWidget);

      // The profile is simply there — including what the old card left for
      // the edit screen to show.
      expect(find.text('Purchase Page'), findsOneWidget);
      expect(find.text(_url), findsOneWidget);
      expect(find.text('Remaining Cycles'), findsOneWidget);
      expect(find.text('Endless'), findsOneWidget);
      expect(find.text('LAUNCH20'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('14 Days'), findsOneWidget);

      // A settings page like any other: centred and capped.
      expect(find.byType(SettingsFormShell), findsOneWidget);
    },
  );

  _screenTest(
    'a one-off link says Once, and has no rows for settings it does not use',
    _link(recurring: false),
    (tester, screen) async {
      expect(_header('Once'), findsOneWidget);
      // Cycles only mean something on a link that repeats.
      expect(find.text('Remaining Cycles'), findsNothing);
      expect(find.text('Promo Discount'), findsNothing);
      expect(find.text('Trial Duration'), findsNothing);
    },
  );

  _screenTest(
    'the Copy Link tile copies the purchase page, not the link to this screen',
    _link(),
    (tester, screen) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      try {
        await tester.tap(_tile('Copy Link'));
        await screen.until(() => copied != null, 'the copy');
        expect(copied, _url);
        // Past the confirmation toast's own timer, which the binding checks.
        await tester.pump(const Duration(seconds: 10));
      } finally {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      }
    },
  );

  _screenTest(
    'a link with no purchase page yet has nothing to copy or open',
    _link(purchasePage: ''),
    (tester, screen) async {
      expect(_tile('Copy Link'), findsNothing);
      expect(_tile('Open'), findsNothing);
      expect(find.text('Purchase Page'), findsNothing);
    },
  );

  _screenTest(
    'a deleted link is read-only, and says so once',
    _link(isDeleted: true),
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // The banner says it; the header pill would be the same word again.
      expect(find.text('Deleted'), findsNothing);
      expect(_tile('Copy Link'), findsNothing);
    },
  );

  _screenTest(
    'an archived link says so and keeps its actions',
    _link(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // Archived is not read-only.
      expect(_tile('Copy Link'), findsOneWidget);
    },
  );

  _screenTest(
    'a user who may not edit payment links gets the banner without Restore',
    _link(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      // Handing the page to a customer is still theirs to do.
      expect(_tile('Copy Link'), findsOneWidget);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_invoice',
    ),
  );

  _screenTest(
    'an unsynced link gets the sync banner and no tiles',
    _link(id: 'tmp_1'),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
      expect(_tile('Copy Link'), findsNothing);
    },
  );

  final server = _Server();
  _screenTest(
    'opening asks for no payment link; R refreshes them, with nothing '
    'clicked first',
    _link(),
    (tester, screen) async {
      // Past the quiet re-check: payment links are bundled reference data,
      // and there is no by-id fetch for it to make.
      await screen.quiet();
      expect(server.listAsks, isEmpty);

      expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isTrue);
      await screen.until(() => server.listAsks.isNotEmpty, 'the refresh');
    },
    server: server,
  );
}
