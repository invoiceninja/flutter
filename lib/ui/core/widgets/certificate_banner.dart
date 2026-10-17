import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/tls/certificate_problems.dart';
import 'package:admin/data/services/tls/certificate_trust_store.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/untrusted_certificate_dialog.dart';

/// Slim strip across the top of the authenticated shell while this device is
/// refusing the signed-in server's certificate — typically a self-signed
/// certificate that was renewed after the user trusted the old one.
///
/// Without it nothing on screen says anything is wrong: [OfflineBanner]
/// follows the radio, not the server, so the shell reads "online" while every
/// request fails its handshake and every save waits in the outbox. It stays
/// up for as long as that is true — a toast would time out on a problem that
/// hasn't — and clears itself on a trust, a revoke, or the next response from
/// that server (`CertificateTrustStore.noteReached`).
///
/// Stands down while the device is offline: the offline strip already says
/// the more useful thing, and one strip owns the top inset.
class CertificateBanner extends StatefulWidget {
  const CertificateBanner({super.key});

  @override
  State<CertificateBanner> createState() => _CertificateBannerState();
}

class _CertificateBannerState extends State<CertificateBanner> {
  late final Services _services = context.read<Services>();

  /// Hoisted so a rebuild doesn't re-subscribe — the stream probes the
  /// platform on every listen.
  late final Stream<bool> _online = _services.connectivity.isOnlineStream;

  @override
  Widget build(BuildContext context) {
    // Before any `Services` read: a shell pumped without the root provider
    // (a widget test) shows no banner and touches nothing.
    final trust = context.read<CertificateTrustStore?>();
    if (trust == null) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: _online,
      builder: (context, online) {
        // Only a known-offline device stands down: an unanswered first probe
        // must not hide a refusal the user needs to see.
        if (online.data == false) return const SizedBox.shrink();
        return ValueListenableBuilder<ApiCredentials?>(
          valueListenable: _services.auth.credentials,
          builder: (context, creds, _) => ListenableBuilder(
            listenable: trust,
            builder: (context, _) {
              final server = creds == null || !creds.isAuthenticated
                  ? null
                  : Uri.tryParse(creds.baseUrl);
              final refused = server == null || server.host.isEmpty
                  ? null
                  : trust.outstandingFor(server.host, server.port);
              if (refused == null) return const SizedBox.shrink();
              return _CertificateStrip(
                refused: refused,
                hosted: creds!.isHosted || trust.isHosted(refused.host),
                changed: trust.pinFor(refused.host, refused.port) != null,
                onReview: () => _review(refused, creds.companyId),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _review(CertificateRejection refused, String companyId) async {
    final trust = context.read<CertificateTrustStore>();
    final trusted = await showUntrustedCertificateDialog(
      context,
      host: refused.host,
      port: refused.port,
      certificate: refused.facts,
      problems: certificateProblems(
        host: refused.host,
        facts: refused.facts,
        now: DateTime.now(),
      ),
      canTrust: !trust.isHosted(refused.host),
      replacing: trust.pinFor(refused.host, refused.port),
      continues: false,
      formatter: _services.formatterIfReady(companyId),
    );
    if (!trusted) return;
    if (!await trust.trust(refused.host, refused.port, refused.facts)) return;
    // What coming back online does: send what waited, and let screens that
    // asked something meanwhile ask again.
    if (companyId.isNotEmpty) {
      unawaited(_services.sync.drainOnce(companyId: companyId));
    }
    _services.backOnline.fire();
    unawaited(_services.refreshScheduler.requestSoon());
  }
}

class _CertificateStrip extends StatelessWidget {
  const _CertificateStrip({
    required this.refused,
    required this.hosted,
    required this.changed,
    required this.onReview,
  });

  final CertificateRejection refused;
  final bool hosted;
  final bool changed;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final host = certificateHostLabel(refused.host, refused.port);
    final message = context.tr(
      hosted
          ? 'certificate_banner_hosted'
          : changed
          ? 'certificate_banner_changed'
          : 'certificate_banner',
      {'host': host},
    );
    return Material(
      key: const ValueKey('certificate_banner'),
      color: tokens.partialSoft,
      // The same inset handling as `OfflineBanner`, which this never shows
      // beside (see the class doc).
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.lg(context),
            vertical: InSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.gpp_maybe_outlined, size: 18, color: tokens.partial),
              const SizedBox(width: InSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  // Never clamped: this line is the only explanation the user
                  // gets, and at a large text size on a phone it needs four.
                  style: TextStyle(color: tokens.ink2, fontSize: 13),
                ),
              ),
              if (!hosted) ...[
                const SizedBox(width: InSpacing.sm),
                TextButton(
                  key: const ValueKey('certificate_banner_review'),
                  onPressed: onReview,
                  child: Text(context.tr('review')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
