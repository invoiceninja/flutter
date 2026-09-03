import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/timezone.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/phone/pending_call_log.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/utils/call_note_sink.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/utils/formatting.dart';

/// The record a placed call can be logged against, threaded from whichever
/// surface owns the call button (invoiceninja/flutter#120).
///
/// A record, not an object: it exists only to be copied into a
/// [PendingCallLog] and held across the dialer round trip. `subject` is the
/// title the log form shows — a party's display name, or a document's
/// `#number`.
typedef CallLogTarget = ({EntityType type, String id, String subject});

/// The `tel:` URI for a stored phone number, or null when there is nothing
/// dialable in it (a placeholder like "call the office", an empty field).
///
/// Callers use the null to decide whether to render an affordance at all — an
/// inert link that reports "Couldn't open the link" is worse than plain text.
Uri? telUri(String phone) => _contactUri('tel', phone);

/// The `sms:` URI for a stored phone number, or null — see [telUri].
Uri? smsUri(String phone) => _contactUri('sms', phone);

Uri? _contactUri(String scheme, String phone) {
  final number = cleanPhoneNumber(phone);
  if (number.isEmpty) return null;
  // Deliberately not routed through `openExternalUrl` / `isSafeWebUrl`: that
  // predicate exists to stop a *server-supplied* URL turning into a
  // `javascript:` / `file:` / `intent:` launch, and it rejects `tel:` by
  // design. Here the scheme is a compile-time constant and `cleanPhoneNumber`
  // has already reduced the payload to `[+]?\d+`, so there is nothing left to
  // inject with. `Uri(scheme:, path:)` also encodes the path itself, so a `+`
  // survives rather than being read as an escaped space.
  return Uri(scheme: scheme, path: number);
}

/// Places a call to [phone] — the guards first, then the platform dialer.
///
/// [subject] names who is being called ("Jane Smith"); [clientId] resolves the
/// per-client timezone override for the out-of-hours check (omit for a vendor
/// or a user, which have no settings cascade and fall back to the company's).
///
/// [logTarget] is the record a completed call can be logged against. When it is
/// supplied and the launch succeeds, the call is parked on
/// `Services.pendingCall` for `CallLogPrompter` to offer when the app next
/// resumes. Omit it (a team member's number on User Details, say) and nothing
/// is parked — there is no activity feed to write to.
///
/// The order below is load-bearing: the quiet-hours state is resolved *before*
/// anything is shown so that a user with both guards on sees **one** dialog,
/// not a generic "Are you sure?" followed by an out-of-hours one.
Future<void> callPhoneNumber(
  BuildContext context,
  String phone, {
  String? subject,
  String? clientId,
  CallLogTarget? logTarget,
}) async {
  final uri = telUri(phone);
  if (uri == null) return;
  // The preference is re-read here, at FIRE time, not just where the
  // affordance is drawn — the `guardedOnTap` convention this codebase uses for
  // `confirmActions`. A surface that forgets `PhoneActionsScope` renders a
  // stale button; this is what stops that stale button from actually placing a
  // call with the feature switched off.
  if (!context.read<Services>().phoneActions.value.tapToCall) return;

  // Everything context-derived is captured before the first await — the widget
  // may be gone by the time the settings read or the dialog resolves.
  // `Notify.capture`'s path has no blank-message fallback, so the error string
  // has to be `tr()`-derived; it is.
  final services = context.read<Services>();
  final toasts = Notify.capture(context);
  final failedMessage = context.tr('failed_to_open_url');
  final callLabel = context.tr('call');
  final outsideHoursMessage = context.tr('call_outside_business_hours');
  final prefs = services.phoneActions.value;

  final localTimeLine = prefs.warnOutsideBusinessHours
      ? await _outsideHoursLine(context, services, clientId)
      : null;

  if (prefs.confirmBeforeCall || localTimeLine != null) {
    if (!context.mounted) return;
    // `subject` renders up to two lines, so the identity and the clock share it
    // rather than competing for one slot.
    final who = (subject ?? '').trim();
    final lines = <String>[
      who.isEmpty ? phone.trim() : who,
      if (localTimeLine != null) localTimeLine,
    ];
    final confirmed = await showConfirmActionDialog(
      context,
      title: callLabel,
      message: localTimeLine == null ? null : outsideHoursMessage,
      subject: lines.join('\n'),
    );
    if (!confirmed) return;
  }

  if (!await launchExternalUri(uri)) {
    toasts?.error(failedMessage);
    return;
  }

  // Parked, not prompted: the app is on its way to the background and the user
  // is about to make a call. `CallLogPrompter` picks this up when they come
  // back. A `true` here means the *intent started*, never that a call
  // connected — which is why the offer is worded "Log call" and is dismissible.
  final target = logTarget;
  if (target == null || !prefs.offerToLogCalls) return;
  // `isMobile`, not `isTouchPrimary`: the offer hangs off an app-lifecycle
  // round trip, and only a native phone reliably backgrounds the app for a
  // call. On mobile *web* `AppLifecycleState` follows page visibility, so every
  // tab switch would look like a finished call; on desktop the dialer may not
  // background the app at all, which would leave this parked for ever.
  if (!Env.isMobile) return;
  if (!canLogCallAgainst(target.type)) return;
  final companyId = services.auth.session.value?.currentCompanyId;
  if (companyId == null || companyId.isEmpty) return;
  services.pendingCall.record(
    PendingCallLog(
      entityType: target.type,
      entityId: target.id,
      subject: target.subject,
      companyId: companyId,
      contactLabel: (subject ?? '').trim(),
      phone: phone.trim(),
    ),
  );
}

