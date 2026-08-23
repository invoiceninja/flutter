import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';

/// Renders a `DashboardActivity` into a (title, meta, tone, icon) tuple the
/// activity card consumes.
///
/// The title is the localized `activity_N` string with `:user`/`:contact`/
/// `:client`/`:invoice`/... tokens replaced. Unknown activity types fall back
/// to "Activity #N" so the card never renders raw template strings.
class ActivityRender {
  const ActivityRender({
    required this.title,
    required this.meta,
    required this.tone,
    required this.icon,
  });

  final String title;
  final String meta;
  final ActivityTone tone;
  final IconData icon;
}

/// Status colors map for activity circles. Indexed by [ActivityTone].
enum ActivityTone { paid, sent, viewed, draft, expense, neutral }

class ActivityFormatter {
  ActivityFormatter(this.context);

  final BuildContext context;

  /// Token labels come from the row itself (`a.labels`), never from the
  /// caller. A caller-supplied seed used to fill `:user` on the user-activity
  /// screen, on the assumption that its feed was actor-scoped — it wasn't, so
  /// every row was stamped with the viewed user's name (invoiceninja/flutter#45).
  /// Feed the denormalized `?reactv2` shape instead; it labels each row itself.
  ActivityRender format(DashboardActivity a) {
    final l = Localization.of(context);
    var key = 'activity_${a.activityTypeId}';
    // Online payments (type 10) are contact-initiated when a contact is
    // present — pick the online/manual template, mirroring the server and the
    // detail-screen `buildActivitySpans`.
    if (a.activityTypeId == 10) {
      key = a.labels.containsKey('contact')
          ? 'activity_10_online'
          : 'activity_10_manual';
    }
    var raw = l?.lookup(key) ?? '';
    final hasTemplate = raw.isNotEmpty && raw != key;

    String resolved;
    if (hasTemplate) {
      // Type 54 with a contact is contact-initiated → swap `:user`→`:contact`.
      if (a.activityTypeId == 54 && a.labels.containsKey('contact')) {
        raw = raw.replaceAll(':user', ':contact');
      }
      resolved = raw.replaceAllMapped(RegExp(r':([a-z_]+)'), (m) {
        final token = m.group(1)!;
        if (token == 'notes') return a.notes;
        // The server's denormalized label (real client / user name, invoice
        // number, …); falls back to the localized noun when the row doesn't
        // name the object, so a bare `:token` never leaks.
        return a.labels[token] ?? context.tr(token);
      });
    } else {
      resolved = context.tr('activity_unknown', {
        'id': a.activityTypeId.toString(),
      });
    }

    final tone = activityToneFor(a.activityTypeId);
    final icon = activityIconFor(tone);
    final meta = formatRelativeTime(
      context,
      DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(a.createdAt * 1000),
      ),
    );
    return ActivityRender(title: resolved, meta: meta, tone: tone, icon: icon);
  }
}

/// Approximate mapping from `activity_type_id` → tone. Drawn from
/// Invoice Ninja's activity catalog — covers the top dozen common types.
/// Shared by the dashboard card and the detail-screen activity rows.
ActivityTone activityToneFor(int id) {
  // 1=created_client, 2=archived_client, 3=deleted_client → neutral
  // 4=created_invoice, 5=updated_invoice → draft
  // 6=emailed_invoice → sent
  // 10=viewed_invoice → viewed
  // 11=marked_paid → paid; 19=paid_invoice → paid
  // 23=updated_quote, 24=emailed_quote → sent
  // 25=viewed_quote → viewed
  // 26=approved_quote, 30=archived_quote → paid
  // 36=created_expense → expense
  switch (id) {
    case 6:
    case 24:
    case 32:
      return ActivityTone.sent;
    case 10:
    case 25:
      return ActivityTone.viewed;
    case 11:
    case 19:
    case 22:
    case 26:
    case 27:
      return ActivityTone.paid;
    case 36:
    case 37:
      return ActivityTone.expense;
    case 4:
    case 5:
    case 23:
      return ActivityTone.draft;
  }
  return ActivityTone.neutral;
}

IconData activityIconFor(ActivityTone tone) {
  switch (tone) {
    case ActivityTone.paid:
      return Icons.check_circle_outline;
    case ActivityTone.sent:
      return Icons.send_outlined;
    case ActivityTone.viewed:
      return Icons.visibility_outlined;
    case ActivityTone.draft:
      return Icons.edit_outlined;
    case ActivityTone.expense:
      return Icons.receipt_long_outlined;
    case ActivityTone.neutral:
      return Icons.circle_outlined;
  }
}

/// Resolve the tone-soft / tone-fg pair for the activity circle.
(Color bg, Color fg) activityToneColors(InTheme t, ActivityTone tone) {
  switch (tone) {
    case ActivityTone.paid:
      return (t.paidSoft, t.paid);
    case ActivityTone.sent:
      return (t.sentSoft, t.sent);
    case ActivityTone.viewed:
      return (t.partialSoft, t.partial);
    case ActivityTone.draft:
      return (t.draftSoft, t.draft);
    case ActivityTone.expense:
      return (t.overdueSoft, t.overdue);
    case ActivityTone.neutral:
      return (t.surfaceAlt, t.ink3);
  }
}
