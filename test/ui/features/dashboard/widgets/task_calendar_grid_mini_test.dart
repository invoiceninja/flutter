import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/dashboard/widgets/task_calendar_grid_mini.dart';
import 'package:admin/utils/date_ranges.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_responsive_helper.dart';

/// The pure half of the task-calendar panel: everything it renders arrives as a
/// parameter, so this file needs no `Services`, no repository double and no
/// stream — which is the point of the split (a widget test over a real Drift
/// watch hangs rather than failing).

/// Real metrics, not the test font. `flutter test` substitutes a square per
/// glyph, which roughly doubles every string — enough to turn a passing width
/// into a failing one and back.
Future<void> _loadFonts() async {
  await (FontLoader(kSansFontFamily)..addFont(
        Future.value(
          File(
            'assets/fonts/InterTight.ttf',
          ).readAsBytesSync().buffer.asByteData(),
        ),
      ))
      .load();
}

final _formatter = Formatter(
  settings: const CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: '5',
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: false,
    locale: 'en',
  ),
  currencies: const {},
  countries: const {},
  dateFormats: const {},
);

final _month = Date(2026, 6, 1);
final _today = Date(2026, 6, 15);

Widget _grid({
  Map<Date, Duration> loadByDay = const {},
  void Function(Date)? onDayTap,
  int firstDayOfWeek = 0,
}) => TaskCalendarGridMini(
  month: _month,
  gridDays: monthGridDays(_month, firstDayOfWeek),
  firstDayOfWeek: firstDayOfWeek,
  loadByDay: loadByDay,
  today: _today,
  formatter: _formatter,
  onDayTap: onDayTap ?? (_) {},
);

/// The cell's tint is painted by its own `Material`, so the fill colour is read
/// off that rather than off a decoration — which is also the thing that keeps
/// the ripple visible (ink features paint before the child subtree).
/// A day number can appear twice in one grid — June 2 and the July 2 that
/// spills into the last row — so [occurrence] picks which, in grid order.
Color _fillOfDay(WidgetTester tester, int day, {int occurrence = 0}) {
  final material = tester.widget<Material>(
    find
        .ancestor(
          of: find.text('$day').at(occurrence),
          matching: find.byType(Material),
        )
        .first,
  );
  // A free cell is `MaterialType.transparency` with a null colour — it skips
  // the canvas Material's two implicit animations, which 42 cells on the
  // landing route would otherwise pay for.
  return material.color ?? Colors.transparent;
}

Finder _barsInDay(int day) => find.descendant(
  of: find
      .ancestor(of: find.text('$day'), matching: find.byType(Material))
      .first,
  matching: find.byType(FractionallySizedBox),
);

/// The day cells format a date through `Formatter.date`, which builds a
/// `DateFormat` with an explicit locale — and intl ships only `en_US`
/// initialised. Production loads the rest via `GlobalMaterialLocalizations`
/// (`main.dart` installs that delegate); `kTestLocalizationsDelegates`
/// deliberately does not, so run the app's own path once here rather than
/// reaching for intl's `initializeDateFormatting()`, whose data is the full
/// CLDR set and therefore not what ships.
Future<void> _loadDateSymbols() =>
    GlobalMaterialLocalizations.delegate.load(const Locale('en'));

/// Non-linear like the Android 14+ system scaler: identity at 1 px, double
/// everywhere else. Exists to prove the extent is scaled directly rather than
/// multiplied by a factor sampled at a single point.
class _StepScaler extends TextScaler {
  const _StepScaler();

  @override
  double scale(double fontSize) => fontSize <= 1 ? fontSize : fontSize * 2;

  @override
  double get textScaleFactor => 2;
}

