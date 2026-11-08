import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/domain/docuninja/docuninja_send_rules.dart';
import 'package:flutter_test/flutter_test.dart';

DnDocument _doc(DnDocumentStatus status, {bool deleted = false}) =>
    DnDocument.fromJson({
      'id': 'd',
      'status_id': status.id,
      'is_deleted': deleted,
    });

/// React's `useIsSendable` and the detail page's action gates.
void main() {
  bool sendable(
    DnDocumentStatus status, {
    bool admin = false,
    bool approval = false,
    bool edit = false,
    bool create = false,
    bool owner = false,
  }) => dnIsSendable(
    document: _doc(status),
    isAdminOrOwner: admin,
    requiresApproval: approval,
    canEdit: edit,
    canCreate: create,
    isDocumentOwner: owner,
  );

  test('an admin sends from draft, pending, approved and sent only', () {
    for (final s in DnDocumentStatus.values) {
      expect(
        sendable(s, admin: true),
        kDnSendableStatuses.contains(s),
        reason: '$s',
      );
    }
  });

  test('an editor sends unless approval is required', () {
    expect(sendable(DnDocumentStatus.draft, edit: true), isTrue);
    expect(
      sendable(DnDocumentStatus.draft, edit: true, approval: true),
      isFalse,
    );
    // Once approved, the approval permission is enough.
    expect(sendable(DnDocumentStatus.approved, approval: true), isTrue);
  });

  test('a creator sends only their own document', () {
    expect(sendable(DnDocumentStatus.draft, create: true), isFalse);
    expect(sendable(DnDocumentStatus.draft, create: true, owner: true), isTrue);
  });

  test('void is for a sent document; download for a completed one', () {
    expect(dnCanVoid(_doc(DnDocumentStatus.sent)), isTrue);
    expect(dnCanVoid(_doc(DnDocumentStatus.completed)), isFalse);
    expect(dnCanVoid(_doc(DnDocumentStatus.sent, deleted: true)), isFalse);
    expect(dnIsCompleted(_doc(DnDocumentStatus.completed)), isTrue);
    expect(dnCanSetExpiry(_doc(DnDocumentStatus.sent)), isTrue);
    expect(dnCanSetExpiry(_doc(DnDocumentStatus.completed)), isFalse);
  });

  group('resend', () {
    DnDocument withSigners(
      List<Map<String, dynamic>> invitations, {
      DnDocumentStatus status = DnDocumentStatus.sent,
    }) => DnDocument.fromJson({
      'id': 'd',
      'status_id': status.id,
      'invitations': invitations,
    });

    test('is hidden once the document is completed, voided or deleted', () {
      expect(dnShowsResend(_doc(DnDocumentStatus.sent)), isTrue);
      expect(dnShowsResend(_doc(DnDocumentStatus.draft)), isTrue);
      expect(dnShowsResend(_doc(DnDocumentStatus.completed)), isFalse);
      expect(dnShowsResend(_doc(DnDocumentStatus.voided)), isFalse);
      expect(
        dnShowsResend(_doc(DnDocumentStatus.sent, deleted: true)),
        isFalse,
      );
    });

    test('without a signing order, every signer may be emailed', () {
      final d = withSigners([
        {'id': 'a'},
        {'id': 'b', 'signed_date': '2026-11-01'},
      ]);
      expect(d.invitations.every((i) => dnCanResend(d, i)), isTrue);
    });

    test('with a signing order, only the next unsigned signer', () {
      final d = withSigners([
        {'id': 'a', 'signing_order': 1, 'signed_date': '2026-11-01'},
        {'id': 'c', 'signing_order': 3},
        {'id': 'b', 'signing_order': 2},
      ]);
      final enabled = [
        for (final i in d.invitations)
          if (dnCanResend(d, i)) i.id,
      ];
      expect(enabled, ['b']);
    });
  });

  group('own invitation', () {
    DnDocument doc({int status = 5, List<Map<String, dynamic>>? invitations}) =>
        DnDocument.fromJson({
          'id': 'd',
          'status_id': status,
          'invitations':
              invitations ??
              [
                {'id': 'c1', 'client_contact_id': 'cc', 'user_id': 'me'},
                {'id': 'u1', 'user_id': 'me'},
              ],
        });

    test('is the user\'s, never a client contact\'s', () {
      expect(dnOwnInvitation(doc(), 'me')?.id, 'u1');
      expect(dnOwnInvitation(doc(), 'someone'), isNull);
      expect(dnOwnInvitation(doc(), ''), isNull);
    });

    test('is gone once signed, completed, voided or deleted', () {
      expect(
        dnOwnInvitation(
          doc(
            invitations: [
              {'id': 'u1', 'user_id': 'me', 'signed_date': '2026-11-01'},
            ],
          ),
          'me',
        ),
        isNull,
      );
      expect(dnOwnInvitation(doc(status: 6), 'me'), isNull);
      expect(dnOwnInvitation(doc(status: 8), 'me'), isNull);
      expect(
        dnOwnInvitation(
          DnDocument.fromJson({
            'id': 'd',
            'status_id': 5,
            'is_deleted': true,
            'invitations': [
              {'id': 'u1', 'user_id': 'me'},
            ],
          }),
          'me',
        ),
        isNull,
      );
    });
  });
}
