import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:store_services/store_services.dart';

import 'package:admin/app/env.dart';
import 'package:admin/data/models/api/terminal_models.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/terminal_repository.dart';
import 'package:admin/data/services/terminal_platform.dart';
import 'package:admin/domain/terminal/terminal_eligibility.dart';

final _log = Logger('TerminalController');

/// In-person card payments for the session (docs/in-person-payments.md):
/// which companies can take a card, what this phone can read cards with, and
/// the card reader's connection, kept across collections.
///
/// The server decides who may collect and on which gateway
/// (`terminal/config`); this only asks once per company per session, and
/// remembers a server that has no such route so an older one is never asked
/// again. A session end or a company switch [reset]s everything — after any
/// charge in flight has been answered.
class TerminalController extends ChangeNotifier {
  TerminalController({
    required TerminalRepository repository,
    required TerminalPlatform platform,
    required AuthRepository auth,
    required DevicePrefsStore prefs,
    bool? platformReady,
  }) : _repo = repository,
       _platform = platform,
       _auth = auth,
       _prefs = prefs,
       _platformReady = platformReady {
    _readerUsed = prefs.read(DevicePrefKeys.cardReaderUsed) ?? false;
    prefs.addListener(_syncPrefs);
  }

  final TerminalRepository _repo;
  final TerminalPlatform _platform;
  final AuthRepository _auth;
  final DevicePrefsStore _prefs;
  final bool? _platformReady;

  TerminalPlatform get platform => _platform;

  /// The build has the feature, this is the mobile app with Stripe's SDK, and
  /// not the demo.
  bool get platformReady =>
      _platformReady ??
      (kCardPresentEnabled &&
          Env.isMobile &&
          !Env.demoMode &&
          _platform.isAvailable);

  final Map<String, _ConfigEntry> _configs = {};
  TerminalDeviceSupport? _device;
  Future<void>? _deviceLoading;

  /// Stripe's simulated reader, from the Debug Panel; honoured only on a
  /// test-mode gateway.
  bool get simulated => _simulated;
  bool _simulated = false;
  set simulated(bool value) {
    if (_simulated == value) return;
    _simulated = value;
    _reader = null;
    notifyListeners();
  }

  /// A Bluetooth reader has been connected in this app.
  bool get readerUsed => _readerUsed;
  bool _readerUsed = false;

  Future<void> noteReaderUsed() async {
    if (_readerUsed) return;
    _readerUsed = true;
    notifyListeners();
    await _prefs.write(DevicePrefKeys.cardReaderUsed, true);
  }

  void _syncPrefs() {
    final used = _prefs.read(DevicePrefKeys.cardReaderUsed) ?? false;
    if (used == _readerUsed) return;
    _readerUsed = used;
    notifyListeners();
  }

  /// The connected reader and the Stripe account it was connected under.
  TerminalReader? get reader => _reader;
  TerminalReader? _reader;
  String? _account;

  /// What this phone can do; null until asked.
  TerminalDeviceSupport? get device => _device;

  /// The company's answer, or null while unknown or unsupported.
  TerminalConfig? configFor(String companyId) => _configs[companyId]?.config;

  bool _canCreatePayment() =>
      _auth.session.value?.currentCompany?.can('create_payment') ?? false;

  /// Asks the server (and this phone) once, when nothing cheaper rules the
  /// feature out. Never throws and never reports: a server without the route
  /// answers 404, which just means "not here".
  void ensureConfig(String companyId) {
    if (!platformReady || !_canCreatePayment()) return;
    if (_configs.containsKey(companyId)) return;
    unawaited(_load(companyId));
  }

  /// Re-reads the company's answer — after an admin acknowledged the
  /// surcharge or created a Location.
  Future<TerminalConfig?> refreshConfig(String companyId) async {
    _configs.remove(companyId);
    await _load(companyId);
    return configFor(companyId);
  }

  Future<void> _load(String companyId) async {
    final entry = _configs[companyId] = _ConfigEntry();
    _deviceLoading ??= _platform
        .deviceSupport()
        .then((d) => _device = d)
        .catchError((Object _) => _device = TerminalDeviceSupport.none);
    try {
      final config = await _repo.config(companyId);
      await _deviceLoading;
      if (!identical(_configs[companyId], entry)) return;
      entry.config = config;
    } catch (e) {
      _log.fine('terminal/config unavailable for $companyId: ${e.runtimeType}');
    }
    if (identical(_configs[companyId], entry)) notifyListeners();
  }

