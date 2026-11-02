import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';

import 'package:admin/app/home_widgets/home_widget_publisher.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/app/home_widgets/home_widget_reader.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/services/home_widget_bridge.dart';
import 'package:admin/domain/home_widgets/widget_command.dart';
import 'package:admin/domain/home_widgets/widget_snapshot.dart';
import 'package:admin/domain/home_widgets/widget_snapshot_builder.dart';
import 'package:admin/utils/formatting.dart';

/// The publisher's timing and lifecycle: when the widgets' snapshot is
/// written, what is reloaded, and that every session end leaves it signed
/// out. What goes *into* the snapshot is `widget_snapshot_builder_test`'s.
///
/// Timers are driven by `testWidgets` + `tester.pump(duration)` — fake_async
/// is not a dev dependency.

class _Write {
  _Write(this.json, this.reload);
  final Map<String, Object?> json;
  final Set<WidgetKind>? reload;
}

class _FakeBridge extends HomeWidgetBridge {
  _FakeBridge() : super(supported: true);

  final List<_Write> writes = [];
  InstalledWidgets installedValue = const InstalledWidgets(
    kinds: {WidgetKind.snapshot, WidgetKind.timer},
  );
  int deleteAllCalls = 0;

  /// False makes every write fail, as a native side that errored would.
  bool writeSucceeds = true;

  @override
  Future<bool> write(
    Map<String, Object?> snapshot, {
    Set<WidgetKind>? reload,
  }) async {
    writes.add(_Write(snapshot, reload));
    return writeSucceeds;
  }

  bool installedAnswers = true;

  @override
  Future<InstalledWidgets?> installed() async =>
      installedAnswers ? installedValue : null;

  @override
  Future<List<({String fileId, WidgetCommand? command})>>
  takeCommands() async => const [];

  @override
  Future<void> deleteAllCommands() async => deleteAllCalls++;
}

class _FakeReader implements HomeWidgetReader {
  /// What [read] answers for the timers; change it to make the snapshot
  /// differ.
  List<String> runningTaskIds = const [];
  int fetches = 0;

  /// The current company's Outstanding totals; null = not loaded yet.
  DashboardTotals? outstanding;

  /// The current company's attention lists are loaded (empty) when true.
  bool attentionLoaded = false;

  /// The `timers` flag of every read.
  final List<bool> timerReads = [];

  /// Completes a read only when set — lets a test sign out mid-rebuild.
  Completer<void>? gate;

  @override
  Future<WidgetCompanyInput> read(
    AuthSession session,
    AuthCompany company, {
    required InstalledWidgets installed,
    required bool figures,
    required bool timers,
    required String localeTag,
    required Date today,
  }) async {
    await gate?.future;
    timerReads.add(timers);
    final current = company.id == session.currentCompanyId;
    return WidgetCompanyInput(
      id: company.id,
      name: company.displayName,
      canViewDashboard: true,
      formatter: _formatter,
      baseCurrencyId: '1',
      outstanding: current ? outstanding : null,
      pastDue: current && attentionLoaded ? const [] : null,
      upcoming: current && attentionLoaded ? const [] : null,
      runningTasks: [
        if (company.id == session.currentCompanyId)
          for (final id in runningTaskIds) _running(id),
      ],
    );
  }

  @override
  Future<void> fetch(
    AuthSession session, {
    required InstalledWidgets installed,
    required Date today,
  }) async => fetches++;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AuthSession _session({String company = 'co1'}) => AuthSession(
  baseUrl: '',
  isHosted: false,
  accountId: '',
  userId: 'u1',
  currentCompanyId: company,
  companies: const [
    AuthCompany(
      id: 'co1',
      name: 'One',
      displayName: 'One',
      permissions: '',
      isAdmin: true,
      isOwner: false,
    ),
    AuthCompany(
      id: 'co2',
      name: 'Two',
      displayName: 'Two',
      permissions: '',
      isAdmin: true,
      isOwner: false,
    ),
  ],
);

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Task _running(String id) => Task(
  id: id,
  number: id,
  description: id,
  rate: Decimal.zero,
  invoiceId: '',
  clientId: '',
  projectId: '',
  statusId: 's1',
  statusOrder: 0,
  assignedUserId: '',
  timeLog: [TimeEntry(start: DateTime.utc(2026, 10, 14, 10), stop: null)],
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: _epoch,
  createdAt: _epoch,
  archivedAt: null,
  isDeleted: false,
);

final _formatter = Formatter(
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
  dateFormats: const {},
);

DashboardTotals _outstanding(String amount) => DashboardTotals.fromJson({
  'currencies': {'1': 'USD'},
  '1': {
    'outstanding': {'amount': amount, 'outstanding_count': 1, 'code': 'USD'},
  },
});

String _tr(String key, [Map<String, String>? params]) => 'T:$key';

class _Rig {
  _Rig({
    AuthSession? session,
    Duration? heartbeat,
    Duration sessionFetchDelay = Duration.zero,
  }) : session = ValueNotifier(session) {
    publisher = HomeWidgetPublisher(
      heartbeatEvery: heartbeat,
      sessionFetchDelay: sessionFetchDelay,
      bridge: bridge,
      session: this.session,
      reader: reader,
      dataChanges: changes.stream,
      fetchRequests: fetches.stream,
      debounce: const Duration(seconds: 2),
      reloadGap: const Duration(minutes: 5),
      now: () => clock,
      today: () => const Date(2026, 10, 14),
    );
  }

