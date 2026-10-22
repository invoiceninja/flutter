import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/api/activity_api_model.dart'
    show kCommentActivityTypeId;
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/domain/activity/activity_tones.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/utils/bidi.dart';

// The tone map moved to a domain leaf so the `/activity` timeline can bucket
// by it without importing a widget file; re-exported for existing callers.
export 'package:admin/domain/activity/activity_tones.dart';

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

/// `activity_type_id`s whose template names both an actor and a target user
/// (`CREATE_USER` 48 … `RESTORE_USER` 52). The actor arrives as the row's
/// `user`, the target only as `notes` — see [ActivityFormatter.format].
const Set<int> kUserLifecycleActivityTypes = {48, 49, 50, 51, 52};

/// Deliberately a plain `RegExp` and not a `const {':user': …}` rename map:
/// `no_unsubstituted_placeholders_test`'s check C false-fails on a map literal
/// keyed `':name':`, and its doc names this file as the tempting refactor.
final RegExp _userToken = RegExp(':user');

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
      // The user-lifecycle templates name two different people
      // (":user created user :user") but the row carries only the actor as a
      // `user` object: `ActivityRepository::save()` returns early for a User
      // entity, and the `activities` table has no second user column. The
      // substitution below would stamp the actor into both slots — "Alice
      // created user Alice". Since fd8cd8ad6c the server writes the target's
      // name to `notes` (`app/Listeners/User/*UserActivity.php`), so the second
      // slot is filled from there; every bundled locale puts the actor first
      // and the target second. A row written before that has no `notes` and
      // falls back to an actor-only phrasing (BACKEND.md § F6).
      if (kUserLifecycleActivityTypes.contains(a.activityTypeId)) {
        final users = _userToken.allMatches(raw).toList();
        if (users.length > 1) {
          if (a.notes.trim().isNotEmpty) {
            raw = raw.replaceRange(users[1].start, users[1].end, ':notes');
          } else {
            final actorOnly = l?.lookup('${key}_actor_only') ?? '';
            if (actorOnly.isNotEmpty && actorOnly != '${key}_actor_only') {
              raw = actorOnly;
            }
          }
        }
      }
      // Each value isolated in a right-to-left sentence, as
      // `buildActivitySpans` does — see there.
      final rtl = Directionality.of(context) == TextDirection.rtl;
      String value(String s) => rtl ? firstStrongIsolate(s) : s;
      resolved = raw.replaceAllMapped(RegExp(r':([a-z_]+)'), (m) {
        final token = m.group(1)!;
        // The marker is stripped because the row already renders a phone icon
        // for it (below) — leaving it in prints the glyph twice. That is
        // exactly what `stripCallNoteMarker`'s doc says it exists for, and it
        // is a no-op on every note that has no marker.
        if (token == 'notes') return value(stripCallNoteMarker(a.notes));
        // The server's denormalized label (real client / user name, invoice
        // number, …); falls back to the localized noun when the row doesn't
        // name the object, so a bare `:token` never leaks.
        final label = a.labels[token];
        return label == null ? context.tr(token) : value(label);
      });
    } else {
      resolved = context.tr('activity_unknown', {
        'id': a.activityTypeId.toString(),
      });
    }

    final tone = activityToneFor(a.activityTypeId);
    // A logged call is an ordinary user note carrying a marker
    // (invoiceninja/flutter#120) — the wire has no note subtype — so the glyph
    // is the only thing that separates "someone rang this client" from the rest
    // of the feed here. Plain comments keep the tone icon they have always had;
    // changing those is a different decision.
    final icon = a.activityTypeId == kCommentActivityTypeId
        ? (isCallNoteText(a.notes)
              ? Icons.phone_in_talk_outlined
              : activityIconFor(tone))
        : activityIconFor(tone);
    final meta = formatRelativeTime(
      context,
      DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(a.createdAt * 1000),
      ),
    );
    return ActivityRender(title: resolved, meta: meta, tone: tone, icon: icon);
  }
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
