import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/entity_modules.dart';
import 'package:admin/data/models/api/activity_api_model.dart';
import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/domain/activity/activity_refs.dart';

/// Every token an activity row can navigate to must resolve to an entity with a
/// record route (invoiceninja/flutter#143).
///
/// `goEntityRecord` returns **without navigating** for a type the registry
/// doesn't carry, or one whose `routePath` is empty — so a token added to
/// [kActivityDocumentTokens] for an entity with no detail screen ships a
/// chevron that does nothing, which is this issue again, one entity later.
/// Nothing else would notice: the row builds, the icon paints, the tap is
/// swallowed in silence.
void main() {
  test('every document token routes to a record screen', () {
    const label = ActivityLabelApi(label: 'X', hashedId: 'h1');
    final refs = Activity.fromApi(
      const ActivityApi(
        id: 'a1',
        activityTypeId: 5,
        invoice: label,
        quote: label,
        credit: label,
        payment: label,
        task: label,
        purchaseOrder: label,
        recurringInvoice: label,
        recurringExpense: label,
        expense: label,
      ),
    ).refs;

    for (final token in kActivityDocumentTokens) {
      final ref = refs[token];
      expect(
        ref,
        isNotNull,
        reason:
            '`$token` is a navigation target but `Activity.fromApi` never '
            'populates it — the row could never resolve one',
      );
      expect(
        ref!.isLink,
        isTrue,
        reason: '`$token` must carry an EntityType to be routable',
      );

      final spec = kWiredEntityModules
          .where((m) => m.type == ref.type)
          .firstOrNull;
      expect(
        spec,
        isNotNull,
        reason:
            '`$token` → ${ref.type} is not in kWiredEntityModules, so '
            'goEntityRecord would silently do nothing',
      );
      expect(spec!.routePath, isNotEmpty, reason: '$token has no route');
      expect(
        spec.detailBuilder,
        isNotNull,
        reason:
            '$token has no detail screen, so entityRecordPath would point at '
            'the editor rather than the viewer',
      );
    }
  });
}
