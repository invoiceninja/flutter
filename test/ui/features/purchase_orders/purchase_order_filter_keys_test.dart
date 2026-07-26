import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/services/tags_api.dart';
import 'package:admin/ui/core/list/search/custom_field_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_filter_keys.dart';

/// Purchase orders reuse the **invoice** custom-field slots — there are no
/// `purchase_order1..4` keys server-side, and every other PO surface passes
/// `prefix: 'invoice'` (see `purchase_order_detail_screen.dart`). Reading a
/// non-existent slot yields an empty label, which makes
/// `CustomFieldFilterKey.isAvailable` false — so the PO list silently offers no
/// `custom1:`…`custom4:` filters at all.
void main() {
  late AppDatabase db;
  late TagRepository tags;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tags = TagRepository(db: db, api: _StubTagsApi());
  });

  tearDown(() async {
    await db.close();
  });

  void disposeKeys(List<FilterKey> keys) {
    for (final k in keys) {
      k.dispose();
    }
  }

  test('custom-field filters read the invoice slots', () {
    final keys = buildPurchaseOrderFilterKeys(
      tags: tags,
      companyId: 'co',
      company: const Company(
        customFields: {'invoice1': 'Cost centre', 'invoice3': 'Approver'},
      ),
    );
    final custom = keys.whereType<CustomFieldFilterKey>().toList();
    expect(custom, hasLength(4));
    expect(custom[0].configuredLabel, 'Cost centre');
    expect(custom[1].configuredLabel, isEmpty);
    expect(custom[2].configuredLabel, 'Approver');
    expect(custom[3].configuredLabel, isEmpty);
    disposeKeys(keys);
  });
}

class _StubTagsApi implements TagsApi {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
