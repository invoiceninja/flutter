import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_actions.dart';

import '../../shell/_shell_test_helpers.dart';

/// Gating coverage for `VendorActions.itemsFor` and `quickItemsFor`.
///
/// Rules the source documents:
///   - **Vendor portal** needs a portal link on the primary contact (falling
///     back to the first), and a synced vendor — a `tmp_` vendor's contacts
///     carry no server link, so the action disables rather than opening a
///     dead URL;
///   - **Merge** is admin/owner-only, hidden on a deleted vendor, and disabled
///     on an archived or `tmp_` one (destructive + server round-trip);
///   - the three "new …" shortcuts each need their module **and** the
///     `create_<entity>` permission;
///   - archive, restore and delete need `edit_vendor`;
///   - a deleted vendor offers only what still works on one;
///   - the quick-action strip is a second render of those same items, most
///     used first, and empty for a vendor nothing can be done with yet.
Vendor _vendor({
  String id = 'v1',
  String phone = '',
  List<VendorContactApi> contacts = const [],
  bool isDeleted = false,
  int archivedAt = 0,
}) => Vendor.fromApi(
  VendorApi(
    id: id,
    name: 'Acme',
    phone: phone,
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
    String permissions = '',
  }) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(
          id: 'co1',
          name: 'Co',
          isOwner: isAdmin,
          isAdmin: isAdmin,
          enabledModules: enabledModules,
          permissions: permissions,
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

  group('the "new …" shortcuts need the module and the permission', () {
    testWidgets('all present with every module enabled', (tester) async {
      final items = await resolveItems(tester, _vendor());

      expect(present(items, VendorAction.newExpense), isTrue);
      expect(present(items, VendorAction.newPurchaseOrder), isTrue);
      expect(present(items, VendorAction.newRecurringExpense), isTrue);
    });

    testWidgets('they sit together under Create New', (tester) async {
      // Three creates inline made a twelve-row menu out of a vendor.
      final items = await resolveItems(tester, _vendor());
      final group = items.singleWhere((i) => i.kind == VendorAction.newGroup);

      expect(
        [for (final c in group.children!) c.kind],
        [
          VendorAction.newExpense,
          VendorAction.newPurchaseOrder,
          VendorAction.newRecurringExpense,
        ],
      );
      expect(items.any((i) => i.kind == VendorAction.newExpense), isFalse);
    });

    testWidgets('all absent with modules off — and no empty group', (
      tester,
    ) async {
      final items = await resolveItems(tester, _vendor(), enabledModules: 0);

      expect(present(items, VendorAction.newExpense), isFalse);
      expect(present(items, VendorAction.newPurchaseOrder), isFalse);
      expect(present(items, VendorAction.newRecurringExpense), isFalse);
      expect(present(items, VendorAction.newGroup), isFalse);
    });

    testWidgets('the module alone is not enough: each needs create_<entity>', (
      tester,
    ) async {
      // The module used to decide on its own, which offered New Expense to a
      // user the server would then refuse.
      final items = await resolveItems(
        tester,
        _vendor(),
        isAdmin: false,
        permissions: 'view_vendor,edit_vendor,create_expense',
      );

      expect(present(items, VendorAction.newExpense), isTrue);
      expect(present(items, VendorAction.newPurchaseOrder), isFalse);
      expect(present(items, VendorAction.newRecurringExpense), isFalse);
    });

    testWidgets('edit rights never imply create', (tester) async {
      final items = await resolveItems(
        tester,
        _vendor(),
        isAdmin: false,
        permissions: 'view_vendor,edit_vendor,edit_expense',
      );

      expect(present(items, VendorAction.newExpense), isFalse);
    });
  });

  group('lifecycle actions reflect entity state', () {
    testWidgets('a live vendor offers archive, not restore', (tester) async {
      final items = await resolveItems(tester, _vendor());

      expect(present(items, VendorAction.archive), isTrue);
      expect(present(items, VendorAction.delete), isTrue);
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

  group('archive, restore and delete need edit_vendor', () {
    // The server authorizes all three through the edit policy. Ungated, a
    // view-only user was offered Restore — one tap from the record's state
    // banner — for a mutation the server refuses.
    testWidgets('a view-only user is offered none of them', (tester) async {
      final live = await resolveItems(
        tester,
        _vendor(),
        isAdmin: false,
        permissions: 'view_vendor',
      );
      expect(present(live, VendorAction.archive), isFalse);
      expect(present(live, VendorAction.delete), isFalse);

      final archived = await resolveItems(
        tester,
        _vendor(archivedAt: 1700000000),
        isAdmin: false,
        permissions: 'view_vendor',
      );
      expect(present(archived, VendorAction.restore), isFalse);
    });

    testWidgets('edit_vendor is enough', (tester) async {
      final live = await resolveItems(
        tester,
        _vendor(),
        isAdmin: false,
        permissions: 'edit_vendor',
      );
      expect(present(live, VendorAction.archive), isTrue);
      expect(present(live, VendorAction.delete), isTrue);

      final deleted = await resolveItems(
        tester,
        _vendor(isDeleted: true),
        isAdmin: false,
        permissions: 'edit_vendor',
      );
      expect(present(deleted, VendorAction.restore), isTrue);
    });
  });

  testWidgets('edit, clone and the note actions are there on a live vendor', (
    tester,
  ) async {
    final items = await resolveItems(tester, _vendor());

    expect(enabled(items, VendorAction.edit), isTrue);
    expect(enabled(items, VendorAction.clone), isTrue);
    expect(enabled(items, VendorAction.addComment), isTrue);
    expect(enabled(items, VendorAction.logCall), isTrue);
  });

  testWidgets('a deleted vendor offers only what still works on one', (
    tester,
  ) async {
    // The server refuses an edit of a deleted record, and the screen says
    // "This record is deleted. Restore it to make changes." — a menu that
    // still offered Edit, Add Comment and New Expense would contradict it.
    final items = await resolveItems(
      tester,
      _vendor(
        isDeleted: true,
        contacts: const [
          VendorContactApi(id: 'c1', isPrimary: true, link: 'https://p/b'),
        ],
      ),
    );

    expect(
      [for (final i in flattenActionItems(items)) i.kind],
      [VendorAction.copyLink, VendorAction.restore],
    );
  });

  testWidgets('Call and Email are quick actions only — not in the menu', (
    tester,
  ) async {
    // `itemsFor` also feeds the list row's menu and the edit screen, neither
    // of which sits under a `PhoneActionsScope`.
    final items = await resolveItems(
      tester,
      _vendor(
        phone: '+1 555 0100',
        contacts: const [
          VendorContactApi(id: 'c1', firstName: 'A', email: 'a@acme.test'),
        ],
      ),
    );

    expect(present(items, VendorAction.call), isFalse);
    expect(present(items, VendorAction.email), isFalse);
  });

  // ─────────── the quick-action strip ───────────

  Future<List<EntityQuickAction<VendorAction>>> quick(
    WidgetTester tester,
    Vendor vendor, {
    bool tapToCall = false,
    int max = 6,
    bool isAdmin = true,
    int enabledModules = 32767,
    String permissions = '',
  }) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(
          id: 'co1',
          name: 'Co',
          isOwner: isAdmin,
          isAdmin: isAdmin,
          enabledModules: enabledModules,
          permissions: permissions,
        ),
      ],
    );
    addTearDown(fixture.dispose);
    await fixture.services.phoneActions.setTapToCall(tapToCall);

    late List<EntityQuickAction<VendorAction>> picked;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            picked = pickQuickActions(
              VendorActions.quickItemsFor(context, vendor, (_) {}),
              max: max,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return picked;
  }

  List<VendorAction> kindsOf(List<EntityQuickAction<VendorAction>> picked) => [
    for (final q in picked) q.item.kind,
  ];

  const reachable = [
    VendorContactApi(
      id: 'k1',
      firstName: 'Katrin',
      email: 'katrin@acme.test',
      phone: '+49 30 5550 1213',
      isPrimary: true,
      link: 'https://portal.example/x',
    ),
  ];

  group('quick actions', () {
    testWidgets('most used first: spend, order, write, ring — then the two '
        'that are set up once', (tester) async {
      final picked = await quick(
        tester,
        _vendor(contacts: reachable),
        tapToCall: true,
      );

      expect(kindsOf(picked), [
        VendorAction.newExpense,
        VendorAction.newPurchaseOrder,
        VendorAction.email,
        VendorAction.call,
        VendorAction.newRecurringExpense,
        VendorAction.vendorPortal,
      ]);
    });

    testWidgets('in the pane, the first four', (tester) async {
      final picked = await quick(
        tester,
        _vendor(contacts: reachable),
        tapToCall: true,
        max: 4,
      );

      expect(kindsOf(picked), [
        VendorAction.newExpense,
        VendorAction.newPurchaseOrder,
        VendorAction.email,
        VendorAction.call,
      ]);
    });

    testWidgets('a tile is labelled with the noun, the menu with the phrase', (
      tester,
    ) async {
      final picked = await quick(tester, _vendor(contacts: reachable));
      final labels = {for (final q in picked) q.item.kind: q.shortLabel};

      expect(labels[VendorAction.newExpense], '+ Expense');
      expect(labels[VendorAction.newPurchaseOrder], '+ Order');
      expect(labels[VendorAction.newRecurringExpense], '+ Recurring');
      expect(labels[VendorAction.vendorPortal], 'Vendor Portal');
      // What a tooltip and a screen reader get is still the whole phrase.
      expect(
        picked
            .firstWhere((q) => q.item.kind == VendorAction.newRecurringExpense)
            .item
            .label,
        'New Recurring Expense',
      );
    });

    testWidgets('a vendor nobody can be reached at yields those slots', (
      tester,
    ) async {
      // No address, no number, no portal link: the creates are what is left,
      // and no tile is a dead end.
      final picked = await quick(tester, _vendor(), tapToCall: true);

      expect(kindsOf(picked), [
        VendorAction.newExpense,
        VendorAction.newPurchaseOrder,
        VendorAction.newRecurringExpense,
      ]);
    });

    testWidgets('Call needs both the preference and a number to dial', (
      tester,
    ) async {
      final withPhone = _vendor(phone: '+1 555 0100');
      expect(
        kindsOf(await quick(tester, withPhone, tapToCall: true)),
        contains(VendorAction.call),
      );
      expect(
        kindsOf(await quick(tester, withPhone)),
        isNot(contains(VendorAction.call)),
        reason: 'tap to call is off',
      );
      expect(
        kindsOf(await quick(tester, _vendor(), tapToCall: true)),
        isNot(contains(VendorAction.call)),
        reason: 'nothing to dial',
      );
    });

    testWidgets('a create tile is the menu\'s item, so it obeys the same '
        'gates', (tester) async {
      final picked = await quick(
        tester,
        _vendor(contacts: reachable),
        isAdmin: false,
        permissions: 'view_vendor,create_purchase_order',
      );

      expect(kindsOf(picked), isNot(contains(VendorAction.newExpense)));
      expect(kindsOf(picked), contains(VendorAction.newPurchaseOrder));

      final off = await quick(
        tester,
        _vendor(contacts: reachable),
        enabledModules: 0,
      );
      expect(kindsOf(off), [VendorAction.email, VendorAction.vendorPortal]);
    });

    testWidgets('an archived vendor keeps its tiles', (tester) async {
      // Archived is not read-only: the server still accepts new records.
      final picked = await quick(tester, _vendor(archivedAt: 1700000000));

      expect(kindsOf(picked), contains(VendorAction.newExpense));
    });

    testWidgets('a deleted vendor gets none', (tester) async {
      final picked = await quick(
        tester,
        _vendor(isDeleted: true, contacts: reachable),
        tapToCall: true,
      );

      expect(picked, isEmpty);
    });

    testWidgets('an unsynced vendor gets none', (tester) async {
      // Every tile would answer "sync first"; the banner says that once.
      final picked = await quick(
        tester,
        _vendor(id: 'tmp_abc', contacts: reachable),
        tapToCall: true,
      );

      expect(picked, isEmpty);
    });
  });
}
