import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:admin/app/logging.dart' show redact;
import 'package:admin/data/db/app_database.dart';

/// Debug-only on-disk capture of runtime errors + stale outbox snapshots.
///
/// Owned by [Services.diagnosticsLog] and only constructed when
/// `kReleaseMode` is false (release builds keep the field `null`). The wiring
/// in `main.dart` then routes:
///
/// - `FlutterError.onError`,
/// - `PlatformDispatcher.instance.onError`,
/// - the `runZonedGuarded` uncaught handler,
/// - and all `Logger` records at WARNING or above
///
/// to [recordError] / [recordLog]. The user can additionally dump the active
/// company's stale outbox rows via the System Logs screen, which calls
/// [appendOutboxSnapshot].
///
/// The file lives next to the encrypted Drift DB (see
/// `path_provider.getApplicationSupportDirectory()` in
/// `lib/data/db/app_database.dart`). Its absolute path is exposed via [path]
/// so Claude can be pointed at it for inspection.

/// Known, debug-only, functionally-harmless Flutter framework noise. Case (1):
/// `RawAutocomplete._onFocusChange` unconditionally calls
/// `OverlayPortalController.hide()` on focus loss, which asserts
/// `_zOrderIndex != null` when the options overlay was never shown / its
/// `OverlayPortal` is momentarily detached during a rebuild. Stripped from
/// release builds (asserts compiled out; `hide()` is a no-op there). Every
/// product/tax cell in the inline line-item table is a `RawAutocomplete`, so
/// the heavily-rebuilt table trips this on ordinary focus changes and floods
/// the diagnostics log, defeating its purpose. Matched narrowly — both the
/// assertion text AND the `RawAutocomplete` frame — so any other
/// `OverlayPortal` / `_zOrderIndex` misuse is still reported. See bundled
/// Flutter SDK overlay.dart:1681 / autocomplete.dart:440.
bool isKnownBenignFrameworkNoise(Object error, StackTrace? stack) {
  final errStr = error.toString();
  // `StackTrace.toString()` can itself throw (package:stack_trace lazy-parse
  // LateInitializationError). A trace we can't stringify can't match any
  // signature below — treat as non-benign so the error is still logged.
  String stackStr;
  try {
    stackStr = stack?.toString() ?? '';
  } catch (_) {
    stackStr = '';
  }
  // (1) RawAutocomplete focus-loss `_zOrderIndex != null` assertion (above).
  if (errStr.contains('_zOrderIndex != null') &&
      stackStr.contains('_RawAutocompleteState._updateOptionsViewVisibility')) {
    return true;
  }
  // (2) `_RawAutocompleteState._announceSemantics` fires after an async gap
  // and touches `State.context` once the field has unmounted (the options
  // list rebuilt a picker out from under itself). Framework lifecycle bug in
  // autocomplete.dart with nothing the app can cancel. Matched on both the
  // unmount message AND the framework frame, so genuine app-side
  // "unmounted context" errors are still reported.
  if (errStr.contains('has been unmounted') &&
      stackStr.contains('_RawAutocompleteState._announceSemantics')) {
    return true;
  }
  // (3) `printing`'s `PdfPreviewRaster._raster` throws a transient
  // `RangeError (index): … Valid value range is empty: 0` when a rebuild /
  // hot-restart re-enters rastering and clears the page list mid-iteration.
  // printing reports it unconditionally via
  // `FlutterError.reportError(library: 'printing')` (raster.dart catch block);
  // the preview self-heals on the next pass, and `isRenderablePdf`
  // (`lib/utils/pdf_bytes_guard.dart`) already blocks the real empty /
  // truncated-bytes cases before they reach the rasterizer. Matched on both
  // the error text AND the rasterizer frame, so any other range error still
  // surfaces.
  if (errStr.contains('Valid value range is empty') &&
      stackStr.contains('PdfPreviewRaster._raster')) {
    return true;
  }
  return false;
}

class DiagnosticsLog {
  DiagnosticsLog._({
    required this.path,
    required IOSink sink,
    required int initialBytes,
    required this.rotateThresholdBytes,
  }) : _sink = sink,
       _bytesWritten = initialBytes;

