import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/segment_menu.dart';
import 'package:admin/ui/features/clients/client_filter_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The clients list's `created` / `updated` filters are the shared
// `DateColumnFilterKey` (its operator menu includes `between`). These pin the
// SegmentMenu behavior against that exact key type.
// The clients list's two timestamps, as registered there.
const _created = DateColumnFilterKey(
  id: 'created',
  serverKey: 'created_at',
  labelKey: 'created',
  hasTime: true,
);
const _updated = DateColumnFilterKey(
  id: 'updated',
  serverKey: 'updated_at',
  labelKey: 'updated',
  hasTime: true,
);

/// Phase 6: the dedicated per-segment dropdown. It commits straight
/// through the key (`changeOp` / `addValue`) and never owns or writes a
/// search text controller — these assert the resulting VM state.
///
/// SegmentMenu touches the VM through exactly one surface:
/// `ComparableFilterKey.changeOp` / `addValue` → `writeSingleExtraFilter`
/// → `vm.setExtraFilter` (and the test reads back `vm.extraFilters`).
/// So a tiny `noSuchMethod` fake is used — instantiating the real
/// `GenericListViewModel` here booted its Drift nav-state subscription +
/// debounce timers, which dead-locked / left a pending Timer under the
/// `testWidgets` fake clock (the prior hang). Rows are tapped by INDEX
/// (op order = `supportedOps`; preset order = `kRelativeDatePresets`) so
/// the test is locale-independent.
class _FakeVm implements GenericListViewModel<dynamic> {
  final Map<String, Set<String>> _extra = {};

  @override
  Map<String, Set<String>> get extraFilters => _extra;

  @override
  Future<void> setExtraFilter({
    required String serverKey,
    required Set<String> values,
  }) async {
    if (values.isEmpty) {
      _extra.remove(serverKey);
    } else {
      _extra[serverKey] = values;
    }
  }

  @override
  Future<void> swapExtraFilter({
    required String fromServerKey,
    required String toServerKey,
    required String wireValue,
    String? alsoClearServerKey,
  }) async {
    _extra.remove(fromServerKey);
    if (alsoClearServerKey != null) _extra.remove(alsoClearServerKey);
    _extra[toServerKey] = {wireValue};
  }

