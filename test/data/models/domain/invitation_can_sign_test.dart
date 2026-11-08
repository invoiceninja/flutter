import 'package:admin/data/models/api/invitation_api_model.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:flutter_test/flutter_test.dart';

/// `can_sign` is tri-state, and the save request's `key` rides only with it:
/// on a DocuNinja company the server applies a matched `key` as
/// `can_sign ?? false`, so a `key` alone would move the signer
/// (docs/contacts-and-invitations.md).
void main() {
  group('toApiJson', () {
    test('an unknown can_sign sends neither key nor can_sign', () {
      const i = Invitation(id: 'i', key: 'k', clientContactId: 'c');
      expect(i.toApiJson(), {'id': 'i', 'client_contact_id': 'c'});
    });

    test('a known can_sign sends it with the key', () {
      const i = Invitation(
        id: 'i',
        key: 'k',
        clientContactId: 'c',
        canSign: false,
      );
      expect(i.toApiJson(), {
        'id': 'i',
        'key': 'k',
        'client_contact_id': 'c',
        'can_sign': false,
      });
    });

    test('a new invitation sends can_sign without a key', () {
      const i = Invitation(clientContactId: 'c', canSign: true);
      expect(i.toApiJson(), {'client_contact_id': 'c', 'can_sign': true});
    });
  });

  group('the stored row', () {
    test('round-trips every field through toPayloadJson', () {
      const i = Invitation(
        id: 'i',
        key: 'k',
        link: 'l',
        clientContactId: 'c',
        sentDate: 's',
        viewedDate: 'v',
        openedDate: 'o',
        emailStatus: 'bounced',
        emailError: 'e',
        messageId: 'm',
        canSign: true,
      );
      expect(Invitation.fromApi(InvitationApi.fromJson(i.toPayloadJson())), i);
    });

    test('a row stored before can_sign existed reads it as unknown', () {
      final api = InvitationApi.fromJson({'id': 'i', 'key': 'k'});
      expect(Invitation.fromApi(api).canSign, isNull);
      expect(api.toJson().containsKey('can_sign'), isFalse);
    });

    test('reads can_sign however the server casts it', () {
      expect(InvitationApi.fromJson({'can_sign': 1}).canSign, isTrue);
      expect(InvitationApi.fromJson({'can_sign': false}).canSign, isFalse);
    });
  });

  test('a clone forgets can_sign, like every other per-send field', () {
    const i = Invitation(
      id: 'i',
      key: 'k',
      clientContactId: 'c',
      canSign: true,
    );
    expect(i.freshClone().canSign, isNull);
  });
}
