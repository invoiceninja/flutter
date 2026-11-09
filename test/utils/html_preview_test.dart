import 'package:admin/utils/html_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = "script-src 'none'";

  test('the preview tags go first in <head>', () {
    final out = previewHtml(
      '<html><head lang="en"><script>x()</script></head><body></body></html>',
    );
    expect(out.indexOf(policy), lessThan(out.indexOf('<script>')));
    expect(out, startsWith('<html><head lang="en"><meta'));
    expect(out, contains('<base target="_blank">'));
    expect(out, contains("form-action 'none'"));
    expect(out, contains('color-scheme: light only'));
  });

  test('a document without a head gets the tags first', () {
    final out = previewHtml('<HTML><body>hi</body></HTML>');
    expect(out, startsWith('<meta'));
    expect(out, contains(policy));
  });

  test('after a doctype, never before it (quirks mode)', () {
    final out = previewHtml('<!DOCTYPE html><html><body>hi</body></html>');
    expect(out, startsWith('<!DOCTYPE html><meta'));
  });

  test('the server wrapper (no head) with a pasted email in its body', () {
    // TemplateEngine strips the wrapper's <head>; a full HTML email pasted
    // into the body brings one inside <body>, where a policy is ignored.
    const wrapper =
        '<!DOCTYPE html><html><meta charset="utf-8"><style>p{}</style>'
        '<body><div id="content"><html><head><title>x</title></head>'
        '<body><script>alert(1)</script></body></html></div></body></html>';
    final out = previewHtml(wrapper);
    expect(out, startsWith('<!DOCTYPE html><meta'));
    expect(out.indexOf(policy), lessThan(out.indexOf('<body')));
  });

  test('a fragment gets the tags in front', () {
    final out = previewHtml('<p>Hello</p>');
    expect(out, startsWith('<meta'));
    expect(out, endsWith('<p>Hello</p>'));
  });

  test('a <header> element is not mistaken for <head>', () {
    final out = previewHtml('<header>Top</header><p>x</p>');
    expect(out, startsWith('<meta'));
  });

  test('a <head> inside a comment is not the head', () {
    final out = previewHtml(
      '<!-- <head> --><html><head><script>x()</script></head></html>',
    );
    expect(out, startsWith('<!-- <head> --><html><head><meta'));
  });

  test('a meta refresh is dropped', () {
    final out = previewHtml(
      '<html><head><META HTTP-EQUIV="Refresh" content="0; url=https://x.y">'
      '</head></html>',
    );
    expect(out.toLowerCase(), isNot(contains('refresh')));
    expect(out, contains(policy));
  });
}
