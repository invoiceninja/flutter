import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/services/tls/certificate_facts.dart';
import 'package:admin/data/services/tls/certificate_problems.dart';
import 'package:admin/data/services/tls/certificate_trust_store.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/utils/local_network_host.dart';

/// Explains a server certificate this device refused and, when [canTrust],
/// offers to trust that exact certificate for [host]:[port]
/// (docs/trusting-a-self-hosted-certificate.md).
///
/// It leads with what is wrong and how to fix it on the server — usually
/// the better outcome — and only then the facts someone would check before
/// trusting it. Nothing is behind a disclosure. A changed certificate on a
/// server the user already trusted ([replacing]) says so first: that is what
/// an intercepted connection looks like.
///
/// Cancel holds the focus, so a stray Enter never trusts anything. Returns
/// `true` only when the user chose to trust it. [continues] labels the
/// button "Trust and continue" where trusting retries the step that failed.
/// [formatter] renders the dates; without one (the login screen has no
/// company yet) they fall back to `yyyy-MM-dd`.
Future<bool> showUntrustedCertificateDialog(
  BuildContext context, {
  required String host,
  required int port,
  required CertificateFacts certificate,
  required List<CertificateProblem> problems,
  required bool canTrust,
  TrustedCertificate? replacing,
  bool continues = true,
  Formatter? formatter,
}) async {
  final trusted = await showDialog<bool>(
    context: context,
    builder: (_) => UntrustedCertificateDialog(
      host: host,
      port: port,
      certificate: certificate,
      problems: problems,
      canTrust: canTrust,
      replacing: replacing,
      continues: continues,
      formatter: formatter ?? fallbackCertificateFormatter(),
    ),
  );
  return trusted ?? false;
}

/// A formatter for a certificate's dates when no company's is at hand: the
/// app-wide fallback settings, which render `yyyy-MM-dd`.
Formatter fallbackCertificateFormatter() => Formatter(
  settings: CompanyFormatSettings.fallback,
  currencies: const {},
  countries: const {},
  dateFormats: const {},
);

/// [dt] as a calendar date on this device, through [formatter].
String certificateDate(Formatter formatter, DateTime dt) =>
    formatter.date(dt.toLocal().toIso8601String());

/// `host`, or `host:port` off the default HTTPS port.
String certificateHostLabel(String host, int port) =>
    port == 443 ? host : '$host:$port';

class UntrustedCertificateDialog extends StatelessWidget {
  const UntrustedCertificateDialog({
    super.key,
    required this.host,
    required this.port,
    required this.certificate,
    required this.problems,
    required this.canTrust,
    required this.formatter,
    this.replacing,
    this.continues = true,
  });

  final String host;
  final int port;
  final CertificateFacts certificate;
  final List<CertificateProblem> problems;
  final bool canTrust;
  final TrustedCertificate? replacing;
  final bool continues;
  final Formatter formatter;

  String get _hostLabel => certificateHostLabel(host, port);

  String get _names => certificate.names.isEmpty
      ? certificate.subject
      : certificate.names.join(', ');

  CertificateProblem get _lead =>
      problems.isEmpty ? CertificateProblem.untrustedIssuer : problems.first;

  bool get _isLocal => isLocalNetworkHost(host);

  /// A CA-issued certificate for other names on a public host is what a
  /// shared host serves before the customer's own certificate is installed —
  /// the beta report's case, and the one where "install a certificate in your
  /// hosting panel" is the fix. A self-signed one, or a server on the user's
  /// own network, has no hosting provider to blame: it is usually reached by
  /// an address the certificate wasn't made for.
  bool get _looksLikeHostingDefault => !certificate.isSelfIssued && !_isLocal;

  Map<String, String> _params() => {
    'host': _hostLabel,
    'name': _names,
    'issuer': certificate.issuerName,
    'date': certificateDate(
      formatter,
      _lead == CertificateProblem.notYetValid
          ? certificate.notBefore
          : certificate.notAfter,
    ),
  };

  String _leadSentence(BuildContext context) {
    final p = _params();
    return switch (_lead) {
      CertificateProblem.nameMismatch => context.tr(
        _looksLikeHostingDefault
            ? 'certificate_lead_name_mismatch'
            : 'certificate_lead_name_mismatch_plain',
        p,
      ),
      CertificateProblem.selfSigned => [
        context.tr('certificate_lead_self_signed', p),
        if (_isLocal) context.tr('certificate_lan_self_signed'),
      ].join(' '),
      CertificateProblem.expired => context.tr('certificate_lead_expired', p),
      CertificateProblem.notYetValid => context.tr(
        'certificate_lead_not_yet_valid',
        p,
      ),
      CertificateProblem.untrustedIssuer => context.tr(
        'certificate_lead_untrusted_issuer',
        p,
      ),
    };
  }

  String _fixSentence(BuildContext context) => switch (_lead) {
    CertificateProblem.nameMismatch => context.tr(
      _looksLikeHostingDefault
          ? 'certificate_fix_name_mismatch'
          : 'certificate_fix_name_mismatch_plain',
      _params(),
    ),
    CertificateProblem.selfSigned => context.tr('certificate_fix_self_signed'),
    CertificateProblem.expired ||
    CertificateProblem.notYetValid => context.tr('certificate_fix_dates'),
    CertificateProblem.untrustedIssuer => context.tr(
      'certificate_fix_untrusted_issuer',
    ),
  };

