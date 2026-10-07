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
import 'package:admin/ui/core/list/search/filter_token_chip.dart';
import 'package:admin/ui/core/list/search/segment_menu.dart';
import 'package:admin/ui/features/clients/client_filter_keys.dart';
import 'package:drift/native.dart';
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
      // One pump. The tap writes `name:acme` into the box, which moves and
      // resizes the input; a popup placed from the previous frame's geometry
      // is still where the input WAS.
      await tester.pump();

      final input = tester.getRect(inputFinder);
      expect(boxText(tester), 'name:acme');
      expect(
        tester.getRect(menuFinder).left,
        moreOrLessEquals(input.left - 12, epsilon: 0.01),
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

      expect(
        vm.extraFilters['balance'],
        {'lt:500'},
        reason: 'row 0 (`>`) used to win whatever was typed',
      );
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
      expect(boxText(tester), 'balance:abc');
      expect(menuFinder, findsOneWidget);
    });

    fieldTest('commits a typed date', (tester) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [_dateKey]);

      await tester.enterText(inputFinder, 'date:2026-05-14');
      await settleMenu(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(
        vm.extraFilters['date'],
        {'gte:2026-05-14'},
        reason: 'Enter used to loop comparator → back row and never commit',
      );

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
      expect(boxText(tester), 'fruit:zzz');
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

      expect(
        vm.extraFilters['date'],
        {'lt:2026-05-14'},
        reason: 'it applied the default "is on or after" — the opposite',
      );
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

    fieldTest(
      'a tick made by touch keeps the query',
      (tester) async {
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
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

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
      expect(boxText(tester), 'date:banana');
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
      expect(
        vm.extraFilters['fruit_id'],
        {'a', 'b'},
        reason: 'the value used to be removed before the picker opened',
      );
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

    fieldTest(
      'on touch every row offers Only',
      (tester) async {
        final vm = newHarnessVm(db);
        await pumpWideField(tester, vm: vm, keys: [FruitKey(checkbox: true)]);

        await tester.tap(inputFinder);
        await settleMenu(tester);
        await tester.tap(inMenu('Fruit'));
        await settleMenu(tester);
        expect(inMenu('Only').hitTestable(), findsNWidgets(3));
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
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

    fieldTest(
      'no keyboard hints on touch',
      (tester) async {
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
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

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
    fieldTest(
      'a click anywhere in the box focuses it and opens the menu',
      (tester) async {
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
      },
      variant: desktop,
    );

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
        boxText(tester),
        'vat:',
        reason: 'a repeat used to move the caret, not the highlight',
      );
      expect(menu.height, lessThan(8 * 40));
    });
  });
}
