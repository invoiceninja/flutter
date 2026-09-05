import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/domain/phone/phone_candidates.dart';
import 'package:admin/ui/core/dialogs/log_call_sheet.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';
import '../../../_support/phone_actions_test_services.dart';

/// The capture form behind "Log call" (invoiceninja/flutter#120).
///
/// It resolves with the **composed note**, not a value object, so these assert
/// on the string that would be handed to `repo.addComment` — the same thing the
/// server stores for ever.
void main() {
  const candidate = (
    label: 'Jane Smith',
    phone: '+1 415 555 0123',
    isPrimary: true,
    isPartyOwnLine: false,
  );

  String? result;

  Future<void> open(
    WidgetTester tester, {
    double width = 400,
    double textScale = 1.0,
    List<PhoneCandidate> candidates = const <PhoneCandidate>[],
    Duration? suggestedDuration,
  }) async {
    result = null;
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      withPhoneActionsServices(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          builder: textScale == 1.0
              ? null
              : (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showLogCallSheet(
                    context,
                    companyId: 'co',
                    subject: 'Acme Corp',
                    candidates: candidates,
                    suggestedDuration: suggestedDuration,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');

  testWidgets('the primary is inert until a summary is typed', (tester) async {
    await open(tester);
    expect(find.textContaining('Acme Corp'), findsWidgets);

    final before = tester.widget<FilledButton>(saveButton());
    expect(before.onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Summary'), 'Rang');
    await tester.pump();
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
  });

  testWidgets('Save resolves with a composed, marker-bearing note', (
    tester,
  ) async {
    await open(
      tester,
      candidates: const [candidate],
      suggestedDuration: const Duration(minutes: 12),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Summary'),
      'They will pay Friday',
    );
    await tester.pump();
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    final note = result!;
    expect(isCallNoteText(note), isTrue);
    // Direction defaults to Outgoing — the overwhelmingly common case, and
    // leaving it unset would disable the primary for a second reason.
    expect(note, contains('Outgoing'));
    expect(note, contains('Jane Smith'));
    expect(note, contains('+1 415 555 0123'));
    // The whole label, not just '12' — the phone number above already contains
    // "12", so the loose form passed even with `suggestedDuration` ignored.
    expect(note, contains('12 Minutes'));
    expect(note, endsWith('\nThey will pay Friday'));
  });

  testWidgets('Cancel resolves with null', (tester) async {
    await open(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Summary'), 'x');
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('the composed time is the wall clock the user picked', (
    tester,
  ) async {
    // Typed into the field rather than read back off `DateTime.now()`: the old
    // shape re-read the clock after `pumpAndSettle` and failed on a minute
    // rollover, and comparing "now" against "now" cannot distinguish a correct
    // render from a UTC-shifted one anyway.
    await open(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Time'), '9:07 PM');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Summary'), 'x');
    await tester.pump();
    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    // The real formatter, never a hand-copy: a copy that drifts from
    // `formatTimeOfDay` keeps this green while the app renders something else.
    expect(
      result,
      contains(
        formatTimeOfDay(
          21,
          7,
          military: kTestFormatSettings.enableMilitaryTime,
        ),
      ),
    );
  });

  // `entity_sort_filter_sheet.dart` and `tax_category_dialog.dart` both
  // hand-roll a selectable list because `RadioGroup` mutates its subtree
  // mid-frame and crashes inside modal layout. The crash only reproduces on a
  // real frame, so this cheap structural guard is what stops it coming back via
  // the "two choices ⇒ radio group" design rule. Both presentations, because
  // the widget branches on width.
  for (final (name, width) in [('sheet', 400.0), ('dialog', 900.0)]) {
    testWidgets('no RadioGroup in the $name presentation', (tester) async {
      await open(tester, width: width);
      expect(find.byType(RadioGroup), findsNothing);
      expect(find.byType(SegmentedButton<CallDirection>), findsOneWidget);
    });

    testWidgets('the direction control is reachable in the $name '
        'presentation, not clipped', (tester) async {
      // Measured, not structural. `SegmentedButton` CLIPS rather than
      // overflows — no exception, no golden difference, nothing a
      // "a scroll view exists somewhere above it" assertion can distinguish
      // from a decorative wrapper.
      //
      // The observable difference is intrinsic sizing: stretched, each segment
      // is clamped to half the sheet and the label is silently cut; inside a
      // horizontal viewport the button takes its intrinsic width, so at a
      // large text scale it EXCEEDS the sheet and the user can scroll to the
      // rest. That is what this asserts, at the width and scale where German
      // and French actually stop fitting.
      await open(tester, width: width, textScale: 1.8);
      final button = tester.getSize(
        find.byType(SegmentedButton<CallDirection>),
      );
      final viewport = tester.getSize(
        find
            .ancestor(
              of: find.byType(SegmentedButton<CallDirection>),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      );
      expect(
        button.width,
        greaterThan(viewport.width),
        reason:
            'the button is still being clamped to the sheet width, so its '
            'labels are being clipped rather than scrolled to',
      );
    });
  }

  testWidgets('the sheet lifts clear of the on-screen keyboard', (
    tester,
  ) async {
    // `showModalBottomSheet` lifts nothing by itself, and the required field is
    // the last one *and* autofocused — the exact geometry the padding rule
    // exists for. Five other sheets shipped without it.
    await open(tester);
    final withoutKeyboard = tester.getBottomLeft(
      find.widgetWithText(TextField, 'Summary'),
    );

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();

    final withKeyboard = tester.getBottomLeft(
      find.widgetWithText(TextField, 'Summary'),
    );
    expect(withKeyboard.dy, lessThan(withoutKeyboard.dy));
  });

  testWidgets('lays out on a narrow phone at the maximum text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      withPhoneActionsServices(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLogCallSheet(
                  context,
                  companyId: 'co',
                  subject: 'Acme Corp',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the contact picker works when Services is provided BELOW the '
      'navigator', (tester) async {
    // The sheet is a route, so its subtree hangs off a `Navigator` that can sit
    // above the caller's `Provider<Services>` — a detail screen inside the
    // master-detail pane is exactly that shape. `showPhoneCandidatePicker`
    // reads `Services` on the way in, so without the re-provide the picker
    // button throws instead of opening.
    final services = PhoneActionsTestServices();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Provider<Services>.value(
          value: services,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLogCallSheet(
                  context,
                  companyId: 'co',
                  subject: 'Acme Corp',
                  candidates: const [candidate],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.contacts_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Jane Smith'), findsWidgets);
  });
}
