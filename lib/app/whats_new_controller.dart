import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:admin/app/env.dart';
import 'package:admin/app/version.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/release_notes.dart';

/// The "What's new" dialog's schedule — the owner of [DevicePrefKeys.whatsNew]
/// (docs/whats-new-dialog.md).
///
/// [noteLaunch], called once by `main()`, decides whether this launch follows
/// an update. If it does, [pending] holds the releases to show, and the
/// shell's `WhatsNewHost` opens them at the first quiet moment. Each launch
/// that gives up without one counts against [maxAttempts]; after that, the
/// notes wait in About and the command palette.
///
/// While the dialog may still open on its own, and for [promptHold] after it
/// opens, [holdsBackPromptsAt] keeps the mobile-app promo away.
///
/// A device preference, so a sign-out keeps it. Built before the store loads,
/// so it re-reads on the store's notify, as `MobileAppPromoController` does.
class WhatsNewController extends ChangeNotifier {
  WhatsNewController({
    required DevicePrefsStore prefs,
    this.currentVersion = AppVersion.kClientVersion,
    this.catalog = kReleaseNotes,
    Set<ReleaseNoteSurface>? surfaces,
    this.isDemoBuild = Env.isDemoBuild,
    this.demoMode = Env.demoMode,
  }) : _prefs = prefs,
       surfaces = surfaces ?? currentReleaseNoteSurfaces() {
    _sync();
    _prefs.addListener(_sync);
  }

  final DevicePrefsStore _prefs;
  final String currentVersion;
  final List<ReleaseNotes> catalog;
  final Set<ReleaseNoteSurface> surfaces;
  final bool isDemoBuild;
  final bool demoMode;

  /// Launches that may give up without a quiet moment before the dialog
  /// stops opening on its own.
  static const int maxAttempts = 3;

  /// How long after the dialog opens the mobile-app promo stays away.
  static const Duration promptHold = Duration(days: 1);

  WhatsNewState get state => _state;
  WhatsNewState _state = const WhatsNewState();

  /// The releases this launch's update brought, newest first; empty when
  /// there is nothing to tell. Set by [noteLaunch], cleared by [markSeen].
  List<ReleaseNotes> get pending => _pending;
  List<ReleaseNotes> _pending = const [];

  /// Set once the dialog has opened on its own in this process — a second
  /// sign-in in the same launch must not re-arm it.
  bool shownThisLaunch = false;

  /// Whether the shell may still open [pending] on its own.
  bool get autoOpens => _pending.isNotEmpty && attempts < maxAttempts;

  /// Launches of this build that gave up without a quiet moment. Counted per
  /// version, so a release whose dialog never found one doesn't silence the
  /// next.
  int get attempts =>
      _state.attemptedVersion == currentVersion ? _state.attempts : 0;

  /// Decide what this launch tells the user. [existingInstall] is whether the
  /// device ran an earlier build: the store was not created by this open, or
  /// a session was restored. Only `main()` calls it, so no harness ever
  /// arms the dialog.
  ///
  /// Writes nothing it can't stand behind: not before the store has read its
  /// rows, and not when there is nothing to show — a later build that
  /// carries notes still covers this update.
  Future<void> noteLaunch({required bool existingInstall}) async {
    if (!_prefs.loadSucceeded || isDemoBuild || demoMode) return;
    final seen = _state.seenVersion;
    if (seen == null && !existingInstall) {
      // A new install: nothing changed for this user.
      await _save(_state.copyWith(seenVersion: currentVersion));
      return;
    }
    if (seen != null && compareSemver(currentVersion, seen) <= 0) return;
    final releases = releasesToShow(
      seen: seen,
      current: currentVersion,
      surfaces: surfaces,
      catalog: catalog,
    );
    if (releases.isEmpty) return;
    _pending = releases;
    notifyListeners();
  }

  /// The dialog opened. Recorded on open, not on close, so a dialog a 401
  /// tears down still starts the promo's hold.
  Future<void> noteOpened(DateTime now) => _save(_state.copyWith(shownAt: now));