  final bridge = _FakeBridge();
  final reader = _FakeReader();
  final ValueNotifier<AuthSession?> session;
  final changes = StreamController<void>.broadcast();
  final fetches = StreamController<void>.broadcast();
  late final HomeWidgetPublisher publisher;
  DateTime clock = DateTime.utc(2026, 10, 14, 12);

  void start() {
    publisher
      ..start()
      ..setLocalization(_tr, localeTag: 'en', rtl: false);
  }

  void dispose() {
    publisher.dispose();
    unawaited(changes.close());
    unawaited(fetches.close());
  }
}

void main() {
  testWidgets('writes once after the debounce, not per change', (tester) async {
    final rig = _Rig(session: _session())..start();
    addTearDown(rig.dispose);
    rig.changes
      ..add(null)
      ..add(null)
      ..add(null);
    await tester.pump(const Duration(seconds: 1));
    expect(rig.bridge.writes, isEmpty);
    await tester.pump(const Duration(seconds: 2));
    expect(rig.bridge.writes, hasLength(1));
    expect(rig.bridge.writes.single.json['signedIn'], isTrue);
  });

  testWidgets('an unchanged snapshot is not written again', (tester) async {
    final rig = _Rig(session: _session())..start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(1));
    // Only the clock moved.
    rig.clock = rig.clock.add(const Duration(minutes: 1));
    rig.changes.add(null);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(1));
  });

  testWidgets('flush writes a pending change at once', (tester) async {
    final rig = _Rig(session: _session())..start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(milliseconds: 100));
    await rig.publisher.flush();
    expect(rig.bridge.writes, hasLength(1));
  });

  testWidgets('a company switch reloads every kind', (tester) async {
    final rig = _Rig(session: _session())..start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    rig.session.value = _session(company: 'co2');
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(2));
    expect(rig.bridge.writes.last.json['activeCompanyId'], 'co2');
    expect(rig.bridge.writes.last.reload, WidgetKind.values.toSet());
  });

  testWidgets('figures arriving inside the gap reload at once — a first fill', (
    tester,
  ) async {
    // The app's first write lands before the dashboard has loaded, so the
    // widgets draw "Open Invoice Ninja to load your data"; the figures a
    // moment later must not wait out the gap with the app open.
    final rig = _Rig(session: _session())..start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(1));
    expect(
      (rig.bridge.writes.last.json['companies']! as List)
          .cast<Map<String, Object?>>()
          .where((c) => c['figures'] != null),
      isEmpty,
    );

    rig.reader.outstanding = _outstanding('100');
    rig.changes.add(null);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(2));
    expect(rig.bridge.writes.last.reload, contains(WidgetKind.snapshot));

    // Outstanding drew the Snapshot widget, but Needs attention is still
    // "not loaded" until its lists arrive — that part is a first fill too.
    rig.reader.attentionLoaded = true;
    rig.changes.add(null);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(3));
    expect(rig.bridge.writes.last.reload, contains(WidgetKind.attention));
  });

  testWidgets('a change to figures already shown waits out the gap', (
    tester,
  ) async {
    final rig = _Rig(session: _session())..start();
    rig.reader
      ..outstanding = _outstanding('100')
      ..attentionLoaded = true;
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(1));

    rig.reader.outstanding = _outstanding('250');
    rig.changes.add(null);
    await tester.pump(const Duration(seconds: 3));
    // Written (the file holds it), but not reloaded.
    expect(rig.bridge.writes, hasLength(2));
    expect(rig.bridge.writes.last.reload, isEmpty);

    // The owed reload goes through once the gap is over.
    rig.clock = rig.clock.add(const Duration(minutes: 5));
    await tester.pump(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(3));
    expect(rig.bridge.writes.last.reload, {
      WidgetKind.snapshot,
      WidgetKind.attention,
    });
  });

  test('figureParts names each part a widget draws "not loaded" without', () {
    expect(
      figureParts([
        {'id': 'a'},
        {
          'id': 'b',
          'figures': {
            'outstanding': {'unpaidCount': 1},
            'periods': {'this_month': <String, Object?>{}},
            'attention': {'pastDue': <Object?>[]},
          },
        },
        {
          'id': 'c',
          'figures': {'periods': <String, Object?>{}},
        },
      ]),
      {'b', 'b/outstanding', 'b/attention', 'b/period/this_month', 'c'},
    );
  });

  testWidgets('a timer change reloads the Timer widget alone', (tester) async {
    final rig = _Rig(session: _session())..start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    rig.reader.runningTaskIds = ['t1'];
    rig.changes.add(null);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(2));
    expect(rig.bridge.writes.last.reload, {WidgetKind.timer});
  });

  testWidgets('a company switch fetches for the new company', (tester) async {
    final rig = _Rig(
      session: _session(),
      sessionFetchDelay: kWidgetSessionFetchDelay,
    )..start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    final before = rig.reader.fetches;
    rig.session.value = _session(company: 'co2');
    await tester.pump(const Duration(seconds: 3));
    // Deferred past the dashboard's own boot fetch.
    expect(rig.reader.fetches, before);
    await tester.pump(kWidgetSessionFetchDelay);
    expect(rig.reader.fetches, before + 1);
  });

  testWidgets('no fetch with no widget installed', (tester) async {
    final rig = _Rig(session: _session());
    rig.bridge.installedValue = InstalledWidgets.none;
    rig.start();
    addTearDown(rig.dispose);
    rig.fetches.add(null);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.reader.fetches, 0);
    // The base snapshot is still written: the widget gallery and the company
    // picker read it before any widget exists.
    expect(rig.bridge.writes, hasLength(1));
  });

  testWidgets('signing out writes the signed-out stub and drops commands', (
    tester,
  ) async {
    final rig = _Rig(session: _session())..start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    rig.session.value = null;
    await tester.pump();
    expect(rig.bridge.writes.last.json['signedIn'], isFalse);
    expect(rig.bridge.writes.last.json['companies'], isEmpty);
    expect(
      (rig.bridge.writes.last.json['strings']! as Map)['widget_sign_in'],
      'T:widget_sign_in',
    );
    expect(rig.bridge.deleteAllCalls, greaterThan(0));
  });

  testWidgets('a rebuild in flight when the user signs out never writes', (
    tester,
  ) async {
    final rig = _Rig(session: _session())..start();
    addTearDown(rig.dispose);
    rig.reader.gate = Completer<void>();
    await tester.pump(const Duration(seconds: 3)); // rebuild started, waiting
    await rig.publisher.signOut();
    rig.reader.gate!.complete();
    await tester.pump();
    expect(rig.bridge.writes, hasLength(1));
    expect(rig.bridge.writes.single.json['signedIn'], isFalse);
  });

  testWidgets('a pending write is cancelled by a sign-out', (tester) async {
    final rig = _Rig(session: _session())..start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(milliseconds: 500));
    await rig.publisher.signOut();
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes.map((w) => w.json['signedIn']), [false]);
  });

  testWidgets('after a failed restore, no session does not blank the widgets', (
    tester,
  ) async {
    final rig = _Rig();
    rig.publisher
      ..start(sessionKnown: false)
      ..setLocalization(_tr, localeTag: 'en', rtl: false);
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, isEmpty);
    // A session arriving later is written as usual …
    rig.session.value = _session();
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes.single.json['signedIn'], isTrue);
    // … and from then on, losing it is a sign-out.
    rig.session.value = null;
    await tester.pump();
    expect(rig.bridge.writes.last.json['signedIn'], isFalse);
  });

  testWidgets('task rows are read only for an installed Timer widget', (
    tester,
  ) async {
    final rig = _Rig(session: _session());
    rig.bridge.installedValue = const InstalledWidgets(
      kinds: {WidgetKind.snapshot},
    );
    rig.start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.reader.timerReads, everyElement(isFalse));
  });

  testWidgets('flush waits for the pass carrying the latest change', (
    tester,
  ) async {
    final rig = _Rig(session: _session())..start();
    addTearDown(rig.dispose);
    rig.reader.gate = Completer<void>();
    await tester.pump(const Duration(seconds: 3)); // rebuild 1 waiting
    rig.reader.runningTaskIds = ['t1'];
    rig.changes.add(null);
    await tester.pump(const Duration(milliseconds: 100));
    var flushed = false;
    unawaited(rig.publisher.flush().then((_) => flushed = true));
    await tester.pump();
    rig.reader.gate!.complete();
    rig.reader.gate = null;
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(flushed, isTrue);
    final timers =
        ((rig.bridge.writes.last.json['companies']! as List).first
                as Map)['timers']
            as List;
    expect(timers, isNotEmpty, reason: 'flush returned before the new data');
  });

  testWidgets('a running timer is re-confirmed hourly with no reload', (
    tester,
  ) async {
    final rig = _Rig(
      session: _session(),
      heartbeat: const Duration(minutes: 30),
    );
    rig.reader.runningTaskIds = ['t1'];
    rig.start();
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(1));
    // Half an hour on: nothing changed and the stamp is fresh — no write.
    rig.clock = rig.clock.add(const Duration(minutes: 30));
    await tester.pump(const Duration(minutes: 30));
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(1));
    // An hour on: re-confirmed, without reloading any widget.
    rig.clock = rig.clock.add(const Duration(minutes: 31));
    await tester.pump(const Duration(minutes: 30));
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(2));
    expect(rig.bridge.writes.last.reload, isEmpty);
    // The periodic timer must not outlive the test.
    rig.dispose();
  });

  testWidgets('an unanswered installed() writes nothing — never "no widgets"', (
    tester,
  ) async {
    final rig = _Rig(session: _session());
    rig.bridge.installedAnswers = false;
    rig.start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, isEmpty);
  });

  testWidgets('a failed write is tried again with the same snapshot', (
    tester,
  ) async {
    final rig = _Rig(session: _session());
    rig.bridge.writeSucceeds = false;
    rig.start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(1));
    rig.bridge.writeSucceeds = true;
    rig.changes.add(null);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(2), reason: 'nothing was remembered');
  });

  testWidgets('a rebuild for the session being signed out writes nothing', (
    tester,
  ) async {
    final rig = _Rig(session: _session())..start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    // onBeforeLogout: the stub goes first, the session is cleared only later.
    await rig.publisher.signOut();
    rig.changes.add(null); // e.g. the outbox drain writing rows
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes.last.json['signedIn'], isFalse);
  });

  testWidgets('a fresh copy of the ended session still writes nothing', (
    tester,
  ) async {
    final rig = _Rig(session: _session())..start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    await rig.publisher.signOut();
    // A companies-row change during the outbox drain rebuilds the session —
    // same user, a new object.
    rig.session.value = _session();
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes.last.json['signedIn'], isFalse);
    // Signed out for real, then back in: written again.
    rig.session.value = null;
    await tester.pump();
    rig.session.value = _session();
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes.last.json['signedIn'], isTrue);
  });

  testWidgets('reloadTimer redraws the Timer widget with nothing changed', (
    tester,
  ) async {
    final rig = _Rig(session: _session())..start();
    addTearDown(rig.dispose);
    await tester.pump(const Duration(seconds: 3));
    await rig.publisher.reloadTimer();
    expect(rig.bridge.writes, hasLength(2));
    expect(rig.bridge.writes.last.reload, contains(WidgetKind.timer));
  });

  testWidgets('a cold start signed out still leaves the stub', (tester) async {
    final rig = _Rig()..start();
    addTearDown(rig.dispose);
    await tester.pump();
    expect(rig.bridge.writes, isNotEmpty);
    expect(rig.bridge.writes.last.json['signedIn'], isFalse);
  });

  testWidgets('nothing is written before the app strings arrive', (
    tester,
  ) async {
    final rig = _Rig(session: _session());
    addTearDown(rig.dispose);
    rig.publisher.start();
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, isEmpty);
    rig.publisher.setLocalization(_tr, localeTag: 'en', rtl: false);
    await tester.pump(const Duration(seconds: 3));
    expect(rig.bridge.writes, hasLength(1));
  });

  testWidgets('an unsupported platform does nothing', (tester) async {
    final bridge = HomeWidgetBridge(supported: false);
    final publisher = HomeWidgetPublisher(
      bridge: bridge,
      session: ValueNotifier(_session()),
      reader: _FakeReader(),
      dataChanges: const Stream.empty(),
      fetchRequests: const Stream.empty(),
    )..start();
    addTearDown(publisher.dispose);
    await tester.pump(const Duration(seconds: 3));
    // `write` on an unsupported bridge is a no-op; reaching here without a
    // MissingPluginException is the assertion.
    await publisher.signOut();
  });
}
