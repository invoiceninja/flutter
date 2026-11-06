import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/review_prompt_controller.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/review_prompt.dart';
import 'package:admin/domain/sync/landed_mutation.dart';

/// The review prompt's schedule (docs/review-prompt.md): nothing during the
/// beta, never in the first week, only after real use and confirmed wins,
/// only at a moment, and never more often than the cadence allows.
AuthSession _session({String baseUrl = 'https://invoicing.co'}) => AuthSession(
  baseUrl: baseUrl,
  isHosted: true,
  accountId: 'acct',
  companies: [
    AuthCompany(
      id: 'co',
      name: 'Co',
      displayName: 'Co',
      permissions: '',
      isAdmin: true,
      isOwner: true,
      enabledModules: 0x7fffffff,
    ),
  ],
  currentCompanyId: 'co',
  userEmail: 'me@example.com',
);

void main() {
  // Mid-day UTC, so the same calendar day from UTC−11 to UTC+10 (CLAUDE.md
  // § Strict rules — CI runs in UTC).
  final start = DateTime.utc(2026, 11, 2, 12);

  late DevicePrefsStore prefs;
  late DateTime now;

  setUp(() {
    prefs = DevicePrefsStore(null);
    now = start;
  });

  ReviewPromptController controller({
    bool isBeta = false,
    ReviewChannel channel = ReviewChannel.capterra,
    String version = '5.2.0',
    bool Function(DateTime)? promoShownRecently,
  }) {
    final c = ReviewPromptController(
      prefs: prefs,
      autoAsk: true,
      isBeta: isBeta,
      channel: channel,
      version: version,
      promoShownRecently: promoShownRecently,
      clock: () => now,
    );
    addTearDown(c.dispose);
    return c;
  }

  LandedMutation emailed({Duration age = const Duration(seconds: 5)}) =>
      LandedMutation(
        entityType: 'invoice',
        mutationKind: 'email_entity',
        rowCreatedAt: now.subtract(age),
      );

  LandedMutation created() => LandedMutation(
    entityType: 'invoice',
    mutationKind: 'create',
    rowCreatedAt: now,
  );

  Date today() => Date(now.year, now.month, now.day);

  /// A device that has met every gate but the moment: installed 7+ days ago,
  /// used on 5 days, with 3 bursts of wins across 2+ days.
  Future<void> establish(ReviewPromptController c) async {
    for (var i = 0; i < 5; i++) {
      await c.recordUseDay(today());
      if (i < 3) await c.noteWin(created());
      now = now.add(const Duration(days: 1));
    }
    now = now.add(const Duration(days: 3));
  }

  const clear = (attention: 0, online: true);
  bool due(ReviewPromptController c) =>
      c.isDue(attentionCount: clear.attention, online: clear.online);

  test('an established device is due right after a finishing win', () async {
    final c = controller();
    await establish(c);
    expect(due(c), isFalse, reason: 'no moment yet');
    expect(await c.noteWin(emailed()), isTrue);
    expect(due(c), isTrue);
  });

  group('beta', () {
    test('nothing is ever due, but the counters still run', () async {
      final c = controller(isBeta: true);
      await establish(c);
      await c.noteWin(emailed());
      expect(due(c), isFalse);
      // The five days, plus the day of the last win.
      expect(c.state.daysSeen, 6);
      expect(c.state.wins, 4);
      expect(c.state.firstSeenAt, isNotNull);
      expect(c.state.gaFirstSeenAt, isNull);
      expect(c.offersManualRatingTo(_session()), isFalse);
    });

    test('the first GA build waits three days, then the beta counts', () async {
      final beta = controller(isBeta: true);
      await establish(beta);
      final ga = controller();
      await ga.recordUseDay(today());
      expect(ga.state.gaFirstSeenAt, now);
      await ga.noteWin(emailed());
      expect(due(ga), isFalse, reason: 'GA build is brand new');
      now = now.add(const Duration(days: 3));
      await ga.noteWin(emailed());
      expect(due(ga), isTrue);
    });
  });

  group('each gate on its own', () {
    test('install age: not in the first week', () async {
      final c = controller();
      for (var i = 0; i < 5; i++) {
        await c.recordUseDay(Date(2026, 11, 2 + i));
      }
      for (var i = 0; i < 3; i++) {
        now = start.add(Duration(days: i));
        await c.noteWin(created());
      }
      now = start.add(const Duration(days: 6, hours: 23));
      await c.noteWin(emailed());
      expect(due(c), isFalse);
      now = start.add(const Duration(days: 7));
      await c.noteWin(emailed());
      expect(due(c), isTrue);
    });

    test('days of use: five, counted once per day', () async {
      final c = controller();
      await c.recordUseDay(today());
      await c.recordUseDay(today());
      expect(c.state.daysSeen, 1);
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(days: 1));
        await c.noteWin(created());
      }
      now = now.add(const Duration(days: 5));
      await c.noteWin(emailed());
      // Days 1–4 and today: a win records its day too.
      expect(c.state.daysSeen, 5);
      expect(due(c), isTrue);
    });

    test('wins: a burst is one, and they must span two days', () async {
      final c = controller();
      for (var i = 0; i < 5; i++) {
        await c.recordUseDay(Date(2026, 11, 2 + i));
      }
      // Twenty invoices emailed in one go.
      for (var i = 0; i < 20; i++) {
        now = start.add(Duration(seconds: i * 10));
        await c.noteWin(emailed());
      }
      expect(c.state.wins, 1);
      // Three bursts, but all on one day.
      now = start.add(const Duration(hours: 1));
      await c.noteWin(created());
      now = start.add(const Duration(hours: 2));
      await c.noteWin(created());
      expect(c.state.wins, 3);
      expect(c.state.winDays, 1);
      now = start.add(const Duration(days: 8));
      await c.noteWin(emailed());
      expect(c.state.winDays, 2);
      expect(due(c), isTrue);
    });

    test('the moment: a fresh finishing win, for a minute', () async {
      final c = controller();
      await establish(c);
      expect(await c.noteWin(created()), isFalse, reason: 'only counts');
      expect(due(c), isFalse);
      expect(
        await c.noteWin(emailed(age: const Duration(minutes: 11))),
        isFalse,
        reason: "yesterday's offline edit landing after a reconnect",
      );
      expect(due(c), isFalse);
      expect(await c.noteWin(emailed()), isTrue);
      now = now.add(const Duration(seconds: 61));
      expect(due(c), isFalse);
    });

    test('a write that reached the server sideways never arms', () async {
      final c = controller();
      await establish(c);
      final m = LandedMutation(
        entityType: 'invoice',
        mutationKind: 'email_entity',
        rowCreatedAt: now,
        committedSettle: true,
      );
      expect(await c.noteWin(m), isFalse);
      expect(due(c), isFalse);
    });

    test('a problem holds asks for three days and disarms', () async {
      final c = controller();
      await establish(c);
      await c.noteWin(emailed());
      await c.noteProblem();
      expect(due(c), isFalse);
      now = now.add(const Duration(days: 2));
      await c.noteWin(emailed());
      expect(due(c), isFalse);
      now = now.add(const Duration(days: 1));
      await c.noteWin(emailed());
      expect(due(c), isTrue);
    });

    test('the outbox needing attention, or offline, holds it', () async {
      final c = controller();
      await establish(c);
      await c.noteWin(emailed());
      expect(c.isDue(attentionCount: 1, online: true), isFalse);
      expect(c.isDue(attentionCount: 0, online: false), isFalse);
      expect(c.isDue(attentionCount: 0, online: true), isTrue);
    });

    test('the mobile-app promo shown lately holds it', () async {
      var promo = true;
      final c = controller(promoShownRecently: (_) => promo);
      await establish(c);
      await c.noteWin(emailed());
      expect(due(c), isFalse);
      promo = false;
      expect(due(c), isTrue);
    });

    test('the demo never asks', () async {
      final c = controller(channel: ReviewChannel.none);
      await establish(c);
      await c.noteWin(emailed());
      expect(due(c), isFalse);
      expect(c.offersManualRatingTo(_session()), isFalse);
    });
  });

  group('native cadence', () {
    test('120 days apart, on a newer version, three a year', () async {
      var c = controller(channel: ReviewChannel.playStore);
      await establish(c);
      await c.noteWin(emailed());
      expect(due(c), isTrue);
      await c.noteNativeAsk();
      expect(due(c), isFalse, reason: 'disarmed');
      expect(c.holdsBackPromptsAt(now), isTrue);
      expect(c.holdsBackPromptsAt(now.add(const Duration(days: 7))), isFalse);

      now = now.add(const Duration(days: 121));
      await c.noteWin(emailed());
      expect(due(c), isFalse, reason: 'same version');

      c = controller(channel: ReviewChannel.playStore, version: '5.3.0');
      await c.noteWin(emailed());
      expect(due(c), isTrue);
      await c.noteNativeAsk();

      now = now.add(const Duration(days: 121));
      c = controller(channel: ReviewChannel.playStore, version: '5.4.0');
      await c.noteWin(emailed());
      expect(due(c), isTrue);
      await c.noteNativeAsk();
      expect(c.state.asks, hasLength(3));

      // A fourth inside the same year: Apple's own cap, kept as ours.
      now = now.add(const Duration(days: 121));
      c = controller(channel: ReviewChannel.playStore, version: '5.5.0');
      await c.noteWin(emailed());
      expect(due(c), isFalse);
      now = now.add(const Duration(days: 2));
      await c.noteWin(emailed());
      expect(due(c), isTrue, reason: 'the first ask has rolled off');
    });
  });

  group('card cadence', () {
    Future<ReviewPromptController> shown() async {
      final c = controller();
      await establish(c);
      await c.noteWin(emailed());
      expect(due(c), isTrue);
      await c.noteCardShown();
      return c;
    }

    Future<bool> dueAfter(ReviewPromptController c, Duration d) async {
      now = now.add(d);
      await c.noteWin(emailed());
      return due(c);
    }

    test('closing snoozes 30 days, then 90, then stops', () async {
      final c = await shown();
      await c.noteCardResult(ReviewCardResult.closed);
      expect(await dueAfter(c, const Duration(days: 29)), isFalse);
      expect(await dueAfter(c, const Duration(days: 1)), isTrue);
      await c.noteCardShown();
      await c.noteCardResult(ReviewCardResult.closed);
      expect(await dueAfter(c, const Duration(days: 89)), isFalse);
      expect(await dueAfter(c, const Duration(days: 1)), isTrue);
      await c.noteCardShown();
      expect(c.isLastCardShow, isTrue);
      await c.noteCardResult(ReviewCardResult.closed);
      expect(c.state.done, isTrue);
      expect(await dueAfter(c, const Duration(days: 400)), isFalse);
    });

    test('closing after Yes waits 90 days', () async {
      final c = await shown();
      await c.noteCardResult(ReviewCardResult.closedAfterYes);
      expect(await dueAfter(c, const Duration(days: 89)), isFalse);
      expect(await dueAfter(c, const Duration(days: 1)), isTrue);
    });

    test('an unhappy answer waits 180 days and a newer version', () async {
      for (final result in [
        ReviewCardResult.unhappy,
        ReviewCardResult.sendFeedback,
      ]) {
        prefs = DevicePrefsStore(null);
        now = start;
        final c = await shown();
        await c.noteCardResult(result);
        expect(
          await dueAfter(c, const Duration(days: 35)),
          isFalse,
          reason: '$result: not the 30-day snooze',
        );
        expect(await dueAfter(c, const Duration(days: 150)), isFalse);
        final newer = controller(version: '5.3.0');
        await newer.noteWin(emailed());
        expect(due(newer), isTrue, reason: '$result');
      }
    });

    test('rating ends it for good', () async {
      final c = await shown();
      await c.noteCardResult(ReviewCardResult.rated);
      expect(c.state.done, isTrue);
      expect(await dueAfter(c, const Duration(days: 400)), isFalse);
    });

    test('a manual rating ends the automatic asks too', () async {
      final c = controller();
      await establish(c);
      await c.noteRatedManually();
      await c.noteWin(emailed());
      expect(due(c), isFalse);
    });
  });

  group('the manual "Rate the app" entry', () {
    test('shows out of beta where there is a page to open', () {
      expect(controller().offersManualRatingTo(_session()), isTrue);
      expect(
        controller(isBeta: true).offersManualRatingTo(_session()),
        isFalse,
      );
      expect(
        controller(
          channel: ReviewChannel.appleStore,
        ).offersManualRatingTo(_session()),
        isFalse,
        reason: 'no App Store id yet',
      );
      expect(controller().offersManualRatingTo(null), isFalse);
    });

    test('never to someone signed into the demo server', () {
      expect(
        controller().offersManualRatingTo(
          _session(baseUrl: 'https://demo.invoiceninja.com'),
        ),
        isFalse,
      );
    });
  });

  test('the schedule survives a round trip through the store', () async {
    final c = controller();
    await establish(c);
    await c.noteNativeAsk();
    await c.noteProblem();
    final raw = prefs.read(DevicePrefKeys.reviewPrompt);
    expect(ReviewPromptState.decode(raw), c.state);
    final again = controller();
    expect(again.state, c.state);
    expect(again.state.asks, hasLength(1));
  });

  test('an unreadable row decodes to a device never counted', () {
    expect(ReviewPromptState.decode('nope'), const ReviewPromptState());
    expect(ReviewPromptState.decode('[1]'), const ReviewPromptState());
    expect(ReviewPromptState.decode(null), const ReviewPromptState());
  });

  test('reset starts over', () async {
    final c = controller();
    await establish(c);
    await c.reset();
    expect(c.state, const ReviewPromptState());
  });
}
