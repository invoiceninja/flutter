import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/domain/columns/client_columns.dart';
import 'package:admin/ui/features/clients/widgets/client_list_tile.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_responsive_helper.dart';
import '../../../../_support/fake_url_launcher.dart';
import '../../../../_support/phone_actions_test_services.dart';

/// The narrow client row: its call button (invoiceninja/flutter#111) and its
/// money column (invoiceninja/flutter#112).
///
/// Both features are *narrow*-branch behaviour, and the wide data table is
/// deliberately untouched by either: a #111 trailing slot there would have to be
/// mirrored into the shared `EntityListColumnHeaders` strip and
/// `computeTableMinWidth`, and #112 leaves the table's em dashes alone because
/// its columns are labelled. The two `wide: true` tests below pin exactly that
/// — they assert the wide row does *not* change.
void main() {
  late FakeUrlLauncher launcher;
  late List<String> copied;

  ContactApi contact({
    required String id,
    String firstName = '',
    String lastName = '',
    String phone = '',
    bool isPrimary = false,
  }) => ContactApi(
    id: id,
    firstName: firstName,
    lastName: lastName,
    phone: phone,
    isPrimary: isPrimary,
  );

  // No `balance` / `isDeleted` here on purpose — the money and status-pill
  // cases live in the `layout` group's own `fullRow`, which passes them as
  // Strings. `ClientApi.balance` is typed `Object` and read through
  // `parseMoney`, which returns `Decimal.zero` for anything that is not a `num`
  // or a `String`: a `Decimal` fixture parses to zero, which now renders no
  // money line at all.
  Client client({
    List<ContactApi> contacts = const [],
    String phone = '',
    String displayName = 'Acme Corporation',
  }) => Client.fromApi(
    ClientApi(
      id: 'c1',
      displayName: displayName,
      phone: phone,
      contacts: contacts,
    ),
  );

  setUp(() {
    launcher = installFakeUrlLauncher();
    copied = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Finder callIcon() => find.byIcon(Icons.call_outlined);

  /// A real formatter, because a null one renders no money at all and would
  /// quietly hollow out the cases that depend on an amount being drawn.
  final formatter = Formatter(
    settings: const CompanyFormatSettings(
      currencyId: '1',
      countryId: '840',
      dateFormatId: 'X',
      useCommaAsDecimalPlace: false,
      showCurrencyCode: false,
      enableMilitaryTime: false,
      locale: '',
    ),
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
    countries: const {},
    dateFormats: const {'X': DatetimeFormat(id: 'X', format: 'd/MMM/yyyy')},
  );

  group('the call button', () {
    // `timezone: null`, so `_outsideHoursLine` resolves null and no
    // quiet-hours dialog can intercept a launch. The harness's default zone is
    // UTC+13:45, whose wall clock sits outside 08:00–20:00 for much of the day.
    late PhoneActionsTestServices services;

    Future<void> pumpRow(
      WidgetTester tester,
      Client c, {
      bool selecting = false,
      bool wide = false,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
      VoidCallback? onViewRecord,
      double width = 500,
      double textScale = 1.0,
    }) async {
      services = PhoneActionsTestServices(timezone: null);
      await pumpAt(
        tester,
        width,
        Provider<Services>.value(
          value: services,
          child: ClientListTile(
            client: c,
            formatter: null,
            wide: wide,
            selecting: selecting,
            // Deliberately NOT `selecting ? null : …`, which is what the real
            // screen passes: tying the two together would let the multi-select
            // case below pass against a button gated on `onAction != null`
            // instead of on `selecting`.
            onAction: (_) {},
            onTap: onTap ?? () {},
            onLongPress: onLongPress,
            onViewRecord: onViewRecord,
          ),
        ),
        textScale: textScale,
      );
    }

    testWidgets('is absent when the client has no dialable number', (
      tester,
    ) async {
      await pumpRow(tester, client());
      expect(callIcon(), findsNothing);

      // `1-800-FLOWERS` reduces to `1800`, which `cleanPhoneNumber` refuses.
      await pumpRow(tester, client(phone: '1-800-FLOWERS'));
      expect(callIcon(), findsNothing);
    });

    testWidgets('is absent while tap-to-call is off', (tester) async {
      await pumpRow(tester, client(phone: '+1 415 555 2671'));
      expect(callIcon(), findsOneWidget);

      await services.phoneActions.setTapToCall(false);
      await tester.pump();
      expect(callIcon(), findsNothing);
    });

    testWidgets('is absent in multi-select — the row tap means toggle there', (
      tester,
    ) async {
      await pumpRow(tester, client(phone: '+1 415 555 2671'), selecting: true);
      expect(callIcon(), findsNothing);
    });

    testWidgets('is absent on the wide table row', (tester) async {
      // The single scoping decision this feature makes, and the one whose
      // violation would have to be mirrored into the shared
      // `EntityListColumnHeaders` strip and `computeTableMinWidth` or every
      // entity's table misaligns. `columns` stays empty: that is still the
      // `_wide` branch, just its legacy outstanding/lifetime layout.
      await pumpRow(tester, client(phone: '+1 415 555 2671'), wide: true);
      expect(callIcon(), findsNothing);

      await pumpRow(tester, client(phone: '+1 415 555 2671'));
      expect(callIcon(), findsOneWidget, reason: 'narrow still has it');
    });

    testWidgets('dials the one number without opening the record', (
      tester,
    ) async {
      var rowTapped = false;
      await pumpRow(
        tester,
        client(phone: '+1 415 555 2671'),
        onTap: () => rowTapped = true,
      );

      await tester.tap(callIcon());
      await tester.pump();
      await tester.pump();

      expect(launcher.launched, ['tel:+14155552671']);
      expect(
        rowTapped,
        isFalse,
        reason: 'the nested recogniser must win the gesture arena',
      );
    });

    testWidgets('opens the picker when the client has several numbers', (
      tester,
    ) async {
      await pumpRow(
        tester,
        client(
          phone: '+1 800 555 0100',
          contacts: [
            contact(
              id: '1',
              firstName: 'Jane',
              lastName: 'Smith',
              phone: '+1 415 555 2671',
              isPrimary: true,
            ),
          ],
        ),
      );

      expect(
        find.byIcon(Icons.arrow_drop_down),
        findsOneWidget,
        reason: 'one glyph must not hide two behaviours',
      );

      await tester.tap(callIcon());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The number, not the name: the row's own subtitle line already shows
      // the primary contact's name.
      expect(find.text('+1 415 555 2671'), findsOneWidget);
      expect(find.text('+1 800 555 0100'), findsOneWidget);
      expect(launcher.launched, isEmpty, reason: 'not until a row is picked');
    });

    testWidgets('long-press reaches the row, and copies nothing', (
      tester,
    ) async {
      var rowLongPressed = false;
      await pumpRow(
        tester,
        client(phone: '+1 415 555 2671'),
        onLongPress: () => rowLongPressed = true,
      );

      await tester.longPress(callIcon());
      await tester.pump();

      expect(rowLongPressed, isTrue, reason: 'long-press enters multi-select');
      expect(copied, isEmpty);
      expect(launcher.launched, isEmpty);
    });

    testWidgets('the picker footer navigates to the record', (tester) async {
      var viewed = false;
      await pumpRow(
        tester,
        client(
          phone: '+1 800 555 0100',
          contacts: [
            contact(id: '1', firstName: 'Jane', phone: '+1 415 555 2671'),
          ],
        ),
        onViewRecord: () => viewed = true,
      );

      await tester.tap(callIcon());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('View Client'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(viewed, isTrue);
    });
  });

  group('the money column', () {
    // invoiceninja/flutter#112. The narrow row omits an empty money line
    // instead of dashing it; the wide table deliberately still dashes, because
    // its columns are labelled. Balances are Strings, never `Decimal` — see
    // the fixture note above `client()`.
    Client moneyClient({String balance = '0', String paidToDate = '0'}) =>
        Client.fromApi(
          ClientApi(
            id: 'c1',
            displayName: 'Acme Corporation',
            // A number, so `_SubtitleLine` has something to render: without it
            // these would be asserting on its own (now blank) fallback as much
            // as on the money column.
            number: '0009',
            balance: balance,
            paidToDate: paidToDate,
          ),
        );

    // Built once per test, not once per pump: several cases below pump twice to
    // compare two rows, and a second `PhoneActionsTestServices` would open a
    // second `AppDatabase` on the same executor (drift warns, loudly).
    late PhoneActionsTestServices services;
    setUp(() => services = PhoneActionsTestServices(timezone: null));

    Future<void> pumpMoney(
      WidgetTester tester,
      Client c, {
      bool withFormatter = true,
      bool wide = false,
      List<ClientColumn> columns = const <ClientColumn>[],
      double width = 390,
    }) => pumpAt(
      tester,
      width,
      Provider<Services>.value(
        value: services,
        child: ClientListTile(
          client: c,
          formatter: withFormatter ? formatter : null,
          wide: wide,
          columns: columns,
          onAction: (_) {},
          onTap: () {},
        ),
      ),
    );

    testWidgets('a client with no activity renders no dash at all', (
      tester,
    ) async {
      await pumpMoney(tester, moneyClient());

      expect(find.text('—'), findsNothing);
      expect(
        find.textContaining(r'$'),
        findsNothing,
        reason: 'a blank line, not a formatted zero',
      );
      expectNoOverflow(tester);
    });

    testWidgets('a paid-to-date with no balance renders on its own', (
      tester,
    ) async {
      await pumpMoney(tester, moneyClient(paidToDate: '695.00'));

      expect(find.text(r'$695.00'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      // Not just "no dash": without `zeroIsNull` the hidden line comes back as
      // a formatted zero, which neither assertion above would catch.
      expect(find.text(r'$0.00'), findsNothing);
    });

    testWidgets('a balance with nothing paid renders on its own', (
      tester,
    ) async {
      await pumpMoney(tester, moneyClient(balance: '1200.00'));

      expect(find.text(r'$1,200.00'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      expect(find.text(r'$0.00'), findsNothing);
    });

    testWidgets('both values still stack, outstanding above paid', (
      tester,
    ) async {
      await pumpMoney(
        tester,
        moneyClient(balance: '1200.00', paidToDate: '695.00'),
      );

      expect(find.text(r'$1,200.00'), findsOneWidget);
      expect(find.text(r'$695.00'), findsOneWidget);
      expect(
        tester.getCenter(find.text(r'$1,200.00')).dy,
        lessThan(tester.getCenter(find.text(r'$695.00')).dy),
      );
    });

    testWidgets('a negative balance renders, in plain ink and not bold', (
      tester,
    ) async {
      // The row used to hide this behind a dash: the old predicate was
      // `!(balance > 0)`, so a client in credit looked exactly like one with no
      // activity — while the wide table (`cellMoney`, strict `== zero`) showed
      // the same client's balance. Plain `ink` rather than `ink3`, or it reads
      // as a second copy of the muted paid line below it.
      await pumpMoney(tester, moneyClient(balance: '-100.00'));

      final style = tester.widget<Text>(find.text(r'-$100.00')).style;
      expect(style?.color, InTheme.light.ink);
      expect(style?.color, isNot(InTheme.light.overdue));
      expect(style?.fontWeight, FontWeight.w400);
    });

    testWidgets('renders nothing while the formatter is still resolving', (
      tester,
    ) async {
      await pumpMoney(
        tester,
        moneyClient(balance: '1200.00'),
        withFormatter: false,
      );

      expect(find.text('—'), findsNothing);
      expect(find.textContaining('1,200'), findsNothing);
    });

    // No test that the money column can't drive the row height: it can't, and
    // no fixture can make it. The identity column (14/2/12) is taller than the
    // money block (13/2/11) at every text scale, and `EntityActionsPopupButton`
    // pins itself to `actionButtonSize()` = 44 on touch — which `flutter test`
    // always is — flooring the row at 72 regardless. An assertion here can only
    // ever pass; the rationale lives in `_narrow` and in CLAUDE.md instead.

    testWidgets('a subtitle with nothing to say is blank, not dashed', (
      tester,
    ) async {
      // `client()` carries no contact, city or number — the only case that
      // reaches `_SubtitleLine`'s fallback.
      await pumpMoney(tester, client());
      expect(find.text('—'), findsNothing);
      final bareNameDy = tester.getCenter(find.text('Acme Corporation')).dy;

      await pumpMoney(tester, moneyClient());

      // The NAME's position, not the row height: the row is floored at 72 by
      // the 44 px `…` button either way, so a height assertion here would pass
      // even if `_SubtitleLine` returned `SizedBox.shrink()` — which is the one
      // thing this test exists to forbid. An empty `Text` keeps its line box,
      // so the min-sized identity column stays ~34 tall and the centred name
      // holds its dy; collapsing it to ~19 drops the name ~7 px and zigzags the
      // name column down a scrolled list.
      expect(
        tester.getCenter(find.text('Acme Corporation')).dy,
        bareNameDy,
        reason: 'the blank subtitle must keep its line box',
      );
    });

    testWidgets('the row summary reports a credit, a debt, and neither', (
      tester,
    ) async {
      // `_semanticsLabel` had no coverage at all, and making a negative balance
      // visible put it out of step with the row: it announced "no outstanding
      // balance" over a row rendering -$100.00.
      String rowLabel() => tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(ClientListTile),
              matching: find.byType(Semantics),
            ),
          )
          .map((w) => w.properties.label)
          .firstWhere((l) => l != null && l.contains('Acme Corporation'))!;

      await pumpMoney(tester, moneyClient(balance: '1200.00'));
      expect(rowLabel(), contains(r'outstanding $1,200.00'));

      await pumpMoney(tester, moneyClient(balance: '-100.00'));
      expect(rowLabel(), contains(r'balance -$100.00'));

      await pumpMoney(tester, moneyClient());
      expect(rowLabel(), contains('no outstanding balance'));
    });

    testWidgets('the wide table still dashes — its columns are labelled', (
      tester,
    ) async {
      await pumpMoney(
        tester,
        moneyClient(),
        wide: true,
        width: 1200,
        columns: [
          clientColumnsById[ClientFieldIds.balance]!,
          clientColumnsById[ClientFieldIds.paidToDate]!,
        ],
      );

      expect(
        find.text('—'),
        findsNWidgets(2),
        reason: 'the deliberate narrow/wide asymmetry — do not "unify" these',
      );
    });
  });

  group('layout', () {
    /// A deleted client (so the status pill is drawn) with two dialable
    /// numbers (so the `▾` is drawn) — the fullest the trailing cluster ever
    /// gets. Both money lines take [balance]: the column sizes to the wider of
    /// the two, so a fixed second line would silently drive the width instead.
    Client fullRow(
      String balance, {
      bool twoNumbers = true,
      bool pill = true,
    }) => Client.fromApi(
      ClientApi(
        id: 'c1',
        displayName: 'A very long client name that wants the whole row',
        phone: '+1 800 555 0100',
        balance: balance,
        paidToDate: balance,
        isDeleted: pill,
        contacts: twoNumbers
            ? [
                ContactApi(
                  id: '1',
                  firstName: 'Jane',
                  lastName: 'Smith',
                  phone: '+1 415 555 2671',
                  isPrimary: true,
                ),
              ]
            : const [],
      ),
    );

    Future<void> pumpLayout(
      WidgetTester tester,
      Client c, {
      required double width,
      required double scale,
    }) => pumpAt(
      tester,
      width,
      Provider<Services>.value(
        value: PhoneActionsTestServices(timezone: null),
        child: ClientListTile(
          client: c,
          formatter: formatter,
          wide: false,
          onAction: (_) {},
          onTap: () {},
        ),
      ),
      textScale: scale,
    );

    for (final scale in [1.0, kTextScaleMax]) {
      // 500 is the app's own responsive floor (`kResponsiveWidths`), and this
      // is the fullest the row gets: status pill, `▾`, and a balance wide
      // enough to hit the narrow row's 160 px money cap. It has teeth — before
      // the `listRow` variant fitted its caret inside the touch target rather
      // than bolting 12 px on beside it, this overflowed by 7.2 px at 1.4x.
      testWidgets('survives the floor width at ${scale}x text', (tester) async {
        await pumpLayout(
          tester,
          fullRow('98765432.10'),
          width: 500,
          scale: scale,
        );

        expect(find.byIcon(Icons.call_outlined), findsOneWidget);
        expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
        // Guards the fixture: a null formatter, or a balance the API model
        // can't parse, renders no money column at all and would hollow the
        // whole case out silently.
        expect(find.text('Deleted'), findsOneWidget);
        expect(find.textContaining(RegExp(r'\d,\d')), findsWidgets);
        expectNoOverflow(tester);
      });

      // A real handset with an ordinary row. Not the pathological fixture
      // above: `flutter test` substitutes a font whose every glyph is a full em
      // square, so a 10-character amount measures ~132 px here against ~75 px
      // of real Inter Tight — which is why the repo's own sweep floor is 500 and
      // not a phone width.
      testWidgets('survives a 390 px handset at ${scale}x text', (
        tester,
      ) async {
        await pumpLayout(
          tester,
          fullRow('1234.56', twoNumbers: false, pill: false),
          width: 390,
          scale: scale,
        );

        expect(find.byIcon(Icons.call_outlined), findsOneWidget);
        expectNoOverflow(tester);
      });
    }
  });
}
