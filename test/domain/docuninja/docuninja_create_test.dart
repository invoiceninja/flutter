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
}
