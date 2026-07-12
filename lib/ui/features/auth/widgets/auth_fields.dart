import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// Shared auth-screen building blocks. Used by both the login and signup
/// screens so the two stay visually identical and we don't copy-paste form
/// chrome. Moved verbatim out of `login_screen.dart` (private `_SurfaceCard`
/// / `_InField` / `_PasswordField`).

// ─── Surface card ────────────────────────────────────────────────────────

class AuthSurfaceCard extends StatelessWidget {
  const AuthSurfaceCard({
    super.key,
    required this.child,
    required this.padding,
    required this.shadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: tokens.border),
        boxShadow: shadow,
      ),
      padding: padding,
      child: child,
    );
  }
}

// ─── Eyebrow section label ───────────────────────────────────────────────

class AuthEyebrowLabel extends StatelessWidget {
  const AuthEyebrowLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: InSpacing.sm),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: context.inTheme.ink3,
        ),
      ),
    );
  }
}

// ─── Field with above-the-field label (v2 convention) ──────────────────

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    this.hint,
    this.initialValue,
    this.keyboardType,
    this.errorText,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.autofillHints,
  });

  final String label;
  final String? hint;
  final String? initialValue;
  final TextInputType? keyboardType;
  final String? errorText;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final Iterable<String>? autofillHints;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.inTheme.ink3,
            ),
          ),
        ),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            suffixIcon: widget.suffix,
          ),
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          autocorrect: !widget.obscureText,
          enableSuggestions: !widget.obscureText,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
        ),
      ],
    );
  }
}

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.label,
    this.initialValue,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final String label;
  final String? initialValue;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Autofill hints for the obscured field. Defaults to the account-password
  /// hint (the common case). Pass `null` for an obscured field that isn't the
  /// account password (e.g. a config secret) so it's excluded from the
  /// surrounding `AutofillGroup` and the OS password manager won't offer the
  /// saved login password there. (An empty list would NOT disable autofill —
  /// Flutter gates on null vs non-null, so a non-null empty list is still an
  /// enabled autofill participant, identical to the framework default.)
  final Iterable<String>? autofillHints;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return AuthField(
      label: widget.label,
      initialValue: widget.initialValue,
      errorText: widget.errorText,
      obscureText: _obscured,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      suffix: IconButton(
        tooltip: _obscured
            ? context.tr('show_password')
            : context.tr('hide_password'),
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 18,
          color: context.inTheme.ink3,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      ),
    );
  }
}