  /// The problems after the lead, one short line each.
  List<String> _otherProblems(BuildContext context) {
    String line(CertificateProblem problem) {
      final p = {
        ..._params(),
        'date': certificateDate(
          formatter,
          problem == CertificateProblem.notYetValid
              ? certificate.notBefore
              : certificate.notAfter,
        ),
      };
      return switch (problem) {
        CertificateProblem.nameMismatch => context.tr(
          'certificate_problem_name_mismatch',
          p,
        ),
        CertificateProblem.selfSigned => context.tr(
          'certificate_problem_self_signed',
        ),
        CertificateProblem.expired => context.tr(
          'certificate_problem_expired',
          p,
        ),
        CertificateProblem.notYetValid => context.tr(
          'certificate_problem_not_yet_valid',
          p,
        ),
        CertificateProblem.untrustedIssuer => context.tr(
          'certificate_problem_untrusted_issuer',
          p,
        ),
      };
    }

    return [for (final problem in problems.skip(1)) line(problem)];
  }

  /// The strong wording only where impersonation is the live risk: a public
  /// server presenting someone else's name. A self-signed certificate on the
  /// user's own network is the normal case, and saying otherwise teaches
  /// people to click through warnings.
  String _riskSentence(BuildContext context) {
    final impersonation =
        !_isLocal && problems.contains(CertificateProblem.nameMismatch);
    return [
      context.tr(
        impersonation ? 'certificate_risk_impersonation' : 'certificate_risk',
      ),
      context.tr('certificate_still_refused'),
    ].join(' ');
  }

  /// A plain-text block to paste into a message to whoever runs the server.
  String _details(BuildContext context) => [
    _hostLabel,
    _leadSentence(context),
    ..._otherProblems(context),
    '${context.tr('issued_to')}: $_names',
    '${context.tr('issued_by')}: ${certificate.issuerName}',
    '${context.tr('valid_until')}: '
        '${certificateDate(formatter, certificate.notAfter)}',
    '${context.tr('sha256_fingerprint')}: ${certificate.displayFingerprint}',
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium?.copyWith(color: tokens.ink);
    final secondary = theme.textTheme.bodySmall?.copyWith(color: tokens.ink2);
    final others = _otherProblems(context);
    final replacing = this.replacing;
    return AlertDialog(
      scrollable: true,
      title: Text(context.tr('certificate_cant_verify', {'host': _hostLabel})),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replacing != null) ...[
              _Callout(
                key: const ValueKey('certificate_replacing_warning'),
                text: context.tr('certificate_replacing_warning', {
                  'date': certificateDate(formatter, replacing.trustedAt),
                }),
              ),
              SizedBox(height: InSpacing.md(context)),
            ],
            Text(_leadSentence(context), style: body),
            if (others.isNotEmpty) ...[
              const SizedBox(height: InSpacing.sm),
              for (final line in others)
                Padding(
                  padding: const EdgeInsets.only(bottom: InSpacing.xs),
                  child: Text('•  $line', style: body),
                ),
            ],
            const SizedBox(height: InSpacing.sm),
            Text(_fixSentence(context), style: body),
            if (canTrust) ...[
              const SizedBox(height: InSpacing.sm),
              Text(_riskSentence(context), style: secondary),
            ],
            SizedBox(height: InSpacing.lg(context)),
            _FactsCard(
              rows: [
                (context.tr('issued_to'), _names, false),
                (context.tr('issued_by'), certificate.issuerName, false),
                (
                  context.tr('valid_until'),
                  certificateDate(formatter, certificate.notAfter),
                  false,
                ),
                (
                  context.tr('sha256_fingerprint'),
                  certificate.displayFingerprint,
                  true,
                ),
              ],
            ),
            const SizedBox(height: InSpacing.xs),
            TextButton.icon(
              key: const ValueKey('certificate_copy_details'),
              onPressed: () => copyToClipboard(
                context,
                _details(context),
                label: context.tr('certificate_details'),
              ),
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: Text(context.tr('copy_details')),
            ),
          ],
        ),
      ),
      actions: canTrust
          ? [
              OutlinedButton(
                // The safe action holds the focus: a stray Enter, Android
                // "Done" or the tail of a double-tap must never trust a
                // certificate.
                autofocus: true,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.tr('cancel')),
              ),
              PrimaryDialogAction(
                buttonKey: const ValueKey('certificate_trust'),
                label: context.tr(
                  continues ? 'trust_and_continue' : 'trust_certificate',
                ),
                autofocus: false,
                showEnterHint: false,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ]
          : [
              OutlinedButton(
                autofocus: true,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.tr('close')),
              ),
            ],
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(InSpacing.sm),
      decoration: BoxDecoration(
        color: tokens.warningSoft,
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: tokens.warning),
          const SizedBox(width: InSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label over value, so a long name or the fingerprint wraps instead of
/// crowding a label column on a phone.
class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.rows});

  final List<(String label, String value, bool mono)> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, (label, value, mono)) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: InSpacing.sm),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: tokens.ink3),
            ),
            const SizedBox(height: 2),
            SelectableText(
              value,
              style: mono
                  ? theme.textTheme.bodySmall?.copyWith(
                      fontFamily: kMonoFontFamily,
                      color: tokens.ink,
                    )
                  : theme.textTheme.bodyMedium?.copyWith(color: tokens.ink),
            ),
          ],
        ],
      ),
    );
  }
}
