import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectivityWatcher.fixed', () {
    test('isOnline reflects the construction arg', () async {
      expect(await ConnectivityWatcher.fixed(online: true).isOnline, isTrue);
      expect(await ConnectivityWatcher.fixed(online: false).isOnline, isFalse);
    });

    test('onOnline emits nothing — the fake never transitions', () async {
      // A 50ms window is plenty for `Stream.empty()` to deliver a `done`
      // event; we just want to confirm no value events ever arrive.
      final events = <void>[];
      final sub = ConnectivityWatcher.fixed(
        online: true,
      ).onOnline.listen(events.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(events, isEmpty);
    });

    test(
      'isOnlineStream emits the construction value so the OfflineBanner '
      'can paint immediately on app start without waiting for a transition',
      () async {
        final emissions = <bool>[];
        final sub = ConnectivityWatcher.fixed(
          online: false,
        ).isOnlineStream.listen(emissions.add);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await sub.cancel();
        expect(emissions, [false]);
      },
    );
  });

  // Simulates the shipped Snap/AppArmor case: the `connectivity_plus` probe
  // reaches NetworkManager over D-Bus and is denied, so it throws. Connectivity
  // detection must degrade to "assume online" rather than break the caller
  // (the reported "Could not save" bug). Streams are finite here so `toList()`
  // makes the assertions deterministic (no timing waits).
  group('ConnectivityWatcher.liveWith — blocked probe degrades gracefully', () {
    ConnectivityWatcher blocked() => ConnectivityWatcher.liveWith(
      check: () async => throw Exception('AppArmor blocked NetworkManager'),
      changes: () => const Stream<List<ConnectivityResult>>.empty(),
    );

    test('isOnline assumes online instead of throwing', () async {
      expect(await blocked().isOnline, isTrue);
    });

    test('onOnline stays inert — no emissions, no error', () async {
      expect(await blocked().onOnline.toList(), isEmpty);
    });

    test('isOnlineStream emits a single true then completes', () async {
      expect(await blocked().isOnlineStream.toList(), [true]);
    });
  });

  // Guards that probe-then-subscribe didn't break real detection where the
  // probe succeeds (every non-Linux platform, and Linux with the
  // `network-manager` interface connected).
  group('ConnectivityWatcher.liveWith — real detection still works', () {
    test('isOnline reflects the probe result', () async {
      expect(
        await ConnectivityWatcher.liveWith(
          check: () async => [ConnectivityResult.wifi],
          changes: () => const Stream<List<ConnectivityResult>>.empty(),
        ).isOnline,
        isTrue,
      );
      expect(
        await ConnectivityWatcher.liveWith(
          check: () async => [ConnectivityResult.none],
          changes: () => const Stream<List<ConnectivityResult>>.empty(),
        ).isOnline,
        isFalse,
      );
    });

    test('onOnline fires on each offline→online transition only', () async {
      final watcher = ConnectivityWatcher.liveWith(
        check: () async => [ConnectivityResult.none],
        changes: () => Stream.fromIterable([
          [ConnectivityResult.none], // offline — no fire
          [ConnectivityResult.wifi], // -> online — fire
          [ConnectivityResult.ethernet], // stays online — no fire
          [ConnectivityResult.none], // -> offline — no fire
          [ConnectivityResult.wifi], // -> online — fire
        ]),
      );
      expect(await watcher.onOnline.toList(), hasLength(2));
    });

    test('isOnlineStream emits the seed then each state change', () async {
      final watcher = ConnectivityWatcher.liveWith(
        check: () async => [ConnectivityResult.wifi], // seed: online
        changes: () => Stream.fromIterable([
          [ConnectivityResult.wifi], // no change (already online)
          [ConnectivityResult.none], // -> offline
          [ConnectivityResult.none], // no change
          [ConnectivityResult.ethernet], // -> online
        ]),
      );
      expect(await watcher.isOnlineStream.toList(), [true, false, true]);
    });
  });

  // After a healthy probe, an error delivered *through* the change stream must
  // not reach consumers. The probe gate only covers the plugin's onListen-throw
  // case; these cover an error that arrives mid-stream.
  group('ConnectivityWatcher.liveWith — mid-stream errors are contained', () {
    test('onOnline swallows a change-stream error (no throw)', () async {
      final watcher = ConnectivityWatcher.liveWith(
        check: () async => [ConnectivityResult.wifi], // probe healthy
        changes: () => Stream<List<ConnectivityResult>>.error(
          Exception('NetworkManager dropped'),
        ),
      );
      expect(await watcher.onOnline.toList(), isEmpty);
    });

    test(
      'isOnlineStream keeps the seed when the change stream errors',
      () async {
        final watcher = ConnectivityWatcher.liveWith(
          check: () async => [ConnectivityResult.wifi], // seed: online
          changes: () => Stream<List<ConnectivityResult>>.error(
            Exception('NetworkManager dropped'),
          ),
        );
        expect(await watcher.isOnlineStream.toList(), [true]);
      },
    );
  });
}
