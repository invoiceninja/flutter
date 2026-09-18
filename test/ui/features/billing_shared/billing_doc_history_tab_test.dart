import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/document_version.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/document_versions_api.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/features/billing_shared/history/billing_doc_history_tab.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';

/// A [DocumentVersionsApi] whose fetch is driven by the test rather than HTTP.
///
/// Subclassed rather than mocked: the class is concrete, and what matters here
/// is what the widget does with the result, not how it was obtained.
class _FakeVersionsApi extends DocumentVersionsApi {
  _FakeVersionsApi({this.page, this.error, this.completer})
    : super(
        ApiClient(
          credentials: ValueNotifier<ApiCredentials?>(
            const ApiCredentials(baseUrl: 'https://test', token: 't'),
          ),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: MockClient(
            (_) async => http.Response('{}', 200, headers: const {}),
          ),
        ),
      );

  final DocumentVersionPage? page;
  final Object? error;
  final Completer<DocumentVersionPage>? completer;
  int calls = 0;

  @override
  Future<DocumentVersionPage> fetchForEntity({
    required String basePath,
    required String id,
  }) {
    calls++;
    if (completer != null) return completer!.future;
    if (error != null) return Future.error(error!);
    return Future.value(page ?? const DocumentVersionPage.empty());
  }

  @override
  Future<Uint8List> downloadVersionPdf(String activityId) async => Uint8List(0);
}

/// A real formatter, so money renders and the timestamp is not a raw ISO
/// string that other assertions would trip over.
final _formatter = Formatter(
  settings: const CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: 'X',
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: false,
    locale: '',
  ),
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
  dateFormats: const {'X': DatetimeFormat(id: 'X', format: 'd/MMM/yyyy')},
);

DocumentVersion _v({
  required String id,
  required String amount,
  String typeId = '5',
  int epoch = 1789733761,
  String userId = '',
  String contactId = '',
  bool isSystem = false,
}) => DocumentVersion(
  activityId: id,
  amount: Decimal.parse(amount),
  createdAt: DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true),
  activityTypeId: typeId,
  userId: userId,
  contactId: contactId,
  isSystem: isSystem,
);

