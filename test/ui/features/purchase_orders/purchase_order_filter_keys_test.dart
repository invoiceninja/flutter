import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/tags_api.dart';
import 'package:admin/data/services/vendors_api.dart';
import 'package:admin/ui/core/list/search/client_filter_key.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
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
  late ClientRepository clients;
  late VendorRepository vendors;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tags = TagRepository(db: db, api: _StubTagsApi());
    clients = ClientRepository(db: db, api: _StubClientsApi());
    vendors = VendorRepository(db: db, api: _StubVendorsApi());
  });

  List<FilterKey> build({Company? company}) => buildPurchaseOrderFilterKeys(
    clients: clients,
    vendors: vendors,
    tags: tags,
    companyId: 'co',
    company: company,
  );

  tearDown(() async {
    await db.close();
  });

  void disposeKeys(List<FilterKey> keys) {
    for (final k in keys) {
      k.dispose();
    }
  }

  test('custom-field filters read the invoice slots', () {
    final keys = build(
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

  // The list offered only State, Tags and the custom fields, while the
  // server filters purchase orders by every one of these.
  test('status, vendor, client and both dates are filters', () {
    final keys = build();
    final byId = {for (final k in keys) k.id: k};
    expect(byId.keys, containsAll(<String>['status', 'vendor', 'client']));
    expect(byId['status'], isA<PurchaseOrderStatusFilterKey>());
    expect(
      (byId['vendor']! as PurchaseOrderVendorFilterKey).serverKey,
      'vendor_id',
    );
    expect(byId['vendor']!.singleValue, isTrue, reason: 'vendor_id is one id');
    // The client is a purchase order's secondary party.
    expect((byId['client']! as ClientFilterKey).isPrimary, isFalse);
    final dates = keys.whereType<DateColumnFilterKey>().map((k) => k.id);
    expect(dates, ['date', 'due_date']);
    disposeKeys(keys);
  });
}

class _StubClientsApi implements ClientsApi {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _StubVendorsApi implements VendorsApi {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _StubTagsApi implements TagsApi {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
