// The ✕ that erases the typed search, on the wide field and the phone sheet.
// Before it, the only button in the box was the Clear filters funnel, which
// users did not read as "clear the search" — they deleted the text a key at a
// time.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/core/list/search/filter_entry_sheet.dart';
import 'package:admin/ui/features/clients/client_filter_keys.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../_localization_helper.dart';
import '_token_search_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  // Ends by letting the view model's debounced `nav_state` write fire.
  void clearTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  String boxText(WidgetTester tester) =>
      tester.widget<TextField>(inputFinder).controller!.text;

  FocusNode boxFocus(WidgetTester tester) =>
      tester.widget<TextField>(inputFinder).focusNode!;

  final clearSearch = find.byTooltip('Clear');
  final clearFilters = find.byTooltip('Clear Filters');

  group('wide field', () {
    clearTest('a typed search gets a ✕, not the Clear filters funnel', (
      tester,
    ) async {
      final vm = newHarnessVm(db);
      await pumpWideField(tester, vm: vm, keys: const [IsFilterKey()]);
      expect(clearSearch, findsNothing);

      await tester.tap(inputFinder);
      await tester.enterText(inputFinder, 'acme');
      await settleSearch(tester);
      expect(vm.search, 'acme');
      expect(clearSearch, findsOneWidget);
      expect(clearFilters, findsNothing);

      await tester.tap(clearSearch);
      await settleSearch(tester);

      expect(boxText(tester), '');
      expect(vm.search, '');
      expect(boxFocus(tester).hasFocus, isTrue, reason: 'ready to retype');
      expect(clearSearch, findsNothing);
    });

    clearTest('the ✕ erases the search and keeps every filter', (tester) async {
      final vm = newHarnessVm(db);
      await vm.setStates({EntityState.active, EntityState.archived});
      await pumpWideField(tester, vm: vm, keys: const [IsFilterKey()]);
      expect(clearFilters, findsOneWidget);

      await tester.tap(inputFinder);
      await tester.enterText(inputFinder, 'acme');
      await settleSearch(tester);
      await tester.tap(clearSearch);
      await settleSearch(tester);

      expect(vm.search, '');
      expect(vm.states, {EntityState.active, EntityState.archived});
      expect(clearFilters, findsOneWidget);
    });
  });

  group('phone sheet', () {
    Future<void> pumpSheet(WidgetTester tester, HarnessVm vm) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: FilterEntrySheet(
            vm: vm,
            filterKeys: const [IsFilterKey()],
            hintKey: 'search',
            // A results list makes the search live, as on a real list.
            resultTile: (_, _, _) => const SizedBox.shrink(),
            onOpenRecord: (_) {},
            // Never the platform clipboard: awaiting it hangs a widget test.
            readClipboard: () async => null,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    clearTest('a typed search gets a ✕ that erases it', (tester) async {
      final vm = newHarnessVm(db);
      await pumpSheet(tester, vm);
      expect(clearSearch, findsNothing);

      await tester.enterText(inputFinder, 'acme');
      await settleSearch(tester);
      expect(vm.search, 'acme');

      await tester.tap(clearSearch);
      await settleSearch(tester);

      expect(boxText(tester), '');
      expect(vm.search, '');
      expect(boxFocus(tester).hasFocus, isTrue);
      expect(clearSearch, findsNothing);
    });
  });
}
