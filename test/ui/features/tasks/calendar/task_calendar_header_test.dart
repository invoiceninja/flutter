import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/calendar_connection_api_model.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/tasks/view_models/calendar_connection_view_model.dart';
import 'package:admin/ui/features/tasks/view_models/task_calendar_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/calendar_connect_menu.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/task_calendar_header.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_responsive_helper.dart';
import '../widgets/_task_filter_doubles.dart';

/// The month navigation bar had **no width branch at all**, unlike the daily
/// and weekly headers beside it, and nothing in its `Row` could shrink: the
/// month label was a bare `Text` and the only flexible child was a `Spacer`.
/// On a hosted account with a connected calendar it asked for ~677 px inside a
/// 412 px phone pane, clipping directly above the grid.
///
/// So this file sweeps widths rather than asserting one layout: the fix is
/// "a row that cannot overflow", and only the sweep can say that.
///
/// The sweep drives width through `pumpAt`'s `setSurfaceSize`, which moves the
/// **constraints** — what the header's own `LayoutBuilder` reads — but leaves
/// `MediaQuery.sizeOf` at the harness default. That is sound because the row
/// reads the view for the text scaler only. Write a `MediaQuery`-*size* read
/// into it (an `InSpacing.md(context)` in place of the const `InSpacing.sm`,
/// say) and the widget and this file will disagree about how wide the screen
/// is, and the sweep will quietly stop measuring the phone — set
/// `tester.view.physicalSize` instead, as `task_filters_sheet_test.dart` does.
class _FakeTaskRepo implements TaskRepository {
  @override
  Stream<List<Task>> watchAllActive({
    required String companyId,
    states = const {},
  }) => oneShot(const <Task>[]);

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

/// Real metrics, not the test font. `flutter test` substitutes a square per
/// glyph, which roughly doubles every string — enough to turn a passing width
/// into a failing one and vice versa. Both
/// `dashboard_mobile_app_bar_test.dart` and `sidebar_search_box_test.dart`
/// load the bundled TTF for the same reason.
Future<void> _loadFonts() async {
  for (final font in const [(kSansFontFamily, 'assets/fonts/InterTight.ttf')]) {
    await (FontLoader(font.$1)..addFont(
          Future.value(File(font.$2).readAsBytesSync().buffer.asByteData()),
        ))
        .load();
  }
}

enum _Account { selfHosted, hostedDisconnected, hostedConnected }

/// Only `locale` matters here — the month label is the one thing this row
/// formats, and it does not go through `Formatter` at all (there is no
/// month-only method).
Formatter _formatterFor(String locale) => Formatter(
  settings: CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: '5',
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: false,
    locale: locale,
  ),
  currencies: const {},
  countries: const {},
  dateFormats: const {},
);

/// The month label is the one string here formatted in the *company's* locale
/// rather than the UI's, and `DateFormat` needs that locale's symbols **and**
/// its skeleton patterns loaded. `GlobalMaterialLocalizations` is what loads
/// them (`loadDateIntlDataIfNotLoaded()`, a global one-shot over Flutter's
/// generated set), which is why `main.dart` installs that delegate — and
/// `kTestLocalizationsDelegates` deliberately does not, so a test needing them
/// runs the app's own path once rather than reaching for intl's
/// `initializeDateFormatting()`, whose data is the full CLDR set and therefore
/// **not** what ships. Loading the delegate for one locale is enough; note
/// Flutter's set carries `pt` and `zh` but not `pt_BR` / `zh_CN`, so those two
/// resolve through intl's short-locale fallback — verified to render the same
/// strings either way.
Future<void> _loadDateSymbols() =>
    GlobalMaterialLocalizations.delegate.load(const Locale('en'));

