import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/project_charts_api.dart';
import 'package:admin/ui/features/projects/view_models/project_analytics_view_model.dart';

/// Behavioral contracts for the project Analytics tab's ViewModel.
///
/// The two endpoints it drives (added server-side 2026-06-30) **404 on the
/// demo host**, so the degradation paths below are the ones users will
/// actually hit first — they're the point of these tests:
///   * one endpoint failing still renders the other's cards
///   * both failing surfaces a retryable error, not a crash
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

  /// Completers let a test hold a response open to exercise ordering.
  Completer<Object?>? analyticsGate;

  int analyticsCalls = 0;
  int burnupCalls = 0;
  BurnupBucket? lastBucket;
  Date? lastStart;
  bool? lastIncludeDrafts;

  @override
  Future<Object?> fetchAnalytics({
    required String projectId,
    required Date startDate,
    required Date endDate,
    bool includeDrafts = false,
  }) async {
    analyticsCalls++;
    lastStart = startDate;
    lastIncludeDrafts = includeDrafts;
    if (analyticsGate != null) return analyticsGate!.future;
    if (analyticsError != null) throw analyticsError!;
    return analytics;
  }

  @override
  Future<Object?> fetchBurnup({
    required String projectId,
    required Date startDate,
    required Date endDate,
    BurnupBucket bucket = BurnupBucket.weekly,
    bool includeDrafts = false,
  }) async {
    burnupCalls++;
    lastBucket = bucket;
    if (burnupError != null) throw burnupError!;
    return burnup;
  }
}

void main() {
  const today = Date(2026, 7, 24);

  ProjectAnalyticsViewModel build(_FakeProjectChartsApi api) =>
      ProjectAnalyticsViewModel(api: api, projectId: 'proj_1', today: today);

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

      expect(vm.errorMessage, isNull);
      expect(vm.analytics?.budgetSummary?.budgetedHours, 40.0);
      expect(vm.burnup?.series, hasLength(1));
      expect(vm.loading, isFalse);
      expect(vm.initialLoading, isFalse);
    });

    test('a failing analytics call still renders the burn-up', () async {
      // The likeliest real-world state while servers roll out unevenly.
      final api = _FakeProjectChartsApi()
        ..analyticsError = ServerException(404, 'not found')
        ..burnup = burnupPayload;
      final vm = build(api);

      await vm.load();

      expect(vm.errorMessage, isNull, reason: 'partial data is still useful');
      expect(vm.analytics, isNull);
      expect(vm.burnup, isNotNull);
    });

    test('a failing burn-up call still renders the analytics cards', () async {
      final api = _FakeProjectChartsApi()
        ..analytics = analyticsPayload
        ..burnupError = ServerException(500, 'boom');
      final vm = build(api);

      await vm.load();

      expect(vm.errorMessage, isNull);
      expect(vm.analytics, isNotNull);
      expect(vm.burnup, isNull);
    });

    test(
      'both failing surfaces the server message for the retry state',
      () async {
        final api = _FakeProjectChartsApi()
          ..analyticsError = ServerException(404, 'Method not supported')
          ..burnupError = ServerException(404, 'Method not supported');
        final vm = build(api);

        await vm.load();

        expect(vm.errorMessage, 'Method not supported');
        expect(vm.analytics, isNull);
        expect(vm.burnup, isNull);
      },
    );

    test('a non-ApiException failure is caught too', () async {
      final api = _FakeProjectChartsApi()
        ..analyticsError = StateError('unexpected')
        ..burnupError = StateError('unexpected');
      final vm = build(api);

      await vm.load();

      expect(vm.errorMessage, isNotNull);
    });

    test('empty payloads report isEmpty rather than an error', () async {
      final api = _FakeProjectChartsApi()
        ..analytics = <String, dynamic>{}
        ..burnup = <String, dynamic>{};
      final vm = build(api);

      await vm.load();

      expect(vm.errorMessage, isNull);
      expect(vm.isEmpty, isTrue);
    });

    test('a previous error is cleared on a successful retry', () async {
      final api = _FakeProjectChartsApi()
        ..analyticsError = ServerException(500, 'boom')
        ..burnupError = ServerException(500, 'boom');
      final vm = build(api);
      await vm.load();
      expect(vm.errorMessage, isNotNull);

      api
        ..analyticsError = null
        ..burnupError = null
        ..analytics = analyticsPayload
        ..burnup = burnupPayload;
      await vm.load();

      expect(vm.errorMessage, isNull);
      expect(vm.analytics, isNotNull);
    });
  });

  group('controls', () {
    test('changing the bucket refetches with the new value', () async {
      final api = _FakeProjectChartsApi()..burnup = burnupPayload;
      final vm = build(api);
      await vm.load();

      vm.setBucket(BurnupBucket.monthly);
      await Future<void>.delayed(Duration.zero);

      expect(vm.bucket, BurnupBucket.monthly);
      expect(api.lastBucket, BurnupBucket.monthly);
      expect(api.burnupCalls, 2);
    });

    test('setting the same value does not refetch', () async {
      final api = _FakeProjectChartsApi()..burnup = burnupPayload;
      final vm = build(api);
      await vm.load();

      vm.setBucket(vm.bucket);
      await Future<void>.delayed(Duration.zero);

      expect(api.burnupCalls, 1);
    });

    test('range maps to the start date sent to the server', () async {
      final api = _FakeProjectChartsApi()..analytics = analyticsPayload;
      final vm = build(api);

      vm.setRange(ProjectAnalyticsRange.last30Days);
      await Future<void>.delayed(Duration.zero);

      expect(api.lastStart, const Date(2026, 6, 24));
    });

    test('include_drafts is threaded through', () async {
      final api = _FakeProjectChartsApi()..analytics = analyticsPayload;
      final vm = build(api);

      vm.setIncludeDrafts(true);
      await Future<void>.delayed(Duration.zero);

      expect(api.lastIncludeDrafts, isTrue);
    });
  });

  test('disposing mid-flight does not notify a disposed notifier', () async {
    // `load()` is fire-and-forget from initState and from every control
    // setter, so navigating off the project detail screen disposes the VM
    // while both chart calls are still in flight. Notifying past dispose
    // throws `debugAssertNotDisposed`.
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
    // Flipping a control faster than the network answers must not resurrect
    // the earlier window's numbers.
    final gate = Completer<Object?>();
    final api = _FakeProjectChartsApi()
      ..burnup = burnupPayload
      ..analyticsGate = gate;
    final vm = build(api);

    final stale = vm.load(); // parks on `gate`

    // Second request supersedes the first; let it complete normally.
    api
      ..analyticsGate = null
      ..analytics = analyticsPayload;
    await vm.load();
    expect(vm.analytics?.budgetSummary?.budgetedHours, 40.0);

    // Release the stale one carrying *different* numbers — proving the drop.
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
