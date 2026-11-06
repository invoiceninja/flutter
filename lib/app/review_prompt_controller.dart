import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:store_services/store_services.dart';

import 'package:admin/app/env.dart';
import 'package:admin/app/prompt_hold.dart';
import 'package:admin/app/version.dart';
import 'package:admin/app/whats_new_controller.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/review_prompt.dart';
import 'package:admin/domain/sync/landed_mutation.dart';

/// This build's review channel (docs/review-prompt.md).
ReviewChannel currentReviewChannel() => resolveReviewChannel(
  isWeb: kIsWeb,
  platform: defaultTargetPlatform,
  isStoreBuild: StoreReview.isStoreBuild,
  isDemo: Env.isDemoBuild || Env.demoMode,
);

/// How an open of the review card ended — the controller moves the schedule
/// by it ([ReviewPromptController.noteCardResult]).
enum ReviewCardResult {
  /// Closed at the first question, or "Not now" there.
  closed,

  /// Closed, or "Not now", after saying they enjoy the app.
  closedAfterYes,

  /// Closed after "Not really" — or "Send feedback", which the host follows
  /// with Contact Us.
  unhappy,

  /// "Send feedback": [unhappy], and the host opens Contact Us.
  sendFeedback,

  /// The store or review page opened.
  rated,
}

/// The review prompt's schedule — the owner of [DevicePrefKeys.reviewPrompt]
/// (docs/review-prompt.md).
///
/// Counts on every build, beta included: the days this device is used and
/// the wins the server confirms. Asks only when a finishing win has just
/// landed, the install is old enough, nothing went wrong lately, and the
/// build is out of beta — through the OS's own sheet on a store build, our
/// card everywhere else.
class ReviewPromptController extends ChangeNotifier {
  ReviewPromptController({
    required DevicePrefsStore prefs,
    this.autoAsk = false,
    WhatsNewController? whatsNew,
    bool Function(DateTime now)? promoShownRecently,
    ReviewChannel? channel,
    this.isBeta = kAppIsBeta,
    this.version = AppVersion.kClientVersion,
    DateTime Function()? clock,
  }) : _prefs = prefs,
       _whatsNew = whatsNew,
       _promoShownRecently = promoShownRecently,
       channel = channel ?? currentReviewChannel(),
       _clock = clock ?? DateTime.now {
    _sync();
    _prefs.addListener(_sync);
  }

  final DevicePrefsStore _prefs;
  final WhatsNewController? _whatsNew;
  final bool Function(DateTime now)? _promoShownRecently;
  final DateTime Function() _clock;

  /// Whether this build asks unasked. Off unless `main()` says so: a test or
  /// harness that builds the graph must never get a sheet or a card over the
  /// screen it is driving. The manual "Rate the app" entries don't ask.
  final bool autoAsk;

  /// Where this build sends a review.
  final ReviewChannel channel;

  /// `kAppIsBeta`, injectable for tests. While true nothing asks and no
  /// "Rate the app" entry shows — but the counters still run.
  final bool isBeta;

  /// This build's version, for "only on a newer version" re-asks.
  final String version;

  DateTime get now => _clock();

  // The gates (docs/review-prompt.md § Gates).
  static const Duration minInstallAge = Duration(days: 7);
  static const int minDaysSeen = 5;
  static const int minWins = 3;
  static const int minWinDays = 2;
  static const Duration minGaAge = Duration(days: 3);
  static const Duration problemHold = Duration(days: 3);

  /// Wins closer together than this are one burst — a bulk email of twenty
  /// invoices is one win.
  static const Duration burstWindow = Duration(minutes: 5);

  /// Only a row queued this recently is "just finished" — a reconnect that
  /// lands yesterday's offline edits is no moment.
  static const Duration freshRow = Duration(minutes: 10);

  /// How long a win stays a moment.
  static const Duration momentWindow = Duration(seconds: 60);

  // The cadence.
  static const Duration nativeInterval = Duration(days: 120);
  static const int maxNativeAsksPerYear = 3;
  static const int maxCardShows = 3;
  static const List<Duration> cardSnoozes = [
    Duration(days: 30),
    Duration(days: 90),
  ];
  static const Duration afterYesSnooze = Duration(days: 90);
  static const Duration unhappyHold = Duration(days: 180);

  ReviewPromptState get state => _state;
  ReviewPromptState _state = const ReviewPromptState();

  DateTime? _armedAt;

