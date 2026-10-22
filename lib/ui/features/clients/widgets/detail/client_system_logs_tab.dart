import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/repositories/system_log_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_list_card.dart';
import 'package:admin/ui/features/clients/view_models/client_system_logs_view_model.dart';
import 'package:admin/ui/features/settings/widgets/system_log_row.dart';

/// Client System Logs tab — mirrors the old Flutter app's per-client system
/// logs (gateway / email / webhook events tied to this client). Fetched
/// server-side via the `client_id` filter (admin/owner only) and rendered with
/// the shared [SystemLogRow]. The tab is only added for admins/owners (see
/// `client_detail_tabs.dart`), matching the endpoint's 403 gate.
class ClientSystemLogsTab extends StatefulWidget {
  const ClientSystemLogsTab({required this.client, super.key});

  final Client client;

  @override
  State<ClientSystemLogsTab> createState() => _ClientSystemLogsTabState();
}

class _ClientSystemLogsTabState extends State<ClientSystemLogsTab> {
  late final ClientSystemLogsViewModel _vm;

  @override
  void initState() {
    super.initState();
    final services = context.read<Services>();
    _vm = ClientSystemLogsViewModel(
      repo: services.systemLogs,
      clientId: widget.client.id,
    );
    // A tmp_ (offline-created, not-yet-synced) client has no server-side logs;
    // skip the fetch so we show the empty state instead of a 4xx error.
    if (!widget.client.id.startsWith('tmp_')) {
      unawaited(_vm.ensureLoaded());
    }
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A tmp_ client has no server-side logs to fetch — keep the refresh button
    // inert so a manual tap can't fire `client_id=tmp_…` and flash a 4xx error.
    final isTmp = widget.client.id.startsWith('tmp_');
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
      child: AnimatedBuilder(
        animation: _vm,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                icon: _vm.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: context.tr('refresh'),
                onPressed: (_vm.isLoading || isTmp) ? null : _vm.refresh,
              ),
            ),
            const SizedBox(height: InSpacing.sm),
            ActivityListCard(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final tokens = context.inTheme;
    final logs = _vm.logs;
    if (logs.isEmpty) {
      if (_vm.result == SystemLogRefreshResult.forbidden ||
          _vm.result == SystemLogRefreshResult.notFound) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: EmptyState(
            icon: Icons.lock_outline,
            title: context.tr('system_logs_unavailable'),
            subtitle: context.tr('system_logs_unavailable_help'),
          ),
        );
      }
      if (_vm.result == SystemLogRefreshResult.networkError) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorView(
            message: context.tr('system_logs_load_failed'),
            onRetry: _vm.refresh,
          ),
        );
      }
      if (_vm.isLoading) {
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(16),
        child: EmptyState(
          icon: Icons.terminal_outlined,
          title: context.tr('no_system_logs'),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = Breakpoints.isWide(constraints);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < logs.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: tokens.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SystemLogRow(log: logs[i], isWide: isWide),
              ),
            ],
          ],
        );
      },
    );
  }
}
