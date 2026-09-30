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
    this.onEditingComplete,
    this.suffix,
    this.autofillHints,
    this.readOnly = false,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction,
    this.labelTrailing,
  });

  final String label;
  final String? hint;
  final String? initialValue;
  final TextInputType? keyboardType;
  final String? errorText;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Passed straight to the `TextField`. A field whose [textInputAction] is
  /// `next` but whose [onSubmitted] decides where focus goes must pass a
  /// no-op here: without it the framework runs its own `nextFocus()` *before*
  /// `onSubmitted`, which from a password field lands on the reveal button.
  final VoidCallback? onEditingComplete;
  final Widget? suffix;
  final Iterable<String>? autofillHints;

  /// Read-only fields still take part in the surrounding `AutofillGroup` with
  /// their current value (so a password manager sees the username on a
  /// two-step login's second page), but reject text an autofill tries to
  /// write into them.
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Keep this fixed for the field's lifetime: `EditableText` only pushes a
  /// new configuration to the platform when `obscureText` or `keyboardType`
  /// changes, so a `textInputAction` that flips while the keyboard is up
  /// never reaches it.
  final TextInputAction? textInputAction;

  /// Right-aligned on the label row (e.g. "Forgot your password?"). When the
  /// label and this widget don't fit on one line, this one wraps beneath.
  final Widget? labelTrailing;

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
    final label = Text(
      widget.label,
      maxLines: widget.labelTrailing == null ? null : 1,
      overflow: widget.labelTrailing == null ? null : TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: context.inTheme.ink3,
      ),
    );
    final trailing = widget.labelTrailing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: trailing == null
              ? label
              // Label left, trailing widget right; when the two don't fit on
              // one line the trailing one wraps beneath instead of either
              // being ellipsized. A `Wrap` (not a `LayoutBuilder`) so the
              // field still reports intrinsic sizes — an `AlertDialog` lays
              // its content out under `IntrinsicWidth`.
              : Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: InSpacing.sm,
                  runSpacing: 2,
                  children: [label, trailing],
                ),
        ),
        TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          readOnly: widget.readOnly,
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
            suffixIcon: widget.suffix,
          ),
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.obscureText,
          autocorrect: !widget.obscureText,
          enableSuggestions: !widget.obscureText,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          onEditingComplete: widget.onEditingComplete,
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
    this.onEditingComplete,
    this.autofillHints = const [AutofillHints.password],
    this.autofocus = false,
    this.focusNode,
    this.textInputAction,
    this.labelTrailing,
  });

  final String label;
  final String? initialValue;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// See [AuthField.onEditingComplete].
  final VoidCallback? onEditingComplete;
  final bool autofocus;
  final FocusNode? focusNode;

  /// See [AuthField.textInputAction].
  final TextInputAction? textInputAction;

  /// See [AuthField.labelTrailing].
  final Widget? labelTrailing;

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
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      labelTrailing: widget.labelTrailing,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
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

// ─── "── or ──" divider ──────────────────────────────────────────────────

/// Separates an email form from the social sign-in buttons below it. Shared
/// by the login and signup screens.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Row(
      children: [
        Expanded(child: Divider(color: tokens.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: InSpacing.sm),
          // Upper-cased like React's `OrDivider` (CSS `uppercase`).
          child: Text(
            context.tr('or').toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.5,
              color: tokens.ink3,
            ),
          ),
        ),
        Expanded(child: Divider(color: tokens.border)),
      ],
    );
  }
}
