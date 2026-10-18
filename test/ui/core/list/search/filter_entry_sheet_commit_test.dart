// The phone filter sheet's own commit and navigation paths — the parts it
// did not share with the wide field and had drifted on.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_entry_sheet.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_token_chip.dart';
import 'package:admin/ui/features/clients/client_filter_keys.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../_localization_helper.dart';
import '_token_search_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pumpSheet(
    WidgetTester tester,
    GenericListViewModel<dynamic> vm,
    List<FilterKey> keys, {
    String? clipboard,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: FilterEntrySheet(
          vm: vm,
          filterKeys: keys,
          hintKey: 'search',
          // Never the platform clipboard: awaiting it hangs a widget test.
          readClipboard: () async => clipboard,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  // Ends by letting the view model's debounced `nav_state` write fire.
  void sheetTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  String boxText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  sheetTest('a typed key:value + Search applies the filter', (tester) async {
    final vm = newHarnessVm(db);
    await pumpSheet(tester, vm, const [IsFilterKey(), NameFilterKey()]);

    await tester.enterText(find.byType(TextField), 'name:acme');
    await tester.pump();
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();

    expect(vm.extraFilters['name'], {
      'acme',
    }, reason: 'the sheet used to SEARCH for the literal text `name:acme`');
    expect(vm.search, '');
    expect(boxText(tester), '');
    // A filter is a batch-edit step: the sheet stays open for the next one.
    expect(find.byType(FilterEntrySheet), findsOneWidget);
  });

  sheetTest('a picked key has a way back that needs no hardware key', (
    tester,
  ) async {
    final vm = newHarnessVm(db);
    await pumpSheet(tester, vm, const [IsFilterKey(), NameFilterKey()]);

    await tester.tap(find.text('State'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Archived'), findsOneWidget);
    expect(find.text('Name'), findsNothing);

    // The header is the only exit a soft keyboard can reach: Backspace on an
    // empty input sends no key event there.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    await tester.pump();
    expect(find.text('Archived'), findsNothing);
    expect(find.text('Name'), findsOneWidget);
  });

  sheetTest('typing narrows a pinned list instead of leaving it', (
    tester,
  ) async {
    final vm = newHarnessVm(db);
    await pumpSheet(tester, vm, const [IsFilterKey(), NameFilterKey()]);

    await tester.tap(find.text('State'));
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'del');
    await tester.pump();
    await tester.pump();

    expect(find.text('Deleted'), findsOneWidget);
    expect(find.text('Archived'), findsNothing);
    expect(vm.search, '', reason: 'a value query is not a search');
  });

  sheetTest('a pick-only key opens with nothing written into the input', (
    tester,
  ) async {
    final vm = newHarnessVm(db);
    await pumpSheet(tester, vm, [FruitKey()]);

    await tester.tap(find.text('Fruit'));
    await tester.pump();
    await tester.pump();
    expect(boxText(tester), '', reason: 'it used to write `fruit:`');
    expect(find.text('Banana'), findsOneWidget);
  });

  sheetTest('a one-value key drops the text typed to find it', (tester) async {
    final vm = newHarnessVm(db);
    final overdue = DirectKey();
    await pumpSheet(tester, vm, [overdue]);

    await tester.enterText(find.byType(TextField), 'over');
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Overdue'));
    await tester.pump();
    await tester.pump();

    expect(overdue.added, 'true');
    expect(
      boxText(tester),
      '',
      reason: 'wide cleared it; the sheet copy did not',
    );
  });

  sheetTest('a chip the key will not prefill opens on an empty box', (
    tester,
  ) async {
    final vm = newHarnessVm(db);
    const date = DateColumnFilterKey(
      id: 'date',
      serverKey: 'date',
      labelKey: 'date',
    );
    await pumpSheet(tester, vm, const [date]);
    await vm.setExtraFilter(serverKey: 'date', values: {'gte:rel:d7'});
    await tester.pump();
    await tester.pump();

    // The field segment of the `Date · is on or after · 7 days ago` chip.
    await tester.tap(
      find.descendant(
        of: find.byType(FilterTokenChip),
        matching: find.text('Date'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(boxText(tester), '', reason: 'it read `date:gte:rel:d7`');
    expect(
      find.descendant(
        of: find.byType(PendingKeyChip),
        matching: find.text('Date'),
      ),
      findsOneWidget,
    );
  });

  sheetTest('tapping a chip edits it without removing it', (tester) async {
    final vm = newHarnessVm(db);
    await pumpSheet(tester, vm, [FruitKey()]);
    await vm.setExtraFilter(serverKey: 'fruit_id', values: {'a', 'b'});
    await tester.pump();
    await tester.pump();
    expect(find.byType(FilterTokenChip), findsNWidgets(2));

    await tester.tap(
      find.descendant(
        of: find.byType(FilterTokenChip),
        matching: find.text('Apple'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(vm.extraFilters['fruit_id'], {
      'a',
      'b',
    }, reason: 'the chip used to be removed before its picker opened');

    // Picking another value replaces the one on the chip.
    await tester.tap(find.text('Cherry'));
    await tester.pump();
    await tester.pump();
    expect(vm.extraFilters['fruit_id'], {'b', 'c'});
  });

  sheetTest('a filter picked in the sheet keeps the search it opened on', (
    tester,
  ) async {
    final vm = newHarnessVm(db);
    vm.setSearch('acme', immediate: true);
    await pumpSheet(tester, vm, [FruitKey()]);
    expect(boxText(tester), 'acme');
    // The list it opened on is not ranked by the search.
    expect(find.text('Fruit'), findsOneWidget);

    await tester.tap(find.text('Fruit'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Banana'));
    await tester.pump();
    await tester.pump();

    expect(vm.extraFilters['fruit_id'], {'b'});
    expect(vm.search, 'acme', reason: 'starting the filter dropped it');
    expect(find.widgetWithText(FilterTokenChip, '"acme"'), findsOneWidget);
  });

  testWidgets('← walks into the chips in the sheet too', (tester) async {
    final vm = newHarnessVm(db);
    await pumpSheet(tester, vm, [FruitKey()]);
    await vm.setExtraFilter(serverKey: 'fruit_id', values: {'a', 'b'});
    await tester.pump();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    bool armed(String label) => tester
        .widget<FilterTokenChip>(find.widgetWithText(FilterTokenChip, label))
        .armed;
    expect(armed('Banana'), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    await tester.pump();
    expect(vm.extraFilters['fruit_id'], {'a'});
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('⌘V in the sheet reads a query too', (tester) async {
    final vm = newHarnessVm(db);
    await pumpSheet(tester, vm, const [
      IsFilterKey(),
    ], clipboard: 'is:archived corp');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    await tester.pump();
    expect(vm.states, contains(EntityState.archived));
    expect(boxText(tester), 'corp');
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  // On a phone the long-press menu's Paste is the only paste there is. It
  // used to be the platform's own, which dropped a query in as raw text.
  sheetTest('long-press Paste reads a query', (tester) async {
    // The platform reports text on the clipboard, so the menu offers Paste.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.hasStrings' ? {'value': true} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final vm = newHarnessVm(db);
    await pumpSheet(tester, vm, const [
      IsFilterKey(),
    ], clipboard: 'is:archived corp');

    await tester.longPress(find.byType(TextField));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Paste'));
    await tester.pump();
    await tester.pump();

    expect(vm.states, contains(EntityState.archived));
    expect(boxText(tester), 'corp');
  });
}
