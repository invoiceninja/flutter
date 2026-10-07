import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/models/domain/email_history.dart';
import 'package:admin/data/services/emails_api.dart';
import 'package:admin/domain/sync/mutation.dart';

/// State for the client Email-History tab. Fetches
/// `POST /api/v1/emails/clientHistory/{clientId}` on first observation and
/// again whenever a pending `reactivateEmail` outbox row drains (so a
/// just-reactivated address drops its bounce on the next read). Also
/// exposes the set of message ids with an in-flight reactivate so the view
/// can show a spinner and block double-enqueue.
class ClientEmailHistoryViewModel extends ChangeNotifier {
  ClientEmailHistoryViewModel({
    required this.api,
    required this.outbox,
    required this.companyId,
    required this.clientId,
  }) {
    pending = outbox.watchPendingForEntity(
      companyId: companyId,
      entityType: 'client',
      entityId: clientId,
      kind: MutationKind.reactivateEmail,
    );
    _pendingSub = pending.listen(_onPendingTick);
  }

  final EmailsApi api;
  final OutboxDao outbox;
  final String companyId;
  final String clientId;

  late final Stream<List<OutboxRow>> pending;
  StreamSubscription<List<OutboxRow>>? _pendingSub;

  List<EmailHistoryRecord> _records = const [];
  List<EmailHistoryRecord> get records => _records;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;

  bool _started = false;
  bool _disposed = false;
  int _lastPendingCount = 0;

  /// Message ids with a pending reactivate row — view shows these in-flight.
  Set<String> pendingMessageIds = const {};

  /// Idempotent — first call fetches, the rest are no-ops.
  Future<void> ensureLoaded() async {
    if (_started || _disposed) return;
    _started = true;
    // The server has never seen an offline-created client, so asking for its
    // email history is a guaranteed error. There is none; say so by staying
    // empty rather than by showing a failed request.
    if (clientId.startsWith('tmp_')) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await api.clientHistory(clientId: clientId);
      _records = raw.map(EmailHistoryRecord.fromApi).toList();
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _onPendingTick(List<OutboxRow> rows) {
    if (_disposed) return;
    pendingMessageIds = rows
        .map((r) => _messageId(r.payload))
        .whereType<String>()
        .toSet();
    final count = rows.length;
    // A reactivate just drained — refetch so the cleared bounce reflects.
    if (_started && !_isLoading && _lastPendingCount > 0 && count == 0) {
      unawaited(refresh());
    }
    _lastPendingCount = count;
    notifyListeners();
  }

  static String? _messageId(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map && decoded['message_id'] is String) {
        return decoded['message_id'] as String;
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _pendingSub?.cancel();
    super.dispose();
  }
}
