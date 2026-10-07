// The list header grows with its search field.
//
// It used to be a Material `AppBar` with a fixed `toolbarHeight`: the search
// row got 45 px however many filter chips it held. A second line of chips was
// laid out anyway, painted outside the box over the first rows of the table,
// and — being outside the bar — could not be clicked. Measured before the
// change: on desktop the wrapped input sat at y 47..79 in a 69 px header; on
// a touch platform a single chip (17..67) already overran its 45 px box.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/ui/core/list/entity_list_app_bar.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_menu.dart';
import 'package:admin/ui/core/list/search/filter_token_chip.dart';
import 'package:admin/ui/core/list/search/token_search_field.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';
import 'search/_token_search_harness.dart';

const _bodyKey = Key('body');
const _surface = Size(1100, 700);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  final both = TargetPlatformVariant(const {
    TargetPlatform.macOS,
    TargetPlatform.android,
  });

  Future<void> pumpHeader(
    WidgetTester tester, {
    required GenericListViewModel<dynamic> vm,
    required ValueListenable<bool> selecting,
    bool wide = true,
    Size surface = _surface,
    double? maxExtent,
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Provider<Services>.value(
          value: FakeSearchServices(),
          child: ValueListenableBuilder<bool>(
            valueListenable: selecting,
            builder: (context, isSelecting, _) => Scaffold(
              appBar: EntityListAppBar<dynamic>(
                vm: vm,
                wide: wide,
                selecting: isSelecting,
                maxExtent:
                    maxExtent ??
                    EntityListAppBar.maxExtentFor(
                      wide: wide,
                      available: surface.height,
                    ),
                titleKey: 'clients',
                newRoute: '/clients/new',
                newLabelKey: 'new_client',
                sortOptions: const [],
                // The wide field in either header: a 600–832 px window gets
                // the narrow bar with the inline field.
                searchField: TokenSearchField(
                  vm: vm,
                  filterKeys: [FruitKey()],
                  wide: true,
                  hintKey: 'search',
                ),
              ),
              body: const SizedBox.expand(key: _bodyKey),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // Ends by letting the view model's debounced `nav_state` write fire.
  void headerTest(
    String description,
    Future<void> Function(WidgetTester tester) body, {
    TestVariant<Object?>? variant,
  }) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pump(const Duration(seconds: 1));
    }, variant: variant ?? both);
  }

  Finder header() => find.byType(EntityListAppBar<dynamic>);
  Finder field() => find.byType(TokenSearchField);
  Finder columns() => find.widgetWithText(OutlinedButton, 'Columns');

  Future<void> seed(
    WidgetTester tester,
    HarnessVm vm,
    Set<String> values,
  ) async {
    await vm.setExtraFilter(serverKey: 'fruit_id', values: values);
    await tester.pump();
    await tester.pump();
  }

  headerTest('with nothing wrapped it is the shared band, on every platform', (
    tester,
  ) async {
    final vm = newHarnessVm(db);
    await pumpHeader(tester, vm: vm, selecting: ValueNotifier(false));

    expect(tester.getSize(header()).height, InSizes.headerBand);
    expect(tester.getTopLeft(find.byKey(_bodyKey)).dy, InSizes.headerBand);
    // The box is exactly the header row, with the band's 12 px either side.
    final box = tester.getRect(field());
    expect(box.top, 12);
    expect(box.height, InSizes.headerRow);

    // One chip still fits one line — it used to overrun the box on touch,
    // where its ✕ was padded to 40 px square.
    await seed(tester, vm, {'a'});
    expect(tester.getSize(header()).height, InSizes.headerBand);
    final chip = tester.getRect(find.byType(FilterTokenChip));
    final boxNow = tester.getRect(field());
    expect(chip.top, greaterThanOrEqualTo(boxNow.top));
    expect(chip.bottom, lessThanOrEqualTo(boxNow.bottom));
  });

  headerTest('grows when the chips wrap, and the body follows in the same '
      'frame', (tester) async {
    final vm = newHarnessVm(db);
    await pumpHeader(tester, vm: vm, selecting: ValueNotifier(false));
    final columnsBefore = tester.getRect(columns());

    await vm.setExtraFilter(serverKey: 'fruit_id', values: {'a', 'b', 'c'});
    // ONE pump: no measuring pass, no frame in which the chips overflow.
    await tester.pump();

    final bar = tester.getRect(header());
    final box = tester.getRect(field());
    final input = tester.getRect(find.byType(TextField));
    expect(bar.height, greaterThan(InSizes.headerBand));
    expect(tester.getTopLeft(find.byKey(_bodyKey)).dy, bar.bottom);
    // Everything the box holds is inside the box, and the box inside the bar.
    for (final e in find.byType(FilterTokenChip).evaluate()) {
      final chip = tester.getRect(find.byWidget(e.widget));
      expect(chip.bottom, lessThanOrEqualTo(box.bottom));
    }
    // The input wrapped onto a later line…
    final firstChip = tester.getRect(find.byType(FilterTokenChip).first);
    expect(input.top, greaterThan(firstChip.center.dy));
    expect(input.bottom, lessThanOrEqualTo(box.bottom));
    expect(box.bottom, bar.bottom - 12);
    // The buttons beside the box stay on its first line.
    expect(tester.getRect(columns()), columnsBefore);

    // The second line can be clicked: it was outside the bar's bounds.
    await tester.tap(find.byType(TextField).hitTestable());
    await tester.pump();
    await tester.pump();
    expect(find.byType(FilterSuggestionMenu), findsOneWidget);
  });

  headerTest('entering multi-select never changes its height', (tester) async {
    final vm = newHarnessVm(db);
    final selecting = ValueNotifier(false);
    await pumpHeader(tester, vm: vm, selecting: selecting);

    // One line.
    final single = tester.getSize(header()).height;
    selecting.value = true;
    await tester.pump();
    expect(tester.getSize(header()).height, single);
    expect(find.byIcon(Icons.close), findsWidgets);
    // The search box is still mounted — its state survives the selection —
    // just not on stage or reachable.
    expect(find.byType(TokenSearchField, skipOffstage: false), findsOneWidget);
    expect(field(), findsNothing);
    expect(find.byType(TextField).hitTestable(), findsNothing);

    // Wrapped: the selection chrome is as tall as what it covers, so the row
    // under the pointer does not move when it is ticked.
    selecting.value = false;
    await tester.pump();
    await seed(tester, vm, {'a', 'b', 'c'});
    final wrapped = tester.getSize(header()).height;
    expect(wrapped, greaterThan(single));
    selecting.value = true;
    await tester.pump();
    expect(tester.getSize(header()).height, wrapped);
    expect(tester.getTopLeft(find.byKey(_bodyKey)).dy, wrapped);
  });

  headerTest('the narrow bar grows too, without squeezing its title row', (
    tester,
  ) async {
    final vm = newHarnessVm(db);
    final selecting = ValueNotifier(false);
    const surface = Size(620, 700);
    await pumpHeader(
      tester,
      vm: vm,
      selecting: selecting,
      wide: false,
      surface: surface,
    );

    final floor = EntityListAppBar.minExtentFor(wide: false);
    expect(tester.getSize(header()).height, floor);
    final title = tester.getRect(find.text('Clients'));

    await seed(tester, vm, {'a', 'b', 'c'});
    final bar = tester.getRect(header());
    expect(bar.height, greaterThan(floor));
    expect(tester.getTopLeft(find.byKey(_bodyKey)).dy, bar.bottom);
    expect(tester.getRect(find.text('Clients')), title);
    expect(tester.getRect(field()).bottom, bar.bottom - 8);

    selecting.value = true;
    await tester.pump();
    expect(tester.getSize(header()).height, bar.height);
  });

  headerTest('the narrow bar scrolls at its ceiling too', (tester) async {
    final vm = newHarnessVm(db);
    // Room for the toolbar and one search row, no more.
    await pumpHeader(
      tester,
      vm: vm,
      selecting: ValueNotifier(false),
      wide: false,
      surface: const Size(620, 700),
      maxExtent: EntityListAppBar.minExtentFor(wide: false),
    );
    await seed(tester, vm, {'a', 'b', 'c'});

    final bar = tester.getRect(header());
    expect(bar.height, EntityListAppBar.minExtentFor(wide: false));
    expect(tester.getTopLeft(find.byKey(_bodyKey)).dy, bar.bottom);
    expect(tester.getRect(field()).bottom, lessThanOrEqualTo(bar.bottom));
    // The search row sat in a Column, which gave it unbounded height: it
    // never reached its scroll ceiling and overflowed the bar instead.
    expect(tester.takeException(), isNull);
  });

  headerTest('at its ceiling the box scrolls instead of spilling', (
    tester,
  ) async {
    final vm = newHarnessVm(db);
    // Room for the band and no more.
    await pumpHeader(
      tester,
      vm: vm,
      selecting: ValueNotifier(false),
      maxExtent: InSizes.headerBand,
    );
    await seed(tester, vm, {'a', 'b', 'c'});

    final bar = tester.getRect(header());
    expect(bar.height, InSizes.headerBand);
    expect(tester.getTopLeft(find.byKey(_bodyKey)).dy, bar.bottom);
    // Nothing is painted outside the box: every chip that can be hit is
    // inside it. (The old header left them over the list.)
    final box = tester.getRect(field());
    expect(box.bottom, lessThanOrEqualTo(bar.bottom));
    for (final e in find.byType(FilterTokenChip).hitTestable().evaluate()) {
      final chip = tester.getRect(find.byWidget(e.widget));
      expect(chip.top, lessThan(box.bottom));
    }
    expect(tester.takeException(), isNull);
  });
}
