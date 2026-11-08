import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/confirm_actions_controller.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/passkey_repository.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/passkey_api.dart';
import 'package:admin/data/services/passkey_readiness.dart';
import 'package:admin/ui/core/dialogs/untrusted_certificate_dialog.dart'
    show fallbackCertificateFormatter;
import 'package:admin/ui/features/settings/views/basic/user_details/passkeys_section.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

class _FakeAuth implements AuthRepository {
  @override
  final ValueNotifier<AuthSession?> session = ValueNotifier(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices(this.confirmActions);

  @override
  final AuthRepository auth = _FakeAuth();
  @override
  final ConfirmActionsController confirmActions;
  @override
  Formatter? formatterIfReady(String companyId) => null;
  @override
  Future<Formatter> formatterFor(String companyId) async =>
      fallbackCertificateFormatter();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Repo implements PasskeyRepository {
  _Repo(this.rows);

  List<RegisteredPasskey> rows;
  String? addedName;
  final removed = <String>[];

  @override
  Future<List<RegisteredPasskey>> list() async => rows;

  @override
  Future<void> add({
    String? name,
    required Future<bool> Function(PasskeyLoginOptions options) beforeCeremony,
  }) async {
    addedName = name;
    rows = [...rows, RegisteredPasskey(id: 'new', name: name ?? '')];
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    rows = rows.where((p) => p.id != id).toList();
  }
}

class _Readiness extends PasskeyReadiness {
  _Readiness(this.ready);

  final bool ready;

  @override
  Future<bool> isReady({
    required String apiBaseUrl,
    required bool isHosted,
    String? rpId,
  }) async => ready;

  @override
  Future<bool> allowsCeremony({
    required String apiBaseUrl,
    required bool isHosted,
    required PasskeyLoginOptions options,
  }) async => ready;
}

void main() {
  late DevicePrefsStore prefs;

  setUp(() => prefs = DevicePrefsStore(null));

  Future<void> pump(
    WidgetTester tester,
    _Repo repo, {
    bool ready = true,
    double textScale = 1,
  }) async {
    final confirmActions = ConfirmActionsController(prefs: prefs);
    await confirmActions.set(false);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(value: _FakeServices(confirmActions)),
          Provider<PasskeyRepository>.value(value: repo),
          Provider<PasskeyReadiness>.value(value: _Readiness(ready)),
        ],
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: PasskeysSection(
                apiBaseUrl: 'https://invoicing.co',
                isHosted: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the passkeys with when each was last used', (
    tester,
  ) async {
    await pump(
      tester,
      _Repo([
        RegisteredPasskey(
          id: 'p1',
          name: 'MacBook',
          createdAt: DateTime.utc(2026, 11, 1, 12),
        ),
      ]),
    );

    expect(find.text('Manage Passkeys'), findsOneWidget);
    expect(find.text('MacBook'), findsOneWidget);
    expect(find.textContaining('Last used: Never'), findsOneWidget);
    expect(find.byKey(const ValueKey('passkeys_add')), findsOneWidget);
  });

  testWidgets('Add asks for a name, and Enter submits it', (tester) async {
    final repo = _Repo([]);
    await pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('passkeys_add')));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('passkey_name'));
    expect(field, findsOneWidget);

    await tester.enterText(field, 'Work phone');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repo.addedName, 'Work phone');
    expect(find.text('Work phone'), findsOneWidget, reason: 'listed after');
  });

  testWidgets('Remove takes the passkey off the list', (tester) async {
    final repo = _Repo([const RegisteredPasskey(id: 'p1', name: 'MacBook')]);
    await pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('passkey_remove_p1')));
    await tester.pumpAndSettle();

    expect(repo.removed, ['p1']);
    expect(find.text('MacBook'), findsNothing);
  });

  testWidgets('nothing to manage and nothing to add: no card', (tester) async {
    await pump(tester, _Repo([]), ready: false);

    expect(find.text('Manage Passkeys'), findsNothing);
  });

  testWidgets('rows with no way to add here explain why', (tester) async {
    await pump(
      tester,
      _Repo([const RegisteredPasskey(id: 'p1', name: 'MacBook')]),
      ready: false,
    );

    expect(find.byKey(const ValueKey('passkeys_add')), findsNothing);
    expect(
      find.text(
        "Adding a passkey isn't available on this device for this server.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('a long name and large text fit a phone', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pump(
      tester,
      _Repo([
        RegisteredPasskey(
          id: 'p1',
          name: 'A very long passkey name that goes on and on and on',
          createdAt: DateTime.utc(2026, 11, 1, 12),
          lastUsedAt: DateTime.utc(2026, 11, 6, 12),
        ),
      ]),
      textScale: 1.4,
    );

    expect(tester.takeException(), isNull);
  });
}
