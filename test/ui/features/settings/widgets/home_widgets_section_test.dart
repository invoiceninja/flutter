import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/services/home_widget_bridge.dart';
import 'package:admin/domain/home_widgets/widget_snapshot.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/settings/widgets/home_widgets_section.dart';

import '../../../../_localization_helper.dart';

/// Device Settings → Home-screen widgets: the only place the app says the
/// widgets exist. A phone shows it; Android can place one; elsewhere nothing.

class _FakeBridge extends HomeWidgetBridge {
  _FakeBridge({required this.pinned}) : super(supported: true);

  final bool pinned;
  final List<WidgetKind> asked = [];

  @override
  Future<bool> pin(WidgetKind kind) async {
    asked.add(kind);
    return pinned;
  }
}

void main() {
  late ToastController toasts;

  setUp(() => toasts = ToastController());
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    toasts.dispose();
  });

  Future<void> pump(WidgetTester tester, HomeWidgetBridge bridge) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ToastController>.value(
        value: toasts,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeWidgetsSection(bridge: bridge),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Android: three Add buttons, each asking the launcher', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final bridge = _FakeBridge(pinned: true);
    await pump(tester, bridge);
    expect(find.text('Home-screen widgets'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(3));
    await tester.tap(find.text('Add Running timer'));
    await tester.pump();
    expect(bridge.asked, [WidgetKind.timer]);
    expect(toasts.toasts, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a launcher that refuses gets the by-hand instructions', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await pump(tester, _FakeBridge(pinned: false));
    await tester.tap(find.text('Add Business snapshot'));
    await tester.pump();
    expect(toasts.toasts, isNotEmpty);
    // Let the toast's own dismiss timer run out.
    await tester.pump(const Duration(seconds: 5));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS: the instructions, no buttons (an app cannot place one)', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pump(tester, _FakeBridge(pinned: true));
    expect(find.text('Home-screen widgets'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('macOS: the instructions, no buttons', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await pump(tester, _FakeBridge(pinned: true));
    expect(find.text('Home-screen widgets'), findsOneWidget);
    expect(find.textContaining('macOS 14'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('no card where there are no widgets', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await pump(tester, _FakeBridge(pinned: true));
    expect(find.text('Home-screen widgets'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
