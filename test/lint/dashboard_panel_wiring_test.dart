import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every orderable dashboard panel must be registered in **both** bodies and
/// gated in **one** place — and hidden-when-empty through one place too.
///
/// The two `builders` maps — `_bottomGrid` in `dashboard_screen.dart` and
/// `_trailingPanels` in `mobile_dashboard_body.dart` — are the lines that put a
/// panel on screen, and a kind missing from one of them half-ships: rendered on
/// desktop, absent on mobile, with both screens looking correct in isolation.
/// The mobile half is covered by a widget test; the wide body is not pumpable
/// (its screen test never builds the body — `formatterFor` never completes), so
/// this is a source scan, the same shape `status_tab_wiring_test.dart` uses for
/// a wiring fact no widget test can reach. (The grid it hands the builders to,
/// `DashboardPanelGrid`, *is* pumpable — `dashboard_panel_grid_test.dart` pins
/// its rules; this only pins that the screen uses it.)
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

  test('empty panels are hidden through the shared builder everywhere', () {
    // invoiceninja/flutter#161. A section emission only notifies its own card,
    // so a surface that filtered on `emptyPanels` without
    // `HiddenEmptyPanelsBuilder` would never update — and one that skipped it
    // entirely would show a panel on one body that the other hides, or a
    // Customize row with no word on why its panel is missing.
    for (final path in [
      ...registrars.values,
      'lib/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart',
    ]) {
      expect(
        read(path).contains('HiddenEmptyPanelsBuilder('),
        isTrue,
        reason: '$path must learn which panels are empty from the builder',
      );
    }
    // The wide body hands its builders to the grid that keys them with
    // `GlobalKey`s; a hand-rolled grid would bring back the `ValueKey` that
    // never matched, and with it a refetch every time a neighbour empties.
    expect(
      read(registrars['wide body']!).contains('DashboardPanelGrid('),
      isTrue,
      reason: 'the wide body must lay panels out through DashboardPanelGrid',
    );
  });

  test('both switches resolve "automatic" through the shared helper', () {
    // `effectiveIn` / `setIn` ask `hidesEmptyPanelsByDefault` — the same
    // question the dashboard asks. A switch that passed its own notion of
    // "phone" (the Customize sheet's `mobileLayout`, say) would read ON in a
    // 600–832 px desktop window while the dashboard still showed empty panels,
    // and every widget test would still pass.
    for (final path in const [
      'lib/ui/features/settings/widgets/dashboard_panels_section.dart',
      'lib/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart',
    ]) {
      final src = read(path);
      expect(src, contains('.effectiveIn('), reason: '$path must read it');
      expect(src, contains('.setIn('), reason: '$path must write it');
      expect(
        src,
        isNot(contains('effectiveFor(')),
        reason: '$path must not resolve automatic by hand',
      );
      expect(
        RegExp(r'\b(pref|controller|hideEmptyPanels)\.set\(').hasMatch(src),
        isFalse,
        reason: '$path must not write the preference by hand',
      );
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
