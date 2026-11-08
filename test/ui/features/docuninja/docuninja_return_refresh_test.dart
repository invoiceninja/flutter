import 'dart:ui';

import 'package:admin/ui/features/docuninja/widgets/docuninja_return_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

/// DocuNinja re-reads on coming back from the browser, not on every
/// window refocus.
void main() {
  testWidgets('a real absence re-reads; a moment out of focus does not', (
    tester,
  ) async {
    var clock = DateTime(2026, 11, 9, 12);
    var refreshes = 0;
    final listener = dnRefreshOnReturn(() => refreshes++, now: () => clock);
    addTearDown(listener.dispose);

    void go(AppLifecycleState s) =>
        tester.binding.handleAppLifecycleStateChanged(s);

    // A desktop window losing focus for a second.
    go(AppLifecycleState.inactive);
    clock = clock.add(const Duration(seconds: 1));
    go(AppLifecycleState.resumed);
    expect(refreshes, 0);

    // Off to the browser and back: through hidden and paused, a minute.
    go(AppLifecycleState.inactive);
    go(AppLifecycleState.hidden);
    go(AppLifecycleState.paused);
    clock = clock.add(const Duration(minutes: 1));
    go(AppLifecycleState.hidden);
    go(AppLifecycleState.inactive);
    go(AppLifecycleState.resumed);
    expect(refreshes, 1);
  });
}