/// Opens the platform SMS composer for [phone].
///
/// Deliberately **unguarded**: `sms:` opens a composer and sends nothing, so
/// neither the confirm nor the out-of-hours warning has anything to protect
/// against — a text at 3 a.m. is the user's own decision, taken again when they
/// press send in their messaging app.
Future<void> messagePhoneNumber(BuildContext context, String phone) async {
  final uri = smsUri(phone);
  if (uri == null) return;
  // Same fire-time gate as [callPhoneNumber] — one switch governs both.
  if (!context.read<Services>().phoneActions.value.tapToCall) return;
  final toasts = Notify.capture(context);
  final failedMessage = context.tr('failed_to_open_url');
  if (!await launchExternalUri(uri)) toasts?.error(failedMessage);
}

/// The "11:47 PM in America/New_York" line, or null when the call is inside
/// business hours **or** the callee's timezone can't be determined.
///
/// An unresolvable timezone skips the warning rather than falling back to the
/// caller's own clock: "it's 11 PM for this contact" would be a confident lie
/// for a client eight zones away, and a warning users learn to dismiss is worse
/// than no warning at all. In practice a company always has a `timezone_id` —
/// the bundle even ships a `timezone_unset` nudge for the case where it
/// doesn't.
Future<String?> _outsideHoursLine(
  BuildContext context,
  Services services,
  String? clientId,
) async {
  final companyId = services.auth.currentCompanyId;
  if (companyId == null) return null;

  final zone = await resolveContactTimezone(
    services: services,
    companyId: companyId,
    clientId: clientId,
  );
  if (zone == null) return null;

  final localNow = contactClock(zone).local;
  if (!services.phoneActions.value.isOutsideBusinessHours(localNow)) {
    return null;
  }
  if (!context.mounted) return null;
  return context.tr('contact_local_time', {
    'time': formatTimeOfDay(
      localNow.hour,
      localNow.minute,
      military:
          services.formatterIfReady(companyId)?.settings.enableMilitaryTime ??
          false,
    ),
    'timezone': zone.name.isEmpty ? zone.location : zone.name,
  });
}

/// In-flight resolutions, keyed by `companyId/clientId`.
///
/// A contacts card mounts one `ContactLocalTime` per contact in a single frame
/// and they all share a client, so a client with eight contacts otherwise runs
/// nine identical cascade resolutions — and `SettingsRepository.resolved` is a
/// companies read *plus* a `clientDao.watchById(...).first`, i.e. a query-stream
/// subscribe and cancel each time.
///
/// Dedupes the burst only: the entry is dropped the moment the future
/// completes, so this is not a cache and inherits no staleness question.
/// `resolved` itself stays deliberately uncached (see its doc) — that
/// invariant is about *acting* on settings, which this never does.
final Map<String, Future<Timezone?>> _timezoneInFlight = {};

/// The callee's timezone: the client's `settings.timezone_id` override when
/// there is one, otherwise the company's, resolved through the same cascade
/// every other settings consumer uses.
Future<Timezone?> resolveContactTimezone({
  required Services services,
  required String companyId,
  String? clientId,
}) {
  final key = '$companyId/${clientId ?? ''}';
  final existing = _timezoneInFlight[key];
  if (existing != null) return existing;
  final future = _resolveContactTimezone(
    services: services,
    companyId: companyId,
    clientId: clientId,
  );
  _timezoneInFlight[key] = future;
  // Cascade, so `future` (not `whenComplete`'s new future) is what is stored
  // and returned — otherwise every caller would await a different object.
  future.whenComplete(() => _timezoneInFlight.remove(key));
  return future;
}

Future<Timezone?> _resolveContactTimezone({
  required Services services,
  required String companyId,
  String? clientId,
}) async {
  final resolved = await services.settings.resolved(
    companyId: companyId,
    clientId: clientId,
  );
  final id = resolved['timezone_id']?.toString() ?? '';
  if (id.isEmpty) return null;
  final zone = services.statics.timezone(id);
  return (zone == null || zone.name.isEmpty && zone.location.isEmpty)
      ? null
      : zone;
}

/// The callee's wall clock and their **current** UTC offset.
///
/// Resolved through the IANA tzdb (`Timezone.name`), so both halves are
/// DST-correct. That is load-bearing in two places and the fixed
/// [Timezone.utcOffset] is wrong for both:
///
///  * the clock itself — the server seeds `America/New_York` as `-18000`, so in
///    July a naive sum prints 14:30 when New York reads 15:30;
///  * the "is this contact even in a different zone?" test in
///    `ContactLocalTime` — the device's `timeZoneOffset` *is* DST-aware, so
///    comparing it against the standard-time constant made a New York client
///    look foreign to a New York user for roughly eight months a year, and
///    then showed them that hour-behind clock. The two errors compounded
///    instead of cancelling.
///
/// [local] is a `DateTime` whose *fields* read as the callee's wall clock; it
/// is not a meaningful instant, so use only its `hour` / `minute`. Falls back
/// to the fixed offset when the name isn't in the tzdb — a server that ships a
/// name we can't resolve should degrade by an hour, not throw.
({DateTime local, Duration offset}) contactClock(
  Timezone zone, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final location = _locationFor(zone.name);
  if (location == null) {
    return (
      local: at.toUtc().add(Duration(seconds: zone.utcOffset)),
      offset: Duration(seconds: zone.utcOffset),
    );
  }
  final zoned = tz.TZDateTime.from(at, location);
  return (local: zoned, offset: zoned.timeZoneOffset);
}

tz.Location? _locationFor(String name) {
  if (name.isEmpty) return null;
  try {
    return tz.getLocation(name);
  } catch (_) {
    // `getLocation` throws for an unknown id, and `initializeTimeZones()` not
    // having run yet would throw here too — either way the fixed offset is a
    // better answer than an exception inside a build.
    return null;
  }
}
