import 'package:admin/data/models/domain/activity.dart';

/// The `activity_type_id` the server writes when a *recipient* opens a billing
/// document, keyed by the entity's wire name (invoiceninja/flutter#154).
///
/// Values are the server's own constants (`app/Models/Activity.php`):
/// `VIEW_INVOICE` 7, `VIEW_QUOTE` 21, `VIEW_CREDIT` 60,
/// `VIEW_PURCHASE_ORDER` 136. Keyed on the wire name the detail screens
/// already pass to `EntityActivityTab.hostWireName`, so a caller needs no
/// entity switch — and a **missing key is the right answer**: a recurring
/// invoice has no viewed state and so no view event.
///
/// Two things about these rows that are easy to get wrong:
///
///  * The event fires **once, on first view**, behind the same
///    `! $invitation->viewed_date` gate as `markViewed()`. So it is among the
///    *oldest* rows in a newest-first feed and the first to age out of the
///    200-row window — a viewed document with no view row is legitimate, not a
///    bug. CSV import also calls `markViewed()` without firing the event.
///  * On a credit the bundled template (`activity_60`) reads
///    ":contact viewed quote :quote", and the server stamps `credit_id`, so
///    `refs['quote']` is absent and the row renders as "… viewed Quote" with no
///    number. Upstream string; nothing local can override it.
const Map<String, int> kViewActivityTypeIds = {
  'invoice': 7,
  'quote': 21,
  'credit': 60,
  'purchase_order': 136,
};

/// The most recent activity of [typeId] in [rows], or null.
///
/// Computes the maximum by `createdAt` itself rather than trusting the caller's
/// ordering. The one production source sorts newest-first already, but a leaf
/// that silently depends on a view model's private sort is a trap for the next
/// caller.
Activity? newestActivityOfType(Iterable<Activity> rows, int typeId) {
  Activity? best;
  for (final row in rows) {
    if (row.activityTypeId != typeId) continue;
    if (best == null || row.createdAt.isAfter(best.createdAt)) best = row;
  }
  return best;
}
