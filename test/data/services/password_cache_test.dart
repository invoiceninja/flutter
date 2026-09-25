import 'package:admin/data/services/password_cache.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordCache TTL', () {
    test('read returns the password until the TTL expires', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final cache = PasswordCache(
        ttl: const Duration(minutes: 5),
        now: () => now,
      );
      cache.set('hunter2');
      expect(cache.read(), 'hunter2');

      now = now.add(const Duration(minutes: 4, seconds: 59));
      expect(cache.read(), 'hunter2');

      now = now.add(const Duration(seconds: 2));
      expect(cache.read(), isNull);
    });

    test('clear wipes the password immediately', () {
      final cache = PasswordCache()..set('hunter2');
      expect(cache.read(), 'hunter2');
      cache.clear();
      expect(cache.read(), isNull);
    });
  });

  group('PasswordCache OAuth token', () {
    test('a password and an OAuth token are exclusive — last set wins', () {
      final cache = PasswordCache()..set('hunter2');
      cache.setOAuthToken('apple.jwt');
      expect(cache.read(), isNull);
      expect(cache.readOAuthToken(), 'apple.jwt');
      cache.set('hunter2');
      expect(cache.readOAuthToken(), isNull);
      expect(cache.read(), 'hunter2');
    });

    test('the OAuth token expires and clears like a password', () {
      var now = DateTime(2026, 1, 1, 12);
      final cache = PasswordCache(now: () => now)..setOAuthToken('jwt');
      now = now.add(const Duration(minutes: 6));
      expect(cache.readOAuthToken(), isNull);
      cache
        ..setOAuthToken('jwt')
        ..clear();
      expect(cache.readOAuthToken(), isNull);
    });
  });

  group('PasswordSubject / isExempt — mirrors PasswordProtection', () {
    PasswordCache cacheFor(PasswordSubject? subject) =>
        PasswordCache()..subject = () => subject;

    PasswordSubject subject({
      String provider = '',
      bool hasPassword = true,
      bool required = false,
    }) => PasswordSubject(
      oauthProvider: provider,
      hasPassword: hasPassword,
      oauthPasswordRequired: required,
    );

    test('an OAuth user is exempt while the company leaves it off', () {
      final cache = cacheFor(subject(provider: 'google', hasPassword: false));
      expect(cache.isExempt, isTrue);
      expect(cache.isPrimed, isTrue);
    });

    test('never exempt once the company requires a password', () {
      expect(
        cacheFor(subject(provider: 'google', required: true)).isExempt,
        isFalse,
      );
    });

    test('an email/password user is never exempt', () {
      expect(cacheFor(subject()).isExempt, isFalse);
      expect(cacheFor(subject()).isPrimed, isFalse);
    });

    test('no subject (tests, signed out) keeps today\'s ask', () {
      expect(cacheFor(null).isExempt, isFalse);
      expect(PasswordCache().isExempt, isFalse);
    });

    test('a one- or two-letter provider is not OAuth (server: strlen > 2)', () {
      expect(cacheFor(subject(provider: 'x')).isExempt, isFalse);
    });

    test('isPrimed is true once any credential is cached', () {
      final cache = cacheFor(subject());
      expect(cache.isPrimed, isFalse);
      cache.setOAuthToken('jwt');
      expect(cache.isPrimed, isTrue);
    });
  });

  group('PasswordCacheLifecycleObserver', () {
    test('paused clears the cache', () {
      // Regression for H5: backgrounding the app should not leave the user's
      // password recoverable in memory for the full TTL.
      final cache = PasswordCache()..set('hunter2');
      final observer = PasswordCacheLifecycleObserver(cache);

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(cache.read(), isNull);
    });

    test('detached clears the cache', () {
      final cache = PasswordCache()..set('hunter2');
      final observer = PasswordCacheLifecycleObserver(cache);

      observer.didChangeAppLifecycleState(AppLifecycleState.detached);
      expect(cache.read(), isNull);
    });

    test('inactive and resumed leave the cache untouched', () {
      // iOS fires `inactive` for transient events (notification center pull,
      // incoming call UI) — clearing there would force constant re-prompts.
      final cache = PasswordCache()..set('hunter2');
      final observer = PasswordCacheLifecycleObserver(cache);

      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(cache.read(), 'hunter2');

      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(cache.read(), 'hunter2');
    });
  });
}