  // SegmentMenu / the key write path never call anything else on the VM.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: buildInTheme(
      InTheme.light,
    ).copyWith(splashFactory: NoSplash.splashFactory),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('comparator: 6 rows, current op checked, tap rewrites the '
      'op only (value preserved) and closes', (tester) async {
    final vm = _FakeVm();
    var closed = false;
    await tester.pumpWidget(
      host(
        SegmentMenu(
          vm: vm,
          filterKey: _created,
          kind: SegmentKind.comparator,
          currentWire: 'gte:2026-01-01',
          onClose: () => closed = true,
        ),
      ),
    );
    await tester.pump();

    // supportedOps == [gt, gte, lt, lte, eq, between] → 6 rows; gte (index 1,
    // the current op) is check-marked.
    expect(find.byType(InkWell), findsNWidgets(6));
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.byType(InkWell).at(2)); // index 2 == lt
    await tester.pump();

    expect(vm.extraFilters['created_at'], {'lt:2026-01-01'});
    expect(closed, isTrue);
  });

  testWidgets('date value: 5 relative presets + Absolute date; a preset '
      'commits the rolling token keeping the current op', (tester) async {
    final vm = _FakeVm();
    await tester.pumpWidget(
      host(
        SegmentMenu(
          vm: vm,
          filterKey: _created,
          kind: SegmentKind.value,
          currentWire: 'lt:2026-01-01',
          onClose: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(InkWell), findsNWidgets(6)); // 5 presets + absolute

    // kRelativeDatePresets[2] == ('rel:d7', '7 days ago').
    await tester.tap(find.byType(InkWell).at(2));
    await tester.pump();

    // Value is the rolling token; the op (lt) is preserved.
    expect(vm.extraFilters['created_at'], {'lt:rel:d7'});
  });

  testWidgets('a window chip lists the rolling windows, its own ticked, and '
      'a pick rolls', (tester) async {
    final vm = _FakeVm();
    await tester.pumpWidget(
      host(
        SegmentMenu(
          vm: vm,
          filterKey: _created,
          kind: SegmentKind.value,
          currentWire: 'created_at,rel:m0s,rel:m0e',
          onClose: () {},
        ),
      ),
    );
    await tester.pump();

    // Ten windows (the current periods, then the last ones), then Custom
    // range — more than the 360 px popup shows at once, so the list scrolls.
    final rows = find.byType(InkWell);
    // This month — the third — is the one applied.
    expect(
      find.descendant(of: rows.at(2), matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(rows.at(1)); // This week
    await tester.pump();
    expect(vm.extraFilters['created_at_range'], {'created_at,rel:w0s,rel:w0e'});
  });

  testWidgets('a date with no time of day offers no hour presets', (
    tester,
  ) async {
    final vm = _FakeVm();
    await tester.pumpWidget(
      host(
        SegmentMenu(
          vm: vm,
          filterKey: const DateColumnFilterKey(
            id: 'date',
            serverKey: 'date',
            labelKey: 'date',
          ),
          kind: SegmentKind.value,
          currentWire: 'lt:2026-01-01',
          onClose: () {},
        ),
      ),
    );
    await tester.pump();

    // "1 hour ago" on a date column matched nothing for the whole day.
    expect(find.byType(InkWell), findsNWidgets(4)); // 3 day presets + absolute
    expect(find.text('1 hour ago'), findsNothing);
  });

  testWidgets('numeric value: prefilled field, Enter commits buildWire '
      'with the current op (no search-field text involved)', (tester) async {
    final vm = _FakeVm();
    var closed = false;
    await tester.pumpWidget(
      host(
        SegmentMenu(
          vm: vm,
          filterKey: const BalanceFilterKey(),
          kind: SegmentKind.value,
          currentWire: 'gt:1000',
          onClose: () => closed = true,
        ),
      ),
    );
    await tester.pump();

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(
      tester.widget<TextField>(field).controller!.text,
      '1000',
      reason: 'value segment prefills the bare value',
    );

    await tester.enterText(field, '500');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(vm.extraFilters['balance'], {'gt:500'});
    expect(closed, isTrue);
  });

  testWidgets('field: lists same-type keys, current checked; picking '
      'another swaps the server key carrying op+value, and closes', (
    tester,
  ) async {
    final vm = _FakeVm();
    vm._extra['created_at'] = {'gte:2026-01-01'};
    var closed = false;
    await tester.pumpWidget(
      host(
        SegmentMenu(
          vm: vm,
          filterKey: _created,
          kind: SegmentKind.field,
          currentWire: 'gte:2026-01-01',
          onClose: () => closed = true,
          fieldChoices: const [_created, _updated],
        ),
      ),
    );
    await tester.pump();

    // Two rows; the current key (Created, index 0) is check-marked.
    expect(find.byType(InkWell), findsNWidgets(2));
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Pick Updated (index 1) → server key swaps, op+value carried.
    await tester.tap(find.byType(InkWell).at(1));
    await tester.pump();

    expect(vm.extraFilters.containsKey('created_at'), isFalse);
    expect(vm.extraFilters['updated_at'], {'gte:2026-01-01'});
    expect(closed, isTrue);
  });

  testWidgets('field: tapping the already-selected key is a no-op close', (
    tester,
  ) async {
    final vm = _FakeVm();
    vm._extra['created_at'] = {'gte:2026-01-01'};
    var closed = false;
    await tester.pumpWidget(
      host(
        SegmentMenu(
          vm: vm,
          filterKey: _created,
          kind: SegmentKind.field,
          currentWire: 'gte:2026-01-01',
          onClose: () => closed = true,
          fieldChoices: const [_created, _updated],
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(InkWell).at(0)); // Created (current)
    await tester.pump();

    expect(vm.extraFilters['created_at'], {'gte:2026-01-01'});
    expect(vm.extraFilters.containsKey('updated_at'), isFalse);
    expect(closed, isTrue);
  });
}
