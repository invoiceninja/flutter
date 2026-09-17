// The Device Settings card for "Hide empty panels"
// (invoiceninja/flutter#161).
//
// Worth pumping where its sibling `ListStatusTabsSection` is not, because the
// switch shows a *resolved* value: the stored preference is null until the
// user chooses, and null means "on for a phone, off everywhere else". A card
// that rendered the raw value would show every phone user a switch that is off
// while their dashboard hides panels.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/hide_empty_panels_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/ui/features/settings/widgets/dashboard_panels_section.dart';

import '../../../../_localization_helper.dart';

class _FakeServices implements Services {
  _FakeServices(this.hideEmptyPanels);
  @override
  final HideEmptyPanelsController hideEmptyPanels;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

void main() {
  late AppDatabase db;
  late HideEmptyPanelsController pref;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    pref = HideEmptyPanelsController(db: db);
  });
  tearDown(() async {
    pref.dispose();
    await db.close();
  });

  const phone = Size(390, 844);
  const tablet = Size(800, 1280);

  /// [window] is the `MediaQuery` size `Breakpoints.isPhone` reads —
  /// `setSurfaceSize` alone would leave it at the test view's 800x600.
  Future<void> pump(WidgetTester tester, {required Size window}) async {
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(pref),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          builder: (context, inner) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: window),
            child: inner!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: DashboardPanelsSection()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  bool switchValue(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

  testWidgets('renders under a Dashboard heading with its explanation', (
    tester,
  ) async {
    await pump(tester, window: phone);

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Hide empty panels'), findsOneWidget);
    expect(find.textContaining('On by default on phones'), findsOneWidget);
  });

  testWidgets('automatic shows as on for a phone', (tester) async {
    await pump(tester, window: phone);
    expect(pref.value, isNull);
    expect(switchValue(tester), isTrue);
  });

  testWidgets('automatic shows as off for a tablet', (tester) async {
    // Touch-primary (the test platform is android) but not a phone — the
    // issue asks for the default on phones only.
    await pump(tester, window: tablet);
    expect(switchValue(tester), isFalse);
  });

  testWidgets('automatic shows as off for a desktop, whatever its size', (
    tester,
  ) async {
    // Reset inside the body — the foundation-vars invariant check runs before
    // teardowns (see dashboard_screen_test.dart).
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pump(tester, window: phone);
      expect(switchValue(tester), isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('flipping it stores an explicit choice that wins on a phone', (
    tester,
  ) async {
    await pump(tester, window: phone);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    // Off — explicitly, which is the one answer automatic can't give a phone.
    expect(pref.value, isFalse);
    expect(switchValue(tester), isFalse);

    // Back on is what the phone would pick anyway: automatic again, so the
    // device keeps its own default rather than a frozen copy of it.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(pref.value, isNull);
    expect(switchValue(tester), isTrue);
  });

  testWidgets('a choice made elsewhere shows here without a rebuild', (
    tester,
  ) async {
    // The dashboard's Customize sheet writes the same controller.
    await pump(tester, window: tablet);
    expect(switchValue(tester), isFalse);

    pref.value = true;
    await tester.pump();
    expect(switchValue(tester), isTrue);
  });
}
