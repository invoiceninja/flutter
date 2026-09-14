import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/data/static/activity_types_catalog.dart';
import 'package:admin/domain/activity/activity_view_events.dart';

Activity _a(int typeId, String isoCreated, {String id = ''}) => Activity(
  id: id,
  activityTypeId: typeId,
  notes: '',
  createdAt: DateTime.parse(isoCreated),
  ip: '',
);

void main() {
  group('kViewActivityTypeIds', () {
    test('holds the server constants for the four viewable docs', () {
      expect(kViewActivityTypeIds, {
        'invoice': 7, // Activity::VIEW_INVOICE
        'quote': 21, // Activity::VIEW_QUOTE
        'credit': 60, // Activity::VIEW_CREDIT
        'purchase_order': 136, // Activity::VIEW_PURCHASE_ORDER
      });
    });

    test('has no recurring-invoice entry', () {
      // Not an omission: a recurring invoice has no viewed status, so there is
      // no view event and a missing key is the correct "inert" answer.
      expect(kViewActivityTypeIds.containsKey('recurring_invoice'), isFalse);
    });

    test('every id is a view_* in the React-derived catalog', () {
      // A second source for the same numbers. Catches an id re-pointed at
      // another record, which is exactly how the tone map went wrong.
      for (final e in kViewActivityTypeIds.entries) {
        expect(
          kActivityTypeLabelKeys[e.value],
          startsWith('view_'),
          reason: '${e.key} → ${e.value}',
        );
      }
    });
  });

  group('newestActivityOfType', () {
    test('picks the newest match whatever order the rows arrive in', () {
      // Deliberately NOT relying on the caller's sort. The one production
      // source happens to sort newest-first; a leaf that depends on a view
      // model's private ordering is a trap for the next caller.
      final rows = [
        _a(7, '2026-03-01T12:00:00Z', id: 'old'),
        _a(6, '2026-05-01T12:00:00Z', id: 'emailed'),
        _a(7, '2026-04-01T12:00:00Z', id: 'new'),
      ];
      expect(newestActivityOfType(rows, 7)?.id, 'new');
      expect(newestActivityOfType(rows.reversed, 7)?.id, 'new');
    });

    test('answers null when the type is absent, and on an empty feed', () {
      expect(newestActivityOfType([_a(6, '2026-03-01T12:00:00Z')], 7), isNull);
      expect(newestActivityOfType(const [], 7), isNull);
    });
  });
}
