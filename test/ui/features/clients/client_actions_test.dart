import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
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
  List<ContactApi> contacts = const [],
}) => Client.fromApi(
  ClientApi(
    id: id,
    name: 'Acme',
    updatedAt: 1,
    isDeleted: isDeleted,
    archivedAt: archivedAt,
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
  }) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(id: 'co1', name: 'Co', isAdmin: isAdmin, isOwner: isOwner),
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
}
