import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

typedef _Row = ({bool archived, bool deleted, bool blocked});

void main() {
  Future<void> noop(String _) async {}

  bool deleteEligible(_Row row, {bool Function(_Row)? canDelete}) {
    final actions = standardCrudBulkActions<_Row>(
      isArchived: (r) => r.archived,
      isDeleted: (r) => r.deleted,
      archive: noop,
      restore: noop,
      delete: noop,
      canDelete: canDelete,
    );
    return actions.firstWhere((a) => a.id == 'delete').eligible(row);
  }

  const live = (archived: false, deleted: false, blocked: false);
  const blocked = (archived: false, deleted: false, blocked: true);
  const deleted = (archived: false, deleted: true, blocked: false);

  test('without canDelete, any row not already deleted is eligible', () {
    expect(deleteEligible(live), isTrue);
    expect(deleteEligible(blocked), isTrue);
    expect(deleteEligible(deleted), isFalse);
  });

  test('canDelete narrows delete eligibility (a payment on a deleted '
      'invoice is skipped rather than queued to dead-letter)', () {
    bool canDelete(_Row r) => !r.blocked;
    expect(deleteEligible(live, canDelete: canDelete), isTrue);
    expect(deleteEligible(blocked, canDelete: canDelete), isFalse);
    expect(deleteEligible(deleted, canDelete: canDelete), isFalse);
  });
}
