import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/list_density_controller.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/list_status_tabs.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/entity_list_status_tabs.dart';
import 'package:admin/ui/core/list/list_density_scope.dart';
import 'package:admin/ui/features/expense_categories/widgets/expense_category_list_tile.dart';

import '../../../_localization_helper.dart';

/// The Normal / Compact list density (docs/list-density.md), measured on real
/// rows: Normal must stay exactly what every list rendered before Compact
/// existed, and Compact must reach its floor without undercutting a touch
/// target. `flutter_test` defaults to Android (touch), so the pointer cases
/// run as macOS.
void main() {
  final pointer = TargetPlatformVariant.only(TargetPlatform.macOS);

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

  /// [scoped] false pumps with no [ListDensityScope] at all — what every
  /// other widget test in the repo does.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool scoped = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        builder: (context, inner) => scoped
            ? ListDensityScope(controller: density, child: inner!)
            : inner!,
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
    await tester.pump();
  }

  const rowKey = Key('row');
  Widget row({bool wide = true}) => EntityListRowFloor(
    key: rowKey,
    child: ExpenseCategoryListTile(
      category: emptyExpenseCategory().copyWith(name: 'Travel'),
      columns: const [],
      wide: wide,
      onTap: () {},
    ),
  );

  double rowHeight(WidgetTester tester) =>
      tester.getSize(find.byKey(rowKey)).height;

  group('row floor', () {
    testWidgets('Normal, and no scope at all, keep the 72 px floor', (
      tester,
    ) async {
      await pump(tester, row(), scoped: false);
      expect(rowHeight(tester), kEntityListRowHeight);

      await pump(tester, row());
      expect(density.isCompact, isFalse);
      expect(rowHeight(tester), kEntityListRowHeight);
    });

    testWidgets('Compact is 40 px with a pointer', (tester) async {
      await density.setCompact(true);
      await pump(tester, row());
      expect(rowHeight(tester), 40);
    }, variant: pointer);

    testWidgets('Compact is 52 px on touch — the 44 px targets win', (
      tester,
    ) async {
      await density.setCompact(true);
      await pump(tester, row());
      expect(actionButtonSize(), InSizes.touchTarget);
      expect(rowHeight(tester), InSizes.touchTarget + 8);
    });

    testWidgets('a flip reflows mounted rows live', (tester) async {
      await pump(tester, row());
      expect(rowHeight(tester), kEntityListRowHeight);
      await density.toggle();
      await tester.pump();
      expect(rowHeight(tester), 40);
    }, variant: pointer);

    testWidgets('Compact grows past the floor rather than clipping', (
      tester,
    ) async {
      await density.setCompact(true);
      await pump(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: row(wide: false),
          ),
        ),
      );
      final box = tester.renderObject<RenderBox>(find.byKey(rowKey));
      expect(
        box.size.height,
        greaterThanOrEqualTo(box.getMaxIntrinsicHeight(box.size.width)),
      );
      expect(box.size.height, greaterThan(40));
    }, variant: pointer);
  });

  group('status tabs', () {
    final tabs = listStatusTabsFor(
      EntityType.invoice,
      modes: kInvoiceBadgeModes,
      trackInventory: false,
    );
    const stripKey = Key('strip');
    Widget strip({required bool dense, bool wrap = false}) => SizedBox(
      width: 1100,
      child: EntityListStatusTabs(
        key: stripKey,
        tabs: tabs,
        dense: dense,
        wrap: wrap,
        selectedIndex: 0,
        showCounts: false,
        streamKey: 'invoice:co',
        countStream: (_) => Stream<int>.value(0),
        onTap: (_) {},
      ),
    );

    testWidgets('a dense strip is shorter on a pointer', (tester) async {
      await pump(tester, strip(dense: false));
      final normal = tester.getSize(find.byKey(stripKey)).height;
      await pump(tester, strip(dense: true));
      final dense = tester.getSize(find.byKey(stripKey)).height;
      // `InSpacing.md` is 12 at this width, `sm` 8: 4 px off each side.
      expect(dense, normal - 8);
    }, variant: pointer);

    testWidgets(
      'dense is a parameter: Compact in scope changes nothing alone',
      (tester) async {
        // The strip never reads the scope, so a host that doesn't pass `dense:`
        // — the dashboard's wrapped strip — is untouched by Compact. That only
        // the list scaffold passes it is pinned by
        // `test/lint/list_row_density_wiring_test.dart`.
        await pump(tester, strip(dense: false, wrap: true), scoped: false);
        final before = tester.getSize(find.byKey(stripKey)).height;
        await density.setCompact(true);
        await pump(tester, strip(dense: false, wrap: true));
        expect(tester.getSize(find.byKey(stripKey)).height, before);
      },
      variant: pointer,
    );
  });

  group('table card inset', () {
    test('Compact trims only the vertical inset', () {
      // The horizontal 24 lines the card up with the header band's row, the
      // status-tab strip and the desktop title bar's arrows.
      for (final compact in [false, true]) {
        final inset = entityListCardInset(compact: compact);
        expect(inset.start, 24);
        expect(inset.end, 24);
      }
      expect(entityListCardInset(compact: false).top, 24);
      expect(entityListCardInset(compact: false).bottom, 24);
      expect(entityListCardInset(compact: true).top, 12);
      expect(entityListCardInset(compact: true).bottom, 12);
    });
  });
}
