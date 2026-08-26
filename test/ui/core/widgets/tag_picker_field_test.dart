import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/ui/core/widgets/tag_picker_field.dart';

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
  }) async {
    await pumpAt(
      tester,
      800,
      TagPickerField(
        label: 'Tags',
        available: available,
        selectedIds: selected,
        onChanged: (_) {},
        onCreate: onCreate,
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
}
