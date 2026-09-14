import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/data/models/domain/vendor.dart' show Vendor, emptyVendor;
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/ui/core/detail/activity_reveal_controller.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart'
    show emptyClient;
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/billing_shared/viewed_status_pill_link.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';

class _FakeClients implements ClientRepository {
  _FakeClients(this.client);
  final Client? client;

  @override
  Stream<Client?> watch({required String companyId, required String id}) =>
      Stream<Client?>.value(client);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _FakeVendors implements VendorRepository {
  _FakeVendors(this.vendor);
  final Vendor? vendor;

  @override
  Stream<Vendor?> watch({required String companyId, required String id}) =>
      Stream<Vendor?>.value(vendor);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

final _formatter = Formatter(
  settings: const CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: 'X',
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: false,
    locale: '',
  ),
  currencies: const {},
  countries: const {},
  dateFormats: const {'X': DatetimeFormat(id: 'X', format: 'd/MMM/yyyy')},
);

const _jane = Invitation(
  id: 'i1',
  clientContactId: 'c1',
  viewedDate: '2026-09-11 15:50:31',
);
const _bob = Invitation(
  id: 'i2',
  clientContactId: 'c2',
  viewedDate: '2026-09-09 09:00:00',
);

Contact _contact(
  String id, {
  String first = '',
  String last = '',
  String email = '',
}) => Contact(
  id: id,
  firstName: first,
  lastName: last,
  email: email,
  phone: '',
  isPrimary: true,
  sendEmail: true,
  updatedAt: DateTime.utc(2026, 1, 1, 12),
  isDeleted: false,
);

Client _clientWith(List<Contact> contacts) =>
    emptyClient().copyWith(id: 'cl1', name: 'Acme Ltd', contacts: contacts);

Vendor get _supplier => emptyVendor().copyWith(
  id: 'vn1',
  contacts: [
    VendorContact(
      id: 'v1',
      firstName: 'Sam',
      lastName: 'Vimes',
      email: '',
      phone: '',
      password: '',
      sendEmail: true,
      isPrimary: true,
      customValue1: '',
      customValue2: '',
      customValue3: '',
      customValue4: '',
      updatedAt: DateTime.utc(2026, 1, 1, 12),
      isDeleted: false,
    ),
  ],
);

void main() {
  late TabSelectionController selectTab;
  late ActivityRevealController reveal;

  setUp(() {
    selectTab = TabSelectionController();
    reveal = ActivityRevealController();
  });

  tearDown(() {
    selectTab.dispose();
    reveal.dispose();
  });

  Future<({String? tooltip, String? semanticsLabel, bool tappable})> pump(
    WidgetTester tester, {
    required bool isViewed,
    List<Invitation> invitations = const [_jane],
    String entityWireName = 'invoice',
    Client? client,
    Vendor? vendor,
    String clientId = 'cl1',
    String vendorId = '',
  }) async {
    String? seenTooltip;
    String? seenSemanticsLabel;
    var tappable = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: ViewedStatusPillLink(
              isViewed: isViewed,
              invitations: invitations,
              entityWireName: entityWireName,
              companyId: 'co1',
              clients: _FakeClients(client),
              vendors: _FakeVendors(vendor),
              clientId: clientId,
              vendorId: vendorId,
              selectTab: selectTab,
              reveal: reveal,
              formatter: _formatter,
              builder: (context, tooltip, semanticsLabel, onTap) {
                seenTooltip = tooltip;
                seenSemanticsLabel = semanticsLabel;
                tappable = onTap != null;
                return StatusPill(
                  label: 'Viewed',
                  fgColor: const Color(0xFFB07A1F),
                  tooltip: tooltip,
                  onTap: onTap,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (
      tooltip: seenTooltip,
      semanticsLabel: seenSemanticsLabel,
      tappable: tappable,
    );
  }

  group('the gate is the pill\'s rendered status, not the invitations', () {
    testWidgets('a viewed-but-Past-Due doc is inert', (tester) async {
      // The error an earlier draft shipped on: `calculatedStatusId` checks its
      // viewed branch LAST, so paid / past due / approved / applied all outrank
      // it. Gating on `hasViewedInvitation` would hang a "viewed by" tooltip
      // under a pill reading *Past Due*. The durable answer for those documents
      // is the header caption, which is status-independent.
      final r = await pump(tester, isViewed: false);
      expect(r.tappable, isFalse);
      expect(r.tooltip, isNull);
    });

    testWidgets('an entity with no view event is inert', (tester) async {
      final r = await pump(
        tester,
        isViewed: true,
        entityWireName: 'recurring_invoice',
      );
      expect(r.tappable, isFalse);
    });

    testWidgets('nothing viewed is inert even when the status says so', (
      tester,
    ) async {
      final r = await pump(
        tester,
        isViewed: true,
        invitations: const [Invitation(id: 'i0', clientContactId: 'c1')],
      );
      expect(r.tappable, isFalse);
    });
  });

  group('the tooltip', () {
    // `flutter test` reports android, i.e. `Env.isTouchPrimary` — and the
    // tooltip is deliberately pointer-only, because on touch it would be
    // reachable only by a long-press nobody will try. So the pointer branch has
    // to be asked for explicitly, and reset INSIDE the body: the binding
    // verifies the foundation debug vars at the end of `_runTestBody`, before
    // any teardown runs.
    testWidgets('names the viewer and the exact moment', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final r = await pump(
          tester,
          isViewed: true,
          client: _clientWith([_contact('c1', first: 'Jane', last: 'Doe')]),
        );
        expect(r.tappable, isTrue);
        expect(r.tooltip, contains('Jane Doe'));
        expect(r.tooltip, contains('Viewed:'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('counts the other viewers as PEOPLE', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        // `viewed_date` is the first view per contact and the server keeps no
        // repeat count, so this can only ever be "+N more people".
        final r = await pump(
          tester,
          isViewed: true,
          invitations: const [_bob, _jane],
          client: _clientWith([
            _contact('c1', first: 'Jane', last: 'Doe'),
            _contact('c2', first: 'Bob', last: 'Roe'),
          ]),
        );
        // Newest first: Jane (11 Sep) leads, Bob is the "+1 more".
        expect(r.tooltip, startsWith('Jane Doe'));
        expect(r.tooltip, contains('1 more'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('falls back to the email when the contact has no name', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final r = await pump(
          tester,
          isViewed: true,
          client: _clientWith([_contact('c1', email: 'jane@acme.test')]),
        );
        expect(r.tooltip, contains('jane@acme.test'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('falls back to "Contact" when it has neither', (tester) async {
      // The server seeds one all-blank contact per client, and blanks its own
      // minted `@example.com` addresses — so this is the normal state of a
      // seeded row, not an edge case. Separate test, not a second `pump` in the
      // one above: re-pumping the same widget type reuses the State, and
      // `WatchBuilder` keeps its stream while the cacheKey is unchanged, so the
      // first client's contacts would still be in hand.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final r = await pump(
          tester,
          isViewed: true,
          client: _clientWith([_contact('c1')]),
        );
        expect(r.tooltip, contains('Contact'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  testWidgets('the screen reader hears the answer on touch too', (
    tester,
  ) async {
    // The tooltip is pointer-gated; the semantics label must NOT be. Touch is
    // where VoiceOver and TalkBack are the primary way in, so tying both to one
    // flag would announce a bare "Viewed" exactly where the answer is most
    // likely to be read only by a screen reader. `flutter test` reports
    // android, so this runs on the touch branch by default.
    final r = await pump(
      tester,
      isViewed: true,
      client: _clientWith([_contact('c1', first: 'Jane', last: 'Doe')]),
    );
    expect(r.tooltip, isNull);
    expect(r.semanticsLabel, contains('Jane Doe'));
    expect(r.semanticsLabel, contains('Viewed:'));
  });

  testWidgets('an inert pill announces nothing extra', (tester) async {
    final r = await pump(tester, isViewed: false);
    expect(r.semanticsLabel, isNull);
  });

  testWidgets('there is no tooltip on touch, only the tap', (tester) async {
    // Not an omission. The issue asked for a long-press hovertip "like the
    // phone icon" — but that icon's long-press COPIES, and its tooltip is
    // gated `!Env.isTouchPrimary` too. Touch gets the answer from the header
    // caption and from the row the tap lands on.
    final r = await pump(
      tester,
      isViewed: true,
      client: _clientWith([_contact('c1', first: 'Jane', last: 'Doe')]),
    );
    expect(r.tooltip, isNull);
    expect(r.tappable, isTrue);
  });

  group('the tap', () {
    testWidgets('selects Activity BEFORE asking for the reveal', (
      tester,
    ) async {
      // Order is load-bearing. On the path where the Activity tab is already
      // mounted but offstage, notifying first would run its listener while the
      // tab controller still points somewhere else.
      final order = <String>[];
      selectTab.addListener(() => order.add('select:${selectTab.value}'));
      reveal.addListener(
        () => order.add('reveal:${reveal.request!.activityTypeId}'),
      );

      await pump(
        tester,
        isViewed: true,
        client: _clientWith([_contact('c1', first: 'Jane', last: 'Doe')]),
      );
      await tester.tap(find.byType(StatusPill));
      await tester.pump();

      expect(order, ['select:$kActivityTabIndex', 'reveal:7']);
    });

    testWidgets('a purchase order reveals its own event type', (tester) async {
      await pump(
        tester,
        isViewed: true,
        entityWireName: 'purchase_order',
        invitations: const [
          Invitation(
            id: 'i1',
            vendorContactId: 'v1',
            viewedDate: '2026-09-11 15:50:31',
          ),
        ],
        clientId: '',
        vendorId: 'vn1',
        vendor: _supplier,
      );
      await tester.tap(find.byType(StatusPill));
      await tester.pump();
      expect(reveal.request!.activityTypeId, 136);
    });
  });

  group('viewedByTooltip', () {
    test('is pure, so it can be read without pumping anything', () {
      expect(
        viewedByTooltip(
          name: 'Jane Doe',
          viewedLabel: 'Viewed',
          formattedDate: '11 Sep 2026 3:50 pm',
        ),
        'Jane Doe · Viewed: 11 Sep 2026 3:50 pm',
      );
    });

    test('drops the date rather than trailing a bare label', () {
      // `Formatter.date` answers '' for anything it cannot parse.
      expect(
        viewedByTooltip(
          name: 'Jane Doe',
          viewedLabel: 'Viewed',
          formattedDate: '',
        ),
        'Jane Doe',
      );
    });

    test('appends the others when there are any', () {
      expect(
        viewedByTooltip(
          name: 'Jane Doe',
          viewedLabel: 'Viewed',
          formattedDate: '11 Sep 2026',
          moreLabel: '+2 more',
        ),
        'Jane Doe · Viewed: 11 Sep 2026 · +2 more',
      );
    });
  });
}
