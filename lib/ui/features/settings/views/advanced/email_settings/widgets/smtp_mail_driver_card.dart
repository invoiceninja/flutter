import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// SMTP transport card on Settings → Email Settings. Renders when the
/// `email_sending_method` dropdown is set to `smtp`. The seven fields are
/// top-level `Company.*` (not cascade-aware), so the card writes through
/// `host.updateCompany((c) => c.copyWith(...))`.
///
/// The "Send Test Email" action lives in the section's trailing slot,
/// right-aligned (drops to full-width below 600 px). It POSTs the current
/// seven-field snapshot to `/api/v1/smtp/check` via [SmtpApi.check] and
/// surfaces the server's reply through [Notify].
class SmtpMailDriverCard extends StatefulWidget {
  const SmtpMailDriverCard({super.key});

  @override
  State<SmtpMailDriverCard> createState() => _SmtpMailDriverCardState();
}

class _SmtpMailDriverCardState extends State<SmtpMailDriverCard> {
  bool _isTesting = false;

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final company = host.draft;
    if (company == null) return const SizedBox.shrink();

    final narrow = MediaQuery.sizeOf(context).width < 600;
    final testButton = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
      icon: _isTesting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send_outlined),
      label: Text(context.tr('send_test_email')),
      onPressed: _isTesting ? null : () => _onSendTest(context, company),
    );

    return FormSection(
      title: context.tr('smtp'),
      trailing: narrow ? null : testButton,
      children: [
        _hostField(context, host, company),
        _portField(context, host, company),
        _encryptionDropdown(context, host, company),
        _usernameField(context, host, company),
        _passwordField(context, host, company),
        _localDomainField(context, host, company),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('verify_peer')),
          value: company.smtpVerifyPeer,
          onChanged: (v) =>
              host.updateCompany((c) => c.copyWith(smtpVerifyPeer: v)),
        ),
        if (narrow)
          Padding(
            padding: EdgeInsets.only(top: InSpacing.md(context)),
            child: SizedBox(width: double.infinity, child: testButton),
          ),
      ],
    );
  }

  Widget _hostField(
    BuildContext context,
    SettingsDraftHost host,
    Company company,
  ) {
    return _SmtpTextField(
      label: context.tr('host'),
      helper: context.tr('host_help'),
      initial: company.smtpHost,
      keyboardType: TextInputType.url,
      autocorrect: false,
      onChanged: (v) => host.updateCompany((c) => c.copyWith(smtpHost: v)),
    );
  }

  Widget _portField(
    BuildContext context,
    SettingsDraftHost host,
    Company company,
  ) {
    return _SmtpTextField(
      label: context.tr('port'),
      helper: context.tr('port_help'),
      initial: company.smtpPort == 0 ? '' : company.smtpPort.toString(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (v) {
        final parsed = int.tryParse(v) ?? 0;
        host.updateCompany((c) => c.copyWith(smtpPort: parsed));
      },
    );
  }

  Widget _encryptionDropdown(
    BuildContext context,
    SettingsDraftHost host,
    Company company,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: _normalizeEncryption(company.smtpEncryption),
      decoration: InputDecoration(labelText: context.tr('encryption')),
      items: const [
        // Values are the lowercase tokens the server feeds straight into
        // Symfony Mailer (see CompanyTransformer / NinjaMailerJob): 'tls' =
        // STARTTLS (port 587), 'ssl' = implicit TLS/SSL (port 465). Sending
        // 'TLS'/'STARTTLS' breaks the 465 path.
        // i18n-exempt: protocol identifiers (STARTTLS / SSL/TLS).
        DropdownMenuItem(value: 'tls', child: Text('STARTTLS')),
        DropdownMenuItem(value: 'ssl', child: Text('SSL/TLS')),
      ],
      onChanged: (v) {
        if (v == null) return;
        host.updateCompany((c) => c.copyWith(smtpEncryption: v));
      },
    );
  }

  Widget _usernameField(
    BuildContext context,
    SettingsDraftHost host,
    Company company,
  ) {
    return _SmtpTextField(
      label: context.tr('username'),
      initial: company.smtpUsername,
      autocorrect: false,
      onChanged: (v) => host.updateCompany((c) => c.copyWith(smtpUsername: v)),
    );
  }

  Widget _passwordField(
    BuildContext context,
    SettingsDraftHost host,
    Company company,
  ) {
    return _SmtpTextField(
      label: context.tr('password'),
      initial: company.smtpPassword,
      obscureToggle: true,
      keyboardType: TextInputType.visiblePassword,
      autocorrect: false,
      onChanged: (v) => host.updateCompany((c) => c.copyWith(smtpPassword: v)),
    );
  }

  Widget _localDomainField(
    BuildContext context,
    SettingsDraftHost host,
    Company company,
  ) {
    return _SmtpTextField(
      label: context.tr('local_domain'),
      helper: context.tr('local_domain_help'),
      initial: company.smtpLocalDomain,
      keyboardType: TextInputType.url,
      autocorrect: false,
      onChanged: (v) =>
          host.updateCompany((c) => c.copyWith(smtpLocalDomain: v)),
    );
  }

  Future<void> _onSendTest(BuildContext context, Company company) async {
    setState(() => _isTesting = true);
    final services = context.read<Services>();
    final errorFallback = context.tr('error');
    try {
      final message = await services.smtp.check(
        payload: <String, dynamic>{
          'smtp_host': company.smtpHost,
          'smtp_port': company.smtpPort,
          'smtp_encryption': _normalizeEncryption(company.smtpEncryption),
          'smtp_username': company.smtpUsername,
          'smtp_password': company.smtpPassword,
          'smtp_local_domain': company.smtpLocalDomain,
          // Server reads `verify_peer` (not `smtp_verify_peer`) — see
          // CheckSmtpRequest; the prefixed key was silently ignored.
          'verify_peer': company.smtpVerifyPeer,
        },
      );
      if (!context.mounted) return;
      Notify.success(
        context,
        message.isEmpty ? context.tr('success') : message,
      );
    } catch (e) {
      if (!context.mounted) return;
      Notify.error(context, errorFallback, detail: e.toString());
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }
}

