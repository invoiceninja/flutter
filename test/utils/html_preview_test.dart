import 'package:admin/utils/html_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = "script-src 'none'";

  test('the no-script policy goes first in <head>', () {
    final out = htmlWithoutScripts(
      '<html><head lang="en"><script>x()</script></head><body></body></html>',
    );
    expect(out.indexOf(policy), lessThan(out.indexOf('<script>')));
    expect(out, startsWith('<html><head lang="en"><meta'));
  });

  test('a document without a head gets one', () {
    final out = htmlWithoutScripts('<HTML><body>hi</body></HTML>');
    expect(out, startsWith('<HTML><head><meta'));
    expect(out, contains(policy));
  });

  test('a fragment gets the policy in front', () {
    final out = htmlWithoutScripts('<p>Hello</p>');
    expect(out, startsWith('<meta'));
    expect(out, endsWith('<p>Hello</p>'));
  });

  test('a <header> element is not mistaken for <head>', () {
    final out = htmlWithoutScripts('<header>Top</header><p>x</p>');
    expect(out, startsWith('<meta'));
  });
}
