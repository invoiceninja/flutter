import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';

import '../../features/shell/_shell_test_helpers.dart';

/// End-to-end contract for the "Confirm actions" gate (invoiceninja/flutter#49).
///
/// Covers the two halves that can drift apart:
///   * the *interception* — every `EntityActionItem` surface must route
///     through `guardedOnTap`, so a tagged action prompts and an untagged one
///     never does, and the preference is honoured at tap time;
///   * the *tagging* — the shared lifecycle factories decide the gate for all
///     18 entities at once, so Archive/Delete/Purge must carry `confirm` while
///     Edit/Restore must not.
void main() {
  Future<ShellFixture> fixture(WidgetTester tester) async {
    final f = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Co', isOwner: true)],
    );
    addTearDown(f.dispose);
    return f;
  }

  /// Pumps a detail actions row holding one tagged Archive and one untagged
  /// Edit, with the preference at [confirmActions].
  Future<int Function()> pumpRow(
    WidgetTester tester, {
    required bool confirmActions,
    required String tapLabel,
  }) async {
    final f = await fixture(tester);
    f.services.confirmActions.value = confirmActions;

    var fired = 0;
    await tester.pumpWidget(
      wrapWithShell(
        f.services,
        Scaffold(
          body: SizedBox(
            width: 900,
            child: EntityDetailActionsRow<String>(
              items: [
                EntityActionItem(
                  kind: 'edit',
                  icon: Icons.edit,
                  label: 'Edit',
                  enabled: true,
                  onTap: () => fired++,
                ),
                EntityActionItem(
                  kind: 'archive',
                  icon: Icons.archive_outlined,
                  label: 'Archive',
                  enabled: true,
                  confirm: true,
                  confirmSubject: 'Acme Corp',
                  onTap: () => fired++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, tapLabel));
    await tester.pumpAndSettle();
    return () => fired;
  }

  group('interception', () {
    testWidgets('a tagged action prompts and fires only on confirm', (
      tester,
    ) async {
      final fired = await pumpRow(
        tester,
        confirmActions: true,
        tapLabel: 'Archive',
      );

      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('Acme Corp'), findsOneWidget);
      expect(fired(), 0, reason: 'must not fire before the user confirms');

      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();
      expect(fired(), 1);
    });

    testWidgets('cancelling a tagged action fires nothing', (tester) async {
      final fired = await pumpRow(
        tester,
        confirmActions: true,
        tapLabel: 'Archive',
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(fired(), 0);
      expect(find.text('Are you sure?'), findsNothing);
    });

    testWidgets(
      'with the preference off a tagged action fires straight through',
      (tester) async {
        final fired = await pumpRow(
          tester,
          confirmActions: false,
          tapLabel: 'Archive',
        );

        expect(find.text('Are you sure?'), findsNothing);
        expect(fired(), 1);
      },
    );

    testWidgets('an untagged action never prompts, preference on', (
      tester,
    ) async {
      final fired = await pumpRow(
        tester,
        confirmActions: true,
        tapLabel: 'Edit',
      );

      expect(find.text('Are you sure?'), findsNothing);
      expect(fired(), 1);
    });
  });

  group('interception — list-row popup', () {
    // The row `⋮` is the most-tapped surface on mobile and reaches `onTap`
    // through `menuChildrenFor` → `MenuItemButton`, a different code path from
    // the detail row's buttons above.
    testWidgets('a tagged menu item prompts before firing', (tester) async {
      final f = await fixture(tester);
      var fired = 0;
      await tester.pumpWidget(
        wrapWithShell(
          f.services,
          Scaffold(
            body: EntityActionsPopupButton<String>(
              items: [
                EntityActionItem(
                  kind: 'archive',
                  icon: Icons.archive_outlined,
                  label: 'Archive',
                  enabled: true,
                  confirm: true,
                  confirmSubject: 'Acme Corp',
                  onTap: () => fired++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Archive'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure?'), findsOneWidget);
      expect(find.text('Acme Corp'), findsOneWidget);
      expect(fired, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();
      expect(fired, 1);
    });
  });

  group('tagging — shared lifecycle factories', () {
    testWidgets('archive/delete/purge are gated; edit/restore are not', (
      tester,
    ) async {
      final f = await fixture(tester);
      late BuildContext ctx;
      await tester.pumpWidget(
        wrapWithShell(
          f.services,
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final archive = archiveActionItem<String>(
        context: ctx,
        kind: 'archive',
        canArchive: true,
        subject: 'Acme Corp',
        onTap: () {},
      )!;
      final restore = restoreActionItem<String>(
        context: ctx,
        kind: 'restore',
        canRestore: true,
        onTap: () {},
      )!;
      final del = deleteActionItem<String>(
        context: ctx,
        kind: 'delete',
        canDelete: true,
        subject: 'Acme Corp',
        onTap: () {},
      )!;
      final purge = purgeActionItem<String>(
        context: ctx,
        kind: 'purge',
        canPurge: true,
        onTap: () {},
      )!;
      final edit = editActionItem<String>(
        context: ctx,
        kind: 'edit',
        onTap: () {},
      );

      expect(archive.confirm, isTrue);
      expect(del.confirm, isTrue);
      expect(purge.confirm, isTrue);
      expect(edit.confirm, isFalse);
      expect(restore.confirm, isFalse, reason: 'restore is the reversal');

      // Red confirm button only where data is actually destroyed.
      expect(archive.isDestructive, isFalse);
      expect(del.isDestructive, isTrue);
      expect(purge.isDestructive, isTrue);

      expect(archive.confirmSubject, 'Acme Corp');
      expect(del.confirmSubject, 'Acme Corp');
    });

    testWidgets('purge can opt out for a caller with its own warning', (
      tester,
    ) async {
      final f = await fixture(tester);
      late BuildContext ctx;
      await tester.pumpWidget(
        wrapWithShell(
          f.services,
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Client purge opens `showPurgeClientDialog` in its dispatch, so the
      // generic gate would be a second prompt in front of it.
      final purge = purgeActionItem<String>(
        context: ctx,
        kind: 'purge',
        canPurge: true,
        confirm: false,
        onTap: () {},
      )!;
      expect(purge.confirm, isFalse);
    });
  });
}
