// The desktop line-item table rebuilds whenever the edit view model notifies —
// every committed keystroke anywhere on the document — and it used to rebuild
// every row each time: a fifty-line invoice paid for fifty rows of cells to
// change one (`screens.invoice_edit_typing` went 149 → 60 ms when that
// stopped; docs/performance-tracking.md). A row is now reused while nothing
// it shows, and nothing its callbacks capture, has changed (`_RowInputs`).
//
// What is pinned: an edit rebuilds the edited row only; a rebuild that changes
// nothing rebuilds no row; a change every row shows (the column config)
// rebuilds them all; and a reused row's callbacks still act on the right line.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';

import '../shell/_shell_test_helpers.dart';

LineItem _line(int i) => emptyLineItem().copyWith(
  productKey: 'P$i',
  notes: 'Line $i',
  cost: Decimal.fromInt(10 + i),
  quantity: Decimal.one,
);

/// Owns the list and the config the way the edit layouts do, and re-renders
/// the table with whatever it is handed.
class _Host extends StatefulWidget {
  const _Host({super.key, required this.initial, required this.onChanged});

  final List<LineItem> initial;
  final ValueChanged<List<LineItem>> onChanged;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<LineItem> items = widget.initial;
  LineItemColumnConfig config = const LineItemColumnConfig();
  Map<int, Map<String, String>>? rowErrors;

  void update({
    List<LineItem>? items,
    LineItemColumnConfig? config,
    Map<int, Map<String, String>>? rowErrors,
  }) => setState(() {
    this.items = items ?? this.items;
    this.config = config ?? this.config;
    this.rowErrors = rowErrors ?? this.rowErrors;
  });

  @override
  Widget build(BuildContext context) => LineItemTableDesktop(
    companyId: 'co1',
    items: items,
    onChanged: (next) {
      widget.onChanged(next);
      setState(() => items = next);
    },
    newItemFactory: emptyLineItem,
    // A fresh, equal config on every build — what `forCompany` hands the
    // table in the app.
    config: config.copyWith(),
    // A fresh map on every build too, like `lineItemRowErrors`.
    rowErrors: rowErrors == null ? null : {...rowErrors!},
  );
}

