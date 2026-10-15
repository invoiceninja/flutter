import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/token_storage.dart';

/// `Services.releaseMemory` is what the OS's low-memory signal reaches
/// (`MemoryPressureObserver`, registered by `InvoiceNinjaApp`). It must reach
/// every entity repository's decoded records — the one in-memory cache that
/// grows with what the user has browsed — and the lists must still read
/// correctly afterwards, decoding their rows again from Drift.
void main() {
  test(
    'releaseMemory empties the decoded records and nothing breaks',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final services = Services.build(
        db: db,
        tokenStorage: InMemoryTokenStorage(),
        connectivityWatcher: ConnectivityWatcher.fixed(online: false),
      );
      try {
        for (var i = 0; i < 3; i++) {
          await services.invoices.applyUpdateResponse(
            companyId: 'co',
            serverResponse: InvoiceApi(
              id: 'inv_$i',
              number: '$i',
              updatedAt: 1,
            ),
          );
        }
        final before = await services.invoices.watchPage(companyId: 'co').first;
        expect(services.invoices.decodedRowCount, 3);

        services.releaseMemory();
        expect(services.invoices.decodedRowCount, 0);

        final after = await services.invoices.watchPage(companyId: 'co').first;
        expect(after, before, reason: 'the same records, decoded again');
      } finally {
        await services.auth.dispose();
        await db.close();
      }
    },
  );
}
