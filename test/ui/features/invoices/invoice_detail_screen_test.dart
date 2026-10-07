// The invoice record screen, assembled — the record layout end to end against
// a real `Services` graph and a real local database, with the network played
// by a `MockClient`. The harness is `test/_support/record_screen_harness.dart`.
//
// The invoice is the reference for the five billing documents: everything
// they share (`billing_shared/detail/`) is exercised here, and each of the
// other four has a shorter test for what is its own.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/core/widgets/party_contact_row.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_notes.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_profile.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_record_header.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_standing.dart';
import 'package:admin/ui/features/billing_shared/history/versioned_pdf_pane.dart';
import 'package:admin/ui/features/invoices/views/invoice_detail_screen.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_actions.dart';

import '../../../_support/record_screen_harness.dart';
import '../billing_shared/detail/_billing_doc_fixtures.dart';
import '../shell/_shell_test_helpers.dart';

const _path = '/api/v1/invoices/d1';

/// The invoice screen over an invoice (and its client) seeded locally.
void _screenTest(
  String description,
  Map<String, dynamic> invoice,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  DocServer? server,
  bool online = false,
  Size size = const Size(480, 2000),
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
}) => recordScreenTest(
  description,
  seed: (services) async {
    await seedClient(services);
    await services.invoices.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: InvoiceApi.fromJson(invoice),
    );
  },
  screen: () => InvoiceDetailScreen(id: invoice['id'] as String),
  ready: () => find.byType(StandingCard),
  // The contacts are the client's, and the client is a second row to arrive.
  // (On a real screen it is seeded from what the list already resolved.)
  body: (tester, screen) async {
    await screen.untilFound(
      find.byType(BillingDocContactsCard),
      'the contacts',
    );
    await body(tester, screen);
  },
  httpClient: server?.client,
  online: online,
  size: size,
  company: company,
);

/// The tiles on screen, left to right, by their short label.
List<String> _tiles(WidgetTester tester) {
  final strip = find.byType(EntityQuickActions<InvoiceAction>);
  if (strip.evaluate().isEmpty) return const [];
  final labels = find.descendant(of: strip, matching: find.byType(Text));
  final texts = labels.evaluate().map((e) => e.widget as Text).toList()
    ..sort(
      (a, b) => tester
          .getTopLeft(find.byWidget(a))
          .dx
          .compareTo(tester.getTopLeft(find.byWidget(b)).dx),
    );
  return [for (final t in texts) t.data ?? ''];
}

Finder _inStanding(String text) =>
    find.descendant(of: find.byType(StandingCard), matching: find.text(text));

