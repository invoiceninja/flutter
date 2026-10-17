import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';

/// `isBlank` decides whether the table's empty row becomes a real line and
/// whether the save-time strip drops one. The wide table's Description cell
/// is multi-line, so Return types a newline there — a description of nothing
/// but whitespace prints nothing and must not keep a line alive.
void main() {
  test('an empty line is blank', () {
    expect(emptyLineItem().isBlank, isTrue);
  });

  test('a whitespace-only description is blank', () {
    expect(emptyLineItem().copyWith(notes: ' \n\t ').isBlank, isTrue);
  });

  test('a description with text is not blank', () {
    expect(emptyLineItem().copyWith(notes: 'x').isBlank, isFalse);
    expect(emptyLineItem().copyWith(notes: '\nx').isBlank, isFalse);
  });
}