  /// Build the log + open the sink. Pass `directoryOverride` from tests to
  /// route writes into a tempdir; production callers leave it null and the
  /// service resolves [getApplicationSupportDirectory] itself.
  ///
  /// Rotates the existing file to `<name>.1` (overwriting any prior backup)
  /// when it would otherwise exceed [rotateThresholdBytes] on the next write.
  static Future<DiagnosticsLog> open({
    Directory? directoryOverride,
    String fileName = 'claude-diagnostics.log',
    int rotateThresholdBytes = 512 * 1024,
    String? sessionBanner,
  }) async {
    final dir = directoryOverride ?? await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final filePath = p.join(dir.path, fileName);
    final file = File(filePath);
    final backupPath = '$filePath.1';

    if (await file.exists()) {
      final size = await file.length();
      if (size >= rotateThresholdBytes) {
        try {
          final backup = File(backupPath);
          if (await backup.exists()) await backup.delete();
          await file.rename(backupPath);
        } catch (_) {
          // Best-effort: if rotation fails we still want to keep capturing.
        }
      }
    }
    final sink = file.openWrite(mode: FileMode.append);
    final size = await file.exists() ? await file.length() : 0;
    final log = DiagnosticsLog._(
      path: filePath,
      sink: sink,
      initialBytes: size,
      rotateThresholdBytes: rotateThresholdBytes,
    );
    log._write(
      '=== SESSION ${_iso(DateTime.now())} ${sessionBanner ?? ''} ===',
    );
    return log;
  }

  /// Absolute path of the live log file.
  final String path;

  /// Rotate threshold; exposed so tests can force rotation cheaply.
  final int rotateThresholdBytes;

  IOSink _sink;
  int _bytesWritten;
  bool _rotating = false;
  final Queue<String> _ring = Queue<String>();
  static const int _ringCapacity = 500;

  // Consecutive identical errors (an assert storm) collapse into one entry
  // plus a repeat count, so a thousands-deep loop can't blow past the rotation
  // threshold and carry the root error — and its causing-widget hints — out of
  // the file. Reset on any non-matching write (see [_flushRepeat]).
  String? _lastErrorSig;
  int _repeatCount = 0;

  void _flushRepeat() {
    if (_repeatCount > 0) {
      _write('  … (previous error repeated $_repeatCount more time(s))');
      _repeatCount = 0;
    }
    _lastErrorSig = null;
  }

  /// Append a stack trace, one indented line per frame. `StackTrace.toString()`
  /// can itself throw — a `package:stack_trace` `Chain` lazy-parse raises
  /// `LateInitializationError` on a malformed trace — so it is guarded here: a
  /// logger that throws while logging would drop the very record (and its
  /// error) it was capturing. On failure we still emit a placeholder so the
  /// head line is never orphaned.
  void _writeStack(StackTrace stack) {
    String text;
    try {
      text = stack.toString();
    } catch (e) {
      _write('  <stack trace unavailable: ${e.runtimeType}>');
      return;
    }
    for (final line in text.split('\n')) {
      if (line.isEmpty) continue;
      _write('  $line');
    }
  }

  /// Append an uncaught error. Safe to call from any zone. Returns whether a
  /// fresh entry was written (false when collapsed into the repeat counter).
  bool recordError(Object error, StackTrace? stack, {String? context}) {
    if (isKnownBenignFrameworkNoise(error, stack)) return false;
    final body = redact(error.toString());
    // Signature excludes the timestamp so a repeating assertion matches.
    final sig = '${context ?? ''}\u0000$body';
    if (sig == _lastErrorSig) {
      _repeatCount++;
      return false;
    }
    _flushRepeat();
    _lastErrorSig = sig;
    final head = StringBuffer('ERROR')
      ..write(' ')
      ..write(_iso(DateTime.now()));
    if (context != null && context.isNotEmpty) {
      head
        ..write(' [')
        ..write(context)
        ..write(']');
    }
    head
      ..write(' ')
      ..write(body);
    _write(head.toString());
    if (stack != null) _writeStack(stack);
    return true;
  }

  /// Append an uncaught Flutter framework error **with** its
  /// `informationCollector` hints — above all the "relevant error-causing
  /// widget" line (the `DiagnosticsDebugCreator`, carrying the widget type +
  /// its creation `file:line`), which `details.exception.toString()` alone
  /// omits. Without this the on-disk log is framework-only and can't name the
  /// culprit widget.
  void recordFlutterError(FlutterErrorDetails details) {
    final wrote = recordError(
      details.exception,
      details.stack,
      context: details.context?.toString(),
    );
    // Collapsed into the repeat counter → the head/info were already written
    // for the first occurrence; don't re-append the info block per repeat.
    if (!wrote) return;
    final collector = details.informationCollector;
    if (collector == null) return;
    for (final node in collector()) {
      final text = node.toStringDeep().trimRight();
      if (text.isEmpty) continue;
      for (final line in text.split('\n')) {
        if (line.trim().isEmpty) continue;
        _write('  ${redact(line)}');
      }
    }
  }

