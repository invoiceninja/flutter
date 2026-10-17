import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/services/tls/certificate_trust_store.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/dialogs/untrusted_certificate_dialog.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/utils/formatting.dart';

/// Search keys for the settings sidebar search — the section title, which is
/// the label a search hit reveals (`search_catalog_consistency_test`).
const kTrustedCertificatesSearchKeys = <String>['trusted_certificates'];

/// Device Settings card listing the server certificates the user chose to
/// trust although this device refused them, each with a way to stop trusting
/// it (docs/trusting-a-self-hosted-certificate.md).
///
/// Absent — not empty — when nothing is trusted, and always on web, where the
/// browser owns certificates and the app can't trust one. A pinned
/// certificate is accepted whatever its dates, so an expired one says so
/// here: this is where the user finds out.
class TrustedCertificatesSection extends StatelessWidget {
  const TrustedCertificatesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final trust = context.read<CertificateTrustStore?>();
    if (kIsWeb || trust == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: trust,
      builder: (context, _) {
        final pins = trust.pins;
        if (pins.isEmpty) return const SizedBox.shrink();
        final services = context.read<Services>();
        final companyId = services.auth.session.value?.currentCompanyId ?? '';
        final formatter =
            (companyId.isEmpty ? null : services.formatterIfReady(companyId)) ??
            fallbackCertificateFormatter();
        return FormSection(
          title: context.tr('trusted_certificates'),
          children: [
            Text(
              context.tr('trusted_certificates_help'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink2),
            ),
            for (final pin in pins)
              _TrustedCertificateRow(
                key: ValueKey('trusted_certificate_${pin.key}'),
                pin: pin,
                formatter: formatter,
                onRevoke: () => _revoke(context, trust, pin),
              ),
          ],
        );
      },
    );
  }

  Future<void> _revoke(
    BuildContext context,
    CertificateTrustStore trust,
    TrustedCertificate pin,
  ) async {
    if (context.read<Services>().confirmActions.value) {
      final ok = await showConfirmActionDialog(
        context,
        title: context.tr('stop_trusting'),
        subject: certificateHostLabel(pin.host, pin.port),
        destructive: true,
      );
      if (!ok) return;
    }
    await trust.revoke(pin.host, pin.port);
  }
}

class _TrustedCertificateRow extends StatelessWidget {
  const _TrustedCertificateRow({
    super.key,
    required this.pin,
    required this.formatter,
    required this.onRevoke,
  });

  final TrustedCertificate pin;
  final Formatter formatter;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final facts = pin.facts;
    final expired = DateTime.now().isAfter(facts.notAfter);
    final small = theme.textTheme.bodySmall?.copyWith(color: tokens.ink2);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                certificateHostLabel(pin.host, pin.port),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${context.tr('issued_to')}: '
                '${facts.names.isEmpty ? facts.subject : facts.names.join(', ')}',
                style: small,
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${context.tr('valid_until')}: '
                          '${certificateDate(formatter, facts.notAfter)}',
                    ),
                    if (expired)
                      TextSpan(
                        text: '  ${context.tr('expired')}',
                        style: TextStyle(
                          color: tokens.overdue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                style: small,
              ),
              Text(
                '${context.tr('sha256_fingerprint')}: '
                '${facts.shortFingerprint}',
                style: small?.copyWith(
                  fontFamily: kMonoFontFamily,
                  color: tokens.ink3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: InSpacing.sm),
        TextButton(
          key: ValueKey('stop_trusting_${pin.key}'),
          onPressed: onRevoke,
          child: Text(context.tr('stop_trusting')),
        ),
      ],
    );
  }
}
