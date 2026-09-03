import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/models/api/activity_api_model.dart';
import 'package:admin/data/services/activities_api.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_record_row.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';

import '../../../_localization_helper.dart';
import '../../../_responsive_helper.dart';

/// The Comments card (invoiceninja/flutter#121) — the surface that answers
/// "I added a comment and can't see where it went".
class _FakeApi implements ActivitiesApi {
  _FakeApi([this.rows = const []]);

  final List<ActivityApi> rows;

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
  }) async => this.rows;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeOutbox implements OutboxDao {
  const _FakeOutbox([this.rows = const []]);

  final List<OutboxRow> rows;

  @override
  Stream<List<OutboxRow>> watchPendingForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
    MutationKind? kind,
  }) => Stream<List<OutboxRow>>.multi((c) {
    c.add(rows);
    c.close();
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ActivityApi _row({
  required int typeId,
  String id = 'a1',
  String notes = '',
  int createdAt = 1778990481,
}) => ActivityApi(
  id: id,
  activityTypeId: typeId,
  notes: notes,
  createdAt: createdAt,
  ip: '1.2.3.4',
);

OutboxRow _pending(String notes) => OutboxRow(
  id: 1,
  companyId: 'co',
  entityType: 'client',
  entityId: 'c1',
  mutationKind: 'add_comment',
  payload: '{"entity_id":"c1","notes":"$notes"}',
  idempotencyKey: 'k1',
  state: 'pending',
  attempts: 0,
  createdAt: 0,
  nextAttemptAt: 0,
  requiresPassword: false,
);

void main() {
  EntityActivityViewModel vmWith(_FakeApi api, {_FakeOutbox? outbox}) =>
      EntityActivityViewModel(
        api: api,
        outbox: outbox ?? const _FakeOutbox(),
        companyId: 'co',
        entityWireName: 'client',
        entityId: 'c1',
        kickDebounce: Duration.zero,
      );

  Future<void> pump(
    WidgetTester tester,
    EntityActivityViewModel vm, {
    VoidCallback? onViewAll,
    EntityNoteActions actions = EntityNoteActions.none,
    double width = 700,
    double height = 900,
    double textScale = 1.0,
    // A queued row spins a `CircularProgressIndicator`, which never settles.
    bool settle = true,
  }) async {
    addTearDown(vm.dispose);
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
            child: EntityCommentsCard(
              vm: vm,
              actions: actions,
              onViewAll: onViewAll,
              hostWireName: 'client',
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Past the (zero) kick debounce — a Timer left pending is a hard
      // failure, and `pumpAndSettle` can't be used over a spinner.
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
    }
  }

  testWidgets('renders nothing at all on a record with no comments', (
    tester,
  ) async {
    // The card is absent, not empty: 95% of records have never been commented
    // on, and a bordered "Comments" box on every one of them is clutter. The
    // Comments tab's empty state is where the feature introduces itself.
    await pump(tester, vmWith(_FakeApi([_row(typeId: 4)])));
    expect(find.text('Comments'), findsNothing);
    expect(find.byType(ActivityRecordRow), findsNothing);
  });

  testWidgets('shows a comment and hides system activity', (tester) async {
    await pump(
      tester,
      vmWith(
        _FakeApi([
          _row(typeId: 141, id: 'c1', notes: 'Will pay Friday'),
          _row(typeId: 4, id: 's1'),
        ]),
      ),
    );
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Will pay Friday'), findsOneWidget);
    expect(find.byType(ActivityRecordRow), findsOneWidget);
  });

  testWidgets('shows a queued comment before it has synced', (tester) async {
    await pump(
      tester,
      vmWith(_FakeApi(), outbox: _FakeOutbox([_pending('Chasing this up')])),
      settle: false,
    );
    expect(find.text('Chasing this up'), findsOneWidget);
  });

  testWidgets('caps at two rows and defers the rest to the tab', (
    tester,
  ) async {
    final vm = vmWith(
      _FakeApi([
        for (var i = 0; i < 6; i++)
          _row(
            typeId: 141,
            id: 'c$i',
            notes: 'note $i',
            createdAt: 1778990481 - i,
          ),
      ]),
    );
    var viewedAll = 0;
    await pump(tester, vm, onViewAll: () => viewedAll++);
    expect(find.byType(ActivityRecordRow), findsNWidgets(2));
    await tester.tap(find.text('View All'));
    expect(viewedAll, 1);
  });

  testWidgets('the footer offers Add comment, never Log call', (tester) async {
    // Log call keeps the Activity tab, the ⋯ menu and the post-call prompter;
    // a third home costs a second `Wrap` run on a card built to stay short.
    await pump(
      tester,
      vmWith(_FakeApi([_row(typeId: 141, notes: 'Hi')])),
      actions: EntityNoteActions(
        onAddComment: () async {},
        onLogCall: () async {},
      ),
    );
    expect(find.widgetWithText(OutlinedButton, 'Add Comment'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Log Call'), findsNothing);
  });

  testWidgets('stays bounded with one very long comment', (tester) async {
    final long = List.filled(300, 'word').join(' ');
    final vm = vmWith(_FakeApi([_row(typeId: 141, notes: long)]));
    await pump(tester, vm, width: 390, height: 844);
    final height = tester.getSize(find.byType(EntityCommentsCard)).height;
    // Two clamped lines plus chrome — nowhere near a phone viewport.
    expect(height, lessThan(300));
  });

  testWidgets('a landscape phone gets the same short card as a portrait one', (
    tester,
  ) async {
    // 890x412 reads as "wide" on width alone, which is exactly why the inline
    // limit is flat: the shortest viewport must not get the taller card.
    final rows = [
      for (var i = 0; i < 4; i++)
        _row(
          typeId: 141,
          id: 'c$i',
          notes: 'note $i',
          createdAt: 1778990481 - i,
        ),
    ];
    await pump(tester, vmWith(_FakeApi(rows)), width: 890, height: 412);
    expect(find.byType(ActivityRecordRow), findsNWidgets(2));
  });

  testWidgets('the last row keeps its border under the footer, and loses it '
      'when there is none', (tester) async {
    // The footer is what keeps a hovered last row off the shell's rounded
    // bottom corners — so with one, the row keeps its rule. Project and Task
    // pass `EntityNoteActions.none` and get no footer, and there the rule
    // would otherwise float above empty card.
    BorderSide bottomOf(WidgetTester t) {
      // The row nests two Containers — the outer bordered one and the 28 px
      // tone badge, which has a decoration but no border.
      final container = t.widget<Container>(
        find
            .descendant(
              of: find.byType(ActivityRecordRow),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Container &&
                    w.decoration is BoxDecoration &&
                    (w.decoration! as BoxDecoration).border != null,
              ),
            )
            .first,
      );
      return ((container.decoration! as BoxDecoration).border! as Border)
          .bottom;
    }

    await pump(
      tester,
      vmWith(_FakeApi([_row(typeId: 141, notes: 'Hi')])),
      actions: EntityNoteActions(onAddComment: () async {}),
    );
    expect(bottomOf(tester), isNot(BorderSide.none));

    await pump(tester, vmWith(_FakeApi([_row(typeId: 141, notes: 'Hi')])));
    expect(bottomOf(tester), BorderSide.none);
  });

  testWidgets('survives the responsive sweep at maximum text scale', (
    tester,
  ) async {
    for (final width in kResponsiveWidths) {
      await pump(
        tester,
        vmWith(
          _FakeApi([
            _row(typeId: 141, notes: 'A reasonably long comment to wrap'),
          ]),
        ),
        actions: EntityNoteActions(onAddComment: () async {}),
        width: width,
        textScale: kTextScaleMax,
      );
      expectNoOverflow(tester);
    }
  });
}
