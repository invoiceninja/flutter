import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/version.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/mobile_app_promo.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/shell/widgets/health_check_dialog.dart';
import 'package:admin/ui/features/mobile_promo/mobile_app_promo_dialog.dart';
import 'package:admin/ui/features/shell/widgets/keyboard_shortcuts_dialog.dart';

/// Pushes Flutter's bundled `LicensePage`. Modal sub-flow (not page
/// navigation) — see the routing rule in `docs/architecture.md` § Navigation.
Future<void> showAppLicensePage(BuildContext context, String version) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LicensePage(
        applicationName: 'Invoice Ninja',
        applicationVersion: version,
      ),
    ),
  );
}

/// Opens the themed About dialog. Hand-rolled rather than Flutter's built-in
/// `showAboutDialog` so it matches the rest of the app's `InTheme` look.
/// "View Licenses" still pushes Flutter's bundled `LicensePage`, which is the
/// right tool for that subpage.
Future<void> showAppAboutDialog(BuildContext context) async {
  final services = context.read<Services>();
  final session = services.auth.session.value;
  final company = session?.currentCompany;
  // Capture the caller's context for the Health Check chain so the
  // re-open survives popping the About dialog (the builder's `ctx`
  // unmounts on pop).
  final outerContext = context;
  await showDialog<void>(
    context: context,
    builder: (ctx) => _AboutDialog(
      serverVersion: services.serverVersion,
      userEmail: session?.userEmail,
      isSelfHosted: session?.isSelfHosted,
      isOwner: company?.isOwner ?? false,
      isAdmin: company?.isAdmin ?? false,
      onShowHealthCheck: _canShowHealthCheck(session)
          ? () {
              Navigator.of(ctx).pop();
              if (outerContext.mounted) {
                showHealthCheckDialog(outerContext);
              }
            }
          : null,
      // Hidden on mobile (iOS/Android): there's no physical keyboard, so the
      // shortcuts never fire and the button is dead UI. Web keeps it — a
      // browser has a keyboard. Null → the action button isn't rendered.
      onShowKeyboardShortcuts: Env.isMobile
          ? null
          : () {
              Navigator.of(ctx).pop();
              if (outerContext.mounted) {
                showKeyboardShortcutsDialog(outerContext);
              }
            },
      onShowDebugPanel: () {
        Navigator.of(ctx).pop();
        services.debugPanelRevealed.value = true;
      },
      // The promo's permanent way back — still offered after "Don't show
      // again", which only ends the automatic opens. Null wherever the promo
      // has nothing to offer: on a phone, or a demo / localhost session.
      onShowMobileApp:
          currentMobilePromoTargets().isNotEmpty && mobilePromoEligible(session)
          ? () {
              Navigator.of(ctx).pop();
              if (outerContext.mounted) {
                showMobileAppPromoDialog(outerContext, isManual: true);
              }
            }
          : null,
    ),
  );
}

/// Self-hosted admins/owners only; `kDebugMode` lets devs probe against the
/// demo server without flipping a build flag.
bool _canShowHealthCheck(AuthSession? s) {
  if (s == null) return false;
  final me = s.currentCompany;
  if (me == null) return false;
  if (!(me.isAdmin || me.isOwner)) return false;
  return !s.isHosted || kDebugMode;
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog({
    required this.serverVersion,
    required this.userEmail,
    required this.isSelfHosted,
    required this.isOwner,
    required this.isAdmin,
    required this.onShowHealthCheck,
    required this.onShowKeyboardShortcuts,
    required this.onShowDebugPanel,
    this.onShowMobileApp,
  });

  final ValueListenable<String?> serverVersion;
  final String? userEmail;
  final bool? isSelfHosted;
  final bool isOwner;
  final bool isAdmin;
  final VoidCallback? onShowHealthCheck;
  final VoidCallback? onShowKeyboardShortcuts;
  final VoidCallback onShowDebugPanel;
  final VoidCallback? onShowMobileApp;

  /// Combined `v<server>-<platformLetter><clientBuild>` label (see
  /// [AppVersion.versionLabel]). [server] is the live `x-app-version` value.
  String _versionLabel(String? server) => AppVersion.versionLabel(
    serverVersion: server,
    platformLetter: Env.platformLetter,
  );

  /// `<Self-Hosted|Hosted> • <Owner|Admin>` identity line, mirroring
  /// admin-portal's About subtitle. Owner outranks admin; with neither flag
  /// it's just the hosting word. Null when logged out, so the line is omitted.
  String? _identityLine(BuildContext context) {
    final selfHosted = isSelfHosted;
    if (selfHosted == null) return null;
    final hosting = context.tr(selfHosted ? 'selfhosted' : 'hosted');
    if (isOwner) return '$hosting • ${context.tr('owner')}';
    if (isAdmin) return '$hosting • ${context.tr('admin')}';
    return hosting;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final identity = _identityLine(context);
    // Responsive sizing: on phones, shrink the dialog inset so it uses more of
    // the screen, and cap the content to the available width (the fixed 400
    // would otherwise be squeezed to ~280 by the default 40px side insets).
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isNarrow = screenWidth < Breakpoints.wide;
    final horizontalInset = isNarrow ? 16.0 : 40.0;
    final available = screenWidth - horizontalInset * 2;
    final contentWidth = available < 400 ? available : 400.0;
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: 24,
      ),
      title: Text(context.tr('about')),
      content: SizedBox(
        width: contentWidth,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/images/icon.png', width: 40, height: 40),
                  SizedBox(width: InSpacing.lg(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Invoice Ninja',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: tokens.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        ValueListenableBuilder<String?>(
                          valueListenable: serverVersion,
                          builder: (context, server, _) => Text(
                            _versionLabel(server),
                            style: TextStyle(fontSize: 13, color: tokens.ink3),
                          ),
                        ),
                        if (identity != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            identity,
                            style: TextStyle(fontSize: 13, color: tokens.ink3),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (userEmail != null && userEmail!.isNotEmpty) ...[
                SizedBox(height: InSpacing.md(context)),
                Text(
                  userEmail!,
                  style: TextStyle(fontSize: 12, color: tokens.ink3),
                ),
              ],
              if (onShowMobileApp != null) ...[
                SizedBox(height: InSpacing.md(context)),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 40),
                  ),
                  onPressed: onShowMobileApp,
                  icon: const Icon(Icons.smartphone_outlined, size: 18),
                  label: Text(context.tr('mobile_app_promo_entry')),
                ),
              ],
              SizedBox(height: InSpacing.md(context)),
              LinkText(
                label: context.tr('view_licenses'),
                style: const TextStyle(fontSize: 12),
                color: tokens.accent,
                onTap: () => showAppLicensePage(
                  context,
                  _versionLabel(serverVersion.value),
                ),
              ),
              SizedBox(height: InSpacing.md(context)),
              Text(
                '© ${DateTime.now().year} Invoice Ninja',
                style: TextStyle(fontSize: 11, color: tokens.ink4),
              ),
            ],
          ),
        ),
      ),
      actionsOverflowButtonSpacing: InSpacing.sm,
      actions: [
        if (onShowHealthCheck != null)
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: onShowHealthCheck,
            child: Text(context.tr('health_check')),
          ),
        if (onShowKeyboardShortcuts != null)
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: onShowKeyboardShortcuts,
            child: Text(context.tr('keyboard_shortcuts')),
          ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: onShowDebugPanel,
          child: Text(context.tr('debug_panel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('close')),
        ),
      ],
    );
  }
}
