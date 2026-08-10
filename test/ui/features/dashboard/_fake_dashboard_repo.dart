import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_calculated_field.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_chart_series.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/dashboard_api.dart';
import 'package:admin/data/services/password_cache.dart';

/// Inert client — the fake repo never issues a request, but
/// [DashboardRepository] needs a real [DashboardApi] to construct.
final ApiClient dummyDashboardClient = ApiClient(
  credentials: ValueNotifier<ApiCredentials?>(
    const ApiCredentials(baseUrl: 'https://t', token: 't'),
  ),
  passwordCache: PasswordCache(),
  onUnauthorized: () async {},
);

/// Repo whose watch streams are test-driven controllers; refreshes no-op.
///
/// Shared by `dashboard_view_model_test.dart` (which drives the streams to
/// test section routing) and `widgets/chart_card_test.dart` (which seeds the
/// chart stream to render a real `LineChart`).
class FakeDashboardRepo extends DashboardRepository {
  FakeDashboardRepo(AppDatabase db)
    : super(db: db, api: DashboardApi(dummyDashboardClient));

  final activities = StreamController<List<DashboardActivity>?>.broadcast();
  final pastDue = StreamController<List<DashboardInvoiceRow>?>.broadcast();
  final upcomingInvoices =
      StreamController<List<DashboardInvoiceRow>?>.broadcast();
  final recentPayments =
      StreamController<List<DashboardPaymentRow>?>.broadcast();
  final expiredQuotes = StreamController<List<DashboardQuoteRow>?>.broadcast();
  final upcomingQuotes = StreamController<List<DashboardQuoteRow>?>.broadcast();
  final upcomingRecurring =
      StreamController<List<DashboardRecurringInvoiceRow>?>.broadcast();
  final totals = StreamController<DashboardTotals?>.broadcast();
  final totalsPrev = StreamController<DashboardTotals?>.broadcast();
  final chart = StreamController<DashboardChartSeries?>.broadcast();

  @override
  Stream<List<DashboardActivity>?> watchActivities(String c) =>
      activities.stream;
  @override
  Stream<List<DashboardInvoiceRow>?> watchPastDue(String c) => pastDue.stream;
  @override
  Stream<List<DashboardInvoiceRow>?> watchUpcomingInvoices(String c) =>
      upcomingInvoices.stream;
  @override
  Stream<List<DashboardPaymentRow>?> watchRecentPayments(String c) =>
      recentPayments.stream;
  @override
  Stream<List<DashboardQuoteRow>?> watchExpiredQuotes(String c) =>
      expiredQuotes.stream;
  @override
  Stream<List<DashboardQuoteRow>?> watchUpcomingQuotes(String c) =>
      upcomingQuotes.stream;
  @override
  Stream<List<DashboardRecurringInvoiceRow>?> watchUpcomingRecurring(
    String c,
  ) => upcomingRecurring.stream;
  @override
  Stream<DashboardTotals?> watchTotals(
    String c,
    DashboardFilter f, {
    bool previousPeriod = false,
  }) => previousPeriod ? totalsPrev.stream : totals.stream;
  @override
  Stream<DashboardChartSeries?> watchChart(String c, DashboardFilter f) =>
      chart.stream;

  /// Cards the VM asked us to fetch (asserted by tests). The last refresh
  /// wins; reset by reading then clearing.
  final List<String> refreshedCardKeys = [];
  final List<String> droppedCardKeys = [];

  @override
  Future<Map<String, Object>> refreshAll(
    String c,
    DashboardFilter f, {
    List<DashboardCardConfig> cards = const [],
  }) async {
    refreshedCardKeys
      ..clear()
      ..addAll(cards.map((e) => e.key));
    return const {};
  }

  @override
  Future<Map<String, Object>> refreshFilterKeyed(
    String c,
    DashboardFilter f, {
    List<DashboardCardConfig> cards = const [],
  }) async {
    refreshedCardKeys
      ..clear()
      ..addAll(cards.map((e) => e.key));
    return const {};
  }

  @override
  Stream<DashboardCalculatedField?> watchCalculatedField(
    String c,
    DashboardFilter f,
    DashboardCardConfig config,
  ) => Stream<DashboardCalculatedField?>.value(null);

  @override
  Future<void> refreshCalculatedField(
    String c,
    DashboardFilter f,
    DashboardCardConfig config,
  ) async {
    refreshedCardKeys.add(config.key);
  }

  /// When set, `dropCalculatedField` blocks on this until completed — lets a
  /// test interleave a re-add against an in-flight drop (P0 race).
  Completer<void>? dropGate;

  @override
  Future<void> dropCalculatedField(String c, DashboardCardConfig config) async {
    droppedCardKeys.add(config.key);
    final gate = dropGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> refreshTotals(String c, DashboardFilter f) async {}
  @override
  Future<void> refreshChart(String c, DashboardFilter f) async {}
  @override
  Future<void> refreshActivities(String c) async {}
  @override
  Future<void> refreshPastDue(String c) async {}
  @override
  Future<void> refreshUpcomingInvoices(String c) async {}
  @override
  Future<void> refreshRecentPayments(String c) async {}
  @override
  Future<void> refreshExpiredQuotes(String c) async {}
  @override
  Future<void> refreshUpcomingQuotes(String c) async {}
  @override
  Future<void> refreshUpcomingRecurring(String c) async {}
}
