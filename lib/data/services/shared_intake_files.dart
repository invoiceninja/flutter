import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:admin/data/services/upload_source.dart';

/// The app-owned copies of files shared into the app from other apps
/// (invoiceninja/flutter#173), and the only code that deletes them.
///
/// A shared file arrives as a grant that dies with the activity / extension
/// that received it, so the native side copies it at once into
/// `<application support>/shared_intake/<uuid>/<name>` — Android's
/// `ShareReceiverActivity` into `filesDir`, iOS's Runner out of the App Group
/// container into `Library/Application Support`, both of which are what
/// [getApplicationSupportDirectory] returns. The copy is what an outbox upload
/// row's `local_path` points at, so it has to outlive the form it was attached
/// to until that row is sent.
///
/// Three invariants, each kept here rather than at every caller:
/// - **Never outside the folder.** Every deletion is confined to [root]: a
///   file the user picked from their own storage is never touched.
/// - **Never one an outbox row names.** [delete] skips any copy a row still
///   points at ([referencedPaths]) — the row may yet be sent, or re-sent from
///   the Outbox. Only [deleteUploaded], for the row being sent right now, and
///   [purgeAll], once the rows themselves are gone, skip that check.
/// - **Matched by the path inside the folder.** A row's `local_path` is
///   absolute, and an absolute prefix can change under it (an iOS data
///   container moves on an app update; `/var` vs `/private/var`), so copies
///   are recognised by their `<uuid>/<name>` — the part this class wrote.
///
/// Native-only; every method is a no-op on web, which has no share target.
class SharedIntakeFiles {
  SharedIntakeFiles({
    Future<Directory> Function()? supportDirectory,
    Future<Set<String>> Function()? referencedPaths,
    DateTime Function()? now,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _referencedPaths = referencedPaths,
       _now = now ?? DateTime.now;

  /// The folder under application support. The native sides hard-code the
  /// same name (`ShareReceiverActivity.kt`, `MainActivity.kt`,
  /// `AppDelegate.swift`).
  static const kFolderName = 'shared_intake';

  /// How long an unreferenced share is kept. A create form is never restored
  /// across launches (`NavStatePersister` skips `/x/new`), so a copy no outbox
  /// row names after this long belongs to a draft that no longer exists.
  static const kSweepAge = Duration(hours: 24);

  final Future<Directory> Function() _supportDirectory;

  /// The `local_path` of every upload still in the outbox
  /// (`OutboxDao.referencedLocalPaths`). Null in tests of the file logic
  /// alone: nothing is then held back by a row.
  final Future<Set<String>> Function()? _referencedPaths;
  final DateTime Function() _now;
  final _log = Logger('SharedIntakeFiles');

  Future<Directory?>? _root;

  /// `<application support>/shared_intake`, or null on web or when the
  /// platform can't say.
  Future<Directory?> root() => _root ??= _resolveRoot();

  Future<Directory?> _resolveRoot() async {
    if (kIsWeb) return null;
    try {
      final support = await _supportDirectory();
      return Directory(p.join(support.path, kFolderName));
    } on MissingPluginException {
      // No path_provider host — a widget test. Nothing was ever shared here.
      _log.fine('No path_provider plugin; shared files disabled');
      return null;
    } catch (e) {
      _log.warning('No application support directory', e);
      return null;
    }
  }

  /// The on-disk path behind [source], or null for an in-memory one.
  static String? localPathOf(UploadSource source) {
    if (source is BytesUploadSource) return null;
    final path = source.toPayload()['local_path'];
    return path is String && path.isNotEmpty ? path : null;
  }

  /// `<uuid>/<name>` for a path inside a `shared_intake` folder — whatever the
  /// absolute prefix in front of it — or null for any other path.
  @visibleForTesting
  static String? intakeKey(String path) {
    final parts = p.split(p.normalize(path));
    final at = parts.lastIndexOf(kFolderName);
    if (at < 0 || at == parts.length - 1) return null;
    return parts.sublist(at + 1).join('/');
  }

  /// Whether [path] is one of this folder's copies — what a share handed over
  /// by the native side must be. Anything else (a forged hand-off naming the
  /// app's own private files) is refused before it can be attached.
  Future<bool> owns(String path) async {
    final dir = await root();
    return dir != null && p.isWithin(dir.path, p.normalize(path));
  }

  /// [source] as the upload of a queued row should read it: unchanged, unless
  /// it names one of this folder's copies at a path that no longer exists and
  /// the copy is still there under today's [root]. An iOS app update moves
  /// the data container — and with it this folder — so the absolute
  /// `local_path` an offline or failed upload row was queued with stops
  /// resolving while the file itself survives (`docs/sharing-files-into-the-app.md`).
  Future<UploadSource> resolve(UploadSource source) async {
    final path = localPathOf(source);
    final key = path == null ? null : intakeKey(path);
    if (path == null || key == null) return source;
    try {
      if (await source.exists()) return source;
      final dir = await root();
      if (dir == null) return source;
      final moved = p.joinAll([dir.path, ...key.split('/')]);
      if (moved == p.normalize(path) || !await File(moved).exists()) {
        return source;
      }
      return fileUploadSource(moved);
    } catch (e) {
      _log.warning('Could not resolve shared file $path', e);
      return source;
    }
  }

  /// Delete [paths] that lie inside [root] and that no outbox row names, and
  /// any `<uuid>` folder that leaves empty. Best-effort: a failure is logged,
  /// never thrown.
  Future<void> delete(Iterable<String> paths) async {
    final wanted = paths.toList();
    if (wanted.isEmpty) return;
    final dir = await root();
    if (dir == null) return;
    final referenced = await _referencedKeys();
    if (referenced == null) return; // Can't tell what's still needed.
    for (final path in wanted) {
      final key = intakeKey(path);
      if (key != null && referenced.contains(key)) continue;
      await _deleteOne(dir, path);
    }
  }

  /// Delete the copy behind an upload that has just been sent. Skips the
  /// outbox check on purpose: the row naming it is the one being completed.
  /// Without this a receipt — personal data — lingered in the sandbox until
  /// the next launch's [sweep], and a day after that.
  Future<void> deleteUploaded(String path) async {
    final dir = await root();
    if (dir == null) return;
    await _deleteOne(dir, path);
  }

  Future<void> _deleteOne(Directory dir, String path) async {
    final normalized = p.normalize(path);
    if (!p.isWithin(dir.path, normalized)) return;
    try {
      final file = File(normalized);
      if (await file.exists()) await file.delete();
      await _pruneEmptyParents(file.parent, dir);
    } catch (e) {
      _log.warning('Could not delete shared file $normalized', e);
    }
  }

  /// Delete every share no outbox upload references ([referenced] is
  /// `OutboxDao.referencedLocalPaths`) and that is older than [kSweepAge].
  /// Run once after boot.
  Future<void> sweep(Set<String> referenced) async {
    final dir = await root();
    if (dir == null || !await dir.exists()) return;
    final keep = {for (final path in referenced) ?intakeKey(path)};
    final cutoff = _now().subtract(kSweepAge);
    try {
      await for (final entry in dir.list(followLinks: false)) {
        if (_holdsAny(dir, entry, keep)) continue;
        final modified = (await entry.stat()).modified;
        if (modified.isAfter(cutoff)) continue;
        await entry.delete(recursive: true);
      }
    } catch (e) {
      _log.warning('Sweeping shared files failed', e);
    }
  }

  /// Delete every share except [except] — on a wipe of the local data
  /// (`LocalDataDisposer.wipeAll`), after the rows: a shared receipt is the
  /// account's data. [except] spares a share still waiting for the sign-in
  /// that triggered the wipe (`SharedFileIntake.heldPaths`).
  Future<void> purgeAll({Set<String> except = const {}}) async {
    final dir = await root();
    if (dir == null || !await dir.exists()) return;
    final keep = {for (final path in except) ?intakeKey(path)};
    try {
      if (keep.isEmpty) {
        await dir.delete(recursive: true);
        return;
      }
      await for (final entry in dir.list(followLinks: false)) {
        if (_holdsAny(dir, entry, keep)) continue;
        await entry.delete(recursive: true);
      }
    } catch (e) {
      _log.warning('Purging shared files failed', e);
    }
  }

  /// The `<uuid>/<name>` of every copy an outbox row names, or null when the
  /// outbox can't be read — then nothing may be deleted.
  Future<Set<String>?> _referencedKeys() async {
    final provider = _referencedPaths;
    if (provider == null) return const {};
    try {
      return {for (final path in await provider()) ?intakeKey(path)};
    } catch (e) {
      _log.warning('Could not read referenced shared files', e);
      return null;
    }
  }

  /// Whether [entry] (a child of [dir]) is, or is a folder containing, one of
  /// [keys].
  bool _holdsAny(Directory dir, FileSystemEntity entry, Set<String> keys) {
    if (keys.isEmpty) return false;
    final own = p.relative(p.normalize(entry.path), from: dir.path);
    return keys.any((key) => key == own || key.startsWith('$own/'));
  }

  Future<void> _pruneEmptyParents(Directory folder, Directory root) async {
    var current = folder;
    while (p.isWithin(root.path, current.path)) {
      if (!await current.exists() || !await current.list().isEmpty) return;
      await current.delete();
      current = current.parent;
    }
  }
}
