import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/api/task_api_model.dart';

import '../../ui/features/shell/_shell_test_helpers.dart';

/// The two local queries a record screen adds a total up from —
/// `watchForVendor` (what was spent with a vendor) and `watchForProject` (the
/// hours on a project) — with `activeClientsOnly`.
///
/// `RelatedRowsProof` shows such a total only when the device holds as many
/// rows as the server counted. The count and the fetch both go out with
/// `without_deleted_clients=true`, which the server reads as "the client is
/// neither deleted **nor archived**" (`QueryFilters::without_deleted_clients`).
/// A watch that still returned those clients' rows could reach the count with
/// rows the count does not include — and call an incomplete set complete.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Services> seeded() async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
      closeStreamsSynchronously: true,
    );
    addTearDown(fixture.dispose);
    final s = fixture.services;
    Future<void> client(
      String id, {
      int archivedAt = 0,
      bool isDeleted = false,
    }) => s.clients.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: ClientApi(
        id: id,
        name: id,
        displayName: id,
        archivedAt: archivedAt,
        isDeleted: isDeleted,
        updatedAt: 1710000000,
        createdAt: 1700000000,
      ),
    );
    await client('active');
    await client('archived', archivedAt: 1710000000);
    await client('deleted', isDeleted: true);
    return s;
  }

  test('a vendor\'s expenses: those billed to an archived or deleted client '
      'are left out', () async {
    final s = await seeded();
    for (final (id, clientId) in [
      ('e_active', 'active'),
      ('e_archived', 'archived'),
      ('e_deleted', 'deleted'),
      ('e_none', ''),
    ]) {
      await s.expenses.applyUpdateResponse(
        companyId: 'co1',
        serverResponse: ExpenseApi(
          id: id,
          vendorId: 'v1',
          clientId: clientId,
          amount: '10.00',
          currencyId: '1',
          date: '2024-03-10',
          updatedAt: 1710000000,
        ),
      );
    }

    final all = await s.expenses
        .watchForVendor(companyId: 'co1', vendorId: 'v1')
        .first;
    expect(
      all.map((e) => e.id),
      unorderedEquals(['e_active', 'e_archived', 'e_deleted', 'e_none']),
      reason: 'the default is unchanged — the Ledger tab reads every one',
    );

    final counted = await s.expenses
        .watchForVendor(
          companyId: 'co1',
          vendorId: 'v1',
          activeClientsOnly: true,
        )
        .first;
    expect(counted.map((e) => e.id), unorderedEquals(['e_active', 'e_none']));
  });

  test('a project\'s tasks: those of an archived or deleted client are left '
      'out', () async {
    final s = await seeded();
    for (final (id, clientId) in [
      ('t_active', 'active'),
      ('t_archived', 'archived'),
      ('t_deleted', 'deleted'),
      ('t_none', ''),
    ]) {
      await s.tasks.applyUpdateResponse(
        companyId: 'co1',
        serverResponse: TaskApi(
          id: id,
          projectId: 'p1',
          clientId: clientId,
          description: id,
          timeLog: '[]',
          updatedAt: 1710000000,
          createdAt: 1700000000,
        ),
      );
    }

    final all = await s.tasks
        .watchForProject(companyId: 'co1', projectId: 'p1')
        .first;
    expect(
      all.map((t) => t.id),
      unorderedEquals(['t_active', 't_archived', 't_deleted', 't_none']),
      reason: 'the default is unchanged — Invoice Project reads every one',
    );

    final counted = await s.tasks
        .watchForProject(
          companyId: 'co1',
          projectId: 'p1',
          activeClientsOnly: true,
        )
        .first;
    expect(counted.map((t) => t.id), unorderedEquals(['t_active', 't_none']));
  });
}