  /// When the last arming win landed, while it is still a moment.
  DateTime? get armedAt => _armedAt;

  /// Set once this process has asked on its own; a second sign-in in the
  /// same launch must not ask again.
  bool askedThisLaunch = false;

  /// Whether the "Rate the app" entries (About, the command palette) show
  /// for [session]: out of beta, with a page to open, and never to someone
  /// signed into the demo server — a tap there would set [ReviewPromptState.
  /// done] and this device would never be asked once a real account signs in.
  bool offersManualRatingTo(AuthSession? session) =>
      !isBeta &&
      kReviewPromptEnabled &&
      reviewListingUri(channel) != null &&
      session != null &&
      !session.isDemo;

  /// Count [today] as a day this device was used — on a session, a resume
  /// and a win — and stamp the install and GA dates the first time.
  Future<void> recordUseDay([Date? today]) async {
    if (!_prefs.isLoaded) return;
    final day = today ?? _dateOf(now);
    final s = _state;
    final firstSeen = s.firstSeenAt == null;
    final firstGa = !isBeta && s.gaFirstSeenAt == null;
    final newDay = Date.tryParse(s.lastDay) != day;
    if (!firstSeen && !firstGa && !newDay) return;
    final t = now;
    await _save(
      s.copyWith(
        firstSeenAt: firstSeen ? t : null,
        gaFirstSeenAt: firstGa ? t : null,
        daysSeen: newDay ? s.daysSeen + 1 : null,
        lastDay: newDay ? day.toIso() : null,
      ),
    );
  }

