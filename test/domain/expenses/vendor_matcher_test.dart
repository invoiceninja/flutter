import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/expenses/vendor_matcher.dart';

/// A receipt's vendor line → one of the company's vendors, or none. A wrong
/// vendor is worse than none: it brings its currency with it.
void main() {
  const vendors = [
    (id: 'shell', name: 'Shell'),
    (id: 'shell-station', name: 'Shell Station'),
    (id: 'blue', name: 'Blue Bottle Coffee'),
    (id: 'roma', name: 'Cafe Roma'),
    (id: 'ab', name: 'AB'),
    (id: 'cafe', name: 'Café Müller'),
  ];

  test('the same name, folded, matches', () {
    expect(matchVendor('BLUE BOTTLE COFFEE', vendors), 'blue');
    expect(matchVendor('Cafe Muller', vendors), 'cafe');
  });

  test("a line that starts with a vendor's whole name matches the most "
      'specific one', () {
    expect(matchVendor('Shell Station Amsterdam', vendors), 'shell-station');
    expect(matchVendor('Shell Express', vendors), 'shell');
    expect(matchVendor('Blue Bottle Coffee Mint St', vendors), 'blue');
  });

  test('containing a name is not naming it', () {
    expect(matchVendor('Cafe', vendors), isNull);
    expect(matchVendor('The Cafe Roma', vendors), isNull);
  });

  test('a two-letter name never matches anything', () {
    expect(matchVendor('AB Plumbing', vendors), isNull);
  });

  test('two equally good vendors are no answer', () {
    expect(
      matchVendor('Acme Supply', const [
        (id: 'a', name: 'Acme'),
        (id: 'b', name: 'ACME'),
      ]),
      isNull,
    );
  });
}
