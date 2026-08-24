// Source-level guards for the #56 grouping wiring.
//
// Scans rather than runtime tests for the same reason as
// `list_pagination_wiring_test.dart`: reaching these paths for real needs the
// whole app graph (`Services`, a router, a mounted scaffold with a live
// scroll position). Every failure below is silent at runtime — the list keeps
// working, it just quietly stops grouping, or folds rows into 72 px of blank
// space instead of nothing.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final scaffold = File(
    'lib/ui/core/list/entity_list_screen_scaffold.dart',
  ).readAsStringSync();

  String methodBody(String signature, String nextSignature) {
    final start = scaffold.indexOf(signature);
    expect(start, isNot(-1), reason: '$signature not found');
    final end = scaffold.indexOf(nextSignature, start);
    expect(end, isNot(-1), reason: 'end of $signature not found');
    return scaffold.substring(start, end);
  }

  group('list grouping wiring (#56)', () {
    test('a hidden row skips the row-height floor', () {
      // `ConstrainedBox(minHeight: kEntityListRowHeight)` around a collapsed
      // row gives every folded record 72 px of blank space — the group reads
      // as "collapsed but still enormous".
      final body = methodBody(
        'final hidden = _vm.isRowHidden(index);',
        'Widget _footer()',
      );
      final shrink = body.indexOf('SizedBox.shrink()');
      final constrained = body.indexOf('ConstrainedBox');
      expect(shrink, isNot(-1), reason: 'hidden rows must render nothing');
      expect(
        shrink < constrained,
        isTrue,
        reason:
            'the hidden branch must come before the ConstrainedBox, not '
            'wrap it',
      );
    });

    test('keyboard stepping skips hidden rows', () {
      final body = methodBody(
        'Object? _stepSelection(BuildContext context',
        'Widget _bodyWithBanner(',
      );
      expect(
        body.contains('_vm.isRowHidden'),
        isTrue,
        reason:
            'arrowing into a record inside a folded group looks like the '
            'selection vanishing',
      );
    });

    test('the master-detail pane walks only visible rows', () {
      // Same class as the keyboard-stepping guard below: the pane's J/K
      // navigation reads these ids, so an unfiltered list steps into records
      // inside a collapsed group.
      final call = scaffold.indexOf('itemIds: [');
      expect(call, isNot(-1), reason: 'MasterDetailNavScope.update not found');
      expect(
        scaffold.substring(call, call + 220).contains('_vm.isRowHidden'),
        isTrue,
      );
    });

    test('the auto-scroll estimate counts only visible rows', () {
      final body = methodBody(
        'void _ensureRowVisible(int index)',
        'void didChangeDependencies()',
      );
      expect(
        body.contains('_vm.isRowHidden'),
        isTrue,
        reason:
            'multiplying the raw index by the row height overshoots by a '
            'whole folded group',
      );
    });
  });

  group('products grouping wiring (#56)', () {
    final screen = File(
      'lib/ui/features/products/views/product_list_screen.dart',
    ).readAsStringSync();

    test('the products list supplies headers and both controls', () {
      expect(screen.contains('sectionHeaderBuilder:'), isTrue);
      expect(screen.contains('groupOptions:'), isTrue);
      expect(screen.contains('ProductGroupByButton'), isTrue);
    });

    test('the group-by button is wide-only', () {
      // Narrow already offers the same choice inside the sort sheet; a third
      // AppBar glyph on a phone is exactly what this design avoided.
      final actions = screen.indexOf('extraAppBarActions:');
      expect(actions, isNot(-1));
      final body = screen.substring(actions, actions + 220);
      expect(body.contains('wide ?'), isTrue);
    });

    test('the Uncategorized label is localized at render, not stored', () {
      // The persisted collapsed set keys on the raw `''`, so folding a group
      // has to survive a language change.
      expect(screen.contains("tr('uncategorized')"), isTrue);
      expect(screen.contains('label.isEmpty'), isTrue);
    });
  });
}
