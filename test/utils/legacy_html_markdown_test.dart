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
    });

    test('keeps a blockquote a blockquote', () {
      // The marker used to be dropped, so a quote degraded to a plain
      // paragraph the next time the record was saved from this app.
      expect(
        markdownFromLegacyHtml('<blockquote>quoted</blockquote>'),
        '> quoted',
      );
      // TinyMCE nests a `<p>` inside; the marker must not be stranded on a
      // line of its own, which CommonMark reads as an empty quote.
      expect(
        markdownFromLegacyHtml('<blockquote><p>quoted</p></blockquote>'),
        '> quoted',
      );
      expect(
        markdownFromLegacyHtml('<p>before</p><blockquote>q</blockquote>'),
        'before\n\n> q',
      );
    });

    test('drops an inline tag it has no mapping for, keeping the text', () {
      // These used to be left in place as literal text: the user saw raw
      // markup in the editor, and now that this app writes HTML the writer
      // would escape it into a visible `&lt;span …&gt;` on the web.
      expect(
        markdownFromLegacyHtml(
          '<p>a <span style="color:red">red</span> word</p>',
        ),
        'a red word',
      );
      expect(markdownFromLegacyHtml('<font size="3">big</font>'), 'big');
      expect(markdownFromLegacyHtml('<p><mark>hi</mark></p>'), 'hi');
    });

    test('converts an image to a markdown image', () {
      // Without a rule it fell through as an unmapped inline tag and was
      // painted to the user as raw markup.
      expect(
        markdownFromLegacyHtml('<img src="https://x.test/a.png" alt="a">'),
        '![a](https://x.test/a.png)',
      );
      expect(
        markdownFromLegacyHtml('<p><img src="https://x.test/b.png" /></p>'),
        '![](https://x.test/b.png)',
      );
      // No `src` is nothing to render.
      expect(markdownFromLegacyHtml('<p>x<img alt="a"></p>'), 'x');
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

    test('resolves entities inside a link destination', () {
      // Everywhere else entities are left to `markdown`'s DecodeHtmlSyntax,
      // but nothing downstream decodes inside a link destination — so an
      // `&amp;` in a query string would survive every round trip.
      expect(
        markdownFromLegacyHtml('<a href="https://x.test/?a=1&amp;b=2">l</a>'),
        '[l](https://x.test/?a=1&b=2)',
      );
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
      // Leading blanks emit nothing — the writer never flushes a break
      // before any text has been written.
      expect(markdownFromLegacyHtml('<p></p><p></p><p>only</p>'), 'only');
      // An *interior* one is a blank line the user typed, and four newlines
      // is exactly one empty paragraph node once super_editor parses this.
      expect(
        markdownFromLegacyHtml('<p>one</p><p></p><p>two</p>'),
        'one\n\n\n\ntwo',
      );
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

  group('consecutive <br> accumulate', () {
    // `requestBreak` takes the LARGER of two pending requests, because `</p><p>`
    // asks twice for the one boundary it describes. Consecutive `<br>`s are the
    // opposite — each is a break the author typed — and taking the max folded
    // `a<br><br>b` to `a\nb`, which is byte-identical to what `a<br>b` folds to.
    // So the blank line was gone by the next save, and it was gone from every
    // company's email templates: each server default body is
    // `'<p>$client<br><br>' . <message> . '</p>…'`.
    test('two breaks are two newlines, not one', () {
      expect(markdownFromLegacyHtml('<p>a<br><br>b</p>'), 'a\n\nb');
    });

    test('one break is still one newline', () {
      // The guard on the fix: `a<br>b` and `a<br><br>b` must not agree.
      expect(markdownFromLegacyHtml('<p>a<br>b</p>'), 'a\nb');
    });

    test(
      'a default email template keeps the blank line after the greeting',
      () {
        expect(
          markdownFromLegacyHtml(
            r'<p>$client<br><br>Here is your invoice.</p>'
            r'<div>$view_button</div>',
          ),
          r'$client'
          '\n\n'
          r'Here is your invoice.'
          '\n\n'
          r'$view_button',
        );
      },
    );

    test('a block boundary still merges rather than stacking', () {
      // What `requestBreak`'s max is for, and what a naive "always sum" would
      // break: one paragraph boundary, not two.
      expect(markdownFromLegacyHtml('<p>a</p><p>b</p>'), 'a\n\nb');
    });

    test('inside a list the run is clamped to one, or the list splits', () {
      // A blank line closes the item's paragraph and the text after it is not
      // indented to the item's content column, so CommonMark ends the list —
      // and the re-emit then restarts `<ol>` numbering at 1. The clamp the block
      // arm applies inside a list has to apply to an author break too.
      expect(
        markdownFromLegacyHtml('<ol><li>a<br><br>b</li><li>c</li></ol>'),
        '1. a\nb\n1. c',
      );
      expect(
        markdownFromLegacyHtml('<ul><li>a<br><br><br>b</li></ul>'),
        '- a\nb',
      );
      // A single break inside an item is unchanged.
      expect(markdownFromLegacyHtml('<ul><li>a<br>b</li></ul>'), '- a\nb');
    });

    test('three breaks snap to four — 3 is not a value the encoding defines', () {
      // super_editor reads two blank lines then text as ONE paragraph whose text
      // begins with a newline, which re-emits as `<p>a</p><p><br>b</p>` and folds
      // back to 2 — so passing 3 through would survive one save and lose a break
      // on the next, which is the bug this group exists to fix, one break along.
      expect(markdownFromLegacyHtml('<p>a<br><br><br>b</p>'), 'a\n\n\n\nb');
    });

    test('runs longer than the encoding distinguishes are capped', () {
      // 4 newlines is the most the encoding means anything by (paragraph plus
      // one deliberately blank paragraph), so a wall of breaks saturates there
      // instead of growing without bound.
      expect(
        markdownFromLegacyHtml('<p>a<br><br><br><br><br><br>b</p>'),
        'a\n\n\n\nb',
      );
    });
  });

  group('a marker construct with no text in it', () {
    // `holdBreaks()` was only ever cleared by `writeText`, so a construct
    // containing no text left the flag armed — and `requestBreak` is a no-op
    // while it is. The suppression then ran to the end of the document: the
    // next real text was appended straight onto the stranded marker.
    test('an empty bullet does not swallow the paragraph after the list', () {
      // Was `- Next`: the paragraph became a bullet, and saving persisted it as
      // one.
      expect(
        markdownFromLegacyHtml('<ul><li></li></ul><p>Next</p>'),
        '- \n\nNext',
      );
    });

    test('an empty bullet between two items does not re-nest the second', () {
      // Was `- One\n- - Two`, i.e. the blank item vanished and `Two` moved into
      // a nested list — a visible change to the rendered PDF.
      expect(
        markdownFromLegacyHtml('<ul><li>One</li><li></li><li>Two</li></ul>'),
        '- One\n- \n- Two',
      );
    });

    test("TinyMCE's emptied `<li><p></p></li>` behaves the same", () {
      expect(
        markdownFromLegacyHtml('<ul><li><p></p></li><li><p>Two</p></li></ul>'),
        '- \n- Two',
      );
    });

    test('an empty heading does not swallow what follows', () {
      expect(markdownFromLegacyHtml('<h2></h2><p>Next</p>'), '## \n\nNext');
    });

    test('an empty blockquote does not swallow what follows', () {
      expect(
        markdownFromLegacyHtml('<blockquote></blockquote><p>Next</p>'),
        '> \n\nNext',
      );
    });

    test('a marker WITH text still sits flush against it', () {
      // The behaviour `holdBreaks` exists for, and which the release must not
      // undo: TinyMCE nests a `<p>` inside each `<li>`, and honouring that
      // break would strand the marker on a line of its own.
      expect(
        markdownFromLegacyHtml(
          '<ul><li><p>One</p></li><li><p>Two</p></li></ul>',
        ),
        '- One\n- Two',
      );
      expect(
        markdownFromLegacyHtml('<blockquote><p>quoted</p></blockquote>'),
        '> quoted',
      );
    });
  });
}
