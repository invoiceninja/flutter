import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/ui/core/widgets/template_variables/markdown_template_variables.dart';
import 'package:admin/utils/legacy_html_markdown.dart';

const _scope = TemplateVariableScope.invoice;

MutableDocument _doc(String markdown) =>
    deserializeMarkdownToDocument(markdown);

String _serialize(Document document) =>
    serializeDocumentToMarkdown(detokenizeTemplateVariables(document));

TextNode _only(Document document) => document.first as TextNode;

List<String> _chips(Document document) =>
    templateVariableTokensIn(document).toList();

/// A one-paragraph editor with the caret at [caret] (default: the end), wired
/// exactly as `MarkdownTextField` wires its own.
({Editor editor, MutableDocument document}) _editor(
  String text, {
  int? caret,
  TemplateVariableScope? scope = _scope,
  bool guard = true,
}) {
  final document = MutableDocument(
    nodes: [ParagraphNode(id: 'p', text: AttributedText(text))],
  );
  final composer = MutableDocumentComposer(
    initialSelection: DocumentSelection.collapsed(
      position: templateVariablePosition('p', caret ?? text.length),
    ),
  );
  final editor = createDefaultDocumentEditor(
    document: document,
    composer: composer,
  );
  if (guard) installTemplateVariableReactions(editor, scope: scope);
  return (editor: editor, document: document);
}

void _type(Editor editor, String character) =>
    editor.execute([InsertCharacterAtCaretRequest(character: character)]);

bool _hasLink(TextNode node) => node.text
    .getAttributionSpansInRange(
      attributionFilter: (a) => a is LinkAttribution,
      range: SpanRange(0, node.text.length - 1),
    )
    .isNotEmpty;