void main() {
  setUpAll(_loadFonts);
  setUpAll(_loadDateSymbols);

  Future<void> pumpHeader(
    WidgetTester tester, {
    required double width,
    required _Account account,
    double textScale = 1.0,
    Formatter? formatter,
  }) async {
    // September is the widest English month label, and pinning it keeps the
    // sweep off the wall clock (CLAUDE.md's UTC/CI rule).
    final vm = TaskCalendarViewModel(
      repo: _FakeTaskRepo(),
      companyId: 'co',
      focusMonth: Date(2026, 9, 1),
    );
    addTearDown(vm.dispose);

    // Seeded BEFORE the view model is built: its constructor reads
    // `connectionState.value` to decide `statusLoaded`, and the menu renders
    // nothing until that is true — so a late seed would silently measure the
    // empty menu, the one state that already fits.
    final calVm = CalendarConnectionViewModel(
      repo: FakeCalendarConnectionRepo(
        connection: switch (account) {
          _Account.selfHosted => const CalendarConnection(),
          _Account.hostedDisconnected => const CalendarConnection(),
          // A long address, because the wide chip caps it at 200 px and that
          // cap is the row's largest un-shrinkable child.
          _Account.hostedConnected => const CalendarConnection(
            connected: true,
            email: 'ada.lovelace@a-rather-long-company-name.example',
          ),
        },
      ),
    );
    addTearDown(calVm.dispose);

    await pumpAt(
      tester,
      width,
      MultiProvider(
        providers: [
          Provider<Services>.value(
            value: FakeServices(isHosted: account != _Account.selfHosted),
          ),
          ChangeNotifierProvider<TaskCalendarViewModel>.value(value: vm),
          ChangeNotifierProvider<CalendarConnectionViewModel>.value(
            value: calVm,
          ),
        ],
        // The bool the host screen would compute for this pane width, so the
        // sweep exercises the real pairing rather than a hand-picked branch.
        child: TaskCalendarHeader(
          wide: width >= Breakpoints.wide,
          formatter: formatter,
        ),
      ),
      scroll: false,
      textScale: textScale,
    );
  }

  /// The month label must be readable, not merely un-overflowed.
  ///
  /// This is the assertion the first version of this file lacked, and the gap
  /// mattered: moving the label into an `Expanded` converts an overflow into
  /// *starvation*, which throws nothing. At a 602 px pane (an iPad in portrait)
  /// the wide chrome's fixed children left the label 22 px and it ellipsised to
  /// "…" with the sweep still green. Same idiom as
  /// `clients/add_comment_dialog_test.dart:88-91`.
  void expectLabelWhole(WidgetTester tester) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.textContaining('2026'),
        matching: find.byType(RichText),
      ),
    );
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'the month label is ellipsised — the row starved it',
    );
  }

  /// Widths at which the month label cannot survive whole, and why — the row
  /// keeps every control and truncates the month, which is the same trade the
  /// daily and weekly headers make with their own labels.
  ///
  /// All three are phones with the account control present. Measured with the
  /// bundled font: five 48 px icon buttons (both chevrons, the events toggle,
  /// the compact account trigger, Today) plus 48 px of gutters and two gaps is
  /// 308 px, so a 320 px pane has 12 px left for a label that wants 70 ("Sep
  /// 2026" at 1x) to 97 (at 1.4x), and a 360 px one has 52. Self-hosted is
  /// absent from the set at every width because `CalendarConnectMenu` paints
  /// nothing there, which is exactly why self-hosted never met the bug.
  ///
  /// Narrowing the 24 px gutters would buy 320 px back — declined in Part 1 of
  /// this issue, because they align this row with the AppBar above it.
  final starved = {
    (320.0, _Account.hostedDisconnected),
    (320.0, _Account.hostedConnected),
    (360.0, _Account.hostedConnected),
  };

  // 320-412 is the phone range; 600-832 is the band where the rail is up but
  // the pane is still narrow, which is where the un-shrinkable connected chip
  // used to starve the label. 832 is the control at the top of that band.
  for (final account in _Account.values) {
    for (final width in const [
      320.0,
      360.0,
      412.0,
      600.0,
      648.0,
      700.0,
      832.0,
    ]) {
      for (final scale in const [1.0, kTextScaleMax]) {
        testWidgets('fits ${width.toInt()} px at ${scale}x — ${account.name}', (
          tester,
        ) async {
          await pumpHeader(
            tester,
            width: width,
            account: account,
            textScale: scale,
          );
          expectNoOverflow(tester);
          if (!starved.contains((width, account))) expectLabelWhole(tester);
        });
      }
    }
  }

  testWidgets('a 700 px pane keeps the wide chrome but pockets the address', (
    tester,
  ) async {
    // The gate that replaced the `Flexible`: the account chip is all-or-
    // nothing, and 700 px is wide chrome (full month name, labelled Today)
    // whose content box is still 48 px short of the 669 the inline chip needs
    // at 1x. Making the chip shrink instead is what starved the label.
    await pumpHeader(tester, width: 700, account: _Account.hostedConnected);

    expect(find.text('September 2026'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Today'), findsOneWidget);
    expect(find.textContaining('ada.lovelace@'), findsNothing);
    expect(find.byIcon(Icons.event_available), findsOneWidget);
  });

  // 744 px is the pane that straddles the threshold, so the pair below is the
  // only place the *scaling* half of it is visible: 524 + 145 = 669 px of
  // content at 1x, which 744 - 48 clears, against 524 + 203 = 727 at 1.4x,
  // which it does not. Nothing else about the row changes between them.
  testWidgets('the address rides inline as soon as the label still fits', (
    tester,
  ) async {
    await pumpHeader(tester, width: 744, account: _Account.hostedConnected);

    expect(find.textContaining('ada.lovelace@'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expectNoOverflow(tester);
  });

  testWidgets('the same pane pockets it at the largest text scale', (
    tester,
  ) async {
    // The month label is the only part of this row that grows with text size,
    // so it is the label the threshold is sized for — and the invariant that
    // buys is one-directional: on the wide branch the address steps back into
    // its menu rather than the month giving way.
    await pumpHeader(
      tester,
      width: 744,
      account: _Account.hostedConnected,
      textScale: kTextScaleMax,
    );

    expect(find.textContaining('ada.lovelace@'), findsNothing);
    expect(find.byIcon(Icons.event_available), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expectNoOverflow(tester);
  });

  group('the month label uses the locale\'s own month-year form', () {
    // A literal `DateFormat('MMMM yyyy', locale)` fixes the field order and
    // drops the locale's connectives, and four of the eleven bundled locales
    // disagree with it — two of them by rendering a backwards date. Each row
    // below is a string the literal pattern could not produce, so this table
    // fails against it.
    const cases = {
      'en': 'September 2026',
      'es': 'septiembre de 2026',
      'pt_BR': 'setembro de 2026',
      'ja': '2026年9月',
      'zh_CN': '2026年9月',
    };
    cases.forEach((locale, expected) {
      testWidgets(locale, (tester) async {
        await pumpHeader(
          tester,
          // Wide, since the abbreviated form is the same in several of these
          // and the full month is where the grammar shows.
          width: 1200,
          account: _Account.selfHosted,
          formatter: _formatterFor(locale),
        );
        expect(find.text(expected), findsOneWidget);
      });
    });

    testWidgets('and the abbreviated form on a phone', (tester) async {
      // Portuguese is the widest narrow label of the eleven at 90 px, against
      // English's 70 — which is why the phone truncation the sweep documents
      // starts one size class earlier outside English.
      await pumpHeader(
        tester,
        width: 412,
        account: _Account.selfHosted,
        formatter: _formatterFor('pt_BR'),
      );
      expect(find.text('set. de 2026'), findsOneWidget);
      expectNoOverflow(tester);
    });
  });

  testWidgets('narrow keeps every control, just not their labels', (
    tester,
  ) async {
    await pumpHeader(tester, width: 412, account: _Account.hostedConnected);

    // Month, both chevrons, the events toggle, the account menu and Today all
    // survive the collapse — the point is to shed labels, not affordances.
    expect(find.textContaining('2026'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byTooltip('Today'), findsOneWidget);
    // The *glyph*, never `find.byType(CalendarConnectMenu)`: that widget is
    // mounted in every state, including the two where it returns
    // `SizedBox.shrink()`, so a type finder passes even when the control is
    // gone — which is the one thing this test is here to notice.
    expect(find.byIcon(Icons.event_available), findsOneWidget);
  });

  testWidgets('wide keeps the full month name and the labelled buttons', (
    tester,
  ) async {
    await pumpHeader(tester, width: 1200, account: _Account.hostedConnected);

    expect(find.text('September 2026'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Today'), findsOneWidget);
    // The wide chip shows the connected address inline.
    expect(
      find.textContaining('ada.lovelace@'),
      findsOneWidget,
      reason: 'the wide branch must keep the account visible',
    );
    expectNoOverflow(tester);
  });

  testWidgets('self-hosted renders no account control at all', (tester) async {
    await pumpHeader(tester, width: 412, account: _Account.selfHosted);
    // `CalendarConnectMenu.isAvailable` is hosted-only, so the widget mounts
    // but paints nothing — which is why self-hosted never met the worst case.
    // Measure it rather than naming a glyph: an absent
    // `Icons.event_available_outlined` is equally true of the *connected*
    // state, so that assertion could never have failed for the right reason.
    expect(tester.getSize(find.byType(CalendarConnectMenu)), Size.zero);
    expect(find.byIcon(Icons.event_available), findsNothing);
    expect(find.byIcon(Icons.event_available_outlined), findsNothing);
    expectNoOverflow(tester);
  });

  testWidgets('the compact account control keeps the address and Disconnect '
      'one tap away', (tester) async {
    // The whole reason compact is an icon *plus a menu*: this header is the
    // only place in the app that shows which calendar account is connected and
    // the only place to disconnect it, so a tooltip would have hidden the
    // address behind a long-press on the one platform that collapses the row.
    await pumpHeader(tester, width: 412, account: _Account.hostedConnected);

    expect(
      find.textContaining('ada.lovelace@'),
      findsNothing,
      reason: 'the address is not inline on narrow — that is the 280 px saved',
    );

    await tester.tap(find.byIcon(Icons.event_available));
    await tester.pumpAndSettle();

    expect(find.textContaining('ada.lovelace@'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);

    // Routed to the *existing* confirm, not to a bare `disconnect()`: the
    // compact branch is a second call site for `_confirmDisconnect`, and
    // nothing about `onSelected` would fail if it had been wired straight to
    // the view model — the calendar would simply detach on one tap.
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure?'), findsOneWidget);
  });

  testWidgets('the compact control still offers both providers when '
      'disconnected', (tester) async {
    await pumpHeader(tester, width: 412, account: _Account.hostedDisconnected);

    await tester.tap(find.byIcon(Icons.event_available_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Microsoft'), findsOneWidget);
  });
}
