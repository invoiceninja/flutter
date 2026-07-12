import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildInTheme(InTheme.light),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('renders label + Enter hint and fires onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(PrimaryDialogAction(label: 'Save', onPressed: () => taps++)),
    );
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('↵'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 1);
  });

  testWidgets('showEnterHint: false hides the Enter glyph', (tester) async {
    await tester.pumpWidget(
      _host(
        PrimaryDialogAction(
          label: 'Save',
          onPressed: () {},
          showEnterHint: false,
        ),
      ),
    );
    expect(find.text('↵'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('enabled: false does not fire onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        PrimaryDialogAction(
          label: 'Delete',
          enabled: false,
          onPressed: () => taps++,
        ),
      ),
    );
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('busy: shows a spinner and hides the label + hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(PrimaryDialogAction(label: 'Save', busy: true, onPressed: () {})),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(find.text('↵'), findsNothing);
  });

  testWidgets(
    'Enter activates the autofocused primary (the Enter hint is truthful)',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(PrimaryDialogAction(label: 'OK', onPressed: () => taps++)),
      );
      await tester.pump(); // let autofocus take hold
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    },
  );

  testWidgets(
    'a disabled primary does not fire on Enter (autofocus is a no-op when disabled)',
    (tester) async {
      // Locks the review gotcha: a button that starts disabled can't take
      // focus, so autofocus:true never lets Enter activate it — the reason
      // several dropdown/validated dialogs must set showEnterHint:false.
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PrimaryDialogAction(
            label: 'OK',
            enabled: false,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 0);
    },
  );

  testWidgets('preserves a forwarded buttonKey', (tester) async {
    await tester.pumpWidget(
      _host(
        PrimaryDialogAction(
          buttonKey: const ValueKey('confirm-btn'),
          label: 'Confirm',
          onPressed: () {},
        ),
      ),
    );
    expect(find.byKey(const ValueKey('confirm-btn')), findsOneWidget);
  });
}
