// The roster query behind every "Assigned User" field. It had been hand-copied
// into five call sites in two incompatible shapes; this is the one home, so
// these are the rules that used to be re-argued (or lost) per copy.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/ui/core/widgets/assigned_user_picker_field.dart';

import '../../../_localization_helper.dart';

/// `Stream.multi`, not `Stream.value`: `EntityPickerField` re-subscribes to
/// `watchById` on every `selectedId` change, and a single-subscription stream
/// throws the second time — the finding `_task_filter_doubles.dart` records.
Stream<T> _oneShot<T>(T value) => Stream<T>.multi((c) {
  c.add(value);
  c.close();
});

User _user(
  String id, {
  String first = '',
  String last = '',
  int archivedAt = 0,
  bool isDeleted = false,
}) => const User().copyWith(
  id: id,
  firstName: first,
  lastName: last,
  archivedAt: archivedAt,
  isDeleted: isDeleted,
);

class _FakeUsers implements UserRepository {
  _FakeUsers(this.roster, {this.byId = const <String, User>{}});

  final List<User> roster;

  /// Deliberately separate from [roster]: the whole point of the widget is that
  /// a selection outside the offered list still resolves.
  final Map<String, User> byId;

  @override
  Stream<List<User>> watchAllForPicker({required String companyId}) =>
      _oneShot(roster);

  @override
  Stream<User?> watch({required String companyId, required String id}) =>
      _oneShot(byId[id] ?? roster.where((u) => u.id == id).firstOrNull);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(this.user);

  @override
  final UserRepository user;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

void main() {
  late List<String> changes;

  Future<void> pump(
    WidgetTester tester, {
    required List<User> roster,
    String selectedId = '',
    Map<String, User> byId = const <String, User>{},
  }) async {
    changes = <String>[];
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(_FakeUsers(roster, byId: byId)),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: AssignedUserPickerField(
                companyId: 'co',
                selectedId: selectedId,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openOptions(WidgetTester tester) async {
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
  }

  testWidgets('archived and soft-deleted users are not offered', (
    tester,
  ) async {
    await pump(
      tester,
      roster: [
        _user('u1', first: 'Ada', last: 'Lovelace'),
        // `archivedAt` is an int epoch, 0 = not archived — never null. An
        // `== null` test analyzes as dead code and filters the roster to
        // nothing, which is why this is asserted rather than assumed.
        _user('u2', first: 'Bob', last: 'Archived', archivedAt: 1700000000),
        _user('u3', first: 'Cleo', last: 'Deleted', isDeleted: true),
      ],
    );
    await openOptions(tester);

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Bob Archived'), findsNothing);
    expect(find.text('Cleo Deleted'), findsNothing);
  });

  testWidgets('options are alphabetical, with the id breaking a name tie', (
    tester,
  ) async {
    await pump(
      tester,
      roster: [
        _user('u9', first: 'Zoe', last: 'Zeta'),
        // `watchAllForPicker` applies no ORDER BY, so without the sort this
        // list is in rowid order.
        _user('u5', first: 'Sam', last: 'Same'),
        _user('u2', first: 'Sam', last: 'Same'),
        _user('u1', first: 'Ada', last: 'Lovelace'),
      ],
    );
    await openOptions(tester);

    double y(Finder f) => tester.getTopLeft(f).dy;
    expect(
      y(find.text('Ada Lovelace')),
      lessThan(y(find.text('Sam Same').at(0))),
    );
    expect(y(find.text('Sam Same').at(1)), lessThan(y(find.text('Zoe Zeta'))));
    // The id tiebreak, proved by which row the first `Sam Same` actually is:
    // `List.sort` is not stable in Dart, so without it the two would swap
    // places between Drift emissions and reorder the list under the user's
    // finger.
    await tester.tap(find.text('Sam Same').at(0));
    await tester.pumpAndSettle();
    expect(changes, ['u2']);
  });

  testWidgets('a nameless user renders its id, never a blank row', (
    tester,
  ) async {
    await pump(tester, roster: [_user('u7', first: '   ')]);
    await openOptions(tester);

    // `(no name)` is wrong here: a repeated `(no name)` cannot tell two
    // nameless rows apart in a list you must pick from.
    expect(find.text('u7'), findsWidgets);
  });

  testWidgets('a selection outside the offered roster still renders', (
    tester,
  ) async {
    // The archived assignee: dropped from `watchAllForPicker`, so a picker that
    // scans the list would blank the field WITHOUT firing `onChanged`, and the
    // form would silently lose an assignment it still holds.
    await pump(
      tester,
      roster: [_user('u1', first: 'Ada', last: 'Lovelace')],
      selectedId: 'gone',
      byId: {
        'gone': _user('gone', first: 'Zoe', last: 'Archived', archivedAt: 1),
      },
    );

    expect(find.text('Zoe Archived'), findsOneWidget);
    expect(changes, isEmpty);
  });

  testWidgets('clearing reports an empty id', (tester) async {
    await pump(
      tester,
      roster: [_user('u1', first: 'Ada', last: 'Lovelace')],
      selectedId: 'u1',
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(changes, ['']);
  });

  testWidgets('an empty roster reads as loading, not as "no records"', (
    tester,
  ) async {
    // Deliberately no `emptyHintKey`: the roster arrives bundled on `/refresh`
    // and always holds at least the signed-in user, so empty really is a
    // loading state. Its Project and Client siblings pass `no_records_found`
    // because a company can genuinely have none.
    await pump(tester, roster: const <User>[]);

    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('No records found'), findsNothing);
  });
}
