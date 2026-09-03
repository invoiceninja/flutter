import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/domain/phone/pending_call_log.dart';
import 'package:admin/ui/core/widgets/call_log_prompter.dart';
import 'package:admin/ui/core/widgets/toast_host.dart';

import '../../../_localization_helper.dart';
import '../../../_support/phone_actions_test_services.dart';

/// The lifecycle gate behind the post-call "Log call?" offer
/// (invoiceninja/flutter#120).
///
/// Every assertion here is about a *false positive*: the offer is raised by an
/// app-level widget with no idea what the user was doing, so the cost of
/// getting the gate wrong is a prompt after every glance at a notification.
void main() {
  const call = PendingCallLog(
    entityType: EntityType.client,
    entityId: 'c1',
    subject: 'Acme Corp',
    companyId: 'co',
    contactLabel: 'Jane Smith',
    phone: '+1 415 555 0123',
  );

  late PhoneActionsTestServices services;
  late DateTime clock;

  Future<void> pump(WidgetTester tester) async {
    services = PhoneActionsTestServices();
    clock = DateTime.utc(2026, 9, 3, 12);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Center(
          child: CallLogPrompter(services: services, now: () => clock),
        ),
      ),
    );
    await tester.pump();
  }

  /// Drives a real background → foreground round trip. `binding` fires the
  /// same callback `WidgetsBindingObserver` sees in production.
  Future<void> roundTrip(
    WidgetTester tester, {
    required Duration away,
    AppLifecycleState leaveVia = AppLifecycleState.paused,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(leaveVia);
    await tester.pump();
    clock = clock.add(away);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  testWidgets('offers after a plausible round trip', (tester) async {
    await pump(tester);
    services.pendingCall.record(call);
    await roundTrip(tester, away: const Duration(minutes: 12));

    expect(services.toasts.toasts, hasLength(1));
    final toast = services.toasts.toasts.single;
    expect(toast.message, '$kCallNoteMarker Jane Smith');
    expect(toast.action, isNotNull);
    expect(toast.action!.label, 'Log Call');

    // Let the toast's own dismiss timer expire — an actionable toast holds a
    // six-second one, and the harness fails a test that leaves it pending.
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('an inactive blip is not a finished call', (tester) async {
    // iOS fires `inactive` for a notification-shade peek and an app-switcher
    // glance. Treating those as a round trip would prompt constantly.
    await pump(tester);
    services.pendingCall.record(call);
    await roundTrip(
      tester,
      away: const Duration(minutes: 12),
      leaveVia: AppLifecycleState.inactive,
    );
    expect(services.toasts.toasts, isEmpty);
    expect(services.pendingCall.value, isNotNull, reason: 'still parked');
  });

  testWidgets('a bounce straight back offers nothing', (tester) async {
    await pump(tester);
    services.pendingCall.record(call);
    await roundTrip(tester, away: const Duration(seconds: 3));
    expect(services.toasts.toasts, isEmpty);
    // Consumed all the same: the round trip happened, so leaving it parked
    // would surface this call at the end of the next, unrelated one.
    expect(services.pendingCall.value, isNull);
  });

  testWidgets('a night on the home screen is not a call duration', (
    tester,
  ) async {
    await pump(tester);
    services.pendingCall.record(call);
    await roundTrip(tester, away: const Duration(hours: 9));
    expect(services.toasts.toasts, isEmpty);
  });

  testWidgets('nothing parked, nothing offered', (tester) async {
    await pump(tester);
    await roundTrip(tester, away: const Duration(minutes: 12));
    expect(services.toasts.toasts, isEmpty);
  });

  testWidgets('the preference switches the offer off', (tester) async {
    await pump(tester);
    await services.phoneActions.setOfferToLogCalls(false);
    services.pendingCall.record(call);
    await roundTrip(tester, away: const Duration(minutes: 12));
    expect(services.toasts.toasts, isEmpty);
  });

  testWidgets('a resume with no preceding background does nothing', (
    tester,
  ) async {
    // Cold start, or a lifecycle event the platform replays — there was no
    // dialer trip to come back from.
    await pump(tester);
    services.pendingCall.record(call);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(services.toasts.toasts, isEmpty);
    expect(services.pendingCall.value, isNotNull);
  });

  testWidgets('the prompter itself paints nothing', (tester) async {
    // It is mounted beside `ToastHost` over every route — anything it painted
    // would sit on top of the whole app.
    await pump(tester);
    expect(tester.getSize(find.byType(CallLogPrompter)), Size.zero);
  });

  testWidgets('the log form opens from the navigator context, not the '
      'prompter\'s own', (tester) async {
    // Reproduces the real mount: `main.dart` puts this in
    // `MaterialApp.router`'s `builder`, as a Stack *sibling* of the router
    // output — so the widget's own context sits ABOVE the Navigator and a
    // sheet pushed from there has none to land on. `contextOf` is what makes
    // the action work; without it this test throws.
    final services = PhoneActionsTestServices();
    var clock = DateTime.utc(2026, 9, 3, 12);
    final navKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          navigatorKey: navKey,
          builder: (context, child) => Stack(
            children: [
              child!,
              Positioned.fill(child: ToastHost(controller: services.toasts)),
              CallLogPrompter(
                services: services,
                contextOf: () => navKey.currentContext,
                now: () => clock,
              ),
            ],
          ),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();

    services.pendingCall.record(call);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    clock = clock.add(const Duration(minutes: 12));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // `ToastHost` renders an action label uppercased.
    await tester.tap(find.text('LOG CALL'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The form is up, titled with the record and pre-filled from the call.
    expect(find.textContaining('Acme Corp'), findsWidgets);
    expect(find.widgetWithText(TextField, 'Summary'), findsOneWidget);
  });
}
