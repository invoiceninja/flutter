import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/passkey_repository.dart';
import 'package:admin/data/services/passkey_api.dart';
import 'package:admin/data/services/passkey_readiness.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/dialogs/untrusted_certificate_dialog.dart'
    show fallbackCertificateFormatter;
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/settings/views/basic/user_details/view_models/passkeys_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/utils/formatting.dart';

/// The Passkeys card on Settings → User Details → Two-Factor
/// (docs/passkeys.md): the user's passkeys, each removable, and a way to add
/// one for this device.
///
/// Absent — not empty — on a server without passkey routes, in demo mode,
/// and where there is nothing to manage and this device cannot add one. Add
/// shows only once [PasskeyReadiness] has proven a passkey can work against
/// this server on this device.
class PasskeysSection extends StatefulWidget {
  const PasskeysSection({
    super.key,
    required this.apiBaseUrl,
    required this.isHosted,
  });

  final String apiBaseUrl;
  final bool isHosted;

  @override
  State<PasskeysSection> createState() => _PasskeysSectionState();
}

class _PasskeysSectionState extends State<PasskeysSection>
    with FormatterHostMixin {
  PasskeysViewModel? _vm;

  @override
  void initState() {
    super.initState();
    // Root providers, not `Services` members: the test fakes of `Services`
    // throw on a new one, and a host without them has no passkeys to show.
    final repo = context.read<PasskeyRepository?>();
    final readiness = context.read<PasskeyReadiness?>();
    if (repo == null || readiness == null) return;
    _vm = PasskeysViewModel(
      repo: repo,
      readiness: readiness,
      apiBaseUrl: widget.apiBaseUrl,
      isHosted: widget.isHosted,
    )..load();
    // Once per screen (CLAUDE.md § Strict rules), for the rows' dates.
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    if (companyId.isNotEmpty) loadFormatter(services, companyId);
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (!vm.visible) return const SizedBox.shrink();
        final tokens = context.inTheme;
        final small = Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: tokens.ink2);
        return FormSection(
          title: context.tr('manage_passkeys'),
          children: [
            Text(
              context.tr('passkeys_help'),
              style: TextStyle(color: tokens.ink2, height: 1.4),
            ),
            if (vm.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (vm.loadFailed)
              Row(
                children: [
                  Expanded(
                    child: Text(context.tr('an_error_occurred'), style: small),
                  ),
                  TextButton(
                    key: const ValueKey('passkeys_retry'),
                    onPressed: vm.load,
                    child: Text(context.tr('retry')),
                  ),
                ],
              )
            else ...[
              for (final passkey in vm.passkeys)
                _PasskeyRow(
                  key: ValueKey('passkey_${passkey.id}'),
                  passkey: passkey,
                  // The company's until it resolves; the mixin rebuilds.
                  formatter: formatter ?? fallbackCertificateFormatter(),
                  onRemove: vm.busy ? null : () => _remove(context, passkey),
                ),
              if (vm.canRegister) ...[
                SizedBox(height: InSpacing.sm),
                Row(
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('passkeys_add'),
                      onPressed: vm.busy || vm.atLimit
                          ? null
                          : () => _add(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 40),
                      ),
                      icon: vm.busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add, size: 18),
                      label: Text(context.tr('add')),
                    ),
                    if (vm.atLimit) ...[
                      SizedBox(width: InSpacing.md(context)),
                      Flexible(
                        child: Text(
                          context.tr('max_limit', {
                            'max': '$kMaxPasskeysPerUser',
                          }),
                          style: small,
                        ),
                      ),
                    ],
                  ],
                ),
              ] else
                Text(context.tr('passkeys_cannot_add_here'), style: small),
            ],
          ],
        );
      },
    );
  }

  Future<void> _add(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _PasskeyNameDialog(initialName: _platformLabel()),
    );
    if (name == null || !context.mounted) return;
    final result = await _vm!.add(name);
    if (!context.mounted) return;
    _report(context, result);
  }

  Future<void> _remove(BuildContext context, RegisteredPasskey passkey) async {
    if (context.read<Services>().confirmActions.value) {
      final ok = await showConfirmActionDialog(
        context,
        title: context.tr('remove'),
        subject: _displayName(context, passkey),
        destructive: true,
      );
      if (!ok || !context.mounted) return;
    }
    final result = await _vm!.remove(passkey);
    if (!context.mounted) return;
    _report(context, result);
  }

  void _report(BuildContext context, PasskeyActionResult result) {
    if (result.ok) {
      Notify.success(context, context.tr('updated_settings'));
      return;
    }
    final key = result.errorKey;
    final message = key != null ? context.tr(key) : result.message;
    if (message != null) Notify.error(context, message);
  }
}

/// The passkey's name, or the generic word when the server stored none.
String _displayName(BuildContext context, RegisteredPasskey passkey) =>
    passkey.name.trim().isEmpty ? context.tr('passkey') : passkey.name;

/// A default name for a passkey added here — product names, so nothing to
/// translate. Not the device model: the passkey usually syncs to the user's
/// other devices through their password manager, and iOS reports only
/// "iPhone" anyway.
String _platformLabel() {
  if (kIsWeb) return 'Web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.windows => 'Windows',
    _ => '',
  };
}

class _PasskeyRow extends StatelessWidget {
  const _PasskeyRow({
    super.key,
    required this.passkey,
    required this.formatter,
    required this.onRemove,
  });

  final RegisteredPasskey passkey;
  final Formatter formatter;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final name = _displayName(context, passkey);
    final created = passkey.createdAt;
    final lastUsed = passkey.lastUsedAt;
    final facts = [
      if (created != null) '${context.tr('created')}: ${_date(created)}',
      '${context.tr('last_used')}: '
          '${lastUsed == null ? context.tr('never') : _date(lastUsed)}',
    ].join(' · ');
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Icon(Icons.key, size: 18, color: tokens.ink3),
          const SizedBox(width: InSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  facts,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.ink2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: InSpacing.sm),
          // Names the passkey, so ten rows don't read as ten identical
          // "Remove" buttons; the excluded button's tap is declared again.
          Semantics(
            label: '${context.tr('remove')}: $name',
            excludeSemantics: true,
            button: true,
            enabled: onRemove != null,
            onTap: onRemove,
            child: TextButton(
              key: ValueKey('passkey_remove_${passkey.id}'),
              onPressed: onRemove,
              child: Text(context.tr('remove')),
            ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime value) =>
      formatter.date(value.toLocal().toIso8601String());
}

/// Names the passkey before the OS sheet opens. Returns the name (possibly
/// blank — the server then picks one), or null when cancelled.
class _PasskeyNameDialog extends StatefulWidget {
  const _PasskeyNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_PasskeyNameDialog> createState() => _PasskeyNameDialogState();
}

class _PasskeyNameDialogState extends State<_PasskeyNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialName.length,
        );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('passkey')),
      content: FormSaveScope(
        onSubmit: _submit,
        child: Builder(
          builder: (context) => TextField(
            key: const ValueKey('passkey_name'),
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(255)],
            decoration: InputDecoration(labelText: context.tr('name')),
            onSubmitted: (_) => FormSaveScope.maybeOf(context)?.trySubmit(),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          buttonKey: const ValueKey('passkey_name_continue'),
          label: context.tr('continue'),
          autofocus: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}
