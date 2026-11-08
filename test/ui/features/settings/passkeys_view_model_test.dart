import 'package:admin/data/repositories/passkey_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/passkey_api.dart';
import 'package:admin/data/services/passkey_readiness.dart';
import 'package:admin/ui/features/settings/views/basic/user_details/view_models/passkeys_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin/data/services/passkey_failure.dart';

/// The Passkeys card on Settings → User Details → Two-Factor
/// (docs/passkeys.md).
class _Repo implements PasskeyRepository {
  _Repo({this.rows = const [], this.listError, this.addError});

  List<RegisteredPasskey> rows;
  final Object? listError;
  final Object? addError;
  int lists = 0;
  String? addedName;
  bool? ceremonyAllowed;
  final removed = <String>[];

  @override
  Future<List<RegisteredPasskey>> list() async {
    lists++;
    if (listError != null) throw listError!;
    return rows;
  }

  @override
  Future<void> add({
    String? name,
    required Future<bool> Function(PasskeyLoginOptions options) beforeCeremony,
  }) async {
    ceremonyAllowed = await beforeCeremony(
      const PasskeyLoginOptions(
        publicKey: {
          'rp': {'id': 'app.invoicing.co'},
        },
        challengeToken: 't',
      ),
    );
    if (!ceremonyAllowed!) {
      throw const PasskeyException(PasskeyFailure.notAssociated);
    }
    if (addError != null) throw addError!;
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
  _Readiness({this.ready = true, this.allows = true});

  final bool ready;
  final bool allows;

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
  }) async => allows;
}

const _one = RegisteredPasskey(id: 'p1', name: 'MacBook');

void main() {
  Future<PasskeysViewModel> loaded(_Repo repo, {_Readiness? readiness}) async {
    final vm = PasskeysViewModel(
      repo: repo,
      readiness: readiness ?? _Readiness(),
      apiBaseUrl: 'https://invoicing.co',
      isHosted: true,
    );
    addTearDown(vm.dispose);
    await vm.load();
    return vm;
  }

  test('lists the passkeys and offers Add once proven ready', () async {
    final vm = await loaded(_Repo(rows: [_one]));

    expect(vm.passkeys, [_one]);
    expect(vm.canRegister, isTrue);
    expect(vm.visible, isTrue);
  });

  test('not ready: the rows stay manageable, Add does not show', () async {
    final vm = await loaded(
      _Repo(rows: [_one]),
      readiness: _Readiness(ready: false),
    );

    expect(vm.visible, isTrue);
    expect(vm.canRegister, isFalse);
  });

  test('not ready and nothing to manage: no card at all', () async {
    final vm = await loaded(_Repo(), readiness: _Readiness(ready: false));

    expect(vm.visible, isFalse);
  });

  test('a server from before passkeys: no card at all', () async {
    final vm = await loaded(
      _Repo(listError: const ServerException(404, 'Not Found')),
    );

    expect(vm.serverSupported, isFalse);
    expect(vm.visible, isFalse);
  });

  test('another failure keeps the card, with a retry', () async {
    final vm = await loaded(
      _Repo(listError: const ServerException(500, 'boom')),
    );

    expect(vm.loadFailed, isTrue);
    expect(vm.visible, isTrue);
  });

  test(
    'adding checks the options before the OS sheet, then refreshes',
    () async {
      final repo = _Repo();
      final vm = await loaded(repo);

      final result = await vm.add('Pixel');

      expect(result.ok, isTrue);
      expect(repo.ceremonyAllowed, isTrue);
      expect(repo.addedName, 'Pixel');
      expect(vm.passkeys.map((p) => p.name), ['Pixel']);
    },
  );

  test('options this device cannot use end before the OS sheet', () async {
    final repo = _Repo();
    final vm = await loaded(repo, readiness: _Readiness(allows: false));

    final result = await vm.add('Pixel');

    expect(result.ok, isFalse);
    expect(result.errorKey, 'passkeys_cannot_add_here');
    expect(repo.addedName, isNull);
  });

  test('the outcomes the section reports', () async {
    Future<PasskeyActionResult> addFailing(Object error) async =>
        (await loaded(_Repo(addError: error))).add('x');

    expect(
      (await addFailing(
        const PasskeyException(PasskeyFailure.cancelled),
      )).errorKey,
      isNull,
      reason: 'a dismissed sheet says nothing',
    );
    expect(
      (await addFailing(
        const PasskeyException(PasskeyFailure.alreadyRegistered),
      )).errorKey,
      'passkey_already_registered',
    );
    expect(
      (await addFailing(
        const ValidationException('Maximum number of passkeys reached.', {}),
      )).message,
      'Maximum number of passkeys reached.',
    );
  });

  test('at the server limit, Add does nothing', () async {
    final repo = _Repo(
      rows: [
        for (var i = 0; i < kMaxPasskeysPerUser; i++)
          RegisteredPasskey(id: 'p$i', name: 'Key $i'),
      ],
    );
    final vm = await loaded(repo);

    expect(vm.atLimit, isTrue);
    expect((await vm.add('one more')).ok, isFalse);
    expect(repo.ceremonyAllowed, isNull, reason: 'no options were fetched');
  });

  test('removing refreshes the list', () async {
    final repo = _Repo(rows: [_one]);
    final vm = await loaded(repo);

    final result = await vm.remove(_one);

    expect(result.ok, isTrue);
    expect(repo.removed, ['p1']);
    expect(vm.passkeys, isEmpty);
  });
}
