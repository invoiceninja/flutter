import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/shared_file_intake.dart';

/// Bridges files shared into the app from other apps (invoiceninja/flutter#173)
/// into [SharedFileIntake]. Android and iOS only.
///
/// The native side has already copied every file into the app's own
/// `shared_intake/` folder — Android's `ShareReceiverActivity` before
/// MainActivity ever starts, iOS's Runner out of the App Group container the
/// Share Extension wrote to — and queues them. This class only *pulls* that
/// queue (`takeShares`), so it never matters whether Dart was listening when
/// a share arrived:
///
/// * once at construction — the share that cold-started the app;
/// * when the native side pings `sharesAvailable` — a share into a running
///   app (Android's `onNewIntent`);
/// * on every resume — the iOS fallback when the extension could not open
///   the app, and harmless everywhere else (an empty queue is a no-op);
/// * when `AppDeepLinks` sees the Share Extension's `invoiceninja://share`.
class AppShareIntake with WidgetsBindingObserver {
  AppShareIntake(
    this._intake, {
    MethodChannel channel = kChannel,
    bool? enabled,
  }) : _channel = channel,
       _enabled = enabled ?? _platformHasShareTarget {
    if (!_enabled) return;
    _channel.setMethodCallHandler(_onCall);
    WidgetsBinding.instance.addObserver(this);
    unawaited(pull());
  }

  /// Hard-coded on the native side too: `MainActivity.kt`, `AppDelegate.swift`.
  static const kChannel = MethodChannel('invoice_ninja/share_intake');

  static bool get _platformHasShareTarget =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final SharedFileIntake _intake;
  final MethodChannel _channel;
  final bool _enabled;
  final _log = Logger('AppShareIntake');

  /// Serialises pulls: a resume and a ping landing together must not both
  /// read the queue while the native side is still draining it.
  Future<void> _pulling = Future.value();

  /// Take whatever the native side has queued and hand it on. Never throws.
  Future<void> pull() {
    if (!_enabled) return Future.value();
    return _pulling = _pulling.then((_) => _pullOnce());
  }

  Future<void> _pullOnce() async {
    final List<Object?>? raw;
    try {
      raw = await _channel.invokeListMethod<Object?>('takeShares');
    } on MissingPluginException {
      return; // A host without the native half (tests, an older build).
    } catch (e, st) {
      _log.warning('takeShares failed', e, st);
      return;
    }
    final files = [
      for (final entry in raw ?? const <Object?>[])
        ?SharedFile.fromChannel(entry),
    ];
    if (files.isEmpty) return;
    // Not awaited: [SharedFileIntake.receive] can sit on an unsaved-changes
    // prompt for as long as the user likes, and the next pull must not wait.
    unawaited(_intake.receive(files));
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method == 'sharesAvailable') await pull();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(pull());
  }

  void dispose() {
    if (!_enabled) return;
    _channel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
  }
}
