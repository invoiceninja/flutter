import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/document_parent.dart';
import 'package:admin/domain/entity_type.dart';

void main() {
  group('documentParentTypeFromWire', () {
    test('reads every stored wire name back', () {
      for (final entry in kDocumentParentWireNames.entries) {
        expect(documentParentTypeFromWire(entry.value), entry.key);
      }
    });

    test("reads the server's documentable_type, which names a group "
        'group_setting', () {
      expect(
        documentParentTypeFromWire('recurring_invoice'),
        EntityType.recurringInvoice,
      );
      expect(documentParentTypeFromWire('group_setting'), EntityType.group);
    });

    test('reads a morph column class name', () {
      expect(
        documentParentTypeFromWire(r'App\Models\GroupSetting'),
        EntityType.group,
      );
    });

    test('an unknown or empty name is null', () {
      expect(documentParentTypeFromWire('proposal'), isNull);
      expect(documentParentTypeFromWire(''), isNull);
      expect(documentParentTypeFromWire(null), isNull);
    });
  });

  test('a group is still stored as group', () {
    expect(documentParentWireName(EntityType.group), 'group');
  });
}
