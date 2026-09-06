import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/ui/core/widgets/tag_picker_field.dart';
import 'package:admin/ui/core/widgets/tag_pill.dart';

import '../../../_responsive_helper.dart';

/// Regression: the inline "Create «name»" row lived purely inside
/// `optionsViewBuilder`, and Flutter's `RawAutocomplete` only mounts its
/// options overlay while the option list is NON-EMPTY. So for a name that
/// matched no existing tag — the one case inline-create exists for — the
/// dropdown never opened at all: no list, no create row, no visible way to make
/// the tag. On a company with no tags yet the field was completely inert.
Tag _tag(String id, String name) => Tag(
  id: id,
  entityType: 'task',
  name: name,
  color: '',
  updatedAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  archivedAt: null,
  isDeleted: false,
);

void main() {
  Future<void> pumpPicker(
    WidgetTester tester, {
    required List<Tag> available,
    Future<Tag?> Function(String)? onCreate,
    List<String> selected = const [],
    Tag? Function(String)? resolveById,
    ValueChanged<List<String>>? onChanged,
  }) async {
    await pumpAt(
      tester,
      800,
      TagPickerField(
        label: 'Tags',
        available: available,
        selectedIds: selected,
        onChanged: onChanged ?? (_) {},
        onCreate: onCreate,
        resolveById: resolveById,
      ),
      scroll: false,
    );
    await tester.pump();
  }

  testWidgets('offers Create for a name that matches nothing', (tester) async {
    await pumpPicker(
      tester,
      available: [_tag('t1', 'urgent')],
      onCreate: (name) async => _tag('new', name),
    );

    await tester.enterText(find.byType(TextField), 'vip-2026');
    await tester.pump();

    // `Icons.add` occurs exactly once in this widget, inside the create row —
    // so it proves the overlay actually mounted. `find.textContaining(query)`
    // would NOT: a TextField renders an EditableText holding that very query,
    // so it matches the input itself whether or not the popover exists.
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Create "vip-2026"'), findsOneWidget);
  });

  testWidgets('offers Create on a company with no tags at all', (tester) async {
    await pumpPicker(
      tester,
      available: const [],
      onCreate: (name) async => _tag('new', name),
    );

    await tester.enterText(find.byType(TextField), 'first-tag');
    await tester.pump();

    // The overlay must exist — pre-fix the option list was empty, so
    // `RawAutocomplete` never mounted it and the field was wholly inert.
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Create "first-tag"'), findsOneWidget);
  });

  testWidgets('tapping Create runs the callback with the typed name', (
    tester,
  ) async {
    final created = <String>[];
    await pumpPicker(
      tester,
      available: const [],
      onCreate: (name) async {
        created.add(name);
        return _tag('new', name);
      },
    );

    await tester.enterText(find.byType(TextField), 'billable');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(created, ['billable']);
  });

  testWidgets('no Create row when the field cannot create', (tester) async {
    // A non-admin gets `onCreate: null`.
    await pumpPicker(tester, available: const []);

    await tester.enterText(find.byType(TextField), 'nope');
    await tester.pump();

    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('an exact existing name offers the tag, not a duplicate create', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      available: [_tag('t1', 'urgent')],
      onCreate: (name) async => _tag('new', name),
    );

    await tester.enterText(find.byType(TextField), 'urgent');
    await tester.pump();

    expect(find.text('urgent'), findsWidgets);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  /// Regression (invoiceninja/flutter): a tag created inline rendered its chip
  /// as `tmp_1f3c…` instead of the name that was typed.
  ///
  /// `create` writes an optimistic row under a `tmp_` id and hands that id to
  /// the parent draft. When the create round-trips,
  /// `applyCreateResponseTemplate` inserts the real row and **deletes the tmp
  /// one** — so a lookup over the tag list alone starts missing, and the chip
  /// fell through `byId[id]?.name ?? id` to printing the raw id. Permanent for
  /// the life of the screen, and only reproducible online.
  ///
  /// Both halves of the drain are simulated here, because the widget is the
  /// surface that has to survive it: `available` loses the tmp tag and gains
  /// the real one, while `selectedIds` still holds the tmp id.
  group('surviving the create swap', () {
    final tmp = _tag('tmp_1f3c', 'vip');
    final real = _tag('real9', 'vip');

    testWidgets('the chip keeps its name after the tmp row is swapped out', (
      tester,
    ) async {
      // Before the drain: the tmp row is still in the pool.
      await pumpPicker(
        tester,
        available: [tmp],
        selected: const ['tmp_1f3c'],
        resolveById: (id) => id == 'tmp_1f3c' ? tmp : null,
      );
      expect(find.text('vip'), findsOneWidget);

      // After the drain: tmp row gone, real row present, alias recorded — and
      // the draft still names the tmp id.
      await pumpPicker(
        tester,
        available: [real],
        selected: const ['tmp_1f3c'],
        resolveById: (id) => id == 'tmp_1f3c' || id == 'real9' ? real : null,
      );

      expect(find.text('vip'), findsOneWidget);
      expect(find.textContaining('tmp_'), findsNothing);
    });

    testWidgets('the swapped tag is not re-offered in its own dropdown', (
      tester,
    ) async {
      // The second bug in the same widget: the pool was filtered by RAW id, so
      // after the swap the real row didn't match the tmp id in `selectedIds`
      // and the tag the user had just created came back as a suggestion.
      // Picking it appended a second id for the same tag.
      final added = <List<String>>[];
      await pumpPicker(
        tester,
        available: [real],
        selected: const ['tmp_1f3c'],
        resolveById: (id) => id == 'tmp_1f3c' || id == 'real9' ? real : null,
        onChanged: added.add,
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      // One 'vip' on screen: the chip. No option row offering it again.
      expect(find.text('vip'), findsOneWidget);
      expect(added, isEmpty);
    });

    testWidgets('an unresolvable id renders a dash, never the id', (
      tester,
    ) async {
      // A tag another user deleted, or the one frame between the tmp row's
      // deletion and its alias landing — both are written in a single
      // transaction whose two watches fire in no guaranteed order, so this
      // branch is reachable on the happy path.
      await pumpPicker(
        tester,
        available: const [],
        selected: const ['tmp_1f3c'],
        resolveById: (_) => null,
      );

      expect(find.text(kUnresolvedTagLabel), findsOneWidget);
      expect(find.textContaining('tmp_'), findsNothing);
    });

    testWidgets('a stranded id can still be removed', (tester) async {
      // Why the editable chip is KEPT for an unresolvable id while the
      // read-only view drops it: the ✕ is the only handle that can take that
      // id back out of the draft, and it is still going to the server.
      List<String>? emitted;
      await pumpPicker(
        tester,
        available: const [],
        selected: const ['tmp_1f3c', 'other'],
        resolveById: (_) => null,
        onChanged: (ids) => emitted = ids,
      );

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();

      // Removal compares the RAW stored id — canonicalizing that path would
      // delete the wrong chip, or none.
      expect(emitted, ['other']);
    });
  });
}
