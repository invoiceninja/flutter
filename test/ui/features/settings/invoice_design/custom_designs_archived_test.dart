import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/bodies/custom_designs_body.dart';

import '../../../../_localization_helper.dart';

/// Archiving a design used to make it unreachable: the list watches active
/// designs only, so there was nowhere to find one again and nothing to
/// restore it with.

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueNotifier<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeDesignRepo implements DesignRepository {
  final archived = StreamController<List<Design>>.broadcast();
  List<Design> lastArchived = const [];
  int refreshes = 0;
  final sweeps = <bool>[];
  Object? refreshError;
  final restored = <String>[];

  /// False is a device with no connection: the restore is queued, and the
  /// row stays until the server has answered.
  bool restoreLands = true;

  void emitArchived(List<Design> designs) {
    lastArchived = designs;
    archived.add(designs);
  }

  @override
  Stream<List<Design>> watchAll({required String companyId}) =>
      Stream.value(const []);

  @override
  Stream<List<Design>> watchArchived({required String companyId}) async* {
    yield lastArchived;
    yield* archived.stream;
  }

  @override
  Future<void> refreshAll({
    required String companyId,
    bool full = false,
  }) async {
    refreshes++;
    sweeps.add(full);
    final e = refreshError;
    if (e != null) throw e;
  }

  @override
  Future<void> restore({required String companyId, required String id}) async {
    restored.add(id);
    if (!restoreLands) return;
    emitArchived([
      for (final d in lastArchived)
        if (d.id != id) d,
    ]);
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices({required this.auth, required this.designs});
  @override
  final AuthRepository auth;
  @override
  final DesignRepository designs;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session({bool pro = true}) => AuthSession(
  baseUrl: 'https://example.test',
  // Self-hosted always has access; hosted with no plan is the gated case.
  isHosted: !pro,
  accountId: 'acct',
  companies: [
    AuthCompany(
      id: 'co-A',
      name: 'Co A',
      displayName: 'Co A',
      permissions: '',
      isAdmin: true,
      isOwner: true,
    ),
  ],
  currentCompanyId: 'co-A',
  plan: pro ? 'pro' : '',
);

Design _design(String id, String name, {bool custom = true}) => Design(
  id: id,
  name: name,
  isCustom: custom,
  isActive: true,
  isTemplate: false,
  isFree: false,
  entities: const ['invoice'],
  template: const DesignTemplate(),
  updatedAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  archivedAt: DateTime.utc(2026, 2),
  isDeleted: false,
);

void main() {
  late _FakeDesignRepo repo;
  late ToastController toasts;

  setUp(() {
    repo = _FakeDesignRepo();
    toasts = ToastController();
  });
  tearDown(() async {
    await repo.archived.close();
    toasts.dispose();
  });

  Future<void> pump(WidgetTester tester, {bool pro = true}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: MultiProvider(
          providers: [
            Provider<Services>.value(
              value: _FakeServices(
                auth: _FakeAuth(ValueNotifier(_session(pro: pro))),
                designs: repo,
              ),
            ),
            ChangeNotifierProvider<ToastController>.value(value: toasts),
          ],
          child: const Scaffold(body: CustomDesignsBody()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> showArchived(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Show archived'));
    await tester.tap(find.text('Show archived'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('off by default: an archived design is not in the way', (
    tester,
  ) async {
    repo.lastArchived = [_design('a1', 'Old letterhead')];
    await pump(tester);
    expect(find.text('Old letterhead'), findsNothing);
    expect(repo.refreshes, 0, reason: 'nothing is fetched until asked');
  });

  testWidgets('on: asks the server, lists them, and Restore brings one back', (
    tester,
  ) async {
    repo.lastArchived = [_design('a1', 'Old letterhead')];
    await pump(tester);
    await showArchived(tester);
    // The login bundle never carries an archived design — and the sweep
    // has to be a full one: a delta starts at the cursor the bundle left,
    // and a design archived before that is not in it.
    expect(repo.refreshes, 1);
    expect(repo.sweeps, [true]);
    expect(find.text('Old letterhead'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Restore'));
    await tester.pump();
    await tester.pump();
    expect(repo.restored, ['a1']);
    expect(find.text('Old letterhead'), findsNothing);
    expect(find.text('No archived designs.'), findsOneWidget);
    // It says so — and the toast's own timer has to run out before the
    // test may end.
    expect(toasts.toasts.single.message, 'Successfully restored design');
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('a restore that has not reached the server does not say it has', (
    tester,
  ) async {
    repo
      ..lastArchived = [_design('a1', 'Old letterhead')]
      ..restoreLands = false;
    await pump(tester);
    await showArchived(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Restore'));
    await tester.pump();
    await tester.pump();
    expect(repo.restored, ['a1']);
    expect(toasts.toasts, isEmpty, reason: 'nothing is known yet');
    // The row is still there, so "restored" would be a lie.
    expect(find.text('Old letterhead'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    expect(
      toasts.toasts.single.message,
      startsWith('Changes are saved locally'),
    );
    await tester.pump(const Duration(seconds: 15));
  });

  testWidgets('offline it still shows what this device knows', (tester) async {
    repo
      ..lastArchived = [_design('a1', 'Old letterhead')]
      ..refreshError = StateError('offline');
    await pump(tester);
    await showArchived(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Old letterhead'), findsOneWidget);
  });

  testWidgets('none: says so, once the answer is in', (tester) async {
    await pump(tester);
    await showArchived(tester);
    expect(find.text('No archived designs.'), findsOneWidget);
  });

  testWidgets('a free account can look but not restore', (tester) async {
    repo.lastArchived = [_design('a1', 'Old letterhead')];
    await pump(tester, pro: false);
    await showArchived(tester);
    expect(find.text('Old letterhead'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Restore'), findsNothing);
  });

  testWidgets('switched off again, the list is put away', (tester) async {
    repo.lastArchived = [_design('a1', 'Old letterhead')];
    await pump(tester);
    await showArchived(tester);
    await showArchived(tester);
    expect(find.text('Old letterhead'), findsNothing);
  });
}
