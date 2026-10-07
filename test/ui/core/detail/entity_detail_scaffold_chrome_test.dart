import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/entity_record_page.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';

import '../../../_localization_helper.dart';

/// What the scaffold's fixed bar and key map gained for the summary-first
/// record page: a compact title once the header has scrolled away, and `[` /
/// `]` to step the tab strip.

EntityDetailTab _tab(String id) => EntityDetailTab(
  id: id,
  label: 'Tab $id',
  icon: Icons.circle_outlined,
  bodyBuilder: (_) => SizedBox(height: 3000, child: Text('Body $id')),
);

Future<void> _pump(
  WidgetTester tester, {
  bool tabs = true,
  Size size = const Size(800, 600),
  Widget actions = const Text('actions'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final rows = StreamController<String?>();
  addTearDown(rows.close);
  final vm = GenericDetailViewModel<String>.bound(rows.stream);
  addTearDown(vm.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: EntityDetailScaffold<String>(
        id: 'x',
        vm: vm,
        emptyTitle: 'Not found',
        actionsForItem: (context, item) => actions,
        compactTitleForItem: (context, item) => const Text('Acme · \$4,250'),
        // Nothing here takes focus on its own, deliberately: that is how a
        // record arrives in the app, and the scaffold's keys have to work
        // from there. (These tests used to wrap the body in an autofocus
        // node, which is exactly the crutch the app does not have.)
        bodyBuilder: (context, item) => tabs
            ? EntityDetailTabs(
                tabs: [_tab('a'), _tab('b'), _tab('c')],
                layoutBuilder: (context, strip, body) => EntityRecordPage(
                  top: const SizedBox(height: 400, child: Text('header')),
                  tabStrip: strip,
                  tabBody: body,
                ),
              )
            : const Padding(padding: EdgeInsets.all(40), child: TextField()),
      ),
    ),
  );
  rows.add('record');
  // The focus keeper claims post-frame; give it its frames.
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

ScrollPosition _vertical(WidgetTester tester) => tester
    .stateList<ScrollableState>(find.byType(Scrollable))
    .map((s) => s.position)
    .firstWhere((p) => p.axis == Axis.vertical);

double _titleOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('Acme · \$4,250'),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

void main() {
  group('compact title', () {
    testWidgets('is hidden at the top and appears once the header is gone', (
      tester,
    ) async {
      await _pump(tester);
      expect(_titleOpacity(tester), 0);

      _vertical(tester).jumpTo(600);
      await tester.pumpAndSettle();
      expect(_titleOpacity(tester), 1);

      _vertical(tester).jumpTo(0);
      await tester.pumpAndSettle();
      expect(_titleOpacity(tester), 0);
    });

    testWidgets('its room is reserved, so the actions do not move', (
      tester,
    ) async {
      // The action cluster picks its layout from the width it is given. A
      // title that only took room while visible would reshuffle the buttons
      // each time the user scrolled past the threshold.
      await _pump(tester);
      final before = tester.getRect(find.text('actions'));
      _vertical(tester).jumpTo(600);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('actions')), before);
    });

    testWidgets('tapping it returns to the top', (tester) async {
      await _pump(tester);
      _vertical(tester).jumpTo(600);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acme · \$4,250'));
      await tester.pumpAndSettle();
      expect(_vertical(tester).pixels, 0);
    });

    testWidgets('hidden, it takes no taps', (tester) async {
      // Scrolled, but not past the reveal threshold: the title is laid out
      // and invisible. A tap that reached it would scroll back to the top.
      await _pump(tester);
      _vertical(tester).jumpTo(40);
      await tester.pumpAndSettle();
      expect(_titleOpacity(tester), 0);
      await tester.tap(find.text('Acme · \$4,250'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_vertical(tester).pixels, 40);
    });

    group('beside the compact cluster', () {
      // The real cluster, with a primary button as wide as the invoice's.
      Widget cluster(String primary) => EntityDetailActionsRow<String>(
        items: [
          EntityActionItem<String>(
            kind: 'primary',
            icon: Icons.payments_outlined,
            label: primary,
            enabled: true,
            isPrimary: true,
            onTap: () {},
          ),
          EntityActionItem<String>(
            kind: 'other',
            icon: Icons.copy,
            label: 'Clone',
            enabled: true,
            onTap: () {},
          ),
        ],
      );

      testWidgets('the cluster is laid out first, at its own width', (
        tester,
      ) async {
        // The title's width used to be reserved up front, on the assumption
        // that the primary is "Edit". With "Enter Payment" on a small phone
        // the reservation pushed the cluster off the bar.
        await _pump(
          tester,
          size: const Size(360, 700),
          actions: cluster('Enter Payment'),
        );
        expect(tester.takeException(), isNull, reason: 'no overflow');
        final bar = tester.getRect(find.byType(AppBar));
        final button = tester.getRect(find.text('Enter Payment'));
        expect(button.left, greaterThan(bar.left));
        expect(
          tester.getRect(find.byIcon(Icons.more_vert)).right,
          lessThanOrEqualTo(bar.right),
        );
      });

      testWidgets('…and the title takes what is left', (tester) async {
        await _pump(
          tester,
          size: const Size(480, 700),
          actions: cluster('Enter Payment'),
        );
        expect(tester.takeException(), isNull);
        final title = tester.getRect(find.text('Acme · \$4,250'));
        final button = tester.getRect(find.text('Enter Payment'));
        expect(title.right, lessThan(button.left), reason: 'they do not meet');
      });

      testWidgets('with too little left, the title is not offered', (
        tester,
      ) async {
        await _pump(
          tester,
          size: const Size(320, 700),
          actions: cluster('Enter Payment'),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Enter Payment'), findsOneWidget);
        expect(find.text('Acme · \$4,250'), findsNothing);
      });

      testWidgets('a cluster wider than the bar shortens its primary rather '
          'than overflowing', (tester) async {
        // A long label at large text. `⋮` holds every other action, so it is
        // the part that must stay on the bar.
        await _pump(
          tester,
          size: const Size(320, 700),
          actions: cluster('Zahlung eingeben und Rechnung versenden'),
        );
        expect(tester.takeException(), isNull, reason: 'no overflow');
        final bar = tester.getRect(find.byType(AppBar));
        expect(
          tester.getRect(find.byIcon(Icons.more_vert)).right,
          lessThanOrEqualTo(bar.right),
        );
      });

      testWidgets('it never moves the cluster as it fades in', (tester) async {
        await _pump(
          tester,
          size: const Size(480, 700),
          actions: cluster('Enter Payment'),
        );
        final before = tester.getRect(find.text('Enter Payment'));
        _vertical(tester).jumpTo(600);
        await tester.pumpAndSettle();
        expect(_titleOpacity(tester), 1);
        expect(tester.getRect(find.text('Enter Payment')), before);
      });
    });

    testWidgets('beside the spread bar its width is reserved, so the buttons '
        'do not reshuffle', (tester) async {
      await _pump(
        tester,
        size: const Size(1400, 700),
        actions: EntityDetailActionsRow<String>(
          items: [
            for (final label in ['Edit', 'Clone', 'Email', 'Archive'])
              EntityActionItem<String>(
                kind: label,
                icon: Icons.circle_outlined,
                label: label,
                enabled: true,
                isPrimary: label == 'Edit',
                onTap: () {},
              ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      // The spread form: the other actions are buttons on the bar.
      expect(find.text('Archive'), findsOneWidget);
      final before = tester.getRect(find.text('Archive'));
      _vertical(tester).jumpTo(600);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Archive')), before);
    });
  });

  group('[ and ]', () {
    Offstage activeBody(WidgetTester tester) => tester
        .widgetList<Offstage>(find.byType(Offstage))
        .firstWhere((o) => !o.offstage && o.child is TickerMode);

    testWidgets('step the tab strip and stop at its ends', (tester) async {
      await _pump(tester);
      expect(find.text('Body a'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pumpAndSettle();
      expect(find.text('Body b'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pumpAndSettle();
      expect(find.text('Body c'), findsOneWidget);

      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      }
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byWidget(activeBody(tester)),
          matching: find.text('Body a'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('work the moment the record opens', (tester) async {
      // No click, no tab key first. Flutter offers a key only to the focused
      // node and its ancestors, and a freshly opened record focuses nothing
      // of its own — so without a focus owner under the scaffold's key map
      // these did nothing until the user clicked into the body.
      await _pump(tester);
      expect(
        await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight),
        isTrue,
        reason: 'the scaffold took the key',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byWidget(activeBody(tester)),
          matching: find.text('Body b'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('work on a layout that types a bracket with a modifier', (
      tester,
    ) async {
      // German Mac: `]` is Option+6. The physical key is a digit and Option
      // is down, so only the *character* says what was typed.
      await _pump(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      final handled = await tester.sendKeyDownEvent(
        LogicalKeyboardKey.digit6,
        character: ']',
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.digit6);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(
        find.descendant(
          of: find.byWidget(activeBody(tester)),
          matching: find.text('Body b'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('are left alone on a screen with no tabs', (tester) async {
      // No strip bound means the action is *disabled*, not a no-op — which is
      // what lets the key go on to whoever else wants it.
      await _pump(tester, tabs: false);
      expect(
        await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft),
        isFalse,
      );
    });
  });

  group('the focus owner', () {
    testWidgets('does not take focus back from a field the user is in', (
      tester,
    ) async {
      await _pump(tester, tabs: false);
      await tester.tap(find.byType(TextField));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final field = tester.state<EditableTextState>(find.byType(EditableText));
      expect(field.widget.focusNode.hasFocus, isTrue);
      // …and while it is, a bare key is typing, not a shortcut.
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyE), isFalse);
    });

    testWidgets('does not take focus back from a dialog above the record', (
      tester,
    ) async {
      await _pump(tester);
      final context = tester.element(find.text('header'));
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) =>
              const AlertDialog(content: TextField(autofocus: true)),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final field = tester.state<EditableTextState>(find.byType(EditableText));
      expect(field.widget.focusNode.hasFocus, isTrue);
    });
  });
}
