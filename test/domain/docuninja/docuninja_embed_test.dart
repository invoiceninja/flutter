import 'dart:convert';

import 'package:admin/domain/docuninja/docuninja_embed.dart';
import 'package:flutter_test/flutter_test.dart';

/// The embedded builder's half of invoiceninja/ui's `embed.ts`.
void main() {
  test('the builder page opens in embed mode, on the document\'s company', () {
    expect(
      dnEmbedBuilderUri(documentId: 'D1', companyId: 'C9').toString(),
      'https://app.invoicing.co/#/docuninja/D1/builder?company=C9&embed=1',
    );
  });

  test('only the web app\'s own origin may load', () {
    expect(dnEmbedAllowed(Uri.parse('https://app.invoicing.co/#/x')), isTrue);
    expect(dnEmbedAllowed(Uri.parse('http://app.invoicing.co/')), isFalse);
    expect(
      dnEmbedAllowed(Uri.parse('https://app.invoicing.co.evil.com/')),
      isFalse,
    );
    expect(dnEmbedAllowed(Uri.parse('https://invoicing.co/')), isFalse);
    expect(
      dnEmbedAllowed(Uri.parse('https://app.invoicing.co:8443/')),
      isFalse,
    );
  });

  test('a message is {v, type, payload}; anything else is dropped', () {
    final m = DnEmbedMessage.parse(
      '{"v":1,"type":"dirty","payload":{"dirty":true}}',
    )!;
    expect(m.version, 1);
    expect(m.type, 'dirty');
    expect(m.payload, {'dirty': true});
    expect(DnEmbedMessage.parse('{"v":1,"type":"ready"}')!.payload, isEmpty);
    expect(DnEmbedMessage.parse('not json'), isNull);
    expect(DnEmbedMessage.parse('{"type":"ready"}'), isNull);
    expect(DnEmbedMessage.parse('[1]'), isNull);
  });

  test('the token reaches the page JSON-encoded, never as script text', () {
    const token = 'a"b\'c</script>';
    final script = dnEmbedInitScript(token);
    final json = script.substring(
      script.indexOf('init(') + 5,
      script.lastIndexOf(')'),
    );
    expect(jsonDecode(json), {'v': kDnEmbedProtocolVersion, 'token': token});
  });
}
