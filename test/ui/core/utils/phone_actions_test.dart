import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;

import 'package:admin/data/models/value/timezone.dart';
import 'package:admin/ui/core/utils/phone_actions.dart';

/// `contactClock` is the whole reason `package:timezone` is a dependency, and
/// the bug it exists to fix is invisible without a *real* tzdb: the fallback
/// path (used by every other test in the suite, which never calls
/// `initializeTimeZones`) reproduces exactly the old wrong behaviour.
void main() {
  // The server seeds standard-time offsets — `ConstantsSeeder` writes
  // `America/New_York` as -18000 and `Europe/London` as 0.
  const newYork = Timezone(
    id: '15',
    name: 'America/New_York',
    location: '(GMT-05:00) Eastern Time (US & Canada)',
    utcOffset: -5 * 3600,
  );
  const london = Timezone(
    id: '38',
    name: 'Europe/London',
    location: '(GMT) London',
    utcOffset: 0,
  );

  // Noon UTC, far from any midnight or transition, on a day each zone is
  // unambiguously in / out of DST.
  final july = DateTime.utc(2026, 7, 15, 12);
  final january = DateTime.utc(2026, 1, 15, 12);

  group('without a tzdb (the fallback)', () {
    test('falls back to the fixed offset rather than throwing', () {
      // `initializeTimeZones` has not run in this group, and an exception
      // inside a build would be far worse than an hour of skew.
      final clock = contactClock(newYork, now: july);
      expect(clock.offset, const Duration(hours: -5));
      expect(clock.local.hour, 7);
    });

    test('an unknown IANA name also falls back', () {
      const bogus = Timezone(
        id: 'x',
        name: 'Not/AZone',
        location: 'nowhere',
        utcOffset: 3600,
      );
      expect(contactClock(bogus, now: july).offset, const Duration(hours: 1));
    });
  });

  group('with the tzdb', () {
    setUpAll(tzdata.initializeTimeZones);

    test('summer resolves the DST offset, not the seeded standard one', () {
      // This is the regression. Seeded -5h; New York is actually on -4h in
      // July, so the old code printed 07:00 for a 08:00 wall clock AND — since
      // `DateTime.now().timeZoneOffset` is DST-aware — decided a New York
      // client was in a different zone from a New York user.
      final clock = contactClock(newYork, now: july);
      expect(clock.offset, const Duration(hours: -4));
      expect(clock.local.hour, 8);
    });

    test('winter matches the seeded standard offset', () {
      final clock = contactClock(newYork, now: january);
      expect(clock.offset, const Duration(hours: -5));
      expect(clock.local.hour, 7);
    });

    test('a zero-offset zone still shifts under DST', () {
      // London is seeded as 0, which is right in January and wrong in July —
      // the case a "non-zero offset means foreign" shortcut would miss.
      expect(contactClock(london, now: january).offset, Duration.zero);
      expect(contactClock(london, now: july).offset, const Duration(hours: 1));
      expect(contactClock(london, now: july).local.hour, 13);
    });
  });

  group('tel: / sms: URIs', () {
    test('build from the normalised number, keeping the +', () {
      expect(telUri('+1 (415) 555-2671').toString(), 'tel:+14155552671');
      expect(smsUri('+1 (415) 555-2671').toString(), 'sms:+14155552671');
    });

    test('are null when there is nothing dialable', () {
      // Callers use the null to render plain text instead of a dead link.
      expect(telUri('call the office'), isNull);
      expect(telUri('1-800-FLOWERS'), isNull);
      expect(smsUri(''), isNull);
    });
  });
}
