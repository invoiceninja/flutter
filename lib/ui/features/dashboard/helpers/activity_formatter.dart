import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/api/activity_api_model.dart'
    show kCommentActivityTypeId;
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/domain/phone/call_note.dart';
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

/// `activity_type_id`s whose template names both an actor and a target user
/// (`CREATE_USER` 48 … `RESTORE_USER` 52). Only the actor survives the wire —
/// see the fallback in [ActivityFormatter.format].
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
      // (":user created user :user") but the server persists only the actor:
      // `ActivityRepository::save()` returns early for a User entity, and the
      // `activities` table has no second user column, so `activity_string()`
      // emits a single `user` object. The substitution below would stamp the
      // actor into both slots — "Alice created user Alice". Fall back to an
      // actor-only phrasing while the template still carries the duplicate
      // token; if the server ever moves the target into `:notes` (BACKEND.md
      // § F6) the count drops to one and the translated template is used
      // again, with no change here.
      if (kUserLifecycleActivityTypes.contains(a.activityTypeId) &&
          _userToken.allMatches(raw).length > 1) {
        final actorOnly = l?.lookup('${key}_actor_only') ?? '';
        if (actorOnly.isNotEmpty && actorOnly != '${key}_actor_only') {
          raw = actorOnly;
        }
      }
      resolved = raw.replaceAllMapped(RegExp(r':([a-z_]+)'), (m) {
        final token = m.group(1)!;
        // The marker is stripped because the row already renders a phone icon
        // for it (below) — leaving it in prints the glyph twice. That is
        // exactly what `stripCallNoteMarker`'s doc says it exists for, and it
        // is a no-op on every note that has no marker.
        if (token == 'notes') return stripCallNoteMarker(a.notes);
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

/// `activity_type_id` → tone, taken from the server's own catalog
/// (`~/Code/invoiceninja/app/Models/Activity.php`) rather than guessed.
///
/// **Deliberately partial.** Only events whose *meaning* maps onto one of the
/// five tones are listed; archive / delete / restore, and the payment-failure
/// ids (39 `VOIDED_PAYMENT`, 40 `REFUNDED_PAYMENT`, 41 `FAILED_PAYMENT`), fall
/// through to [ActivityTone.neutral] on purpose. There is no failure tone, and
/// [ActivityTone.expense] paints `overdueSoft`/`overdue` — red — so widening it
/// to cover failures would shout at the user about the wrong rows.
///
/// The tone follows what the event *means*, not the verb: a payment being
/// entered is money arriving (`paid`), a payment being edited is a record
/// changing (`draft`).
///
/// The map shipped wrong and nothing noticed, because a wrong tone is a grey
/// circle rather than an error. It mapped 10 and 25 to `viewed` —
/// `CREATE_PAYMENT` and `RESTORE_INVOICE` — while the four real view events
/// (7 / 21 / 60 / 136) fell through to neutral, so "the client opened your
/// invoice" rendered identically to "someone archived a vendor". Eight arms
/// were dropped outright (22, 23, 24, 26, 27, 32, 36, 37 — all archive, delete
/// or restore) and one re-homed (10, to `paid`). `activity_formatter_test.dart`
/// now derives the `viewed` and `sent` sets from the bundled `en.json`
/// templates in both directions, so the same class of drift fails the build.
const Map<int, ActivityTone> kActivityTones = {
  // The other side looked at the document.
  7: ActivityTone.viewed, // VIEW_INVOICE
  21: ActivityTone.viewed, // VIEW_QUOTE
  56: ActivityTone.viewed, // (no server constant — vestigial "viewed ticket")
  60: ActivityTone.viewed, // VIEW_CREDIT
  136: ActivityTone.viewed, // VIEW_PURCHASE_ORDER
  // Something left the building.
  6: ActivityTone.sent, // EMAIL_INVOICE
  20: ActivityTone.sent, // EMAIL_QUOTE
  53: ActivityTone.sent, // MARK_SENT_INVOICE
  63: ActivityTone.sent, // INVOICE_REMINDER1_SENT
  64: ActivityTone.sent, // INVOICE_REMINDER2_SENT
  65: ActivityTone.sent, // INVOICE_REMINDER3_SENT
  66: ActivityTone.sent, // INVOICE_REMINDER_ENDLESS_SENT
  135: ActivityTone.sent, // EMAIL_PURCHASE_ORDER
  138: ActivityTone.sent, // payment emailed
  139: ActivityTone.sent, // expense notification sent
  140: ActivityTone.sent, // statement sent
  142: ActivityTone.sent, // quote reminder 1 sent
  145: ActivityTone.sent, // e-invoice sent
  149: ActivityTone.sent, // credit emailed
  154: ActivityTone.sent, // e-invoice sent to AEAT
  156: ActivityTone.sent, // invoice cancellation sent to AEAT
  // Money arrived, or the other side said yes.
  10: ActivityTone.paid, // CREATE_PAYMENT
  29: ActivityTone.paid, // APPROVE_QUOTE
  54: ActivityTone.paid, // PAID_INVOICE
  // A record was created or edited.
  4: ActivityTone.draft, // CREATE_INVOICE
  5: ActivityTone.draft, // UPDATE_INVOICE
  11: ActivityTone.draft, // UPDATE_PAYMENT — an edit, not a receipt
  18: ActivityTone.draft, // CREATE_QUOTE
  19: ActivityTone.draft, // UPDATE_QUOTE

  34: ActivityTone.expense, // CREATE_EXPENSE
  47: ActivityTone.expense, // UPDATE_EXPENSE
};

ActivityTone activityToneFor(int id) =>
    kActivityTones[id] ?? ActivityTone.neutral;

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
