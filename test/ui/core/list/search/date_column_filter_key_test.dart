// A date filter's rolling windows, as the chip and the comparator switch see
// them.

import 'package:admin/data/db/app_database.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../_localization_helper.dart';
import '_token_search_harness.dart';

const _date = DateColumnFilterKey(
  id: 'date',
  serverKey: 'date',
  labelKey: 'date',
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<BuildContext> pumpContext(WidgetTester tester) async {
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
    return context;
  }

  testWidgets('a preset window reads as its name, its dates on hover', (
    tester,
  ) async {
    final context = await pumpContext(tester);
    final vm = newHarnessVm(db);
    await vm.setExtraFilter(
      serverKey: 'date_range',
      values: {'date,rel:m0s,rel:m0e'},
    );

    final token = _date.tokensFrom(vm, context).single;
    // It used to read `rel:m0s – rel:m0e`.
    expect(token.displayValue, 'This Month');
    expect(token.displayComparator, 'is');
    final today = DateTime.now();
    final first = '${today.year}-${today.month.toString().padLeft(2, '0')}-01';
    expect(token.valueTooltip, startsWith(first));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a rolling window that is no preset reads as its dates', (
    tester,
  ) async {
    final context = await pumpContext(tester);
    final vm = newHarnessVm(db);
    await vm.setExtraFilter(
      serverKey: 'date_range',
      values: {'date,rel:d3,rel:d0'},
    );
    final token = _date.tokensFrom(vm, context).single;
    expect(token.displayValue, isNot(contains('rel:')));
    expect(token.displayComparator, 'is between');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('switching a period window to a single date fixes the date', (
    tester,
  ) async {
    await pumpContext(tester);
    final vm = newHarnessVm(db);
    await _date.changeOp(vm, 'date,rel:m0s,rel:m0e', FilterOp.gte);
    final wire = vm.extraFilters['date']!.single;
    // "on or after the first of this month" must not move next month.
    expect(wire, startsWith('gte:'));
    expect(wire, isNot(contains('rel:')));

    // A rolling day stays rolling.
    await _date.changeOp(vm, 'date,rel:d7,rel:d0', FilterOp.gte);
    expect(vm.extraFilters['date'], {'gte:rel:d7'});
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a typed window may have rolling bounds', (tester) async {
    final context = await pumpContext(tester);
    final vm = newHarnessVm(db);
    expect(
      _date.normalizeTypedValue(vm, context, 'date,rel:w0s,rel:w0e'),
      'date,rel:w0s,rel:w0e',
    );
    expect(
      _date.normalizeTypedValue(vm, context, 'date,rel:zz,rel:w0e'),
      isNull,
    );
    await tester.pump(const Duration(seconds: 1));
  });

  test('a time-free column offers no hour presets; a timestamp does', () {
    expect(_date.singlePresets.map((p) => p.$1), isNot(contains('rel:h1')));
    const created = DateColumnFilterKey(
      id: 'created',
      serverKey: 'created_at',
      labelKey: 'created',
      hasTime: true,
    );
    expect(created.singlePresets.map((p) => p.$1), contains('rel:h1'));
  });

  test('a due date looks ahead', () {
    const due = DateColumnFilterKey(
      id: 'due_date',
      serverKey: 'due_date',
      labelKey: 'due_date',
      lookAhead: true,
    );
    expect(
      due.windowPresets.map((p) => p.labelKey),
      containsAll(<String>['next_week', 'next_month']),
    );
    expect(
      due.windowPresets.map((p) => p.labelKey),
      isNot(contains('last_year')),
    );
    expect(
      _date.windowPresets.map((p) => p.labelKey),
      isNot(contains('next_week')),
    );
  });
}
