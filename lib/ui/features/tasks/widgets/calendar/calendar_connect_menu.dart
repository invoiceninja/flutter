import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/tasks/view_models/calendar_connection_view_model.dart';

/// Toolbar control for connecting / disconnecting a calendar. Renders nothing
/// unless calendar connect is available (hosted, non-demo — mirrors React's
/// `isHosted` gate; the OAuth app credentials are Invoice Ninja's hosted ones).
/// When disconnected it's a "Connect calendar" menu (Google / Microsoft); when
/// connected it shows the linked account + a disconnect affordance.
class CalendarConnectMenu extends StatelessWidget {
  const CalendarConnectMenu({super.key});

  /// Whether the connect UI should show at all. Also gates event loading in the
  /// screen, so keep the predicate identical.
  static bool isAvailable(Services services) {
    final session = services.auth.session.value;
    return !Env.demoMode && (session?.isHosted ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    if (!isAvailable(services)) return const SizedBox.shrink();

    final vm = context.watch<CalendarConnectionViewModel>();
    // Wait until the first status read resolves so we don't flash "Connect"
    // over an already-connected account.
    if (!vm.statusLoaded) return const SizedBox.shrink();

    return vm.isConnected ? _connected(context, vm) : _connect(context, vm);
  }

  Widget _connect(BuildContext context, CalendarConnectionViewModel vm) {
    final tokens = context.inTheme;
    return PopupMenuButton<String>(
      enabled: !vm.connecting,
      tooltip: context.tr('connect_calendar'),
      position: PopupMenuPosition.under,
      onSelected: (provider) => _startConnect(context, vm, provider),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'google',
          child: Text(context.tr('google')),
        ),
        PopupMenuItem<String>(
          value: 'microsoft',
          child: Text(context.tr('microsoft')),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (vm.connecting)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.event_available_outlined, size: 16, color: tokens.ink),
            const SizedBox(width: 6),
            Text(
              context.tr('connect_calendar'),
              style: TextStyle(fontSize: 13, color: tokens.ink),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: tokens.ink3),
          ],
        ),
      ),
    );
  }

  Widget _connected(BuildContext context, CalendarConnectionViewModel vm) {
    final tokens = context.inTheme;
    final email = vm.connectedEmail;
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available, size: 16, color: tokens.accent),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              email == null || email.isEmpty ? context.tr('connected') : email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: tokens.ink),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: context.tr('disconnect'),
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmDisconnect(context, vm),
          ),
        ],
      ),
    );
  }

  Future<void> _startConnect(
    BuildContext context,
    CalendarConnectionViewModel vm,
    String provider,
  ) async {
    try {
      await vm.connect(provider);
    } catch (error) {
      if (context.mounted) {
        Notify.error(context, context.tr('error'), error: error);
      }
    }
  }

  Future<void> _confirmDisconnect(
    BuildContext context,
    CalendarConnectionViewModel vm,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('are_you_sure')),
        content: Text(dialogContext.tr('disconnect_calendar_confirmation')),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            child: Text(dialogContext.tr('cancel')),
          ),
          SizedBox(width: InSpacing.md(dialogContext)),
          PrimaryDialogAction(
            label: dialogContext.tr('continue'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await vm.disconnect();
      if (context.mounted) {
        Notify.success(context, context.tr('disconnected'));
      }
    } catch (error) {
      if (context.mounted) {
        Notify.error(context, context.tr('error'), error: error);
      }
    }
  }
}
