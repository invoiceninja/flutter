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
import 'package:admin/ui/features/billing_shared/activity/activity_record_row.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';

import '../../../_localization_helper.dart';
import '../../../_responsive_helper.dart';

/// The Activity tab's write affordances (invoiceninja/flutter#120) and its
/// comments-only mode (#121).
///
/// `onAddComment` shipped as a declared-but-never-passed parameter, so the
/// Add-comment button was dead on all eight billing-doc screens; `onLogCall`
/// joins it. Task and Project mount this same tab and must keep passing
/// `EntityNoteActions.none` — neither repository has an `addComment` to call.
///
/// `call_note_wiring_test.dart` pins the call sites that pass the callbacks;
/// `comments_surface_wiring_test.dart` pins the comments-only mounts.
class _FakeActivitiesApi implements ActivitiesApi {
  _FakeActivitiesApi([this.rows = const []]);

  final List<ActivityApi> rows;
  int fetchCount = 0;

  @override
  List<ActivityApi>? peekForEntity({
    required String entity,
    required String entityId,
  }) => null;

  @override
  Future<List<ActivityApi>> fetchForEntity({
    required String entity,
    required String entityId,
    int rows = kEntityActivityRows,
  }) async {
    fetchCount++;
    return this.rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A synthetic stream, not a real Drift watch: `pumpAndSettle` never settles
/// over a live query, it just burns its ten-minute timeout. `Stream.multi`
/// rather than `Stream.value` because more than one thing may listen over the
/// widget's life, and a single-subscription stream throws the second time.
class _FakeOutboxDao implements OutboxDao {
  const _FakeOutboxDao();

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

ActivityApi _row({required int typeId, String id = 'a1', String notes = ''}) =>
    ActivityApi(
      id: id,
      activityTypeId: typeId,
      notes: notes,
      createdAt: 1778990481,
      ip: '1.2.3.4',
    );

void main() {
  EntityActivityViewModel vmWith(_FakeActivitiesApi api) =>
      EntityActivityViewModel(
        api: api,
        outbox: const _FakeOutboxDao(),
        companyId: 'co',
        entityWireName: 'invoice',
        entityId: 'i1',
        kickDebounce: Duration.zero,
      );

  Future<void> pump(
    WidgetTester tester,
    EntityActivityViewModel vm, {
    required EntityNoteActions actions,
    bool commentsOnly = false,
    double width = 700,
    double textScale = 1.0,
  }) async {
    addTearDown(vm.dispose);
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // The host arms the VM from its `bodyBuilder`; the tab deliberately does
    // not (see `EntityActivityTab`'s note on the missing `initState` kick), so
    // the harness stands in for the host here.
    vm.kick();
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
            child: EntityActivityTab(
              vm: vm,
              actions: actions,
              commentsOnly: commentsOnly,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final both = EntityNoteActions(
    onAddComment: () async {},
    onLogCall: () async {},
  );

  testWidgets('renders both buttons when both callbacks are supplied', (
    tester,
  ) async {
    await pump(tester, vmWith(_FakeActivitiesApi()), actions: both);
    expect(find.widgetWithText(OutlinedButton, 'Log Call'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Add Comment'), findsOneWidget);
  });

  testWidgets('renders neither for EntityNoteActions.none (Task / Project)', (
    tester,
  ) async {
    await pump(
      tester,
      vmWith(_FakeActivitiesApi()),
      actions: EntityNoteActions.none,
    );
    expect(find.widgetWithText(OutlinedButton, 'Log Call'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Add Comment'), findsNothing);
  });

  testWidgets('the pair wraps instead of overflowing a narrow phone at the '
      'maximum text scale', (tester) async {
    // Two labelled buttons in a `Row` do not fit 320 px at 1.4×; the `Wrap` and
    // the explicit `minimumSize` on each button are what keep this quiet.
    await pump(
      tester,
      vmWith(_FakeActivitiesApi()),
      actions: both,
      width: 320,
      textScale: kTextScaleMax,
    );
    expectNoOverflow(tester);
    expect(find.widgetWithText(OutlinedButton, 'Log Call'), findsOneWidget);
    expect(find.byType(ActivityNoteButtons), findsOneWidget);
  });

  group('commentsOnly', () {
    testWidgets('keeps notes and drops system rows', (tester) async {
      // Count the ROWS, not the comment's own text: asserting the comment is
      // present twice over says nothing about the system row, and leaves the
      // test green with the filter deleted. This is the assertion that
      // distinguishes the two modes.
      final rows = [
        _row(typeId: 141, id: 'c1', notes: 'Will pay Friday'),
        _row(typeId: 4, id: 's1'),
      ];
      await pump(
        tester,
        vmWith(_FakeActivitiesApi(rows)),
        actions: both,
        commentsOnly: true,
      );
      expect(find.text('Will pay Friday'), findsOneWidget);
      expect(find.byType(ActivityRecordRow), findsOneWidget);
    });

    testWidgets('the Activity tab keeps both — the control for the above', (
      tester,
    ) async {
      await pump(
        tester,
        vmWith(
          _FakeActivitiesApi([
            _row(typeId: 141, id: 'c1', notes: 'Will pay Friday'),
            _row(typeId: 4, id: 's1'),
          ]),
        ),
        actions: both,
      );
      expect(find.byType(ActivityRecordRow), findsNWidgets(2));
    });

    testWidgets('the empty state explains the feature and offers the write', (
      tester,
    ) async {
      await pump(
        tester,
        vmWith(_FakeActivitiesApi()),
        actions: both,
        commentsOnly: true,
      );
      expect(find.text('No comments yet'), findsOneWidget);
      expect(find.textContaining("aren't emailed"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add Comment'), findsOneWidget);
    });

    testWidgets('drops the subtitle and the action when nothing can write', (
      tester,
    ) async {
      await pump(
        tester,
        vmWith(_FakeActivitiesApi()),
        actions: EntityNoteActions.none,
        commentsOnly: true,
      );
      expect(find.text('No comments yet'), findsOneWidget);
      // Telling a user to add a comment on a screen with no way to do it is
      // worse than saying nothing.
      expect(find.textContaining("aren't emailed"), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Add Comment'), findsNothing);
    });

    testWidgets('the Activity tab keeps its own empty copy', (tester) async {
      await pump(tester, vmWith(_FakeActivitiesApi()), actions: both);
      expect(find.text('No comments yet'), findsNothing);
      expect(find.text('No records found'), findsOneWidget);
    });
  });
}
