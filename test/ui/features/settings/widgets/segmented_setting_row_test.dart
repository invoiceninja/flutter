import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/segmented_setting_row.dart';

import '../../../../_responsive_helper.dart';

void main() {
  SegmentedButton<int> control() => SegmentedButton<int>(
    showSelectedIcon: false,
    segments: const [
      ButtonSegment(value: 0, label: Text('S')),
      ButtonSegment(value: 1, label: Text('M')),
      ButtonSegment(value: 2, label: Text('L')),
      ButtonSegment(value: 3, label: Text('XL')),
    ],
    selected: const {1},
    onSelectionChanged: (_) {},
  );

  Widget row() => SegmentedSettingRow(
    leading: const Icon(Icons.format_size_outlined),
    title: 'Font size',
    subtitle: 'Normal',
    control: control(),
  );

  testWidgets('wide: control stays in the ListTile trailing slot', (
    tester,
  ) async {
    await pumpAt(tester, 800, row());
    expectNoOverflow(tester);

    expect(find.byType(ListTile), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.byType(SegmentedButton<int>),
      ),
      findsOneWidget,
      reason: 'wide branch keeps the control as ListTile.trailing',
    );
  });

  testWidgets('narrow: control drops below the tile, no overflow', (
    tester,
  ) async {
    await pumpAt(tester, 360, row());
    expectNoOverflow(tester);

    // Narrow branch renders the control outside the ListTile (its own
    // horizontally scrollable row) so a wide button can't overflow the tile.
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.byType(SegmentedButton<int>),
      ),
      findsNothing,
    );
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
  });

  testWidgets(
    'scrollableTrailing wraps a wide control in a horizontal scroll view so a '
    'large text scale cannot overflow the trailing slot',
    (tester) async {
      // The font-size row uses natural-width labels and opts into
      // `scrollableTrailing`; at Extra Large (1.4x) an unguarded button would
      // overflow `ListTile.trailing` and trip `_RenderListTile`.
      SegmentedButton<int> wideControl() => SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 0, label: Text('Small')),
          ButtonSegment(value: 1, label: Text('Normal')),
          ButtonSegment(value: 2, label: Text('Large')),
          ButtonSegment(value: 3, label: Text('Extra Large')),
        ],
        selected: const {3},
        onSelectionChanged: (_) {},
      );

      await pumpAt(
        tester,
        600, // >= 520 → wide / trailing-slot branch
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: SegmentedSettingRow(
              leading: const Icon(Icons.format_size_outlined),
              title: 'Font size',
              subtitle: 'Extra Large',
              scrollableTrailing: true,
              control: wideControl(),
            ),
          ),
        ),
      );
      expectNoOverflow(tester);

      // Still the wide (ListTile) branch, but the control now sits inside a
      // horizontal scroll view that absorbs the overflow.
      expect(find.byType(ListTile), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.byType(SegmentedButton<int>),
        ),
        findsOneWidget,
        reason: 'control stays in the trailing slot, just scrollable',
      );
    },
  );

  testWidgets(
    'right-aligned FilledButton in a FormSection sizes to content, not full width',
    (tester) async {
      // Regression for the Device Settings "Sync" button: the themed
      // FilledButton default `Size.fromHeight(44)` (infinite min-width) would
      // otherwise fill the stretched FormSection column and defeat the
      // centerRight alignment. The per-call `minimumSize` keeps it compact.
      await pumpAt(
        tester,
        800,
        FormSection(
          title: 'Data',
          children: [
            // Placeholder prose, deliberately NOT a copy of the screen's real
            // `sync_data_help` string: this test never touches Localization,
            // and a verbatim duplicate would go stale on the next copy edit.
            const Text('Body copy that wraps across more than a single line.'),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                onPressed: () {},
                icon: const Icon(Icons.sync),
                label: const Text('Sync'),
              ),
            ),
          ],
        ),
      );
      expectNoOverflow(tester);

      final buttonWidth = tester.getSize(find.byType(FilledButton)).width;
      final sectionWidth = tester.getSize(find.byType(FormSection)).width;
      expect(
        buttonWidth,
        lessThan(sectionWidth * 0.5),
        reason: 'button must size to content, not fill the stretched column',
      );
    },
  );
}