  /// A launch went by with no quiet moment for the dialog.
  Future<void> noteGaveUp() => _save(
    _state.copyWith(attempts: attempts + 1, attemptedVersion: currentVersion),
  );

  /// The user has read [pending]: this version is told.
  Future<void> markSeen() async {
    if (_pending.isEmpty) return;
    _pending = const [];
    await _save(_state.copyWith(seenVersion: currentVersion));
  }

  /// Whether another automatic prompt must wait at [now]: the dialog may
  /// still open on its own, or opened less than [promptHold] ago. A
  /// [WhatsNewState.shownAt] in the future — the clock moved back — holds
  /// nothing, or it could hold for months.
  bool holdsBackPromptsAt(DateTime now) {
    if (autoOpens) return true;
    final shownAt = _state.shownAt;
    if (shownAt == null) return false;
    final since = now.difference(shownAt);
    return !since.isNegative && since < promptHold;
  }

  /// The releases About and the command palette open: [pending], else the
  /// newest release this build carries.
  List<ReleaseNotes> get onRequest => _pending.isNotEmpty
      ? _pending
      : releasesToShow(
          seen: null,
          current: currentVersion,
          surfaces: surfaces,
          catalog: catalog,
        );

  Future<void> _save(WhatsNewState next) async {
    _state = next;
    notifyListeners();
    await _prefs.write(DevicePrefKeys.whatsNew, next.encode());
  }

  /// Re-read the store (its `load`, or a wipe — which keeps this key).
  void _sync() {
    final next = WhatsNewState.decode(_prefs.read(DevicePrefKeys.whatsNew));
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
class WhatsNewState {
  const WhatsNewState({
    this.seenVersion,
    this.shownAt,
    this.attempts = 0,
    this.attemptedVersion,
  });

  /// The version whose notes this install has shown, or that it was
  /// installed at. Null on an install that predates the record.
  final String? seenVersion;

  /// When the dialog last opened.
  final DateTime? shownAt;

  /// Launches of [attemptedVersion] that gave up without showing it.
  final int attempts;
  final String? attemptedVersion;

  WhatsNewState copyWith({
    String? seenVersion,
    DateTime? shownAt,
    int? attempts,
    String? attemptedVersion,
  }) => WhatsNewState(
    seenVersion: seenVersion ?? this.seenVersion,
    shownAt: shownAt ?? this.shownAt,
    attempts: attempts ?? this.attempts,
    attemptedVersion: attemptedVersion ?? this.attemptedVersion,
  );

  String encode() => jsonEncode({
    if (seenVersion != null) 'seenVersion': seenVersion,
    if (shownAt != null) 'shownAt': shownAt!.toUtc().millisecondsSinceEpoch,
    'attempts': attempts,
    if (attemptedVersion != null) 'attemptedVersion': attemptedVersion,
  });

  /// A missing or unreadable row is an install that predates the record.
  static WhatsNewState decode(String? raw) {
    if (raw == null) return const WhatsNewState();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const WhatsNewState();
      final seen = json['seenVersion'];
      final shownAt = json['shownAt'];
      final attempts = json['attempts'];
      final attemptedVersion = json['attemptedVersion'];
      return WhatsNewState(
        seenVersion: seen is String && seen.isNotEmpty ? seen : null,
        shownAt: shownAt is int
            ? DateTime.fromMillisecondsSinceEpoch(shownAt, isUtc: true)
            : null,
        attempts: attempts is int && attempts >= 0 ? attempts : 0,
        attemptedVersion: attemptedVersion is String ? attemptedVersion : null,
      );
    } on FormatException {
      return const WhatsNewState();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is WhatsNewState &&
      other.seenVersion == seenVersion &&
      other.shownAt == shownAt &&
      other.attempts == attempts &&
      other.attemptedVersion == attemptedVersion;

  @override
  int get hashCode =>
      Object.hash(seenVersion, shownAt, attempts, attemptedVersion);
}
