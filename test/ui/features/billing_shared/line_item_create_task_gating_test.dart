// invoiceninja/flutter#88 — "Create Task" on a line item. The action is
// injected by the invoice / quote layouts, so `billing_shared` must render it
// only when a host wired it, and never on a row that already IS a task.
//
// Also pins the debounce trap: text cells commit on a 250 ms timer, so reading
// `widget.items[index]` in the menu handler would hand the sheet pre-keystroke
// text — and the description is the whole point of the seed.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_card_list_mobile.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';

import '../shell/_shell_test_helpers.dart';

LineItem _line({String notes = 'Boiler service', String? taskId}) =>
    emptyLineItem().copyWith(
      productKey: 'SVC-01',
      notes: notes,
      cost: Decimal.fromInt(150),
      quantity: Decimal.fromInt(2),
      taskId: taskId,
    );

void main() {
  late List<LineItem> captured;

  /// Every list the editor emits upward, so a test can assert what actually
  /// landed on the document — not just what the sheet was handed.
  late List<List<LineItem>> emitted;

  Future<ShellFixture> fixtureFor(WidgetTester tester) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    return fixture;
  }

  /// Drift schedules a zero-duration close timer on unsubscribe; unmount and
  /// elapse the clock so it fires before the "Timer still pending" invariant.
  Future<void> teardownSubtree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pumpDesktop(
    WidgetTester tester, {
    required bool wired,
    String? taskId,
  }) async {
    captured = <LineItem>[];
    emitted = <List<LineItem>>[];
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final fixture = await fixtureFor(tester);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        LineItemTableDesktop(
          companyId: 'co1',
          items: [_line(taskId: taskId)],
          onChanged: emitted.add,
          newItemFactory: emptyLineItem,
          config: const LineItemColumnConfig(),
          onCreateTaskFromLineItem: wired ? captured.add : null,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> openRowMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('desktop row menu', () {
    testWidgets('offers Create Task when a host wired the callback', (
      tester,
    ) async {
      await pumpDesktop(tester, wired: true);
      await openRowMenu(tester);
      expect(find.text('Create Task'), findsOneWidget);
      await teardownSubtree(tester);
    });

    testWidgets('omits it when no host wired one (credit / recurring / PO)', (
      tester,
    ) async {
      await pumpDesktop(tester, wired: false);
      await openRowMenu(tester);
      expect(find.text('Create Task'), findsNothing);
      // The rest of the menu is untouched.
      expect(find.text('Clone'), findsOneWidget);
      await teardownSubtree(tester);
    });

    testWidgets('omits it for a row that already is a task', (tester) async {
      await pumpDesktop(tester, wired: true, taskId: 'task-1');
      await openRowMenu(tester);
      expect(find.text('Create Task'), findsNothing);
      await teardownSubtree(tester);
    });

    testWidgets('hands over text typed inside the 250ms cell debounce', (
      tester,
    ) async {
      await pumpDesktop(tester, wired: true);

      // The notes cell of the first row. Typing then reaching straight for the
      // menu is the common case, and the debounce has not fired yet.
      final notes = find.widgetWithText(TextField, 'Boiler service');
      await tester.enterText(notes, 'Annual boiler service');
      await tester.pump(const Duration(milliseconds: 50));

      await openRowMenu(tester);
      await tester.tap(find.text('Create Task'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(captured, hasLength(1));
      expect(captured.single.notes, 'Annual boiler service');
      // The other half of the same flush: the typing must also reach the
      // document, or picking Create Task would quietly discard it.
      expect(emitted, isNotEmpty);
      expect(emitted.last.first.notes, 'Annual boiler service');
      await teardownSubtree(tester);
    });

    testWidgets('leaves the line item unlinked — no task_id, no type change', (
      tester,
    ) async {
      // The feature deliberately creates a STANDALONE task: linking would let
      // the server stamp `task.invoice_id` on save, which this app treats as
      // read-only and hides from kanban. Nothing may mutate the row.
      await pumpDesktop(tester, wired: true);
      await openRowMenu(tester);
      await tester.tap(find.text('Create Task'));
      await tester.pump(const Duration(milliseconds: 300));

      for (final list in emitted) {
        for (final item in list) {
          expect(item.taskId, isNull);
          expect(item.typeId, LineItemType.standard);
        }
      }
      await teardownSubtree(tester);
    });
  });

  group('mobile card', () {
    Future<void> pumpMobile(
      WidgetTester tester, {
      required bool wired,
      String? taskId,
    }) async {
      captured = <LineItem>[];
      // A small phone — two trailing icon buttons plus the drag handle and the
      // money label is the tightest this row ever gets.
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final fixture = await fixtureFor(tester);
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          LineItemCardListMobile(
            companyId: 'co1',
            items: [_line(taskId: taskId)],
            onChanged: (_) {},
            newItemFactory: emptyLineItem,
            config: const LineItemColumnConfig(),
            currencyId: '1',
            onCreateTaskFromLineItem: wired ? captured.add : null,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows the button only when wired, and fires with the item', (
      tester,
    ) async {
      await pumpMobile(tester, wired: true);
      expect(find.byIcon(Icons.more_time), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_time));
      await tester.pump();
      expect(captured.single.notes, 'Boiler service');
      await teardownSubtree(tester);
    });

    testWidgets('hidden with no host callback', (tester) async {
      await pumpMobile(tester, wired: false);
      expect(find.byIcon(Icons.more_time), findsNothing);
      // Remove stays a single tap.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      await teardownSubtree(tester);
    });

    testWidgets('hidden for a row that already is a task', (tester) async {
      await pumpMobile(tester, wired: true, taskId: 'task-1');
      expect(find.byIcon(Icons.more_time), findsNothing);
      await teardownSubtree(tester);
    });

    testWidgets('the card does not overflow at 360px with both buttons', (
      tester,
    ) async {
      await pumpMobile(tester, wired: true);
      expect(tester.takeException(), isNull);
      await teardownSubtree(tester);
    });

    testWidgets('both trailing buttons are pinned to the action size', (
      tester,
    ) async {
      // Left implicit, an IconButton's layout box floors at
      // kMinInteractiveDimension (48) — 96 for the pair, out of a ~320 px row,
      // and the Expanded identity column pays for all of it. Same trap as
      // invoiceninja/flutter#89.
      await pumpMobile(tester, wired: true);
      final side = actionButtonSize();
      for (final icon in [Icons.more_time, Icons.delete_outline]) {
        final box = tester.getSize(
          find.ancestor(
            of: find.byIcon(icon),
            matching: find.byType(IconButton),
          ),
        );
        expect(box.width, side, reason: '$icon width');
        expect(box.height, side, reason: '$icon height');
      }
      await teardownSubtree(tester);
    });

    testWidgets('the card survives a long money value at 1.4x text scale', (
      tester,
    ) async {
      // The money Text is deliberately non-flex (making it Flexible would put
      // it in a flex split with the identity Expanded and cost the identity
      // MORE width), so the row's tail risk is a long amount at large scale.
      captured = <LineItem>[];
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final fixture = await fixtureFor(tester);
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: LineItemCardListMobile(
              companyId: 'co1',
              items: [
                _line().copyWith(
                  productKey: 'Annual boiler service contract, north wing',
                  cost: Decimal.parse('1234567.89'),
                  quantity: Decimal.fromInt(2),
                ),
              ],
              onChanged: (_) {},
              newItemFactory: emptyLineItem,
              config: const LineItemColumnConfig(),
              currencyId: '1',
              onCreateTaskFromLineItem: captured.add,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      await teardownSubtree(tester);
    });
  });
}