  /// A change the server confirmed. Returns whether it armed a moment.
  Future<bool> noteWin(LandedMutation m) async {
    final win = classifyReviewWin(m);
    if (win == ReviewWin.none || !_prefs.isLoaded) return false;
    await recordUseDay();
    final t = now;
    final s = _state;
    final last = s.lastWinAt;
    final newBurst =
        last == null || t.difference(last) > burstWindow || t.isBefore(last);
    final today = _dateOf(t).toIso();
    if (newBurst || s.lastWinDay != today) {
      await _save(
        s.copyWith(
          wins: newBurst ? s.wins + 1 : null,
          lastWinAt: t,
          winDays: s.lastWinDay != today ? s.winDays + 1 : null,
          lastWinDay: today,
        ),
      );
    } else {
      await _save(s.copyWith(lastWinAt: t));
    }
    final age = t.difference(m.rowCreatedAt);
    if (win == ReviewWin.arms &&
        !m.committedSettle &&
        !age.isNegative &&
        age <= freshRow) {
      _armedAt = t;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Something went wrong with the user's work — a dead, unconfirmed,
  /// conflicting or rejected change. No ask for [problemHold].
  Future<void> noteProblem() async {
    _armedAt = null;
    if (!_prefs.isLoaded) return;
    await _save(_state.copyWith(lastProblemAt: now));
  }

  /// Whether this device has earned an ask, leaving out the moment and the
  /// live inputs ([isDue] adds those).
  bool isEligibleAt(DateTime t) {
    final s = _state;
    if (!_prefs.isLoaded || !kReviewPromptEnabled || isBeta) return false;
    if (channel == ReviewChannel.none || s.done) return false;
    if (!_elapsed(s.gaFirstSeenAt, minGaAge, t)) return false;
    if (!_elapsed(s.firstSeenAt, minInstallAge, t)) return false;
    if (s.daysSeen < minDaysSeen) return false;
    if (s.wins < minWins || s.winDays < minWinDays) return false;
    final problem = s.lastProblemAt;
    if (problem != null && !_elapsed(problem, problemHold, t)) return false;
    final next = s.nextAt;
    if (next != null && t.isBefore(next)) return false;
    if (s.newerThan.isNotEmpty && compareSemver(version, s.newerThan) <= 0) {
      return false;
    }
    if (channel.isNative) {
      final yearAgo = t.subtract(const Duration(days: 365));
      final recent = s.asks.where((a) => a.isAfter(yearAgo)).length;
      if (recent >= maxNativeAsksPerYear) return false;
    } else if (s.cardShows >= maxCardShows) {
      return false;
    }
    if (_whatsNew?.holdsBackPromptsAt(t) ?? false) return false;
    if (_promoShownRecently?.call(t) ?? false) return false;
    return true;
  }

  /// Whether to ask right now: [isEligibleAt], a win that is still a moment,
  /// nothing waiting for the user's attention in the outbox, and online.
  bool isDue({required int attentionCount, required bool online}) {
    final t = now;
    final armed = _armedAt;
    if (armed == null) return false;
    final since = t.difference(armed);
    if (since.isNegative || since > momentWindow) return false;
    if (attentionCount > 0 || !online) return false;
    return isEligibleAt(t);
  }

  /// Whether another automatic prompt (the mobile-app promo) must wait: for
  /// [kAutomaticPromptGap] after this one asked.
  bool holdsBackPromptsAt(DateTime t) =>
      promptHoldsBack(_state.shownAt, kAutomaticPromptGap, t);

  /// The OS was asked to show its sheet.
  Future<void> noteNativeAsk() {
    final t = now;
    _armedAt = null;
    final yearAgo = t.subtract(const Duration(days: 365));
    return _save(
      _state.copyWith(
        asks: [..._state.asks.where((a) => a.isAfter(yearAgo)), t],
        nextAt: t.add(nativeInterval),
        newerThan: version,
        shownAt: t,
      ),
    );
  }

  /// The card is opening — recorded on open, so a card a 401 tears down
  /// still counts and still holds the promo back.
  Future<void> noteCardShown() {
    _armedAt = null;
    return _save(
      _state.copyWith(cardShows: _state.cardShows + 1, shownAt: now),
    );
  }

  /// How the card closed.
  Future<void> noteCardResult(ReviewCardResult result) {
    final t = now;
    final s = _state;
    switch (result) {
      case ReviewCardResult.rated:
        return _save(s.copyWith(done: true));
      case ReviewCardResult.unhappy || ReviewCardResult.sendFeedback:
        return _save(
          s.copyWith(
            nextAt: t.add(unhappyHold),
            newerThan: version,
            done: s.cardShows >= maxCardShows,
          ),
        );
      case ReviewCardResult.closedAfterYes:
        return _save(
          s.copyWith(
            nextAt: t.add(afterYesSnooze),
            done: s.cardShows >= maxCardShows,
          ),
        );
      case ReviewCardResult.closed:
        final i = (s.cardShows - 1).clamp(0, cardSnoozes.length - 1);
        return _save(
          s.copyWith(
            nextAt: t.add(cardSnoozes[i]),
            done: s.cardShows >= maxCardShows,
          ),
        );
    }
  }

  /// The open now showing is the last one the card gets.
  bool get isLastCardShow => _state.cardShows >= maxCardShows;

  /// "Rate the app" opened the listing: never ask this device again.
  Future<void> noteRatedManually() =>
      _state.done ? Future.value() : _save(_state.copyWith(done: true));

  /// Debug Panel: start the schedule over.
  Future<void> reset() async {
    _armedAt = null;
    askedThisLaunch = false;
    await _save(const ReviewPromptState());
  }

  static bool _elapsed(DateTime? since, Duration span, DateTime t) {
    if (since == null) return false;
    final d = t.difference(since);
    // A stamp in the future — the clock moved back — counts as elapsed
    // rather than holding for however long the jump was.
    return d.isNegative || d >= span;
  }

  static Date _dateOf(DateTime t) {
    final local = t.toLocal();
    return Date(local.year, local.month, local.day);
  }

  Future<void> _save(ReviewPromptState next) async {
    _state = next;
    notifyListeners();
    await _prefs.write(DevicePrefKeys.reviewPrompt, next.encode());
  }

  /// Re-read the store (its `load`, or a wipe — which keeps this key).
  void _sync() {
    final next = ReviewPromptState.decode(
      _prefs.read(DevicePrefKeys.reviewPrompt),
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

/// The stored schedule — `review_prompt_json`.
@immutable
class ReviewPromptState {
  const ReviewPromptState({
    this.firstSeenAt,
    this.gaFirstSeenAt,
    this.lastDay = '',
    this.daysSeen = 0,
    this.wins = 0,
    this.lastWinAt,
    this.winDays = 0,
    this.lastWinDay = '',
    this.lastProblemAt,
    this.asks = const [],
    this.newerThan = '',
    this.cardShows = 0,
    this.nextAt,
    this.shownAt,
    this.done = false,
  });

  /// The first launch that counted — the install's age.
  final DateTime? firstSeenAt;

  /// The first launch of a build out of beta.
  final DateTime? gaFirstSeenAt;

  /// The last day counted in [daysSeen], `YYYY-MM-DD`.
  final String lastDay;

  /// Distinct calendar days this device was used while signed in.
  final int daysSeen;

  /// Bursts of confirmed wins.
  final int wins;
  final DateTime? lastWinAt;

  /// Distinct days with a win, and the last of them.
  final int winDays;
  final String lastWinDay;

  final DateTime? lastProblemAt;

  /// Native asks in the last year.
  final List<DateTime> asks;

  /// The next ask needs a version newer than this; empty is any.
  final String newerThan;

  /// Times the card has opened on its own.
  final int cardShows;

  /// No ask before this instant.
  final DateTime? nextAt;

  /// The last automatic ask of either kind — holds the promo back.
  final DateTime? shownAt;

  /// Rated, or out of card shows: never ask again.
  final bool done;

  ReviewPromptState copyWith({
    DateTime? firstSeenAt,
    DateTime? gaFirstSeenAt,
    String? lastDay,
    int? daysSeen,
    int? wins,
    DateTime? lastWinAt,
    int? winDays,
    String? lastWinDay,
    DateTime? lastProblemAt,
    List<DateTime>? asks,
    String? newerThan,
    int? cardShows,
    DateTime? nextAt,
    DateTime? shownAt,
    bool? done,
  }) => ReviewPromptState(
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    gaFirstSeenAt: gaFirstSeenAt ?? this.gaFirstSeenAt,
    lastDay: lastDay ?? this.lastDay,
    daysSeen: daysSeen ?? this.daysSeen,
    wins: wins ?? this.wins,
    lastWinAt: lastWinAt ?? this.lastWinAt,
    winDays: winDays ?? this.winDays,
    lastWinDay: lastWinDay ?? this.lastWinDay,
    lastProblemAt: lastProblemAt ?? this.lastProblemAt,
    asks: asks ?? this.asks,
    newerThan: newerThan ?? this.newerThan,
    cardShows: cardShows ?? this.cardShows,
    nextAt: nextAt ?? this.nextAt,
    shownAt: shownAt ?? this.shownAt,
    done: done ?? this.done,
  );

  static int? _ms(DateTime? t) => t?.toUtc().millisecondsSinceEpoch;

  String encode() => jsonEncode({
    if (firstSeenAt != null) 'firstSeenAt': _ms(firstSeenAt),
    if (gaFirstSeenAt != null) 'gaFirstSeenAt': _ms(gaFirstSeenAt),
    'lastDay': lastDay,
    'daysSeen': daysSeen,
    'wins': wins,
    if (lastWinAt != null) 'lastWinAt': _ms(lastWinAt),
    'winDays': winDays,
    'lastWinDay': lastWinDay,
    if (lastProblemAt != null) 'lastProblemAt': _ms(lastProblemAt),
    'asks': [for (final a in asks) _ms(a)],
    'newerThan': newerThan,
    'cardShows': cardShows,
    if (nextAt != null) 'nextAt': _ms(nextAt),
    if (shownAt != null) 'shownAt': _ms(shownAt),
    'done': done,
  });

  /// A missing or unreadable row is a device that has never been counted.
  static ReviewPromptState decode(String? raw) {
    if (raw == null) return const ReviewPromptState();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const ReviewPromptState();
      final asks = json['asks'];
      return ReviewPromptState(
        firstSeenAt: _time(json['firstSeenAt']),
        gaFirstSeenAt: _time(json['gaFirstSeenAt']),
        lastDay: _str(json['lastDay']),
        daysSeen: _int(json['daysSeen']),
        wins: _int(json['wins']),
        lastWinAt: _time(json['lastWinAt']),
        winDays: _int(json['winDays']),
        lastWinDay: _str(json['lastWinDay']),
        lastProblemAt: _time(json['lastProblemAt']),
        asks: asks is List
            ? [
                for (final a in asks)
                  if (_time(a) case final t?) t,
              ]
            : const [],
        newerThan: _str(json['newerThan']),
        cardShows: _int(json['cardShows']),
        nextAt: _time(json['nextAt']),
        shownAt: _time(json['shownAt']),
        done: json['done'] == true,
      );
    } on FormatException {
      return const ReviewPromptState();
    }
  }

  static DateTime? _time(Object? v) =>
      v is int ? DateTime.fromMillisecondsSinceEpoch(v, isUtc: true) : null;
  static int _int(Object? v) => v is int && v >= 0 ? v : 0;
  static String _str(Object? v) => v is String ? v : '';

  @override
  bool operator ==(Object other) =>
      other is ReviewPromptState && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}
