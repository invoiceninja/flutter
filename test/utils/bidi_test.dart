import 'package:flutter_test/flutter_test.dart';

import 'package:admin/utils/bidi.dart';
import 'package:admin/utils/file_names.dart';
import 'package:admin/utils/search_fold.dart';

void main() {
  test('stripBidiControls removes isolates, marks and embeddings only', () {
    expect(stripBidiControls(ltrIsolate('Saved.')), 'Saved.');
    expect(stripBidiControls(firstStrongIsolate(r'-$5')), r'-$5');
    expect(stripBidiControls('\u200Eabc\u202Bdef\u202C'), 'abcdef');
    expect(stripBidiControls('فاتورة 42'), 'فاتورة 42');
  });

  test('search folding ignores the isolates a right-to-left tr() adds', () {
    expect(
      foldSearchText(ltrIsolate('Overdue')).startsWith(foldSearchText('ov')),
      isTrue,
    );
  });

  test('a file name never carries bidi controls', () {
    expect(sanitizeFileName(ltrIsolate('Invoice 42')), 'Invoice 42');
  });
}
