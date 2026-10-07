import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/features/clients/widgets/client_actions.dart';

import '../shell/_shell_test_helpers.dart';

/// Gating coverage for `ClientActions.itemsFor` — the single source of truth
/// for which actions a client surfaces. Mirrors admin-portal / React:
///   - soft-deleted clients show only Restore + Purge,
///   - Merge + Purge are admin/owner-only,
///   - Client Portal is enabled only when a contact has a portal link,
///   - the New menu offers Recurring Invoice + Credit.
Client _client({
  String id = 'c1',
  bool isDeleted = false,
  int archivedAt = 0,
  String balance = '0',
  String paidToDate = '0',
  String phone = '',
  List<ContactApi> contacts = const [],
}) => Client.fromApi(
  ClientApi(
    id: id,
    name: 'Acme',
    updatedAt: 1,
    isDeleted: isDeleted,
    archivedAt: archivedAt,
    balance: balance,
    paidToDate: paidToDate,
    phone: phone,
    contacts: contacts,
  ),
);

void main() {
  // Builds a real in-memory Services with a session for [isAdmin]/[isOwner],
  // pumps a Builder, and returns whatever `itemsFor` produced for [client].
  Future<List<EntityActionItem<ClientAction>>> resolveItems(
    WidgetTester tester, {
    required Client client,
    bool isAdmin = true,
    bool isOwner = true,
    String permissions = '',
  }) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(
          id: 'co1',
          name: 'Co',
          isAdmin: isAdmin,
          isOwner: isOwner,
          permissions: permissions,
        ),
      ],
    );
    addTearDown(fixture.dispose);

    late List<EntityActionItem<ClientAction>> items;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            items = ClientActions.itemsFor(context, client, (_) {});
            return const SizedBox();
          },
        ),
      ),
    );
    return items;
  }

  Set<ClientAction> kindsOf(List<EntityActionItem<ClientAction>> items) =>
      items.map((i) => i.kind).toSet();

  testWidgets('admin sees merge, purge and client portal on an active client', (
    tester,
  ) async {
    final items = await resolveItems(
      tester,
      client: _client(
        contacts: const [
          ContactApi(link: 'https://portal.example/x', isPrimary: true),
        ],
      ),
    );
    final kinds = kindsOf(items);
    expect(kinds, contains(ClientAction.merge));
    expect(kinds, contains(ClientAction.purge));
    expect(kinds, contains(ClientAction.clientPortal));

    final portal = items.firstWhere((i) => i.kind == ClientAction.clientPortal);
    expect(portal.enabled, isTrue, reason: 'primary contact has a link');
  });

  testWidgets('New menu includes Recurring Invoice + Credit', (tester) async {
    final items = await resolveItems(tester, client: _client());
    final newGroup = items.firstWhere((i) => i.kind == ClientAction.newGroup);
    final childKinds = newGroup.children!.map((i) => i.kind).toSet();
    expect(childKinds, contains(ClientAction.newInvoice));
    expect(childKinds, contains(ClientAction.newRecurringInvoice));
    expect(childKinds, contains(ClientAction.newCredit));
  });

  testWidgets('non-admin/owner sees neither merge nor purge', (tester) async {
    final items = await resolveItems(
      tester,
      client: _client(),
      isAdmin: false,
      isOwner: false,
    );
    final kinds = kindsOf(items);
    expect(kinds, isNot(contains(ClientAction.merge)));
    expect(kinds, isNot(contains(ClientAction.purge)));
  });

  testWidgets('soft-deleted client shows only restore + purge', (tester) async {
    final items = await resolveItems(tester, client: _client(isDeleted: true));
    // Copy Link is state-independent: a soft-deleted record is still a real
    // record with a real id, and a colleague following the link should land on
    // it (and see that it's deleted) rather than on nothing.
    expect(kindsOf(items), {
      ClientAction.copyLink,
      ClientAction.restore,
      ClientAction.purge,
    });
  });

  group('archive, restore and delete need edit_client', () {
    // The server authorizes all three through the edit policy. Ungated, a
    // view-only user was offered Restore — one tap, from the record's state
    // banner — for a change the server then refused.
    const lifecycle = {
      ClientAction.archive,
      ClientAction.restore,
      ClientAction.delete,
    };

    testWidgets('a view-only user is offered none of them', (tester) async {
      for (final client in [
        _client(),
        _client(archivedAt: 1700000000),
        _client(isDeleted: true),
      ]) {
        final kinds = kindsOf(
          await resolveItems(
            tester,
            client: client,
            isAdmin: false,
            isOwner: false,
            permissions: 'view_client',
          ),
        );
        expect(kinds.intersection(lifecycle), isEmpty);
      }
    });

    testWidgets('a user who may edit clients gets them, by state', (
      tester,
    ) async {
      Future<Set<ClientAction>> offered(Client client) async => kindsOf(
        await resolveItems(
          tester,
          client: client,
          isAdmin: false,
          isOwner: false,
          permissions: 'edit_client',
        ),
      ).intersection(lifecycle);

      expect(await offered(_client()), {
        ClientAction.archive,
        ClientAction.delete,
      });
      expect(await offered(_client(archivedAt: 1700000000)), {
        ClientAction.restore,
        ClientAction.delete,
      });
      expect(await offered(_client(isDeleted: true)), {ClientAction.restore});
    });
  });

  testWidgets('log call sits beside add comment and is not confirm-gated', (
    tester,
  ) async {
    // Both write the same activity note through the same repo method, so they
    // travel together. `logCall` opens its own capture form, which is exactly
    // the shape CLAUDE.md § Action confirmations says not to put a second
    // prompt in front of.
    final items = await resolveItems(tester, client: _client());
    final kinds = kindsOf(items);
    expect(kinds, contains(ClientAction.addComment));
    expect(kinds, contains(ClientAction.logCall));
    final logCall = items.firstWhere((i) => i.kind == ClientAction.logCall);
    expect(logCall.confirm, isFalse);
  });

  testWidgets('a soft-deleted client offers neither note action', (
    tester,
  ) async {
    final kinds = kindsOf(
      await resolveItems(tester, client: _client(isDeleted: true)),
    );
    expect(kinds, isNot(contains(ClientAction.logCall)));
    expect(kinds, isNot(contains(ClientAction.addComment)));
  });

  testWidgets('copy link is offered on a saved record', (tester) async {
    final items = await resolveItems(tester, client: _client());
    expect(kindsOf(items), contains(ClientAction.copyLink));
  });

  testWidgets('copy link is absent on an unsynced offline create — a tmp_ id '
      'resolves to nothing on the recipient\'s device', (tester) async {
    final items = await resolveItems(tester, client: _client(id: 'tmp_abc'));
    expect(kindsOf(items), isNot(contains(ClientAction.copyLink)));
  });

  testWidgets('client portal is disabled when the contact has no link', (
    tester,
  ) async {
    final items = await resolveItems(
      tester,
      // link defaults to '' — there is no portal for this contact yet.
      client: _client(contacts: const [ContactApi(isPrimary: true)]),
    );
    final portal = items.firstWhere((i) => i.kind == ClientAction.clientPortal);
    expect(portal.enabled, isFalse);
  });

  // ─────────── create actions need the permission, not just the module ───────

  Set<ClientAction> createKinds(List<EntityActionItem<ClientAction>> items) {
    final group = items.where((i) => i.kind == ClientAction.newGroup);
    return group.isEmpty
        ? const {}
        : group.single.children!.map((i) => i.kind).toSet();
  }

  testWidgets('a user who may only create quotes is offered only New Quote', (
    tester,
  ) async {
    // The module being on is not permission to create. This used to offer New
    // Invoice to a user the server would then refuse.
    final items = await resolveItems(
      tester,
      client: _client(),
      isAdmin: false,
      isOwner: false,
      permissions: 'view_client,create_quote',
    );
    expect(createKinds(items), {ClientAction.newQuote});
  });

  testWidgets('with no create permission there is no Create New menu at all', (
    tester,
  ) async {
    final items = await resolveItems(
      tester,
      client: _client(),
      isAdmin: false,
      isOwner: false,
      permissions: 'view_client,edit_client',
    );
    expect(kindsOf(items), isNot(contains(ClientAction.newGroup)));
  });

  testWidgets('create_all covers every create action', (tester) async {
    final items = await resolveItems(
      tester,
      client: _client(),
      isAdmin: false,
      isOwner: false,
      permissions: 'create_all',
    );
    expect(
      createKinds(items),
      containsAll([ClientAction.newInvoice, ClientAction.newPayment]),
    );
  });

  // ─────────── the quick-action strip ───────────

  Future<List<ClientAction>> quickKinds(
    WidgetTester tester, {
    required Client client,
    bool tapToCall = false,
    int max = 4,
  }) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Co', isAdmin: true)],
    );
    addTearDown(fixture.dispose);
    await fixture.services.phoneActions.setTapToCall(tapToCall);

    late List<EntityQuickAction<ClientAction>> picked;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            picked = pickQuickActions(
              ClientActions.quickItemsFor(context, client, (_) {}),
              max: max,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return [for (final q in picked) q.item.kind];
  }

  const linked = [
    ContactApi(
      id: 'k1',
      firstName: 'Jane',
      isPrimary: true,
      link: 'https://portal.example/x',
    ),
  ];

  testWidgets('a client who owes money leads with billing and payment', (
    tester,
  ) async {
    final kinds = await quickKinds(
      tester,
      client: _client(balance: '100', contacts: linked),
    );
    expect(kinds, [
      ClientAction.newInvoice,
      ClientAction.newPayment,
      ClientAction.viewStatement,
      ClientAction.clientPortal,
    ]);
  });

  testWidgets('with nothing owed and no history, payment and statement yield', (
    tester,
  ) async {
    // Taking a payment and printing a statement are pointless on a client
    // with no balance and no history; a tile for either would push out one
    // that is useful. Both stay in the menu.
    final kinds = await quickKinds(tester, client: _client(contacts: linked));
    expect(kinds, [
      ClientAction.newInvoice,
      ClientAction.clientPortal,
      ClientAction.newQuote,
      ClientAction.newTask,
    ]);
  });

  testWidgets('a paid-up client with history still gets a statement', (
    tester,
  ) async {
    final kinds = await quickKinds(tester, client: _client(paidToDate: '50'));
    expect(kinds, contains(ClientAction.viewStatement));
    expect(kinds, isNot(contains(ClientAction.newPayment)));
  });

  testWidgets('Call needs both the preference and a number to dial', (
    tester,
  ) async {
    final withPhone = _client(balance: '100', phone: '+1 555 0100');
    expect(
      await quickKinds(tester, client: withPhone, tapToCall: true),
      contains(ClientAction.call),
    );
    expect(
      await quickKinds(tester, client: withPhone),
      isNot(contains(ClientAction.call)),
      reason: 'tap to call is off',
    );
    expect(
      await quickKinds(
        tester,
        client: _client(balance: '100'),
        tapToCall: true,
      ),
      isNot(contains(ClientAction.call)),
      reason: 'nothing to dial',
    );
  });

  testWidgets('Call is a quick action only — it is not in the menu', (
    tester,
  ) async {
    // `itemsFor` also feeds the list row's menu and the edit screen, neither
    // of which sits under a `PhoneActionsScope`.
    final items = await resolveItems(
      tester,
      client: _client(phone: '+1 555 0100'),
    );
    expect(kindsOf(items), isNot(contains(ClientAction.call)));
  });

  testWidgets('a deleted or unsynced client has no quick actions', (
    tester,
  ) async {
    expect(
      await quickKinds(tester, client: _client(isDeleted: true, balance: '9')),
      isEmpty,
    );
    // An unsynced client would answer every tile with "sync first"; the
    // banner says that once instead.
    expect(
      await quickKinds(
        tester,
        client: _client(id: 'tmp_1', balance: '9'),
      ),
      isEmpty,
    );
  });

  // ─────────── step 2: email, new project, menu groups ───────────

  testWidgets('Email appears when a contact has a usable address', (
    tester,
  ) async {
    const withEmail = [
      ContactApi(id: 'k1', firstName: 'Jane', email: 'jane@acme.io'),
    ];
    expect(
      await quickKinds(tester, client: _client(contacts: withEmail)),
      contains(ClientAction.email),
    );
    expect(
      await quickKinds(tester, client: _client()),
      isNot(contains(ClientAction.email)),
      reason: 'nobody to write to',
    );
    const hostile = [
      ContactApi(id: 'k1', firstName: 'X', email: 'x@acme.io?bcc=y@evil.io'),
    ];
    expect(
      await quickKinds(tester, client: _client(contacts: hostile)),
      isNot(contains(ClientAction.email)),
      reason: 'not one plain address',
    );
  });

  testWidgets('Create New offers a project, like every other related tab', (
    tester,
  ) async {
    final items = await resolveItems(tester, client: _client());
    expect(createKinds(items), contains(ClientAction.newProject));
  });

  testWidgets('the menu is grouped, and day-to-day actions come first', (
    tester,
  ) async {
    final items = await resolveItems(tester, client: _client());
    final kinds = [for (final i in items) i.kind];
    int at(ClientAction a) => kinds.indexOf(a);
    // Notes and creating records sit ahead of the record-keeping tools.
    expect(at(ClientAction.addComment), lessThan(at(ClientAction.newGroup)));
    expect(at(ClientAction.newGroup), lessThan(at(ClientAction.assignGroup)));
    expect(at(ClientAction.assignGroup), lessThan(at(ClientAction.clone)));
    final starts = {
      for (final i in items)
        if (i.startsGroup) i.kind,
    };
    expect(starts, {
      ClientAction.addComment,
      ClientAction.newGroup,
      ClientAction.assignGroup,
    });
  });
}
