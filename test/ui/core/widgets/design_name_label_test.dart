import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/design_api_model.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/ui/core/widgets/design_name_label.dart';

import '../../../_localization_helper.dart';

class _FakeDesignRepo implements DesignRepository {
  _FakeDesignRepo(this.byId);
  final Map<String, Design> byId;
  @override
  Stream<Design?> watch({required String companyId, required String id}) =>
      Stream<Design?>.value(byId[id]);
  // Cold peek cache: keeps these tests on the async watch path,
  // exactly as before `BaseEntityRepository.peek` existed.
  @override
  Design? peek({required String companyId, required String id}) => null;
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
  _FakeServices({required this.auth, required this.designs});
  @override
  final AuthRepository auth;
  @override
  final DesignRepository designs;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late _FakeServices services;

  setUp(() {
    final clean = Design.fromApi(const DesignApi(id: 'd1', name: 'Clean'));
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
      designs: _FakeDesignRepo({'d1': clean}),
    );
  });

  Future<void> pump(WidgetTester tester, String designId) async {
    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: Center(child: DesignNameLabel(designId: designId)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('resolves the design name from the local catalog', (
    tester,
  ) async {
    await pump(tester, 'd1');
    expect(find.text('Clean'), findsOneWidget);
    expect(find.text('d1'), findsNothing);
  });

  testWidgets('falls back to the raw id for an unknown design', (tester) async {
    await pump(tester, 'ghost');
    expect(find.text('ghost'), findsOneWidget);
  });

  testWidgets('renders an em-dash for an empty id', (tester) async {
    await pump(tester, '');
    expect(find.text('—'), findsOneWidget);
  });
}
