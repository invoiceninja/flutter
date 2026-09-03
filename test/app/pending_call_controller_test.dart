import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/pending_call_controller.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/phone/pending_call_log.dart';

/// The one-slot holder behind the post-call "Log call?" offer
/// (invoiceninja/flutter#120).
void main() {
  PendingCallLog call({String companyId = 'co', String id = 'c1'}) =>
      PendingCallLog(
        entityType: EntityType.client,
        entityId: id,
        subject: 'Acme Corp',
        companyId: companyId,
        contactLabel: 'Jane Smith',
        phone: '+1 415 555 0123',
      );

  test('take() consumes the slot exactly once', () {
    final c = PendingCallController()..record(call());
    expect(c.take(activeCompanyId: 'co')?.entityId, 'c1');
    expect(c.take(activeCompanyId: 'co'), isNull);
  });

  test(
    'a second call replaces the first — the newer one is what was dialled',
    () {
      final c = PendingCallController()
        ..record(call(id: 'c1'))
        ..record(call(id: 'c2'));
      expect(c.take(activeCompanyId: 'co')?.entityId, 'c2');
    },
  );

  test('a call from another company is dropped, not offered', () {
    // Switching workspaces mid-call must not offer to file a note against a
    // record in the one the user has left.
    final c = PendingCallController()..record(call(companyId: 'other'));
    expect(c.take(activeCompanyId: 'co'), isNull);
    expect(c.value, isNull, reason: 'still consumed — it is stale either way');
  });

  test('no active company drops it too', () {
    final c = PendingCallController()..record(call());
    expect(c.take(activeCompanyId: null), isNull);
  });

  test('clear() empties the slot (the logout path)', () {
    final c = PendingCallController()..record(call());
    c.clear();
    expect(c.value, isNull);
  });

  test('displayName prefers the contact, then the number, then the record', () {
    expect(call().displayName, 'Jane Smith');
    expect(
      const PendingCallLog(
        entityType: EntityType.vendor,
        entityId: 'v1',
        subject: 'Globex',
        companyId: 'co',
        contactLabel: '  ',
        phone: '+44 20 7946 0000',
      ).displayName,
      '+44 20 7946 0000',
    );
    expect(
      const PendingCallLog(
        entityType: EntityType.vendor,
        entityId: 'v1',
        subject: 'Globex',
        companyId: 'co',
        contactLabel: '',
        phone: '',
      ).displayName,
      'Globex',
    );
  });
}
