import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';

final _log = Logger('DocuNinjaDocumentViewModel');

/// One DocuNinja document and its timeline (React's `show/Document.tsx`),
/// online-only (docs/docuninja.md). Every action re-reads the document, so the
/// screen always shows what DocuNinja holds.
class DocuNinjaDocumentViewModel extends ChangeNotifier {
  DocuNinjaDocumentViewModel({required DocuNinjaApi api, required this.id})
    : _api = api;

  final DocuNinjaApi _api;
  final String id;

  DnDocument? _document;
  DnDocument? get document => _document;
  List<DnTimelineEntry> _timeline = const [];
  List<DnTimelineEntry> get timeline => _timeline;

  bool _loading = false;
  bool get isLoading => _loading;
  bool _busy = false;

  /// An action is running; the actions are disabled meanwhile.
  bool get isBusy => _busy;

  /// The load failed: offline, not found / no access, or otherwise.
  Object? _error;
  Object? get error => _error;
  bool get isOffline => _error is NetworkException;
  bool get isMissing =>
      _error is DocuNinjaException &&
      const {403, 404}.contains((_error! as DocuNinjaException).statusCode);

  bool _disposed = false;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final results = await Future.wait([
        _api.document(id),
        _api.timeline(id).catchError((Object e) {
          _log.warning('DocuNinja timeline failed', e);
          return const <DnTimelineEntry>[];
        }),
      ]);
      _document = results[0] as DnDocument;
      _timeline = results[1] as List<DnTimelineEntry>;
    } on Object catch (e, st) {
      if (e is! NetworkException) {
        _log.warning('DocuNinja document failed', e, st);
      }
      _error = e;
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Runs [action], then re-reads the document. Returns whether it worked.
  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    _busy = true;
    _notify();
    try {
      await action();
      await load();
      return true;
    } on Object catch (e, st) {
      _log.warning('DocuNinja action failed', e, st);
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Emails every invitation, or [only] one (a resend).
  Future<bool> send({DnInvitation? only}) {
    final doc = _document;
    if (doc == null) return Future.value(false);
    return _run(() => _api.send(id, only == null ? doc.invitations : [only]));
  }

  Future<bool> voidDocument() => _run(() => _api.action(id, 'void'));

  Future<bool> archive() => _run(() => _api.bulk('archive', [id]));

  Future<bool> restore() => _run(() => _api.bulk('restore', [id]));

  /// Saves the Options modal. Returns null on success, else the failure, so
  /// the dialog can stay open with the user's edit and the field errors.
  /// [setExpiry] sends [expiresAt] (null clears it); otherwise expiry is left
  /// alone.
  Future<Object?> saveSettings({
    required String description,
    bool setExpiry = false,
    String? expiresAt,
  }) async {
    if (_busy) return StateError('busy');
    _busy = true;
    _notify();
    try {
      await _api.updateDocument(
        id,
        description: description,
        setExpiry: setExpiry,
        expiresAt: expiresAt,
      );
      await load();
      return null;
    } on Object catch (e, st) {
      _log.warning('DocuNinja settings save failed', e, st);
      return e;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Clones the document; returns the copy's id, or null.
  Future<String?> clone() async {
    if (_busy) return null;
    _busy = true;
    _notify();
    try {
      final json = await _api.action(id, 'clone');
      final data = json is Map ? json['data'] : null;
      final newId = data is Map ? '${data['id'] ?? ''}' : '';
      return newId.isEmpty ? null : newId;
    } on Object catch (e, st) {
      _log.warning('DocuNinja clone failed', e, st);
      return null;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// React's Clone to Template; returns the new template's id, or null.
  Future<String?> makeTemplate() async {
    if (_busy) return null;
    _busy = true;
    _notify();
    try {
      final templateId = await _api.makeBlueprint(id);
      return templateId.isEmpty ? null : templateId;
    } on Object catch (e, st) {
      _log.warning('DocuNinja make template failed', e, st);
      return null;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Deletes the document. Like React, the page stays, now showing it
  /// deleted, with Restore.
  Future<bool> delete() => _run(() => _api.bulk('delete', [id]));

  Future<DnFileBytes> download() => _api.download(id);

  Future<DnFileBytes> auditLog() => _api.auditLog(id);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
