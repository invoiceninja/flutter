import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/company_gateway_repository.dart';
import 'package:admin/ui/core/widgets/company_gateway_name_label.dart';

import '../../../_localization_helper.dart';

class _FakeGatewayRepo implements CompanyGatewayRepository {
  _FakeGatewayRepo(this.byId);
  final Map<String, CompanyGateway> byId;
  @override
  Stream<CompanyGateway?> watch({
    required String companyId,
    required String id,
  }) => Stream<CompanyGateway?>.value(byId[id]);
  // Cold peek cache: keeps these tests on the async watch path,
  // exactly as before `BaseEntityRepository.peek` existed.
  @override
  CompanyGateway? peek({required String companyId, required String id}) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueListenable<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices({required this.auth, required this.companyGateways});
  @override
  final AuthRepository auth;
  @override
  final CompanyGatewayRepository companyGateways;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _FakeServices services;

  setUp(() {
    final session = ValueNotifier<AuthSession?>(
      const AuthSession(
        baseUrl: '',
        isHosted: false,
        accountId: '',
        companies: [],
        currentCompanyId: 'co',
      ),
    );
    services = _FakeServices(
      auth: _FakeAuth(session),
      companyGateways: _FakeGatewayRepo({
        'g1': const CompanyGateway(id: 'g1', label: 'Stripe'),
      }),
    );
  });

  Future<void> pump(WidgetTester tester, String gatewayId) async {
    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: Center(child: CompanyGatewayNameLabel(gatewayId: gatewayId)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('resolves the gateway label from the local cache', (
    tester,
  ) async {
    await pump(tester, 'g1');
    expect(find.text('Stripe'), findsOneWidget);
    expect(find.text('g1'), findsNothing);
  });

  testWidgets('falls back to the raw id for an unknown gateway', (
    tester,
  ) async {
    await pump(tester, 'ghost');
    expect(find.text('ghost'), findsOneWidget);
  });

  testWidgets('renders an em-dash for an empty id', (tester) async {
    await pump(tester, '');
    expect(find.text('—'), findsOneWidget);
  });
}
