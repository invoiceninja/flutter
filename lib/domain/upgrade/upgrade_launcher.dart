import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/upgrade/purchase_service.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';

/// The single platform-conditional upgrade entry point. **Every** upgrade
/// surface (the `PlanGateBanner` CTA, the Plan screen's "Upgrade / Change
/// Plan" button, the company picker's plan-limited "New Company" row) routes
/// here so the App Store Guideline 3.1.1 rule — never steer to an external
/// payment URL for an in-app subscription — is enforced in one place.
///
/// - Web / desktop → external `ninjaPortalUrl` (Stripe billing portal).
/// - iOS / Android, IAP-managed plan → the store's own subscription
///   management page (Apple/Google forbid us mutating their subscription
///   from a web portal).
/// - iOS / Android, web-billed paid plan → the portal (manage existing).
/// - iOS / Android, free/trial → the in-app store purchase sheet.
Future<void> launchUpgrade(BuildContext context) async {
  final services = context.read<Services>();
  final session = services.auth.session.value;
  final portalUrl = session?.ninjaPortalUrl ?? '';

  final isStore =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  if (!isStore) {
    await _openPortalOrPlanScreen(context, portalUrl);
    return;
  }

  if (session?.hasIapPlan ?? false) {
    await _openStoreSubscriptions();
    return;
  }

  // Already paying through the web portal on a store device — let them
  // manage that subscription where it was created.
  if (session != null && session.isPaidPlanSlug && !session.isTrial) {
    await _openPortalOrPlanScreen(context, portalUrl);
    return;
  }

  if (!context.mounted) return;
  await showUpgradeSheet(context);
}

Future<void> _openPortalOrPlanScreen(BuildContext context, String url) async {
  if (url.isNotEmpty) {
    final uri = Uri.tryParse(url);
    // Falls through to the in-app destination when it doesn't open.
    if (uri != null && await launchExternalUri(uri)) return;
  }
  if (!context.mounted) return;
  // Plan is the Account Management shell's bare-URL default tab; `/plan` is not
  // a matchable route (it would land on the route-error view).
  context.go('/settings/account_management');
}

Future<void> _openStoreSubscriptions() async {
  final uri = defaultTargetPlatform == TargetPlatform.android
      ? Uri.parse('https://play.google.com/store/account/subscriptions')
      // Apple's own subscription management page — not payment steering.
      : Uri.parse('https://apps.apple.com/account/subscriptions');
  await launchExternalUri(uri);
}

/// Bottom sheet listing the store products. Owns a [PurchaseService] for its
/// lifetime so the purchase-stream subscription is scoped to the sheet.
Future<void> showUpgradeSheet(BuildContext context) async {
  final services = context.read<Services>();
  final svc = PurchaseService(
    apiClient: services.apiClient,
    auth: services.auth,
  );
  if (!await svc.isAvailable) {
    // Store backend unreachable (sandbox/login) — fall back to the portal so
    // the user is never left at a dead end.
    if (context.mounted) {
      final url = services.auth.session.value?.ninjaPortalUrl ?? '';
      await _openPortalOrPlanScreen(context, url);
    }
    await svc.dispose();
    return;
  }
  await svc.init();
  if (!context.mounted) {
    await svc.dispose();
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _UpgradeSheet(service: svc),
  );
  await svc.dispose();
}

class _UpgradeSheet extends StatelessWidget {
  const _UpgradeSheet({required this.service});

  final PurchaseService service;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('upgrade'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: InSpacing.md(context)),
            ValueListenableBuilder<bool>(
              valueListenable: service.busy,
              builder: (context, busy, _) => ValueListenableBuilder(
                valueListenable: service.products,
                builder: (context, products, _) {
                  if (busy && products.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (products.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(context.tr('no_results')),
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final p in products)
                        ListTile(
                          title: Text(p.title),
                          subtitle: Text(p.description),
                          trailing: Text(
                            p.price,
                            style: TextStyle(color: tokens.accentInk),
                          ),
                          onTap: busy ? null : () => service.buy(p),
                        ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: InSpacing.md(context)),
            TextButton(
              onPressed: () => service.restore(),
              child: Text(context.tr('restore_purchases')),
            ),
          ],
        ),
      ),
    );
  }
}
