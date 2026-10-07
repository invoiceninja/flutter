import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/email_history_api_model.dart';
import 'package:admin/data/services/emails_api.dart';
import 'package:admin/ui/features/clients/view_models/client_email_history_view_model.dart';

class _Api implements EmailsApi {
  int calls = 0;

  @override
  Future<List<EmailHistoryRecordApi>> clientHistory({
    required String clientId,
  }) async {
    calls++;
    return const [];
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected API call: ${invocation.memberName}');
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ClientEmailHistoryViewModel vm(_Api api, String clientId) =>
      ClientEmailHistoryViewModel(
        api: api,
        outbox: db.outboxDao,
        companyId: 'co',
        clientId: clientId,
      );

  test('a synced client fetches its history', () async {
    final api = _Api();
    final model = vm(api, 'c1');
    await model.ensureLoaded();
    expect(api.calls, 1);
    model.dispose();
  });

  test('an unsynced client asks the server nothing', () async {
    // The server has never seen an offline-created client, so the request is
    // a guaranteed error. There is no history; the tab stays empty rather
    // than showing a failed fetch.
    final api = _Api();
    final model = vm(api, 'tmp_abc');
    await model.ensureLoaded();
    expect(api.calls, 0);
    expect(model.error, isNull);
    expect(model.isLoading, isFalse);
    model.dispose();
  });
}
