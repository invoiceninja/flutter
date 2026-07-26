import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';

/// `_pulse` is built in `initState`, so a `showDot` change on a reused State
/// used to be ignored entirely: false→true left the dot permanently missing,
/// and true→false left an `AnimationController.repeat()` scheduling frames for
/// a dot that is never painted.
void main() {
  Widget wrap({required bool showDot}) => MaterialApp(
    theme: ThemeData.light().copyWith(
      extensions: <ThemeExtension<dynamic>>[InTheme.light],
    ),
    home: Scaffold(
      body: RunningDurationLabel(
        // A stable key so the same State is reused across the flip.
        key: const ValueKey('label'),
        start: DateTime.utc(2026, 1, 1),
        showDot: showDot,
      ),
    ),
  );

  /// The pulsing dot: the only circular `Container` this widget builds.
  final dot = find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).shape == BoxShape.circle,
  );

  testWidgets('flipping showDot on a mounted label adds the dot', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(showDot: false));
    expect(dot, findsNothing);

    await tester.pumpWidget(wrap(showDot: true));
    await tester.pump();
    expect(dot, findsOneWidget);
  });

  testWidgets('flipping it back removes the dot', (tester) async {
    await tester.pumpWidget(wrap(showDot: true));
    await tester.pump();
    expect(dot, findsOneWidget);

    await tester.pumpWidget(wrap(showDot: false));
    await tester.pump();
    expect(dot, findsNothing);
  });
}
