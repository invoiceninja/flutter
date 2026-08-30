import 'package:flutter/material.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/gateway_constants.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/confirm_password_sheet.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/notify_async.dart';

/// Action set surfaced for a company gateway. Mirrors `ProjectAction` —
/// edit / archive / restore / delete are wired today; `disconnect`
/// (Stripe Connect) lands in Phase 2.
enum CompanyGatewayAction {
  edit,
  clone,
  disconnect,
  importCustomers,
  verifyCustomers,
  copyLink,
  archive,
  restore,
  delete,
}

class CompanyGatewayActions {
  CompanyGatewayActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone / archive /
  /// restore / delete — you can't clone or manage a record that doesn't exist.
  static bool isLifecycle(CompanyGatewayAction action) {
    switch (action) {
      case CompanyGatewayAction.clone:
      case CompanyGatewayAction.archive:
      case CompanyGatewayAction.restore:
      case CompanyGatewayAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(CompanyGateway gateway) => gateway.label;

  static List<EntityActionItem<CompanyGatewayAction>> itemsFor(
    BuildContext context,
    CompanyGateway gateway,
    void Function(CompanyGatewayAction) onTap,
  ) {
    final canArchive = gateway.archivedAt == 0 && !gateway.isDeleted;
    final canRestore = gateway.archivedAt != 0 || gateway.isDeleted;

    final isStripeConnect = gateway.gatewayKey == kGatewayStripeConnect;
    final isAnyStripe =
        gateway.gatewayKey == kGatewayStripe ||
        gateway.gatewayKey == kGatewayStripeConnect;
    return [
      editActionItem(
        context: context,
        kind: CompanyGatewayAction.edit,
        onTap: () => onTap(CompanyGatewayAction.edit),
      ),
      if (isStripeConnect)
        EntityActionItem(
          kind: CompanyGatewayAction.disconnect,
          confirm: true,
          confirmSubject: _confirmSubject(gateway),
          icon: Icons.link_off_outlined,
          label: context.tr('disconnect'),
          enabled: true,
          onTap: () => onTap(CompanyGatewayAction.disconnect),
        ),
      if (isAnyStripe) ...[
        EntityActionItem(
          kind: CompanyGatewayAction.importCustomers,
          confirm: true,
          confirmSubject: _confirmSubject(gateway),
          icon: Icons.cloud_download_outlined,
          label: context.tr('import_customers'),
          enabled: true,
          onTap: () => onTap(CompanyGatewayAction.importCustomers),
        ),
        EntityActionItem(
          kind: CompanyGatewayAction.verifyCustomers,
          icon: Icons.fact_check_outlined,
          label: context.tr('verify_customers'),
          enabled: true,
          onTap: () => onTap(CompanyGatewayAction.verifyCustomers),
        ),
      ],
      EntityActionItem(
        kind: CompanyGatewayAction.clone,
        icon: Icons.copy_all_outlined,
        label: context.tr('clone'),
        enabled: true,
        onTap: () => onTap(CompanyGatewayAction.clone),
      ),
      ?copyLinkActionItem(
        context: context,
        kind: CompanyGatewayAction.copyLink,
        entityId: gateway.id,
        onTap: () => onTap(CompanyGatewayAction.copyLink),
      ),
      ?archiveActionItem(
        context: context,
        subject: _confirmSubject(gateway),
        kind: CompanyGatewayAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(CompanyGatewayAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: CompanyGatewayAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(CompanyGatewayAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        subject: _confirmSubject(gateway),
        kind: CompanyGatewayAction.delete,
        canDelete: !gateway.isDeleted,
        onTap: () => onTap(CompanyGatewayAction.delete),
      ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    CompanyGateway gateway,
    CompanyGatewayAction action,
  ) async {
    switch (action) {
      case CompanyGatewayAction.edit:
        goEntityEdit(context, '/settings/company_gateways', gateway.id);
      case CompanyGatewayAction.clone:
        {
          // Clone client-side via the outbox create (the gateway create flow is
          // picker-first and doesn't read a seed draft, so the generic
          // `goEntityCreateFullWidth(extra:)` convention doesn't apply here).
          // Strip server-owned fields; navigate to the new row's edit screen for
          // review. (React clones server-side via `POST .../clone`; we clone
          // offline through the outbox instead — same outcome, different path.)
          var cleaned = gateway.copyWith(
            id: '',
            label: gateway.label.isEmpty ? '' : '${gateway.label} (copy)',
            createdAt: 0,
            updatedAt: 0,
            archivedAt: 0,
            isDeleted: false,
            isDirty: false,
          );
          // Don't carry an OAuth provider's connected-account credentials into
          // the clone — clear config so it starts fresh (the user re-runs
          // setup). Non-OAuth gateways keep their config, matching React.
          if (gateway.isOAuthGateway) {
            cleaned = cleaned.withConfig(const <String, dynamic>{});
          }
          final result = await services.companyGateways.create(
            companyId: companyId,
            draft: cleaned,
          );
          if (context.mounted) {
            goEntityEdit(
              context,
              '/settings/company_gateways',
              result.entity.id,
            );
          }
        }
      case CompanyGatewayAction.disconnect:
        {
          // Stripe disconnect hits a password-gated endpoint. Prime the
          // password cache on demand and retry rather than dead-ending on a
          // generic error when the cache is cold (e.g. after a restart).
          final disconnected = await _withPasswordRetry(
            context,
            services,
            () async {
              await services.companyGateways.disconnectStripe(id: gateway.id);
              return true;
            },
          );
          if (disconnected == true && context.mounted) {
            Notify.success(context, context.tr('disconnected_gateway'));
          }
        }
      case CompanyGatewayAction.importCustomers:
        await runMutationWithNotify(
          context,
          () => services.companyGateways.importStripeCustomers(id: gateway.id),
          successMsg: context.tr('imported_customers'),
        );
      case CompanyGatewayAction.verifyCustomers:
        {
          // Verify hits the same password-gated `/stripe/verify` endpoint.
          final counts = await _withPasswordRetry(
            context,
            services,
            () => services.companyGateways.verifyStripeCustomers(),
          );
          if (counts != null && context.mounted) {
            await _showVerifyCustomersDialog(context, counts);
          }
        }
      case CompanyGatewayAction.copyLink:
        await copyEntityLink(context, EntityType.companyGateway, gateway.id);
      case CompanyGatewayAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'company_gateway',
          op: () => services.companyGateways.archive(
            companyId: companyId,
            id: gateway.id,
          ),
          undoOp: () => services.companyGateways.restore(
            companyId: companyId,
            id: gateway.id,
          ),
        );
      case CompanyGatewayAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'company_gateway',
          op: () => services.companyGateways.restore(
            companyId: companyId,
            id: gateway.id,
          ),
        );
      case CompanyGatewayAction.delete:
        if (!requireSynced(context, gateway.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'company_gateway',
          op: () => services.companyGateways.delete(
            companyId: companyId,
            id: gateway.id,
          ),
          undoOp: () => services.companyGateways.restore(
            companyId: companyId,
            id: gateway.id,
          ),
        );
    }
  }

  /// Run a password-gated Stripe op. The server throws
  /// [PasswordRequiredException] when the 5-minute password cache is empty
  /// (common right after an app restart); prime it via
  /// [showConfirmPasswordSheet] and retry once. Returns the op's result, or
  /// null if it failed or the user cancelled — mirroring the danger-zone /
  /// 2FA re-prompt pattern instead of swallowing the exception into a generic
  /// "could not save".
  static Future<T?> _withPasswordRetry<T>(
    BuildContext context,
    Services services,
    Future<T> Function() op,
  ) async {
    try {
      return await op();
    } on PasswordRequiredException {
      if (!context.mounted) return null;
      final ok = await showConfirmPasswordSheet(
        context,
        cache: services.passwordCache,
      );
      if (!ok || !context.mounted) return null;
      try {
        return await op();
      } catch (e) {
        // Wrong/expired password (or any post-prompt failure): clear the
        // cache so the next attempt re-prompts cleanly instead of silently
        // resending a known-bad password. Mirrors security_settings /
        // danger_zone.
        services.passwordCache.clear();
        if (context.mounted) {
          Notify.error(context, context.tr('could_not_save'), error: e);
        }
        return null;
      }
    } catch (e) {
      if (!context.mounted) return null;
      Notify.error(context, context.tr('could_not_save'), error: e);
      return null;
    }
  }

  static Future<void> _showVerifyCustomersDialog(
    BuildContext context,
    ({int stripeCount, int localCount}) counts,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('customer_count')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CountRow(label: 'Stripe', value: counts.stripeCount),
            const SizedBox(height: 8),
            _CountRow(label: 'Invoice Ninja', value: counts.localCount),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.tr('close')),
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        SizedBox(width: 100, child: Text('$value', textAlign: TextAlign.end)),
      ],
    );
  }
}
