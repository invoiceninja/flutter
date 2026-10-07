// What a value TYPED after `<key>:` is allowed to mean. These are the rules
// the field's Enter path and the suggestion menu's rows both go through:
// `DateColumnFilterKey.parseTypedDate`, `ComparableFilterKey.normalizeTypedNumber`,
// `splitTypedOperator`, and the key-list ranking.

import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_menu.dart';
import 'package:admin/ui/core/list/search/token_search_controller.dart';
import 'package:admin/ui/features/clients/client_filter_keys.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    test('a window-only key has no rolling form', () {
      expect(dueWindow.parseTypedDate('today', now: now), (
        value: '2026-05-14',
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
    // Refused tokens are not dropped — they stay in the box with the rest.
    expect(controller.text.text, 'balance:abc fruit:zzz hello');
    expect(vm.search, '', reason: 'a filter left in the box is not a search');

    // Nothing understood: the caller pastes it as plain text.
    expect(controller.applyPastedQuery('fruit:zzz', context), isFalse);
    expect(controller.applyPastedQuery('just some text', context), isFalse);

    // Leftover free text is shown AND searched.
    expect(controller.applyPastedQuery('is:deleted acme', context), isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(vm.states, contains(EntityState.deleted));
    expect(controller.text.text, 'acme');
    expect(vm.search, 'acme');

    await tester.pump(const Duration(seconds: 1));
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
