import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/activity_reveal_controller.dart';

void main() {
  test('a repeat request for the same type still fires', () {
    // The reason this is not a `ValueNotifier<int>`: tapping the same `Viewed`
    // pill twice carries the same activity type id, so a value notifier would
    // go silent on the second tap. `TabSelectionController.select` exists for
    // the same reason.
    final c = ActivityRevealController();
    var notifications = 0;
    c.addListener(() => notifications++);

    c.reveal(7);
    final first = c.request!.seq;
    c.reveal(7);

    expect(notifications, 2);
    expect(c.request!.activityTypeId, 7);
    expect(c.request!.seq, greaterThan(first));
  });

  test('the request persists for a consumer that mounts afterwards', () {
    // The whole point. On the first tap the Activity tab is built the frame
    // AFTER `select()`, so the notification fired before anything was
    // listening; the tab reads `request` in `initState` instead.
    final c = ActivityRevealController();
    c.reveal(21);
    expect(c.request?.activityTypeId, 21);
  });

  test('no request before anyone asks', () {
    expect(ActivityRevealController().request, isNull);
  });
}