Future<void> _pump(
  WidgetTester tester, {
  required DocumentVersionsApi api,
  String entityId = 'inv1',
  bool settle = true,
  bool showSelection = false,
  String? selectedActivityId,
  bool planBlocksBackups = false,
  void Function(String?)? onOpen,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 480,
            child: BillingDocHistoryTab(
              api: api,
              basePath: '/api/v1/invoices',
              entityId: entityId,
              contacts: const {
                'c1': (name: 'Dana Portal', email: 'dana@example.test'),
              },
              userNames: const {'u1': 'Jane Doe'},
              currentAmount: Decimal.parse('100'),
              currentUpdatedAt: DateTime.utc(2026, 9, 18, 12),
              formatter: _formatter,
              currencyId: '1',
              showSelection: showSelection,
              selectedActivityId: selectedActivityId,
              planBlocksBackups: planBlocksBackups,
              onOpenVersion: onOpen ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a spinner until the first fetch settles', (tester) async {
    // The empty state must not paint before the first response, or a document
    // with history reads "no records" for the length of a round trip.
    final completer = Completer<DocumentVersionPage>();
    await _pump(
      tester,
      api: _FakeVersionsApi(completer: completer),
      settle: false,
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);

    completer.complete(const DocumentVersionPage.empty());
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('empty history explains itself and never says "No History"', (
    tester,
  ) async {
    await _pump(tester, api: _FakeVersionsApi());
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No records found'), findsOneWidget);
    expect(
      find.text('A version is saved each time the document changes.'),
      findsOneWidget,
    );
    // `no_history` is Greek in fr.json and English in zh_CN, and
    // `_app_pending.json` cannot override a present-but-wrong locale value.
    expect(find.text('No History'), findsNothing);
  });

  testWidgets('an unsynced record fires no request and offers no dead retry', (
    tester,
  ) async {
    // A `tmp_` id 404s server-side, and a 404 is a plain permanent 4xx here —
    // so a naive fetch leaves a raw server string behind a Retry that can
    // never succeed.
    final api = _FakeVersionsApi();
    await _pump(tester, api: api, entityId: 'tmp_abc');
    expect(api.calls, 0);
    expect(find.byType(ErrorView), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('a failed fetch shows the server message and retries', (
    tester,
  ) async {
    final api = _FakeVersionsApi(
      error: ServerException(404, 'No backup exists for this activity'),
    );
    await _pump(tester, api: api);
    expect(find.byType(ErrorView), findsOneWidget);
    expect(
      find.textContaining('No backup exists for this activity'),
      findsOneWidget,
    );

    expect(api.calls, 1);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(api.calls, 2);
  });

  testWidgets('lists the current version first, then each saved version', (
    tester,
  ) async {
    final api = _FakeVersionsApi(
      page: DocumentVersionPage(
        versions: [
          _v(id: 'a', amount: '150', epoch: 1789733761, userId: 'u1'),
          _v(id: 'b', amount: '100', epoch: 1789730000, isSystem: true),
        ],
        truncated: false,
      ),
    );
    await _pump(tester, api: api);

    // The anchor row, and the only way back to "now" from the picker.
    expect(find.text('Current version'), findsOneWidget);
    // Event labels come from the shared catalog, so they cost no new strings.
    expect(find.text('Update Invoice'), findsNWidgets(2));
    // The actor: a roster name, and the server's own "System".
    expect(find.textContaining('Jane Doe'), findsOneWidget);
    expect(find.textContaining('System'), findsOneWidget);
  });

  testWidgets('a delta renders on the newer row and never on the oldest', (
    tester,
  ) async {
    final api = _FakeVersionsApi(
      page: DocumentVersionPage(
        versions: [
          _v(id: 'a', amount: '150', epoch: 1789733761),
          _v(id: 'b', amount: '100', epoch: 1789730000),
        ],
        truncated: false,
      ),
    );
    await _pump(tester, api: api);

    // 150 − 100, with an explicit `+` to match the `-` money already emits.
    expect(find.text(r'+$50.00'), findsOneWidget);
    // Exactly one delta in the tree, and it is the positive one: the oldest
    // row holds no honest predecessor (its real one may sit beyond the
    // server's 50-activity window), so it shows none. A tree-wide `$` count
    // would also pass if the delta had landed on the wrong row; naming the
    // signed value rules that out, since only one ordering produces `+$50.00`.
    expect(find.textContaining(r'+$'), findsOneWidget);
    expect(find.textContaining(r'-$'), findsNothing);
  });

  testWidgets('a zero delta renders nothing at all', (tester) async {
    // Most events — mark sent, archive, a reminder — leave the total alone,
    // and a column of $0.00 would claim a change that did not happen.
    final api = _FakeVersionsApi(
      page: DocumentVersionPage(
        versions: [
          _v(id: 'a', amount: '100', epoch: 1789733761),
          _v(id: 'b', amount: '100', epoch: 1789730000),
        ],
        truncated: false,
      ),
    );
    await _pump(tester, api: api);
    expect(find.text(r'+$0.00'), findsNothing);
    expect(find.text(r'$0.00'), findsNothing);
  });

  testWidgets('a truncated window says so rather than implying completeness', (
    tester,
  ) async {
    final api = _FakeVersionsApi(
      page: DocumentVersionPage(
        versions: [_v(id: 'a', amount: '100')],
        truncated: true,
      ),
    );
    await _pump(tester, api: api);
    expect(find.text("Older versions aren't shown."), findsOneWidget);
  });

  testWidgets('tapping a row reports its activity id; Current reports null', (
    tester,
  ) async {
    final opened = <String?>[];
    final api = _FakeVersionsApi(
      page: DocumentVersionPage(
        versions: [_v(id: 'a', amount: '150')],
        truncated: false,
      ),
    );
    await _pump(tester, api: api, onOpen: opened.add);

    await tester.tap(find.text('Update Invoice'));
    await tester.pumpAndSettle();
    expect(opened, ['a']);

    await tester.tap(find.text('Current version'));
    await tester.pumpAndSettle();
    expect(opened, ['a', null]);
  });

  testWidgets('a portal contact is named ahead of the acting user', (
    tester,
  ) async {
    // An approval or rejection from the other side is the change users least
    // expect to find, so the contact wins when both ids are present.
    final api = _FakeVersionsApi(
      page: DocumentVersionPage(
        versions: [_v(id: 'a', amount: '150', userId: 'u1', contactId: 'c1')],
        truncated: false,
      ),
    );
    await _pump(tester, api: api);
    expect(find.textContaining('Dana Portal'), findsOneWidget);
    expect(find.textContaining('Jane Doe'), findsNothing);
  });

  testWidgets('an unresolvable actor is never an em dash', (tester) async {
    // An edit *was* made by somebody — `UserAvatar`'s rule, deliberately not
    // `UserNameLabel`'s.
    final api = _FakeVersionsApi(
      page: DocumentVersionPage(
        versions: [_v(id: 'a', amount: '150', userId: 'ghost')],
        truncated: false,
      ),
    );
    await _pump(tester, api: api);
    expect(find.textContaining('—'), findsNothing);
    expect(find.textContaining('User'), findsOneWidget);
  });

  testWidgets('an activity type outside the catalog fills its placeholder', (
    tester,
  ) async {
    // `activity_unknown` is "Activity #:id"; a mismatched param name
    // substitutes nothing and prints the raw token at the user.
    final api = _FakeVersionsApi(
      page: DocumentVersionPage(
        versions: [_v(id: 'a', amount: '10', typeId: '99999')],
        truncated: false,
      ),
    );
    await _pump(tester, api: api);
    expect(find.textContaining(':id'), findsNothing);
    expect(find.text('Activity #99999'), findsOneWidget);
  });

  testWidgets('Retry keeps the spinner instead of claiming no history', (
    tester,
  ) async {
    // `refresh()` clears the error synchronously while `_loaded` is still
    // true, so gating only on `hasLoaded` drops the retry into the empty
    // state for the whole round trip.
    final completer = Completer<DocumentVersionPage>();
    var calls = 0;
    final api = _RetryApi(() {
      calls++;
      return calls == 1
          ? Future<DocumentVersionPage>.error(Exception('offline'))
          : completer.future;
    });
    await _pump(tester, api: api);
    expect(find.byType(ErrorView), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No records found'), findsNothing);

    completer.complete(const DocumentVersionPage.empty());
    await tester.pumpAndSettle();
  });

  testWidgets('nothing is announced selected when no selection is driving', (
    tester,
  ) async {
    // On narrow a row tap navigates and the notifier is never written, so the
    // anchor row must not sit permanently filled and announced as selected.
    final api = _FakeVersionsApi(
      page: DocumentVersionPage(
        versions: [_v(id: 'a', amount: '10')],
        truncated: false,
      ),
    );
    await _pump(tester, api: api, showSelection: false);
    final handle = tester.ensureSemantics();
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected == true),
      isEmpty,
    );
    handle.dispose();
  });

  testWidgets('the plan-gated empty state offers a reachable upgrade action', (
    tester,
  ) async {
    // Not `PlanGateBanner`: it self-hides for a trialing user, which is
    // exactly the user this branch is shown to.
    await _pump(tester, api: _FakeVersionsApi(), planBlocksBackups: true);
    expect(
      find.text('Document history is available on a paid plan.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Upgrade'), findsOneWidget);
  });
}

/// Drives a sequence of results so a retry can be observed mid-flight.
class _RetryApi extends _FakeVersionsApi {
  _RetryApi(this.next);
  final Future<DocumentVersionPage> Function() next;

  @override
  Future<DocumentVersionPage> fetchForEntity({
    required String basePath,
    required String id,
  }) => next();
}
