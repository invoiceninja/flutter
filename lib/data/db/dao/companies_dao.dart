import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/tables/companies_table.dart';

part 'companies_dao.g.dart';

@DriftAccessor(tables: [Companies, Accounts])
class CompaniesDao extends DatabaseAccessor<AppDatabase>
    with _$CompaniesDaoMixin {
  CompaniesDao(super.db);

  Future<List<CompanyRow>> all() => select(companies).get();
  Stream<List<CompanyRow>> watchAll() =>
      select(companies).watch().distinctRows();

  Future<CompanyRow?> byId(String id) =>
      (select(companies)
            ..where((c) => c.id.equals(id))
            ..limit(1))
          .getSingleOrNull();

  Stream<CompanyRow?> watchById(String id) =>
      (select(companies)
            ..where((c) => c.id.equals(id))
            ..limit(1))
          .watchSingleOrNull();

  Future<void> upsertAll(List<CompaniesCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(companies, rows));
  }

  /// Advance only the delta watermark, leaving every other column alone.
  ///
  /// `_persistAndActivate` skips the full row write for a company whose
  /// settings edit is still queued in the outbox (that row IS the dirty
  /// marker). Without this the watermark would freeze for as long as the edit
  /// is parked, so each later `/refresh` would re-request a wider delta.
  Future<void> touchLastSyncAt({
    required String companyId,
    required int at,
  }) async {
    await (update(companies)..where((c) => c.id.equals(companyId))).write(
      CompaniesCompanion(lastSyncAt: Value(at)),
    );
  }

  Future<AccountRow?> account() =>
      (select(accounts)..limit(1)).getSingleOrNull();

  Stream<AccountRow?> watchAccount() =>
      (select(accounts)..limit(1)).watchSingleOrNull();

  Future<void> upsertAccount(AccountsCompanion row) =>
      into(accounts).insertOnConflictUpdate(row);

  Future<void> wipe() async {
    await transaction(() async {
      await delete(companies).go();
      await delete(accounts).go();
    });
  }
}