void main() {
  setUpAll(_loadFonts);
  setUpAll(_loadDateSymbols);

  testWidgets('renders a fixed 6×7 grid plus a weekday strip', (tester) async {
    await pumpAt(tester, 400, _grid());
    // Fixed at 42 whatever the month, so the card's height never jumps as the
    // user pages — February would otherwise be two rows shorter than August.
    expect(find.byType(InkWell), findsNWidgets(42));
    expectNoOverflow(tester);
  });

  testWidgets('a free day gets no fill and no bar', (tester) async {
    await pumpAt(tester, 400, _grid());
    expect(_fillOfDay(tester, 15), Colors.transparent);
    expect(_barsInDay(15), findsNothing);
  });

  testWidgets('each bucket takes its own status token', (tester) async {
    // Asserted by token identity, never a literal hex: the six presets carry
    // different values and a hex would pin one of them.
    final tokens = InTheme.light;
    await pumpAt(
      tester,
      400,
      _grid(
        loadByDay: {
          Date(2026, 6, 2): const Duration(hours: 2), // light
          Date(2026, 6, 3): const Duration(hours: 5), // limited
          Date(2026, 6, 4): const Duration(hours: 9), // full
        },
      ),
    );

    for (final (day, hue) in [
      (2, tokens.paid),
      (3, tokens.sent),
      (4, tokens.overdue),
    ]) {
      expect(
        _fillOfDay(tester, day),
        isNot(Colors.transparent),
        reason: 'day $day should be tinted',
      );
      final bar = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: _barsInDay(day),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((bar.decoration as BoxDecoration).color, hue);
    }
  });

  testWidgets('the bar length tracks the hours and clamps at a full day', (
    tester,
  ) async {
    await pumpAt(
      tester,
      400,
      _grid(
        loadByDay: {
          Date(2026, 6, 2): const Duration(hours: 2),
          Date(2026, 6, 3): const Duration(hours: 4),
          Date(2026, 6, 4): const Duration(hours: 8),
          Date(2026, 6, 5): const Duration(hours: 14),
        },
      ),
    );
    double factorOn(int day) =>
        tester.widget<FractionallySizedBox>(_barsInDay(day)).widthFactor!;

    expect(factorOn(2), closeTo(0.25, 1e-9));
    expect(factorOn(3), closeTo(0.5, 1e-9));
    expect(factorOn(4), 1);
    expect(
      factorOn(5),
      1,
      reason: 'over-booked clamps rather than overflowing',
    );
  });

  testWidgets('a ten-minute entry still draws a visible bar', (tester) async {
    await pumpAt(
      tester,
      400,
      _grid(loadByDay: {Date(2026, 6, 2): const Duration(minutes: 10)}),
    );
    expect(
      tester.widget<FractionallySizedBox>(_barsInDay(2)).widthFactor,
      greaterThanOrEqualTo(0.1),
    );
  });

  testWidgets('a spill day keeps its bar at full strength', (tester) async {
    // The panel exists to answer "can you do the 2nd?" — and early next month
    // lands in the spill row, so dimming the load there would fade exactly the
    // days it is for. Only the NUMBER steps back.
    await pumpAt(
      tester,
      400,
      _grid(loadByDay: {Date(2026, 7, 2): const Duration(hours: 9)}),
    );
    expect(find.byType(Opacity), findsNothing);
    // The SECOND "2" in the grid is July's; June's own 2nd is free.
    expect(_fillOfDay(tester, 2), Colors.transparent);
    expect(_fillOfDay(tester, 2, occurrence: 1), isNot(Colors.transparent));
  });

  testWidgets('today is marked, and its digits use onAccent', (tester) async {
    // The A9 contrast fix had no test at all: reverting the marker to
    // `accentInk` — a ~2:1 pairing against the accent it sits on — left the
    // whole suite green. Asserted by token identity, not a hex, so a user's
    // accent override moves both together.
    final tokens = InTheme.light;
    await pumpAt(tester, 400, _grid());

    final marker = tester.widget<Container>(
      find
          .ancestor(of: find.text('15'), matching: find.byType(Container))
          .first,
    );
    expect((marker.decoration! as BoxDecoration).color, tokens.accent);
    expect((marker.decoration! as BoxDecoration).shape, BoxShape.circle);

    final digits = tester.widget<Text>(find.text('15'));
    expect(digits.style!.color, tokens.onAccent);
    expect(
      digits.style!.color,
      isNot(tokens.accentInk),
      reason: 'accentInk on accent is the ~2:1 pairing this replaced',
    );
  });

  testWidgets('an ordinary day gets no marker', (tester) async {
    // The negative control: without it the assertion above would pass against
    // an implementation that circled every cell.
    await pumpAt(tester, 400, _grid());
    expect(
      find.ancestor(of: find.text('16'), matching: find.byType(Container)),
      findsNothing,
    );
  });

  testWidgets('tapping a day reports that day', (tester) async {
    Date? tapped;
    await pumpAt(tester, 400, _grid(onDayTap: (d) => tapped = d));
    await tester.tap(find.text('15'));
    expect(tapped, Date(2026, 6, 15));
  });

  testWidgets('a cell is a button a screen reader can actually activate', (
    tester,
  ) async {
    // `excludeSemantics` drops the descendant InkWell's tap ACTION along with
    // its text node, so the wrapper has to re-declare it — otherwise the cell
    // announces as a button that cannot be invoked.
    final handle = tester.ensureSemantics();
    await pumpAt(
      tester,
      400,
      _grid(
        loadByDay: {Date(2026, 6, 15): const Duration(hours: 5, minutes: 30)},
      ),
    );

    final node = tester.getSemantics(
      find
          .ancestor(of: find.text('15'), matching: find.byType(Semantics))
          .first,
    );
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    // Decimal hours with a unit — `5:30` would be read as a clock time.
    expect(data.label, contains('5.5'));
    expect(data.label, contains('booked'));
    handle.dispose();
  });

  testWidgets('a free day says so rather than announcing zero', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAt(tester, 400, _grid());
    final node = tester.getSemantics(
      find
          .ancestor(of: find.text('15'), matching: find.byType(Semantics))
          .first,
    );
    expect(node.label, contains('Free'));
    expect(node.label, isNot(contains('booked')));
    handle.dispose();
  });

  group('no overflow across widths and text scales', () {
    for (final width in const [320.0, 360.0, 412.0, 440.0, 570.0]) {
      for (final scale in const [1.0, kTextScaleMax]) {
        testWidgets('at ${width.toInt()}px × $scale', (tester) async {
          await pumpAt(
            tester,
            width,
            _grid(
              loadByDay: {
                for (var d = 1; d <= 30; d++)
                  Date(2026, 6, d): Duration(hours: d % 10),
              },
            ),
            textScale: scale,
          );
          expectNoOverflow(tester);
        });
      }
    }
  });

  group('miniCalendarCellExtent', () {
    // Asserted as a pure function: `Env.isTouchPrimary` is always true under
    // `flutter test`, so no widget test in this repo could ever see the
    // pointer-platform branch.
    test('grows on touch and scales with the user text size', () {
      expect(
        miniCalendarCellExtent(touch: true, scaler: TextScaler.noScaling),
        greaterThan(
          miniCalendarCellExtent(touch: false, scaler: TextScaler.noScaling),
        ),
      );
      expect(
        miniCalendarCellExtent(
          touch: true,
          scaler: const TextScaler.linear(kTextScaleMax),
        ),
        closeTo(
          miniCalendarCellExtent(touch: true, scaler: TextScaler.noScaling) *
              1.4,
          1e-9,
        ),
      );
    });

    test('scales the extent, never a factor sampled at 1 px', () {
      // A non-linear scaler is the whole reason this takes a `TextScaler`:
      // `scale(1)` would read 1.0 here and leave the cell unscaled while the
      // 12 px numbers inside it grew.
      const nonLinear = _StepScaler();
      expect(nonLinear.scale(1), 1.0);
      expect(
        miniCalendarCellExtent(touch: true, scaler: nonLinear),
        miniCalendarCellExtent(touch: true, scaler: TextScaler.noScaling) * 2,
      );
    });
  });
}
