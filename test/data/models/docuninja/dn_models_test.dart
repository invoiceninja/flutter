import 'dart:convert';
import 'dart:io';

import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/docuninja/$name').readAsStringSync())
        as Map<String, dynamic>;

/// The fixtures are the live service's answers, with tokens, keys, emails and
/// signed URLs replaced (docs/docuninja.md).
void main() {
  test('login: the user, the companies, the role and the account', () {
    final login = DnLogin.fromJson(_fixture('login.json'));
    expect(login.user.email, 'signer@example.com');
    expect(login.companies.map((c) => c.name), ['Test Company', 'The Beatles']);
    expect(login.companies.first.token, 'dn-test-token');
    expect(login.companies.first.documentLimit, 4);
    expect(login.companyUser.isAdmin, isTrue);
    expect(login.account.plan, 'pro');
    expect(login.account.numUsers, 1);
    expect(login.permissions, isEmpty);
  });

  test('companyFor pairs by ninja_company_key, and nothing for none', () {
    final login = DnLogin.fromJson(_fixture('login.json'));
    expect(login.companyFor('ninja-company-key-2')?.name, 'The Beatles');
    expect(login.companyFor('unknown'), isNull);
    expect(login.companyFor(''), isNull);
  });

  test('a document: status, files with percentage fields, invitations', () {
    final doc = DnDocument.fromJson(
      _fixture('document.json')['data'] as Map<String, dynamic>,
    );
    expect(doc.status, DnDocumentStatus.sent);
    final file = doc.files.single;
    expect(
      file.previews.single,
      startsWith('https://previews.docuninja.test/'),
    );
    final field = file.rectangles.single;
    expect(field.type, 'signature');
    expect(field.page, 1);
    expect(field.left, inInclusiveRange(0, 100));
    expect(field.left + field.width, lessThanOrEqualTo(100));
    final invitation = doc.invitations.single;
    expect(invitation.isContact, isTrue);
    // A field belongs to the signer whose contact (or user) id it names.
    expect(field.signatoryId, invitation.signatoryId);
    expect(invitation.state, DnInvitationState.sent);
    // Whole-object writes carry every field the app does not model.
    expect(field.raw['options'], isNotNull);
    expect(doc.raw['settings'], isNotNull);
  });

  test('a documents page reads Laravel paging', () {
    final page = DnPage.fromJson(
      _fixture('documents_page.json'),
      DnDocument.fromJson,
    );
    expect(page.items, hasLength(1));
    expect(page.total, 1);
    expect(page.hasMore, isFalse);
  });

  test('a mistyped or missing field takes a default, never throws', () {
    final doc = DnDocument.fromJson({
      'id': 7,
      'status_id': '6',
      'files': [
        {
          'metadata': {
            'rectangles': [
              {'left': '12.5', 'page': null},
            ],
          },
        },
      ],
      'invitations': 'nope',
    });
    expect(doc.id, '7');
    expect(doc.status, DnDocumentStatus.completed);
    expect(doc.files.single.rectangles.single.left, 12.5);
    expect(doc.files.single.rectangles.single.page, 1);
    expect(doc.invitations, isEmpty);
  });

  test('invitation state follows the latest date, as React reads it', () {
    DnInvitation inv(Map<String, dynamic> j) => DnInvitation.fromJson(j);
    expect(inv({}).state, DnInvitationState.pending);
    expect(inv({'sent_date': 'x'}).state, DnInvitationState.sent);
    expect(
      inv({'sent_date': 'x', 'viewed_date': 'y'}).state,
      DnInvitationState.viewed,
    );
    expect(
      inv({'viewed_date': 'y', 'signed_date': 'z'}).state,
      DnInvitationState.signed,
    );
  });
}
