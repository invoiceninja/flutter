import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/phone_actions_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/timezone.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/utils/formatting.dart';

/// UTC+13:45 — not an offset any real machine runs at, so the
/// "same offset as this device ⇒ render nothing" branch of `ContactLocalTime`
/// can't accidentally swallow the widget on a developer's laptop.
const kTestForeignTimezone = Timezone(
  id: 'tz',
  name: 'Test/Zone',
  location: 'Test',
  utcOffset: 13 * 3600 + 45 * 60,
);

/// The smallest `Services` a detail card needs now that phone numbers are
/// tap-to-call (invoiceninja/flutter#109): `PhoneActionsScope` reads
/// `Provider<Services>` on every phone surface, so a card carrying a number no
/// longer renders under a bare `MaterialApp`.
///
/// Everything else throws — this is a harness for widgets whose only dependency
/// on `Services` is the phone-actions slice, not a stand-in for the real graph.
/// That now includes behaviour tests: `party_call_button_test.dart` and the
/// two list-tile tests dial, open the picker and assert on the launcher through
/// it. A widget that needs a repository still wants the shell fixture
/// (`test/ui/features/shell/_shell_test_helpers.dart`).
class PhoneActionsTestServices implements Services {
  PhoneActionsTestServices._(this.phoneActions, this._zone);

  /// [timezone] defaults to [kTestForeignTimezone] so `ContactLocalTime`
  /// actually renders and an overflow sweep measures its width. Pass null for
  /// the "no timezone configured" case.
  factory PhoneActionsTestServices({
    Timezone? timezone = kTestForeignTimezone,
  }) {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return PhoneActionsTestServices._(PhoneActionsController(db: db), timezone);
  }

  @override
  final PhoneActionsController phoneActions;
  final Timezone? _zone;

  @override
  late final AuthRepository auth = _Auth();
  @override
  late final SettingsRepository settings = _Settings(_zone);
  @override
  late final StaticsRepository statics = _Statics(_zone);

  @override
  Formatter? formatterIfReady(String companyId) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Wraps [child] in the minimal `Provider<Services>` above.
Widget withPhoneActionsServices(Widget child, {Timezone? timezone}) =>
    Provider<Services>.value(
      value: PhoneActionsTestServices(timezone: timezone),
      child: child,
    );

class _Auth implements AuthRepository {
  /// Signed in to company `co` with an empty roster.
  ///
  /// Two things reach through the auth repo here: `currentCompanyId` (the
  /// settings cascade's company key) and the admin/owner gate in
  /// `ClientActions.itemsFor` / `VendorActions.itemsFor`, which a list tile
  /// builds for its `…` menu. `AuthSession.currentCompany` walks [companies]
  /// and returns null for an empty one, so the gate reads "not an admin" and
  /// the admin-only verbs stay out of the menu.
  ///
  /// A *null* session with a non-null [currentCompanyId] would be the smaller
  /// change and is what this fake used to do, but the pair is unreachable in
  /// production (`AuthRepository.currentCompanyId` is derived from the session)
  /// and it fails in the wrong direction: `PartyCallButton` resolves its
  /// company through `session.value`, so it would render `SizedBox.shrink()`
  /// and let a `findsNothing` pass vacuously instead of throwing.
  @override
  final ValueListenable<AuthSession?> session = ValueNotifier<AuthSession?>(
    const AuthSession(
      baseUrl: 'https://example.test',
      isHosted: false,
      accountId: 'acct',
      companies: [],
      currentCompanyId: 'co',
    ),
  );

  @override
  String? get currentCompanyId => session.value?.currentCompanyId;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Settings implements SettingsRepository {
  _Settings(this.zone);
  final Timezone? zone;

  // `SynchronousFuture` so `ContactLocalTime`'s resolve lands during the same
  // `pumpWidget` microtask drain — an overflow sweep that only calls `pump()`
  // would otherwise measure the frame before the suffix exists.
  @override
  Future<Map<String, dynamic>> resolved({
    required String companyId,
    String? clientId,
  }) => SynchronousFuture(zone == null ? const {} : {'timezone_id': zone!.id});

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Statics implements StaticsRepository {
  _Statics(this.zone);
  final Timezone? zone;

  @override
  Timezone? timezone(String id) =>
      (zone != null && zone!.id == id) ? zone : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
