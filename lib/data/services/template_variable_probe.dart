import 'dart:math';

import 'package:admin/data/services/templates_api.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/l10n/transifex_php_parser.dart' show decodeHtmlEntities;

/// What each of [tokens] renders as in an email about one document, straight
/// from the server (invoiceninja/flutter#139).
///
/// A free function over [TemplatesApi.render] rather than a method on it:
/// four tests fake `TemplatesApi` with `implements`, so widening its surface
/// would break their compilation, and `render` already carries
/// `readOnly: true`.
///
/// It sends a subject made of the tokens behind markers (see
/// [buildTemplateVariableProbe]) and reads each value out of the rendered
/// subject. That is exact because the server substitutes a subject with plain
/// `strtr` — the same engine and the same values the real email gets. The
/// body is `'.'` rather than empty: Laravel's global `ConvertEmptyStringsToNull`
/// would turn `''` into null and the engine would load the whole default body
/// for nothing.
///
/// Throws [ArgumentError] when [entity] / [entityId] is empty: unbound, the
/// server renders an arbitrary other record's values — the
/// invoiceninja/flutter#31 failure — so a value from an unbound probe would be
/// a confident lie. Returns an empty map when the response doesn't carry every
/// marker; no value is better than a misattributed one.
Future<Map<String, TemplateVariableValue>> resolveTemplateVariables(
  TemplatesApi api, {
  required String template,
  required String entity,
  required String entityId,
  required List<String> tokens,
  Random? random,
}) async {
  if (entity.isEmpty || entityId.isEmpty) {
    throw ArgumentError(
      'resolveTemplateVariables needs a bound document; an unbound render '
      'substitutes another record\'s values.',
    );
  }
  final unique = tokens.toSet().toList();
  if (unique.isEmpty) return const {};
  final nonce = _nonce(random ?? Random());
  final preview = await api.render(
    template: template,
    subject: buildTemplateVariableProbe(unique, nonce),
    body: '.',
    entity: entity,
    entityId: entityId,
  );
  final raw = parseTemplateVariableProbe(preview.subject, unique, nonce);
  if (raw == null) return const {};
  return {
    for (final entry in raw.entries)
      entry.key: templateVariableValueFromRendered(entry.key, entry.value),
  };
}

/// Classify one rendered probe segment. An echo of the token itself means the
/// server didn't recognise it; otherwise the segment is reduced to the text a
/// reader would see — HTML comments (`buildViewButton` emits Outlook
/// conditionals) and tags stripped, entities decoded (`VendorHtmlEngine`
/// emits `&nbsp;` for an empty number), whitespace collapsed.
TemplateVariableValue templateVariableValueFromRendered(
  String token,
  String rendered,
) {
  if (rendered == token) return const TemplateVariableUnknown();
  final withoutComments = rendered.replaceAll(_comment, '');
  final isMarkup = _tag.hasMatch(withoutComments);
  final text = decodeHtmlEntities(
    withoutComments.replaceAll(_tag, ' '),
  ).replaceAll(_whitespace, ' ').trim();
  if (text.isEmpty) return const TemplateVariableEmpty();
  return TemplateVariableResolved(text, isMarkup: isMarkup);
}

final _comment = RegExp(r'<!--.*?-->', dotAll: true);
final _tag = RegExp(r'<[^>]+>');
final _whitespace = RegExp(r'\s+');

const _nonceAlphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

String _nonce(Random random) => String.fromCharCodes([
  for (var i = 0; i < 6; i++)
    _nonceAlphabet.codeUnitAt(random.nextInt(_nonceAlphabet.length)),
]);
