import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_list_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';

/// A brand-new company was offered a "Show archived" filter over an empty
/// list, which reveals nothing (invoiceninja/flutter#63). The toggle is now
/// gated on an archived row actually existing — which is only knowable
/// because the scaffold always subscribes to the archived-inclusive stream
/// and splits the two sections locally.
class _Row {
  const _Row(this.id, {this.archived = false, this.deleted = false});

  final String id;
  final bool archived;
  final bool deleted;
}

void main() {
  // The shared chrome renders a SettingsScopeBanner, which reads the scope
  // controller off the settings shell in production.
  Widget host(List<_Row> rows, {bool supportsArchive = true}) =>
      ChangeNotifierProvider<SettingsLevelController>(
        create: (_) => SettingsLevelController(),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: SettingsEntityListScaffold<_Row>(
            titleKey: 'schedules',
            sectionTitleKey: 'schedules',
            newRoute: '/settings/schedules/new',
            newLabelKey: 'new_schedule',
            emptyIcon: Icons.schedule_outlined,
            emptyTitleKey: 'no_schedules',
            emptyHintKey: 'no_schedules_hint',
            supportsArchive: supportsArchive,
            refreshAll: () async {},
            streamKey: 'test',
            stream: () => Stream.value(rows),
            isArchivedOf: (r) => r.archived,
            isDeletedOf: (r) => r.deleted,
            rowBuilder: (r) => ListTile(key: ValueKey(r.id), title: Text(r.id)),
          ),
        ),
      );

  Finder archiveToggle() => find.text('Show archived');
  Finder activeToggle() => find.text('Show active');

  testWidgets('hides the archive toggle when nothing exists at all', (
    tester,
  ) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();

    expect(find.text('No schedules yet'), findsOneWidget);
    expect(archiveToggle(), findsNothing);
    expect(activeToggle(), findsNothing);
  });

  testWidgets('hides the archive toggle when every row is active', (
    tester,
  ) async {
    await tester.pumpWidget(host(const [_Row('a')]));
    await tester.pumpAndSettle();

    expect(find.text('a'), findsOneWidget);
    expect(archiveToggle(), findsNothing);
  });

  testWidgets('shows the toggle once an archived row exists, and reveals it', (
    tester,
  ) async {
    await tester.pumpWidget(host(const [_Row('a'), _Row('b', archived: true)]));
    await tester.pumpAndSettle();

    // Archived rows stay hidden until asked for...
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsNothing);
    expect(archiveToggle(), findsOneWidget);

    await tester.tap(archiveToggle());
    await tester.pumpAndSettle();

    expect(find.text('b'), findsOneWidget);
    // ...and the toggle flips to the way back out.
    expect(activeToggle(), findsOneWidget);
  });

  testWidgets('offers the toggle when the only rows are archived', (
    tester,
  ) async {
    // The empty state is judged on what is *visible*, so this still reads
    // "No schedules yet" — but the user gets a way to go find them.
    await tester.pumpWidget(host(const [_Row('b', archived: true)]));
    await tester.pumpAndSettle();

    expect(find.text('No schedules yet'), findsOneWidget);
    expect(archiveToggle(), findsOneWidget);

    await tester.tap(archiveToggle());
    await tester.pumpAndSettle();

    expect(find.text('b'), findsOneWidget);
    expect(find.text('No schedules yet'), findsNothing);
  });

  testWidgets('deleted rows never count toward the toggle', (tester) async {
    await tester.pumpWidget(
      host(const [_Row('a'), _Row('gone', archived: true, deleted: true)]),
    );
    await tester.pumpAndSettle();

    expect(archiveToggle(), findsNothing);
  });

  testWidgets('supportsArchive: false never renders the toggle', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const [_Row('b', archived: true)], supportsArchive: false),
    );
    await tester.pumpAndSettle();

    expect(archiveToggle(), findsNothing);
  });
}