  /// How a card can be read for [gateway] on this phone.
  TerminalReaderChoice readerChoiceFor(String accountCountry) {
    final device = _device;
    return terminalReaderChoice(
      tapToPayDevice: device?.tapToPay ?? false,
      accountCountry: accountCountry,
      bluetoothDevice: device?.bluetooth ?? false,
      readerUsed: _readerUsed || _reader?.kind == TerminalReaderKind.bluetooth,
    );
  }

  TerminalAvailability availabilityFor(String companyId, Invoice invoice) {
    final config = configFor(companyId);
    return terminalAvailability(
      platformReady: platformReady,
      canCreatePayment: _canCreatePayment(),
      invoice: invoice,
      configEnabled: config?.enabled ?? false,
      planOk: config?.planOk ?? false,
      accountCountry: config?.usableGateway?.accountCountry,
      readers: readerChoiceFor,
    );
  }

  /// Starts the SDK for one Stripe account and Location — a connection token
  /// belongs to exactly one — dropping any reader connected under another.
  Future<void> prepare({
    required String companyId,
    required TerminalGatewayConfig gateway,
    required TerminalLocation location,
  }) async {
    final account = '$companyId/${gateway.companyGatewayId}/${location.id}';
    if (_account != account) _reader = null;
    _account = account;
    await _platform.initialize(
      account: account,
      fetchToken: () => _repo.connectionToken(
        companyId,
        companyGatewayId: gateway.companyGatewayId,
        locationId: location.id,
      ),
    );
  }

  /// The reader already connected for this account, if it still is.
  Future<TerminalReader?> connectedReader() async {
    if (_reader == null) return null;
    try {
      final reader = await _platform.connectedReader();
      if (reader == null) _reader = null;
      return reader == null ? null : _reader;
    } catch (_) {
      return _reader = null;
    }
  }

  /// Finds this phone's Tap to Pay reader and connects it.
  Future<TerminalReader> connectTapToPay({
    required TerminalGatewayConfig gateway,
    required TerminalLocation location,
    required String merchantDisplayName,
    required bool isAdmin,
  }) async {
    final found = await _platform
        .discover(
          TerminalReaderKind.tapToPay,
          simulated: _simulated && !gateway.livemode,
        )
        .firstWhere((readers) => readers.isNotEmpty)
        .timeout(const Duration(seconds: 60));
    return _connect(found.first, location, merchantDisplayName, isAdmin);
  }

  /// Bluetooth readers in range, for the reader sheet.
  Stream<List<TerminalReader>> discoverBluetooth(
    TerminalGatewayConfig gateway,
  ) => _platform.discover(
    TerminalReaderKind.bluetooth,
    simulated: _simulated && !gateway.livemode,
  );

  Future<TerminalReader> connectBluetooth(
    TerminalReader reader, {
    required TerminalLocation location,
    required String merchantDisplayName,
  }) async {
    final connected = await _connect(
      reader,
      location,
      merchantDisplayName,
      false,
    );
    unawaited(noteReaderUsed());
    return connected;
  }

  Future<TerminalReader> _connect(
    TerminalReader reader,
    TerminalLocation location,
    String merchantDisplayName,
    bool isAdmin,
  ) async {
    final connected = await _platform.connect(
      reader,
      locationId: location.id,
      merchantDisplayName: merchantDisplayName,
      tosAcceptancePermitted: isAdmin,
    );
    _reader = connected;
    notifyListeners();
    return connected;
  }

  Future<void> disconnect() async {
    _reader = null;
    notifyListeners();
    try {
      await _platform.disconnect();
    } catch (_) {}
  }

  /// Wraps a confirm and the `complete` after it: nothing [reset]s the SDK
  /// while a card may be being charged.
  Future<T> guardCharge<T>(Future<T> Function() charge) {
    final future = charge();
    final settled = future.then<void>((_) {}, onError: (_) {});
    _charges.add(settled);
    settled.whenComplete(() => _charges.remove(settled));
    return future;
  }

  final Set<Future<void>> _charges = {};

  /// Forgets every company's answer and the reader, and resets the SDK — a
  /// session end or a company switch. Waits up to a minute for a charge in
  /// flight to be answered first.
  Future<void> reset() async {
    if (_charges.isNotEmpty) {
      try {
        await Future.wait(
          _charges.toList(),
        ).timeout(const Duration(seconds: 60));
      } catch (_) {
        _log.warning('reset while a card charge was still unanswered');
      }
    }
    _configs.clear();
    _reader = null;
    _account = null;
    notifyListeners();
    if (!platformReady) return;
    try {
      await _platform.reset();
    } catch (_) {}
  }

  @override
  void dispose() {
    _prefs.removeListener(_syncPrefs);
    super.dispose();
  }
}

class _ConfigEntry {
  TerminalConfig? config;
}
