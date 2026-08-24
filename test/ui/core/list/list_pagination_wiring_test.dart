import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for the flutter#32 wiring.
///
/// Scans rather than runtime tests because reaching these paths for real needs
/// the whole app graph (`Services`, a router, a mounted scaffold with a live
/// scroll position) — the same reason `test/app/resync_wiring_test.dart` is
/// written this way. Every failure below is **silent** at runtime: nothing
/// throws, the list just quietly goes stale again the way it did in #32.
void main() {
  group('list pagination wiring (#32)', () {
    final scaffold = File(
      'lib/ui/core/list/entity_list_screen_scaffold.dart',
    ).readAsStringSync();

    test('the scroll trigger consults canLoadMore before consuming the arm '
        'latch', () {
      final check = scaffold.indexOf('void _checkLoadMore(ScrollController c)');
      expect(check, isNot(-1), reason: '_checkLoadMore not found');
      // Slice to the next method rather than a fixed character budget — a
      // window that merely *happens* to be long enough turns any added
      // comment into a spurious failure.
      final end = scaffold.indexOf('void _onScroll()', check);
      expect(end, isNot(-1), reason: 'end of _checkLoadMore not found');
      final body = scaffold.substring(check, end);
      expect(
        body.contains('_vm.canLoadMore'),
        isTrue,
        reason:
            'disarming on a call that immediately no-ops strands a user parked '
            'at the bottom of an exhausted list: the latch only re-arms on the '
            'way back OUT of the band, so once a Sync makes more rows '
            'reachable no further trigger ever fires.',
      );
    });

    test('the VM is bound to the Sync pass in both places it is built', () {
      // initState + the company-switch rebuild. Missing either leaves that
      // list unable to re-arm after a Sync.
      expect(
        'bindResync(_services.resync)'.allMatches(scaffold).length,
        2,
        reason:
            'expected bindResync after buildVm in BOTH initState and '
            '_onSessionChanged',
      );
    });

    test('every repo reads the keyset cursor through the shared gate', () {
      // Six repos hand-roll `ensurePageLoaded`; the READ gate drifted apart
      // from the ADVANCE gate once already, which is what #32 was.
      const handRolled = [
        'invoice',
        'quote',
        'credit',
        'recurring_invoice',
        'purchase_order',
        'group_setting',
      ];
      for (final name in handRolled) {
        final src = File(
          'lib/data/repositories/${name}_repository.dart',
        ).readAsStringSync();
        expect(
          src.contains('readCursorIfEligible('),
          isTrue,
          reason:
              '${name}_repository hand-rolls ensurePageLoaded and must use the '
              'shared cursor gate, not its own expression',
        );
        expect(
          src.contains('ignoreCursor ||'),
          isFalse,
          reason: '${name}_repository still has an open-coded cursor read gate',
        );
      }
    });
  });
}