/// Normalizes a stored `smtp_encryption` value to the lowercase token the
/// server expects (Symfony Mailer: `tls` = STARTTLS, `ssl` = implicit TLS).
/// Legacy admin-portal values (`TLS` / `STARTTLS`), empty, and anything
/// unknown collapse to `tls`, so the value always matches a dropdown item
/// (no "value not in items" assertion) and uppercase never reaches the server.
String _normalizeEncryption(String raw) =>
    raw.toLowerCase() == 'ssl' ? 'ssl' : 'tls';

/// Internal labeled text field for the seven SMTP rows. Mirrors
/// [OverridableTextField]'s look-and-feel (label + helper + optional eye
/// toggle) but bypasses the cascade machinery — these are top-level
/// `Company.*` fields, not cascade-aware settings.
class _SmtpTextField extends StatefulWidget {
  const _SmtpTextField({
    required this.label,
    required this.initial,
    required this.onChanged,
    this.helper,
    this.keyboardType,
    this.inputFormatters,
    this.obscureToggle = false,
    this.autocorrect = true,
  });

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;
  final String? helper;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureToggle;

  /// False for the hostname / username / credential rows — none of them is
  /// prose, and iOS will happily "correct" a mail server name.
  final bool autocorrect;

  @override
  State<_SmtpTextField> createState() => _SmtpTextFieldState();
}

class _SmtpTextFieldState extends State<_SmtpTextField> {
  late final TextEditingController _controller;
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _obscured = widget.obscureToggle;
  }

  @override
  void didUpdateWidget(covariant _SmtpTextField old) {
    super.didUpdateWidget(old);
    if (widget.initial != _controller.text && widget.initial != old.initial) {
      _controller.value = TextEditingValue(
        text: widget.initial,
        selection: TextSelection.collapsed(offset: widget.initial.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      // Keyed on the declaration, not the live reveal state — see
      // `overridable_text_field.dart`.
      autocorrect: widget.autocorrect && !widget.obscureToggle,
      enableSuggestions: widget.autocorrect && !widget.obscureToggle,
      inputFormatters: widget.inputFormatters,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        suffixIcon: widget.obscureToggle
            ? IconButton(
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
      ),
      onChanged: widget.onChanged,
    );
  }
}
