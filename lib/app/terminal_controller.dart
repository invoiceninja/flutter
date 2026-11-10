import 'dart:async';
import 'dart:convert';

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
import 'package:admin/data/services/api_exception.dart';
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
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _repo = repository,
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
  final DateTime Function() _clock;

  /// How long an answer stands: an admin who turns Card present on sees it
  /// within minutes, and a failed fetch is tried again.
  static const configLifetime = Duration(minutes: 5);
  static const failedConfigRetry = Duration(minutes: 1);

  TerminalPlatform get platform => _platform;
  TerminalRepository get repository => _repo;

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
    // A reader connected the other way must not serve the next collection.
    unawaited(disconnect());
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

  // ------------------------------------------------- payments being checked

  Map<String, dynamic> _pending() {
    final raw = _prefs.read(DevicePrefKeys.pendingCardPayments);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _savePending(Map<String, dynamic> pending) => _prefs.write(
    DevicePrefKeys.pendingCardPayments,
    pending.isEmpty ? null : jsonEncode(pending),
  );

  /// A charge is about to start: until the server answers, the payment is
  /// remembered on the device, so a crash or a closed app can't lose it.
  Future<void> notePending({
    required String companyId,
    required String invoiceId,
    required String paymentIntentId,
  }) => _savePending({
    ..._pending(),
    paymentIntentId: {'company': companyId, 'invoice': invoiceId},
  });

  /// The server gave a final answer for it.
  Future<void> clearPending(String paymentIntentId) async {
    final pending = _pending();
    if (pending.remove(paymentIntentId) != null) await _savePending(pending);
  }

  /// The payment on [invoiceId] still waiting for the server's answer.
  String? pendingFor(String companyId, String invoiceId) {
    for (final e in _pending().entries) {
      final v = e.value;
      if (v is Map && v['company'] == companyId && v['invoice'] == invoiceId) {
        return e.key;
      }
    }
    return null;
  }

  /// Asks the server about [invoiceId]'s pending payment. True when there is
  /// none left (answered, or there never was one).
  Future<bool> recoverPending(String companyId, String invoiceId) async {
    final pi = pendingFor(companyId, invoiceId);
    if (pi == null) return true;
    try {
      final result = await _repo.complete(companyId, pi, invoiceId: invoiceId);
      if (isFinalCompletion(result.status)) {
        await clearPending(pi);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// A `complete` answer after which nothing more will happen to the charge.
  static bool isFinalCompletion(String status) => const {
    'recorded',
    'unapplied',
    'canceled',
    'failed',
    'rejected',
    'orphaned',
  }.contains(status);

  /// Why the feature is, or isn't, here for [companyId] — Device Settings
  /// says so in words.
  TerminalConfigState configState(String companyId) {
    if (!platformReady) return TerminalConfigState.unavailable;
    if (!_canCreatePayment()) return TerminalConfigState.noPermission;
    final entry = _configs[companyId];
    if (entry == null || (entry.loading && entry.config == null)) {
      return TerminalConfigState.loading;
    }
    if (entry.unsupported) return TerminalConfigState.serverTooOld;
    final config = entry.config;
    if (config == null) return TerminalConfigState.unreachable;
    if (!config.enabled) return TerminalConfigState.switchedOff;
    if (config.gateways.isEmpty) return TerminalConfigState.notEnabled;
    if (config.usableGateway == null) {
      return TerminalConfigState.accountInactive;
    }
    if (!config.planOk) return TerminalConfigState.planRequired;
    return TerminalConfigState.ready;
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

  /// Asks the server (and this phone) when nothing cheaper rules the
  /// feature out. Never throws and never reports. A server without the route
  /// answers 404 — "not here", remembered for the session; any other failure
  /// is tried again after [failedConfigRetry], and an answer is refreshed
  /// after [configLifetime].
  void ensureConfig(String companyId) {
    if (!platformReady || !_canCreatePayment()) return;
    final entry = _configs[companyId];
    if (entry != null) {
      if (entry.loading || entry.unsupported) return;
      final age = _clock().difference(entry.fetchedAt);
      if (age < (entry.failed ? failedConfigRetry : configLifetime)) return;
    }
    unawaited(_load(companyId, keep: entry?.config));
  }

  /// Re-reads the company's answer — after an admin acknowledged the
  /// surcharge or created a Location.
  Future<TerminalConfig?> refreshConfig(String companyId) async {
    // The last answer stands while this one loads, and if it fails.
    await _load(companyId, keep: _configs[companyId]?.config);
    return configFor(companyId);
  }

  Future<void> _load(String companyId, {TerminalConfig? keep}) async {
    final entry = _configs[companyId] = _ConfigEntry(_clock())..config = keep;
    _deviceLoading ??= _platform
        .deviceSupport()
        .then((d) => _device = d)
        .catchError((Object _) => _device = TerminalDeviceSupport.none);
    try {
      final config = await _repo.config(companyId);
      await _deviceLoading;
      if (!identical(_configs[companyId], entry)) return;
      entry
        ..config = config
        ..failed = false;
    } catch (e) {
      entry.failed = true;
      _log.fine('terminal/config unavailable for $companyId: ${e.runtimeType}');
      // An older server: forget any answer. Anything else keeps the last one.
      entry.unsupported = e is ServerException && e.statusCode == 404;
      if (entry.unsupported) entry.config = null;
    }
    entry
      ..loading = false
      ..fetchedAt = _clock();
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
    _prepared++;
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

  /// Bumped by every [prepare]: a [reset] that waited leaves a newer
  /// session alone.
  int _prepared = 0;

  /// Forgets every company's answer and the reader, and resets the SDK — a
  /// session end or a company switch. Waits up to a minute for a charge in
  /// flight to be answered first.
  Future<void> reset() async {
    // The session's own state goes now, so nothing new starts on it.
    _configs.clear();
    _reader = null;
    _account = null;
    final prepared = _prepared;
    notifyListeners();
    // Until no charge is left: one that ends may have started another (a
    // read again after finalize). Real time, whatever the clock says.
    // Longer than the facade's bound on a confirm (2 minutes), so a confirm
    // is always answered before the reader goes.
    const limit = Duration(seconds: 150);
    final waited = Stopwatch()..start();
    while (_charges.isNotEmpty) {
      final left = limit - waited.elapsed;
      if (left <= Duration.zero) {
        _log.warning('reset while a card charge was still unanswered');
        break;
      }
      try {
        await Future.any(_charges.toList()).timeout(left);
      } catch (_) {}
    }
    // A newer session prepared while this waited has already reset the SDK
    // for its own account: leave it alone.
    if (!platformReady || _prepared != prepared) return;
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

/// Why "Collect card payment" is, or isn't, offered for a company.
enum TerminalConfigState {
  unavailable,
  noPermission,
  loading,
  serverTooOld,
  unreachable,
  switchedOff,
  notEnabled,
  accountInactive,
  planRequired,
  ready,
}

class _ConfigEntry {
  _ConfigEntry(this.fetchedAt);

  DateTime fetchedAt;
  TerminalConfig? config;
  bool loading = true;

  /// The server has no such route: an older one. Not asked again.
  bool unsupported = false;

  /// The last fetch failed (any answer kept is older): asked again sooner.
  bool failed = false;
}