void main() {
  group('tokenize / detokenize', () {
    // Every one of these must serialize byte-for-byte as it did before chips
    // existed — or opening an untouched field would emit a change.
    final corpus = <String>[
      markdownFromLegacyHtml(
        r'<p>$client<br><br>To view your invoice for $amount, click the link '
        r'below.</p><div>$view_button</div>',
      ),
      markdownFromLegacyHtml(
        r'<p>Dear $client,</p><p>Your balance is <b>$balance</b>.</p>',
      ),
      r'New invoice $number from $company.name',
      r'**Bold $amount** and *$company.name* here',
      r'Pay [here]($payment_url) or [$view_url]($view_url)',
      '- first \$number\n- second \$amount',
      '1. one \$client\n2. two',
      r'# Invoice $number',
      r'Inline `code $number` stays',
      r'Mixed **$client**.name stays',
      r'Price $5 and US$ 10 are money',
      r'Adjacent $number$amount tokens',
      r'Sentence end $company.name.',
      r'Unknown $not_a_variable stays',
      '| a | b |\n| --- | --- |\n| \$number | x |',
      '',
    ];

    for (final markdown in corpus) {
      test(
        'round-trips byte-identically: ${markdown.replaceAll('\n', r'\n')}',
        () {
          final plain = serializeDocumentToMarkdown(_doc(markdown));
          final tokenized = tokenizeTemplateVariables(_doc(markdown), _scope);
          expect(_serialize(tokenized), plain);
        },
      );
    }

    test('recognised tokens become chips, in order', () {
      final document = tokenizeTemplateVariables(
        _doc(r'New invoice $number from $company.name'),
        _scope,
      );
      expect(_chips(document), [r'$number', r'$company.name']);
    });

    test('a chip keeps the formatting that covered its whole token', () {
      final document = tokenizeTemplateVariables(
        _doc(r'**$amount** due'),
        _scope,
      );
      final text = _only(document).text;
      expect(_chips(document), [r'$amount']);
      final chipOffset = text.placeholders.keys.single;
      expect(text.getAllAttributionsAt(chipOffset), contains(boldAttribution));
    });

    test(
      'partial formatting, inline code, tables and unknown tokens stay text',
      () {
        for (final markdown in [
          r'Mixed **$client**.name',
          r'Inline `$number`',
          r'Unknown $not_a_variable',
          '| a |\n| --- |\n| \$number |',
        ]) {
          expect(
            _chips(tokenizeTemplateVariables(_doc(markdown), _scope)),
            isEmpty,
            reason: markdown,
          );
        }
      },
    );

    test('a stray U+FFFC (a chip copied and pasted as text) is dropped', () {
      final document = MutableDocument(
        nodes: [ParagraphNode(id: 'p', text: AttributedText('a￼b'))],
      );
      expect(_serialize(document), 'ab');
    });

    test('an untouched document is returned as-is', () {
      final document = _doc('Nothing to see');
      expect(
        identical(detokenizeTemplateVariables(document), document),
        isTrue,
      );
      expect(
        identical(tokenizeTemplateVariables(document, _scope), document),
        isTrue,
      );
    });
  });

  group('linkify guard', () {
    test('the unguarded editor links a typed variable — the bug', () {
      final e = _editor(r'Dear $client.name', guard: false);
      _type(e.editor, ' ');
      expect(_hasLink(_only(e.document)), isTrue);
    });

    for (final (text, typed) in [
      (r'Dear $client.name', ' '),
      (r'Dear $client.name,', ' '),
      (r'Dear $Client.Name', ' '),
      (r'Hi ($client.city)', ' '),
    ]) {
      test('a plain markdown field never links "$text"', () {
        final e = _editor(text, scope: null);
        _type(e.editor, typed);
        expect(_hasLink(_only(e.document)), isFalse);
        expect(_serialize(e.document), isNot(contains('](https://')));
      });
    }

    test('a real URL still links', () {
      final e = _editor('see example.com', scope: null);
      _type(e.editor, ' ');
      expect(_hasLink(_only(e.document)), isTrue);
    });

    test('content saved while the bug was live heals on seed', () {
      final text = AttributedText(r'Dear $client.name, hi')
        ..addAttribution(
          const LinkAttribution(r'https://$client.name,'),
          const SpanRange(5, 17),
        );
      final healed = healTemplateVariableLinks(
        MutableDocument(
          nodes: [ParagraphNode(id: 'p', text: text)],
        ),
      );
      expect(_hasLink(_only(healed)), isFalse);
      expect(serializeDocumentToMarkdown(healed), r'Dear $client.name, hi');
    });

    test('the predicate', () {
      expect(
        isTemplateVariableAutoLink(
          const LinkAttribution(r'https://$client.name,'),
          r'$client.name,',
        ),
        isTrue,
      );
      expect(
        isTemplateVariableAutoLink(
          const LinkAttribution(r'https://$client.name'),
          r'$Client.Name',
        ),
        isTrue,
      );
      expect(
        isTemplateVariableAutoLink(
          const LinkAttribution('https://example.com'),
          'example.com',
        ),
        isFalse,
      );
      // A deliberate link *around* a variable is the user's.
      expect(
        isTemplateVariableAutoLink(
          const LinkAttribution('https://portal.example.com'),
          r'$view_url',
        ),
        isFalse,
      );
    });
  });

  group('conversion reaction', () {
    test('a typed space turns the token before it into a chip', () {
      final e = _editor(r'Dear $client.name');
      _type(e.editor, ' ');
      expect(_chips(e.document), [r'$client.name']);
      expect(_serialize(e.document), r'Dear $client.name ');
      expect(_hasLink(_only(e.document)), isFalse);
    });

    test('punctuation after the token converts it too', () {
      final e = _editor(r'Dear $client.name');
      _type(e.editor, ',');
      expect(_chips(e.document), [r'$client.name']);
      expect(_serialize(e.document), r'Dear $client.name,');
    });

    test('a dot may be on its way to a longer token, so it waits', () {
      final e = _editor(r'Dear $client');
      _type(e.editor, '.');
      expect(_chips(e.document), isEmpty);
    });

    test('the token being typed is left alone', () {
      final e = _editor(r'Dear $client.nam');
      _type(e.editor, 'e');
      expect(_chips(e.document), isEmpty);
    });

    test('a pasted token converts at once', () {
      final e = _editor('Hello ');
      e.editor.execute([
        InsertTextRequest(
          documentPosition: templateVariablePosition('p', 6),
          textToInsert: r'$company.name',
          attributions: const {},
        ),
      ]);
      expect(_chips(e.document), [r'$company.name']);
      expect(_serialize(e.document), r'Hello $company.name');
    });

    test('unknown tokens are never converted', () {
      final e = _editor(r'Hi $not_a_variable');
      _type(e.editor, ' ');
      expect(_chips(e.document), isEmpty);
    });
  });

  group('chip edits', () {
    ({Editor editor, MutableDocument document}) withChip() {
      final document = tokenizeTemplateVariables(
        _doc(r'From $company.name today'),
        _scope,
      );
      final editor = createDefaultDocumentEditor(
        document: document,
        composer: MutableDocumentComposer(),
      );
      return (editor: editor, document: document);
    }

    test('replace swaps the token in place', () {
      final e = withChip();
      final node = _only(e.document);
      final offset = node.text.placeholders.keys.single;
      e.editor.execute(
        replaceTemplateVariableChipRequests(node, offset, token: r'$client'),
      );
      expect(_serialize(e.document), r'From $client today');
    });

    test('remove deletes the chip', () {
      final e = withChip();
      final node = _only(e.document);
      final offset = node.text.placeholders.keys.single;
      e.editor.execute(replaceTemplateVariableChipRequests(node, offset));
      expect(_serialize(e.document), 'From  today');
    });

    test('a chip that would run into a word gets a space', () {
      final document = tokenizeTemplateVariables(_doc(r'$number x'), _scope);
      final editor = createDefaultDocumentEditor(
        document: document,
        composer: MutableDocumentComposer(),
      );
      // Delete the space so a letter follows the chip directly, then swap it.
      final node = _only(document);
      editor.execute([
        DeleteContentRequest(
          documentRange: DocumentRange(
            start: templateVariablePosition(node.id, 1),
            end: templateVariablePosition(node.id, 2),
          ),
        ),
      ]);
      final updated = _only(document);
      editor.execute(
        replaceTemplateVariableChipRequests(updated, 0, token: r'$amount'),
      );
      expect(_serialize(document), r'$amount x');
    });

    test('the append position is the end of the last text block', () {
      final document = _doc('one\n\ntwo');
      final position = templateVariableAppendPosition(document)!;
      expect(position.nodeId, document.last.id);
      expect((position.nodePosition as TextNodePosition).offset, 3);
    });
  });
}
