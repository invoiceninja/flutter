// The hosted name prompt's save path (React #3341): the password it asks for
// first must ride on the PUT, success is what the server confirmed rather than
// "the drain ran", and the required (pre-upgrade) form always has a way out.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/ui/features/auth/widgets/name_required_dialog.dart';

import '../../../_localization_helper.dart';

AuthSession _session({String first = '', String last = ''}) => AuthSession(
  baseUrl: 'https://invoicing.co',
  isHosted: true,
  accountId: 'a1',
  companies: const [],
  currentCompanyId: 'co1',
  userId: 'u1',
  userFirstName: first,
  userLastName: last,
);

class _FakeAuth implements AuthRepository {
  final ValueNotifier<AuthSession?> sess = ValueNotifier(_session());

  @override
  ValueListenable<AuthSession?> get session => sess;

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeUsers implements UserRepository {
  final List<({User draft, bool requiresPassword})> enqueued = [];

  @override
  Future<User?> get({
    required String companyId,
    required String userId,
  }) async => const User(id: 'u1');

  @override
  Future<void> enqueueUpdate({
    required String companyId,
    required User draft,
    required Map<String, dynamic> body,
    bool requiresPassword = false,
  }) async => enqueued.add((draft: draft, requiresPassword: requiresPassword));

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeSync implements SyncRepository {
  _FakeSync(this.onDrain);

  /// What one drain does to the session — the PUT's response patching it, or
  /// nothing (offline / rejected).
  final void Function() onDrain;
  int drains = 0;

  @override
  Future<int> drainOnce({required String companyId}) async {
    drains++;
    onDrain();
    return 0;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices({required this.sync});

  @override
  final _FakeAuth auth = _FakeAuth();
  @override
  final _FakeUsers user = _FakeUsers();
  @override
  final SyncRepository sync;
  @override
  final PasswordCache passwordCache = PasswordCache()..set('pw');

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  Future<bool?> run(
    WidgetTester tester,
    _FakeServices services, {
    bool required = false,
    Future<void> Function()? interact,
  }) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await promptForUserName(
              context,
              services,
              required: required,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    if (interact != null) {
      await interact();
    } else {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Ada');
      await tester.enterText(fields.at(1), 'Lovelace');
      await tester.tap(find.text(bundledLocalization().lookup('save')));
    }
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('the save carries the password, and succeeds once the server '
      'has the names', (tester) async {
    late _FakeServices services;
    services = _FakeServices(
      sync: _FakeSync(
        () =>
            services.auth.sess.value = _session(first: 'Ada', last: 'Lovelace'),
      ),
    );

    expect(await run(tester, services), isTrue);
    final saved = services.user.enqueued.single;
    expect(saved.requiresPassword, isTrue);
    expect(saved.draft.firstName, 'Ada');
    expect(saved.draft.lastName, 'Lovelace');
  });

  testWidgets('a save the server never confirmed is not a success', (
    tester,
  ) async {
    final sync = _FakeSync(() {});
    final services = _FakeServices(sync: sync);

    expect(await run(tester, services, required: true), isFalse);
    // A drain already under way is followed by one more before giving up.
    expect(sync.drains, 2);
  });

  testWidgets('the required form can be cancelled', (tester) async {
    final services = _FakeServices(sync: _FakeSync(() {}));

    final result = await run(
      tester,
      services,
      required: true,
      interact: () async {
        await tester.tap(find.text(bundledLocalization().lookup('cancel')));
      },
    );

    expect(result, isFalse);
    expect(services.user.enqueued, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
