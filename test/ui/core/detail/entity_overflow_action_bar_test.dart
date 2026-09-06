import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';

import '../../../_localization_helper.dart';

/// A pinned leading button (the edit screen forwards its Save button here).
Widget _leading() => FilledButton(
  key: const ValueKey('leading'),
  style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
  onPressed: () {},
  child: const Text('Save'),
);

List<EntityActionItem<String>> _items(int count) => [
  for (var i = 0; i < count; i++)
    EntityActionItem(
      kind: 'a$i',
      icon: Icons.bolt_outlined,
      label: 'Action $i',
      enabled: true,
      onTap: () {},
    ),
];

/// Hosts [child] at a fixed [width]. When [scopeWide] is set, an
/// [ActionBarLayoutScope] supplies the wide/narrow decision (as the edit-screen
/// header does); otherwise the bar falls back to its own [LayoutBuilder] over
/// the [width] (the detail-wide path).
Widget _host(Widget child, {required double width, bool? scopeWide}) {
  Widget content = SizedBox(width: width, child: child);
  if (scopeWide != null) {
    content = ActionBarLayoutScope(wide: scopeWide, child: content);
  }
  return MaterialApp(
    theme: buildInTheme(InTheme.light),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    home: Scaffold(body: Center(child: content)),
  );
}

void main() {
  group('scope-driven (edit-screen header)', () {
    testWidgets('narrow ⇒ leading + a single compact ⋮ holding every action', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          EntityOverflowActionBar<String>(
            leading: _leading(),
            items: _items(3),
          ),
          width: 800, // roomy slot; the scope (not the width) forces narrow
          scopeWide: false,
        ),
      );
      await tester.pumpAndSettle();

      // Save stays surfaced; the trigger is the label-less ⋮ IconButton —
      // never the labeled "More" button. Both carry `Icons.more_vert` (the
      // app uses one glyph everywhere), so the widget is the discriminator,
      // not the icon.
      expect(find.byKey(const ValueKey('leading')), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.more_vert), findsOneWidget);
      expect(
        find.widgetWithIcon(OutlinedButton, Icons.more_vert),
        findsNothing,
      );
      expect(find.text('More'), findsNothing);
      // No action renders inline — they all live behind the ⋮.
      expect(find.text('Action 0'), findsNothing);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Action 0'), findsOneWidget);
      expect(find.text('Action 2'), findsOneWidget);
    });

    testWidgets('wide ⇒ the spread bar collapses its tail into "More" (⋮ '
        'never appears)', (tester) async {
      await tester.pumpWidget(
        _host(
          EntityOverflowActionBar<String>(
            leading: _leading(),
            items: _items(8),
          ),
          width: 650,
          scopeWide: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithIcon(OutlinedButton, Icons.more_vert),
        findsOneWidget,
      );
      expect(find.widgetWithIcon(IconButton, Icons.more_vert), findsNothing);
    });
  });

  group('fallback (no scope ⇒ local LayoutBuilder, the detail-wide path)', () {
    testWidgets('narrow width ⇒ compact ⋮', (tester) async {
      await tester.pumpWidget(
        _host(
          EntityOverflowActionBar<String>(
            leading: _leading(),
            items: _items(3),
          ),
          width: 400,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithIcon(IconButton, Icons.more_vert), findsOneWidget);
      expect(
        find.widgetWithIcon(OutlinedButton, Icons.more_vert),
        findsNothing,
      );
    });

    testWidgets('wide width ⇒ spread "More" bar', (tester) async {
      await tester.pumpWidget(
        _host(
          EntityOverflowActionBar<String>(
            leading: _leading(),
            items: _items(8),
          ),
          width: 800,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithIcon(OutlinedButton, Icons.more_vert),
        findsOneWidget,
      );
      expect(find.widgetWithIcon(IconButton, Icons.more_vert), findsNothing);
    });
  });

  testWidgets('no leading (multi-select bulk bar) ⇒ stays the spread "More" '
      'bar even when narrow', (tester) async {
    await tester.pumpWidget(
      _host(EntityOverflowActionBar<String>(items: _items(8)), width: 400),
    );
    await tester.pumpAndSettle();

    // The compact ⋮ is gated on a pinned leading; without one the bar keeps the
    // labeled overflow at every width (the locked multi-select design).
    expect(
      find.widgetWithIcon(OutlinedButton, Icons.more_vert),
      findsOneWidget,
    );
    expect(find.widgetWithIcon(IconButton, Icons.more_vert), findsNothing);
  });
}
