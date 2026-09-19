import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/utils/editor_html.dart';
import 'package:admin/utils/notes_html.dart';

/// What the editor stores for [markdown], i.e. what a save would persist.
String htmlOf(String markdown) =>
    htmlFromEditorDocument(deserializeMarkdownToDocument(markdown));

/// One full open-and-save cycle over a stored value — which is exactly what
/// `htmlFromEditableValue` does for the fields that have no editor.
String cycle(String stored) => htmlFromEditableValue(stored);

void main() {
  group('htmlFromEditorDocument', () {
    test('an empty document is an empty value, not an empty paragraph', () {
      expect(htmlFromEditorDocument(MutableDocument.empty()), '');
      expect(htmlOf(''), '');
      expect(htmlOf('   '), '');
    });

    test('paragraphs become <p>, with no newline between them', () {
      expect(htmlOf('one\n\ntwo'), '<p>one</p><p>two</p>');
    });

    test('a soft line break inside a paragraph becomes <br>', () {
      // This is the #159 shape: an email pasted with single newlines. The
      // markdown serializer writes it as a two-space hard break, which no
      // consumer of these fields honours.
      expect(htmlOf('one  \ntwo'), '<p>one<br>two</p>');
    });

    test('a blank line the user typed survives as an empty paragraph', () {
      expect(htmlOf('one\n\n\n\ntwo'), '<p>one</p><p></p><p>two</p>');
    });

    test('leading and trailing blank paragraphs are dropped', () {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(id: '1', text: AttributedText('')),
          ParagraphNode(id: '2', text: AttributedText('body')),
          ParagraphNode(id: '3', text: AttributedText('   ')),
        ],
      );
      expect(htmlFromEditorDocument(document), '<p>body</p>');
    });

    test('inline marks become their tags', () {
      expect(htmlOf('a **b** c'), '<p>a <strong>b</strong> c</p>');
      expect(htmlOf('*i*'), '<p><em>i</em></p>');
      expect(htmlOf('¬u¬'), '<p><u>u</u></p>');
      expect(htmlOf('~s~'), '<p><s>s</s></p>');
      expect(htmlOf('`c`'), '<p><code>c</code></p>');
    });

    test('a link wraps its style marks, like the markdown it mirrors', () {
      expect(
        htmlOf('[**t**](https://x.test)'),
        '<p><a href="https://x.test"><strong>t</strong></a></p>',
      );
    });

    test('lists nest inside the item above them', () {
      expect(htmlOf('  * One\n  * Two'), '<ul><li>One</li><li>Two</li></ul>');
      expect(htmlOf('  1. One\n  1. Two'), '<ol><li>One</li><li>Two</li></ol>');
      expect(
        htmlOf('  * Parent\n    * Child'),
        '<ul><li>Parent<ul><li>Child</li></ul></li></ul>',
      );
    });

    test('headings, rules, quotes and code blocks keep their block', () {
      expect(htmlOf('## Title'), '<h2>Title</h2>');
      expect(htmlOf('---'), '<hr>');
      expect(htmlOf('> quoted'), '<blockquote><p>quoted</p></blockquote>');
      expect(htmlOf('```\nx = 1\n```'), '<pre><code>x = 1</code></pre>');
    });

    test('an image keeps its source and alt text', () {
      expect(
        htmlOf('![a cat](https://x.test/cat.png)'),
        '<img src="https://x.test/cat.png" alt="a cat">',
      );
    });

    test('text is escaped, so markup the user typed stays text', () {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(id: '1', text: AttributedText('a < b & c > d')),
          ParagraphNode(
            id: '2',
            text: AttributedText('<script>alert(1)</script>'),
          ),
        ],
      );
      expect(
        htmlFromEditorDocument(document),
        '<p>a &lt; b &amp; c &gt; d</p>'
        '<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>',
      );
    });

    test('plain text is never re-read as markdown', () {
      // The whole reason this is a document walker: routing the emit through
      // markdown text would turn each of these into markup and persist it.
      for (final text in [
        '5 * 3 * 2',
        '# 1 priority',
        '- see below',
        'a_b_c',
        'not > a quote',
        '| a | b |',
      ]) {
        final document = MutableDocument(
          nodes: [ParagraphNode(id: '1', text: AttributedText(text))],
        );
        expect(
          htmlFromEditorDocument(document),
          '<p>${escapeHtmlText(text)}</p>',
        );
      }
    });

    test('a template variable is left exactly as typed', () {
      final document = MutableDocument(
        nodes: [
          ParagraphNode(id: '1', text: AttributedText(r'Dear $client.name,')),
        ],
      );
      expect(htmlFromEditorDocument(document), r'<p>Dear $client.name,</p>');
    });

    test('partially overlapping spans still produce well-formed HTML', () {
      final text = AttributedText('abcdefgh');
      text.addAttribution(boldAttribution, const SpanRange(0, 4));
      text.addAttribution(italicsAttribution, const SpanRange(3, 7));
      final html = htmlFromEditorDocument(
        MutableDocument(
          nodes: [ParagraphNode(id: '1', text: text)],
        ),
      );
      expect(html, '<p><strong>abc<em>de</em></strong><em>fgh</em></p>');
    });

    test('a table keeps its structure', () {
      // Only reachable from pasted markdown, but nothing else asserts the
      // shape — the fixed-point corpus can't, because the inbound fold
      // flattens a table to paragraphs before it gets back here.
      expect(
        htmlOf('| a | b |\n| --- | --- |\n| 1 | 2 |'),
        '<table><thead><tr><th>a</th><th>b</th></tr></thead>'
        '<tbody><tr><td>1</td><td>2</td></tr></tbody></table>',
      );
    });

    test('a link destination no consumer would keep is dropped', () {
      // The server's `Purify` allows `http(s)`, `data:image/` and `$var`
      // hrefs; React runs DOMPurify. Storing a `javascript:` anchor would only
      // ever render as a dead tag.
      expect(htmlOf('[x](javascript:alert(1))'), '<p>x</p>');
      expect(
        htmlOf('[x](https://x.test)'),
        '<p><a href="https://x.test">x</a></p>',
      );
      expect(
        htmlOf('[x](mailto:a@x.test)'),
        '<p><a href="mailto:a@x.test">x</a></p>',
      );
      // A relative destination, and a template variable the linkifier grabbed,
      // both stay — `Purify` has a `$*.*` pattern for exactly the latter.
      expect(htmlOf('[x](/portal)'), '<p><a href="/portal">x</a></p>');
    });

    test('never emits a newline', () {
      const corpus = [
        'one\n\ntwo',
        'one  \ntwo',
        'one\n\n\n\ntwo',
        '## Title\n\nbody',
        '  * One\n  * Two',
        '  * Parent\n    * Child',
        '> quoted',
        '```\nx = 1\ny = 2\n```',
        '---',
        '[t](https://x.test)',
        '![a](https://x.test/a.png)',
        '| a | b |\n| --- | --- |\n| 1 | 2 |',
      ];
      for (final markdown in corpus) {
        expect(htmlOf(markdown), isNot(contains('\n')), reason: markdown);
      }
    });
  });

  group('open-and-save is a fixed point', () {
    // Opening a record and saving it must not churn the stored value. The
    // invariant is over the HTML, not the markdown in between: the fold writes
    // a bullet as `- One` while super_editor serializes `  * One`, and both
    // mean the same list.
    const corpus = [
      '',
      'plain text',
      'line one\nline two',
      'para one\n\npara two',
      '<p>a</p><p>b</p>',
      '<p>a</p><p></p><p>b</p>',
      '<p>a<br>b</p>',
      '<p>Intro</p><ul><li>One</li><li>Two</li></ul>',
      '<ol><li>One</li><li>Two</li></ol>',
      '<ul><li>Parent<ul><li>Child</li></ul></li></ul>',
      '<h2>Title</h2><p>body</p>',
      '<p>a <strong>bold</strong> and <em>italic</em> word</p>',
      '<p><u>u</u> and <s>s</s> and <code>c</code></p>',
      '<p>see <a href="https://x.test/?a=1&amp;b=2">this</a></p>',
      '<p>a &amp; b &lt; c</p>',
      r'<p>Dear $client.name,</p>',
      '<blockquote><p>quoted</p></blockquote>',
      '<hr>',
      '<img src="https://x.test/a.png" alt="a">',
      '<p>a <span style="color:red">red</span> word</p>',
      // The shapes a Send Email "Customize" hands back — the regression that
      // made `htmlFromEditableValue` its own function.
      '<p>Hi <strong>Bob</strong></p><ul><li>One</li><li>Two</li></ul>',
      '<p>See <a href="https://x.test">this</a></p>',
      '<pre><code>x = 1</code></pre>',
      '<table><thead><tr><th>a</th></tr></thead></table>',
    ];

    for (final stored in corpus) {
      test('stable for: ${stored.isEmpty ? '<empty>' : stored}', () {
        final once = cycle(stored);
        expect(cycle(once), once);
        expect(once, isNot(contains('\n')));
      });
    }
  });

  group('open-and-save preserves a blank line', () {
    // Deliberately NOT added to the corpus above: that asserts *stability*
    // (`cycle(cycle(x)) == cycle(x)`), not identity, so a shape that loses
    // content on the first pass and is stable afterwards passes it vacuously.
    // Which is exactly what `<br><br>` did. These assert the content instead.

    test('two breaks survive one cycle', () {
      // Was `<p>a<br>b</p>` — one break silently dropped, because the fold
      // merged consecutive `<br>`s into a single newline and `a<br>b` folds to
      // that same newline. Now a paragraph boundary, which is what a blank line
      // between two runs of text means.
      expect(cycle('<p>a<br><br>b</p>'), '<p>a</p><p>b</p>');
    });

    test('one break is still one break', () {
      // The guard on the test above: the two inputs must not agree.
      expect(cycle('<p>a<br>b</p>'), '<p>a<br>b</p>');
    });

    test('a default email template keeps the line after the greeting', () {
      // Every server default body is `<p>$client<br><br>…</p>`
      // (`EmailTemplateDefaults.php`), and this is the value the Templates &
      // Reminders editor is seeded with. Before the fix, changing one word saved
      // the greeting and the body as one run.
      final saved = cycle(
        r'<p>$client<br><br>Here is your invoice.</p>'
        r'<div>$view_button</div>',
      );
      expect(
        saved,
        r'<p>$client</p><p>Here is your invoice.</p><p>$view_button</p>',
      );
      expect(cycle(saved), saved);
    });

    test('an empty bullet no longer eats the paragraph after the list', () {
      // Was `<ul><li>Next</li></ul>`: the paragraph became a bullet, and the
      // save persisted it as one. `holdBreaks` had no release, so a marker with
      // no text in it suppressed every break to the end of the document.
      final saved = cycle('<ul><li></li></ul><p>Next</p>');
      expect(saved, '<ul><li></li></ul><p>Next</p>');
      expect(cycle(saved), saved);
    });

    test('a double break inside a list item does not split the list', () {
      // Was `<ol><li>a</li></ol><p>b</p><ol><li>c</li></ol>` — the list ends at
      // the blank line and `c` is **numbered 1 again** in the rendered PDF. The
      // `<br>` arm has to honour the same in-list clamp the block arm does.
      final saved = cycle('<ol><li>a<br><br>b</li><li>c</li></ol>');
      expect(saved, '<ol><li>a<br>b</li><li>c</li></ol>');
      expect(cycle(saved), saved);
    });

    test('three breaks round-trip without losing one on the second save', () {
      // 3 newlines is not a value the encoding defines: super_editor reads it as
      // one paragraph beginning with a newline, which folds back to 2. Snapping
      // to 4 makes it a paragraph plus a blank one, which IS stable.
      final saved = cycle('<p>a<br><br><br>b</p>');
      expect(cycle(saved), saved, reason: 'must not shed a break on save #2');
    });

    test('a blank bullet between two items does not re-nest the second', () {
      // Was `<ul><li>One</li><li><ul><li>Two</li></ul></li></ul>` — a visible
      // change to the rendered PDF.
      expect(
        cycle('<ul><li>One</li><li></li><li>Two</li></ul>'),
        '<ul><li>One</li><li></li><li>Two</li></ul>',
      );
    });
  });
}
