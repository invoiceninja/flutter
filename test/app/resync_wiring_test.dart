import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for the issue #14 wiring.
///
/// These are scans rather than runtime tests because `Services.build` needs the
/// whole app graph (a real database, token storage, an HTTP client) to reach
/// either behaviour — the same reason the `sidebar wiring (issue #11)` group in
/// `sidebar_nav_item_test.dart` is written this way. Both failures below are
/// silent at runtime: nothing throws, the wrong thing just quietly happens.
void main() {
  group('logout cancels an in-flight download', () {
    final services = File('lib/app/services.dart').readAsStringSync();

    test('the onBeforeLogout hook calls resync.cancel()', () {
      final hook = services.indexOf('auth.onBeforeLogout = () async {');
      expect(hook, isNot(-1), reason: 'onBeforeLogout wrap not found');
      final body = services.substring(
        hook,
        (hook + 600).clamp(0, services.length),
      );
      expect(
        body.contains('resync.cancel()'),
        isTrue,
        reason:
            'logout wipes every Drift table — without this the rest of the '
            'download keeps writing rows into the wiped database behind the '
            'login screen.',
      );
    });

    test(
      'the resync controller is driven by syncNow, not the raw download',
      () {
        expect(
          services.contains('services.syncNow('),
          isTrue,
          reason:
              'ResyncController must run syncNow so queued offline edits are '
              'pushed before the download, per issue #14.',
        );
      },
    );
  });

  // The header's own layout (stacking, height match, overflow, tap routing) is
  // pumped directly in `sidebar_header_test.dart`. What that test *can't* see
  // is whether `InSidebar` actually threads the rail's state into it — hence
  // this scan.
  group('sidebar Sync button wiring (issue #14)', () {
    final sidebar = File(
      'lib/ui/features/shell/widgets/in_sidebar.dart',
    ).readAsStringSync();

    test('InSidebar mounts SidebarHeader with compact, touch and resync', () {
      const marker = 'SidebarHeader(';
      final start = sidebar.indexOf(marker);
      expect(start, isNot(-1), reason: 'no SidebarHeader construction?');
      final body = sidebar.substring(
        start,
        (start + 900).clamp(0, sidebar.length),
      );
      expect(
        body.contains('compact: collapsed'),
        isTrue,
        reason: 'without compact the header overflows the 64-px collapsed rail',
      );
      expect(
        body.contains('touch: touch'),
        isTrue,
        reason: 'without touch the Sync button keeps the 36-px pointer size',
      );
      expect(
        body.contains('resync: services.resync'),
        isTrue,
        reason:
            'the header must read the shared controller, not a local flag, or '
            'a pass started elsewhere leaves the rail showing an idle button.',
      );
    });
  });
}
