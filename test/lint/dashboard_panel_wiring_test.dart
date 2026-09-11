import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every orderable dashboard panel must be registered in **both** bodies and
/// gated in **one** place.
///
/// The two `builders` maps — `_bottomGrid` in `dashboard_screen.dart` and
/// `_trailingPanels` in `mobile_dashboard_body.dart` — are the lines that put a
/// panel on screen, and a kind missing from one of them half-ships: rendered on
/// desktop, absent on mobile, with both screens looking correct in isolation.
/// The mobile half is covered by a widget test; the wide body is not pumpable
/// (its screen test never builds the body — `formatterFor` never completes), so
/// this is a source scan, the same shape `status_tab_wiring_test.dart` uses for
/// a wiring fact no widget test can reach.
void main() {
  String read(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '$path is missing');
    // Strip `//` tails so the scan can't be satisfied by a comment that merely
    // mentions the kind — including the ones explaining this rule.
    return f
        .readAsLinesSync()
        .map((l) {
          final i = l.indexOf('//');
          return i == -1 ? l : l.substring(0, i);
        })
        .join('\n');
  }

  const registrars = {
    'wide body': 'lib/ui/features/dashboard/views/dashboard_screen.dart',
    'mobile body':
        'lib/ui/features/dashboard/widgets/mobile_dashboard_body.dart',
  };

  test('every panel kind is registered in both dashboard bodies', () {
    // Read the kinds from the registry rather than hardcoding them, so a panel
    // added later is covered the day it ships.
    final repo = read('lib/data/repositories/dashboard_repository.dart');
    final block = RegExp(
      r'panelKinds\s*=\s*\[(.*?)\]',
      dotAll: true,
    ).firstMatch(repo);
    expect(block, isNotNull, reason: 'panelKinds list not found');
    final kinds = RegExp(
      r'\b([a-zA-Z]\w*)\s*,',
    ).allMatches(block!.group(1)!).map((m) => m.group(1)!).toList();
    expect(kinds, isNotEmpty);

    for (final entry in registrars.entries) {
      final src = read(entry.value);
      for (final kind in kinds) {
        if (entry.key == 'mobile body' && kind == 'pastDue') {
          // The one documented exception: mobile pins past-due to the hero zone
          // above the chart and ignores its order slot, so it is rendered
          // directly rather than through `_trailingPanels`. Assert the pin
          // instead of exempting the kind outright — dropping it would
          // otherwise be as silent as a missing builders entry.
          expect(
            src.contains('_panelVisible(DashboardKind.pastDue)'),
            isTrue,
            reason: 'past-due must stay pinned in the mobile hero zone',
          );
          continue;
        }
        expect(
          src.contains('DashboardKind.$kind:'),
          isTrue,
          reason:
              'DashboardKind.$kind has no builders entry in ${entry.key} '
              '(${entry.value}) — it would render on the other body only',
        );
      }
    }
  });

  test('the panel gate lives in exactly one place', () {
    // Three copies is what made a half-ship likely in the first place, so the
    // module reads must stay behind `enabledPanelKinds`.
    for (final path in [
      ...registrars.values,
      'lib/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart',
    ]) {
      expect(
        read(path).contains('enabledPanelKinds('),
        isTrue,
        reason: '$path must gate panels through the shared helper',
      );
    }
  });
}
