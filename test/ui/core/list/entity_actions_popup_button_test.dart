import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/mdi_icons.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';

import '../../../_localization_helper.dart';
import '../../../_responsive_helper.dart';

/// Builds the canonical action list: a primary "Edit" item (the only place
/// `isPrimary` is ever set in the app) plus an ordinary "Archive" item.
List<EntityActionItem<String>> _items({
  required VoidCallback onEdit,
  required VoidCallback onArchive,
}) => [
  EntityActionItem(
    kind: 'edit',
    icon: MdiIcons.circleEditOutline,
    label: 'Edit',
    enabled: true,
    isPrimary: true,
    onTap: onEdit,
  ),
  EntityActionItem(
    kind: 'archive',
    icon: Icons.archive_outlined,
    label: 'Archive',
    enabled: true,
    onTap: onArchive,
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required bool splitEditAction,
  bool editEnabled = true,
  IconData icon = Icons.more_vert,
  required VoidCallback onEdit,
  required VoidCallback onArchive,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: Center(
          child: EntityActionsPopupButton<String>(
            splitEditAction: splitEditAction,
            editEnabled: editEnabled,
            icon: icon,
            items: _items(onEdit: onEdit, onArchive: onArchive),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the split-mode cluster inside the **production** slot the wide row
/// tiles give it, which is what [_pump] deliberately can't see: it centres the
/// widget under unbounded width, so no amount of inflation ever overflows.
Future<void> _pumpInSlot(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: const Key('slot'),
            width: colWMoreMenu(),
            child: EntityActionsPopupButton<String>(
              splitEditAction: true,
              items: _items(onEdit: () {}, onArchive: () {}),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('split mode: standalone edit button fires onTap and is '
      'removed from the overflow menu', (tester) async {
    var edited = 0;
    var archived = 0;
    await _pump(
      tester,
      splitEditAction: true,
      onEdit: () => edited++,
      onArchive: () => archived++,
    );

    final editButton = find.widgetWithIcon(
      IconButton,
      MdiIcons.circleEditOutline,
    );
    expect(editButton, findsOneWidget);

    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(edited, 1);
    expect(archived, 0);

    // Open the `…` menu — Edit must no longer be listed, Archive must be.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Archive'), findsOneWidget);
  });

  testWidgets('non-split mode: no standalone edit button, Edit stays in '
      'the menu (unchanged behavior)', (tester) async {
    await _pump(
      tester,
      splitEditAction: false,
      onEdit: () {},
      onArchive: () {},
    );

    expect(
      find.widgetWithIcon(IconButton, MdiIcons.circleEditOutline),
      findsNothing,
    );

    await tester.tap(find.widgetWithIcon(IconButton, Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
  });

  testWidgets('split mode forces the vertical 3-dot overflow icon even when '
      'a horizontal icon is passed', (tester) async {
    await _pump(
      tester,
      splitEditAction: true,
      icon: Icons.more_horiz,
      onEdit: () {},
      onArchive: () {},
    );

    expect(find.widgetWithIcon(IconButton, Icons.more_vert), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.more_horiz), findsNothing);
    expect(
      find.widgetWithIcon(IconButton, MdiIcons.circleEditOutline),
      findsOneWidget,
    );
  });

  testWidgets('a divider is inserted before the first lifecycle action, '
      'positioned between the entity action and Archive', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: EntityActionsPopupButton<String>(
              items: [
                EntityActionItem(
                  kind: 'email',
                  icon: Icons.email_outlined,
                  label: 'Email',
                  enabled: true,
                  onTap: () {},
                ),
                EntityActionItem(
                  kind: 'archive',
                  icon: Icons.archive_outlined,
                  label: 'Archive',
                  enabled: true,
                  isLifecycle: true,
                  onTap: () {},
                ),
                EntityActionItem(
                  kind: 'delete',
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  enabled: true,
                  isLifecycle: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.more_vert));
    await tester.pumpAndSettle();

    // Exactly one divider, between the lone non-lifecycle item and the
    // first lifecycle item.
    expect(find.byType(Divider), findsOneWidget);
    final emailY = tester.getCenter(find.text('Email')).dy;
    final dividerY = tester.getCenter(find.byType(Divider)).dy;
    final archiveY = tester.getCenter(find.text('Archive')).dy;
    expect(emailY, lessThan(dividerY));
    expect(dividerY, lessThan(archiveY));
  });

  testWidgets('no leading divider when the menu is lifecycle-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: EntityActionsPopupButton<String>(
              items: [
                EntityActionItem(
                  kind: 'restore',
                  icon: Icons.unarchive_outlined,
                  label: 'Restore',
                  enabled: true,
                  isLifecycle: true,
                  onTap: () {},
                ),
                EntityActionItem(
                  kind: 'delete',
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  enabled: true,
                  isLifecycle: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.byType(Divider), findsNothing);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('split mode + editEnabled:false: pencil renders disabled and '
      'does nothing when tapped', (tester) async {
    var edited = 0;
    await _pump(
      tester,
      splitEditAction: true,
      editEnabled: false,
      onEdit: () => edited++,
      onArchive: () {},
    );

    final editButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, MdiIcons.circleEditOutline),
    );
    expect(editButton.onPressed, isNull);

    await tester.tap(
      find.widgetWithIcon(IconButton, MdiIcons.circleEditOutline),
    );
    await tester.pumpAndSettle();
    expect(edited, 0);
  });

  // invoiceninja/flutter#89. `flutter test` reports TargetPlatform.android, so
  // the touch branch — the one that was broken — is the default path here.
  group('wide-table actions slot', () {
    testWidgets('the cluster fits the slot it is given', (tester) async {
      await _pumpInSlot(tester);
      expectNoOverflow(tester);
    });

    testWidgets('the menu button stays inside the slot, so it can be '
        'hit-tested', (tester) async {
      await _pumpInSlot(tester);
      // Geometry as well as the exception: this still fails if someone
      // silences the overflow with a ClipRect or a FittedBox instead of
      // sizing the slot for what it holds.
      final slot = tester.getRect(find.byKey(const Key('slot')));
      final menu = tester.getRect(
        find.widgetWithIcon(IconButton, Icons.more_vert),
      );
      expect(menu.right, lessThanOrEqualTo(slot.right + 0.01));
    });

    testWidgets('both buttons meet the touch floor on a touch platform', (
      tester,
    ) async {
      await _pumpInSlot(tester);
      // Blocks the tempting wrong fix for the two tests above — shrinking the
      // buttons to make them fit would leave this red.
      for (final icon in [MdiIcons.circleEditOutline, Icons.more_vert]) {
        final size = tester.getSize(find.widgetWithIcon(IconButton, icon));
        expect(size.width, InSizes.touchTarget);
        expect(size.height, InSizes.touchTarget);
      }
    });

    testWidgets('a pointer platform keeps the dense cluster and still fits', (
      tester,
    ) async {
      // Set before pumpWidget: buildInTheme bakes materialTapTargetSize at
      // ThemeData construction from whatever defaultTargetPlatform was then.
      // Reset in a finally, not addTearDown — the binding asserts every
      // foundation debug var is back to null before tear-downs run.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await _pumpInSlot(tester);
        expectNoOverflow(tester);
        expect(
          tester
              .getSize(find.widgetWithIcon(IconButton, Icons.more_vert))
              .width,
          32,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
