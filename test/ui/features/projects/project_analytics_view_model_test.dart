import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/resync_controller.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/project_charts_api.dart';
import 'package:admin/data/services/realtime/realtime_service.dart';
import 'package:admin/ui/features/projects/view_models/project_analytics_view_model.dart';

/// Behavioral contracts for the project Analytics tab's view model:
///   * one endpoint failing still renders the other's sections
///   * a failed refresh keeps the figures already on screen
///   * a failure is classified by what the user can do about it
///   * the tab refetches when a Sync, a pushed change or the user's own
///     change makes its figures old
///   * the burn-up's window is the project's life unless asked otherwise,
///     and its bucket suits the span
///   * a stale in-flight response never overwrites a newer one
///
/// No http layer here — a fake [ProjectChartsApi] feeds canned responses.

/// Minimal stand-in so the fake can satisfy `ProjectChartsApi`'s `final
/// ApiClient client` field. Never called.
final ApiClient _dummyClient = ApiClient(
  credentials: ValueNotifier<ApiCredentials?>(
    const ApiCredentials(baseUrl: 'https://test', token: 't'),
  ),
  passwordCache: PasswordCache(),
  onUnauthorized: () async {},
);

class _FakeProjectChartsApi extends ProjectChartsApi {
  _FakeProjectChartsApi() : super(_dummyClient);

  Object? analytics;
  Object? burnup;
  Object? analyticsError;
  Object? burnupError;

  /// Lets a test hold a response open to exercise ordering.
  Completer<Object?>? analyticsGate;

  int analyticsCalls = 0;
  int burnupCalls = 0;
  BurnupBucket? lastBucket;
  Date? lastStart;
  Date? lastEnd;
  bool? lastIncludeDrafts;

  @override
  Future<Object?> fetchAnalytics({
    required String projectId,
    bool includeDrafts = false,
  }) async {
    analyticsCalls++;
    lastIncludeDrafts = includeDrafts;
    if (analyticsGate != null) return analyticsGate!.future;
    if (analyticsError != null) throw analyticsError!;
    return analytics;
  }

  @override
  Future<Object?> fetchBurnup({
    required String projectId,
    Date? startDate,
    Date? endDate,
    BurnupBucket bucket = BurnupBucket.daily,
    bool includeDrafts = false,
  }) async {
    burnupCalls++;
    lastBucket = bucket;
    lastStart = startDate;
    lastEnd = endDate;
    if (burnupError != null) throw burnupError!;
    return burnup;
  }
}

