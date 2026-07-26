import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_actions.dart';

import '../../shell/_shell_test_helpers.dart';

/// Gating coverage for `VendorActions.itemsFor`, mirroring the harness in
/// `purchase_order_actions_test.dart`. Vendors were one of three feature areas
/// with no `test/ui/features/<name>/` directory at all.
///
/// Rules the source documents:
///   - **Vendor portal** needs a portal link on the primary contact (falling
///     back to the first), and a synced vendor — a `tmp_` vendor's contacts
///     carry no server link, so the action disables rather than opening a
///     dead URL;
///   - **Merge** is admin/owner-only, hidden on a deleted vendor, and disabled
///     on an archived or `tmp_` one (destructive + server round-trip);
///   - the three "new …" shortcuts each hang off their entity's module flag.
Vendor _vendor({
  String id = 'v1',
  List<VendorContactApi> contacts = const [],
  bool isDeleted = false,
  int archivedAt = 0,
}) => Vendor.fromApi(
  VendorApi(
    id: id,
    contacts: contacts,
    isDeleted: isDeleted,
    archivedAt: archivedAt,
  ),
);

void main() {
  Future<List<EntityActionItem<VendorAction>>> resolveItems(
    WidgetTester tester,
    Vendor vendor, {
    bool isAdmin = true,
    int enabledModules = 32767,
  }) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(
          id: 'co1',
          name: 'Co',
          isOwner: isAdmin,
          isAdmin: isAdmin,
          enabledModules: enabledModules,
        ),
      ],
    );
    addTearDown(fixture.dispose);

    late List<EntityActionItem<VendorAction>> items;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            items = VendorActions.itemsFor(context, vendor, (_) {});
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return items;
  }

  bool enabled(List<EntityActionItem<VendorAction>> items, VendorAction kind) {
    final match = flattenActionItems(items).where((i) => i.kind == kind);
    return match.isNotEmpty && match.first.enabled;
  }

  bool present(List<EntityActionItem<VendorAction>> items, VendorAction kind) =>
      flattenActionItems(items).any((i) => i.kind == kind);

  group('vendor portal — needs a real link on a synced vendor', () {
    testWidgets('disabled when the vendor has no contacts', (tester) async {
      final items = await resolveItems(tester, _vendor());

      expect(enabled(items, VendorAction.vendorPortal), isFalse);
    });

    testWidgets('disabled when the contact carries no link', (tester) async {
      final items = await resolveItems(
        tester,
        _vendor(contacts: const [VendorContactApi(id: 'c1', isPrimary: true)]),
      );

      expect(enabled(items, VendorAction.vendorPortal), isFalse);
    });

    testWidgets('enabled from the primary contact link', (tester) async {
      final items = await resolveItems(
        tester,
        _vendor(
          contacts: const [
            VendorContactApi(id: 'c1', link: 'https://portal/a'),
            VendorContactApi(id: 'c2', isPrimary: true, link: 'https://p/b'),
          ],
        ),
      );

      expect(enabled(items, VendorAction.vendorPortal), isTrue);
    });

    testWidgets('falls back to the first contact when none is primary', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _vendor(
          contacts: const [
            VendorContactApi(id: 'c1', link: 'https://portal/a'),
            VendorContactApi(id: 'c2'),
          ],
        ),
      );

      expect(enabled(items, VendorAction.vendorPortal), isTrue);
    });

    testWidgets('disabled on a tmp_ vendor even with a link', (tester) async {
      final items = await resolveItems(
        tester,
        _vendor(
          id: 'tmp_abc',
          contacts: const [
            VendorContactApi(id: 'c1', isPrimary: true, link: 'https://p/b'),
          ],
        ),
      );

      expect(
        enabled(items, VendorAction.vendorPortal),
        isFalse,
        reason: 'an unsynced vendor has no server-side portal link yet',
      );
    });
  });

  group('merge — admin/owner only, active and synced', () {
    testWidgets('present and enabled for an admin on a live vendor', (
      tester,
    ) async {
      final items = await resolveItems(tester, _vendor());

      expect(enabled(items, VendorAction.merge), isTrue);
    });

    testWidgets('hidden entirely for a non-admin', (tester) async {
      final items = await resolveItems(tester, _vendor(), isAdmin: false);

      expect(present(items, VendorAction.merge), isFalse);
    });

    testWidgets('hidden on a deleted vendor', (tester) async {
      final items = await resolveItems(tester, _vendor(isDeleted: true));

      expect(present(items, VendorAction.merge), isFalse);
    });

    testWidgets('disabled on an archived vendor', (tester) async {
      final items = await resolveItems(tester, _vendor(archivedAt: 1700000000));

      expect(enabled(items, VendorAction.merge), isFalse);
    });

    testWidgets('disabled on a tmp_ vendor', (tester) async {
      final items = await resolveItems(tester, _vendor(id: 'tmp_abc'));

      expect(enabled(items, VendorAction.merge), isFalse);
    });
  });

  group('the "new …" shortcuts follow their module flags', () {
    testWidgets('all present with every module enabled', (tester) async {
      final items = await resolveItems(tester, _vendor());

      expect(present(items, VendorAction.newExpense), isTrue);
      expect(present(items, VendorAction.newPurchaseOrder), isTrue);
      expect(present(items, VendorAction.newRecurringExpense), isTrue);
    });

    testWidgets('all absent with modules off', (tester) async {
      final items = await resolveItems(tester, _vendor(), enabledModules: 0);

      expect(present(items, VendorAction.newExpense), isFalse);
      expect(present(items, VendorAction.newPurchaseOrder), isFalse);
      expect(present(items, VendorAction.newRecurringExpense), isFalse);
    });
  });

  group('lifecycle actions reflect entity state', () {
    testWidgets('a live vendor offers archive, not restore', (tester) async {
      final items = await resolveItems(tester, _vendor());

      expect(present(items, VendorAction.archive), isTrue);
      expect(present(items, VendorAction.restore), isFalse);
    });

    testWidgets('an archived vendor offers restore, not archive', (
      tester,
    ) async {
      final items = await resolveItems(tester, _vendor(archivedAt: 1700000000));

      expect(present(items, VendorAction.restore), isTrue);
      expect(present(items, VendorAction.archive), isFalse);
    });

    testWidgets('a deleted vendor offers restore', (tester) async {
      final items = await resolveItems(tester, _vendor(isDeleted: true));

      expect(present(items, VendorAction.restore), isTrue);
    });
  });

  testWidgets('edit, clone and comment are always available', (tester) async {
    final items = await resolveItems(tester, _vendor(isDeleted: true));

    expect(enabled(items, VendorAction.edit), isTrue);
    expect(enabled(items, VendorAction.clone), isTrue);
    expect(enabled(items, VendorAction.addComment), isTrue);
  });
}
