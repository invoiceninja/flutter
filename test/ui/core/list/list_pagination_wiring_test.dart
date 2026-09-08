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

    test(
      'the VM is bound to the active company in both places it is built',
      () {
        // initState + the company-switch rebuild. Custom-field columns render
        // under the company's configured labels and hide unconfigured slots, so
        // a list whose VM is never bound silently offers zero of them — nothing
        // throws, the Columns picker is just quietly short.
        expect(
          'bindCompany(_services.company.watchCompany('
              .allMatches(scaffold)
              .length,
          2,
          reason:
              'both `initState` and `_onSessionChanged` must bind the company, '
              'or that list permanently shows no custom-field columns.',
        );
      },
    );

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

    test('no repo hand-rolls ensurePageLoaded — all delegate to the '
        'shared template', () {
      // Six repos (invoice / quote / credit / recurring_invoice /
      // purchase_order / group_setting) used to carry a ~95-line hand-copied
      // body. The READ gate drifted apart from the ADVANCE gate once already,
      // which is what #32 was; the only durable fix is that there is one body.
      //
      // Deliberately checks the CALL, not the import: five of the six carried
      // a comment reading "same gate as `ensurePageLoadedTemplate`" while
      // never calling it, so a grep for the template's name suggested they
      // were covered when they were not.
      final offenders = <String>[];
      final openCoded = <String>[];
      for (final f
          in Directory('lib/data/repositories')
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('_repository.dart'))) {
        final src = f.readAsStringSync();
        final name = f.uri.pathSegments.last;
        if (name == 'base_entity_repository.dart') continue;
        if (!src.contains('Future<bool> ensurePageLoaded({')) continue;
        if (!src.contains('ensurePageLoadedTemplate(')) offenders.add(name);
        if (src.contains('ignoreCursor ||')) openCoded.add(name);
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'these declare ensurePageLoaded without routing through '
            '`BaseEntityRepository.ensurePageLoadedTemplate`, so the cursor '
            'read/advance gates can drift again:\n  ${offenders.join('\n  ')}',
      );
      expect(
        openCoded,
        isEmpty,
        reason:
            'open-coded cursor read gate (should be `readCursorIfEligible`, '
            'which the template calls):\n  ${openCoded.join('\n  ')}',
      );
    });
  });
}