  /// Append a `Logger` record. Mirrors the format used by [recordError].
  void recordLog(LogRecord r) {
    // A log line breaks an error run — emit any pending repeat tally first.
    _flushRepeat();
    final head = StringBuffer(r.level.name.padRight(7))
      ..write(' ')
      ..write(_iso(r.time))
      ..write(' [')
      ..write(r.loggerName)
      ..write('] ')
      ..write(redact(r.message));
    if (r.error != null) {
      head
        ..write(' :: ')
        ..write(redact(r.error.toString()));
    }
    _write(head.toString());
    final st = r.stackTrace;
    if (st != null) _writeStack(st);
  }

  /// Append a snapshot of stale outbox rows for [companyId] — dead rows,
  /// in-flight rows, and pending rows parked more than 24 h in the future.
  /// Returns the count written so the caller can show a confirmation.
  Future<int> appendOutboxSnapshot({
    required AppDatabase db,
    required String companyId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.outboxDao.staleRowsForCompany(
      companyId: companyId,
      now: now,
    );
    _write(
      '=== OUTBOX SNAPSHOT ${_iso(DateTime.now())} '
      'company=$companyId n=${rows.length} ===',
    );
    for (final row in rows) {
      final next = DateTime.fromMillisecondsSinceEpoch(row.nextAttemptAt);
      final deltaDays =
          ((row.nextAttemptAt - now) / Duration.millisecondsPerDay).round();
      final relative = row.state == 'pending' ? ' (in ${deltaDays}d)' : '';
      _write(
        'row id=${row.id} state=${row.state} '
        'entity=${row.entityType}/${row.entityId} '
        'kind=${row.mutationKind} attempts=${row.attempts} '
        'status=${row.lastStatusCode ?? '-'} '
        'requires_password=${row.requiresPassword} '
        'next_attempt_at=${_iso(next)}$relative '
        'payload_size=${utf8.encode(row.payload).length}',
      );
      if (row.lastError != null && row.lastError!.isNotEmpty) {
        _write('  last_error: ${redact(row.lastError!)}');
      }
      final fe = row.fieldErrorsJson;
      if (fe != null && fe.isNotEmpty) {
        _write('  field_errors: $fe');
      }
    }
    _write('=== END SNAPSHOT n=${rows.length} ===');
    await flush();
    return rows.length;
  }

  /// Recent lines retained in memory (newest last). Useful for tests and for
  /// future "show me the last 50 lines" UI without reopening the file.
  List<String> recent() => List.unmodifiable(_ring);

  Future<void> flush() async {
    _flushRepeat();
    try {
      await _sink.flush();
    } catch (_) {
      // Sink errors must never crash the app.
    }
  }

  /// Closes the underlying sink. Tests call this in tearDown to release the
  /// file handle on Windows / strict filesystems; production keeps it open
  /// for the app's lifetime.
  Future<void> close() async {
    _flushRepeat();
    try {
      await _sink.flush();
      await _sink.close();
    } catch (_) {}
  }

  void _write(String line) {
    _ring.addLast(line);
    while (_ring.length > _ringCapacity) {
      _ring.removeFirst();
    }
    try {
      _sink.writeln(line);
      _bytesWritten += line.length + 1;
      if (_bytesWritten >= rotateThresholdBytes && !_rotating) {
        _rotating = true;
        unawaited(_rotate().whenComplete(() => _rotating = false));
      }
    } catch (_) {
      // Swallow — the ring buffer still holds the line for in-app inspection.
    }
  }

  Future<void> _rotate() async {
    final current = _sink;
    final filePath = path;
    final backupPath = '$filePath.1';
    try {
      await current.flush();
      await current.close();
      final file = File(filePath);
      if (await file.exists()) {
        final backup = File(backupPath);
        if (await backup.exists()) await backup.delete();
        await file.rename(backupPath);
      }
      _sink = File(filePath).openWrite(mode: FileMode.append);
      _bytesWritten = 0;
      _sink.writeln('=== ROTATED ${_iso(DateTime.now())} ===');
    } catch (_) {
      // If rotation fails, reopen append on whatever's there so we don't
      // permanently lose the sink.
      try {
        _sink = File(filePath).openWrite(mode: FileMode.append);
      } catch (_) {}
    }
  }

  static String _iso(DateTime t) => t.toUtc().toIso8601String();
}
