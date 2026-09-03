import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/models/api/activity_api_model.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/services/activities_api.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/features/billing_shared/activity/billing_doc_activity_tab.dart';

import '../../../_localization_helper.dart';
import '../../../_responsive_helper.dart';

/// The Activity tab's two write affordances (invoiceninja/flutter#120).
///
/// `onAddComment` shipped as a declared-but-never-passed parameter, so the
/// Add-comment button was dead on all eight billing-doc screens; `onLogCall`
/// joins it. Task and Project mount this same tab and must keep passing null
/// for both — neither repository has an `addComment` to call.
///
/// The pair itself is `ActivityNoteButtons`, shared with the client tab, so the
/// overflow sweep below covers both surfaces. `call_note_wiring_test.dart` pins
/// the eight call sites that pass the callbacks.
class _FakeActivitiesApi implements ActivitiesApi {
  @override
  Future<List<ActivityApi>> fetchForEntity({
    required String entity,
    required String entityId,
  }) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A synthetic stream, not a real Drift watch: `pumpAndSettle` never settles
/// over a live query, it just burns its ten-minute timeout. `Stream.multi`
/// rather than `Stream.value` because the tab's `StreamBuilder` re-subscribes
/// on every rebuild, and a single-subscription stream throws the second time.
class _FakeOutboxDao implements OutboxDao {
  @override
  Stream<List<OutboxRow>> watchPendingForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
    MutationKind? kind,
  }) => Stream<List<OutboxRow>>.multi((c) {
    c.add(const <OutboxRow>[]);
    c.close();
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool withCallbacks,
    double width = 700,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: BillingDocActivityTab(
              entityWireName: 'invoice',
              entityId: 'i1',
              companyId: 'co',
              activitiesApi: _FakeActivitiesApi(),
              outboxDao: _FakeOutboxDao(),
              onAddComment: withCallbacks ? () async {} : null,
              onLogCall: withCallbacks ? () async {} : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders both buttons when both callbacks are supplied', (
    tester,
  ) async {
    await pump(tester, withCallbacks: true);
    expect(find.widgetWithText(OutlinedButton, 'Log Call'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Add Comment'), findsOneWidget);
  });

  testWidgets('renders neither when both are null (the Task / Project case)', (
    tester,
  ) async {
    await pump(tester, withCallbacks: false);
    expect(find.widgetWithText(OutlinedButton, 'Log Call'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Add Comment'), findsNothing);
  });

  testWidgets('the pair wraps instead of overflowing a narrow phone at the '
      'maximum text scale', (tester) async {
    // Two labelled buttons in a `Row` do not fit 320 px at 1.4×; the `Wrap` and
    // the explicit `minimumSize` on each button are what keep this quiet.
    await pump(
      tester,
      withCallbacks: true,
      width: 320,
      textScale: kTextScaleMax,
    );
    expectNoOverflow(tester);
    expect(find.widgetWithText(OutlinedButton, 'Log Call'), findsOneWidget);
    // Shared with `ClientActivityTabBody`, so this sweep covers it too.
    expect(find.byType(ActivityNoteButtons), findsOneWidget);
  });
}
