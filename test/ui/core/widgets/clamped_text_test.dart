import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/widgets/clamped_text.dart';

import '../../../_responsive_helper.dart';

/// `ClampedText` holds a user's free-text note to a few lines, with the rest
/// one tap away in place.
void main() {
  const long =
      'Net 60 agreed by phone. Always call before visiting — the gate code '
      'changes monthly and reception will not let anyone in without it. Ask '
      'for Jane, not the front desk. She is in on Tuesdays and Thursdays only.';

  testWidgets('text that fits has no toggle', (tester) async {
    await pumpAt(
      tester,
      400,
      const Material(child: ClampedText(text: 'Short note.', maxLines: 2)),
    );
    expect(find.text('More'), findsNothing);
    expect(find.text('Less'), findsNothing);
  });

  testWidgets('text that overflows opens and closes in place', (tester) async {
    await pumpAt(
      tester,
      400,
      const Material(child: ClampedText(text: long, maxLines: 2)),
    );
    expect(find.text('More'), findsOneWidget);
    final clamped = tester.getSize(find.text(long)).height;

    // The whole note is the target, not just the word.
    await tester.tap(find.text(long));
    await tester.pump();
    expect(find.text('Less'), findsOneWidget);
    expect(tester.getSize(find.text(long)).height, greaterThan(clamped));

    await tester.tap(find.text('Less'));
    await tester.pump();
    expect(find.text('More'), findsOneWidget);
    expect(tester.getSize(find.text(long)).height, clamped);
  });

  testWidgets('the toggle follows the width it is given', (tester) async {
    // Measured against real constraints: the same note needs no toggle once
    // the column is wide enough to hold it.
    await pumpAt(
      tester,
      4000,
      const Material(child: ClampedText(text: long, maxLines: 2)),
    );
    expect(find.text('More'), findsNothing);
  });

  testWidgets('announces whether it is open', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAt(
      tester,
      400,
      const Material(child: ClampedText(text: long, maxLines: 2)),
    );
    // One node: the note itself is the label, the cue is its hint.
    expect(
      tester.getSemantics(find.text('More')),
      isSemantics(
        isButton: true,
        hasExpandedState: true,
        isExpanded: false,
        hasTapAction: true,
        label: long,
        hint: 'More',
      ),
    );
    handle.dispose();
  });
}