void main() {
  const today = Date(2026, 7, 24);

  ProjectAnalyticsViewModel build(
    _FakeProjectChartsApi api, {
    Date? projectStart,
    Date? projectDue,
    ValueListenable<ResyncCompletion?>? resync,
    ValueListenable<RealtimeRefresh?>? realtime,
    Stream<int>? outbox,
  }) => ProjectAnalyticsViewModel(
    api: api,
    projectId: 'proj_1',
    companyId: 'co',
    projectStart: projectStart ?? const Date(2026, 6, 1),
    projectDue: projectDue,
    today: today,
    resyncCompletions: resync,
    realtimeRefreshes: realtime,
    outboxActive: outbox,
    refetchDelay: Duration.zero,
  );

  final analyticsPayload = <String, dynamic>{
    'budget_summary': [
      {'budgeted_hours': 40.0, 'current_hours': 10.0, 'currency_id': '1'},
    ],
  };
  final burnupPayload = <String, dynamic>{
    'bucket_type': 'weekly',
    'series': [
      {'period_end': '2026-07-01', 'cumulative_logged_hours': 10.0},
    ],
  };

  group('load', () {
    test('decodes both payloads on success', () async {
      final api = _FakeProjectChartsApi()
        ..analytics = analyticsPayload
        ..burnup = burnupPayload;
      final vm = build(api);

      await vm.load();

      expect(vm.blockingFailure, isNull);
      expect(vm.analytics?.budgetSummary?.budgetedHours, 40.0);
      expect(vm.burnup?.series, hasLength(1));
      expect(vm.loading, isFalse);
      expect(vm.initialLoading, isFalse);
    });

    test('a failing analytics call still renders the burn-up', () async {
      final api = _FakeProjectChartsApi()
        ..analyticsError = const ServerException(500, 'boom')
        ..burnup = burnupPayload;
      final vm = build(api);

      await vm.load();

      expect(vm.blockingFailure, isNull, reason: 'partial data is useful');
      expect(vm.analytics, isNull);
      expect(vm.analyticsFailure, ProjectAnalyticsFailure.other);
      expect(vm.burnup, isNotNull);
    });

    test('both failing is a blocking failure', () async {
      final api = _FakeProjectChartsApi()
        ..analyticsError = const ServerException(500, 'Server on fire')
        ..burnupError = const ServerException(500, 'Server on fire');
      final vm = build(api);

      await vm.load();

      expect(vm.blockingFailure, ProjectAnalyticsFailure.other);
      expect(vm.failureMessage, 'Server on fire');
    });

    test('a failure is classified by what the user can do about it', () async {
      Future<ProjectAnalyticsFailure?> failureFor(Object error) async {
        final api = _FakeProjectChartsApi()
          ..analyticsError = error
          ..burnupError = error;
        final vm = build(api);
        await vm.load();
        return vm.blockingFailure;
      }

      // Offline used to read "Analytics aren't available from this server".
      expect(
        await failureFor(const NetworkException('no route')),
        ProjectAnalyticsFailure.offline,
      );
      expect(
        await failureFor(const ServerException(404, 'Route does not exist')),
        ProjectAnalyticsFailure.unavailable,
      );
      expect(
        await failureFor(const ServerException(403, 'nope')),
        ProjectAnalyticsFailure.forbidden,
      );
      expect(
        await failureFor(StateError('unexpected')),
        ProjectAnalyticsFailure.other,
      );
    });

    test('a failed refresh keeps the figures already on screen', () async {
      final api = _FakeProjectChartsApi()
        ..analytics = analyticsPayload
        ..burnup = burnupPayload;
      final vm = build(api);
      await vm.load();

      api
        ..analyticsError = const NetworkException('offline')
        ..burnupError = const NetworkException('offline');
      await vm.load();

      expect(vm.analytics?.budgetSummary?.budgetedHours, 40.0);
      expect(vm.burnup, isNotNull);
      expect(vm.analyticsFailure, ProjectAnalyticsFailure.offline);
      expect(
        vm.blockingFailure,
        isNull,
        reason: 'there is something to show, so the failure is a banner',
      );

      api
        ..analyticsError = null
        ..burnupError = null;
      await vm.load();
      expect(vm.analyticsFailure, isNull, reason: 'cleared on success');
    });
  });

  group('the burn-up window', () {
    test('by default no dates are sent: the server spans the project', () {
      final api = _FakeProjectChartsApi()..burnup = burnupPayload;
      final vm = build(api);
      return vm.load().then((_) {
        expect(api.lastStart, isNull);
        expect(api.lastEnd, isNull);
      });
    });

    test('the bucket suits the span until the user picks one', () async {
      // Started 53 days before today: daily.
      final young = _FakeProjectChartsApi()..burnup = burnupPayload;
      await build(young).load();
      expect(young.lastBucket, BurnupBucket.daily);

      // Two years long: monthly.
      final old = _FakeProjectChartsApi()..burnup = burnupPayload;
      await build(old, projectStart: const Date(2024, 1, 1)).load();
      expect(old.lastBucket, BurnupBucket.monthly);

      // A due date far ahead lengthens the span, as the server's window does.
      final planned = _FakeProjectChartsApi()..burnup = burnupPayload;
      await build(planned, projectDue: const Date(2027, 6, 1)).load();
      expect(planned.lastBucket, BurnupBucket.weekly);
    });

    test('a narrower range sends its dates and re-picks the bucket', () async {
      final api = _FakeProjectChartsApi()..burnup = burnupPayload;
      final vm = build(api, projectStart: const Date(2024, 1, 1));
      await vm.load();

      vm.setRange(ProjectBurnupRange.last30Days);
      await Future<void>.delayed(Duration.zero);

      expect(api.lastStart, const Date(2026, 6, 24));
      expect(api.lastEnd, today);
      expect(vm.bucket, BurnupBucket.daily);
    });

    test('a bucket the user picked survives a range change', () async {
      final api = _FakeProjectChartsApi()..burnup = burnupPayload;
      final vm = build(api);
      await vm.load();

      vm.setBucket(BurnupBucket.monthly);
      vm.setRange(ProjectBurnupRange.last30Days);
      await Future<void>.delayed(Duration.zero);

      expect(api.lastBucket, BurnupBucket.monthly);
    });

    test('a due date moved under a mounted tab re-picks the bucket — '
        'unless the user chose one', () async {
      final api = _FakeProjectChartsApi()..burnup = burnupPayload;
      final vm = build(api);
      await vm.load();
      expect(vm.bucket, BurnupBucket.daily);

      vm.updateProject(
        start: const Date(2026, 6, 1),
        due: const Date(2028, 6, 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(vm.bucket, BurnupBucket.monthly);
      expect(api.lastBucket, BurnupBucket.monthly, reason: 'and refetched');

      vm.setBucket(BurnupBucket.weekly);
      vm.updateProject(start: const Date(2026, 6, 1), due: null);
      expect(vm.bucket, BurnupBucket.weekly);
      vm.dispose();
    });

    test('changing the window refetches the burn-up alone', () async {
      // The analytics endpoint reads no dates.
      final api = _FakeProjectChartsApi()
        ..analytics = analyticsPayload
        ..burnup = burnupPayload;
      final vm = build(api);
      await vm.load();

      vm.setRange(ProjectBurnupRange.last365Days);
      await Future<void>.delayed(Duration.zero);

      expect(api.analyticsCalls, 1);
      expect(api.burnupCalls, 2);
    });

    test('include drafts refetches both', () async {
      final api = _FakeProjectChartsApi()
        ..analytics = analyticsPayload
        ..burnup = burnupPayload;
      final vm = build(api);
      await vm.load();

      vm.setIncludeDrafts(true);
      await Future<void>.delayed(Duration.zero);

      expect(api.lastIncludeDrafts, isTrue);
      expect(api.analyticsCalls, 2);
      expect(api.burnupCalls, 2);
    });
  });

  group('refetches when its figures go old', () {
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 5));

    test('a completed Sync pass for this company', () async {
      final resync = ValueNotifier<ResyncCompletion?>(null);
      final api = _FakeProjectChartsApi()..analytics = analyticsPayload;
      final vm = build(api, resync: resync);
      await vm.load();

      resync.value = const ResyncCompletion(
        serial: 1,
        companyId: 'other',
        result: ResyncResult(ResyncDisposition.completed),
      );
      await settle();
      expect(api.analyticsCalls, 1, reason: 'another company');

      resync.value = const ResyncCompletion(
        serial: 2,
        companyId: 'co',
        result: ResyncResult(ResyncDisposition.completed),
      );
      await settle();
      expect(api.analyticsCalls, 2);
      vm.dispose();
    });

    test('a pushed server change', () async {
      final realtime = ValueNotifier<RealtimeRefresh?>(null);
      final api = _FakeProjectChartsApi()..analytics = analyticsPayload;
      final vm = build(api, realtime: realtime);
      await vm.load();

      realtime.value = RealtimeRefresh(companyId: 'co', at: DateTime(2026));
      await settle();
      expect(api.analyticsCalls, 2);
      vm.dispose();
    });

    test(
      'a change of the user\'s own leaving the outbox — not entering it',
      () async {
        final outbox = StreamController<int>();
        final api = _FakeProjectChartsApi()..analytics = analyticsPayload;
        final vm = build(api, outbox: outbox.stream);
        await vm.load();

        outbox.add(0);
        outbox.add(1); // a save queued: the server does not have it yet
        await settle();
        expect(api.analyticsCalls, 1);

        outbox.add(0); // it went through
        await settle();
        expect(api.analyticsCalls, 2);
        vm.dispose();
        await outbox.close();
      },
    );
  });

  test('disposing mid-flight does not notify a disposed notifier', () async {
    final gate = Completer<Object?>();
    final api = _FakeProjectChartsApi()
      ..burnup = burnupPayload
      ..analyticsGate = gate;
    final vm = build(api);

    final pending = vm.load();
    vm.dispose();
    gate.complete(analyticsPayload);

    await expectLater(pending, completes);
  });

  test('load() on an already-disposed VM is a no-op', () async {
    final api = _FakeProjectChartsApi()..analytics = analyticsPayload;
    final vm = build(api)..dispose();

    await expectLater(vm.load(), completes);
    expect(api.analyticsCalls, 0, reason: 'no request for a dead screen');
  });

  test('a stale in-flight response never overwrites a newer one', () async {
    final gate = Completer<Object?>();
    final api = _FakeProjectChartsApi()
      ..burnup = burnupPayload
      ..analyticsGate = gate;
    final vm = build(api);

    final stale = vm.load(); // parks on `gate`

    api
      ..analyticsGate = null
      ..analytics = analyticsPayload;
    await vm.load();
    expect(vm.analytics?.budgetSummary?.budgetedHours, 40.0);

    gate.complete(<String, dynamic>{
      'budget_summary': [
        {'budgeted_hours': 999.0},
      ],
    });
    await stale;

    expect(
      vm.analytics?.budgetSummary?.budgetedHours,
      40.0,
      reason: 'stale response must not clobber the newer answer',
    );
  });
}
