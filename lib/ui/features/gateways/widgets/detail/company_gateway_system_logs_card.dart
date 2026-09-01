import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/data/models/domain/system_log.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/gateway_constants.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/system_log_row.dart';

/// Per-gateway System Logs section on the gateway detail screen. Reuses the
/// shared company-wide system-logs cache (admin/owner only) and filters it to
/// the provider's log type ids. Triggers a refresh on first mount when the
/// cache is stale, mirroring the global System Logs screen.
///
/// Scoping is by *provider*, not gateway instance: system_log rows carry no
/// `company_gateway_id`, so two gateways of the same provider share logs.
/// Hidden entirely for non-admins/owners (the endpoint is 403 for them) and
/// for providers with no known log type id (bank/crypto gateways).
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
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRefresh());
  }

  /// Fetch on first mount when the cache is empty / > 1 h old — the cache is
  /// only otherwise warmed by visiting the global System Logs screen.
  Future<void> _maybeRefresh() async {
    if (!mounted) return;
    final services = context.read<Services>();
    if (widget.companyId.isEmpty) return;
    if (!_canView(services.auth.session.value)) return;
    if (kGatewaySystemLogTypeIds[widget.gateway.gatewayKey] == null) return;
    final last = await services.systemLogs.lastFetchedAt(widget.companyId);
    if (!mounted) return;
    final stale =
        last == null ||
        DateTime.now().toUtc().difference(last) > const Duration(hours: 1);
    if (stale) await _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing || widget.companyId.isEmpty) return;
    final services = context.read<Services>();
    setState(() => _refreshing = true);
    await services.systemLogs.refresh(widget.companyId);
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  bool _canView(AuthSession? session) {
    final me = session?.currentCompany;
    return me != null && (me.isAdmin || me.isOwner);
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    if (!_canView(services.auth.session.value)) return const SizedBox.shrink();
    final typeIds = kGatewaySystemLogTypeIds[widget.gateway.gatewayKey];
    if (typeIds == null || typeIds.isEmpty) return const SizedBox.shrink();
    final tokens = context.inTheme;

    return FormSection(
      title: context.tr('system_logs'),
      trailing: IconButton(
        icon: _refreshing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        tooltip: context.tr('refresh'),
        onPressed: _refreshing ? null : _refresh,
      ),
      children: [
        WatchBuilder<List<SystemLog>>(
          cacheKey: widget.companyId,
          create: () => services.systemLogs.watch(widget.companyId),
          builder: (context, snap) {
            final rows = (snap.data ?? const <SystemLog>[])
                .where((l) => l.categoryId == 1 && typeIds.contains(l.typeId))
                .toList(growable: false);
            if (rows.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
                child: Text(
                  context.tr('no_system_logs'),
                  style: TextStyle(color: tokens.ink3),
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = Breakpoints.isWide(constraints);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 1, color: tokens.border),
                      SystemLogRow(log: rows[i], isWide: isWide),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
