import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/gateway.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/gateways/view_models/company_gateway_edit_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/utils/url_safety.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Dynamic credentials form. Reads the active provider's `parsedFields`
/// JSON schema and routes each `(name, descriptor)` to a control:
///   * `bool` → toggle.
///   * `String` of `[a,b,c]` (with commas) → dropdown.
///   * `String` shaped like a hex color OR field name containing "color"
///     → hex text input (Phase 3 will swap in a real swatch picker).
///   * Else → text input. Obscure-by-default for password / secret / key /
///     token fields with an eye-icon toggle.
class GatewayConfigForm extends StatefulWidget {
  const GatewayConfigForm({super.key, required this.vm, required this.gateway});

  final CompanyGatewayEditViewModel vm;
  final Gateway gateway;

  @override
  State<GatewayConfigForm> createState() => _GatewayConfigFormState();
}

class _GatewayConfigFormState extends State<GatewayConfigForm> {
  final Map<String, bool> _showSensitive = {};
  bool _testing = false;

  @override
  Widget build(BuildContext context) {
    final fields = widget.gateway.parsedFields;
    final values = widget.vm.draft.parsedConfig;
    final siteUrl = widget.gateway.siteUrl;
    return SettingsFormShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // siteUrl is server-supplied (gateway catalog from /refresh).
          // Reject anything that isn't http/https before launching so a
          // hostile catalog can't push javascript:/file:/intent: URIs.
          if (isSafeWebUrl(siteUrl)) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: () => launchUrl(
                  Uri.parse(siteUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(context.tr('learn_more')),
              ),
            ),
            SizedBox(height: InSpacing.lg(context)),
          ],
          if (fields.isEmpty)
            FormSection(
              title: context.tr('credentials'),
              children: [Text(context.tr('no_payment_types_enabled'))],
            )
          else
            FormSection(
              title: context.tr('credentials'),
              children: [
                for (final entry in fields.entries)
                  _fieldWidget(entry.key, entry.value, values[entry.key]),
              ],
            ),
          if (!widget.vm.isCreate)
            FormSection(
              title: context.tr('check_credentials'),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    onPressed: _testing
                        ? null
                        : () => _runTestCredentials(context),
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_outlined, size: 18),
                    label: Text(context.tr('check_credentials')),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _runTestCredentials(BuildContext context) async {
    setState(() => _testing = true);
    try {
      final services = context.read<Services>();
      final result = await services.companyGateways.testCredentials(
        id: widget.vm.draft.id,
      );
      if (!context.mounted) return;
      if (result.valid) {
        Notify.success(context, context.tr('valid_credentials'));
      } else {
        // `??` alone doesn't cover it — the server's `message` is a plain
        // String that can arrive as `""`, which would title the toast blank.
        final reason = result.message?.trim();
        Notify.error(
          context,
          reason == null || reason.isEmpty
              ? context.tr('invalid_credentials')
              : reason,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Notify.error(context, context.tr('an_error_occurred'), error: e);
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Widget _fieldWidget(String name, Object? descriptor, Object? current) {
    // Bool — toggle.
    if (descriptor is bool) {
      final value = current is bool ? current : descriptor;
      return SwitchListTile(
        title: Text(_humanize(name)),
        value: value,
        onChanged: (v) => widget.vm.updateConfigField(name, v),
        contentPadding: EdgeInsets.zero,
      );
    }
    // Dropdown — `[a,b,c]` shape.
    if (descriptor is String &&
        descriptor.startsWith('[') &&
        descriptor.endsWith(']') &&
        descriptor.contains(',')) {
      final inner = descriptor.substring(1, descriptor.length - 1);
      final options = inner
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final value = current?.toString();
      return DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: _humanize(name)),
        items: [
          for (final opt in options)
            DropdownMenuItem(value: opt, child: Text(opt)),
        ],
        onChanged: (v) => widget.vm.updateConfigField(name, v),
      );
    }
    // Color hex.
    final lower = name.toLowerCase();
    final looksLikeColor =
        lower.contains('color') ||
        (descriptor is String &&
            RegExp(r'^#?[0-9A-Fa-f]{6}$').hasMatch(descriptor));
    if (looksLikeColor) {
      return TextFormField(
        initialValue: current?.toString() ?? descriptor?.toString() ?? '',
        decoration: InputDecoration(
          labelText: _humanize(name),
          hintText: '#RRGGBB',
        ),
        onChanged: (v) => widget.vm.updateConfigField(name, v),
      );
    }
    // Plain text — obscure for sensitive field names.
    final isSensitive =
        lower.contains('password') ||
        lower.contains('secret') ||
        lower.contains('key') ||
        lower.contains('token');
    final isMultiline = name == 'text' || name == 'appleDomainVerification';
    final reveal = _showSensitive[name] ?? false;
    // Keyboard is derived from the descriptor name, same as `isSensitive`
    // above — these fields are generated per gateway, so there is no call
    // site to annotate. Nothing here is prose, so autocorrect stays off
    // throughout; `autofillHints` is never set, so the OS password manager
    // can't offer the user's own credentials for a merchant account.
    final TextInputType? keyboardType;
    if (isMultiline) {
      keyboardType = null; // TextField derives multiline from maxLines.
    } else if (lower.contains('email')) {
      keyboardType = TextInputType.emailAddress;
    } else if (lower.contains('url') ||
        lower.contains('domain') ||
        lower.contains('endpoint')) {
      keyboardType = TextInputType.url;
    } else if (isSensitive) {
      keyboardType = TextInputType.visiblePassword;
    } else {
      keyboardType = null;
    }
    return TextFormField(
      initialValue: current?.toString() ?? '',
      maxLines: isMultiline ? 5 : 1,
      obscureText: isSensitive && !reveal,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: _humanize(name),
        errorText: widget.vm.fieldErrorFor('config.$name'),
        suffixIcon: isSensitive
            ? IconButton(
                icon: Icon(
                  reveal
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _showSensitive[name] = !reveal),
                tooltip: reveal ? context.tr('hide') : context.tr('show'),
              )
            : null,
      ),
      onChanged: (v) => widget.vm.updateConfigField(name, v),
    );
  }

  /// Pretty-print a camelCase / snake_case field name for the label slot.
  String _humanize(String name) {
    final out = StringBuffer();
    var capNext = true;
    for (var i = 0; i < name.length; i++) {
      final c = name[i];
      if (c == '_') {
        out.write(' ');
        capNext = true;
        continue;
      }
      if (i > 0 &&
          c.toUpperCase() == c &&
          name[i - 1].toLowerCase() == name[i - 1]) {
        out.write(' ');
      }
      out.write(capNext ? c.toUpperCase() : c);
      capNext = false;
    }
    return out.toString();
  }
}
