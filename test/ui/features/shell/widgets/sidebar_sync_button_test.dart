import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/resync_controller.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_sync_button.dart';

import '../../../../_localization_helper.dart';

/// The sidebar header's one-tap Sync button (issue #14).
///
/// NOTE: an indeterminate `CircularProgressIndicator` never stops animating, so
/// `pumpAndSettle` times out on any running-state assertion. Every test that
/// puts the controller in flight uses `pump()`.

ThemeData _theme() => ThemeData.light().copyWith(
  extensions: <ThemeExtension<dynamic>>[InTheme.light],
);

void main() {
  late ValueNotifier<ResyncProgress> progress;
  late int taps;

  setUp(() {
    progress = ValueNotifier<ResyncProgress>(const ResyncProgress.idle());
    taps = 0;
  });

  tearDown(() => progress.dispose());

  Widget wrap({
    bool compact = false,
    bool touch = false,
    String companyId = 'c1',
    double? width,
  }) {
    final button = SidebarSyncButton(
      progress: progress,
      companyId: companyId,
      compact: compact,
      touch: touch,
      onSync: () => taps++,
    );
    return MaterialApp(
      theme: _theme(),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: width == null
              ? button
              // Mirrors the real collapsed rail: 64 px wide, 14 px of
              // horizontal padding either side, children stretched.
              : SizedBox(
                  width: width,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [button],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  testWidgets('idle renders the sync icon and runs on tap', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.sync), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byTooltip('Sync now'), findsOneWidget);

    await tester.tap(find.byType(SidebarSyncButton));
    expect(taps, 1);
  });

  testWidgets('a pass for this company shows a spinner and goes inert', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    progress.value = const ResyncProgress.preparing('c1');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsNothing);

    await tester.tap(find.byType(SidebarSyncButton));
    await tester.pump();
    expect(taps, 0, reason: 'a running pass must not be restartable');
  });

  testWidgets('the tooltip carries the progress count', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    progress.value = const ResyncProgress.downloading(
      companyId: 'c1',
      completed: 4,
      total: 12,
    );
    await tester.pump();

    expect(find.byTooltip('Syncing 4 of 12'), findsOneWidget);
  });

  testWidgets('before the total is known the tooltip is generic', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    progress.value = const ResyncProgress.preparing('c1');
    await tester.pump();

    expect(find.byTooltip('Syncing…'), findsOneWidget);
  });

  testWidgets('a pass for another company dims the button, not spins it', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    progress.value = const ResyncProgress.downloading(
      companyId: 'other',
      completed: 1,
      total: 9,
    );
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'the spinner belongs to the workspace actually downloading',
    );
    expect(find.byIcon(Icons.sync), findsOneWidget);
    expect(find.byTooltip('Sync already in progress'), findsOneWidget);

    await tester.tap(find.byType(SidebarSyncButton));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('touch floors the button at the touch target', (tester) async {
    await tester.pumpWidget(wrap(touch: true));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(SidebarSyncButton));
    expect(size.height, greaterThanOrEqualTo(InSizes.touchTarget));
    expect(size.width, greaterThanOrEqualTo(InSizes.touchTarget));
  });

  testWidgets('compact fits the 64-px collapsed rail even on touch', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(compact: true, touch: true, width: 64));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(SidebarSyncButton));
    expect(
      size.width,
      lessThanOrEqualTo(36),
      reason: '64 rail − 28 padding leaves 36 px; a 44 width floor overflows',
    );
    expect(size.height, greaterThanOrEqualTo(InSizes.touchTarget));
  });

  testWidgets('height is a floor, never a fixed box', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(SidebarSyncButton),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      container.constraints?.maxHeight,
      double.infinity,
      reason:
          'the header stretches this box to the company switcher, which grows '
          'with text scale — a fixed height would clip its descenders',
    );
  });
}
