import 'package:drift/drift.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/tables/user_settings_table.dart';

part 'user_settings_dao.g.dart';

@DriftAccessor(tables: [UserSettings])
class UserSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$UserSettingsDaoMixin {
  UserSettingsDao(super.db);

  /// Watch a single company's settings row. Emits `null` until login has
  /// persisted it.
  Stream<UserSettingsRow?> watch(String companyId) => (select(
    userSettings,
  )..where((u) => u.companyId.equals(companyId))).watchSingleOrNull();

  Future<UserSettingsRow?> get(String companyId) => (select(
    userSettings,
  )..where((u) => u.companyId.equals(companyId))).getSingleOrNull();

  Future<void> upsert(UserSettingsCompanion row) =>
      into(userSettings).insertOnConflictUpdate(row);

  /// Replace only the `table_columns_json` blob, leaving `extra_json` and
  /// `user_id` untouched. Used when the user changes columns via the picker
  /// — we don't want to clobber the rest of settings until the server PUT
  /// returns the canonical version.
  Future<void> writeTableColumns({
    required String companyId,
    required String tableColumnsJson,
    required int now,
  }) async {
    await (update(
      userSettings,
    )..where((u) => u.companyId.equals(companyId))).write(
      UserSettingsCompanion(
        tableColumnsJson: Value(tableColumnsJson),
        updatedAt: Value(now),
      ),
    );
  }

  /// Replace only the `react_settings_json` blob.
  Future<void> writeReactSettings({
    required String companyId,
    required String reactSettingsJson,
    required int now,
  }) async {
    await (update(
      userSettings,
    )..where((u) => u.companyId.equals(companyId))).write(
      UserSettingsCompanion(
        reactSettingsJson: Value(reactSettingsJson),
        updatedAt: Value(now),
      ),
    );
  }

  Future<int> deleteFor(String companyId) =>
      (delete(userSettings)..where((u) => u.companyId.equals(companyId))).go();
}
