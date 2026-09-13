import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/services/template_variable_probe.dart';
import 'package:admin/data/services/templates_api.dart';
import 'package:admin/domain/email_template_variables.dart';

/// Renders a subject the way the server's `TemplateEngine` does: PHP `strtr`
/// over [values] — longest key first at each position, unknown tokens left
/// literal, no markdown and no escaping.
class _StrtrTemplatesApi implements TemplatesApi {
  _StrtrTemplatesApi(this.values, {this.subjectOverride});

  final Map<String, String> values;

  /// Replaces the rendered subject outright — to simulate a response that
  /// isn't the probe it should be.
  final String? subjectOverride;

  final calls =
      <
        ({
          String template,
          String subject,
          String body,
          String entity,
          String entityId,
        })
      >[];

  @override
  Future<TemplatePreview> render({
    required String template,
    required String subject,
    required String body,
    String entity = '',
    String entityId = '',
  }) async {
    calls.add((
      template: template,
      subject: subject,
      body: body,
      entity: entity,
      entityId: entityId,
    ));
    final keys = values.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final out = StringBuffer();
    var i = 0;
    outer:
    while (i < subject.length) {
      for (final key in keys) {
        if (subject.startsWith(key, i)) {
          out.write(values[key]);
          i += key.length;
          continue outer;
        }
      }
      out.write(subject[i]);
      i++;
    }
    return TemplatePreview(
      subject: subjectOverride ?? out.toString(),
      body: body,
      wrapper: '',
      rawSubject: subject,
      rawBody: body,
    );
  }
}

void main() {
  Future<Map<String, TemplateVariableValue>> probe(
    _StrtrTemplatesApi api,
    List<String> tokens,
  ) => resolveTemplateVariables(
    api,
    template: 'invoice',
    entity: 'invoice',
    entityId: 'Wpmbk5ezJn',
    tokens: tokens,
  );

  test('sends the tokens as the subject of a bound render', () async {
    final api = _StrtrTemplatesApi({r'$number': '0012'});
    await probe(api, [r'$number', r'$company.name']);

    expect(api.calls, hasLength(1));
    final call = api.calls.single;
    expect(call.entity, 'invoice');
    expect(call.entityId, 'Wpmbk5ezJn');
    expect(call.template, 'invoice');
    // Non-empty: the server turns '' into null and loads the default body.
    expect(call.body, '.');
    expect(call.subject, contains(r'$number'));
    expect(call.subject, contains(r'$company.name'));
  });

  test('reads back resolved, empty and unknown values', () async {
    final api = _StrtrTemplatesApi({
      r'$number': '0012',
      r'$company.name': 'Acme Ltd',
      r'$po_number': '',
      r'$client': 'Jane &amp; Co',
    });
    final values = await probe(api, [
      r'$number',
      r'$company.name',
      r'$po_number',
      r'$client',
      r'$nope',
    ]);

    expect((values[r'$number'] as TemplateVariableResolved).text, '0012');
    expect(
      (values[r'$company.name'] as TemplateVariableResolved).text,
      'Acme Ltd',
    );
    expect(values[r'$po_number'], isA<TemplateVariableEmpty>());
    expect((values[r'$client'] as TemplateVariableResolved).text, 'Jane & Co');
    expect(values[r'$nope'], isA<TemplateVariableUnknown>());
  });

  test(
    'a button reduces to its visible text and is flagged as markup',
    () async {
      const button =
          '<!--[if mso]><v:roundrect href="https://x"><![endif]-->'
          '<a class="button" href="https://x">View Invoice</a>'
          '<!--[if mso]></v:roundrect><![endif]-->';
      final api = _StrtrTemplatesApi({r'$view_button': button});
      final value =
          (await probe(api, [r'$view_button']))[r'$view_button']
              as TemplateVariableResolved;

      expect(value.text, 'View Invoice');
      expect(value.isMarkup, isTrue);
    },
  );

  test('a non-breaking space alone is an empty value', () async {
    final api = _StrtrTemplatesApi({r'$number': '&nbsp;'});
    expect(
      (await probe(api, [r'$number']))[r'$number'],
      isA<TemplateVariableEmpty>(),
    );
  });

  test('a typo shows what the recipient would actually get', () async {
    // strtr matches the longest *key*, so `$client` swallows the prefix.
    final api = _StrtrTemplatesApi({r'$client': 'Acme'});
    final value =
        (await probe(api, [r'$client.nmae']))[r'$client.nmae']
            as TemplateVariableResolved;

    expect(value.text, 'Acme.nmae');
  });

  test('a response without every marker yields no values', () async {
    final api = _StrtrTemplatesApi({
      r'$number': '0012',
    }, subjectOverride: 'Something else entirely');
    expect(await probe(api, [r'$number']), isEmpty);
  });

  test('duplicate tokens are probed once', () async {
    final api = _StrtrTemplatesApi({r'$number': '0012'});
    final values = await probe(api, [r'$number', r'$number']);

    expect(values.keys, [r'$number']);
    expect(
      RegExp(r'\$number').allMatches(api.calls.single.subject),
      hasLength(1),
    );
  });

  test('no tokens means no request', () async {
    final api = _StrtrTemplatesApi(const {});
    expect(await probe(api, const []), isEmpty);
    expect(api.calls, isEmpty);
  });

  test('refuses to run unbound — that renders another record (#31)', () {
    final api = _StrtrTemplatesApi(const {});
    expect(
      () => resolveTemplateVariables(
        api,
        template: 'invoice',
        entity: '',
        entityId: '',
        tokens: const [r'$number'],
      ),
      throwsArgumentError,
    );
    expect(api.calls, isEmpty);
  });
}
