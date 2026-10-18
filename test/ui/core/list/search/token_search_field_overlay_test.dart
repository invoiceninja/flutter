// Behaviour of the real wide `TokenSearchField`: where its popup lands, and
// what typing, Enter, Tab, Escape, Backspace and a click actually do.
//
// Every test here failed against the field as it was. See
// `_token_search_harness.dart` for why the host has a second Overlay and why
// nothing calls `pumpAndSettle`.

import 'dart:ui';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_token_chip.dart';
import 'package:admin/ui/core/list/search/segment_menu.dart';
import 'package:admin/ui/features/clients/client_filter_keys.dart';
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '_token_search_harness.dart';

const _dateKey = DateColumnFilterKey(
  id: 'date',
  serverKey: 'date',
  labelKey: 'date',
  isPrimary: true,
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  // A pointer platform: 40 px rows, the key-hint footer, hover.
  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  // Every test ends by letting the view model's debounced `nav_state` write
  // fire. It is a Timer, and a widget test that ends with one pending fails.
  void fieldTest(
    String description,
    Future<void> Function(WidgetTester tester) body, {
    TestVariant<Object?>? variant,
  }) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pump(const Duration(seconds: 1));
    }, variant: variant ?? desktop);
  }

  String boxText(WidgetTester tester) =>
      tester.widget<TextField>(inputFinder).controller!.text;

  FocusNode boxFocus(WidgetTester tester) =>
      tester.widget<TextField>(inputFinder).focusNode!;

  Finder inMenu(String text) =>
      find.descendant(of: menuFinder, matching: find.text(text));

  group('popup placement', () {
    fieldTest('opens under the start of the input, in the Overlay that hosts '
        'it', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: const [IsFilterKey(), NameFilterKey()],
      );

      await tester.tap(inputFinder);
      await settleMenu(tester);

      final field = tester.getRect(fieldFinder);
      final input = tester.getRect(inputFinder);
      final menu = tester.getRect(menuFinder);
      // The harness puts the list's Overlay 232 px in, as the shell does. A
      // placement that forgot the Overlay's origin lands 232 px to the right.
      expect(field.left, kHarnessSidebar + 24);
      expect(menu.left, moreOrLessEquals(input.left - 12, epsilon: 0.01));
      expect(menu.top, moreOrLessEquals(field.bottom + 4, epsilon: 0.01));
    });

    fieldTest('re-opening on existing text anchors at its START, not at the '
        'caret', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [IsFilterKey()]);

      await tester.enterText(inputFinder, 'acme corporation');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(menuFinder, findsNothing, reason: 'Enter commits and closes');

      // Click at the END of the term, which puts the caret there.
      final input = tester.getRect(inputFinder);
      await tester.tapAt(input.centerRight - const Offset(3, 0));
      await settleMenu(tester);

      expect(
        tester.getRect(menuFinder).left,
        moreOrLessEquals(input.left - 12, epsilon: 0.01),
        reason: 'the menu used to hang from the caret, a text-width away',
      );
    });

    fieldTest('editing a chip positions the popup in the SAME frame', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: const [IsFilterKey(), NameFilterKey()],
        // Wide enough that the in-box clamp is not what places the popup.
        fieldWidth: 1000,
      );
      await const NameFilterKey().addValue(vm, 'acme');
      await settleMenu(tester);

      // The Name chip reads `contains "acme"`.
      await tester.tap(find.textContaining('"acme"'));
      // One pump. The tap writes `acme` into the box behind a Name key chip,
      // which moves and resizes the input; a popup placed from the previous
      // frame's geometry is still where the input WAS.
      await tester.pump();

      expect(boxText(tester), 'acme');
      // The token starts at the key chip in front of the text.
      final token = tester.getRect(find.byType(PendingKeyChip));
      expect(
        tester.getRect(menuFinder).left,
        moreOrLessEquals(token.left - 12, epsilon: 0.01),
      );
    });

    fieldTest('removing chips with Backspace re-anchors the open popup', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey()]);
      await vm.setExtraFilter(serverKey: 'fruit_id', values: {'a', 'b'});
      await settleMenu(tester);

      await tester.tap(inputFinder);
      await settleMenu(tester);
      final before = tester.getRect(menuFinder).left;

      // First press arms the last chip, the second removes it.
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(vm.extraFilters['fruit_id'], {'a', 'b'});
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await settleMenu(tester);
      expect(vm.extraFilters['fruit_id'], hasLength(1));

      final input = tester.getRect(inputFinder);
      final after = tester.getRect(menuFinder).left;
      expect(after, moreOrLessEquals(input.left - 12, epsilon: 0.01));
      expect(
        after,
        lessThan(before),
        reason: 'the popup used to stay where the input had been',
      );
    });

    fieldTest('never hangs past the search box, however many chips', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey()], fieldWidth: 620);
      await vm.setExtraFilter(serverKey: 'fruit_id', values: {'a', 'b', 'c'});
      await settleMenu(tester);

      await tester.tap(inputFinder);
      await settleMenu(tester);

      final field = tester.getRect(fieldFinder);
      final menu = tester.getRect(menuFinder);
      expect(menu.left, greaterThanOrEqualTo(field.left - 0.01));
      expect(menu.right, lessThanOrEqualTo(field.right + 0.01));
      expect(menu.top, moreOrLessEquals(field.bottom + 4, epsilon: 0.01));
    });

    fieldTest('holds still while a multi-select list is being ticked', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey(checkbox: true)]);

      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Fruit'));
      await settleMenu(tester);
      final before = tester.getRect(menuFinder);
      final inputBefore = tester.getRect(inputFinder);

      await tester.tap(inMenu('Apple'));
      await settleMenu(tester);

      expect(vm.extraFilters['fruit_id'], {'a'});
      expect(menuFinder, findsOneWidget, reason: 'a tick keeps the list open');
      // The new chip shoved the input right…
      expect(tester.getRect(inputFinder).left, greaterThan(inputBefore.left));
      // …and the list the pointer is working stayed where it was.
      expect(tester.getRect(menuFinder).left, before.left);
    });

    fieldTest('RTL: the popup ends at the token start', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: const [IsFilterKey()],
        textDirection: TextDirection.rtl,
      );

      await tester.tap(inputFinder);
      await settleMenu(tester);

      final field = tester.getRect(fieldFinder);
      final input = tester.getRect(inputFinder);
      final menu = tester.getRect(menuFinder);
      expect(menu.right, moreOrLessEquals(input.right + 12, epsilon: 0.01));
      expect(menu.right, lessThanOrEqualTo(field.right + 0.01));
    });

    fieldTest('a chip segment popup stays on screen at the right edge', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      const surface = Size(kHarnessSidebar + 24 + 320, 600);
      await pumpWideField(
        tester,
        vm: vm,
        keys: const [BalanceFilterKey()],
        fieldWidth: 300,
        surface: surface,
      );
      await vm.setExtraFilter(serverKey: 'balance', values: {'gt:5'});
      await settleMenu(tester);

      // The value segment of the `Balance > 5` chip.
      await tester.tap(find.text('5'));
      await tester.pump();

      final popup = tester.getRect(find.byType(SegmentMenu));
      expect(popup.right, lessThanOrEqualTo(surface.width - 8 + 0.01));
      expect(popup.left, greaterThanOrEqualTo(kHarnessSidebar + 8 - 0.01));
    });
  });

  group('search state', () {
    fieldTest('emptying the box clears the search', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [IsFilterKey()]);

      await tester.enterText(inputFinder, 'acme');
      await settleSearch(tester);
      expect(vm.search, 'acme');

      await tester.enterText(inputFinder, '');
      await settleSearch(tester);
      expect(
        vm.search,
        '',
        reason: 'the list stayed filtered by the last term under an empty box',
      );
    });

    fieldTest('starting a filter withdraws a search still inside its '
        'debounce', (tester) async {
      const debounce = Duration(milliseconds: 250);
      final vm = newHarnessVm(db, searchDebounce: debounce);
      await pumpWideField(
        tester,
        vm: vm,
        keys: const [IsFilterKey(), NameFilterKey()],
      );

      await tester.enterText(inputFinder, 'nam');
      await tester.pump(const Duration(milliseconds: 100));
      expect(vm.search, '', reason: 'still debouncing');
      await tester.enterText(inputFinder, 'name:');
      await settleSearch(tester, debounce);

      expect(vm.search, '', reason: '`nam` used to fire under the picker');
    });

    fieldTest('clicking a typed-value key withdraws the text typed to find '
        'it', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: const [IsFilterKey(), NameFilterKey()],
      );

      await tester.enterText(inputFinder, 'nam');
      await settleSearch(tester);
      expect(vm.search, 'nam');
      // A MOUSE click: a text field unfocuses on a tap outside itself only
      // for a mouse (`EditableText`'s default `onTapOutside`), and
      // `tester.tap` is a touch by default.
      await tester.tap(inMenu('Name'), kind: PointerDeviceKind.mouse);
      await settleSearch(tester);

      // The click takes focus off the input before the row's handler writes
      // `name:`, so the text listener skips that write; `nam` is withdrawn
      // only because the field takes focus back. Nothing may leave it behind.
      expect(vm.search, '');
    });

    fieldTest('a colon that names no filter is still a search', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [IsFilterKey()]);

      await tester.enterText(inputFinder, 'INV:001');
      await settleSearch(tester);
      expect(vm.search, 'INV:001');
    });

    fieldTest('text typed into a pinned picker is not searched', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [IsFilterKey()]);

      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('State'));
      await settleMenu(tester);

      await tester.enterText(inputFinder, 'del');
      await settleSearch(tester);
      expect(vm.search, '');
      expect(inMenu('Deleted'), findsOneWidget, reason: 'it narrows the list');

      // Tick it and click away: the query is debris, not a search to keep.
      await tester.tap(inMenu('Deleted'));
      await settleMenu(tester);
      await tester.tapAt(const Offset(kHarnessSidebar + 400, 500));
      await settleSearch(tester);
      expect(vm.states, contains(EntityState.deleted));
      expect(vm.search, '');
      expect(boxText(tester), '');
    });

    fieldTest('a locked key cannot be reached by typing its prefix', (
      tester,
    ) async {
      // An embedded list: the parent record owns `fruit`.
      final vm = newHarnessVm(db, locked: {'fruit'});
      await pumpWideField(tester, vm: vm, keys: [FruitKey()]);

      await tester.enterText(inputFinder, 'fruit:a');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleSearch(tester);

      expect(vm.extraFilters['fruit_id'], isNull);
      expect(vm.search, 'fruit:a', reason: 'it is just text there');
    });
  });

  group('Enter', () {
    fieldTest('commits the comparator that was typed', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [BalanceFilterKey()]);

      await tester.enterText(inputFinder, 'balance:<500');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(vm.extraFilters['balance'], {
        'lt:500',
      }, reason: 'row 0 (`>`) used to win whatever was typed');
      expect(boxText(tester), '');
    });

    fieldTest('refuses an amount that is not a number', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [BalanceFilterKey()]);

      await tester.enterText(inputFinder, 'balance:abc');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(vm.extraFilters['balance'], isNull);
      // Kept, to be finished: the typed `balance:` became its key chip.
      expect(boxText(tester), 'abc');
      expect(find.widgetWithText(PendingKeyChip, 'Balance'), findsOneWidget);
      expect(menuFinder, findsOneWidget);
    });

    fieldTest('commits a typed date', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [_dateKey]);

      await tester.enterText(inputFinder, 'date:2026-05-14');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(vm.extraFilters['date'], {
        'gte:2026-05-14',
      }, reason: 'Enter used to loop comparator → back row and never commit');

      await tester.enterText(inputFinder, 'date:<today');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(vm.extraFilters['date'], {'lt:rel:d0'}, reason: 'rolling');
    });

    fieldTest('never invents a value for a pick-only key', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey()]);

      await tester.enterText(inputFinder, 'fruit:zzz');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(
        vm.extraFilters['fruit_id'],
        isNull,
        reason: 'it used to apply `fruit_id=zzz` and empty the list',
      );
      expect(boxText(tester), 'zzz');
      expect(find.widgetWithText(PendingKeyChip, 'Fruit'), findsOneWidget);
      expect(menuFinder, findsOneWidget);
    });

    fieldTest('…nor while the value list is still loading', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: [FruitKey(delay: const Duration(seconds: 1))],
      );

      await tester.enterText(inputFinder, 'fruit:app');
      await settleMenu(tester);
      expect(inMenu('No matches'), findsNothing);
      // "Loading" only once the list has kept the user waiting — a list that
      // answers at once never flashes the word.
      Color? loadingInk() =>
          tester.widget<Text>(inMenu('Loading')).style?.color;
      expect(loadingInk(), Colors.transparent);
      await tester.pump(const Duration(milliseconds: 200));
      expect(loadingInk(), isNot(Colors.transparent));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(vm.extraFilters['fruit_id'], isNull);

      await tester.pump(const Duration(seconds: 1));
      await settleMenu(tester);
      expect(inMenu('Apple'), findsOneWidget);
    });

    fieldTest('commits what is in the box, not the rows of the previous '
        'keystroke', (tester) async {
      const debounce = Duration(milliseconds: 250);
      final vm = newHarnessVm(db, searchDebounce: debounce);
      await pumpWideField(tester, vm: vm, keys: const [IsFilterKey()]);

      await tester.enterText(inputFinder, 'acm');
      await settleMenu(tester);
      // A scanner, or a paste followed at once by Enter: the key arrives in
      // the same frame as the text, before the menu has re-published.
      await tester.enterText(inputFinder, 'acme');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleSearch(tester, debounce);

      expect(vm.search, 'acme', reason: 'it used to run "Search for acm"');
    });

    fieldTest('is not stolen by a pointer parked where the menu opens', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [BalanceFilterKey()]);

      // Find where the `Balance` row lands, then close.
      await tester.enterText(inputFinder, 'ba');
      await settleMenu(tester);
      final row = tester.getCenter(inMenu('Balance'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(menuFinder, findsNothing);

      // Park a mouse there and type: the row appears UNDER it.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: row);
      addTearDown(mouse.removePointer);
      await tester.pump();
      await tester.enterText(inputFinder, 'bal');
      await settleMenu(tester);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleSearch(tester);

      expect(
        boxText(tester),
        'bal',
        reason: 'the row under the pointer used to take the highlight',
      );
      expect(vm.search, 'bal');
    });
  });

  group('ship review', () {
    fieldTest('a date typed after choosing a comparator keeps the comparator', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [_dateKey]);

      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Date'));
      await settleMenu(tester);
      await tester.tap(inMenu('is before'));
      await settleMenu(tester);

      // Typing the date swaps the preset list for the typed-date rows. The
      // comparator just chosen lived in the widget that was swapped out.
      await tester.enterText(inputFinder, 'date:2026-05-14');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(vm.extraFilters['date'], {
        'lt:2026-05-14',
      }, reason: 'it applied the default "is on or after" — the opposite');
    });

    fieldTest('Enter never commits rows left over from the previous query', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      const wait = Duration(seconds: 1);
      await pumpWideField(
        tester,
        vm: vm,
        keys: [FruitKey(delay: wait)],
      );

      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Fruit'));
      await settleMenu(tester);
      await tester.pump(wait);
      await settleMenu(tester);
      expect(inMenu('Apple'), findsOneWidget);

      // The new query's list has not arrived; the old one is still on screen
      // with its first row highlighted.
      await tester.enterText(inputFinder, 'zzz');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(
        vm.extraFilters['fruit_id'],
        isNull,
        reason: 'it applied the first row of the list for the OLD query',
      );
      await tester.pump(wait);
    });

    fieldTest('Tab leaves the box when what is typed cannot commit', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [BalanceFilterKey()]);

      await tester.enterText(inputFinder, 'balance:abc');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        menuFinder,
        findsNothing,
        reason: 'Tab was swallowed: nothing committed, nothing moved',
      );
      expect(vm.extraFilters['balance'], isNull);
    });

    fieldTest('a tick made with Enter clears the query that found the row', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey(checkbox: true)]);

      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Fruit'));
      await settleMenu(tester);
      await tester.enterText(inputFinder, 'an');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleMenu(tester);

      expect(vm.extraFilters['fruit_id'], {'b'});
      expect(boxText(tester), '');
      expect(
        inMenu('Cherry'),
        findsOneWidget,
        reason: 'the whole list is back',
      );
    });

    fieldTest('a tick made by touch keeps the query', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey(checkbox: true)]);

      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Fruit'));
      await settleMenu(tester);
      await tester.enterText(inputFinder, 'an');
      await settleMenu(tester);
      await tester.tap(inMenu('Banana'));
      await settleMenu(tester);

      expect(vm.extraFilters['fruit_id'], {'b'});
      expect(
        boxText(tester),
        'an',
        reason: 'a tap was mistaken for Enter and the list reshuffled',
      );
      expect(inMenu('Cherry'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    fieldTest('Backspace removes the chip it armed, all of it', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey(checkbox: true)]);
      await vm.setExtraFilter(serverKey: 'fruit_id', values: {'a', 'b', 'c'});
      await settleMenu(tester);
      // One aggregate chip stands for all three.
      expect(find.byType(FilterTokenChip), findsOneWidget);

      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await settleMenu(tester);

      expect(
        vm.extraFilters['fruit_id'],
        isNull,
        reason: 'the whole chip was highlighted, one value was removed',
      );
      expect(find.byType(FilterTokenChip), findsNothing);
    });

    fieldTest('a partly typed period lists the periods it starts, and says '
        'nothing is wrong', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [_dateKey]);

      await tester.enterText(inputFinder, 'date:th');
      await settleMenu(tester);
      expect(inMenu('This Week'), findsOneWidget);
      expect(inMenu('This Month'), findsOneWidget);
      expect(inMenu('This Year'), findsOneWidget);
      expect(inMenu('Last Month'), findsNothing);
      expect(
        find.textContaining('Not a date yet'),
        findsNothing,
        reason: 'every keystroke of `this month` used to read "not a date"',
      );

      // One word matches any word of a period's name.
      await tester.enterText(inputFinder, 'month');
      await settleMenu(tester);
      expect(inMenu('This Month'), findsOneWidget);
      expect(inMenu('Last Month'), findsOneWidget);
      expect(inMenu('This Week'), findsNothing);
    });

    fieldTest('a typed period commits its rolling window on Enter', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [_dateKey]);

      await tester.enterText(inputFinder, 'date:this month');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(vm.extraFilters['date_range'], {'date,rel:m0s,rel:m0e'});
      expect(vm.extraFilters['date'], isNull);
      expect(boxText(tester), '');
    });

    fieldTest('under a comparator already picked, a typed period is its bound '
        '— "is before this month" is before the 1st, not the month', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [_dateKey]);

      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Date'));
      await settleMenu(tester);
      await tester.tap(inMenu('is before'));
      await settleMenu(tester);
      await tester.enterText(inputFinder, 'this month');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(vm.extraFilters['date'], {
        'lt:rel:m0s',
      }, reason: 'committing the window dropped the comparator the user chose');
      expect(vm.extraFilters['date_range'], isNull);
    });

    fieldTest('Enter does not walk a preset in under text that is not a date', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [_dateKey]);

      await tester.enterText(inputFinder, 'date:banana');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleMenu(tester);

      expect(
        vm.extraFilters['date'],
        isNull,
        reason: 'two Enters picked a comparator and then "1 hour ago"',
      );
      expect(boxText(tester), 'banana');
      expect(find.widgetWithText(PendingKeyChip, 'Date'), findsOneWidget);
    });
  });

  group('chips', () {
    fieldTest('a tap on the body opens the editor and removes nothing', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey()]);
      await vm.setExtraFilter(serverKey: 'fruit_id', values: {'a', 'b'});
      await settleMenu(tester);
      expect(find.byType(FilterTokenChip), findsNWidgets(2));
      final chip = tester.getRect(
        find.widgetWithText(FilterTokenChip, 'Apple'),
      );

      await tester.tap(find.text('Apple'));
      await settleMenu(tester);
      expect(vm.extraFilters['fruit_id'], {
        'a',
        'b',
      }, reason: 'the value used to be removed before the picker opened');
      // The picker hangs under the chip it edits.
      final menu = tester.getRect(menuFinder);
      expect(menu.left, greaterThanOrEqualTo(chip.left - 12));
      expect(menu.left, lessThan(chip.right));
      expect(boxText(tester), '', reason: 'no `fruit:` written into the box');

      // Backing out leaves the filter exactly as it was.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(menuFinder, findsNothing);
      expect(vm.extraFilters['fruit_id'], {'a', 'b'});

      // Picking another value replaces the one on the chip.
      await tester.tap(find.text('Apple'));
      await settleMenu(tester);
      await tester.tap(inMenu('Cherry'));
      await tester.pump();
      expect(vm.extraFilters['fruit_id'], {'b', 'c'});
    });

    fieldTest('keep the case of their label', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey()]);
      await vm.setExtraFilter(serverKey: 'fruit_id', values: {'a'});
      await settleMenu(tester);
      expect(find.text('Fruit'), findsOneWidget);
      expect(find.text('fruit'), findsNothing);
    });
  });

  group('date presets', () {
    fieldTest('a window can be This month, and stays this month', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [_dateKey]);
      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Date'));
      await settleMenu(tester);
      await tester.tap(inMenu('is between'));
      await settleMenu(tester);

      await tester.tap(inMenu('This Month'));
      await settleSearch(tester);
      // Not the dates it covers today: a saved view keeps meaning this month.
      expect(vm.extraFilters['date_range'], {'date,rel:m0s,rel:m0e'});
      expect(
        find.widgetWithText(FilterTokenChip, 'This Month'),
        findsOneWidget,
      );
    });

    fieldTest('a date with no time of day is not offered "1 hour ago"', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [_dateKey]);
      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Date'));
      await settleMenu(tester);
      await tester.tap(inMenu('is on or after'));
      await settleMenu(tester);
      expect(inMenu('7 days ago'), findsOneWidget);
      expect(inMenu('1 hour ago'), findsNothing);
    });
  });

  group('paste', () {
    Future<HarnessVm> pumpWithClipboard(
      WidgetTester tester,
      String clipboard,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: [const IsFilterKey(), FruitKey()],
        readClipboard: () async => clipboard,
      );
      await tester.tap(inputFinder);
      await settleMenu(tester);
      return vm;
    }

    Future<void> commandV(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await settleSearch(tester);
    }

    fieldTest('⌘V reads a query: filters become chips, the rest the search', (
      tester,
    ) async {
      final vm = await pumpWithClipboard(tester, 'is:archived acme');
      await commandV(tester);
      // A keyboard paste used to drop the text in raw — `is:` then made the
      // whole thing one State query that matched nothing.
      expect(vm.states, contains(EntityState.archived));
      expect(boxText(tester), 'acme');
      expect(vm.search, 'acme');
    });

    fieldTest('⌘V of plain text pastes it where the caret is', (tester) async {
      final vm = await pumpWithClipboard(tester, 'hello');
      await tester.enterText(inputFinder, 'abcd');
      tester.widget<TextField>(inputFinder).controller!.selection =
          const TextSelection.collapsed(offset: 2);
      await tester.pump();
      await commandV(tester);
      expect(boxText(tester), 'abhellocd');
      expect(vm.search, 'abhellocd');
    });

    fieldTest('a colon that names no filter pastes as text', (tester) async {
      final vm = await pumpWithClipboard(tester, 'INV:001');
      await commandV(tester);
      expect(boxText(tester), 'INV:001');
      expect(vm.search, 'INV:001');
    });

    fieldTest('the context menu\'s Paste is the same paste', (tester) async {
      final vm = await pumpWithClipboard(tester, 'is:archived');
      await tester.tapAt(
        tester.getCenter(inputFinder),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await tester.tap(find.text('Paste'));
      await settleSearch(tester);
      expect(vm.states, contains(EntityState.archived));
      expect(boxText(tester), '');
    });
  });

  group('chip navigation', () {
    bool armed(WidgetTester tester, String label) => tester
        .widget<FilterTokenChip>(find.widgetWithText(FilterTokenChip, label))
        .armed;

    Future<HarnessVm> threeFruits(
      WidgetTester tester, {
      TextDirection textDirection = TextDirection.ltr,
    }) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: [FruitKey()],
        textDirection: textDirection,
      );
      await vm.setExtraFilter(serverKey: 'fruit_id', values: {'a', 'b', 'c'});
      await settleMenu(tester);
      await tester.tap(inputFinder);
      await settleMenu(tester);
      return vm;
    }

    Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
      await tester.sendKeyEvent(k);
      await tester.pump();
    }

    fieldTest('← at the start walks into the chips and → back out', (
      tester,
    ) async {
      await threeFruits(tester);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(armed(tester, 'Cherry'), isTrue);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(armed(tester, 'Banana'), isTrue);
      expect(armed(tester, 'Cherry'), isFalse);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(armed(tester, 'Apple'), isTrue, reason: 'it stops at the first');

      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(armed(tester, 'Cherry'), isTrue);
      await key(tester, LogicalKeyboardKey.arrowRight);
      for (final f in const ['Apple', 'Banana', 'Cherry']) {
        expect(armed(tester, f), isFalse);
      }
      expect(boxFocus(tester).hasFocus, isTrue, reason: 'focus never moved');
    });

    fieldTest('← moves the caret when there is text before it, or a '
        'modifier is held', (tester) async {
      await threeFruits(tester);
      await tester.enterText(inputFinder, 'ab');
      await settleMenu(tester);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(armed(tester, 'Cherry'), isFalse);

      tester.widget<TextField>(inputFinder).controller!.selection =
          const TextSelection.collapsed(offset: 0);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(armed(tester, 'Cherry'), isFalse, reason: 'Shift+← selects');

      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(armed(tester, 'Cherry'), isTrue, reason: 'caret at the start');
    });

    fieldTest('Delete or Backspace removes the armed chip, wherever it is', (
      tester,
    ) async {
      final vm = await threeFruits(tester);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.delete);
      await settleMenu(tester);
      expect(vm.extraFilters['fruit_id'], {'a', 'c'});

      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.backspace);
      await settleMenu(tester);
      expect(vm.extraFilters['fruit_id'], {'c'});
    });

    fieldTest('Enter on the armed chip opens its editor and removes nothing', (
      tester,
    ) async {
      final vm = await threeFruits(tester);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      final chip = tester.getRect(
        find.widgetWithText(FilterTokenChip, 'Banana'),
      );
      await key(tester, LogicalKeyboardKey.enter);
      await settleMenu(tester);

      expect(vm.extraFilters['fruit_id'], {'a', 'b', 'c'});
      final menu = tester.getRect(menuFinder);
      expect(menu.left, greaterThanOrEqualTo(chip.left - 12));
      expect(menu.left, lessThan(chip.right), reason: 'under the chip');
      await tester.tap(inMenu('Apple'));
      await settleMenu(tester);
      expect(vm.extraFilters['fruit_id'], {
        'a',
        'c',
      }, reason: 'it replaced Banana');
    });

    fieldTest('Escape lets go of the chip and leaves the menu open', (
      tester,
    ) async {
      await threeFruits(tester);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.escape);
      expect(armed(tester, 'Cherry'), isFalse);
      expect(menuFinder, findsOneWidget);
    });

    fieldTest('↓ lets go of the chip and moves the menu highlight', (
      tester,
    ) async {
      await threeFruits(tester);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(armed(tester, 'Cherry'), isFalse);
    });

    fieldTest('typing lets go of the chip and types', (tester) async {
      await threeFruits(tester);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'x',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();
      expect(armed(tester, 'Cherry'), isFalse);
      expect(boxText(tester), 'x');
    });

    fieldTest('a caret moved without typing keeps the chip armed', (
      tester,
    ) async {
      await threeFruits(tester);
      await tester.enterText(inputFinder, 'ab');
      await settleMenu(tester);
      final text = tester.widget<TextField>(inputFinder).controller!;
      text.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(armed(tester, 'Cherry'), isTrue);

      text.selection = const TextSelection(baseOffset: 0, extentOffset: 0);
      text.selection = const TextSelection.collapsed(
        offset: 0,
        affinity: TextAffinity.upstream,
      );
      await tester.pump();
      expect(
        armed(tester, 'Cherry'),
        isTrue,
        reason: 'every notification of the text controller used to disarm',
      );
    });

    fieldTest('in right-to-left text → walks into the chips', (tester) async {
      await threeFruits(tester, textDirection: TextDirection.rtl);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(armed(tester, 'Cherry'), isFalse);
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(armed(tester, 'Cherry'), isTrue);
    });

    fieldTest('Enter on the search chip puts the term back in the box', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey()]);
      await tester.enterText(inputFinder, 'acme');
      await settleSearch(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleSearch(tester);
      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Fruit'));
      await settleMenu(tester);
      await tester.tap(inMenu('Banana'));
      await settleSearch(tester);
      await tester.tap(inputFinder);
      await settleMenu(tester);

      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(armed(tester, '"acme"'), isTrue);
      await key(tester, LogicalKeyboardKey.enter);
      await settleMenu(tester);
      expect(boxText(tester), 'acme');
      expect(vm.search, 'acme');
      expect(find.widgetWithText(FilterTokenChip, '"acme"'), findsNothing);
    });
  });

  group('pending key', () {
    Finder pendingKey(String label) => find.descendant(
      of: find.byType(PendingKeyChip),
      matching: find.text(label),
    );

    Future<HarnessVm> pickBalance(WidgetTester tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: const [IsFilterKey(), BalanceFilterKey(), NameFilterKey()],
      );
      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Balance'));
      await settleMenu(tester);
      return vm;
    }

    fieldTest('a picked key shows as a chip in front of an empty box, and '
        'its typed value commits', (tester) async {
      final vm = await pickBalance(tester);
      expect(boxText(tester), '', reason: 'it used to write `balance:`');
      expect(pendingKey('Balance'), findsOneWidget);

      await tester.enterText(inputFinder, '<500');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleSearch(tester);
      expect(vm.extraFilters['balance'], {'lt:500'});
      expect(find.byType(PendingKeyChip), findsNothing);
    });

    fieldTest('a half-typed value survives a click away, key and all', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: const [IsFilterKey(), NameFilterKey()],
      );
      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Name'));
      await settleMenu(tester);
      await tester.enterText(inputFinder, 'ac');
      await settleMenu(tester);

      await tester.tapAt(const Offset(kHarnessSidebar + 400, 500));
      await settleSearch(tester);
      expect(menuFinder, findsNothing);
      expect(boxText(tester), 'ac');
      expect(pendingKey('Name'), findsOneWidget);
      expect(vm.search, '', reason: 'a value being typed is not a search');
    });

    fieldTest('a pick-only key leaves nothing behind when the menu closes', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey()]);
      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Fruit'));
      await settleMenu(tester);
      await tester.enterText(inputFinder, 'ban');
      await settleMenu(tester);

      await tester.tapAt(const Offset(kHarnessSidebar + 400, 500));
      await settleSearch(tester);
      expect(boxText(tester), '');
      expect(find.byType(PendingKeyChip), findsNothing);
    });

    fieldTest('Backspace in the empty box goes back to the filters', (
      tester,
    ) async {
      await pickBalance(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await settleMenu(tester);
      expect(find.byType(PendingKeyChip), findsNothing);
      expect(inMenu('Name'), findsOneWidget);
    });

    fieldTest('a tap on the key chip goes back to the filters', (tester) async {
      await pickBalance(tester);
      await tester.tap(find.byType(PendingKeyChip));
      await settleMenu(tester);
      expect(find.byType(PendingKeyChip), findsNothing);
      expect(inMenu('Name'), findsOneWidget);
    });

    fieldTest('a typed `key:` becomes its key chip', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [BalanceFilterKey()]);
      await tester.enterText(inputFinder, 'balance:');
      await settleMenu(tester);
      expect(boxText(tester), '');
      expect(pendingKey('Balance'), findsOneWidget);
      expect(vm.search, '');
    });

    fieldTest('not while an input method is composing', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [BalanceFilterKey()]);
      await tester.showKeyboard(inputFinder);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'balance:',
          selection: TextSelection.collapsed(offset: 8),
          composing: TextRange(start: 0, end: 8),
        ),
      );
      await settleMenu(tester);
      expect(boxText(tester), 'balance:');
      expect(find.byType(PendingKeyChip), findsNothing);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'balance:',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      await settleMenu(tester);
      expect(boxText(tester), '');
      expect(pendingKey('Balance'), findsOneWidget);
    });

    fieldTest('a colon that names no key is part of the value', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey()]);
      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Fruit'));
      await settleMenu(tester);
      await tester.enterText(inputFinder, 'net:30');
      await settleMenu(tester);
      expect(boxText(tester), 'net:30');
      expect(pendingKey('Fruit'), findsOneWidget);
    });

    fieldTest('a search changed from outside abandons a key left standing', (
      tester,
    ) async {
      final vm = await pickBalance(tester);
      await tester.enterText(inputFinder, '<5');
      await settleMenu(tester);
      await tester.tapAt(const Offset(kHarnessSidebar + 400, 500));
      await settleSearch(tester);
      expect(pendingKey('Balance'), findsOneWidget);

      vm.setSearch('zeta', immediate: true);
      await settleSearch(tester);
      expect(find.byType(PendingKeyChip), findsNothing);
      expect(boxText(tester), 'zeta');
    });
  });

  group('search chip', () {
    Finder searchChip(String term) =>
        find.widgetWithText(FilterTokenChip, '"$term"');

    // A search committed with Enter, then the box clicked again: the menu
    // opens on a search the list is already showing.
    Future<HarnessVm> committedSearch(
      WidgetTester tester, {
      List<FilterKey>? keys,
    }) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: keys ?? [const IsFilterKey(), FruitKey()],
      );
      await tester.enterText(inputFinder, 'acme');
      await settleSearch(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleSearch(tester);
      expect(vm.search, 'acme');
      expect(menuFinder, findsNothing);
      await tester.tap(inputFinder);
      await settleMenu(tester);
      return vm;
    }

    // …and then a filter started from it.
    Future<HarnessVm> searchInChip(WidgetTester tester) async {
      final vm = await committedSearch(tester);
      await tester.tap(inMenu('Fruit'));
      await settleMenu(tester);
      expect(searchChip('acme'), findsOneWidget);
      return vm;
    }

    fieldTest('words typed before a key are the search: `acme fruit:` lifts '
        '`acme` into a chip and opens Fruit', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey()]);

      // Typed as a person types it: the menu opens on the first letters, and
      // `acme fruit` is live-searched until the colon lands.
      await tester.enterText(inputFinder, 'acme fruit');
      await settleSearch(tester);
      await tester.enterText(inputFinder, 'acme fruit:');
      await settleMenu(tester);

      expect(vm.search, 'acme');
      expect(searchChip('acme'), findsOneWidget);
      expect(find.widgetWithText(PendingKeyChip, 'Fruit'), findsOneWidget);
      expect(boxText(tester), '');
      expect(inMenu('Banana'), findsOneWidget);
    });

    fieldTest('the longest key wins: `acme due date:` opens Due Date, not Date '
        'with "due" lifted', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: const [
          _dateKey,
          DateColumnFilterKey(
            id: 'due_date',
            serverKey: 'due_date',
            labelKey: 'due_date',
          ),
        ],
      );

      await tester.enterText(inputFinder, 'acme due date:');
      await settleMenu(tester);

      expect(vm.search, 'acme');
      expect(find.widgetWithText(PendingKeyChip, 'Due Date'), findsOneWidget);
    });

    fieldTest('words before something that is not a key stay the search', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey()]);

      await tester.enterText(inputFinder, 'acme fruitx:');
      await settleSearch(tester);

      expect(boxText(tester), 'acme fruitx:');
      expect(find.byType(PendingKeyChip), findsNothing);
      expect(searchChip('acme'), findsNothing);
    });

    fieldTest('the menu re-opened on a committed search lists every filter, '
        'and picking one keeps the search', (tester) async {
      final vm = await committedSearch(tester);

      expect(
        inMenu('Fruit'),
        findsOneWidget,
        reason: 'the list was ranked by `acme`, so no filter could be picked',
      );
      expect(inMenu('Search for '), findsNothing);

      await tester.tap(inMenu('Fruit'));
      await settleMenu(tester);
      expect(vm.search, 'acme', reason: 'starting the filter dropped it');
      expect(boxText(tester), '');
      expect(searchChip('acme'), findsOneWidget);

      await tester.tap(inMenu('Banana'));
      await settleSearch(tester);
      expect(vm.extraFilters['fruit_id'], {'b'});
      expect(vm.search, 'acme', reason: 'picking the value dropped it');
      expect(searchChip('acme'), findsOneWidget);
    });

    fieldTest('a committed search that names a filter is not mistaken for '
        'having found it', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey()]);
      await tester.enterText(inputFinder, 'fru');
      await settleSearch(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleSearch(tester);
      await tester.tap(inputFinder);
      await settleMenu(tester);

      await tester.tap(inMenu('Fruit'));
      await settleMenu(tester);
      expect(vm.search, 'fru');
      expect(searchChip('fru'), findsOneWidget);
    });

    fieldTest('✕ clears only the search', (tester) async {
      final vm = await searchInChip(tester);
      await tester.tap(inMenu('Banana'));
      await settleSearch(tester);

      await tester.tap(
        find.descendant(
          of: searchChip('acme'),
          matching: find.byIcon(Icons.close),
        ),
      );
      await settleSearch(tester);
      expect(vm.search, '');
      expect(vm.extraFilters['fruit_id'], {'b'});
      expect(searchChip('acme'), findsNothing);
    });

    fieldTest('a tap puts the term back in the box, where it is the search '
        'again', (tester) async {
      final vm = await searchInChip(tester);
      await tester.tap(inMenu('Banana'));
      await settleSearch(tester);

      await tester.tap(find.text('"acme"'));
      await settleMenu(tester);
      expect(boxText(tester), 'acme');
      expect(searchChip('acme'), findsNothing);
      expect(vm.search, 'acme');

      await tester.enterText(inputFinder, 'acme corp');
      await settleSearch(tester);
      expect(vm.search, 'acme corp');
    });

    fieldTest('Backspace arms the search chip, then removes it', (
      tester,
    ) async {
      final vm = await searchInChip(tester);
      // Out of the Fruit picker first, as for any pinned picker.
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(tester.widget<FilterTokenChip>(searchChip('acme')).armed, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await settleSearch(tester);
      expect(vm.search, '');
      expect(searchChip('acme'), findsNothing);
    });

    fieldTest('text typed beside the chip is not searched until it is '
        'committed, and then it replaces the chip', (tester) async {
      final vm = await searchInChip(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      await tester.enterText(inputFinder, 'corp');
      await settleSearch(tester);
      expect(vm.search, 'acme', reason: '`corp` replaced it live');
      expect(searchChip('acme'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleSearch(tester);
      expect(vm.search, 'corp');
      expect(boxText(tester), 'corp');
      expect(searchChip('acme'), findsNothing);
    });

    fieldTest('text spent finding a value leaves the chip alone', (
      tester,
    ) async {
      final vm = await searchInChip(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      await tester.enterText(inputFinder, 'del');
      await settleMenu(tester);
      await tester.tap(inMenu('Deleted'));
      await settleSearch(tester);
      expect(vm.states, contains(EntityState.deleted));
      expect(vm.search, 'acme');
      expect(searchChip('acme'), findsOneWidget);
      expect(boxText(tester), '');
    });

    fieldTest('a search changed from outside the field lands in the box', (
      tester,
    ) async {
      final vm = await searchInChip(tester);
      await tester.tapAt(const Offset(kHarnessSidebar + 400, 500));
      await settleSearch(tester);

      vm.setSearch('zeta', immediate: true);
      await settleSearch(tester);
      expect(boxText(tester), 'zeta');
      expect(searchChip('acme'), findsNothing);
      expect(searchChip('zeta'), findsNothing);
    });

    fieldTest('removing the chip with the menu open re-anchors it', (
      tester,
    ) async {
      await searchInChip(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(menuFinder, findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await settleMenu(tester);
      final input = tester.getRect(inputFinder);
      final menu = tester.getRect(menuFinder);
      expect(menu.left, moreOrLessEquals(input.left - 12, epsilon: 0.01));
    });
  });

  group('multi-select rows', () {
    fieldTest('the row toggles and stays open; Only replaces and closes', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey(checkbox: true)]);

      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Fruit'));
      await settleMenu(tester);

      // Clicking the LABEL ticks — it used to replace the selection and close.
      await tester.tap(inMenu('Apple'));
      await settleMenu(tester);
      await tester.tap(inMenu('Banana'));
      await settleMenu(tester);
      expect(vm.extraFilters['fruit_id'], {'a', 'b'});
      expect(menuFinder, findsOneWidget);
      // …and again unticks.
      await tester.tap(inMenu('Apple'));
      await settleMenu(tester);
      expect(vm.extraFilters['fruit_id'], {'b'});

      // "Only" shows on the row under the pointer.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final cherry = tester.getCenter(inMenu('Cherry'));
      await mouse.addPointer(location: cherry - const Offset(4, 0));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(cherry);
      await tester.pump();
      final only = inMenu('Only').hitTestable();
      expect(only, findsOneWidget);
      await tester.tap(only);
      await tester.pump();

      expect(vm.extraFilters['fruit_id'], {'c'});
      expect(menuFinder, findsNothing);
    });

    fieldTest('on touch every row offers Only', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: [FruitKey(checkbox: true)]);

      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Fruit'));
      await settleMenu(tester);
      expect(inMenu('Only').hitTestable(), findsNWidgets(3));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('first view', () {
    fieldTest('suggested filters lead, the rest follow A to Z, with what to '
        'type', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: const [
          BalanceFilterKey(),
          NameFilterKey(),
          IsFilterKey(),
          VatFilterKey(),
        ],
      );

      await tester.tap(inputFinder);
      await settleMenu(tester);

      double y(String text) => tester.getTopLeft(inMenu(text)).dy;
      // Suggested: the primary keys, in the order the list registers them.
      expect(y('Suggested'), lessThan(y('Name')));
      expect(y('Name'), lessThan(y('State')));
      expect(y('State'), lessThan(y('All filters')));
      // The rest, A→Z.
      expect(y('All filters'), lessThan(y('Balance')));
      expect(y('Balance'), lessThan(y('VAT Number')));
      // What to type to get there without the menu.
      expect(inMenu('balance:'), findsOneWidget);
      expect(inMenu('state:'), findsOneWidget);
      // The key hints.
      expect(inMenu('Navigate'), findsOneWidget);
    });

    fieldTest('no keyboard hints on touch', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: const [BalanceFilterKey(), IsFilterKey()],
      );

      await tester.tap(inputFinder);
      await settleMenu(tester);
      expect(inMenu('Balance'), findsOneWidget);
      expect(inMenu('balance:'), findsNothing);
      expect(inMenu('Navigate'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    fieldTest('a key with one value applies it on pick', (tester) async {
      final vm = newHarnessVm(db);
      final overdue = DirectKey();
      await pumpWideField(tester, vm: vm, keys: [overdue]);

      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('Overdue'));
      await tester.pump();

      expect(overdue.added, 'true');
      expect(menuFinder, findsNothing);
      expect(boxText(tester), '', reason: 'no `overdue:` left in the box');
    });

    fieldTest('picking a filter drops the text typed to find it', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [IsFilterKey()]);

      await tester.enterText(inputFinder, 'sta');
      await settleMenu(tester);
      await tester.tap(inMenu('State'));
      await settleMenu(tester);
      await settleSearch(tester);

      expect(boxText(tester), '');
      expect(vm.search, '');
      expect(inMenu('Archived'), findsOneWidget, reason: 'the whole list');
    });

    fieldTest('the value header leads back to the filters', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        keys: const [IsFilterKey(), NameFilterKey()],
      );

      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.tap(inMenu('State'));
      await settleMenu(tester);
      expect(inMenu('Archived'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: menuFinder,
          matching: find.byIcon(Icons.chevron_left),
        ),
      );
      await settleMenu(tester);
      expect(inMenu('Archived'), findsNothing);
      expect(inMenu('Name'), findsOneWidget);
    });
  });

  group('keyboard and pointer', () {
    fieldTest('a click anywhere in the box focuses it and opens the menu', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [IsFilterKey()]);

      // Far from the input, which is only as wide as its hint.
      final field = tester.getRect(fieldFinder);
      final input = tester.getRect(inputFinder);
      final blank = Offset(field.right - 40, field.center.dy);
      expect(input.contains(blank), isFalse);
      await tester.tapAt(blank);
      await settleMenu(tester);

      expect(menuFinder, findsOneWidget);
      expect(boxFocus(tester).hasFocus, isTrue);
    }, variant: desktop);

    fieldTest('Down opens a closed menu', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [IsFilterKey()]);

      // What `/` does: focus, nothing else.
      boxFocus(tester).requestFocus();
      await tester.pump();
      expect(menuFinder, findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settleMenu(tester);
      expect(menuFinder, findsOneWidget);
    });

    fieldTest('Escape closes the menu first, and leaves the box second', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [IsFilterKey()]);

      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(menuFinder, findsNothing);
      expect(boxFocus(tester).hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(boxFocus(tester).hasFocus, isFalse);
    });

    fieldTest('Tab never strands the menu', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [IsFilterKey()]);

      // Nothing typed: Tab just closes it.
      await tester.tap(inputFinder);
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(menuFinder, findsNothing);

      // Something typed: Tab accepts the highlighted row.
      await tester.enterText(inputFinder, 'ac');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await settleSearch(tester);
      expect(menuFinder, findsNothing);
      expect(vm.search, 'ac');
    });

    fieldTest('a held Down walks the highlight, and it stays in view', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(
        tester,
        vm: vm,
        // Enough rows to overflow the 320 px menu.
        keys: const [
          IsFilterKey(),
          NameFilterKey(),
          NumberFilterKey(),
          BalanceFilterKey(),
          VatFilterKey(),
          IdNumberFilterKey(),
          ClassificationFilterKey(),
          _dateKey,
        ],
        surface: const Size(1280, 330),
      );

      await tester.tap(inputFinder);
      await settleMenu(tester);
      final menu = tester.getRect(menuFinder);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
        await settleMenu(tester);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await settleMenu(tester);

      // Row 7 of 8 is highlighted; commit it and see which key opened.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleMenu(tester);
      expect(
        find.descendant(
          of: find.byType(PendingKeyChip),
          matching: find.text('VAT Number'),
        ),
        findsOneWidget,
        reason: 'a repeat used to move the caret, not the highlight',
      );
      expect(menu.height, lessThan(8 * 40));
    });
  });
}
