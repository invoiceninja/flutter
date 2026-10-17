import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/ui/features/documents/widgets/document_actions.dart';

/// `documentEditable` is the one rule behind the row menu's Rename /
/// visibility / Delete and the list's bulk Delete. Before it was shared, bulk
/// Delete checked only `isDeleted` and was offered on files the row menu hid
/// it for — and the server refused each with a 403.
void main() {
  AuthSession session({
    bool isAdmin = false,
    String permissions = '',
    bool isHosted = false,
    String plan = '',
  }) => AuthSession(
    baseUrl: 'https://example.test',
    isHosted: isHosted,
    accountId: 'acc1',
    companies: [
      AuthCompany(
        id: 'co1',
        name: 'Co',
        displayName: 'Co',
        permissions: permissions,
        isAdmin: isAdmin,
        isOwner: false,
      ),
    ],
    currentCompanyId: 'co1',
    userId: 'me',
    plan: plan,
  );

  DocumentRecord doc({String userId = 'someone', bool isDeleted = false}) =>
      DocumentRecord(
        id: 'd1',
        name: 'f.pdf',
        type: 'pdf',
        hash: 'h',
        size: 1,
        width: 0,
        height: 0,
        isPublic: true,
        userId: userId,
        assignedUserId: '',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        archivedAt: null,
        isDeleted: isDeleted,
      );

  test('an admin may; a user may only change their own uploads', () {
    expect(documentEditable(session(isAdmin: true), doc()), isTrue);
    expect(documentEditable(session(), doc()), isFalse);
    expect(documentEditable(session(), doc(userId: 'me')), isTrue);
    expect(
      documentEditable(session(permissions: 'edit_document'), doc()),
      isTrue,
    );
  });

  test('hosted below Enterprise is read-only, like a record\'s own tab', () {
    expect(
      documentEditable(
        session(isAdmin: true, isHosted: true, plan: 'pro'),
        doc(),
      ),
      isFalse,
    );
    expect(
      documentEditable(
        session(isAdmin: true, isHosted: true, plan: 'enterprise'),
        doc(),
      ),
      isTrue,
    );
  });

  test('a file whose delete is already queued, or no session, is not', () {
    expect(
      documentEditable(session(isAdmin: true), doc(isDeleted: true)),
      isFalse,
    );
    expect(documentEditable(null, doc()), isFalse);
  });
}
