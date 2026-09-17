import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The dashboard's `+` (invoiceninja/flutter#164) covers the bottom 72 px of
/// the body, so the body pads its last panel clear of it.
///
/// That one line is the only part of the feature no widget test can reach.
/// `dashboard_screen_test.dart` never builds `MobileDashboardBody` — the
/// screen is only pumpable because its formatter future never completes, which
/// leaves the body a spinner — and `mobile_dashboard_body_test.dart` passes the
/// clearance itself. So a scan, the shape `dashboard_panel_wiring_test.dart`
/// uses for the same reason. Dropping the argument would leave the last panel
/// under the button, silently.
void main() {
  test('the screen pads the mobile body by the FAB clearance', () {
    final src = File(
      'lib/ui/features/dashboard/views/dashboard_screen.dart',
    ).readAsStringSync();

    expect(
      RegExp(
        r'fabClearance:[^,]*kDashboardFabClearance',
        dotAll: true,
      ).hasMatch(src),
      isTrue,
      reason:
          'the narrow body must be padded by kDashboardFabClearance wherever '
          'the screen shows DashboardCreateFab',
    );
  });
}
