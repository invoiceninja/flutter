import 'package:flutter/foundation.dart';

import 'package:admin/data/models/domain/system_log.dart';
import 'package:admin/data/repositories/system_log_repository.dart';

/// State for the client System Logs tab. Fetches this client's server-side
/// system logs directly (admin/owner only, scoped via the API's `client_id`
/// filter) and holds them in memory — the per-client feed is read-only
/// ancillary detail data, so it bypasses Drift, mirroring
/// [EntityActivityViewModel].
class ClientSystemLogsViewModel extends ChangeNotifier {
  ClientSystemLogsViewModel({required this.repo, required this.clientId});

  final SystemLogRepository repo;
  final String clientId;

  List<SystemLog> _logs = const [];
  List<SystemLog> get logs => _logs;

  /// Outcome of the last fetch. Drives the empty-state copy (forbidden /
  /// notFound → "unavailable"; networkError → retry).
  SystemLogRefreshResult _result = SystemLogRefreshResult.ok;
  SystemLogRefreshResult get result => _result;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _started = false;
  bool _disposed = false;

  /// Idempotent first load — call from the view's `initState`.
  Future<void> ensureLoaded() async {
    if (_started || _disposed) return;
    _started = true;
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    _isLoading = true;
    notifyListeners();
    SystemLogRefreshResult result;
    List<SystemLog> logs;
    try {
      final res = await repo.fetchForClient(clientId);
      result = res.$1;
      logs = res.$2;
    } catch (_) {
      // fetchForClient only rethrows truly-unexpected exceptions; surface
      // them as a retryable error state rather than crashing the tab.
      result = SystemLogRefreshResult.networkError;
      logs = const [];
    }
    if (_disposed) return;
    _result = result;
    _logs = logs;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
