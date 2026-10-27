import 'package:admin/data/db/app_database.dart';

/// The tables that gained a `last_sent_date` column in v18.
const List<String> kLastSentDateTables = ['invoices', 'quotes'];

/// Fill `last_sent_date` on the rows that predate the column, from the
/// server's copy already sitting in each row's payload.
///
/// Runs from the v18 upgrade step and, best-effort, after a failed upgrade is
/// repaired instead (`repairSchema` adds the column but copies nothing). Pure
/// SQL — one `json_extract` pass per table, no Dart decode — so it is cheap
/// enough to hold the open for. Safe to run twice: only a still-empty column
/// is written, and a row the server never sent stays `''`. `json_valid`
/// skips a row whose payload would otherwise make `json_extract` throw and
/// fail the whole upgrade.
Future<void> backfillLastSentDates(AppDatabase db) async {
  for (final table in kLastSentDateTables) {
    // `table` comes from the const list above — never user input.
    await db.customStatement(
      'UPDATE "$table" SET "last_sent_date" = '
      "COALESCE(json_extract(\"payload\", '\$.last_sent_date'), '') "
      "WHERE \"last_sent_date\" = '' AND json_valid(\"payload\")",
    );
  }
}
