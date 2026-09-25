import 'dart:io' show exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/app_reload.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/db/database_opener.dart';
import 'package:admin/data/db/db_open_exception.dart';

/// Minimal full-screen error shown when the local database could not be
/// opened: the store was left untouched ([kind] says why), or
/// `openAppDatabase`'s own destroy-and-reopen recovery failed too. `Services`
/// and localization aren't available this early, so the copy is plain
/// English.
///
/// This exists because the alternative is worse than an error screen: before
/// it, that failure escaped `_bootstrap` uncaught, `runApp` was never called,
/// and the user was left on the HTML boot loader (`web/index.html`) — a dead
/// end whose only escape was clearing site data. The overwhelmingly common
/// cause on web is a store still locked by a stale browser context, which
/// clears on its own within seconds, so "Try again" is a real fix and is
/// offered first.
class LocalDataUnavailableApp extends StatefulWidget {
  const LocalDataUnavailableApp({
    required this.detail,
    this.kind,
    this.isWeb = kIsWeb,
    this.isDesktop,
    this.resetStore = destroyDatabaseStore,
    this.reload = reloadApp,
    this.quit = _quitApp,
    super.key,
  });

  /// The underlying error, shown small — enough for a bug report without
  /// making the screen look like a crash dump.
  final String detail;

  /// Why the open failed, when `openAppDatabase` classified it and left the
  /// store untouched ([DatabaseUnavailableException]); null when recovery
  /// itself failed. Picks the explanation — "close your other tab" is the
  /// right advice for a lock and useless for a full disk.
  final DbOpenFailureKind? kind;

  /// Which platform's copy and buttons to show — a parameter so a test can
  /// render both.
  final bool isWeb;

  /// Moves the store aside (natively: quarantined for salvage on the next
  /// open). Injectable for tests.
  final Future<bool> Function() resetStore;

  /// Reloads the page — web only. Injectable for tests.
  final void Function() reload;

  /// Whether to offer Quit: a desktop window, which on Windows and Linux has
  /// no close button of its own here — the app draws those, and this screen
  /// is not the app. Null resolves from the platform; on a phone the app
  /// switcher closes the app, and app review rejects one that quits itself.
  final bool? isDesktop;

  /// Ends the process — nothing is open to save, the store never opened.
  /// Injectable for tests.
  final void Function() quit;

  @override
  State<LocalDataUnavailableApp> createState() =>
      _LocalDataUnavailableAppState();
}

class _LocalDataUnavailableAppState extends State<LocalDataUnavailableApp> {
  bool _busy = false;

  Future<void> _resetAndReload() async {
    setState(() => _busy = true);
    try {
      await widget.resetStore();
    } catch (e, st) {
      Logger('boot').warning('Resetting local data failed', e, st);
    }
    if (widget.isWeb) {
      widget.reload();
    } else if (mounted) {
      setState(() => _busy = false);
    }
  }

  static String _explanation(
    DbOpenFailureKind? kind, {
    required bool isWeb,
  }) => switch (kind) {
    DbOpenFailureKind.storageFull =>
      isWeb
          ? 'Your browser has run out of storage for Invoice Ninja\'s local '
                'data. Free up some space, then try again.'
          : 'Your device has run out of storage for Invoice Ninja\'s local '
                'data. Free up some space, then relaunch the app.',
    DbOpenFailureKind.inUse =>
      isWeb
          ? 'Invoice Ninja is already open in another tab. Close it, then '
                'try again.'
          : 'Invoice Ninja is already open in another window, and only one '
                'copy can use its local data at a time. Switch to that '
                'window, or quit it and open Invoice Ninja again.',
    DbOpenFailureKind.transient || DbOpenFailureKind.unknown =>
      isWeb
          ? 'Invoice Ninja is probably open in another tab, or a tab that '
                'just closed is still holding its local data. Close any other '
                'Invoice Ninja tabs, then try again.'
          : 'The local database is busy or temporarily unavailable. Quit '
                'Invoice Ninja and open it again to retry.',
    // Recovery itself failed, or a reset-worthy failure we could not repair.
    DbOpenFailureKind.corrupt ||
    DbOpenFailureKind.migrationFailed ||
    null => 'Invoice Ninja could not open its local database.',
  };

  @override
  Widget build(BuildContext context) {
    // No Reset while another copy of the app has the store open: it would
    // move the store out from under that copy, which keeps writing to it.
    // `destroyDatabaseStore` refuses anyway; the button would only fail.
    final canReset = widget.kind != DbOpenFailureKind.inUse;
    final canQuit =
        widget.isDesktop ??
        (!widget.isWeb &&
            const {
              TargetPlatform.macOS,
              TargetPlatform.windows,
              TargetPlatform.linux,
            }.contains(defaultTargetPlatform));
    // Nothing here is localized on purpose: this screen renders before
    // `Services` exists, so there is no `Localization` to read from.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        // Scrolls: a landscape phone, or a large text size, is shorter than
        // this column, and a boot screen that overflows hides its own Reset.
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storage_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Could not open local data',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _explanation(widget.kind, isWeb: widget.isWeb),
                        textAlign: TextAlign.center,
                      ),
                      if (canReset) ...[
                        const SizedBox(height: 12),
                        // Honest about what a reset costs. This used to
                        // promise that "everything is re-downloaded from the
                        // server", which is true of the cache and false of the
                        // outbox: changes made on this device that never
                        // reached the server exist nowhere else. Native keeps
                        // the old store and carries those tables into the new
                        // one on relaunch (`readQuarantinedStore`) when it can
                        // still be read; web has no salvage yet.
                        Text(
                          widget.isWeb
                              ? 'Resetting deletes this device\'s copy of '
                                    'your data. Everything already synced '
                                    'downloads again, but changes made on this '
                                    'device that haven\'t synced yet are lost.'
                              : 'Resetting starts this device\'s copy of your '
                                    'data over, and everything already synced '
                                    'downloads again. Changes that haven\'t '
                                    'synced yet are carried over if the old '
                                    'copy can still be read, and lost if it '
                                    'can\'t.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Paired side-by-side, never stacked (§ Design system) —
                      // as long as they fit. A `Wrap`, not a `Row`: on a phone
                      // browser at a large text size the pair is wider than the
                      // column, and a Row overflowed where this wraps.
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (widget.isWeb)
                            FilledButton(
                              onPressed: _busy ? null : widget.reload,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(64, 44),
                              ),
                              // i18n-exempt: renders before localization exists.
                              child: const Text('Try again'),
                            ),
                          if (canReset)
                            OutlinedButton(
                              onPressed: _busy ? null : _resetAndReload,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(64, 40),
                              ),
                              child: Text(
                                _busy ? 'Resetting…' : 'Reset local data',
                              ),
                            ),
                          if (canQuit)
                            OutlinedButton(
                              onPressed: _busy ? null : widget.quit,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(64, 40),
                              ),
                              // i18n-exempt: renders before localization exists.
                              child: const Text('Quit'),
                            ),
                        ],
                      ),
                      if (!widget.isWeb && canReset) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Then relaunch the app.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      SelectableText(
                        widget.detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: kMonoFontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _quitApp() => exit(0);
