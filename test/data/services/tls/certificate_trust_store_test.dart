import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/services/tls/certificate_facts.dart';
import 'package:admin/data/services/tls/certificate_trust_store.dart';

CertificateFacts _facts(String hexByte, {String cn = 'pay.example.com'}) =>
    CertificateFacts(
      sha256: hexByte * 32,
      subject: '/CN=$cn',
      issuer: '/CN=$cn',
      notBefore: DateTime.utc(2026, 1, 1, 12),
      notAfter: DateTime.utc(2027, 1, 1, 12),
      subjectAltNames: [cn],
    );

final _a = _facts('aa');
final _b = _facts('bb');

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// A relaunch: a new store, loaded from the same database.
  Future<CertificateTrustStore> relaunch() async {
    final prefs = DevicePrefsStore(db);
    await prefs.load();
    return CertificateTrustStore(prefs: prefs);
  }

  group('pins', () {
    test('a trust is exactly one certificate for one host:port', () async {
      final store = await relaunch();
      expect(await store.trust('Pay.Example.com.', 443, _a), isTrue);

      expect(store.isTrusted('pay.example.com', 443, _a.sha256), isTrue);
      expect(store.isTrusted('pay.example.com', 443, _b.sha256), isFalse);
      expect(store.isTrusted('pay.example.com', 8443, _a.sha256), isFalse);
      expect(store.isTrusted('other.example.com', 443, _a.sha256), isFalse);
    });

    test('survives a relaunch', () async {
      await (await relaunch()).trust('pay.example.com', 443, _a);
      final again = await relaunch();
      expect(again.isTrusted('pay.example.com', 443, _a.sha256), isTrue);
      expect(again.pins.single.facts.subjectAltNames, ['pay.example.com']);
    });

    test(
      'trusting another certificate replaces the pin for that server',
      () async {
        final store = await relaunch();
        await store.trust('pay.example.com', 443, _a);
        await store.trust('pay.example.com', 443, _b);
        await store.trust('other.example.com', 443, _a);
        expect(store.pins, hasLength(2));
        expect(store.isTrusted('pay.example.com', 443, _a.sha256), isFalse);
        expect(store.isTrusted('pay.example.com', 443, _b.sha256), isTrue);
        expect(store.pinFor('pay.example.com', 443)?.facts, _b);
      },
    );

    test('revoke forgets the pin, on disk too', () async {
      final store = await relaunch();
      await store.trust('pay.example.com', 443, _a);
      await store.revoke('pay.example.com', 443);
      expect(store.pins, isEmpty);
      expect((await relaunch()).pins, isEmpty);
    });

    test('the hosted service is never trusted, even from a stored row', () async {
      final store = await relaunch();
      expect(await store.trust('invoicing.co', 443, _a), isFalse);
      expect(await store.trust('app.invoicing.co', 443, _a), isFalse);
      expect(store.pins, isEmpty);

      final prefs = DevicePrefsStore(db);
      await prefs.load();
      await prefs.write(
        DevicePrefKeys.trustedCertificates,
        '[${'{"host":"invoicing.co","port":443,${_jsonFacts(_a)},"trusted_at":"2026-10-17T12:00:00.000Z"}'}]',
      );
      final tampered = CertificateTrustStore(prefs: prefs);
      expect(tampered.pins, hasLength(1));
      expect(tampered.isTrusted('invoicing.co', 443, _a.sha256), isFalse);
    });

    test('a corrupt blob trusts nothing; a bad entry is skipped', () async {
      final prefs = DevicePrefsStore(db);
      await prefs.load();
      await prefs.write(DevicePrefKeys.trustedCertificates, '{not json');
      expect(CertificateTrustStore(prefs: prefs).pins, isEmpty);

      await prefs.write(
        DevicePrefKeys.trustedCertificates,
        '[{"host":"bad"},'
        '{"host":"pay.example.com","port":443,${_jsonFacts(_a)},"trusted_at":"2026-10-17T12:00:00.000Z"}]',
      );
      final store = CertificateTrustStore(prefs: prefs);
      expect(store.pins.single.host, 'pay.example.com');
    });

    test('a sign-out keeps the pins (device scope)', () async {
      final prefs = DevicePrefsStore(db);
      await prefs.load();
      final store = CertificateTrustStore(prefs: prefs);
      await store.trust('pay.example.com', 443, _a);
      prefs.forgetWiped();
      expect(store.isTrusted('pay.example.com', 443, _a.sha256), isTrue);
    });
  });

  group('rejections', () {
    test('nothing is recorded before the preferences have loaded', () async {
      final prefs = DevicePrefsStore(db);
      final store = CertificateTrustStore(prefs: prefs);
      store.recordRejection('pay.example.com', 443, _a);
      expect(store.rejectionSerial, 0);
      expect(store.outstandingFor('pay.example.com', 443), isNull);

      await prefs.load();
      store.recordRejection('pay.example.com', 443, _a);
      expect(store.rejectionSerial, 1);
    });

    test('a ticket never blames an earlier rejection', () async {
      final store = await relaunch();
      store.recordRejection('pay.example.com', 443, _a);
      final ticket = store.rejectionSerial;
      expect(
        store.rejectionAfter(ticket, host: 'pay.example.com', port: 443),
        isNull,
      );
      store.recordRejection('pay.example.com', 443, _b);
      expect(
        store.rejectionAfter(ticket, host: 'pay.example.com', port: 443)?.facts,
        _b,
      );
    });

    test('a redirected request is matched to the one host refused', () async {
      final store = await relaunch();
      final ticket = store.rejectionSerial;
      store.recordRejection('www.pay.example.com', 443, _a);
      final found = store.rejectionAfter(
        ticket,
        host: 'pay.example.com',
        port: 443,
      );
      expect(found?.host, 'www.pay.example.com');

      // Two other hosts refused since: neither can be pinned on it.
      store.recordRejection('cdn.example.com', 443, _b);
      expect(
        store.rejectionAfter(ticket, host: 'pay.example.com', port: 443),
        isNull,
      );
    });

    test('outstanding until the server answers, a trust or a revoke', () async {
      final store = await relaunch();
      var notified = 0;
      store.addListener(() => notified++);

      store.recordRejection('pay.example.com', 443, _a);
      expect(store.outstandingFor('pay.example.com', 443)?.facts, _a);
      // Listeners hear on the next microtask, never inside the handshake.
      expect(notified, 0);
      await Future<void>.delayed(Duration.zero);
      expect(notified, 1);

      // The same refusal again is no news.
      store.recordRejection('pay.example.com', 443, _a);
      await Future<void>.delayed(Duration.zero);
      expect(notified, 1);

      store.noteReached('other.example.com', 443);
      expect(store.outstandingFor('pay.example.com', 443), isNotNull);
      store.noteReached('pay.example.com', 443);
      expect(store.outstandingFor('pay.example.com', 443), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(notified, 2);

      store.recordRejection('pay.example.com', 443, _a);
      await store.trust('pay.example.com', 443, _a);
      expect(store.outstandingFor('pay.example.com', 443), isNull);
    });
  });
}

String _jsonFacts(CertificateFacts f) =>
    '"sha256":"${f.sha256}","subject":"${f.subject}","issuer":"${f.issuer}",'
    '"not_before":"${f.notBefore.toIso8601String()}",'
    '"not_after":"${f.notAfter.toIso8601String()}"';
