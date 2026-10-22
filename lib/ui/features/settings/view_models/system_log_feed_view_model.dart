import 'package:flutter/foundation.dart';

import 'package:admin/data/models/domain/system_log.dart';
import 'package:admin/data/repositories/system_log_repository.dart';

/// A scoped, read-only System Logs feed held in memory: [fetch] is one of
/// [SystemLogRepository]'s server-filtered reads (`fetchForClient`,
/// `fetchForTypes`). Ancillary detail data, so it bypasses Drift, mirroring
/// `EntityActivityViewModel`. Shared by the client System Logs tab and the
/// gateway detail's System Logs card.
class SystemLogFeedViewModel extends ChangeNotifier {
  SystemLogFeedViewModel({required this.fetch});

  final Future<(SystemLogRefreshResult, List<SystemLog>)> Function() fetch;

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
    if (_disposed || _isLoading) return;
    _isLoading = true;
    notifyListeners();
    SystemLogRefreshResult result;
    List<SystemLog> logs;
    try {
      final res = await fetch();
      result = res.$1;
      logs = res.$2;
    } catch (_) {
      // The repository only rethrows truly-unexpected exceptions; surface
      // them as a retryable error state rather than crashing the view.
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
