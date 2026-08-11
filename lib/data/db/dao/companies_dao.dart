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

  /// Refresh only the columns the server owns outright, leaving every column
  /// the user can edit locally alone.
  ///
  /// `_persistAndActivate` skips the full row write for a company whose
  /// settings edit is still queued in the outbox (that row IS the dirty
  /// marker — this table has no `is_dirty` column). Skipping *everything*
  /// would be wrong in two ways: the delta watermark would freeze for as long
  /// as the edit is parked, so each later `/refresh` would re-request an
  /// ever-wider window; and the per-(user, company) flags would stop healing,
  /// which is the entire reason `restore()` fires a background refresh — an
  /// account owner whose cached row says `is_owner = false` stays silently
  /// downgraded. A 409 parks a row as `pending` for a year, so "as long as the
  /// edit is parked" can mean every launch for a very long time.
  ///
  /// The columns below are safe to write unconditionally because
  /// `CompanyRepository.updateCompany` never touches them — they carry no
  /// local edit that could be clobbered. Two deliberate omissions:
  /// `enabledModules`, which Settings → Account Management → Enabled Modules
  /// writes (so it belongs to the skipped set alongside `settings` and the
  /// top-level company columns); and `token`, because `/refresh` has been
  /// observed returning empty tokens for non-active companies and nothing
  /// reads this column anyway — the live credential comes from
  /// `AuthRepository._tokensByCompany` / secure storage.
  Future<void> touchSessionColumns({
    required String companyId,
    required int at,
    required String permissions,
    required String accountId,
    required bool isAdmin,
    required bool isOwner,
  }) async {
    await (update(companies)..where((c) => c.id.equals(companyId))).write(
      CompaniesCompanion(
        lastSyncAt: Value(at),
        permissions: Value(permissions),
        accountId: Value(accountId),
        isAdmin: Value(isAdmin),
        isOwner: Value(isOwner),
      ),
    );
  }

  Future<AccountRow?> account() =>
      (select(accounts)..limit(1)).getSingleOrNull();

  Stream<AccountRow?> watchAccount() =>
      (select(accounts)..limit(1)).watchSingleOrNull();

  Future<void> upsertAccount(AccountsCompanion row) =>
      into(accounts).insertOnConflictUpdate(row);

  /// Full-sync reconciliation: drop the companies (and any stale account) the
  /// response no longer carries, and leave every surviving row in place.
  ///
  /// Deliberately NOT a wipe-and-reseed. `_persistAndActivate` follows this
  /// with [upsertAll], whose `insertAllOnConflictUpdate` only writes the
  /// columns present on the companion — so a surviving row keeps any column
  /// the login/refresh envelope doesn't carry. Deleting the row first would
  /// reset those to their table defaults instead, silently blanking the
  /// user's SMTP credentials and friends on every launch (issue #29).
  Future<void> pruneExcept({
    required Set<String> companyIds,
    required String accountId,
  }) async {
    await transaction(() async {
      // `isNotIn([])` compiles to a bare `WHERE TRUE` — drift's `isNotInExp`
      // returns `Constant(true)` for an empty list — so an empty set would
      // delete every row, the exact opposite of pruning. The caller can't
      // reach that (a company-less response throws earlier), but the blast
      // radius of getting it wrong is the entire local cache.
      if (companyIds.isNotEmpty) {
        await (delete(companies)..where((c) => c.id.isNotIn(companyIds))).go();
      }
      await (delete(accounts)..where((a) => a.id.equals(accountId).not())).go();
    });
  }
}
