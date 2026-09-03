import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/phone/phone_actions_settings.dart';

/// A `DateTime` whose hour/minute are all [PhoneActionsSettings] reads. The
/// date is deliberately fixed and mid-day-UTC-agnostic: this predicate never
/// touches the device zone, so a CI box in UTC and a laptop in UTC+3 agree.
DateTime at(int hour, int minute) => DateTime(2026, 6, 15, hour, minute);

void main() {
  group('isOutsideBusinessHours', () {
    const window = PhoneActionsSettings(tapToCall: true); // 08:00–20:00

    test('inside the window does not warn', () {
      expect(window.isOutsideBusinessHours(at(8, 0)), isFalse);
      expect(window.isOutsideBusinessHours(at(13, 30)), isFalse);
      expect(window.isOutsideBusinessHours(at(19, 59)), isFalse);
    });

    test('outside the window warns, and the end bound is exclusive', () {
      expect(window.isOutsideBusinessHours(at(7, 59)), isTrue);
      expect(window.isOutsideBusinessHours(at(20, 0)), isTrue);
      expect(window.isOutsideBusinessHours(at(23, 47)), isTrue);
      expect(window.isOutsideBusinessHours(at(3, 0)), isTrue);
    });

    test('an empty window (start == end) never warns', () {
      // Dragging the two fields together is a legitimate way to silence the
      // warning without hunting for the switch.
      const empty = PhoneActionsSettings(
        tapToCall: true,
        startMinutes: 9 * 60,
        endMinutes: 9 * 60,
      );
      expect(empty.isOutsideBusinessHours(at(9, 0)), isFalse);
      expect(empty.isOutsideBusinessHours(at(3, 0)), isFalse);
    });

    test('start > end wraps midnight rather than being treated as invalid', () {
      // 22:00–06:00 reads as "these are my hours, warn during the day".
      const overnight = PhoneActionsSettings(
        tapToCall: true,
        startMinutes: 22 * 60,
        endMinutes: 6 * 60,
      );
      expect(overnight.isOutsideBusinessHours(at(23, 0)), isFalse);
      expect(overnight.isOutsideBusinessHours(at(2, 0)), isFalse);
      expect(overnight.isOutsideBusinessHours(at(6, 0)), isTrue);
      expect(overnight.isOutsideBusinessHours(at(12, 0)), isTrue);
      expect(overnight.isOutsideBusinessHours(at(21, 59)), isTrue);
    });
  });

  group('serialization', () {
    test('round-trips every field', () {
      const original = PhoneActionsSettings(
        tapToCall: false,
        confirmBeforeCall: true,
        warnOutsideBusinessHours: false,
        offerToLogCalls: false,
        startMinutes: 9 * 60 + 30,
        endMinutes: 17 * 60 + 45,
      );
      expect(PhoneActionsSettings.fromJson(original.toJson()), original);
    });

    test('a partial blob falls back to the constant defaults', () {
      final restored = PhoneActionsSettings.fromJson({'tapToCall': true});
      expect(restored.tapToCall, isTrue);
      expect(restored.confirmBeforeCall, isFalse);
      expect(restored.warnOutsideBusinessHours, isTrue);
      // A blob written before this field existed must not silently switch the
      // offer off — the blob is taken literally only for keys it *has*.
      expect(restored.offerToLogCalls, isTrue);
      expect(restored.startMinutes, PhoneActionsSettings.defaultStartMinutes);
      expect(restored.endMinutes, PhoneActionsSettings.defaultEndMinutes);
    });

    test('an out-of-range or non-numeric minute falls back', () {
      final restored = PhoneActionsSettings.fromJson({
        'startMinutes': -5,
        'endMinutes': 'nonsense',
      });
      expect(restored.startMinutes, PhoneActionsSettings.defaultStartMinutes);
      expect(restored.endMinutes, PhoneActionsSettings.defaultEndMinutes);
    });
  });

  group('deviceDefaults', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('tap-to-call is on where the primary pointer is a finger', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(PhoneActionsSettings.deviceDefaults().tapToCall, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(PhoneActionsSettings.deviceDefaults().tapToCall, isTrue);
    });

    test('tap-to-call is off on desktop, where there may be no dialer', () {
      // The app can't ask whether a `tel:` handler exists (`canLaunchUrl` is
      // banned), so on by default would mean a number that stops selecting as
      // text and reports "Couldn't open the link" for a user who never asked.
      for (final platform in const [
        TargetPlatform.linux,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          PhoneActionsSettings.deviceDefaults().tapToCall,
          isFalse,
          reason: '$platform should default off',
        );
      }
    });

    test('the guards keep their defaults regardless of platform', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final defaults = PhoneActionsSettings.deviceDefaults();
      // Off: iOS and Android already confirm before a call connects, so this
      // would be a second prompt in front of the OS's own.
      expect(defaults.confirmBeforeCall, isFalse);
      // On: the only guard the OS cannot provide.
      expect(defaults.warnOutsideBusinessHours, isTrue);
      // On: it costs a dismissible toast and nothing else. The *platform* gate
      // lives at the call site (`Env.isMobile`), not here.
      expect(defaults.offerToLogCalls, isTrue);
    });
  });
}
