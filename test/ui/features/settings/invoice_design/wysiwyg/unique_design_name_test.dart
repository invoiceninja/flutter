import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_screen.dart';

/// A new design is named for the user, and the server rejects a name another
/// design of the company already has (`unique:designs,name`).
void main() {
  test('the base name when it is free', () {
    expect(
      uniqueDesignName('Visual design', const ['Clean', 'Bold']),
      'Visual design',
    );
  });

  test('the first free numbered name otherwise', () {
    expect(
      uniqueDesignName('Visual design', const ['Visual design']),
      'Visual design 2',
    );
    expect(
      uniqueDesignName('Visual design', const [
        'Visual design',
        'Visual design 2',
        'Visual design 4',
      ]),
      'Visual design 3',
    );
  });

  test('compared trimmed and without case', () {
    expect(
      uniqueDesignName('Visual design', const [' visual DESIGN ']),
      'Visual design 2',
    );
  });
}
