import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/pending_call_controller.dart';
import 'package:admin/app/phone_actions_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/value/timezone.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
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
/// The one exception is [PhoneActionsTestServices.clients] / [vendors], which
/// answer a **one-record stub** when the factory is given a `client:` /
/// `vendor:` and otherwise keep throwing — see the factory.
/// That now includes behaviour tests: `party_call_button_test.dart` and the
/// two list-tile tests dial, open the picker and assert on the launcher through
/// it. A widget that needs a repository still wants the shell fixture
/// (`test/ui/features/shell/_shell_test_helpers.dart`).
class PhoneActionsTestServices implements Services {
  PhoneActionsTestServices._(
    this.phoneActions,
    this._zone,
    this._clients,
    this._vendors,
  );

  /// [timezone] defaults to [kTestForeignTimezone] so `ContactLocalTime`
  /// actually renders and an overflow sweep measures its width. Pass null for
  /// the "no timezone configured" case.
  ///
  /// [client] / [vendor] install a one-record stub repository each, for the
  /// party lookup `promptLogCallFor` does (invoiceninja/flutter#129). Left
  /// null, [clients] / [vendors] keep throwing — which is the point: it is what
  /// pins that the lookup is reached only via an id a caller opted into. A
  /// stubbed repo still answers `null` for any OTHER id, so "no repository
  /// configured" and "this record isn't cached" stay distinguishable.
  ///
  /// [clientHydratesOnEnsureLoaded] starts the client stub EMPTY and lets
  /// `ensureLoaded` populate it, which is the only way to exercise
  /// `_hydrate`'s miss → hydrate → hit path; [clientWatchError] makes `watch`
  /// emit an error instead, for the degradation path. Both are ignored unless
  /// [client] is supplied.
  factory PhoneActionsTestServices({
    Timezone? timezone = kTestForeignTimezone,
    Client? client,
    Vendor? vendor,
    bool clientHydratesOnEnsureLoaded = false,
    bool clientWatchError = false,
  }) {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return PhoneActionsTestServices._(
      PhoneActionsController(db: db),
      timezone,
      client == null
          ? null
          : _Clients(
              client,
              present: !clientHydratesOnEnsureLoaded,
              watchError: clientWatchError,
            ),
      vendor == null ? null : _Vendors(vendor),
    );
  }

  @override
  final PhoneActionsController phoneActions;
  final Timezone? _zone;

  /// Built once, not per access — the stubs count their own calls and can
  /// change what they answer, which is what makes the hydrate path testable.
  final _Clients? _clients;
  final _Vendors? _vendors;

  @override
  ClientRepository get clients => _clients ?? (throw UnimplementedError());

  @override
  VendorRepository get vendors => _vendors ?? (throw UnimplementedError());

  /// How many times the client stub was asked to hydrate. Lets a test pin that
  /// the bounded hydrate ran exactly once rather than on every read.
  int get clientEnsureLoadedCalls => _clients?.ensureLoadedCalls ?? 0;

  @override
  late final AuthRepository auth = _Auth();
  @override
  late final SettingsRepository settings = _Settings(_zone);
  @override
  late final StaticsRepository statics = _Statics(_zone);

  /// Deliberately still null. `formatterIfReady` is what
  /// `phone_actions_section.dart` reads for its business-hours fields, and
  /// handing it a 12-hour formatter would silently flip those from `08:00` to
  /// `8:00 AM` — re-pointing that file's 320 px overflow sweep at ~40 % wider
  /// strings without anyone asking. Only `formatterFor` (which the log-call
  /// sheet awaits) resolves.
  @override
  Formatter? formatterIfReady(String companyId) => null;

  @override
  Future<Formatter> formatterFor(String companyId) async => testFormatter;

  @override
  late final PendingCallController pendingCall = PendingCallController();

  /// A real controller, not a throwing stub: `Notify` swallowed the failure
  /// and dropped every toast silently before. Consequence for new tests — a
  /// test that copies to the clipboard, or that makes the fake launcher fail,
  /// now queues a real toast and must let its timer expire (6 s) or the harness
  /// fails with "A Timer is still pending".
  @override
  late final ToastController toasts = ToastController();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// One-record repository stubs for the log-call party lookup. `watch` answers
/// the seeded record for its own id and `null` for anything else — the shape
/// `promptLogCallFor` reads from Drift — and `ensureLoaded` is a no-op, since
/// there is no network here for it to reach.
class _Clients implements ClientRepository {
  _Clients(this.client, {this.present = true, this.watchError = false});
  final Client client;

  /// Whether the record is "in Drift" yet. [ensureLoaded] flips it, mirroring
  /// the real repo, so `_hydrate`'s second read can succeed where the first
  /// failed.
  bool present;
  final bool watchError;
  int ensureLoadedCalls = 0;

  @override
  Stream<Client?> watch({required String companyId, required String id}) {
    if (watchError) {
      return Stream.error(StateError('drift blew up'), StackTrace.current);
    }
    return Stream.value(present && id == client.id ? client : null);
  }

  @override
  Future<void> ensureLoaded({
    required String companyId,
    required String id,
  }) async {
    ensureLoadedCalls++;
    if (id == client.id) present = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Vendors implements VendorRepository {
  _Vendors(this.vendor);
  final Vendor vendor;

  @override
  Stream<Vendor?> watch({required String companyId, required String id}) =>
      Stream.value(id == vendor.id ? vendor : null);

  @override
  Future<void> ensureLoaded({
    required String companyId,
    required String id,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// A company that prints `d/MMM/yyyy` and 12-hour clocks — enough for
/// `InDateField` / `InTimeField` and the log-call form's composed timestamp.
const kTestFormatSettings = CompanyFormatSettings(
  currencyId: '1',
  countryId: '840',
  dateFormatId: 'X',
  useCommaAsDecimalPlace: false,
  showCurrencyCode: false,
  enableMilitaryTime: false,
  locale: '',
);

final Formatter testFormatter = Formatter(
  settings: kTestFormatSettings,
  currencies: const {},
  countries: const {},
  dateFormats: const {'X': DatetimeFormat(id: 'X', format: 'd/MMM/yyyy')},
);

/// Wraps [child] in the minimal `Provider<Services>` above.
Widget withPhoneActionsServices(
  Widget child, {
  Timezone? timezone,
  Client? client,
  Vendor? vendor,
  bool clientHydratesOnEnsureLoaded = false,
  bool clientWatchError = false,
}) => Provider<Services>.value(
  value: PhoneActionsTestServices(
    timezone: timezone,
    client: client,
    vendor: vendor,
    clientHydratesOnEnsureLoaded: clientHydratesOnEnsureLoaded,
    clientWatchError: clientWatchError,
  ),
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
