import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';

/// Subdomain text field for the Client Portal → Settings tab. Writes the
/// top-level `Company.subdomain` field through `host.updateCompany`.
///
/// As the user types, the field debounces 500 ms and probes the server
/// (`POST /api/v1/check_subdomain`) for availability. The inline helper text
/// flips between three states:
///   * not yet checked / typing — shows the projected URL preview
///     (`<subdomain>.invoicing.co/client/login`)
///   * available — checkmark icon + "available"
///   * taken — error icon + `subdomain_is_not_available`
///
/// **Save is never blocked on a failing check.** The server is authoritative
/// — if the user saves a taken subdomain, the PUT returns 422 and the
/// existing tab-jump resolver surfaces the field error. Blocking save here
/// would race with the debounce and create a stuck "still checking" state on
/// a flaky network.
class SubdomainField extends StatefulWidget {
  const SubdomainField({super.key, this.enabled = true});

  /// When false (free plan), the input is disabled. The check still runs at
  /// company-owner level on the server.
  final bool enabled;

  @override
  State<SubdomainField> createState() => _SubdomainFieldState();
}

enum _AvailabilityState { unknown, checking, available, taken }

class _SubdomainFieldState extends State<SubdomainField> {
  late final TextEditingController _controller;
  Timer? _debounce;
  _AvailabilityState _state = _AvailabilityState.unknown;
  String? _lastChecked;
  SettingsDraftHost? _host;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to the host once. Re-running on every didChangeDependencies
    // is safe — removeListener is idempotent and the host is stable across
    // rebuilds inside the cascade scaffold (changes to scope remount the
    // whole subtree per `_SettingsLevelKeyed`).
    final host = context.read<SettingsDraftHost>();
    if (!identical(_host, host)) {
      _host?.removeListener(_onHostChanged);
      _host = host;
      host.addListener(_onHostChanged);
    }
    // Seed / re-seed the controller from the host. On first mount _lastChecked
    // is null so the seed runs once; subsequent host pushes (refresh, scope
    // flip) flow through _onHostChanged.
    final hostValue = host.draft?.subdomain ?? '';
    if (_controller.text != hostValue) {
      _controller.value = TextEditingValue(
        text: hostValue,
        selection: TextSelection.collapsed(offset: hostValue.length),
      );
      _lastChecked = hostValue;
      _state = _AvailabilityState.unknown;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _host?.removeListener(_onHostChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Host pushed a new draft (refresh emission, reset, etc.). Sync the
  /// controller; if the value diverged from what we last checked, schedule a
  /// fresh availability probe so the user doesn't see a stuck "checking"
  /// state when the field re-seeds.
  void _onHostChanged() {
    if (!mounted) return;
    final hostValue = _host?.draft?.subdomain ?? '';
    if (_controller.text == hostValue) return;
    _controller.value = TextEditingValue(
      text: hostValue,
      selection: TextSelection.collapsed(offset: hostValue.length),
    );
    if (hostValue != _lastChecked) {
      _scheduleCheck(hostValue);
    }
  }

  void _onChanged(String value) {
    context.read<SettingsDraftHost>().updateCompany(
      (c) => c.copyWith(subdomain: value),
    );
    _scheduleCheck(value);
  }

  void _scheduleCheck(String value) {
    _debounce?.cancel();
    if (value.isEmpty) {
      setState(() => _state = _AvailabilityState.unknown);
      return;
    }
    setState(() => _state = _AvailabilityState.checking);
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _runCheck(value);
    });
  }

  Future<void> _runCheck(String value) async {
    final services = context.read<Services>();
    try {
      final available = await services.companies.checkSubdomainAvailable(value);
      if (!mounted) return;
      if (_controller.text != value) return;
      setState(() {
        _lastChecked = value;
        _state = available
            ? _AvailabilityState.available
            : _AvailabilityState.taken;
      });
    } catch (_) {
      if (!mounted) return;
      // Network / 5xx — drop back to "unknown" so the user doesn't see a
      // misleading red error. The save path will surface real validation
      // failures from the server.
      setState(() => _state = _AvailabilityState.unknown);
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final scope = FormSaveScope.maybeOf(context);
    final errors = host.fieldErrors['subdomain'];
    final errorText = (errors != null && errors.isNotEmpty)
        ? errors.first
        : null;
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          textInputAction: TextInputAction.done,
          // A DNS label. `url` is the closest keyboard — it keeps the
          // default (no) auto-capitalization and surfaces `.`; it does NOT
          // lowercase anything, and it offers `/` and `.com`, neither legal
          // in a single label. The server validates the value regardless.
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: context.tr('subdomain'),
            errorText: errorText,
            suffixIcon: _StateIcon(state: _state),
          ),
          onChanged: _onChanged,
          onSubmitted: scope == null ? null : (_) => scope.trySubmit(),
        ),
        if (_controller.text.isNotEmpty) ...[
          SizedBox(height: InSpacing.xs),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: InSpacing.md(context)),
            child: Text(
              _helperText(context, _controller.text),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _state == _AvailabilityState.taken
                    ? Theme.of(context).colorScheme.error
                    : tokens.ink3,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _helperText(BuildContext context, String value) {
    switch (_state) {
      case _AvailabilityState.taken:
        return context.tr('subdomain_is_not_available');
      case _AvailabilityState.available:
      case _AvailabilityState.checking:
      case _AvailabilityState.unknown:
        return '$value.invoicing.co/client/login';
    }
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.state});

  final _AvailabilityState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (state) {
      case _AvailabilityState.unknown:
        return const SizedBox.shrink();
      case _AvailabilityState.checking:
        return Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.outline,
            ),
          ),
        );
      case _AvailabilityState.available:
        return Icon(
          Icons.check_circle_outline,
          color: theme.colorScheme.primary,
        );
      case _AvailabilityState.taken:
        return Icon(Icons.error_outline, color: theme.colorScheme.error);
    }
  }
}
