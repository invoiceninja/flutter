import 'package:admin/utils/legacy_html_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

/// The note fields (`public_notes` / `private_notes` / `terms` / `footer`)
/// hold HTML for anyone who has ever edited them in the React client, which
/// uses TinyMCE. Handed straight to super_editor's markdown deserializer, a
/// block-level tag is parsed as a raw HTML block running to the next blank
/// line and then dropped — so `<ul>` used to delete the list and everything
/// after it — while an inline tag survives as literal text. Either way the
/// loss is persisted by the next edit (invoiceninja/flutter#107).

void main() {
  group('markdownFromLegacyHtml', () {
    test('leaves plain text and markdown alone', () {
      expect(markdownFromLegacyHtml(''), '');
      expect(markdownFromLegacyHtml('  hello  '), 'hello');
      expect(
        markdownFromLegacyHtml('# Terms\n\n- **Net 30**\n- Late fee 2%'),
        '# Terms\n\n- **Net 30**\n- Late fee 2%',
      );
    });

    test('maps paragraphs, divs and breaks to newlines', () {
      expect(markdownFromLegacyHtml('<p>one</p><p>two</p>'), 'one\n\ntwo');
      expect(
        markdownFromLegacyHtml('<div>one</div><div>two</div>'),
        'one\n\ntwo',
      );
      expect(markdownFromLegacyHtml('one<br>two'), 'one\ntwo');
      expect(markdownFromLegacyHtml('one<br />two'), 'one\ntwo');
      // The old regex only knew `<br>` / `<br/>`; legacy data carries this
      // malformed closer too.
      expect(markdownFromLegacyHtml('one</br>two'), 'one\ntwo');
      // Self-closing `<p/>` separators are paragraph boundaries like any
      // other, so they get the blank line rather than a soft break.
      expect(markdownFromLegacyHtml('<p/>one<p/>two'), 'one\n\ntwo');
      // Case is not significant in HTML.
      expect(markdownFromLegacyHtml('<P>one</P><BR>two'), 'one\n\ntwo');
    });

    test('matches tags carrying attributes, including quoted brackets', () {
      // TinyMCE emits these; every attribute-blind regex this replaces missed
      // them, so the tag survived into the parser as a raw HTML block.
      expect(
        markdownFromLegacyHtml(
          '<p style="margin:0">one</p><p dir="ltr">two</p>',
        ),
        'one\n\ntwo',
      );
      expect(
        markdownFromLegacyHtml('<ul class="x"><li data-k="1">one</li></ul>'),
        '- one',
      );
      // A quoted attribute value may contain the bracket characters. Stopping
      // at the first `>` used to leak the tail of the tag into the note.
      expect(markdownFromLegacyHtml('<p title="a > b">text</p>'), 'text');
      expect(markdownFromLegacyHtml('<p title="a < b">text</p>'), 'text');
    });

    group('prose containing < is never mistaken for a tag', () {
      // A permissive tag tail turns any `<` followed by a block-tag word into
      // a tag and deletes everything up to the next `>`. These are ordinary
      // note and footer contents.
      const cases = <String>[
        'Fee applies if qty < table rate > 10 units',
        'mail <form@x.com> now',
        'contact <bob@x.com> today',
        'docs at <https://x.test> online',
        'a < b and c > d',
        '5 < 6 > 7',
        '<!-- not a tag -->',
        'width < 5',
      ];
      for (final input in cases) {
        test(input, () => expect(markdownFromLegacyHtml(input), input));
      }
    });

    test('turns an unordered list into markdown list items', () {
      expect(
        markdownFromLegacyHtml(
          '<p>Intro</p><ul><li>One</li><li>Two</li></ul><p>Outro</p>',
        ),
        'Intro\n\n- One\n- Two\n\nOutro',
      );
      // A list opening straight off a text run still gets its blank line —
      // it used to depend on a preceding `</p>` happening to supply one.
      expect(
        markdownFromLegacyHtml('Intro<ul><li>One</li></ul>'),
        'Intro\n\n- One',
      );
    });

    test('turns an ordered list into numbered items', () {
      expect(
        markdownFromLegacyHtml('<ol><li>One</li><li>Two</li></ol>'),
        '1. One\n1. Two',
      );
    });

    test('keeps a list item whose text is wrapped in a block tag', () {
      // TinyMCE wraps list content in `<p>` once a list item has been split.
      // Left alone, the marker and the text land on different lines and
      // CommonMark reads an empty bullet plus a stray paragraph.
      expect(
        markdownFromLegacyHtml(
          '<ul><li><p>One</p></li><li><p>Two</p></li></ul>',
        ),
        '- One\n- Two',
      );
    });

    test('nests a sub-list tightly under its parent marker', () {
      // Two spaces clears a `- ` parent's content column, three clears `1. `.
      expect(
        markdownFromLegacyHtml(
          '<ul><li>Parent<ol><li>Child</li></ol></li></ul>',
        ),
        '- Parent\n  1. Child',
      );
      expect(
        markdownFromLegacyHtml(
          '<ol><li>Parent<ul><li>Child</li></ul></li></ol>',
        ),
        '1. Parent\n   - Child',
      );
    });

    test('survives unclosed list items and stray closers', () {
      expect(markdownFromLegacyHtml('<ul><li>a<li>b</ul>'), '- a\n- b');
      // A `</ul>` with no opener must not underflow the list stack.
      expect(markdownFromLegacyHtml('a</ul></ol>b'), 'a\n\nb');
    });

    test('maps headings and horizontal rules to markdown', () {
      expect(
        markdownFromLegacyHtml('<h2>Title</h2><p>body</p>'),
        '## Title\n\nbody',
      );
      expect(markdownFromLegacyHtml('<h1>A</h1><h6>B</h6>'), '# A\n\n###### B');
      expect(markdownFromLegacyHtml('<p>a</p><hr><p>b</p>'), 'a\n\n---\n\nb');
    });

    test('keeps the text of other block tags that would swallow a block', () {
      // Cells flatten to separate paragraphs — lossy, but the words survive,
      // which is the whole point versus the block being deleted.
      expect(
        markdownFromLegacyHtml('<table><tr><td>a</td><td>b</td></tr></table>'),
        'a\n\nb',
      );
      expect(
        markdownFromLegacyHtml('<blockquote>quoted</blockquote>'),
        'quoted',
      );
    });

    test('converts inline formatting to markdown', () {
      // super_editor does NOT interpret literal inline HTML: `InlineHtmlSyntax`
      // isn't in the default syntax set, so an untranslated `<strong>` is
      // painted to the user verbatim and then saved as content.
      expect(
        markdownFromLegacyHtml('<p>a <strong>bold</strong> word</p>'),
        'a **bold** word',
      );
      expect(markdownFromLegacyHtml('<b>x</b> and <i>y</i>'), '**x** and *y*');
      expect(markdownFromLegacyHtml('<em>e</em>'), '*e*');
      // `¬` is super_editor's own underline delimiter; `~~` its strikethrough.
      expect(markdownFromLegacyHtml('<u>u</u>'), '¬u¬');
      expect(markdownFromLegacyHtml('<s>s</s><del>d</del>'), '~~s~~~~d~~');
      expect(markdownFromLegacyHtml('<code>c</code>'), '`c`');
    });

    test('converts anchors to markdown links', () {
      expect(
        markdownFromLegacyHtml('<p>see <a href="https://x.test">this</a></p>'),
        'see [this](https://x.test)',
      );
      expect(
        markdownFromLegacyHtml(
          '<a href="https://x.test" target="_blank"><strong>t</strong></a>',
        ),
        '[**t**](https://x.test)',
      );
      // An anchor with no href keeps its label rather than losing it.
      expect(markdownFromLegacyHtml('<a name="x">label</a>'), 'label');
      // `<address>` must not be mistaken for an anchor.
      expect(markdownFromLegacyHtml('<address>here</address>'), 'here');
    });

    test('leaves HTML entities for the markdown parser to decode', () {
      // `markdown`'s DecodeHtmlSyntax resolves these downstream against the
      // full WHATWG table; decoding here as well would only double up.
      expect(
        markdownFromLegacyHtml('<p>a&nbsp;b &amp; c &#39;d&#39;</p>'),
        'a&nbsp;b &amp; c &#39;d&#39;',
      );
    });

    test('collapses blank-line runs it created, and only those', () {
      // super_editor preserves every blank line as an empty paragraph node, so
      // a run in hand-written markdown is deliberate and must survive. The two
      // return paths used to disagree, keyed on an unrelated `<`.
      expect(
        markdownFromLegacyHtml('<div><p>one</p></div><div><p>two</p></div>'),
        'one\n\ntwo',
      );
      expect(markdownFromLegacyHtml('<p></p><p></p><p>only</p>'), 'only');
      expect(markdownFromLegacyHtml('one\n\n\n\ntwo'), 'one\n\n\n\ntwo');
      expect(
        markdownFromLegacyHtml('one < 5\n\n\n\ntwo'),
        'one < 5\n\n\n\ntwo',
      );
    });

    test('is idempotent', () {
      // The guard for the real failure mode: whatever this produces is what
      // super_editor serializes back and what the next edit persists, so a
      // second pass over its own output must not degrade further.
      const corpus = <String>[
        '',
        'plain text',
        '# Terms\n\n- **Net 30**\n- Late fee 2%',
        '<p>Intro</p><ul><li>One</li><li>Two</li></ul><p>Outro</p>',
        '<ol><li>A<ul><li>B</li></ul></li></ol>',
        '<h2>Title</h2><p>a <strong>bold</strong> word</p>',
        '<p>see <a href="https://x.test">this</a></p>',
        '<table><tr><td>a</td><td>b</td></tr></table>',
        'Fee applies if qty < table rate > 10 units',
        'one\n\n\n\ntwo',
        '<p>a&nbsp;b &amp; c</p>',
      ];
      for (final input in corpus) {
        final once = markdownFromLegacyHtml(input);
        expect(
          markdownFromLegacyHtml(once),
          once,
          reason: 'not idempotent for: $input',
        );
      }
    });
  });
}
