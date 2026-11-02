@TestOn('vm')
library;

import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/home_widgets/home_widget_reader.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/dashboard_api.dart';
import 'package:admin/data/services/home_widget_bridge.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/tasks_api.dart';
import 'package:admin/domain/home_widgets/widget_snapshot.dart';
import 'package:admin/utils/formatting.dart';

/// [HomeWidgetReader] against a real Drift store: what a widget is told
/// depends on reading the dashboard's own cache rows (under the dashboard's
/// saved filter), the user's own tasks, and the permission gates — none of
/// which the publisher tests' fake reader exercises.

const _today = Date(2026, 10, 14);
final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

class _NoTasksApi implements TasksApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoClientsApi implements ClientsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _dummyClient = ApiClient(
  credentials: ValueNotifier<ApiCredentials?>(
    const ApiCredentials(baseUrl: 'https://test', token: 't'),
  ),
  passwordCache: PasswordCache(),
  onUnauthorized: () async {},
);

Formatter _formatter() => Formatter(
  settings: CompanyFormatSettings.fallback.copyWith(currencyId: '1'),
  currencies: {
    '1': Currency(
      id: '1',
      name: 'US Dollar',
      code: 'USD',
      symbol: r'$',
      precision: 2,
      thousandSeparator: ',',
      decimalSeparator: '.',
      swapCurrencySymbol: false,
      exchangeRate: Decimal.one,
    ),
  },
  countries: const {},
  dateFormats: const {'5': DatetimeFormat(id: '5', format: 'MMM d, yyyy')},
);

AuthCompany _company({String permissions = '', bool admin = false}) =>
    AuthCompany(
      id: 'co',
      name: 'Acme',
      displayName: 'Acme',
      permissions: permissions,
      isAdmin: admin,
      isOwner: false,
      // Every module on.
      enabledModules: 0x7FFFFFFF,
    );

AuthSession _session(AuthCompany company) => AuthSession(
  baseUrl: '',
  isHosted: false,
  accountId: '',
  userId: 'me',
  currentCompanyId: company.id,
  companies: [company],
);

Task _task(
  String id, {
  String userId = '',
  String assigned = '',
  bool running = true,
}) => Task(
  id: id,
  number: id,
  description: 'Task $id',
  rate: Decimal.zero,
  invoiceId: '',
  clientId: '',
  projectId: '',
  statusId: 's1',
  statusOrder: 0,
  assignedUserId: assigned,
  userId: userId,
  timeLog: [
    TimeEntry(
      start: DateTime.utc(2026, 10, 14, 9),
      stop: running ? null : DateTime.utc(2026, 10, 14, 10),
    ),
  ],
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: _epoch,
  createdAt: _epoch,
  archivedAt: null,
  isDeleted: false,
);

Map<String, Object?> _totals(String outstanding) => {
  'currencies': {'1': 'USD'},
  '1': {
    'invoices': {'invoiced_amount': '500', 'code': 'USD'},
    'revenue': {'paid_to_date': '200', 'code': 'USD'},
    'outstanding': {
      'amount': outstanding,
      'outstanding_count': 3,
      'code': 'USD',
    },
    'expenses': {'amount': '10', 'code': 'USD'},
  },
};

void main() {
  late AppDatabase db;
  late TaskRepository tasks;
  late HomeWidgetReader reader;
  String? navFilters;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tasks = TaskRepository(db: db, api: _NoTasksApi());
    navFilters = null;
    reader = HomeWidgetReader(
      dashboard: DashboardRepository(db: db, api: DashboardApi(_dummyClient)),
      tasks: tasks,
      clients: ClientRepository(db: db, api: _NoClientsApi()),
      navFilters: () async => navFilters,
      formatterFor: (_) async => _formatter(),
    );
  });

  tearDown(() => db.close());

  const installed = InstalledWidgets(
    kinds: {WidgetKind.snapshot, WidgetKind.timer},
  );

  Future<void> cache(String kind, String hash, Object payload) =>
      db.dashboardCacheDao.upsert(
        companyId: 'co',
        kind: kind,
        filterHash: hash,
        payload: jsonEncode(payload),
        fetchedAt: 1000,
      );

  test('reads the dashboard\'s rows under its own saved filter', () async {
    // The dashboard was left on "include drafts": its outstanding row lives
    // under that hash, and the widget must read that one, not the default's.
    navFilters = jsonEncode({
      'co': {
        'dashboard': {
          'filter': const DashboardFilter(
            range: DashboardPresetRange(DashboardDatePreset.last7),
            includeDrafts: true,
          ).toJson(),
        },
      },
    });
    await cache(
      DashboardKind.totalsOutstanding,
      dashboardOutstandingHash(includeDrafts: true),
      _totals('900'),
    );
    await cache(
      DashboardKind.totalsOutstanding,
      dashboardOutstandingHash(includeDrafts: false),
      _totals('1'),
    );
    final company = _company(admin: true);
    final input = await reader.read(
      _session(company),
      company,
      installed: installed,
      figures: true,
      timers: false,
      localeTag: 'en',
      today: _today,
    );
    expect(
      input.outstanding?.byCurrency['1']?.outstandingAmount,
      Decimal.parse('900'),
    );
  });

  test('without view_dashboard, no figure is read at all', () async {
    await cache(
      DashboardKind.totalsOutstanding,
      dashboardOutstandingHash(includeDrafts: false),
      _totals('900'),
    );
    final company = _company(permissions: 'view_task');
    final input = await reader.read(
      _session(company),
      company,
      installed: installed,
      figures: true,
      timers: false,
      localeTag: 'en',
      today: _today,
    );
    expect(input.canViewDashboard, isFalse);
    expect(input.formatter, isNull);
    expect(input.outstanding, isNull);
  });

  test(
    "the Timer widget gets the user's own tasks, never a teammate's",
    () async {
      for (final t in [
        _task('mine', userId: 'me'),
        _task('assigned', userId: 'boss', assigned: 'me'),
        _task('teammate', userId: 'someone'),
      ]) {
        await tasks.create(companyId: 'co', draft: t);
      }
      final company = _company(admin: true);
      final input = await reader.read(
        _session(company),
        company,
        installed: installed,
        figures: false,
        timers: true,
        localeTag: 'en',
        today: _today,
      );
      expect(
        input.runningTasks.map((t) => t.description),
        unorderedEquals(['Task mine', 'Task assigned']),
      );
    },
  );

  test('no task is read without a Timer widget', () async {
    await tasks.create(
      companyId: 'co',
      draft: _task('mine', userId: 'me'),
    );
    final company = _company(admin: true);
    final input = await reader.read(
      _session(company),
      company,
      installed: installed,
      figures: false,
      timers: false,
      localeTag: 'en',
      today: _today,
    );
    expect(input.runningTasks, isEmpty);
    expect(input.recentTasks, isEmpty);
  });

  test('the invoices module off: no past-due rows', () async {
    final company = AuthCompany(
      id: 'co',
      name: 'Acme',
      displayName: 'Acme',
      permissions: '',
      isAdmin: true,
      isOwner: false,
      enabledModules: 0,
    );
    final input = await reader.read(
      _session(company),
      company,
      installed: installed,
      figures: true,
      timers: false,
      localeTag: 'en',
      today: _today,
    );
    expect(input.showInvoices, isFalse);
  });
}
