// The phone form of the record layout (invoiceninja/flutter#187,
// `docs/detail-screen-layout.md` § The phone record layout): the same order,
// denser — and only on a phone. Every case runs both ways, because the
// pointer layout must not move.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/list_density_controller.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/record_timestamps.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/core/list/list_density_scope.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';

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

// Midday UTC, so the local calendar day is the same from UTC-11 to UTC+10.
final _created = DateTime.utc(2025, 5, 17, 12);
final _updated = DateTime.utc(2025, 11, 25, 12);

/// A phone: touch-primary at 390 × 844. Otherwise a 1200 px desktop window.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required bool phone,
  ListDensityController? density,
}) async {
  debugDefaultTargetPlatformOverride = phone
      ? TargetPlatform.android
      : TargetPlatform.macOS;
  // The view, not `setSurfaceSize`: `Breakpoints.isPhone` reads the
  // MediaQuery, which `setSurfaceSize` leaves at 800 × 600.
  tester.view.physicalSize = phone
      ? const Size(390, 844)
      : const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      builder: (context, inner) => density == null
          ? inner!
          : ListDensityScope(controller: density, child: inner!),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [child],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

EntityDetailHeader _header() => EntityDetailHeader(
  seedForAvatar: 'seed',
  displayName: 'Alpha Construction',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  isDeleted: false,
  isArchived: false,
  isDirty: false,
);

/// A header row of rows, so the test can see what `recordTimestampRows` gave.
class _Rows extends StatelessWidget {
  const _Rows();

  @override
  Widget build(BuildContext context) => Column(
    children: recordTimestampRows(
      context,
      createdAt: _created,
      updatedAt: _updated,
      formatter: _formatter,
    ),
  );
}

StandingCard _card({VoidCallback? onRate}) => StandingCard(
  primary: const [
    StandingFigure(label: 'Duration', value: '17:15:00'),
    StandingFigure(label: 'Amount', value: r'$1,863.00'),
  ],
  secondary: [StandingFigure(label: 'Rate', value: r'$108.00', onTap: onRate)],
  footnote: const Padding(
    padding: EdgeInsets.only(top: kStandingFootnoteGap),
    child: Text('In progress'),
  ),
);

/// `testWidgets` that clears the platform override before the framework's
/// end-of-test invariant check, which a `tearDown` runs too late for.
void _test(String description, Future<void> Function(WidgetTester) body) =>
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

void main() {
  group('header', () {
    _test('a phone keeps the avatar: it costs width, not height', (
      tester,
    ) async {
      await _pump(tester, _header(), phone: true);
      // The initials are the avatar's only text.
      expect(find.text('AC'), findsOneWidget);
    });

    _test('detailHeaderLeadingInset is the avatar and its gap', (tester) async {
      double? inset;
      Widget probe() => Builder(
        builder: (context) {
          inset = detailHeaderLeadingInset(context);
          return const SizedBox.shrink();
        },
      );
      await _pump(tester, probe(), phone: true);
      expect(inset, greaterThan(kDetailHeaderAvatarSize));
    });
  });

  group('created / updated', () {
    _test('a phone has one line and no rows', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            const _Rows(),
            RecordTimestampsLine(
              createdAt: _created,
              updatedAt: _updated,
              formatter: _formatter,
            ),
          ],
        ),
        phone: true,
      );
      expect(find.byType(DetailInfoRow), findsNothing);
      expect(find.textContaining('17/May/2025'), findsOneWidget);
      expect(find.textContaining('25/Nov/2025'), findsOneWidget);
      // One line holds both.
      expect(
        find.textContaining(RegExp('17/May/2025.*25/Nov/2025')),
        findsOneWidget,
      );
    });

    _test('a pointer keeps the rows and draws no line', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            const _Rows(),
            RecordTimestampsLine(
              createdAt: _created,
              updatedAt: _updated,
              formatter: _formatter,
            ),
          ],
        ),
        phone: false,
      );
      expect(find.byType(DetailInfoRow), findsNWidgets(2));
      expect(
        find.textContaining(RegExp('17/May/2025.*25/Nov/2025')),
        findsNothing,
      );
    });
  });

  group('standing card', () {
    _test('a phone puts the secondaries and the footnote on one line', (
      tester,
    ) async {
      await _pump(tester, _card(), phone: true);
      expect(find.byType(Divider), findsNothing);
      final rate = tester.getRect(find.text(r'$108.00'));
      final status = tester.getRect(find.text('In progress'));
      expect(
        (rate.center.dy - status.center.dy).abs(),
        lessThan(6),
        reason: 'the figure and the footnote share a run',
      );
      expect(
        tester.getTopLeft(find.text('Rate')).dx,
        lessThan(status.left),
        reason: 'the secondaries lead: an empty footnote must not indent them',
      );
    });

    _test('a pointer keeps the divided secondary row', (tester) async {
      await _pump(tester, _card(), phone: false);
      expect(find.byType(Divider), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(r'$108.00')).dy,
        greaterThan(tester.getBottomLeft(find.text('In progress')).dy),
      );
    });

    _test('on a phone only a secondary that leads somewhere keeps the '
        'touch floor', (tester) async {
      await _pump(tester, _card(), phone: true);
      final copyOnly = tester.getSize(find.byType(StandingCard)).height;
      await _pump(tester, _card(onRate: () {}), phone: true);
      final tappable = tester.getSize(find.byType(StandingCard)).height;
      expect(tappable - copyOnly, greaterThan(10));
      final rateRow = find.ancestor(
        of: find.text('Rate'),
        matching: find.byType(InkWell),
      );
      expect(
        tester.getSize(rateRow.first).height,
        greaterThanOrEqualTo(InSizes.touchTarget),
      );
    });
  });

  group('the gap above the dates line', () {
    // The line's top relative to the standing card's foot, with [profile]
    // between them.
    Future<double> lineGap(WidgetTester tester, Widget profile) async {
      await _pump(
        tester,
        EntityRecordColumn(
          header: const Text('Name'),
          standing: const SizedBox(key: Key('standing'), height: 40),
          profile: profile,
          timestamps: RecordTimestampsLine(
            createdAt: _created,
            updatedAt: _updated,
            formatter: _formatter,
          ),
        ),
        phone: true,
      );
      final above = find.byKey(const Key('card')).evaluate().isEmpty
          ? find.byKey(const Key('standing'))
          : find.byKey(const Key('card'));
      return tester.getTopLeft(find.textContaining('Created')).dy -
          tester.getBottomLeft(above).dy;
    }

    _test('is the same under a card as under the standing card', (
      tester,
    ) async {
      final underCard = await lineGap(
        tester,
        const SizedBox(key: Key('card'), height: 60),
      );
      final underStanding = await lineGap(tester, const SizedBox.shrink());
      expect(underCard, greaterThan(InSpacing.sm));
      expect(
        underCard,
        underStanding,
        reason: 'an empty profile pays no gap; a drawn one pays the same one',
      );
    });
  });

  _test('a dates line that draws nothing costs the profile no gap', (
    tester,
  ) async {
    // A record created offline: epoch-0 dates until its create syncs.
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    await _pump(
      tester,
      EntityRecordColumn(
        header: const Text('Name'),
        profile: const SizedBox(key: Key('card'), height: 60),
        timestamps: RecordTimestampsLine(
          createdAt: epoch,
          updatedAt: epoch,
          formatter: _formatter,
        ),
      ),
      phone: true,
    );
    expect(
      tester.getBottomLeft(find.byType(EntityRecordColumn)).dy,
      tester.getBottomLeft(find.byKey(const Key('card'))).dy,
    );
  });

  _test('a vendor\'s last login joins the dates line', (tester) async {
    await _pump(
      tester,
      RecordTimestampsLine(
        createdAt: _created,
        updatedAt: _updated,
        lastLogin: DateTime.utc(2025, 11, 30, 12),
        formatter: _formatter,
      ),
      phone: true,
    );
    expect(
      find.textContaining(RegExp('Last.login.30/Nov/2025')),
      findsOneWidget,
    );
  });

  _test('on a phone a copy-only secondary copies on long-press, never a tap', (
    tester,
  ) async {
    await _pump(tester, _card(), phone: true);
    final copy = tester.widget<CopyableValue>(
      find.ancestor(
        of: find.text(r'$108.00'),
        matching: find.byType(CopyableValue),
      ),
    );
    expect(copy.enableTapToCopy, isFalse);
    expect(copy.enableLongPressToCopy, isTrue);
  });

  group('Compact density', () {
    late AppDatabase db;
    late ListDensityController density;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      final prefs = DevicePrefsStore(db);
      await prefs.load();
      density = ListDensityController(prefs: prefs);
    });
    tearDown(() async {
      density.dispose();
      await db.close();
    });

    EntityQuickActions<String> tiles() => EntityQuickActions<String>(
      priority: [
        EntityQuickAction(
          item: EntityActionItem<String>(
            kind: 'invoice',
            label: 'Invoice',
            icon: Icons.receipt_long_outlined,
            enabled: true,
            onTap: () {},
          ),
          shortLabel: 'Invoice',
        ),
      ],
    );

    double tileHeight(WidgetTester tester) =>
        tester.getSize(find.byType(InkWell).first).height;

    _test('shortens the tiles, still above the touch target', (tester) async {
      await _pump(tester, tiles(), phone: true, density: density);
      final normal = tileHeight(tester);
      await tester.runAsync(() => density.setCompact(true));
      await tester.pump();
      final compact = tileHeight(tester);
      expect(normal, greaterThanOrEqualTo(kQuickTileHeight));
      expect(compact, lessThan(normal));
      expect(compact, greaterThanOrEqualTo(InSizes.touchTarget));
    });

    _test('tightens the standing card', (tester) async {
      await _pump(tester, _card(), phone: true, density: density);
      final normal = tester.getSize(find.byType(StandingCard)).height;
      await tester.runAsync(() => density.setCompact(true));
      await tester.pump();
      expect(
        tester.getSize(find.byType(StandingCard)).height,
        lessThan(normal),
      );
    });
  });
}
