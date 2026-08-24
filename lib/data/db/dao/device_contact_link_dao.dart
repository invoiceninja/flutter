import 'package:drift/drift.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/tables/device_contact_links_table.dart';

part 'device_contact_link_dao.g.dart';

/// Reads/writes the device address-book link index (see [DeviceContactLinks]).
///
/// Every query is company-scoped: a device can hold cards for several companies
/// at once, each under its own label, and a reconcile for one must never see
/// (or delete) another's rows.
@DriftAccessor(tables: [DeviceContactLinks])
class DeviceContactLinkDao extends DatabaseAccessor<AppDatabase>
    with _$DeviceContactLinkDaoMixin, CompanyScopedDao {
  DeviceContactLinkDao(super.db);

  /// Every link for [companyId], keyed by `sourceId` — the whole working set
  /// for one reconcile. Bounded by the number of synced cards (thousands at
  /// worst) and each row is tiny, so this is a single read rather than a page
  /// loop.
  Future<Map<String, DeviceContactLinkRow>> byCompany(String companyId) async {
    final rows = await (select(
      deviceContactLinks,
    )..where((l) => l.companyId.equals(companyId))).get();
    return {for (final row in rows) row.sourceId: row};
  }

  /// Every company that has at least one link row. Drives the logout cleanup,
  /// which must reach companies the user hasn't opened this session.
  Future<List<String>> companiesWithLinks() async {
    final q = selectOnly(deviceContactLinks, distinct: true)
      ..addColumns([deviceContactLinks.companyId]);
    final rows = await q.get();
    return [
      for (final row in rows)
        if (row.read(deviceContactLinks.companyId) case final id?) id,
    ];
  }

  Future<void> upsertAll(List<DeviceContactLinksCompanion> links) async {
    if (links.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(deviceContactLinks, links));
  }

  Future<void> deleteBySourceIds({
    required String companyId,
    required List<String> sourceIds,
  }) async {
    if (sourceIds.isEmpty) return;
    await (delete(deviceContactLinks)..where(
          (l) => l.companyId.equals(companyId) & l.sourceId.isIn(sourceIds),
        ))
        .go();
  }

  Future<void> deleteCompany(String companyId) => (delete(
    deviceContactLinks,
  )..where((l) => l.companyId.equals(companyId))).go();
}
