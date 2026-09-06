import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';

/// Canonical single-line text input for any settings screen — covers both
/// bundled-entity CRUD (payment_terms name, task_status name, group_setting
/// name) and plain top-level `company.*` / `user.*` fields outside the
/// cascade (Expense Settings mailbox, User Details first name, etc.).
///
/// The cascade-aware sibling is `OverridableTextField` (writes through a
/// `SettingsBinding`, surfaces the override checkbox at non-company scope).
/// Anything that doesn't fit either of these is a transformed-value field
/// (numeric with zero-as-empty display, password with visibility toggle,
/// etc.) — keep those local to their screen.
///
/// Solves the long-standing resync gap: the underlying
/// `TextEditingController` reseeds whenever the upstream value changes, so
/// an external draft mutation (e.g. the unsaved-changes-guard's Discard
/// path or a deferred-load arrival) repopulates the field instead of
/// silently keeping the stale typed value. Same trick as
/// `OverridableTextField` + `MarkdownTextField`'s `externalValueKey`.
///
/// **Two label modes** — pass exactly one:
/// - [labelKey] looks up `context.tr(labelKey)` at build time. Use for
///   static labels: bundled-entity CRUD, search-catalog-scanned screens.
/// - [labelText] passes a resolved string straight through. Use for
///   call sites that need to interpolate (e.g. tax/region forms) or have
///   already resolved their label upstream.
///
/// **Two resync modes**:
/// - With [externalSyncKey]: reseed only when the key changes (entity
///   swap, scope swap). In-progress typing is never clobbered by content
///   refresh emissions for the same key. Use for entity-CRUD screens.
/// - Without [externalSyncKey]: reseed when [initialValue] changes between
///   rebuilds *and* differs from the controller text. Safe because the
///   typical onChanged → vm.updateCompany → rebuild cycle keeps them in
///   lockstep; a real upstream change (Discard, refresh) trips both
///   guards. Use for plain top-level fields whose value is the draft.
///
/// Pressing Enter submits the surrounding [FormSaveScope] when present —
/// per CLAUDE.md § Forms § Enter to save.
class SettingsTextField extends StatefulWidget {
  const SettingsTextField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.labelKey,
    this.labelText,
    this.helperText,
    this.helperMaxLines,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textInputAction = TextInputAction.done,
    this.externalSyncKey,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.autocorrect = true,
  }) : assert(
         (labelKey == null) != (labelText == null),
         'Pass exactly one of labelKey or labelText',
       );

  final String initialValue;

  /// Localization key for the field's floating label. Mutually exclusive
  /// with [labelText].
  final String? labelKey;

  /// Pre-resolved label string. Mutually exclusive with [labelKey].
  final String? labelText;

  final String? helperText;
  final int? helperMaxLines;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction textInputAction;

  /// When this value changes between rebuilds, the internal controller
  /// reseeds from [initialValue] — even if `initialValue` itself didn't
  /// change. Pass the loaded entity's id (or `vm.original?.id`) so reopening
  /// a different row repopulates the field. Leave null for plain top-level
  /// fields (the fallback resync rule covers Discard / refresh emissions).
  final Object? externalSyncKey;

  /// Soft-keyboard auto-capitalization. `words` for proper nouns (names,
  /// cities, streets), `characters` for postal codes. Defaults to Flutter's
  /// own `none`, so passing nothing changes nothing.
  final TextCapitalization textCapitalization;

  /// OS autofill hints. **Only ever set these on a field describing the
  /// signed-in user or their own company** — never on a client / vendor /
  /// contact record, where the platform would offer the *admin's* own name,
  /// phone and address. Flutter gates on null vs non-null, so an empty list
  /// does NOT opt out (see `auth_fields.dart`).
  final Iterable<String>? autofillHints;

  /// Set false on identifier-shaped values iOS would happily "correct" —
  /// VAT / registration numbers, hostnames, API keys. Also drives
  /// `enableSuggestions`, which travels with it.
  final bool autocorrect;

  @override
  State<SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<SettingsTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void didUpdateWidget(covariant SettingsTextField old) {
    super.didUpdateWidget(old);
    if (widget.externalSyncKey != null) {
      // Keyed mode: reseed only when the key changes. The extra
      // `initialValue != controller.text` check lets a same-key reset (e.g.
      // Discard for the same entity) still flush.
      if (old.externalSyncKey != widget.externalSyncKey &&
          _controller.text != widget.initialValue) {
        _setControllerText(widget.initialValue);
      }
    } else {
      // Plain mode: reseed when upstream changes and differs from the
      // typed text. Same guard `_PlainTextField` and `_MailboxTextField`
      // shipped with — won't clobber an in-progress keystroke.
      if (widget.initialValue != _controller.text &&
          widget.initialValue != old.initialValue) {
        _setControllerText(widget.initialValue);
      }
    }
  }

  void _setControllerText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = FormSaveScope.maybeOf(context);
    final labelKey = widget.labelKey;
    final label = labelKey != null ? context.tr(labelKey) : widget.labelText!;
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: widget.helperText,
        helperMaxLines: widget.helperMaxLines,
        errorText: widget.errorText,
      ),
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      autofillHints: widget.autofillHints,
      // One knob, not two — the pairing `AuthField` already uses.
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.autocorrect,
      inputFormatters: widget.inputFormatters,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: scope == null ? null : (_) => scope.trySubmit(),
    );
  }
}
