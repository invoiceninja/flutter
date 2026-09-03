import 'package:flutter/widgets.dart';

import 'package:admin/app/services.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/domain/phone/pending_call_log.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/log_call_sheet.dart';
import 'package:admin/ui/core/utils/call_note_sink.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/notify_async.dart';

/// Minimum time away before a parked call is worth offering.
///
/// A mis-tap on a phone number bounces straight back — the dialer opens, the
/// user hits back, two seconds have passed. Offering to log *that* is noise.
/// Twenty seconds is short enough to catch "they didn't pick up" and long
/// enough to exclude a bounce.
const Duration kMinCallAwayDuration = Duration(seconds: 20);

/// Beyond this the app was almost certainly backgrounded for something other
/// than the call — a night on the home screen, a day in the app switcher —
/// and the elapsed time is no longer a believable call duration.
const Duration kMaxCallAwayDuration = Duration(hours: 4);

/// Offers to log a call when the user comes back from the dialer
/// (invoiceninja/flutter#120).
///
/// Mounted beside `ToastHost` in `main.dart` so it can raise a toast over any
/// route, and — like `ShortcutHintOverlay` next to it — it paints nothing. It
/// is a widget rather than another `WidgetsBindingObserver` in `main.dart`'s
/// list because the offer needs a `BuildContext` under the providers: it opens
/// the log form and enqueues through the repositories.
///
/// Four things here are deliberate:
///
///  * **Only `paused` / `detached` → `resumed` counts as a round trip.** iOS
///    fires `inactive` for a notification-shade peek or an app-switcher glance,
///    and Android can surface `hidden`; treating those as a finished call would
///    offer to log one every time the user glanced at a notification. Same gate
///    `SyncLifecycleObserver` uses, for the same reason.
///  * **The platform gate is upstream, not here.** `callPhoneNumber`
///    (`phone_actions.dart`) refuses to park anything unless `Env.isMobile` —
///    `isTouchPrimary` would include a mobile *browser*, where
///    `AppLifecycleState` follows page visibility and every tab switch looks
///    like a finished call. Nothing is ever parked off-mobile, so nothing is
///    ever offered; a second `pendingCall.record` caller would need its own
///    gate.
///  * **The away time seeds the duration, it does not assert it.** It includes
///    the seconds before the user pressed dial, so the form rounds it to whole
///    minutes and it is only offered inside [kMinCallAwayDuration] ..
///    [kMaxCallAwayDuration]. The user sees it in an editable field before
///    anything is saved.
///  * **A dismissible toast, never a modal.** The app already ships
///    "Confirm before calling" off because the OS confirms; interrupting
///    someone who just made a call with a form they did not ask for would be
///    the same mistake. Ignore it and it disappears; the record's actions menu
///    and Activity tab keep the manual path.
class CallLogPrompter extends StatefulWidget {
  const CallLogPrompter({
    required this.services,
    this.contextOf,
    this.now,
    super.key,
  });

  final Services services;

  /// Supplies a context **inside** the router's `Navigator` for the log form.
  ///
  /// Load-bearing, not a convenience. This widget is mounted in
  /// `MaterialApp.router`'s `builder`, i.e. as a *sibling* of the router's
  /// output — the same slot `ToastHost` occupies — so its own context sits
  /// above that `Navigator` and `showDialog` / `showModalBottomSheet` from it
  /// would have none to push onto. `main.dart` passes
  /// `_router.routerDelegate.navigatorKey.currentContext`, exactly what
  /// `deepLinks.attach` takes for the same reason. Null falls back to this
  /// widget's own context, which is what a test that pumps it as the tree root
  /// wants.
  final BuildContext? Function()? contextOf;

  /// Clock, injectable for tests. `tester.pump(duration)` advances Flutter's
  /// fake clock but not `DateTime.now()`, so without this the away time is
  /// always ~zero and every gate below passes vacuously. Same seam
  /// `SavedViewsRepository` takes for the same reason.
  final DateTime Function()? now;

  @override
  State<CallLogPrompter> createState() => _CallLogPrompterState();
}

class _CallLogPrompterState extends State<CallLogPrompter>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _backgroundedAt = _now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null) return;
    _offer(_now().difference(since));
  }

  void _offer(Duration away) {
    final services = widget.services;
    // Consumed FIRST, before every other gate: the round trip has happened
    // either way, so a parked call is resolved whether or not it is worth
    // offering. Returning early with the slot still full would surface this
    // call at the end of some later, unrelated background trip — with an away
    // duration measured from that trip. The preference check has to sit below
    // this for the same reason: switch the offer off mid-call and the parked
    // entry would otherwise wait for you to switch it back on.
    final call = services.pendingCall.take(
      activeCompanyId: services.auth.session.value?.currentCompanyId,
    );
    if (call == null || !mounted) return;
    if (!services.phoneActions.value.offerToLogCalls) return;
    if (away < kMinCallAwayDuration || away > kMaxCallAwayDuration) return;

    // The glyph ties the toast to the marker the note itself carries, and the
    // name is all the app can honestly assert: the away time is a *suggestion*
    // for the form's duration field, not a measured call length, so stating it
    // here — where it cannot be corrected — would be a claim, not a prompt.
    services.toasts.info(
      '$kCallNoteMarker ${call.displayName}',
      action: NotifyAction(context.tr('log_call'), () => _open(call, away)),
    );
  }

  Future<void> _open(PendingCallLog call, Duration suggested) async {
    if (!mounted) return;
    final host = widget.contextOf?.call() ?? context;
    if (!host.mounted) return;
    final note = await showLogCallSheet(
      host,
      companyId: call.companyId,
      subject: call.subject,
      dialled: call.phone.isEmpty
          ? null
          : (
              label: call.contactLabel,
              phone: call.phone,
              isPrimary: false,
              isPartyOwnLine: false,
            ),
      suggestedDuration: suggested,
    );
    if (note == null || !mounted || !host.mounted) return;
    final op = enqueueCallNote(
      widget.services,
      type: call.entityType,
      entityId: call.entityId,
      companyId: call.companyId,
      note: note,
    );
    if (op == null) {
      // Unreachable while `canLogCallAgainst` and the sink's switch agree
      // (`call_note_sink_test.dart` pins that), but the user has typed a
      // summary and pressed Save by now — dropping it silently would be the
      // worst possible failure, so say so.
      Notify.error(host, host.tr('an_error_occurred'));
      return;
    }
    // `op` is a thunk, not a running future: `runMutationWithNotify`'s Retry
    // re-invokes what it is given, and re-awaiting a settled future would fail
    // instantly for ever. See `enqueueCallNote`.
    await runMutationWithNotify(host, op, successMsg: host.tr('logged_call'));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