void main() {
  _screenTest(
    'a sent invoice: what it is and whose, tiles, standing, profile, tabs',
    docJson(),
    (tester, screen) async {
      // What it is, its number, and whose — the client as a link.
      final header = find.byType(BillingDocRecordHeader);
      expect(
        find.descendant(of: header, matching: find.text('INVOICE')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('#0042')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('Acme Corporation')),
        findsOneWidget,
      );
      // Date · due date, on one line under the name. (No date format is
      // seeded here, so the formatter prints ISO.)
      expect(find.text('2000-01-01'), findsOneWidget);
      expect(find.text('Due Date: 2999-01-01'), findsOneWidget);
      // Nobody has opened it, so the line does not say when they did.
      expect(find.textContaining('Viewed:'), findsNothing);

      // Something is owed: taking a payment leads. No PDF pane at this width,
      // so opening the PDF is worth a tile.
      expect(_tiles(tester), ['+ Payment', 'Email', 'PDF', 'Mark Paid']);

      // The two figures that answer "where does this stand", and how long is
      // left. Nothing has been paid, so there is no Paid figure.
      expect(_inStanding('AMOUNT'), findsOneWidget);
      expect(_inStanding('BALANCE DUE'), findsOneWidget);
      expect(_inStanding(r'$3,720.00'), findsNWidgets(2));
      expect(_inStanding('Paid to Date'), findsNothing);
      final line = tester.widget<Text>(
        find.descendant(
          of: find.byType(BillingDocDueLine),
          matching: find.byType(Text),
        ),
      );
      expect(line.data, startsWith('Due: '));
      expect(line.data, endsWith(' Days'));
      expect(line.style?.color, InTheme.light.ink2, reason: 'not late');

      // The people it went to — and not the blank contact the server seeds
      // for every client, though it has an invitation like the others.
      expect(find.byType(PartyContactRow), findsNWidgets(2));
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('jane@acme.example.com'), findsOneWidget);
      expect(find.text('Sam Lee'), findsOneWidget);
      // Its details, and the note left for whoever opens it.
      expect(find.text('PO Number'), findsOneWidget);
      expect(find.text('PO-7781'), findsOneWidget);
      expect(find.byType(BillingDocPrivateNotesCard), findsOneWidget);
      expect(find.text('Call Jane before the next phase.'), findsOneWidget);

      // Comments and Activity still lead the strip, and it opens on the
      // document itself.
      final comments = tester.getTopLeft(find.text('Comments')).dx;
      final activity = tester.getTopLeft(find.text('Activity')).dx;
      final overview = tester.getTopLeft(find.text('Overview')).dx;
      expect(comments, lessThan(activity));
      expect(activity, lessThan(overview));
      expect(find.text('Design'), findsOneWidget);
      // What prints on it sits under its totals — not above the tabs.
      final printed = find.byType(BillingDocPrintedNotesCard);
      expect(printed, findsOneWidget);
      expect(
        tester.getTopLeft(printed).dy,
        greaterThan(tester.getTopLeft(find.text('Total')).dy),
      );
      expect(find.text('Thank you for your business.'), findsOneWidget);

      // The PDF is a screen of its own at this width.
      expect(find.byType(VersionedPdfPane), findsNothing);

      // And the Comments tab offers a new comment — the control for the
      // deleted-invoice test below, which expects exactly this to be gone.
      await tester.tap(find.text('Comments'));
      await screen.untilFound(find.text('Add Comment'), 'the comments tab');
    },
  );

  _screenTest(
    'an invoice with no number yet is named for what it is — once',
    // A company can hold numbers back until a document is sent.
    docJson(number: '', status: '1', balance: '0', sent: false),
    (tester, screen) async {
      final header = find.byType(BillingDocRecordHeader);
      expect(
        find.descendant(of: header, matching: find.text('Invoice')),
        findsOneWidget,
      );
      // The word is the name here, so it is not also printed above itself,
      // and there is no bare "#" or dash where the number would be.
      expect(find.text('INVOICE'), findsNothing);
      expect(find.text('#'), findsNothing);
      expect(find.text('—'), findsNothing);
    },
  );

  _screenTest(
    'a draft: getting it out leads, and nothing is "due" yet',
    docJson(status: '1', balance: '0', sent: false),
    (tester, screen) async {
      expect(_tiles(tester), ['Mark Sent', 'Email', 'PDF', 'Mark Paid']);
      // A draft has been sent to nobody who could be late.
      expect(find.byType(BillingDocDueLine), findsNothing);
      // The balance is the answer even at zero — printed, never dashed.
      expect(_inStanding(r'$0.00'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      // Not sent to anyone, so neither contact carries a delivery pill.
      expect(find.text('Sent'), findsNothing);
    },
  );

  _screenTest(
    'past due: the line says by how much, and is the only red on the card',
    docJson(
      status: '3',
      balance: '1720.00',
      paid: '2000.00',
      due: '2000-02-01',
    ),
    (tester, screen) async {
      final line = tester.widget<Text>(
        find.descendant(
          of: find.byType(BillingDocDueLine),
          matching: find.byType(Text),
        ),
      );
      expect(line.data, startsWith('Past Due: '));
      expect(line.style?.color, InTheme.light.overdue);
      // The balance itself stays plain ink: the pill above says Past Due and
      // the line says by how much.
      final balance = tester.widget<Text>(_inStanding(r'$1,720.00'));
      expect(balance.style?.color, InTheme.light.ink);
      // Part of it has been paid, so that figure appears.
      expect(_inStanding('Paid to Date'), findsOneWidget);
      expect(_inStanding(r'$2,000.00'), findsOneWidget);
      expect(find.text('Past Due'), findsOneWidget, reason: 'the status pill');
    },
  );

  test('the line is late exactly when the invoice itself says it is', () {
    // The screen decides "is this still owed" with `invoiceAwaitsPayment` and
    // the date with `billingDocDueNote`; the status pill uses
    // `Invoice.isPastDueOn`. Two rules that must agree, on every status.
    final today = Date.today();
    for (final status in ['1', '2', '3', '4', '5', '6']) {
      for (final due in ['2000-01-01', '2999-01-01']) {
        for (final balance in ['0', '50.00']) {
          final invoice = Invoice.fromApi(
            InvoiceApi.fromJson(
              docJson(status: status, due: due, balance: balance),
            ),
          );
          final late =
              invoiceAwaitsPayment(invoice) &&
              invoice.dueDate!.compareTo(today) < 0;
          expect(
            late,
            invoice.isPastDueOn(today),
            reason: 'status $status, due $due, balance $balance',
          );
        }
      }
    }
  });

  _screenTest(
    'paid: no payment tile, the zero balance is printed, nothing is due',
    docJson(status: '4', balance: '0', paid: '3720.00', due: '2000-02-01'),
    (tester, screen) async {
      expect(_tiles(tester), ['Email', 'PDF', 'Download', 'Refund']);
      expect(_inStanding(r'$0.00'), findsOneWidget);
      expect(find.byType(BillingDocDueLine), findsNothing);
    },
  );

  _screenTest(
    'a viewed invoice: the header says when, and the pill opens the activity',
    docJson(viewed: true),
    (tester, screen) async {
      // Date-only, like its neighbours — the time is in the pill's tooltip.
      expect(find.text('Viewed: 2000-01-03'), findsOneWidget);
      // The contact who looked carries it too.
      expect(
        find.descendant(
          of: find.byType(PartyContactRow).first,
          matching: find.text('Viewed'),
        ),
        findsOneWidget,
      );
      bool activityTab(Widget w) => w is EntityActivityTab && !w.commentsOnly;
      expect(find.byWidgetPredicate(activityTab), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(BillingDocRecordHeader),
          matching: find.text('Viewed'),
        ),
      );
      await screen.untilFound(
        find.byWidgetPredicate(activityTab),
        'the Activity tab',
      );
    },
  );

  _screenTest(
    'a contact\'s copy button copies the link they were sent',
    docJson(),
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
        await tester.tap(find.byTooltip('Client Portal: Copy Link').first);
        await screen.until(() => copied != null, 'the copy');
        expect(copied, kPortalLink);
        // Let the "copied" toast run out its clock before the tree goes.
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
    'a deleted invoice is read-only, and says so once',
    docJson(deleted: true),
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // Nothing that writes to the record is offered: no tiles, and no
      // payment against an invoice the server would refuse one for.
      expect(_tiles(tester), isEmpty);
      expect(find.text('Enter Payment'), findsNothing);
      // What it says is still all there.
      expect(_inStanding(r'$3,720.00'), findsNWidgets(2));
      expect(find.text('Jane Doe'), findsOneWidget);

      // Its comments stay readable; adding one does not.
      await tester.tap(find.text('Comments'));
      await screen.untilFound(find.text('No comments yet'), 'the comments tab');
      expect(find.text('Add Comment'), findsNothing);
    },
    server: DocServer(_path)..emptyActivity = true,
  );

  _screenTest(
    'an archived invoice says so and keeps its actions',
    docJson(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // Archived is not read-only: the server still accepts a payment.
      expect(_tiles(tester), contains('+ Payment'));
    },
  );

  _screenTest(
    'a user who may only view invoices gets the banner without Restore, and '
    'no tile for what they may not do',
    docJson(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      // Reading it is all that is left.
      expect(_tiles(tester), ['PDF', 'Download']);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_invoice,view_client',
    ),
  );

  final unsynced = DocServer('/api/v1/invoices/tmp_1')
    ..record = docJson(id: 'tmp_1');
  _screenTest(
    'an unsynced invoice gets the sync banner — no tiles, and nothing is '
    'asked of a server that has never seen it',
    docJson(id: 'tmp_1'),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
      expect(_tiles(tester), isEmpty);
      await screen.quiet();
      expect(unsynced.requests, isEmpty);
    },
    server: unsynced,
    online: true,
  );

  group('beside its PDF', () {
    _screenTest(
      'a wide window shows the PDF pane, drops the PDF tile, and keeps the '
      'tab strip in view however far the record scrolls',
      docJson(),
      (tester, screen) async {
        expect(find.byType(VersionedPdfPane), findsOneWidget);
        // The record column is its own width here — five elevenths of the
        // window — so it is still one stack, with room for more tiles.
        final tiles = _tiles(tester);
        expect(tiles, isNot(contains('PDF')));
        expect(tiles, containsAll(['+ Payment', 'Email', 'Download', 'Clone']));
        final column = tester.getSize(find.byType(StandingCard)).width;
        expect(column, lessThan(700));

        // Scroll the record as far as it goes: the strip pins at the top
        // instead of leaving with the header.
        final scrollable = tester.state<ScrollableState>(
          find
              .ancestor(
                of: find.byType(StandingCard),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump();
        expect(scrollable.position.pixels, greaterThan(100));
        final strip = tester.getTopLeft(find.text('Overview')).dy;
        expect(strip, greaterThanOrEqualTo(0));
        expect(strip, lessThan(160), reason: 'pinned under the action bar');
      },
      // Short, so the Overview tab's body is taller than the viewport and
      // the strip has somewhere to pin.
      size: const Size(1320, 420),
    );
  });

  group('refresh', () {
    final server = DocServer(_path)..record = docJson(updatedAt: 1700000001);
    _screenTest(
      'the record is re-checked quietly on open, and R fetches it again — '
      'with nothing clicked first',
      docJson(),
      (tester, screen) async {
        await screen.until(() => server.recordAsks.isNotEmpty, 'the re-check');
        await screen.quiet();
        expect(server.recordAsks, hasLength(1));
        expect(_inStanding(r'$3,720.00'), findsNWidgets(2));

        // A payment landed on the server since.
        server.record = docJson(
          status: '3',
          balance: '720.00',
          paid: '3000.00',
          updatedAt: 1700000002,
        );
        expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isTrue);
        await screen.untilFound(_inStanding(r'$720.00'), 'the new balance');
        expect(server.recordAsks, hasLength(2));
        expect(_inStanding('Paid to Date'), findsOneWidget);
      },
      server: server,
      online: true,
    );
  });

  group('the profile', () {
    _screenTest(
      'an invoice with nothing to add shows only who it went to',
      docJson(po: '', privateNotes: ''),
      (tester, screen) async {
        expect(find.byType(BillingDocContactsCard), findsOneWidget);
        expect(find.byType(BillingDocDetailsCard), findsNothing);
        expect(find.byType(BillingDocPrivateNotesCard), findsNothing);
      },
    );

    _screenTest(
      'a custom field the company has labelled is a Details row',
      {...docJson(po: ''), 'custom_value1': 'Blue'},
      (tester, screen) async {
        await screen.untilFound(find.text('Colour'), 'the custom field');
        expect(find.text('Blue'), findsOneWidget);
      },
      company: const FakeCompany(
        id: 'co1',
        name: 'Co',
        customFields: {'invoice1': 'Colour|single_line_text'},
      ),
    );
  });
}
