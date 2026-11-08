import 'dart:convert';
import 'dart:typed_data';

import 'package:admin/domain/docuninja/docuninja_create.dart';
import 'package:flutter_test/flutter_test.dart';

/// Creating a document as React's `Create.tsx` and drop zone do.
void main() {
  test('a file name becomes React\'s document name', () {
    expect(
      dnDocumentNameFromFile('service-agreement_v2.pdf'),
      'Service Agreement V2',
    );
    expect(dnDocumentNameFromFile('NDA.docx'), 'NDA');
    expect(dnDocumentNameFromFile('  lease  terms .pdf'), 'Lease Terms');
    expect(dnDocumentNameFromFile('.pdf', fallback: 'Untitled'), 'Untitled');
    expect(dnDocumentNameFromFile('---.pdf', fallback: 'Untitled'), 'Untitled');
  });

  test('a password-protected PDF names an /Encrypt dictionary', () {
    Uint8List b(String s) => Uint8List.fromList(latin1.encode(s));
    final plain = b('%PDF-1.7\ntrailer\n<< /Root 1 0 R /Size 9 >>');
    final locked = b('trailer\n<< /Root 1 0 R /Encrypt 7 0 R /ID [<a><b>] >>');
    expect(dnLooksPasswordProtected(plain, plain), isFalse);
    expect(dnLooksPasswordProtected(plain, locked), isTrue);
    expect(
      dnLooksPasswordProtected(b('<< /Encrypt << /Filter /Standard'), plain),
      isTrue,
    );
    // A word in the text is not the dictionary.
    expect(
      dnLooksPasswordProtected(b('(How to /Encrypt files) Tj'), plain),
      isFalse,
    );
    expect(dnProtectedFileName('a.pdf', 'pw'), 'a.pdf|pw');
  });

  test('the browser builder link opens on the document\'s company', () {
    final uri = dnBuilderWebUri(documentId: 'D1', companyId: 'Xyz9');
    expect(
      uri.toString(),
      'https://app.invoicing.co/#/docuninja/D1/builder?company=Xyz9',
    );
  });

  test('a template\'s builder, and a document just made from one', () {
    expect(
      dnBuilderWebUri(
        documentId: 'B1',
        companyId: 'C',
        template: true,
      ).toString(),
      'https://app.invoicing.co/#/docuninja/templates/B1/edit?company=C',
    );
    expect(
      dnBuilderWebUri(
        documentId: 'D1',
        companyId: 'C',
        fromTemplate: true,
      ).toString(),
      'https://app.invoicing.co/#/docuninja/D1/builder'
      '?company=C&from_template=true',
    );
  });

  test('the sign page carries the invitation as sig, and the company', () {
    expect(
      dnWebAppSignUri(
        documentId: 'D1',
        invitationId: 'I1',
        companyId: 'C',
      ).toString(),
      'https://app.invoicing.co/#/docuninja/sign/D1/I1?sig=I1&company=C',
    );
  });

  test('a signer\'s copied link is the web app\'s sign page, no sig', () {
    expect(
      dnWebAppSignLink(documentId: 'D1', invitationId: 'I1').toString(),
      'https://app.invoicing.co/#/docuninja/sign/D1/I1',
    );
  });
}
