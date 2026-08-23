import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/core/widgets/unsynced_pill.dart';

import '../../../_localization_helper.dart';

/// `UnsyncedPill` is the single app-wide cue that a row still has a local
/// edit in the outbox. Both keys live in `_app_pending.json` (Transifex has
/// no `unsynced`), so a future import that drops them would otherwise ship
/// the raw slug to users — pin the resolved strings here.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: buildInTheme(InTheme.light),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('renders the resolved label, not a raw key', (tester) async {
    await tester.pumpWidget(host(const UnsyncedPill()));
    await tester.pumpAndSettle();

    expect(find.text('Unsynced'), findsOneWidget);
    expect(find.text('unsynced'), findsNothing);
  });

  testWidgets('carries the pending-outbox tooltip', (tester) async {
    await tester.pumpWidget(host(const UnsyncedPill()));
    await tester.pumpAndSettle();

    final pill = tester.widget<StatusPill>(find.byType(StatusPill));
    expect(pill.tooltip, 'Unsynced — pending outbox');
  });

  testWidgets('uses the sent/sentSoft token pair so every call site matches', (
    tester,
  ) async {
    await tester.pumpWidget(host(const UnsyncedPill()));
    await tester.pumpAndSettle();

    final pill = tester.widget<StatusPill>(find.byType(StatusPill));
    expect(pill.fgColor, InTheme.light.sent);
    expect(pill.bgColor, InTheme.light.sentSoft);
  });
}