void main() {
  const count = 20;
  final host = GlobalKey<_HostState>();
  late List<List<LineItem>> emitted;
  late ShellFixture fixture;

  Future<void> pumpTable(WidgetTester tester) async {
    emitted = [];
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        SingleChildScrollView(
          child: _Host(
            key: host,
            initial: [for (var i = 0; i < count; i++) _line(i)],
            onChanged: emitted.add,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Unmounts before the fixture closes: a mounted table still watches the
  /// company row, and the database's close waits for that stream to go.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<int> rowBuildsDuring(Future<void> Function() action) async {
    final before = debugLineItemRowBuilds;
    await action();
    return debugLineItemRowBuilds - before;
  }

  testWidgets('a rebuild that changes nothing rebuilds no row', (tester) async {
    await pumpTable(tester);
    expect(find.text('Line ${count - 1}'), findsOneWidget);

    final builds = await rowBuildsDuring(() async {
      host.currentState!.update(
        items: [for (var i = 0; i < count; i++) _line(i)],
      );
      await tester.pump();
    });
    expect(
      builds,
      0,
      reason:
          'an equal list, a fresh equal config: every row is as it was, so '
          'every row widget is reused',
    );
    await unmount(tester);
  });

  testWidgets('changing one line rebuilds that row only', (tester) async {
    await pumpTable(tester);
    final items = [for (var i = 0; i < count; i++) _line(i)];
    items[7] = items[7].copyWith(notes: 'Changed');

    final builds = await rowBuildsDuring(() async {
      host.currentState!.update(items: items);
      await tester.pump();
    });
    expect(builds, 1);
    expect(find.text('Changed'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('typing in a cell rebuilds that row only, through the commit', (
    tester,
  ) async {
    await pumpTable(tester);
    final notes = find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == 'Line 3',
    );
    expect(notes, findsOneWidget);

    final builds = await rowBuildsDuring(() async {
      await tester.enterText(notes, 'Line 3, revised');
      await tester.pump();
      // The cell's 250 ms debounce, the commit, and the host's rebuild.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
    });
    expect(emitted.last[3].notes, 'Line 3, revised');
    expect(builds, 1);
    await unmount(tester);
  });

  testWidgets('a change every row shows rebuilds every row', (tester) async {
    await pumpTable(tester);
    final builds = await rowBuildsDuring(() async {
      host.currentState!.update(
        config: const LineItemColumnConfig(showDiscount: true),
      );
      await tester.pump();
    });
    expect(builds, count + 1, reason: 'every line, and the ghost row');
    await unmount(tester);
  });

  testWidgets('a reused row still acts on its own line', (tester) async {
    await pumpTable(tester);
    // Change line 2, so every other row is reused from an earlier build —
    // with callbacks that build captured.
    final items = [for (var i = 0; i < count; i++) _line(i)];
    items[2] = items[2].copyWith(notes: 'Changed');
    host.currentState!.update(items: items);
    await tester.pump();

    // Remove line 5 through its own row menu.
    await tester.tap(find.byIcon(Icons.more_vert).at(5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Remove').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final last = emitted.last;
    expect(last, hasLength(count - 1));
    expect(last.map((l) => l.productKey), isNot(contains('P5')));
    expect(last[2].notes, 'Changed', reason: 'the edit made before survives');
    await unmount(tester);
  });

  Future<void> rowMenu(WidgetTester tester, int index, String action) async {
    await tester.tap(find.byIcon(Icons.more_vert).at(index));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(action).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a moved row acts on its new position', (tester) async {
    await pumpTable(tester);
    // P5 moves up to index 4. Were a row reused with the index its callbacks
    // captured before the move, its menu would act on index 5 — now P4.
    await rowMenu(tester, 5, 'Move Up');
    expect(emitted.last[4].productKey, 'P5');
    await rowMenu(tester, 4, 'Remove');
    expect(
      emitted.last.map((l) => l.productKey),
      allOf(isNot(contains('P5')), contains('P4')),
    );
    await unmount(tester);
  });

  testWidgets('a server error reaches its row, and only that row rebuilds', (
    tester,
  ) async {
    await pumpTable(tester);
    final builds = await rowBuildsDuring(() async {
      host.currentState!.update(
        rowErrors: {
          3: {'notes': 'The notes are too long'},
        },
      );
      await tester.pump();
    });
    expect(find.text('The notes are too long'), findsOneWidget);
    expect(builds, 1);
    await unmount(tester);
  });

  testWidgets('typing into the trailing blank row promotes it', (tester) async {
    await pumpTable(tester);
    final menusBefore = find.byIcon(Icons.more_vert).evaluate().length;
    final ghostNotes = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.controller?.text == '' &&
          w.decoration?.hintText == 'Description',
    );
    await tester.enterText(ghostNotes.last, 'A new line');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(emitted.last, hasLength(count + 1));
    expect(emitted.last.last.notes, 'A new line');
    expect(
      find.byIcon(Icons.more_vert).evaluate().length,
      menusBefore + 1,
      reason: 'the promoted row is a real line now and gets its menu',
    );
    await unmount(tester);
  });

  testWidgets('a company change rebuilds every row', (tester) async {
    await pumpTable(tester);
    final builds = await rowBuildsDuring(() async {
      await tester.runAsync(
        () => fixture.db.customUpdate(
          "UPDATE companies SET name = 'Renamed' WHERE id = 'co1'",
          updates: {fixture.db.companies},
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    });
    expect(builds, count + 1, reason: 'every row reads the company');
    await unmount(tester);
  });
}
