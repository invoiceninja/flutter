import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/data/services/docuninja/docuninja_login_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/docuninja/docuninja_access.dart';
import 'package:admin/ui/core/utils/fab_clearance.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/filter_icon_button.dart';
import 'package:admin/ui/core/widgets/toast_host.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_documents_view_model.dart';
import 'package:admin/ui/features/docuninja/views/docuninja_screen.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_builder_link.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_documents_list.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_filter_dialog.dart';

import '../../../_localization_helper.dart';
import '../../../_support/fake_url_launcher.dart';
import '../shell/_shell_test_helpers.dart';

/// The documents page on a phone (portrait and landscape): create without
/// leaving the app, the `+` and its sheet, selection chrome, the filter
/// sheet, the narrow rows and the first-run empty page.
class _Api implements DocuNinjaApi {
  _Api({this.rows = 0});

  final int rows;
  final created = <String>[];

  @override
  Future<DnDocument> createDocument({
    required String description,
    required List<DnUploadPart> files,
  }) async {
    created.add(description);
    return DnDocument.fromJson({'id': 'new1', 'status_id': 1});
  }

  @override
  Future<DnPage<DnDocument>> documents({
    int page = 1,
    int perPage = 20,
    String search = '',
    String status = '',
    String sort = 'id|desc',
  }) async => DnPage(
    items: [
      for (var i = 0; i < rows; i++)
        DnDocument.fromJson({'id': 'd$i', 'status_id': 1}),
    ],
    currentPage: 1,
    lastPage: 1,
    total: rows,
  );

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A ready session for an admin of the company the fixture signs in to,
/// that never runs a handshake of its own.
class _Session extends DocuNinjaSession {
  _Session()
    : super(
        loginApi: _NoLoginApi(),
        auth: ValueNotifier(null),
        companyKeyOf: (_) async => null,
      ) {
    final json =
        jsonDecode(
              File('test/fixtures/docuninja/login.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final data = Map<String, dynamic>.from(json['data'] as Map? ?? json);
    data['company_user'] = {
      ...Map<String, dynamic>.from(data['company_user'] as Map),
      'is_admin': true,
      'is_owner': true,
    };
    value = DocuNinjaState(
      DocuNinjaAccess.ready,
      login: DnLogin.fromJson(data),
      company: DnCompany.fromJson(const {'id': 'dn1', 'token': 't'}),
    );
  }

  @override
  Future<void> load({bool force = false}) async {}
}

class _NoLoginApi implements DocuNinjaLoginApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void _size(WidgetTester tester, Size size, {double bottomInset = 0}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(bottom: bottomInset);
  tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
  addTearDown(tester.view.reset);
}

const _portrait = Size(393, 852);
const _landscape = Size(852, 393);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The documents page under a router (a create lands on `/docuninja/:id`),
/// with the app's toast host.
Future<({ShellFixture fixture, _Api api})> _pumpScreen(
  WidgetTester tester, {
  int rows = 0,
}) async {
  final fixture = await buildFixture(
    companies: [FakeCompany(id: 'co1', name: 'Acme')],
  );
  addTearDown(fixture.dispose);
  final api = _Api(rows: rows);
  final session = _Session();
  addTearDown(session.dispose);
  final router = GoRouter(
    initialLocation: '/docuninja',
    routes: [
      GoRoute(
        path: '/docuninja',
        builder: (_, _) => const DocuNinjaScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, s) =>
                Scaffold(body: Text('document ${s.pathParameters['id']}')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<Services>.value(value: fixture.services),
        Provider<DocuNinjaApi>.value(value: api),
        ChangeNotifierProvider<DocuNinjaSession?>.value(value: session),
      ],
      child: MaterialApp.router(
        theme: ThemeData.light().copyWith(
          extensions: <ThemeExtension<dynamic>>[InTheme.light],
        ),
        locale: const Locale('en'),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        routerConfig: router,
        builder: (context, child) => Stack(
          children: [
            child!,
            Positioned.fill(
              child: ToastHost(controller: fixture.services.toasts),
            ),
          ],
        ),
      ),
    ),
  );
  await _settle(tester);
  return (fixture: fixture, api: api);
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
}

UploadSource _file(String name) =>
    BytesUploadSource(Uint8List.fromList('not a pdf'.codeUnits), name);

void main() {
  group('the builder helpers', () {
    test('a native phone defers the browser builder; a desktop does not', () {
      // The embed is off in a test build, so the builder opens outside.
      expect(dnBuilderOpensExternally(), isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(dnDeferBuilderOnPhone(), isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(dnDeferBuilderOnPhone(), isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(dnDeferBuilderOnPhone(), isFalse);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('a create on a mobile device lands on the document and stays '
      'in the app', (tester) async {
    // A tablet: still mobile (the rule is the device's), and its pane still
    // has the drop zone to create from — a phone's one way in is the FAB.
    _size(tester, const Size(1024, 1366));
    final launcher = installFakeUrlLauncher();
    final pumped = await _pumpScreen(tester);

    final zone = tester.widget<FileDropZone>(find.byType(FileDropZone));
    await zone.onFiles([_file('Sales_contract.docx')]);
    await _settle(tester);

    expect(pumped.api.created, ['Sales Contract']);
    expect(find.text('document new1'), findsOneWidget);
    expect(launcher.launched, isEmpty, reason: 'no browser on a phone');
    expect(
      pumped.fixture.services.toasts.toasts.map((t) => t.message),
      contains('Document created'),
    );
    await _dispose(tester);
  });

  testWidgets('a create on a desktop still opens the builder', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    _size(tester, const Size(1200, 800));
    final launcher = installFakeUrlLauncher();
    final pumped = await _pumpScreen(tester);

    final zone = tester.widget<FileDropZone>(find.byType(FileDropZone));
    await zone.onFiles([_file('Sales_contract.docx')]);
    await _settle(tester);

    expect(pumped.api.created, ['Sales Contract']);
    expect(find.text('document new1'), findsOneWidget);
    expect(launcher.launched.single, contains('/docuninja/new1/builder'));
    debugDefaultTargetPlatformOverride = null;
    await _dispose(tester);
  });

  testWidgets('a phone creates from a `+` and its sheet, not the app bar', (
    tester,
  ) async {
    _size(tester, _portrait);
    await _pumpScreen(tester, rows: 2);

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.add),
      ),
      findsNothing,
    );
    // Rows to show: the tiles step aside for them.
    expect(find.text('Camera'), findsNothing);

    await tester.tap(fab);
    await _settle(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);

    // A name first: the New Document dialog.
    await tester.tap(find.byIcon(Icons.edit_note_outlined));
    await _settle(tester);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.widgetWithText(AlertDialog, 'New Document'), findsOneWidget);
    // The name is optional: no keyboard over the file pickers on touch.
    expect(
      tester.widget<TextField>(find.byType(TextField).last).autofocus,
      isFalse,
    );
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    await _dispose(tester);
  });

  testWidgets('the last row clears the `+` and the home indicator', (
    tester,
  ) async {
    _size(tester, _portrait, bottomInset: 34);
    await _pumpScreen(tester, rows: 2);

    final list = find.byType(DocuNinjaDocumentsList);
    final context = tester.element(list);
    final expected = fabScrollClearance(context);
    expect(expected, greaterThan(kFabClearance + 34 - 1));
    expect(
      find.descendant(
        of: list,
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == expected,
        ),
      ),
      findsOneWidget,
    );
    await _dispose(tester);
  });

  testWidgets('selecting on a phone: one bar, its actions in sight', (
    tester,
  ) async {
    _size(tester, _portrait);
    await _pumpScreen(tester, rows: 3);
    expect(find.byType(FilterIconButton), findsOneWidget);

    await tester.longPress(find.text('Untitled document').first);
    await _settle(tester);

    // The app bar's +, filter and ⋮ step aside, and the `+` with them.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(FilterIconButton), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    // The bulk actions are buttons, not a second ⋮.
    expect(find.byTooltip('Archive'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel'));
    await _settle(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(FilterIconButton), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('a landscape phone keeps the rows and the `+`', (tester) async {
    _size(tester, _landscape);
    await _pumpScreen(tester, rows: 2);

    // Not the table: no column header strip, no wide toolbar.
    expect(find.text('CONTACT'), findsNothing);
    expect(find.text('Lifecycle: Active'), findsNothing);
    expect(find.byType(FilterIconButton), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    // Nor the tiles over the rows.
    expect(find.text('Camera'), findsNothing);
    expect(find.text('Untitled document'), findsNWidgets(2));
    await _dispose(tester);
  });

  testWidgets('the filter is a sheet on a phone, headed as the toolbar', (
    tester,
  ) async {
    _size(tester, _portrait);
    await _pumpScreen(tester, rows: 1);

    await tester.tap(find.byType(FilterIconButton));
    await _settle(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Lifecycle'), findsOneWidget);
    expect(find.text('State'), findsNothing);

    await tester.tap(find.text('Archived'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await _settle(tester);
    expect(find.byType(BottomSheet), findsNothing);
    final vm = tester
        .widget<DocuNinjaDocumentsList>(find.byType(DocuNinjaDocumentsList))
        .vm;
    expect(vm.states, {'active', 'archived'});
    await _dispose(tester);
  });

  testWidgets('the filter stays a dialog with a pointer', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDnFilterPicker(context, states: {'active'}),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Lifecycle'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    await _dispose(tester);
  });

  testWidgets('an empty phone list says what the page is for', (tester) async {
    _size(tester, _portrait);
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    final vm = DocuNinjaDocumentsViewModel(api: _Api());
    addTearDown(vm.dispose);
    var created = 0;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        DocuNinjaDocumentsList(
          vm: vm,
          onOpen: (_) {},
          onCreate: () => created++,
          onClearFilters: () {},
        ),
      ),
    );
    await vm.refresh();
    await _settle(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No records found'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'New Document'));
    expect(created, 1);

    // A filtered empty result keeps the slim line and Clear filters.
    vm.setFilters(statuses: {'sent'}, states: {'active'});
    await _settle(tester);
    expect(find.byType(EmptyState), findsNothing);
    expect(find.text('No records found'), findsOneWidget);
    expect(find.text('Clear Filters'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('the real screen on an empty phone page offers one create: the '
      '`+`', (tester) async {
    _size(tester, _portrait);
    await _pumpScreen(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(EmptyState), findsOneWidget);
    // No tiles above it and no second button inside it, each to its own
    // flow.
    expect(find.byType(FileDropZone), findsNothing);
    expect(find.widgetWithText(FilledButton, 'New Document'), findsNothing);
    await _dispose(tester);
  });

  testWidgets('a builder opened after a save waits for a tap on a phone, and '
      'says it leaves the app', (tester) async {
    _size(tester, _portrait);
    final launcher = installFakeUrlLauncher();
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => notifyAndOpenDocuNinjaBuilder(
              context,
              message: 'Template created',
              documentId: 'b1',
              companyId: 'co1',
              template: true,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await _settle(tester);
    // Use Template, New Template and Clone to Template all come here: none
    // of them throws a phone out to the browser.
    expect(launcher.launched, isEmpty);
    final toast = fixture.services.toasts.toasts.single;
    expect(toast.message, 'Template created');
    expect(toast.action?.label, 'Edit in browser');
    toast.action!.onPressed();
    await _settle(tester);
    expect(launcher.launched, hasLength(1), reason: 'the user chose to');
    await _dispose(tester);
  });

  test(
    'every builder or sign action names the browser while it opens there',
    () {
      // The embedded builder is off in this build.
      expect(dnBuilderOpensExternally(), isTrue);
      expect(dnBuilderEditIcon(), Icons.open_in_new);
      expect(dnBuilderEditLabelKey(), 'edit_in_browser');
      expect(dnSignLabelKey(), 'sign_in_browser');
    },
  );
}
