import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';

/// The create-draft staging carries whether the seed is a clone.
///
/// A clone and a prefilled new record ("New expense" from a vendor) both reach
/// the create screen through this one slot, and they must be told apart: a new
/// expense takes the company's Expense Settings defaults, a clone copies its
/// source. Losing the flag would compile, run, and silently apply "mark paid"
/// or "invoiceable" over a cloned expense's own values.
void main() {
  late AppDatabase db;
  late Services services;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    services = Services.build(
      db: db,
      tokenStorage: InMemoryTokenStorage(),
      connectivityWatcher: ConnectivityWatcher.fixed(online: false),
    );
  });
  tearDown(() async {
    await services.auth.dispose();
    await db.close();
  });

  test('a clone round-trips its flag, once', () {
    final draft = emptyExpense().copyWith(vendorId: 'v1');
    services.stageCreateDraft('/expenses', draft, isClone: true);

    final seed = services.takeCreateSeed<Expense>('/expenses');
    expect(seed?.draft, draft);
    expect(seed?.isClone, isTrue);

    // One-shot: the slot is cleared, flag included.
    expect(services.takeCreateSeed<Expense>('/expenses'), isNull);
  });

  test('a prefill is not a clone, and a later prefill does not inherit a '
      'stale flag', () {
    services.stageCreateDraft('/expenses', emptyExpense(), isClone: true);
    services.stageCreateDraft(
      '/expenses',
      emptyExpense().copyWith(vendorId: 'v1'),
    );

    expect(services.takeCreateSeed<Expense>('/expenses')?.isClone, isFalse);
  });

  test('takeCreateDraft still hands back the bare draft', () {
    final draft = emptyExpense().copyWith(clientId: 'c1');
    services.stageCreateDraft('/expenses', draft, isClone: true);

    expect(services.takeCreateDraft<Expense>('/expenses'), draft);
  });

  test('a seed staged for another route or type is not taken', () {
    services.stageCreateDraft('/expenses', emptyExpense(), isClone: true);

    expect(services.takeCreateSeed<Expense>('/recurring_expenses'), isNull);
    expect(services.takeCreateSeed<String>('/expenses'), isNull);
    // Still there for the right reader.
    expect(services.takeCreateSeed<Expense>('/expenses')?.isClone, isTrue);
  });
}
