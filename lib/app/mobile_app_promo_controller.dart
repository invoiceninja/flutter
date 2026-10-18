import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:admin/app/whats_new_controller.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// The "get the mobile app" promo's schedule — the owner of
/// [DevicePrefKeys.mobileAppPromo] (docs/mobile-app-promo.md).
///
/// It opens on its own at most [maxAutoOpens] times, never before the
/// [daysBeforeFirstOpen]th day this device is used, and each close without
/// engaging pushes the next one out ([snooze]). "Don't show again" ([finish])
/// and taking the app ([markEngaged]) end the automatic opens; the About and
/// Device Settings entries still open it on request.
///
/// A device preference, so it survives a sign-out: the promo is "this machine
/// has been told", and the next person signing in here shouldn't be pitched
/// again. Built before the store loads, so it re-reads on the store's notify,
/// exactly as `SignOutNotice` does — without that a launch would decode the
/// defaults and "Don't show again" would never stick.
class MobileAppPromoController extends ChangeNotifier {
  MobileAppPromoController({
    required DevicePrefsStore prefs,
    this.promote = false,
    WhatsNewController? whatsNew,
  }) : _prefs = prefs,
       _whatsNew = whatsNew {
    _sync();
    _prefs.addListener(_sync);
  }

  final DevicePrefsStore _prefs;

  /// The What's New dialog, which goes first: while it may still open on its
  /// own, and for a day after it opens, the promo is not due
  /// (docs/whats-new-dialog.md).
  final WhatsNewController? _whatsNew;

  /// Whether this build pitches the phone app unasked — the automatic open
  /// and the sidebar card. Off unless `main()` asks: a test or harness that
  /// builds the graph must never get a dialog over the screen it is driving,
  /// nor a card that shortens the nav list it taps (the web smoke test).
  /// About and Device Settings, which the user goes looking for, don't ask.
  final bool promote;

  static const int maxAutoOpens = 3;
  static const int daysBeforeFirstOpen = 3;

  /// After the first and the second close without engaging.
  static const List<Duration> snoozeSteps = [
    Duration(days: 7),
    Duration(days: 30),
  ];

  MobileAppPromoState get state => _state;
  MobileAppPromoState _state = const MobileAppPromoState();

  /// Set once the promo has opened on its own in this process. Not persisted
  /// and not on the shell, which unmounts on a sign-out — a second sign-in in
  /// the same launch must not re-arm it.
  bool shownThisLaunch = false;

  /// Count [today] as a day this device was used, once per calendar day.
  Future<void> recordUseDay(Date today) async {
    // Before the store loads, the state is the defaults; writing it would
    // overwrite the real one.
    if (!_prefs.isLoaded) return;
    final last = Date.tryParse(_state.lastDay);
    if (last == today) return;
    await _save(
      _state.copyWith(daysSeen: _state.daysSeen + 1, lastDay: today.toIso()),
    );
  }

  /// Whether the next automatic open may happen at [now].
  bool isDue(DateTime now) {
    final s = _state;
    if (!_prefs.isLoaded || s.done || s.engaged) return false;
    if (s.closes >= maxAutoOpens) return false;
    if (s.daysSeen < daysBeforeFirstOpen) return false;
    if (_whatsNew?.holdsBackPromptsAt(now) ?? false) return false;
    final next = s.nextAt;
    return next == null || !now.isBefore(next);
  }

  /// The automatic open now showing is the last one.
  bool get isLastReminder => _state.closes >= maxAutoOpens - 1;

  /// The sidebar card's gate: gone once the user said no for good, took the
  /// app, or let every automatic open go by.
  bool get showsSidebarCard =>
      !_state.done && !_state.engaged && _state.closes < maxAutoOpens;

  /// An automatic open closed without engaging: push the next one out.
  Future<void> snooze(DateTime now) {
    final closes = _state.closes + 1;
    final step = closes - 1 < snoozeSteps.length
        ? snoozeSteps[closes - 1]
        : null;
    return _save(
      _state.copyWith(
        closes: closes,
        nextAt: step == null ? null : now.add(step),
        clearNextAt: step == null,
      ),
    );
  }

  /// The user copied the link, opened the store, or said they installed it.
  Future<void> markEngaged() =>
      _state.engaged ? Future.value() : _save(_state.copyWith(engaged: true));

  /// "Don't show again", or Done after installing.
  Future<void> finish() =>
      _state.done ? Future.value() : _save(_state.copyWith(done: true));

  Future<void> _save(MobileAppPromoState next) async {
    _state = next;
    notifyListeners();
    await _prefs.write(DevicePrefKeys.mobileAppPromo, next.encode());
  }

  /// Re-read the store (its `load`, or a wipe — which keeps this key).
  void _sync() {
    final next = MobileAppPromoState.decode(
      _prefs.read(DevicePrefKeys.mobileAppPromo),
    );
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _prefs.removeListener(_sync);
    super.dispose();
  }
}

@immutable
class MobileAppPromoState {
  const MobileAppPromoState({
    this.closes = 0,
    this.nextAt,
    this.done = false,
    this.engaged = false,
    this.daysSeen = 0,
    this.lastDay = '',
  });

  /// Automatic opens closed without engaging.
  final int closes;

  /// No automatic open before this instant.
  final DateTime? nextAt;
  final bool done;
  final bool engaged;

  /// Distinct calendar days this device has been used while signed in.
  final int daysSeen;

  /// The last of those days, `YYYY-MM-DD`.
  final String lastDay;

  MobileAppPromoState copyWith({
    int? closes,
    DateTime? nextAt,
    bool clearNextAt = false,
    bool? done,
    bool? engaged,
    int? daysSeen,
    String? lastDay,
  }) => MobileAppPromoState(
    closes: closes ?? this.closes,
    nextAt: clearNextAt ? null : (nextAt ?? this.nextAt),
    done: done ?? this.done,
    engaged: engaged ?? this.engaged,
    daysSeen: daysSeen ?? this.daysSeen,
    lastDay: lastDay ?? this.lastDay,
  );

  String encode() => jsonEncode({
    'closes': closes,
    if (nextAt != null) 'nextAt': nextAt!.toUtc().millisecondsSinceEpoch,
    'done': done,
    'engaged': engaged,
    'daysSeen': daysSeen,
    'lastDay': lastDay,
  });

  /// A missing or unreadable row is a device that hasn't been told yet.
  static MobileAppPromoState decode(String? raw) {
    if (raw == null) return const MobileAppPromoState();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const MobileAppPromoState();
      final nextAt = json['nextAt'];
      return MobileAppPromoState(
        closes: _int(json['closes']),
        nextAt: nextAt is int
            ? DateTime.fromMillisecondsSinceEpoch(nextAt, isUtc: true)
            : null,
        done: json['done'] == true,
        engaged: json['engaged'] == true,
        daysSeen: _int(json['daysSeen']),
        lastDay: json['lastDay'] is String ? json['lastDay'] as String : '',
      );
    } on FormatException {
      return const MobileAppPromoState();
    }
  }

  static int _int(Object? v) => v is int && v >= 0 ? v : 0;

  @override
  bool operator ==(Object other) =>
      other is MobileAppPromoState &&
      other.closes == closes &&
      other.nextAt == nextAt &&
      other.done == done &&
      other.engaged == engaged &&
      other.daysSeen == daysSeen &&
      other.lastDay == lastDay;

  @override
  int get hashCode =>
      Object.hash(closes, nextAt, done, engaged, daysSeen, lastDay);
}
