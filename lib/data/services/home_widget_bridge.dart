import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'package:admin/domain/home_widgets/widget_command.dart';
import 'package:admin/domain/home_widgets/widget_snapshot.dart';

final _log = Logger('HomeWidgetBridge');

/// What the native side says is on the user's home screens.
class InstalledWidgets {
  const InstalledWidgets({
    this.kinds = const {},
    this.companyIds = const {},
    this.periods = const {},
  });

  static const InstalledWidgets none = InstalledWidgets();

  final Set<WidgetKind> kinds;

  /// Companies a widget is pinned to. A widget on "Current company" adds
  /// nothing here; it follows the active one.
  final Set<String> companyIds;
  final Set<WidgetPeriod> periods;

  bool get isEmpty => kinds.isEmpty;

  static InstalledWidgets fromChannel(Object? raw) {
    if (raw is! Map) return none;
    Set<String> strings(Object? v) => v is List
        ? {
            for (final s in v)
              if (s is String && s.isNotEmpty) s,
          }
        : const {};
    return InstalledWidgets(
      kinds: {
        for (final k in strings(raw['kinds']))
          if (WidgetKind.fromWire(k) case final kind?) kind,
      },
      companyIds: strings(raw['companyIds']),
      periods: {
        for (final p in strings(raw['periods']))
          if (WidgetPeriod.fromWire(p) case final period?) period,
      },
    );
  }
}

/// The app's half of the home-screen widgets: writes the snapshot they read,
/// asks which are installed, and takes the commands they queued. The native
/// halves live in `ios/HomeWidgets/` (iOS and macOS) and the Android
/// `homewidgets` package — see `docs/home-screen-widgets.md`.
///
/// Every call is a no-op where there are no widgets (web, Windows, Linux) and
/// survives a platform that has not registered the channel (a test, a build
/// without the native half): a widget must never take the app down.
class HomeWidgetBridge {
  HomeWidgetBridge({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel(kChannelName),
      supported = supported ?? _platformSupported();

  static const String kChannelName = 'invoice_ninja/home_widgets';

  final MethodChannel _channel;

  /// Whether this platform has home-screen widgets at all.
  final bool supported;

  final StreamController<void> _commandsQueued =
      StreamController<void>.broadcast();
  final StreamController<void> _widgetsChanged =
      StreamController<void>.broadcast();

  /// How long a native call may take. `signOut` is awaited inside the logout
  /// hooks, and a handler that never replied would hang the sign-out.
  static const Duration kCallTimeout = Duration(seconds: 5);

  bool _listening = false;

  /// Fires when a widget queued a command while the app was running (macOS,
  /// or an Android widget tapped with the app in the background).
  ///
  /// The native side is listened to from the first read, not from
  /// construction: `Services.build` runs before a test has a binding, and a
  /// channel handler set then asserts.
  Stream<void> get commandsQueued {
    _listen();
    return _commandsQueued.stream;
  }

  /// Fires when a widget was placed or reconfigured — it may show a company
  /// or a period nothing has fetched yet.
  Stream<void> get widgetsChanged {
    _listen();
    return _widgetsChanged.stream;
  }

  void _listen() {
    if (supported && !_listening) {
      _listening = true;
      _channel.setMethodCallHandler(_onNativeCall);
    }
  }

  static bool _platformSupported() {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS ||
      TargetPlatform.android ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  Future<Object?> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'commandsQueued':
        _commandsQueued.add(null);
      case 'widgetsChanged':
        _widgetsChanged.add(null);
    }
    return null;
  }

  /// Replaces the snapshot file and reloads the widgets of [reload] kinds —
  /// all of them when null. The file is written atomically by the native side.
  /// Returns whether it was written — a caller must not treat a failed write
  /// as delivered, or an identical snapshot is never sent again.
  Future<bool> write(
    Map<String, Object?> snapshot, {
    Set<WidgetKind>? reload,
  }) async => (await _call<void>('write', {
    'json': jsonEncode(snapshot),
    if (reload != null) 'reload': [for (final k in reload) k.wire],
  })).ok;

  /// The placed widgets, or null when the native side didn't answer — which
  /// is "unknown", never "none": read as none it would write a snapshot with
  /// no figures and no timers, and blank every widget on the screen.
  Future<InstalledWidgets?> installed() async {
    final (:ok, :value) = await _call<Object?>('installed');
    return ok ? InstalledWidgets.fromChannel(value) : null;
  }

  /// The commands waiting, oldest first. Unparseable ones are skipped (and
  /// left for [deleteAllCommands]).
  Future<List<({String fileId, WidgetCommand? command})>> takeCommands() async {
    final raw = await _invoke<Object?>('takeCommands');
    if (raw is! List) return const [];
    final out = <({String fileId, WidgetCommand? command})>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final fileId = item['fileId'];
      if (fileId is! String || fileId.isEmpty) continue;
      Object? decoded;
      try {
        final json = item['json'];
        decoded = json is String ? jsonDecode(json) : null;
      } on FormatException {
        decoded = null;
      }
      out.add((fileId: fileId, command: WidgetCommand.tryParse(decoded)));
    }
    return out;
  }

  /// Asks the launcher to place a [kind] widget (Android 8+, where the
  /// launcher supports it). False when it can't — the user then adds it from
  /// the home screen; iOS never can.
  Future<bool> pin(WidgetKind kind) async =>
      (await _invoke<bool>('pin', {'kind': kind.wire})) ?? false;

  Future<void> deleteCommand(String fileId) =>
      _invoke<void>('deleteCommand', {'fileId': fileId});

  Future<void> deleteAllCommands() => _invoke<void>('deleteAllCommands');

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async =>
      (await _call<T>(method, args)).value;

  /// [method]'s answer, and whether there was one: a timeout, a platform
  /// error or a missing native half is `ok: false`.
  Future<({bool ok, T? value})> _call<T>(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    if (!supported) return (ok: false, value: null);
    try {
      final value = await _channel
          .invokeMethod<T>(method, args)
          .timeout(kCallTimeout);
      return (ok: true, value: value);
    } on MissingPluginException {
      return (ok: false, value: null);
    } on TimeoutException {
      _log.warning('Home widget call $method timed out');
      return (ok: false, value: null);
    } on PlatformException catch (e, st) {
      _log.warning('Home widget call $method failed', e, st);
      return (ok: false, value: null);
    }
  }

  void dispose() {
    if (_listening) _channel.setMethodCallHandler(null);
    unawaited(_commandsQueued.close());
    unawaited(_widgetsChanged.close());
  }
}
