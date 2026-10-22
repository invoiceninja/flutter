import 'package:admin/data/repositories/system_log_repository.dart';
import 'package:admin/ui/features/settings/view_models/system_log_feed_view_model.dart';

/// State for the client System Logs tab. Fetches this client's server-side
/// system logs directly (admin/owner only, scoped via the API's `client_id`
/// filter) and holds them in memory — see [SystemLogFeedViewModel].
class ClientSystemLogsViewModel extends SystemLogFeedViewModel {
  ClientSystemLogsViewModel({required this.repo, required this.clientId})
    : super(fetch: () => repo.fetchForClient(clientId));

  final SystemLogRepository repo;
  final String clientId;
}
