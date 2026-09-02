import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/phone_actions_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/timezone.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/ui/core/utils/phone_actions.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/core/widgets/phone_number_value.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';

class _FakeLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<String> launched = <String>[];

  @override
  final LinkDelegate? linkDelegate = null;

  @override
  Future<bool> canLaunch(String url) async => false;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

class _FakeAuth implements AuthRepository {
  @override
  String? get currentCompanyId => 'co';
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Answers the cascade from a fixed map, synchronously for the seed path and
/// asynchronously for the authoritative one — the same two-step shape
/// `SettingsRepository` really has.
class _FakeSettings implements SettingsRepository {
  _FakeSettings(this.values);
  final Map<String, dynamic> values;

  @override
  Future<Map<String, dynamic>> resolved({
    required String companyId,
    String? clientId,
  }) async => values;

  @override
  Map<String, dynamic>? resolvedIfReady({
    required String companyId,
    String? clientId,
  }) => values;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeStatics implements StaticsRepository {
  _FakeStatics(this.zones);
  final Map<String, Timezone> zones;

  @override
  Timezone? timezone(String id) => zones[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices({
    required this.phoneActions,
    required this.settings,
    required this.statics,
  });

  @override
  final PhoneActionsController phoneActions;
  @override
  final SettingsRepository settings;
  @override
  final StaticsRepository statics;
  @override
  final AuthRepository auth = _FakeAuth();

  @override
  Formatter? formatterIfReady(String companyId) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late PhoneActionsController phoneActions;
  late _FakeServices services;
  late _FakeLauncher launcher;
  late UrlLauncherPlatform originalLauncher;

  /// Far from every DST boundary and every midnight, so the offsets below
  /// resolve to the same wall clock on a UTC CI box and a UTC+n laptop.
  const utcPlus2 = Timezone(
    id: '1',
    name: 'Europe/Berlin',
    location: 'Berlin',
    utcOffset: 2 * 3600,
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    phoneActions = PhoneActionsController(db: db);
    services = _FakeServices(
      phoneActions: phoneActions,
      settings: _FakeSettings(const {'timezone_id': '1'}),
      statics: _FakeStatics(const {'1': utcPlus2}),
    );
    originalLauncher = UrlLauncherPlatform.instance;
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() async {
    UrlLauncherPlatform.instance = originalLauncher;
    debugDefaultTargetPlatformOverride = null;
    await db.close();
  });

  Future<void> pump(WidgetTester tester, {String phone = '+1 415 555 2671'}) {
    return tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: PhoneNumberValue(phone: phone, subject: 'Jane Smith'),
          ),
        ),
      ),
    );
  }

  group('rendering', () {
    testWidgets('a dialable number renders as a link when tap-to-call is on', (
      tester,
    ) async {
      await phoneActions.setTapToCall(true);
      await pump(tester);
      await tester.pump();

      expect(find.byType(LinkText), findsOneWidget);
      // `LinkText` emits no semantics of its own, so the wrapper is the only
      // thing telling a screen reader the number does anything.
      expect(
        tester
            .getSemantics(find.byType(LinkText))
            .label
            .contains('+1 415 555 2671'),
        isTrue,
      );
    });

    testWidgets('tap-to-call off leaves plain text, as before the feature', (
      tester,
    ) async {
      await phoneActions.setTapToCall(false);
      await pump(tester);
      await tester.pump();

      expect(find.byType(LinkText), findsNothing);
      expect(find.text('+1 415 555 2671'), findsOneWidget);
    });

    testWidgets('a number with nothing to dial never becomes a link', (
      tester,
    ) async {
      await phoneActions.setTapToCall(true);
      await pump(tester, phone: 'call the office');
      await tester.pump();

      // An inert link that can only report "Couldn't open the link" is worse
      // than plain text.
      expect(find.byType(LinkText), findsNothing);
      expect(find.text('call the office'), findsOneWidget);
    });

    testWidgets('flipping the preference restyles an already-mounted row', (
      tester,
    ) async {
      // The regression this guards: a detail screen stays mounted behind the
      // settings route, so a build-time read with no listener would leave it
      // showing the old styling until something unrelated rebuilt it.
      await phoneActions.setTapToCall(false);
      await pump(tester);
      await tester.pump();
      expect(find.byType(LinkText), findsNothing);

      await phoneActions.setTapToCall(true);
      await tester.pump();
      expect(find.byType(LinkText), findsOneWidget);
    });
  });

  group('placing the call', () {
    testWidgets('a tap launches the normalised tel: URI', (tester) async {
      await phoneActions.setTapToCall(true);
      await phoneActions.setWarnOutsideBusinessHours(false);
      await pump(tester);
      await tester.pump();

      await tester.tap(find.byType(LinkText));
      await tester.pumpAndSettle();

      expect(launcher.launched, ['tel:+14155552671']);
    });

    testWidgets('the confirm switch gates the launch, and Cancel aborts it', (
      tester,
    ) async {
      await phoneActions.setTapToCall(true);
      await phoneActions.setWarnOutsideBusinessHours(false);
      await phoneActions.setConfirmBeforeCall(true);
      await pump(tester);
      await tester.pump();

      await tester.tap(find.byType(LinkText));
      await tester.pumpAndSettle();

      expect(find.text('Jane Smith'), findsOneWidget);
      expect(launcher.launched, isEmpty, reason: 'not until confirmed');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(launcher.launched, isEmpty);
    });

    testWidgets('outside business hours warns once, naming the local clock', (
      tester,
    ) async {
      // Squeeze the window shut around "now in Berlin" so the warning fires
      // whatever time CI runs at, without pinning a wall clock.
      final berlinNow = DateTime.now().toUtc().add(
        Duration(seconds: utcPlus2.utcOffset),
      );
      final minutes = berlinNow.hour * 60 + berlinNow.minute;
      await phoneActions.setTapToCall(true);
      await phoneActions.setConfirmBeforeCall(true);
      await phoneActions.setBusinessHours(
        startMinutes: (minutes + 1) % (24 * 60),
        endMinutes: minutes,
      );
      await pump(tester);
      await tester.pump();

      await tester.tap(find.byType(LinkText));
      await tester.pumpAndSettle();

      // ONE dialog, not a generic confirm followed by an out-of-hours one.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Call outside business hours?'), findsOneWidget);
      expect(
        find.textContaining('Europe/Berlin'),
        findsOneWidget,
        reason: 'the prompt has to say whose clock it is judging',
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(launcher.launched, isEmpty);
    });

    testWidgets('a call is refused at fire time when tap-to-call is off', (
      tester,
    ) async {
      // Belt to the `PhoneActionsScope` braces: this is what stops a surface
      // that forgot the scope — and so is still painting a stale Call button —
      // from actually dialling with the feature switched off. Invoked outside
      // any scope on purpose, which is precisely the shape being guarded.
      await phoneActions.setTapToCall(false);
      late BuildContext ctx;
      await tester.pumpWidget(
        Provider<Services>.value(
          value: services,
          child: MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: Builder(
              builder: (c) {
                ctx = c;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        ),
      );

      await callPhoneNumber(ctx, '+1 415 555 2671');
      await messagePhoneNumber(ctx, '+1 415 555 2671');
      await tester.pumpAndSettle();

      expect(launcher.launched, isEmpty);
    });

    testWidgets('inside business hours does not interrupt', (tester) async {
      await phoneActions.setTapToCall(true);
      await phoneActions.setBusinessHours(startMinutes: 0, endMinutes: 24 * 60);
      await pump(tester);
      await tester.pump();

      await tester.tap(find.byType(LinkText));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(launcher.launched, ['tel:+14155552671']);
    });
  });

  group('ContactLocalTime', () {
    testWidgets('stays hidden when the contact shares this device\'s offset', (
      tester,
    ) async {
      services = _FakeServices(
        phoneActions: phoneActions,
        settings: _FakeSettings(const {'timezone_id': 'same'}),
        statics: _FakeStatics({
          'same': Timezone(
            id: 'same',
            name: 'Device/Local',
            location: 'here',
            utcOffset: DateTime.now().timeZoneOffset.inSeconds,
          ),
        }),
      );
      await phoneActions.setTapToCall(true);
      await pump(tester);
      await tester.pumpAndSettle();

      // Nothing to add: it's the clock the user is already looking at.
      expect(find.byType(ContactLocalTime), findsOneWidget);
      expect(
        tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(ContactLocalTime),
            matching: find.byType(SizedBox),
          ),
        ),
        isNotNull,
      );
      expect(
        find.descendant(
          of: find.byType(ContactLocalTime),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('shows the clock when the contact is in another zone', (
      tester,
    ) async {
      // Guard against the device happening to sit at UTC+2 (where the widget
      // is correct to render nothing).
      if (DateTime.now().timeZoneOffset == const Duration(hours: 2)) return;

      await phoneActions.setTapToCall(true);
      await pump(tester);
      await tester.pumpAndSettle();

      final berlinNow = DateTime.now().toUtc().add(
        Duration(seconds: utcPlus2.utcOffset),
      );
      expect(
        find.descendant(
          of: find.byType(ContactLocalTime),
          matching: find.text(
            formatTimeOfDay(berlinNow.hour, berlinNow.minute, military: false),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('stays hidden when no timezone is configured', (tester) async {
      // An unresolvable zone must not fall back to the caller's own clock —
      // "it's 11 PM for this contact" would be a confident lie.
      services = _FakeServices(
        phoneActions: phoneActions,
        settings: _FakeSettings(const {}),
        statics: _FakeStatics(const {}),
      );
      await phoneActions.setTapToCall(true);
      await pump(tester);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(ContactLocalTime),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });
  });
}
