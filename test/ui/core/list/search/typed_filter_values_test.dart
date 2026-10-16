// What a value TYPED after `<key>:` is allowed to mean. These are the rules
// the field's Enter path and the suggestion menu's rows both go through:
// `DateColumnFilterKey.parseTypedDate`, `ComparableFilterKey.normalizeTypedNumber`,
// `splitTypedOperator`, and the key-list ranking.

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/relative_date_token.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_menu.dart';
import 'package:admin/ui/core/list/search/token_search_controller.dart';
import 'package:admin/ui/features/clients/client_filter_keys.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';

import '../../../../_localization_helper.dart';
import '_token_search_harness.dart';

void main() {
  const date = DateColumnFilterKey(
    id: 'date',
    serverKey: 'date',
    labelKey: 'date',
  );
  const dueWindow = DateColumnFilterKey(
    id: 'due_date',
    serverKey: 'due_date',
    labelKey: 'due_date',
    windowOnly: true,
  );
  // Far from midnight in every zone CI and the dev machines use.
  final now = DateTime(2026, 5, 14, 12);

  group('splitTypedOperator', () {
    test('symbols, their ASCII forms and the wire names', () {
      expect(splitTypedOperator('<500'), (op: FilterOp.lt, value: '500'));
      expect(splitTypedOperator('>= 500'), (op: FilterOp.gte, value: '500'));
      expect(splitTypedOperator('≤30'), (op: FilterOp.lte, value: '30'));
      expect(splitTypedOperator('=7'), (op: FilterOp.eq, value: '7'));
      expect(splitTypedOperator('gte:2026-01-01'), (
        op: FilterOp.gte,
        value: '2026-01-01',
      ));
    });

    test('no operator is null — not the key default', () {
      expect(splitTypedOperator(' 500 '), (op: null, value: '500'));
      expect(splitTypedOperator(''), (op: null, value: ''));
    });
  });

  group('parseTypedDate', () {
    ({String value, FilterOp? op})? parse(String typed, {String? pattern}) =>
        date.parseTypedDate(typed, activePattern: pattern, now: now);

    test('an ISO date, with or without a typed comparator', () {
      expect(parse('2026-05-14'), (value: '2026-05-14', op: null));
      expect(parse('<2026-05-14'), (value: '2026-05-14', op: FilterOp.lt));
      expect(parse('>=2026-05-14'), (value: '2026-05-14', op: FilterOp.gte));
    });

    test('the short forms a date field accepts, in the company pattern', () {
      expect(parse('5/14/2026'), (value: '2026-05-14', op: null));
      expect(parse('14/05/2026', pattern: 'dd/MM/yyyy'), (
        value: '2026-05-14',
        op: null,
      ));
      expect(parse('May 14, 2026'), (value: '2026-05-14', op: null));
    });

    test('today / yesterday roll; tomorrow is absolute', () {
      // Rolling tokens, so a saved view keeps meaning "today".
      expect(parse('today'), (value: 'rel:d0', op: null));
      expect(parse('Yesterday'), (value: 'rel:d1', op: null));
      expect(parse('<today'), (value: 'rel:d0', op: FilterOp.lt));
      expect(parse('tomorrow'), (value: '2026-05-15', op: null));
      // A rolling token someone typed or pasted passes through.
      expect(parse('rel:d7'), (value: 'rel:d7', op: null));
    });

    test('bare shortcuts are NOT dates here', () {
      // `parseDateInput` reads these as "the 20th", "tomorrow", "May 14" —
      // right for a date field committed on blur, wrong mid-way through
      // typing `2026-05-14`, where Enter would commit the 20th.
      expect(parse('20'), isNull);
      expect(parse('2'), isNull);
      expect(parse('+1'), isNull);
      expect(parse('-7'), isNull);
      expect(parse('0514'), isNull);
    });

    test('garbage, an empty value and a window are not single dates', () {
      expect(parse('banana'), isNull);
      expect(parse(''), isNull);
      expect(parse('>'), isNull);
      expect(parse('2026-13-40'), isNull);
      expect(parse('2026-01-01,2026-02-01'), isNull);
    });

    test('a window-only key keeps "today" rolling too', () {
      // It froze to the date typed while a window's bounds could not roll.
      expect(dueWindow.parseTypedDate('today', now: now), (
        value: 'rel:d0',
        op: null,
      ));
    });
  });

  testWidgets('normalizeTypedValue builds the canonical wire', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final vm = newHarnessVm(db);

    // Dates: the key's default comparator unless one was typed.
    expect(
      date.normalizeTypedValue(vm, context, '2026-05-14'),
      'gte:2026-05-14',
    );
    expect(
      date.normalizeTypedValue(vm, context, '<2026-05-14'),
      'lt:2026-05-14',
    );
    expect(date.normalizeTypedValue(vm, context, 'banana'), isNull);
    expect(date.normalizeTypedValue(vm, context, '20'), isNull);
    // A window-only key turns one day into that day's window.
    expect(
      dueWindow.normalizeTypedValue(vm, context, '2026-05-14'),
      'due_date,2026-05-14,2026-05-14',
    );
    // A typed window is still a window.
    expect(
      date.normalizeTypedValue(vm, context, '2026-01-01,2026-02-01'),
      '2026-01-01,2026-02-01',
    );

    // Amounts.
    const balance = BalanceFilterKey();
    expect(balance.normalizeTypedValue(vm, context, '<500'), 'lt:500');
    expect(balance.normalizeTypedValue(vm, context, '1,000'), 'gt:1000');
    expect(balance.normalizeTypedValue(vm, context, '>= 12.50'), 'gte:12.5');
    expect(balance.normalizeTypedValue(vm, context, 'abc'), isNull);
    expect(balance.normalizeTypedValue(vm, context, '>'), isNull);
    expect(balance.normalizeTypedValue(vm, context, '12 apples'), isNull);
    // Not a number at all once the separators are read: `parseDecimal`
    // answers zero for these rather than failing, which made them `> 0`.
    expect(balance.normalizeTypedValue(vm, context, '1.2.3'), isNull);
    expect(balance.normalizeTypedValue(vm, context, '1.234.567'), isNull);
    expect(balance.normalizeTypedValue(vm, context, '-250'), 'gt:-250');

    // What a chip tap prefills. A typed-value key hands back what was typed;
    // a rolling date has no typeable form and prefills nothing.
    expect(const VatFilterKey().editableValueText('X1'), 'X1');
    expect(date.editableValueText('gte:rel:d7'), isNull);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a typed period: matched as you type, committed by name', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final vm = newHarnessVm(db);

    List<RollingDatePreset> matches(DateColumnFilterKey k, String typed) =>
        k.typedPresetMatches(context, typed);

    // The name's start, in this key's menu order.
    expect(matches(date, 'th'), const [
      RollingDatePreset.thisWeek,
      RollingDatePreset.thisMonth,
      RollingDatePreset.thisQuarter,
      RollingDatePreset.thisYear,
    ]);
    expect(matches(date, 'THIS  mo'), const [RollingDatePreset.thisMonth]);
    // One word matches any word of the name.
    expect(matches(date, 'month'), const [
      RollingDatePreset.thisMonth,
      RollingDatePreset.lastMonth,
      RollingDatePreset.nextMonth,
    ]);
    // Every period, not only the key's own: a due date's menu offers no
    // "Last month", but typing it means it.
    const due = DateColumnFilterKey(
      id: 'due_date',
      serverKey: 'due_date',
      labelKey: 'due_date',
      lookAhead: true,
    );
    expect(matches(due, 'last mo'), const [RollingDatePreset.lastMonth]);
    // Nothing typed, a comparator, or a word no period has.
    expect(matches(date, ''), isEmpty);
    expect(matches(date, '>=th'), isEmpty);
    expect(matches(date, 'banana'), isEmpty);

    // Committed by its full name — Enter in the sheet, a quoted paste.
    expect(
      date.normalizeTypedValue(vm, context, 'this month'),
      'date,rel:m0s,rel:m0e',
    );
    expect(
      date.normalizeTypedValue(vm, context, 'Last Quarter'),
      'date,rel:q1s,rel:q1e',
    );
    // A part of a name is not a value.
    expect(date.normalizeTypedValue(vm, context, 'this mo'), isNull);
    // today / yesterday stay single dates.
    expect(date.normalizeTypedValue(vm, context, 'today'), 'gte:rel:d0');

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('rankFilterKeys puts prefix matches first', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    const keys = <FilterKey>[
      VatFilterKey(),
      BalanceFilterKey(),
      NameFilterKey(),
      IsFilterKey(),
      IdNumberFilterKey(),
    ];
    List<String> ids(String query) => [
      for (final k in rankFilterKeys(keys, query, context)) k.id,
    ];

    // Empty query: every key, A→Z by label (Balance, ID Number, Name, State,
    // VAT Number).
    expect(ids(''), ['balance', 'id_number', 'name', 'is', 'vat']);
    // `n`: Name starts with it; the others merely contain it.
    expect(ids('n').first, 'name');
    expect(ids('n'), containsAll(<String>['id_number', 'vat', 'balance']));
    // An alias prefix counts (`state` → the `is` key).
    expect(ids('sta'), ['is']);
    expect(ids('zzz'), isEmpty);
  });

  testWidgets('a pasted query passes the same gate as a typed one', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final vm = newHarnessVm(db);
    final controller = TokenSearchController(
      vm: vm,
      filterKeys: [
        const IsFilterKey(),
        const NameFilterKey(),
        const BalanceFilterKey(),
        FruitKey(),
      ],
      initialText: '',
    );
    addTearDown(controller.dispose);

    // `applyPastedQuery` is the clipboard-free half of `handlePaste`.
    expect(
      controller.applyPastedQuery(
        'is:archived name:acme balance:abc fruit:zzz hello',
        context,
      ),
      isTrue,
    );
    await tester.pump();
    // A pick-only key takes a value that names one of its own exactly…
    expect(vm.states, contains(EntityState.archived));
    // …a typed key takes what its normalizer accepts…
    expect(vm.extraFilters['name'], {'acme'});
    // …and what would have been refused when typed is refused when pasted.
    // It used to go straight to `addValue`: `balance=gt:abc`, `fruit_id=zzz`.
    expect(vm.extraFilters['balance'], isNull);
    expect(vm.extraFilters['fruit_id'], isNull);
    // The first refused token is left to be finished — its key pinned, its
    // value in the box — and the free text is the search, beside it.
    expect(controller.pinnedValueKey?.id, 'balance');
    expect(controller.text.text, 'abc');
    expect(controller.searchInChip, isTrue);
    expect(vm.search, 'hello');

    // Nothing understood: the caller pastes it as plain text.
    expect(controller.applyPastedQuery('fruit:zzz', context), isFalse);
    expect(controller.applyPastedQuery('just some text', context), isFalse);

    // Leftover free text is shown AND searched.
    controller.clearBox();
    expect(controller.applyPastedQuery('is:deleted acme', context), isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(vm.states, contains(EntityState.deleted));
    expect(controller.text.text, 'acme');
    expect(vm.search, 'acme');

    await tester.pump(const Duration(seconds: 1));
  });

  group('a paste lands where the caret is', () {
    late BuildContext context;
    late HarnessVm vm;
    late TokenSearchController controller;
    late ToastController toasts;

    Future<void> setUpController(WidgetTester tester) async {
      toasts = ToastController();
      addTearDown(toasts.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          // `Notify` prefers a provided ToastController over `Services`.
          home: ChangeNotifierProvider<ToastController>.value(
            value: toasts,
            child: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      vm = newHarnessVm(db);
      controller = TokenSearchController(
        vm: vm,
        filterKeys: [const IsFilterKey(), const BalanceFilterKey(), FruitKey()],
        initialText: '',
      );
      addTearDown(controller.dispose);
    }

    void type(String text, {TextSelection? selection}) {
      controller.text.value = TextEditingValue(
        text: text,
        selection: selection ?? TextSelection.collapsed(offset: text.length),
      );
      vm.setSearch(text, immediate: true);
    }

    testWidgets('its free text joins the search already in the box', (
      tester,
    ) async {
      await setUpController(tester);
      type('acme');
      // It used to replace the whole box, `acme` with it.
      expect(controller.applyPastedQuery('is:archived corp', context), isTrue);
      await tester.pump();
      expect(vm.states, contains(EntityState.archived));
      expect(controller.text.text, 'acme corp');
      expect(vm.search, 'acme corp');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('it replaces a selection, as a paste does', (tester) async {
      await setUpController(tester);
      type(
        'acme corp',
        selection: const TextSelection(baseOffset: 5, extentOffset: 9),
      );
      expect(controller.applyPastedQuery('is:archived inc', context), isTrue);
      await tester.pump();
      expect(controller.text.text, 'acme inc');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('beside a search chip its text is a candidate', (tester) async {
      await setUpController(tester);
      type('acme');
      controller.pickKey(FruitKey(), context);
      controller.clearPinnedValueKey();
      expect(controller.searchInChip, isTrue);

      expect(controller.applyPastedQuery('is:archived corp', context), isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(controller.text.text, 'corp');
      expect(vm.search, 'acme', reason: 'the candidate is not applied');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a refused token sets the search in the box aside', (
      tester,
    ) async {
      await setUpController(tester);
      type('acme');
      expect(
        controller.applyPastedQuery('is:archived balance:abc', context),
        isTrue,
      );
      await tester.pump();
      expect(controller.pinnedValueKey?.id, 'balance');
      expect(controller.text.text, 'abc');
      expect(controller.searchInChip, isTrue);
      expect(vm.search, 'acme');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a refused value is left to finish as it was, spaces and all', (
      tester,
    ) async {
      await setUpController(tester);
      expect(
        controller.applyPastedQuery(
          'is:archived balance:"twelve pounds"',
          context,
        ),
        isTrue,
      );
      expect(controller.pinnedValueKey?.id, 'balance');
      expect(controller.text.text, 'twelve pounds');
      await tester.pump(const Duration(seconds: 1));
    });

    // It used to write `balance:bogus acme` into the box, where the typed
    // prefix became the Balance key with `bogus acme` as its value: the
    // search vanished into a value that matched nothing.
    testWidgets('free text beside a refused token is the search, not its '
        'value', (tester) async {
      await setUpController(tester);
      type('north');
      expect(
        controller.applyPastedQuery('is:archived balance:bogus acme', context),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(vm.states, contains(EntityState.archived));
      expect(controller.text.text, 'bogus');
      expect(controller.searchInChip, isTrue);
      expect(vm.search, 'north acme');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('only one refused filter can be finished; the rest are named '
        'in a toast', (tester) async {
      await setUpController(tester);
      expect(
        controller.applyPastedQuery(
          'is:archived balance:bogus fruit:zzz',
          context,
        ),
        isTrue,
      );
      expect(controller.pinnedValueKey?.id, 'balance');
      expect(controller.text.text, 'bogus');
      expect(toasts.toasts.single.message, contains('fruit:zzz'));
      // The toast's own dismissal timer, so the test ends with none pending.
      toasts.clearAll();
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('typed prefixes reach only keys the picker would offer', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final vm = newHarnessVm(db, locked: {'fruit'});
    final controller = TokenSearchController(
      vm: vm,
      // `email` is registered but hidden (`isAvailable` false); `fruit` is
      // locked by the embedding parent.
      filterKeys: [const NameFilterKey(), const EmailFilterKey(), FruitKey()],
      initialText: '',
    );
    addTearDown(controller.dispose);

    expect([for (final k in controller.typeableKeys) k.id], ['name']);

    controller.text.text = 'name:acme';
    expect(controller.parseInput().matchedKey?.id, 'name');
    controller.text.text = 'email:a@b.c';
    expect(controller.parseInput().matchedKey, isNull);
    controller.text.text = 'fruit:a';
    expect(controller.parseInput().matchedKey, isNull);

    await tester.pump(const Duration(seconds: 1));
  });
}
