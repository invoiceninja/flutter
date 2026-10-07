import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/detail/detail_scroll_scope.dart';
import 'package:admin/ui/core/detail/settings_record_body.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// `SettingsRecordBody` puts a settings-hosted record through the settings
/// shell and still gives the detail scaffold what it needs from the page: its
/// scroll controller, and a pull that works on a short record.

Future<void> _pump(
  WidgetTester tester, {
  required ScrollController scroll,
  required Widget child,
  Future<void> Function()? onRefresh,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildInTheme(InTheme.light),
    home: Scaffold(
      body: DetailScrollScope(
        controller: scroll,
        child: SettingsRecordBody(onRefresh: onRefresh, child: child),
      ),
    ),
  ),
);

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
    testWidgets(
      'the shell scrolls on the scaffold\'s controller on $platform',
      (tester) async {
        // A list inherits a primary controller by itself only on mobile. On
        // desktop the scaffold's controller had no clients, so the compact
        // title in the fixed bar could never learn the header had scrolled
        // away.
        debugDefaultTargetPlatformOverride = platform;
        final scroll = ScrollController();
        try {
          await _pump(
            tester,
            scroll: scroll,
            child: const SizedBox(height: 3000),
          );
          expect(find.byType(SettingsFormShell), findsOneWidget);
          expect(scroll.hasClients, isTrue);
          scroll.jumpTo(200);
          await tester.pump();
          expect(scroll.offset, 200);
        } finally {
          debugDefaultTargetPlatformOverride = null;
          scroll.dispose();
        }
      },
    );
  }

  testWidgets('a record shorter than its viewport can still be pulled', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var refreshed = 0;
    await _pump(
      tester,
      scroll: scroll,
      child: const SizedBox(height: 40, child: Text('short')),
      onRefresh: () async => refreshed++,
    );
    await tester.fling(find.text('short'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(refreshed, 1);
  });

  testWidgets('without a refresh there is no indicator', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await _pump(tester, scroll: scroll, child: const Text('short'));
    expect(find.byType(RefreshIndicator), findsNothing);
  });
}
