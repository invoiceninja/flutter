import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/system_log_repository.dart';
import 'package:admin/domain/gateway_constants.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/settings/view_models/system_log_feed_view_model.dart';
import 'package:admin/ui/features/settings/widgets/system_log_row.dart';

/// Per-gateway System Logs section on the gateway detail screen — the newest
/// 50 logs of the provider's `type_id`(s), fetched server-side
/// ([SystemLogRepository.fetchForTypes]) exactly as the server's own
/// `CompanyGateway::system_logs()` scopes them (admin-portal read that through
/// `?include=system_logs`). It used to filter the company-wide System Logs
/// cache, which holds only the newest 200 logs of every kind — on a busy
/// account the gateway's history was hidden behind email and webhook rows.
///
/// Scoping is by *provider*, not gateway instance: system_log rows carry no
/// `company_gateway_id`, so two gateways of the same provider share logs.
/// Hidden entirely for non-admins/owners (the endpoint is 403 for them) and
/// for providers with no known log type id (bank/crypto gateways).
///
/// **It owns its leading gap.** Whether it draws anything is decided in here,
/// so a gap paid by the host would be paid for a card that then builds
/// nothing (`docs/comments-and-activity.md` § A card that hides itself still
/// costs a gap).
class CompanyGatewaySystemLogsCard extends StatefulWidget {
  const CompanyGatewaySystemLogsCard({
    super.key,
    required this.gateway,
    required this.companyId,
  });

  final CompanyGateway gateway;
  final String companyId;

  @override
  State<CompanyGatewaySystemLogsCard> createState() =>
      _CompanyGatewaySystemLogsCardState();
}

class _CompanyGatewaySystemLogsCardState
    extends State<CompanyGatewaySystemLogsCard> {
  /// Null when this card draws nothing: not an admin/owner, or a provider
  /// that writes no logs.
  SystemLogFeedViewModel? _vm;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(CompanyGatewaySystemLogsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gateway.gatewayKey != widget.gateway.gatewayKey ||
        oldWidget.companyId != widget.companyId) {
      _vm?.dispose();
      _vm = null;
      _attach();
    }
  }

  void _attach() {
    final services = context.read<Services>();
    final typeIds = kGatewaySystemLogTypeIds[widget.gateway.gatewayKey];
    if (widget.companyId.isEmpty ||
        typeIds == null ||
        typeIds.isEmpty ||
        !_canView(services.auth.session.value)) {
      return;
    }
    final repo = services.systemLogs;
    final vm = SystemLogFeedViewModel(fetch: () => repo.fetchForTypes(typeIds));
    _vm = vm;
    unawaited(vm.ensureLoaded());
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  bool _canView(AuthSession? session) {
    final me = session?.currentCompany;
    return me != null && (me.isAdmin || me.isOwner);
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: InSpacing.md(context)),
      child: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => DashboardCardShell(
          title: context.tr('system_logs'),
          trailing: IconButton(
            icon: vm.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            tooltip: context.tr('refresh'),
            visualDensity: Env.isTouchPrimary ? null : VisualDensity.compact,
            onPressed: vm.isLoading ? null : vm.refresh,
          ),
          child: _body(context, vm),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, SystemLogFeedViewModel vm) {
    final tokens = context.inTheme;
    final rows = vm.logs;
    if (rows.isEmpty) {
      Widget note(String key) => Padding(
        padding: const EdgeInsets.symmetric(vertical: InSpacing.sm),
        child: Text(context.tr(key), style: TextStyle(color: tokens.ink3)),
      );
      // A first load: the empty sentence would be a claim nobody has made.
      if (vm.isLoading) return const SizedBox(height: InSpacing.sm);
      switch (vm.result) {
        case SystemLogRefreshResult.forbidden:
        case SystemLogRefreshResult.notFound:
          return note('system_logs_unavailable');
        case SystemLogRefreshResult.networkError:
          return Row(
            children: [
              Expanded(child: note('system_logs_load_failed')),
              const SizedBox(width: InSpacing.sm),
              TextButton(
                onPressed: vm.refresh,
                child: Text(context.tr('retry')),
              ),
            ],
          );
        case SystemLogRefreshResult.ok:
          return note('no_system_logs');
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = Breakpoints.isWide(constraints);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: tokens.border),
              SystemLogRow(log: rows[i], isWide: isWide),
            ],
          ],
        );
      },
    );
  }
}
