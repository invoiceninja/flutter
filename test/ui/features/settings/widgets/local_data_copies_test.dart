import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/salvage.dart';
import 'package:admin/ui/features/settings/widgets/local_data_copies.dart';

import '../../../../_localization_helper.dart';

/// Device Settings → Data lists the old copies of the database a reset kept,
/// and is the only place one can be deleted.
void main() {
  final now = DateTime(2026, 9, 24, 12);

  RetainedStore copy(
    String name, {
    required Duration age,
    bool unrecovered = false,
  }) => RetainedStore(
    path: '/support/$name',
    keptAt: now.subtract(age),
    bytes: 3 * 1024 * 1024,
    unrecovered: unrecovered,
  );

  Future<void> pump(
    WidgetTester tester, {
    required List<RetainedStore> Function() copies,
    Future<void> Function(String path)? delete,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: LocalDataCopies(
          list: () async => copies(),
          delete: delete ?? (_) async {},
          now: () => now,
        ),
      ),
    ),
  );

  testWidgets('no copies: nothing at all', (tester) async {
    await pump(tester, copies: () => const []);
    await tester.pump();
    expect(find.text('Old copies of local data'), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('each copy shows its age and size, and an unrecovered one '
      'says so', (tester) async {
    await pump(
      tester,
      copies: () => [
        copy(
          'invoiceninja.sqlite.unrecovered.2',
          age: const Duration(days: 2),
          unrecovered: true,
        ),
        copy('invoiceninja.sqlite.broken.1', age: const Duration(hours: 5)),
      ],
    );
    await tester.pump();

    expect(find.text('Old copies of local data'), findsOneWidget);
    expect(find.textContaining('3.0 MB'), findsNWidgets(2));
    expect(find.text('Not fully recovered'), findsOneWidget);
    expect(find.text('Delete'), findsNWidgets(2));
  });

  testWidgets('Delete asks first, then deletes and re-lists', (tester) async {
    var copies = [
      copy('invoiceninja.sqlite.unrecovered.2', age: const Duration(days: 2)),
    ];
    final deleted = <String>[];
    await pump(
      tester,
      copies: () => copies,
      delete: (path) async {
        deleted.add(path);
        copies = const [];
      },
    );
    await tester.pump();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty, reason: 'not before the user confirms');
    expect(find.textContaining('can\'t be recovered'), findsOneWidget);

    // The dialog's confirm carries the title, "Delete" — the last one found.
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(deleted, ['/support/invoiceninja.sqlite.unrecovered.2']);
    expect(find.text('Old copies of local data'), findsNothing);
  });

  testWidgets('Cancel deletes nothing', (tester) async {
    final deleted = <String>[];
    await pump(
      tester,
      copies: () => [
        copy('invoiceninja.sqlite.broken.1', age: const Duration(hours: 5)),
      ],
      delete: (path) async => deleted.add(path),
    );
    await tester.pump();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(find.text('Old copies of local data'), findsOneWidget);
  });
}
