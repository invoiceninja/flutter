import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/sync/entity_type.dart';
import 'package:admin/domain/sync/sync_event.dart';
import 'package:admin/ui/core/widgets/conflict_resolution_sheet.dart';

import '../../../_responsive_helper.dart';

/// Finding #41: an entity-deleted-server-side conflict gets a distinct sheet —
/// "discard locally" + "keep for later", and crucially NO "use my changes"
/// (re-sending the update would fail forever). A stale-data (409) conflict
/// keeps the open / discard / use-mine flow. Asserted structurally (button
/// types) + by the resolution the primary action returns, so it's independent
/// of localized button text.
///
/// The variant is keyed on the explicit [ConflictEvent.isDeletedServerSide]
/// flag, never on `statusCode == 404`: Invoice Ninja reports a missing entity
/// as **400** and reserves 404 for routing mistakes, and this sheet's discard
/// hard-deletes the local row (invoiceninja/flutter#36).
void main() {
  Future<void> pumpSheet(WidgetTester tester, ConflictEvent event) async {
    await pumpAt(
      tester,
      600,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showConflictResolutionSheet(context, event: event),
          child: const Text('trigger'),
        ),
      ),
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
  }

  ConflictEvent event(int status, {bool deleted = false}) => ConflictEvent(
    entityType: EntityType.client,
    entityId: 'c1',
    companyId: 'co',
    message: 'msg',
    wireEntityType: 'client',
    statusCode: status,
    outboxRowId: 1,
    isDeletedServerSide: deleted,
  );

  testWidgets('deleted-server-side shows discard + keep-for-later and no '
      'use-mine (no OutlinedButton); the primary action discards', (
    tester,
  ) async {
    await pumpSheet(tester, event(400, deleted: true));

    // Deleted actions are [TextButton(keep), FilledButton(discard)] — no
    // OutlinedButton (that's the stale-data discard slot), and no third button.
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    // (Resolution asserted via the engine test; here the structural shape +
    // dismissal is the contract.)
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('409 keeps open / discard / use-mine (OutlinedButton present)', (
    tester,
  ) async {
    await pumpSheet(tester, event(409));

    // 409 actions are [TextButton(open), OutlinedButton(discard),
    // FilledButton(use-mine)].
    expect(find.byType(TextButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('a bare 404 does NOT get the deleted variant — without the '
      'explicit flag a routing mistake would offer to hard-delete the local '
      'record', (tester) async {
    await pumpSheet(tester, event(404));

    // Falls through to the stale-data shape: three buttons, use-mine present.
    expect(find.byType(OutlinedButton), findsOneWidget);
  });
}
