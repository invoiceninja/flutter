import 'package:flutter/foundation.dart';

import 'package:admin/app/env.dart';

/// Device-local preferences for the tap-to-call / tap-to-message affordances
/// on phone numbers (invoiceninja/flutter#109).
///
/// Persisted as one JSON blob in `nav_state.phone_actions_json` — five related
/// fields, same reasoning as `contacts_sync_json`: none of it is ever queried
/// by SQL, and one column is one migration instead of five.
///
/// Owned by `PhoneActionsController`; the quiet-hours predicate lives here so
/// it can be unit-tested without Drift, `Services`, or a widget tree.
@immutable
class PhoneActionsSettings {
  const PhoneActionsSettings({
    required this.tapToCall,
    this.confirmBeforeCall = false,
    this.warnOutsideBusinessHours = true,
    this.startMinutes = defaultStartMinutes,
    this.endMinutes = defaultEndMinutes,
  });

  /// 08:00 — deliberately generous. The window exists to catch a 2 a.m.
  /// mis-tap, not to police a working day.
  static const int defaultStartMinutes = 8 * 60;
  static const int defaultEndMinutes = 20 * 60;

  /// The defaults for *this device*, used when the column is null.
  ///
  /// [tapToCall] follows [Env.isTouchPrimary] rather than being flatly `true`.
  /// The app deliberately cannot ask whether a `tel:` handler exists —
  /// `canLaunchUrl` is banned by `test/lint/no_can_launch_url_test.dart`
  /// because on Android 11+ it answers a package-visibility question and lies
  /// — so on a Windows or Linux desktop with no dialer an on-by-default link
  /// would both stop the number selecting as text and fire "Couldn't open the
  /// link", a regression for a user who never asked for the feature. A macOS
  /// (FaceTime) or Phone Link user opts in with one switch; a field worker on
  /// a phone, who is who the issue is about, gets it out of the box.
  ///
  /// This is a *device* preference, so a phone and a desktop signed into the
  /// same account legitimately differ. Only expressible because the pref is a
  /// JSON blob: a null column means "ask the platform", whereas a SQL column
  /// default would have to pick one answer for every device.
  factory PhoneActionsSettings.deviceDefaults() =>
      PhoneActionsSettings(tapToCall: Env.isTouchPrimary);

  /// Tapping a phone number opens the dialer, and contact rows grow Call /
  /// Message buttons. Off restores the plain copyable text the app had before.
  final bool tapToCall;

  /// Show an in-app "Call …?" prompt before handing over to the dialer.
  ///
  /// **Off by default**, unlike the sibling `confirm_actions` preference: both
  /// iOS (a system `Call …?` alert) and Android (`ACTION_VIEW tel:` opens the
  /// dialer *pre-filled*, the user still presses the call button) already
  /// confirm before a call connects, so switching this on adds a second
  /// prompt in front of one the OS is going to show anyway — the shape
  /// CLAUDE.md warns against under § Action confirmations. It exists because
  /// the issue asked for it, for people who want the belt as well as braces.
  final bool confirmBeforeCall;

  /// Warn when the callee's local time falls outside [startMinutes] ..
  /// [endMinutes]. On by default — this is the half of the guard the OS cannot
  /// provide, and the only one that knows what time it is *where the phone
  /// will ring*.
  final bool warnOutsideBusinessHours;

  /// Minutes past midnight, in the *callee's* zone. Not a `TimeOfDay`: this
  /// type is JSON-serialised and must not depend on `dart:ui`.
  final int startMinutes;
  final int endMinutes;

  /// Whether [localTime] — already converted into the callee's zone — falls
  /// outside the configured window.
  ///
  /// Two shapes are deliberately supported rather than rejected as invalid:
  ///  * `start == end` is an empty window and never warns, so dragging the two
  ///    fields together is a way to silence the warning without hunting for
  ///    the switch;
  ///  * `start > end` wraps midnight (22:00 → 06:00 reads as "warn during the
  ///    day"), which is nonsense for business hours but is what the user
  ///    typed, and inverting it silently would be worse than honouring it.
  ///
  /// Time of day only — there is no weekday axis, so a Sunday afternoon does
  /// not warn. A deliberate omission (it doubles the settings card); if it is
  /// ever asked for, it belongs here beside the window.
  bool isOutsideBusinessHours(DateTime localTime) {
    if (startMinutes == endMinutes) return false;
    final minutes = localTime.hour * 60 + localTime.minute;
    if (startMinutes < endMinutes) {
      return minutes < startMinutes || minutes >= endMinutes;
    }
    return minutes < startMinutes && minutes >= endMinutes;
  }

  PhoneActionsSettings copyWith({
    bool? tapToCall,
    bool? confirmBeforeCall,
    bool? warnOutsideBusinessHours,
    int? startMinutes,
    int? endMinutes,
  }) => PhoneActionsSettings(
    tapToCall: tapToCall ?? this.tapToCall,
    confirmBeforeCall: confirmBeforeCall ?? this.confirmBeforeCall,
    warnOutsideBusinessHours:
        warnOutsideBusinessHours ?? this.warnOutsideBusinessHours,
    startMinutes: startMinutes ?? this.startMinutes,
    endMinutes: endMinutes ?? this.endMinutes,
  );

  Map<String, dynamic> toJson() => {
    'tapToCall': tapToCall,
    'confirmBeforeCall': confirmBeforeCall,
    'warnOutsideBusinessHours': warnOutsideBusinessHours,
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
  };

  /// Tolerant of a partial / older blob: a key that is present is taken
  /// literally — a *stored* value is the user's choice and the platform must
  /// not re-decide it — while a **missing** key falls back to the same default
  /// a fresh install on this device would get, including
  /// [Env.isTouchPrimary] for [tapToCall].
  ///
  /// That last part matters for a blob written by a build that predates a
  /// field: falling back to a flat `true` instead would switch tap-to-call on
  /// for desktop users who never asked for it, which is precisely what
  /// [deviceDefaults] exists to avoid.
  factory PhoneActionsSettings.fromJson(Map<String, dynamic> json) {
    bool flag(String key, bool fallback) {
      final v = json[key];
      return v is bool ? v : fallback;
    }

    int minutes(String key, int fallback) {
      final v = json[key];
      final n = v is int ? v : int.tryParse('$v');
      if (n == null || n < 0 || n > 24 * 60) return fallback;
      return n;
    }

    return PhoneActionsSettings(
      tapToCall: flag('tapToCall', Env.isTouchPrimary),
      confirmBeforeCall: flag('confirmBeforeCall', false),
      warnOutsideBusinessHours: flag('warnOutsideBusinessHours', true),
      startMinutes: minutes('startMinutes', defaultStartMinutes),
      endMinutes: minutes('endMinutes', defaultEndMinutes),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PhoneActionsSettings &&
      other.tapToCall == tapToCall &&
      other.confirmBeforeCall == confirmBeforeCall &&
      other.warnOutsideBusinessHours == warnOutsideBusinessHours &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes;

  @override
  int get hashCode => Object.hash(
    tapToCall,
    confirmBeforeCall,
    warnOutsideBusinessHours,
    startMinutes,
    endMinutes,
  );
}
