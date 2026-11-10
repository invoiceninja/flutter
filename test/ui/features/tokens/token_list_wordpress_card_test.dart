import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/dao/token_dao.dart';
import 'package:admin/data/models/domain/token.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/token_repository.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/core/widgets/copy_value_row.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/tokens/views/token_list_screen.dart';

import '../../../_localization_helper.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth(AuthSession session) : _session = ValueNotifier(session);
  final ValueNotifier<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeTokens implements TokenRepository {
  @override
  Stream<List<Token>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = TokenFieldIds.name,
    bool sortAscending = true,
  }) => Stream.value(const []);

  @override
  Future<void> refreshAll({required String companyId, bool full = false}) =>
      Future.value();

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(this.auth);
  @override
  final AuthRepository auth;
  @override
  final TokenRepository tokens = _FakeTokens();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session({bool admin = true, bool selfHosted = false}) =>
    AuthSession(
      baseUrl: selfHosted
          ? 'https://billing.example.com/api/v1/'
          : 'https://invoicing.co',
      isHosted: !selfHosted,
      accountId: 'acct',
      plan: selfHosted ? '' : 'pro',
      companies: [
        AuthCompany(
          id: 'co',
          name: 'Co',
          displayName: 'Co',
          permissions: '',
          isAdmin: admin,
          isOwner: false,
        ),
      ],
      currentCompanyId: 'co',
    );

/// API Tokens: the WordPress plugin's setup card under the list
/// (docs/companion-apps.md) — for admins only, with the server address to
/// copy only on a self-hosted server.
void main() {
  late ToastController toasts;
  String? copied;

  setUp(() {
    toasts = ToastController();
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    toasts.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(WidgetTester tester, AuthSession session) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(value: _FakeServices(_FakeAuth(session))),
          ChangeNotifierProvider<SettingsLevelController>(
            create: (_) => SettingsLevelController(),
          ),
          ChangeNotifierProvider<ToastController>.value(value: toasts),
        ],
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: const TokenListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final l10n = bundledLocalization();
  String t(String key) => l10n.lookup(key);

  testWidgets('hosted: the card, without a server address', (tester) async {
    await pump(tester, _session());
    expect(find.byType(WordPressSetupCard), findsOneWidget);
    expect(find.text(t('wordpress_setup_body_hosted')), findsOneWidget);
    expect(find.text(t('get_the_plugin')), findsOneWidget);
    expect(find.text(t('server_url')), findsNothing);
    expect(find.byType(CopyValueRow), findsNothing);
  });

  testWidgets('self-hosted: the address to copy, without /api/v1', (
    tester,
  ) async {
    try {
      await pump(tester, _session(selfHosted: true));
      expect(find.text(t('wordpress_setup_body')), findsOneWidget);
      expect(find.text(t('server_url')), findsOneWidget);
      expect(find.text('https://billing.example.com'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(CopyValueRow),
          matching: find.byIcon(Icons.copy_outlined),
        ),
      );
      await tester.pump();
      expect(copied, 'https://billing.example.com');
    } finally {
      toasts.clearAll();
    }
  });

  testWidgets('a member gets no card', (tester) async {
    await pump(tester, _session(admin: false, selfHosted: true));
    expect(find.byType(WordPressSetupCard), findsNothing);
    expect(find.text(t('wordpress_plugin')), findsNothing);
  });
}
