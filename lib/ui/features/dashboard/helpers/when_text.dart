import 'package:flutter/widgets.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';

/// How a dashboard row says *when*, relative to today — the phrases shared by
/// the needs-attention band and the list panels, so "due in 3 days" reads the
/// same wherever an invoice appears.
///
/// Each count has a singular and a plural key: the app's localization has no
/// plural rules, and "1 days late" is the kind of slip a user reads as a bug.

/// "12 days late". [days] below one — the server's day and the device's can
/// differ by one around midnight — is simply "Past Due", never "0 days late".
String lateText(BuildContext context, int days) {
  if (days <= 0) return context.tr('past_due');
  return context.tr(
    days == 1 ? 'days_late_count_singular' : 'days_late_count_plural',
    {'count': '$days'},
  );
}

/// "due today" / "due in 3 days".
String dueText(BuildContext context, Date due, Date today) {
  final days = due.differenceInDays(today);
  if (days <= 0) return context.tr('due_today_label');
  return context.tr(
    days == 1 ? 'due_in_days_count_singular' : 'due_in_days_count_plural',
    {'count': '$days'},
  );
}

/// "expires today" / "expires in 3 days".
String expiresText(BuildContext context, Date validUntil, Date today) {
  final days = validUntil.differenceInDays(today);
  if (days <= 0) return context.tr('expires_today_label');
  return context.tr(
    days == 1
        ? 'expires_in_days_count_singular'
        : 'expires_in_days_count_plural',
    {'count': '$days'},
  );
}
